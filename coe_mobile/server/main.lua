-- coe_mobile (servidor): telefone básico do personagem. Número próprio (gerado no primeiro uso), Telefone (ligações
-- com voz pelo coe_talk), Contatos, Mensagens e Ajustes simples. Só funciona com o item do telefone no inventário.
-- Um pacote com smartphone completo assume pelo export Yield (ACE coe.mobile.yield).
local config = MobileConfig
local Store = MobilePersistence

local ready = false
local yieldedBy = nil
local owners = {}      -- playerId -> { characterId, number, name }
local calls = {}       -- chave -> ligação
local inCall = {}      -- playerId -> chave da ligação
local nextCall = 0
local busy = {}
local lastWrite = {}
local lastMessage = {}

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

local function notify(playerId, kind, message)
	pcall(function()
		exports.coe_notify:Notify(playerId, kind, message)
	end)
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
		log('warn', 'system', 'mobile_remote_failed', { action = resource .. ':' .. name, error_code = tostring(result):sub(1, 96) })
		return nil
	end
	return result
end

local function generateNumber()
	return MobileRules.Generate(config, math.random)
end

-- Jogador, personagem e aparelho -----------------------------------------------------------------------------

local function character(playerId)
	local snapshot = Core.Players.GetActiveCharacter(playerId)
	if type(snapshot) ~= 'table' or not snapshot.characterId then
		return nil
	end
	return {
		characterId = tostring(snapshot.characterId),
		name = MobileRules.Name(snapshot.firstName, snapshot.lastName) or tostring(snapshot.stateId or '')
	}
end

local function hasPhone(playerId)
	local inventoryId = remote('coe_inventory', 'GetPlayerInventory', playerId)
	return inventoryId ~= nil and (tonumber(remote('coe_inventory', 'GetItemCount', inventoryId, config.Item)) or 0) > 0
end

-- Dono do aparelho: personagem ativo e o número dele (gerado na primeira vez).
local function owner(playerId)
	local who = character(playerId)
	if not who then
		return nil, 'no_character'
	end
	local cached = owners[playerId]
	if cached and cached.characterId == who.characterId then
		return cached
	end
	local number, errorCode = Store.EnsureNumber(who.characterId, generateNumber)
	if not number then
		return nil, errorCode
	end
	local me = { characterId = who.characterId, number = number, name = who.name }
	owners[playerId] = me
	return me
end

local function playerOfCharacter(characterId)
	characterId = tostring(characterId)
	for playerId, me in pairs(owners) do
		local who = me.characterId == characterId and character(playerId)
		if who and who.characterId == characterId then
			return playerId
		end
	end
	for _, id in ipairs(GetPlayers()) do
		local playerId = tonumber(id)
		local who = playerId and character(playerId)
		if who and who.characterId == characterId then
			return playerId
		end
	end
	return nil
end

-- Agenda do personagem como mapa número -> nome (para dar nome às conversas e ligações).
local function contactNames(characterId)
	local names = {}
	for _, contact in ipairs(Store.Contacts(characterId) or {}) do
		names[contact.number] = contact.name
	end
	return names
end

local function named(list, names)
	for _, entry in ipairs(list) do
		entry.name = names[entry.number]
	end
	return list
end

-- Ligações ---------------------------------------------------------------------------------------------------

local function sideOf(call, playerId)
	if call.caller.playerId == playerId then
		return call.caller, call.callee, 'outgoing'
	end
	return call.callee, call.caller, 'incoming'
end

local function callView(call, playerId)
	local mine, other, direction = sideOf(call, playerId)
	return {
		key = call.key, state = call.state, direction = direction, number = other.number,
		name = mine.label, answeredAt = call.answeredAt, silent = mine.silent
	}
end

local function pushCall(call)
	for _, side in ipairs({ call.caller, call.callee }) do
		TriggerClientEvent('coe_mobile:call', side.playerId, callView(call, side.playerId))
	end
end

