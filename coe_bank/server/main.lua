-- coe_bank (servidor): banco básico do personagem. Saldo da conta (coe_economy), dinheiro em espécie (item `money` do
-- coe_inventory), saque, depósito, transferência por ID de cidadão e extrato, nas agências e nos caixas eletrônicos.
-- Um pacote com banco completo assume o atendimento pelo export Yield (ACE coe.bank.yield).
local config = BankConfig

local sessions = {}   -- playerId -> { mode, agencyId, title, at }
local busy = {}
local lastAction = {}
local yieldedBy = nil

local rawLocales = (type(Locales) == 'table' and Locales) or {}
local _t_inst = (Core and Core.Locale and Core.Locale.New) and Core.Locale.New({
	default = (config and config.Locale) or (Core and Core.Locale and Core.Locale.GetDefaultLang()) or 'pt-BR',
	locales = rawLocales
})
local _t = function(k, params)
	if type(_t_inst) == 'table' and _t_inst.T then
		return _t_inst:T(k, params)
	elseif type(_t_inst) == 'function' then
		return _t_inst(k, params)
	end
	return (rawLocales['pt-BR'] and rawLocales['pt-BR'][k]) or k
end

local function log(level, category, event, context)
	pcall(function()
		return exports.coe_logging:Log(level, category, event, context)
	end)
end

local function audit(event, context)
	pcall(function()
		return exports.coe_audit:Record('info', 'audit', event, context)
	end)
end

local function notify(playerId, kind, message)
	pcall(function()
		exports.coe_notify:Notify(playerId, kind, message)
	end)
end

local function money(value)
	if Core and Core.Locale and Core.Locale.FormatMoney then
		return Core.Locale.FormatMoney(value, config.Locale or Core.Locale.GetDefaultLang())
	end
	local text = tostring(math.floor(value))
	return config.Currency .. ' ' .. text:reverse():gsub('(%d%d%d)', '%1.'):reverse():gsub('^%.', '')
end

-- Export de outro resource (só o primeiro retorno); nil se o resource não está de pé ou falhou.
local function remote(resource, name, ...)
	if GetResourceState(resource) ~= 'started' then
		return nil
	end
	local args = { ... }
	local ok, result = pcall(function()
		return exports[resource][name](exports[resource], table.unpack(args))
	end)
	if not ok then
		log('warn', 'system', 'bank_remote_failed', { action = resource .. ':' .. name, error_code = tostring(result):sub(1, 96) })
		return nil
	end
	return result
end

local function callDatabase(exportName, ...)
	if GetResourceState('coe_database') ~= 'started' then
		return nil, 'database_error'
	end
	local response = promise.new()
	local database = exports['coe_database']
	local args = { database, ... }
	args[#args + 1] = function(success, result, errorCode)
		response:resolve({ success = success == true, result = result, error = errorCode })
	end
	if not pcall(function() database[exportName](table.unpack(args)) end) then
		return nil, 'database_error'
	end
	local result = Citizen.Await(response)
	if not result.success then
		return nil, 'database_error'
	end
	return result.result
end

-- Jogador e personagem -----------------------------------------------------------------------------------

local function character(playerId)
	local snapshot = Core.Players.GetActiveCharacter(playerId)
	if type(snapshot) ~= 'table' or not snapshot.characterId then
		return nil
	end
	return {
		characterId = tostring(snapshot.characterId),
		stateId = snapshot.stateId,
		name = BankRules.Name(snapshot.firstName, snapshot.lastName) or tostring(snapshot.stateId or '')
	}
end

local function coordsOf(playerId)
	local ped = GetPlayerPed(playerId)
	if not ped or ped == 0 then
		return nil
	end
	local c = GetEntityCoords(ped)
	return { x = c.x, y = c.y, z = c.z }
end

-- Destinatário por ID de cidadão: online pela sessão do coe_core; offline pelo cadastro de personagens.
local function recipient(stateId)
	local session = Core.Players.GetPlayerByStateId(stateId)
	if type(session) == 'table' and type(session.character) == 'table' and session.character.characterId then
		local snapshot = session.character
		return {
			characterId = tostring(snapshot.characterId), stateId = stateId, source = session.source,
			name = BankRules.Name(snapshot.firstName, snapshot.lastName) or stateId
		}
	end
	local rows, errorCode = callDatabase('Query',
		'SELECT character_id, first_name, last_name FROM coe_characters WHERE state_id = ? AND archived_at IS NULL LIMIT 1',
		{ stateId })
	if not rows then
		return nil, errorCode
	end
	local row = rows[1]
	if not row then
		return nil, 'character_not_found'
	end
	return { characterId = tostring(row.character_id), stateId = stateId, name = BankRules.Name(row.first_name, row.last_name) or stateId }
end

-- Dinheiro -------------------------------------------------------------------------------------------------

local function inventoryOf(playerId)
	return remote('coe_inventory', 'GetPlayerInventory', playerId)
end

local function cashOf(inventoryId)
	return inventoryId and tonumber(remote('coe_inventory', 'GetItemCount', inventoryId, 'money')) or 0
end

local function balanceOf(characterId)
	local balance = remote('coe_economy', 'GetBalance', characterId)
	return type(balance) == 'number' and balance or nil
end

-- Saque: debita a conta e entrega espécie; se não couber no inventário, devolve à conta.
local function withdrawCash(playerId, who, amount, reference)
	local inventoryId = inventoryOf(playerId)
	if not inventoryId then
		return 'inventory_full'
	end
	local balance = balanceOf(who.characterId)
	if not balance then
		return 'economy_unavailable'
	end
	if balance < amount then
		return 'insufficient_funds'
	end
	if remote('coe_economy', 'Debit', who.characterId, amount, 'bank_withdraw', reference) ~= true then
		return 'insufficient_funds'
	end
	if remote('coe_inventory', 'AddItem', inventoryId, 'money', amount) ~= true then
		if remote('coe_economy', 'Credit', who.characterId, amount, 'bank_refund', reference) ~= true then
			log('error', 'banking', 'bank_refund_failed', { character_id = who.characterId, count = amount, action = 'withdraw' })
		end
		return 'inventory_full'
	end
	return nil
end

-- Depósito: retira a espécie e credita; se o crédito falhar, devolve a espécie.
local function depositCash(playerId, who, amount, reference)
	local inventoryId = inventoryOf(playerId)
	if not inventoryId or cashOf(inventoryId) < amount then
		return 'insufficient_cash'
	end
	if remote('coe_inventory', 'RemoveItemByName', inventoryId, 'money', amount) ~= true then
		return 'insufficient_cash'
	end
	if remote('coe_economy', 'Credit', who.characterId, amount, 'bank_deposit', reference) ~= true then
		if remote('coe_inventory', 'AddItem', inventoryId, 'money', amount) ~= true then
			log('error', 'banking', 'bank_refund_failed', { character_id = who.characterId, count = amount, action = 'deposit' })
		end
		return 'balance_limit'
	end
	return nil
end

-- Tela -----------------------------------------------------------------------------------------------------

local function view(playerId, who, session)
	local atm = session.mode == 'atm'
	local max = atm and config.MaxAtmAmount or config.MaxAgencyAmount
	return {
		mode = session.mode,
		title = session.title,
		holder = who.name,
		stateId = who.stateId,
		balance = balanceOf(who.characterId),
		cash = cashOf(inventoryOf(playerId)),
		max = max,
		quick = BankRules.Quick(atm and config.AtmQuickAmounts or config.AgencyQuickAmounts, max),
		statement = BankRules.Statement(remote('coe_economy', 'Ledger', who.characterId,
			atm and config.AtmStatementSize or config.StatementSize), atm and config.AtmStatementSize or config.StatementSize)
	}
end

-- Operações ------------------------------------------------------------------------------------------------

local ACTIONS = {}

function ACTIONS.refresh()
	return nil
end

local function maxFor(session)
	return session.mode == 'atm' and config.MaxAtmAmount or config.MaxAgencyAmount
end

local function reference(session)
	return session.mode == 'atm' and 'atm' or ('agency:' .. session.agencyId)
end

function ACTIONS.withdraw(playerId, who, session, data)
	local amount, amountError = BankRules.Amount(data.amount, maxFor(session))
	if not amount then
		return amountError
	end
	local errorCode = withdrawCash(playerId, who, amount, reference(session))
	if errorCode then
		return errorCode
	end
	audit('bank_withdraw', { character_id = who.characterId, count = amount, action = session.mode })
	return nil, _t('withdraw_success', { amount = money(amount) })
end

function ACTIONS.deposit(playerId, who, session, data)
	local amount, amountError = BankRules.Amount(data.amount, maxFor(session))
	if not amount then
		return amountError
	end
	local errorCode = depositCash(playerId, who, amount, reference(session))
	if errorCode then
		return errorCode
	end
	audit('bank_deposit', { character_id = who.characterId, count = amount, action = session.mode })
	return nil, _t('deposit_success', { amount = money(amount) })
end

local function target(who, data)
	local stateId, stateError = BankRules.StateId(data.stateId)
	if not stateId then
		return nil, stateError
	end
	if stateId == who.stateId then
		return nil, 'same_account'
	end
	local found, foundError = recipient(stateId)
	if not found then
		return nil, foundError or 'character_not_found'
	end
	if found.characterId == who.characterId then
		return nil, 'same_account'
	end
	return found
end

-- Confere o destinatário antes de transferir (a tela mostra o nome para confirmar).
function ACTIONS.lookup(_playerId, who, _session, data)
	local found, errorCode = target(who, data)
	if not found then
		return errorCode
	end
	return nil, nil, { stateId = found.stateId, name = found.name }
end

function ACTIONS.transfer(_playerId, who, _session, data)
	local amount, amountError = BankRules.Amount(data.amount, config.MaxAgencyAmount)
	if not amount then
		return amountError
	end
	local found, errorCode = target(who, data)
	if not found then
		return errorCode
	end
	local balance = balanceOf(who.characterId)
	if not balance then
		return 'economy_unavailable'
	end
	if balance < amount then
		return 'insufficient_funds'
	end
	if remote('coe_economy', 'Transfer', who.characterId, found.characterId, amount, 'bank_transfer', 'state:' .. found.stateId) ~= true then
		local after = balanceOf(who.characterId)
		return (after and after < amount) and 'insufficient_funds' or 'balance_limit'
	end
	audit('bank_transfer', { character_id = who.characterId, target = found.characterId, count = amount })
	if found.source then
		notify(found.source, 'info', _t('transfer_received', { amount = money(amount), sender = who.name }))
	end
	return nil, _t('transfer_success', { amount = money(amount), target = found.name })
end

-- Pedidos do client ----------------------------------------------------------------------------------------

local function respond(playerId, requestId, result)
	TriggerClientEvent('coe_bank:response', playerId, requestId, result)
end

local function fail(errorCode)
	return { ok = false, error = errorCode, message = _t(errorCode) ~= errorCode and _t(errorCode) or _t('generic_error') }
end

local function throttled(playerId)
	local now = GetGameTimer()
	if lastAction[playerId] and now - lastAction[playerId] < config.ActionIntervalMs then
		return true
	end
	lastAction[playerId] = now
	return false
end

local function openSession(playerId, payload)
	local at = coordsOf(playerId)
	if not at then
		return nil, 'too_far'
	end
	if payload.mode == 'agency' then
		local agency = BankRules.Agency(config, payload.agencyId)
		if not agency or not BankRules.Near(at, agency, agency.radius + 2.0) then
			return nil, 'too_far'
		end
		return { mode = 'agency', agencyId = agency.id, title = agency.label, at = at }
	end
	if payload.mode == 'atm' then
		local ped = GetPlayerPed(playerId)
		if GetVehiclePedIsIn(ped, false) ~= 0 then
			return nil, 'too_far'
		end
		return { mode = 'atm', title = 'Caixa eletrônico', at = at }
	end
	return nil, 'unavailable'
end

local function stillThere(playerId, session)
	local at = coordsOf(playerId)
	if not BankRules.Near(at, session.at, config.SessionRadius + 1.0) then
		return false
	end
	if session.mode == 'agency' then
		local agency = BankRules.Agency(config, session.agencyId)
		return agency ~= nil and BankRules.Near(at, agency, agency.radius + 2.0)
	end
	return true
end

local function handle(playerId, kind, payload)
	if yieldedBy then
		return fail('unavailable')
	end
	local who = character(playerId)
	if not who then
		return fail('no_character')
	end
	if kind == 'open' then
		local session, errorCode = openSession(playerId, payload)
		if not session then
			return fail(errorCode)
		end
		sessions[playerId] = session
		return { ok = true, view = view(playerId, who, session) }
	end
	local session = sessions[playerId]
	if not session then
		return fail('unavailable')
	end
	if not stillThere(playerId, session) then
		sessions[playerId] = nil
		return fail('too_far')
	end
	local action = type(payload.action) == 'string' and payload.action or ''
	if not BankRules.Allowed(session.mode, action) then
		return fail('unavailable')
	end
	local moves = action == 'withdraw' or action == 'deposit' or action == 'transfer'
	if moves and throttled(playerId) then
		return fail('busy')
	end
	local errorCode, message, data = ACTIONS[action](playerId, who, session, type(payload.data) == 'table' and payload.data or {})
	if errorCode then
		local result = fail(errorCode)
		result.view = view(playerId, who, session)
		return result
	end
	return { ok = true, view = view(playerId, who, session), message = message, data = data }
end

RegisterNetEvent('coe_bank:request', function(requestId, kind, payload)
	local playerId = source
	if type(requestId) ~= 'number' or (kind ~= 'open' and kind ~= 'action') or type(payload) ~= 'table' then
		return
	end
	if busy[playerId] then
		return respond(playerId, requestId, fail('busy'))
	end
	busy[playerId] = true
	local ok, result = pcall(handle, playerId, kind, payload)
	busy[playerId] = nil
	if not ok then
		log('error', 'banking', 'bank_operation_failed', { player_id = playerId, error_code = tostring(result):sub(1, 96) })
		result = fail('database_error')
	end
	respond(playerId, requestId, result)
end)

RegisterNetEvent('coe_bank:closed', function()
	sessions[source] = nil
end)

AddEventHandler('playerDropped', function()
	sessions[source] = nil
	busy[source] = nil
	lastAction[source] = nil
end)

-- Pacote que assume o banco ----------------------------------------------------------------------------------

local function setYield(resource)
	yieldedBy = resource
	GlobalState.coeBankYielded = resource or false
	if resource then
		sessions = {}
		TriggerClientEvent('coe_bank:close', -1)
	end
end

-- Esconde agências, caixas e blips até o resource chamador parar. Valor único: true ou { error }.
exports('Yield', function()
	local caller = GetInvokingResource()
	if not caller or not CoeAccess.Allowed(caller, config.Ace.Yield) then
		return { error = 'forbidden' }
	end
	if yieldedBy ~= caller then
		setYield(caller)
		log('info', 'system', 'bank_yielded', { action = caller })
	end
	return true
end)

-- { active, yieldedBy }: se o banco básico está atendendo.
exports('Status', function()
	return { active = yieldedBy == nil, yieldedBy = yieldedBy }
end)

AddEventHandler('onResourceStop', function(resource)
	if yieldedBy and resource == yieldedBy then
		setYield(nil)
		log('info', 'system', 'bank_resumed', { action = resource })
	end
end)

GlobalState.coeBankYielded = false