-- Encerra a ligação. status vai para o histórico (answered, missed, declined); reason vai para a tela.
local function endCall(call, status, reason)
	if calls[call.key] ~= call then
		return
	end
	calls[call.key] = nil
	local active = call.state == 'active'
	local duration = (active and call.answeredAt) and (os.time() - call.answeredAt) or 0
	for _, side in ipairs({ call.caller, call.callee }) do
		if inCall[side.playerId] == call.key then
			inCall[side.playerId] = nil
		end
		if active then
			remote('coe_talk', 'SetPlayerCall', side.playerId, nil)
		end
		TriggerClientEvent('coe_mobile:call', side.playerId, { key = call.key, state = 'ended', reason = reason })
	end
	if status == 'missed' then
		notify(call.callee.playerId, 'info', _t('missed_call', { name = call.callee.label or call.caller.number }))
	end
	CreateThread(function()
		if not Store.LogCall(call.caller.number, call.callee.number, status, duration) then
			log('warn', 'persistence', 'mobile_call_log_failed', { action = status })
		end
	end)
end

local function endCallOf(playerId, status, reason)
	local key = inCall[playerId]
	local call = key and calls[key]
	if not call then
		inCall[playerId] = nil
		return
	end
	if call.state == 'active' then
		endCall(call, 'answered', 'ended')
	else
		endCall(call, status, reason)
	end
end

local function settingsOf(characterId)
	return MobileRules.Settings(nil, config, Store.Settings(characterId))
end

-- Pedidos ----------------------------------------------------------------------------------------------------

local ACTIONS = {}

function ACTIONS.contacts(_playerId, me)
	local contacts, errorCode = Store.Contacts(me.characterId)
	if not contacts then
		return errorCode
	end
	return nil, nil, { contacts = contacts }
end

function ACTIONS.contact_save(playerId, me, data)
	local name, nameError = MobileRules.ContactName(data.name, config.Contacts.NameMax)
	if not name then
		return nameError
	end
	local number, numberError = MobileRules.Number(data.number, config)
	if not number then
		return numberError
	end
	local id = data.id ~= nil and MobileRules.Id(data.id) or nil
	if data.id ~= nil and not id then
		return 'contact_not_found'
	end
	if not id then
		local total, countError = Store.ContactCount(me.characterId)
		if not total then
			return countError
		end
		if total >= config.Contacts.Max then
			return 'contacts_full'
		end
	end
	local saved, errorCode = Store.SaveContact(me.characterId, id, number, name)
	if not saved then
		return errorCode
	end
	return ACTIONS.contacts(playerId, me)
end

function ACTIONS.contact_delete(playerId, me, data)
	local id = MobileRules.Id(data.id)
	if not id then
		return 'contact_not_found'
	end
	local deleted, errorCode = Store.DeleteContact(me.characterId, id)
	if not deleted then
		return errorCode
	end
	return ACTIONS.contacts(playerId, me)
end

function ACTIONS.threads(_playerId, me)
	local threads, errorCode = Store.Threads(me.number)
	if not threads then
		return errorCode
	end
	return nil, nil, { threads = named(threads, contactNames(me.characterId)) }
end

function ACTIONS.thread(_playerId, me, data)
	local other, numberError = MobileRules.Number(data.number, config)
	if not other then
		return numberError
	end
	local messages, errorCode = Store.Thread(me.number, other)
	if not messages then
		return errorCode
	end
	return nil, nil, { number = other, name = Store.ContactName(me.characterId, other) or nil, messages = messages }
end

function ACTIONS.thread_delete(playerId, me, data)
	local other, numberError = MobileRules.Number(data.number, config)
	if not other then
		return numberError
	end
	local deleted, errorCode = Store.DeleteThread(me.number, other)
	if not deleted then
		return errorCode
	end
	return ACTIONS.threads(playerId, me)
end

function ACTIONS.message_send(playerId, me, data)
	local to, numberError = MobileRules.Number(data.number, config)
	if not to or to == me.number then
		return numberError or 'invalid_number'
	end
	local body, bodyError = MobileRules.Body(data.body, config.Messages.BodyMax)
	if not body then
		return bodyError
	end
	local now = GetGameTimer()
	if lastMessage[playerId] and now - lastMessage[playerId] < config.Messages.CooldownMs then
		return 'busy'
	end
	local target, targetError = Store.CharacterOf(to)
	if target == nil then
		return targetError
	end
	if not target then
		return 'number_not_found'
	end
	local id, errorCode = Store.SendMessage(me.number, to, body)
	if not id then
		return errorCode
	end
	lastMessage[playerId] = now
	local at = os.time()
	local targetPlayer = playerOfCharacter(target)
	if targetPlayer and hasPhone(targetPlayer) then
		TriggerClientEvent('coe_mobile:message', targetPlayer, {
			number = me.number, name = Store.ContactName(target, me.number) or nil, body = body, at = at
		})
	end
	return nil, nil, { message = { id = math.type(id) == 'integer' and id or nil, body = body, at = at, mine = true } }
end

function ACTIONS.recents(_playerId, me)
	local recents, errorCode = Store.Recents(me.number)
	if not recents then
		return errorCode
	end
	return nil, nil, { recents = named(recents, contactNames(me.characterId)) }
end

function ACTIONS.call_start(playerId, me, data)
	if inCall[playerId] then
		return 'already_in_call'
	end
	local number, numberError = MobileRules.Number(data.number, config)
	if not number or number == me.number then
		return numberError or 'invalid_number'
	end
	local target, targetError = Store.CharacterOf(number)
	if target == nil then
		return targetError
	end
	if not target then
		return 'number_not_found'
	end
	local targetPlayer = playerOfCharacter(target)
	local callee = targetPlayer and hasPhone(targetPlayer) and owner(targetPlayer)
	if not callee or callee.characterId ~= target then
		Store.LogCall(me.number, number, 'unreachable', 0)
		return 'unreachable'
	end
	if inCall[targetPlayer] then
		Store.LogCall(me.number, number, 'busy', 0)
		return 'line_busy'
	end
	nextCall = nextCall + 1
	local call = {
		key = nextCall,
		voice = MobileRules.CallId(math.random),
		state = 'ringing',
		caller = { playerId = playerId, number = me.number, label = Store.ContactName(me.characterId, number) or nil },
		callee = {
			playerId = targetPlayer, number = number,
			label = Store.ContactName(target, me.number) or nil,
			silent = settingsOf(target).silent
		}
	}
	-- Dois pedidos podem ter consultado o banco ao mesmo tempo: confere de novo antes de ocupar as linhas.
	if inCall[playerId] or inCall[targetPlayer] then
		return inCall[playerId] and 'already_in_call' or 'line_busy'
	end
	calls[call.key] = call
	inCall[playerId] = call.key
	inCall[targetPlayer] = call.key
	pushCall(call)
	if not call.callee.silent then
		notify(targetPlayer, 'info', _t('incoming_call', { name = call.callee.label or me.number }))
	end
	SetTimeout(config.Calls.RingSeconds * 1000, function()
		if calls[call.key] == call and call.state == 'ringing' then
			endCall(call, 'missed', 'missed')
		end
	end)
	return nil, nil, { call = callView(call, playerId) }
end

local function currentCall(playerId)
	local key = inCall[playerId]
	return key and calls[key] or nil
end

function ACTIONS.call_answer(playerId)
	local call = currentCall(playerId)
	if not call or call.state ~= 'ringing' or call.callee.playerId ~= playerId then
		return 'not_in_call'
	end
	if not hasPhone(playerId) then
		return 'no_phone'
	end
	call.state = 'active'
	call.answeredAt = os.time()
	for _, side in ipairs({ call.caller, call.callee }) do
		if remote('coe_talk', 'SetPlayerCall', side.playerId, call.voice) ~= true then
			log('warn', 'system', 'mobile_voice_failed', { player_id = side.playerId })
		end
	end
	pushCall(call)
	return nil, nil, { call = callView(call, playerId) }
end

function ACTIONS.call_decline(playerId)
	local call = currentCall(playerId)
	if not call or call.state ~= 'ringing' or call.callee.playerId ~= playerId then
		return 'not_in_call'
	end
	endCall(call, 'declined', 'declined')
	return nil
end

function ACTIONS.call_end(playerId)
	local call = currentCall(playerId)
	if not call then
		return 'not_in_call'
	end
	if call.state == 'active' then
		endCall(call, 'answered', 'ended')
	elseif call.caller.playerId == playerId then
		endCall(call, 'missed', 'cancelled')
	else
		endCall(call, 'declined', 'declined')
	end
	return nil
end

function ACTIONS.settings_save(_playerId, me, data)
	local current = Store.Settings(me.characterId)
	if not current then
		return 'database_error'
	end
	local settings = MobileRules.Settings(data, config, current)
	if not Store.SaveSettings(me.characterId, settings) then
		return 'database_error'
	end
	return nil, nil, { settings = settings }
end

function ACTIONS.bank_info(playerId, me)
	local balance = remote('coe_economy', 'GetBalance', me.characterId) or 0
	local cash = 0
	local inv = remote('coe_inventory', 'GetPlayerInventory', playerId)
	if inv then
		cash = remote('coe_inventory', 'GetItemCount', inv, 'money') or 0
	end
	local ledgerRaw = remote('coe_economy', 'Ledger', me.characterId, 10)
	local ledger = {}
	if type(ledgerRaw) == 'table' and not ledgerRaw.error then
		ledger = ledgerRaw
	end
	return nil, nil, {
		balance = balance,
		cash = cash,
		ledger = ledger
	}
end

function ACTIONS.bank_transfer(playerId, me, data)
	local rawTarget = type(data.target) == 'string' and data.target:gsub('%s+', '') or tostring(data.target or '')
	local amount = math.tointeger(tonumber(data.amount))
	if not amount or amount <= 0 then
		return 'invalid_amount'
	end
	if #rawTarget < 1 then
		return 'invalid_target'
	end

	local targetCharId = nil
	local targetPlayerId = nil

	local formattedNumber = MobileRules.Number(rawTarget, config)
	if formattedNumber then
		targetCharId = Store.CharacterOf(formattedNumber)
	end

	if not targetCharId and rawTarget:match('^%d+$') then
		local candidateSource = tonumber(rawTarget)
		if candidateSource and candidateSource > 0 and candidateSource <= 65535 and GetPlayerPing(candidateSource) > 0 then
			local activeChar = Core.Players.GetActiveCharacterId(candidateSource)
			if activeChar then
				targetCharId = activeChar
				targetPlayerId = candidateSource
			end
		end
	end

	if not targetCharId and rawTarget:match('^%d+$') then
		targetCharId = tonumber(rawTarget)
	end

	if not targetCharId then
		return 'recipient_not_found'
	end

	if tostring(targetCharId) == tostring(me.characterId) then
		return 'same_account'
	end

	if not targetPlayerId then
		targetPlayerId = playerOfCharacter(targetCharId)
	end

	local currentBalance = remote('coe_economy', 'GetBalance', me.characterId) or 0
	if currentBalance < amount then
		return 'insufficient_funds'
	end

	local success, err = remote('coe_economy', 'Transfer', me.characterId, targetCharId, amount, 'mobile_pix', 'PIX App')
	if not success then
		return err or 'transfer_failed'
	end

	if targetPlayerId then
		pcall(function()
			exports.coe_notify:Show(targetPlayerId, 'info', _t('pix_received', { amount = amount, sender = me.name }), 6000)
		end)
	end

	local newBalance = remote('coe_economy', 'GetBalance', me.characterId) or 0
	return nil, _t('transfer_success', { amount = amount }), {
		balance = newBalance
	}
end

-- Abertura ---------------------------------------------------------------------------------------------------

local function profile(playerId, me)
	local key = inCall[playerId]
	return {
		number = me.number,
		name = me.name,
		settings = settingsOf(me.characterId),
		unread = Store.UnreadCount(me.number) or 0,
		call = key and calls[key] and callView(calls[key], playerId) or nil,
		limits = {
			bodyMax = config.Messages.BodyMax, nameMax = config.Contacts.NameMax,
			ringtones = config.Settings.Ringtones, wallpapers = config.Settings.Wallpapers,
			prefix = config.Number.Prefix, digits = config.Number.Digits
		}
	}
end

-- Pedidos do client ------------------------------------------------------------------------------------------

local function respond(playerId, requestId, result)
	TriggerClientEvent('coe_mobile:response', playerId, requestId, result)
end

local function fail(errorCode)
	local message = _t(errorCode)
	return { ok = false, error = errorCode, message = message ~= errorCode and message or _t('generic_error') }
end

local function throttled(playerId)
	local now = GetGameTimer()
	if lastWrite[playerId] and now - lastWrite[playerId] < config.ActionIntervalMs then
		return true
	end
	lastWrite[playerId] = now
	return false
end

local function handle(playerId, kind, payload)
	if yieldedBy then
		return fail('unavailable')
	end
	if not ready then
		return fail('not_ready')
	end
	local action = kind == 'open' and 'open' or (type(payload.action) == 'string' and payload.action or '')
	local category = MobileRules.Actions[action]
	if action ~= 'open' and not category then
		return fail('unavailable')
	end
	-- Encerrar ou recusar uma ligação vale mesmo sem o aparelho (ele pode ter saído do inventário).
	if category ~= 'call' and not hasPhone(playerId) then
		return fail('no_phone')
	end
	local me, ownerError = owner(playerId)
	if not me then
		return fail(ownerError == 'no_character' and 'no_character' or 'database_error')
	end
	if action == 'open' then
		return { ok = true, data = profile(playerId, me) }
	end
	if category == 'write' and throttled(playerId) then
		return fail('busy')
	end
	local errorCode, message, data = ACTIONS[action](playerId, me, type(payload.data) == 'table' and payload.data or {})
	if errorCode then
		return fail(errorCode)
	end
	return { ok = true, message = message, data = data }
end

RegisterNetEvent('coe_mobile:request', function(requestId, kind, payload)
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
		log('error', 'system', 'mobile_request_failed', { player_id = playerId, error_code = tostring(result):sub(1, 96) })
		result = fail('database_error')
	end
	respond(playerId, requestId, result)
end)

-- Usar o item abre o telefone.
Core.Events.On('inventory.itemUsed', function(inventoryId, _slot, item)
	local characterId = type(inventoryId) == 'string' and inventoryId:match('^character:(.+)$')
	if not characterId or type(item) ~= 'table' or item.name ~= config.Item or yieldedBy then
		return
	end
	local playerId = playerOfCharacter(characterId)
	if playerId then
		TriggerClientEvent('coe_mobile:use', playerId)
	end
end)

local function release(playerId)
	endCallOf(playerId, 'missed', 'unreachable')
	owners[playerId] = nil
	busy[playerId] = nil
	lastWrite[playerId] = nil
	lastMessage[playerId] = nil
end

Core.Events.On('player.characterUnloaded', function(event)
	if type(event) == 'table' and event.source then
		release(event.source)
		TriggerClientEvent('coe_mobile:close', event.source)
	end
end)

AddEventHandler('playerDropped', function()
	release(source)
end)

-- Pacote que assume o telefone -------------------------------------------------------------------------------

local function setYield(resource)
	yieldedBy = resource
	GlobalState.coeMobileYielded = resource or false
	if resource then
		for _, call in pairs(calls) do
			endCall(call, call.state == 'active' and 'answered' or 'missed', 'unreachable')
		end
		TriggerClientEvent('coe_mobile:close', -1)
	end
end

-- O telefone básico encerra as ligações, fecha as telas e para de abrir até o resource chamador parar.
-- Valor único: true ou { error }.
exports('Yield', function()
	local caller = GetInvokingResource()
	if not caller or not CoeAccess.Allowed(caller, config.Ace.Yield) then
		return { error = 'forbidden' }
	end
	if yieldedBy ~= caller then
		setYield(caller)
		log('info', 'system', 'mobile_yielded', { action = caller })
	end
	return true
end)

-- { active, yieldedBy }: se o telefone básico está atendendo.
exports('Status', function()
	return { active = yieldedBy == nil, yieldedBy = yieldedBy }
end)

-- Número do personagem no telefone básico (nil se ainda não usou o telefone). Não gera número.
exports('NumberOf', function(characterId)
	if characterId == nil or not ready then
		return nil
	end
	return Store.NumberOf(tostring(characterId)) or nil
end)

AddEventHandler('onResourceStop', function(resource)
	if yieldedBy and resource == yieldedBy then
		setYield(nil)
		log('info', 'system', 'mobile_resumed', { action = resource })
	end
end)

GlobalState.coeMobileYielded = false

-- Inicialização: migrações do banco. Pedidos antes disso recebem not_ready.
CreateThread(function()
	local waitingLogged = false
	while true do
		local initialized, errorCode = Store.Initialize()
		if initialized then
			break
		end
		if errorCode == 'database_not_ready' or errorCode == 'database_unavailable' then
			if not waitingLogged then
				log('info', 'persistence', 'database_waiting', {})
				waitingLogged = true
			end
			Wait(1000)
		else
			-- Ex.: coe_database ainda sem o coe_mobile na lista de chamadores (reinicie o coe_database). Tenta de novo.
			log('error', 'persistence', 'mobile_migrations_failed', { error_code = tostring(errorCode) })
			Wait(15000)
		end
	end
	ready = true
end)
