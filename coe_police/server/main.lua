local config = PoliceConfig
local ready = false
-- Estado em memória por jogador. Algema cai ao sair; a pena fica no banco.
local cuffed, jailed, loaded = {}, {}, {}
-- escorts[alvo] = policial que escolta
local escorts = {}

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

local rawLocales = (type(Locales) == 'table' and Locales) or {}
local _t_inst = (Core and Core.Locale and Core.Locale.New) and Core.Locale.New({
	default = (config and config.Locale) or (Core and Core.Locale and Core.Locale.GetDefaultLang()) or 'pt-BR',
	locales = rawLocales
})
local _t = function(k, params)
	if type(_t_inst) == 'table' then
		if _t_inst.T then
			return _t_inst:T(k, params)
		end
		local lang = _t_inst.lang or 'pt-BR'
		local dict = (_t_inst.locales and _t_inst.locales[lang]) or rawLocales[lang] or rawLocales['pt-BR']
		if dict and dict[k] then
			return dict[k]
		end
	elseif type(_t_inst) == 'function' then
		return _t_inst(k, params)
	end
	return (rawLocales['pt-BR'] and rawLocales['pt-BR'][k]) or k
end

local function failure(code)
	return { error = code }
end

local function businessCall(name, ...)
	if GetResourceState('coe_businesses') ~= 'started' then
		return nil
	end
	local args = { ... }
	local ok, result = pcall(function()
		return exports.coe_businesses[name](exports.coe_businesses, table.unpack(args))
	end)
	return ok and result or nil
end

local function characterOf(source)
	local id = Core.Players.GetActiveCharacterId(source)
	return id and tostring(id) or nil
end

-- Policial: personagem ativo, de ponto em um negócio police e com a permissão de cargo.
local function officer(source, permission)
	local characterId = characterOf(source)
	if not characterId then
		return nil, 'no_character'
	end
	local businessId = businessCall('CurrentDuty', source)
	local business = type(businessId) == 'string' and businessCall('Get', businessId) or nil
	if type(business) ~= 'table' then
		return nil, 'not_on_duty'
	end
	if business.category ~= 'police' then
		return nil, 'not_police'
	end
	if businessCall('Can', businessId, characterId, permission) ~= true then
		return nil, 'forbidden'
	end
	return { characterId = characterId, businessId = businessId }
end

local function distanceBetween(a, b)
	local pa, pb = GetPlayerPed(a), GetPlayerPed(b)
	if pa == 0 or pb == 0 then
		return nil
	end
	return #(Core.Platform.Entities.GetCoords(pa) - Core.Platform.Entities.GetCoords(pb))
end

local PERMISSION = {
	cuff = 'police.cuff', uncuff = 'police.cuff', fine = 'police.fine', jail = 'police.jail',
	search = 'police.search', seize = 'police.seize', escort = 'police.escort'
}

-- Valida policial, alvo, estado e distância. Retorna { officer, targetId } ou nil, codigo.
local function prepare(action, officerSource, targetSource)
	officerSource, targetSource = tonumber(officerSource), tonumber(targetSource)
	if not ready then
		return nil, 'not_ready'
	end
	if not officerSource or not targetSource or GetPlayerName(targetSource) == nil then
		return nil, 'unknown_target'
	end
	local cop, copError = officer(officerSource, PERMISSION[action])
	if not cop then
		return nil, copError
	end
	local targetId = characterOf(targetSource)
	if not targetId then
		return nil, 'unknown_target'
	end
	if targetId == cop.characterId then
		return nil, 'same_character'
	end
	local allowed, stateError = PoliceRules.CanApply(action, cuffed[targetSource] == true, jailed[targetSource] ~= nil)
	if not allowed then
		return nil, stateError
	end
	if not PoliceRules.InRange(distanceBetween(officerSource, targetSource), config) then
		return nil, 'too_far'
	end
	return { officer = cop, targetId = targetId, officerSource = officerSource, targetSource = targetSource }
end

local function stopEscort(targetSource)
	if escorts[targetSource] then
		escorts[targetSource] = nil
		TriggerClientEvent('coe_police:escort', targetSource, nil)
	end
end

local function setCuffed(source, value)
	cuffed[source] = value or nil
	if not value then
		stopEscort(source)
	end
	TriggerClientEvent('coe_police:cuffed', source, value == true)
end

local function cuff(action, officerSource, targetSource)
	local ctx, errorCode = prepare(action, officerSource, targetSource)
	if not ctx then
		return failure(errorCode)
	end
	local on = action == 'cuff'
	setCuffed(ctx.targetSource, on)
	TriggerEvent('coe_police:cuffChanged', ctx.officerSource, ctx.targetSource, on, ctx.officer.businessId)
	audit('police_' .. action, { character_id = ctx.officer.characterId, target = ctx.targetId, action = ctx.officer.businessId })
	return true
end

local function fine(officerSource, targetSource, amount, charge)
	local value, amountError = PoliceRules.Fine(amount, config)
	if not value then
		return failure(amountError)
	end
	local cleanCharge, chargeError = PoliceRules.Charge(charge)
	if not cleanCharge then
		return failure(chargeError)
	end
	local ctx, errorCode = prepare('fine', officerSource, targetSource)
	if not ctx then
		return failure(errorCode)
	end
	-- Retornos múltiplos se perdem entre resources: confere o saldo antes para dar o motivo certo.
	local ok, balance = pcall(function()
		return exports.coe_economy:GetBalance(ctx.targetId)
	end)
	if not ok or type(balance) ~= 'number' then
		return failure('economy_unavailable')
	end
	if balance < value then
		return failure('insufficient_funds')
	end
	local debited = pcall(function()
		return exports.coe_economy:Debit(ctx.targetId, value, 'police_fine', 'police:' .. ctx.officer.businessId)
	end)
	if not debited then
		return failure('economy_unavailable')
	end
	local afterOk, after = pcall(function()
		return exports.coe_economy:GetBalance(ctx.targetId)
	end)
	if not afterOk or type(after) ~= 'number' or after > balance - value then
		return failure('payment_failed')
	end
	if not PolicePersistence.AddRecord(ctx.targetId, ctx.officer.characterId, ctx.officer.businessId, 'fine', cleanCharge, value, nil) then
		log('error', 'records', 'fine_record_failed', { character_id = ctx.targetId, count = value })
	end
	if config.FinesToSociety then
		local collected = false
		pcall(function()
			local result = exports.coe_economy:SocietyCollect(ctx.officer.businessId, value, 'police_fine')
			collected = result == true
		end)
		if not collected then
			log('warn', 'economy', 'fine_not_collected', { action = ctx.officer.businessId, count = value })
		end
	end
	TriggerEvent('coe_police:fined', ctx.officerSource, ctx.targetSource, value, cleanCharge, ctx.officer.businessId)
	audit('police_fine', { character_id = ctx.officer.characterId, target = ctx.targetId, action = cleanCharge, count = value })
	notify(ctx.targetSource, 'info', _t('fine_received'))
	return true
end

local function startSentence(source, characterId, releaseAt)
	jailed[source] = { characterId = characterId, releaseAt = releaseAt }
	setCuffed(source, false)
	local place = config.Jail
	TriggerClientEvent('coe_police:jail', source, place.x, place.y, place.z, place.heading, place.radius)
end

local function arrest(officerSource, targetSource, minutes, charge)
	local total, minutesError = PoliceRules.Minutes(minutes, config)
	if not total then
		return failure(minutesError)
	end
	local cleanCharge, chargeError = PoliceRules.Charge(charge)
	if not cleanCharge then
		return failure(chargeError)
	end
	local ctx, errorCode = prepare('jail', officerSource, targetSource)
	if not ctx then
		return failure(errorCode)
	end
	local releaseAt = PoliceRules.ReleaseAt(os.time(), total)
	if not PolicePersistence.SetSentence(ctx.targetId, releaseAt) then
		return failure('database_error')
	end
	if not PolicePersistence.AddRecord(ctx.targetId, ctx.officer.characterId, ctx.officer.businessId, 'arrest', cleanCharge, nil, total) then
		log('error', 'records', 'arrest_record_failed', { character_id = ctx.targetId })
	end
	startSentence(ctx.targetSource, ctx.targetId, releaseAt)
	TriggerEvent('coe_police:arrested', ctx.officerSource, ctx.targetSource, total, cleanCharge, ctx.officer.businessId)
	audit('police_arrest', { character_id = ctx.officer.characterId, target = ctx.targetId, action = cleanCharge, count = total })
	notify(ctx.targetSource, 'error', _t('jailed_notify', { minutes = total }))
	return true
end

local function release(source)
	local entry = jailed[source]
	if not entry then
		return
	end
	jailed[source] = nil
	PolicePersistence.ClearSentence(entry.characterId)
	local place = config.Release
	TriggerClientEvent('coe_police:release', source, place.x, place.y, place.z, place.heading)
	TriggerEvent('coe_police:released', source, entry.characterId)
	notify(source, 'success', _t('released_notify'))
end

local function allowed()
	return config.ActionResources[GetInvokingResource() or ''] == true
end

local function inventoryId(characterId)
	return 'character:' .. characterId
end

-- Revista: só de alvo algemado; lista nome/rótulo/quantidade. Fica na auditoria e o alvo é avisado.
local function search(officerSource, targetSource)
	local ctx, errorCode = prepare('search', officerSource, targetSource)
	if not ctx then
		return failure(errorCode)
	end
	local ok, snapshot = pcall(function()
		return exports.coe_inventory:GetInventory(inventoryId(ctx.targetId))
	end)
	if not ok or type(snapshot) ~= 'table' then
		return failure('inventory_unavailable')
	end
	local list = PoliceRules.SearchList(snapshot, config.SearchLimit)
	audit('police_search', { character_id = ctx.officer.characterId, target = ctx.targetId, action = ctx.officer.businessId, count = #list })
	notify(ctx.targetSource, 'info', _t('searched_notify'))
	return list
end

-- Apreensão: tira do alvo algemado e entrega ao policial; se o policial não puder carregar, devolve.
local function seize(officerSource, targetSource, slot, count)
	local cleanSlot, cleanCount = PoliceRules.Seizure(slot, count)
	if not cleanSlot then
		return failure(cleanCount)
	end
	local ctx, errorCode = prepare('seize', officerSource, targetSource)
	if not ctx then
		return failure(errorCode)
	end
	local targetInventory, officerInventory = inventoryId(ctx.targetId), inventoryId(ctx.officer.characterId)
	local okSlot, item = pcall(function()
		return exports.coe_inventory:GetSlot(targetInventory, cleanSlot)
	end)
	if not okSlot or type(item) ~= 'table' or type(item.name) ~= 'string' or item.count < cleanCount then
		return failure('insufficient_items')
	end
	local removeOk, removed = pcall(function()
		return exports.coe_inventory:RemoveItem(targetInventory, cleanSlot, cleanCount)
	end)
	if not removeOk or removed ~= true then
		return failure('inventory_unavailable')
	end
	local addOk, added = pcall(function()
		return exports.coe_inventory:AddItem(officerInventory, item.name, cleanCount, item.metadata)
	end)
	if not addOk or added ~= true then
		local restored = pcall(function()
			return exports.coe_inventory:AddItem(targetInventory, item.name, cleanCount, item.metadata, cleanSlot)
		end)
		if not restored then
			log('error', 'inventory', 'seize_restore_failed', { character_id = ctx.targetId, item = item.name, count = cleanCount })
		end
		return failure('officer_inventory_full')
	end
	audit('police_seize', { character_id = ctx.officer.characterId, target = ctx.targetId, action = item.name, count = cleanCount })
	TriggerEvent('coe_police:seized', ctx.officerSource, ctx.targetSource, item.name, cleanCount, ctx.officer.businessId)
	return true
end

-- Escolta alterna: o alvo algemado passa a seguir o policial.
local function escort(officerSource, targetSource)
	local target = tonumber(targetSource)
	if target and escorts[target] == tonumber(officerSource) then
		local cop, copError = officer(tonumber(officerSource), 'police.escort')
		if not cop then
			return failure(copError)
		end
		stopEscort(target)
		TriggerEvent('coe_police:escortChanged', tonumber(officerSource), target, false, cop.businessId)
		return true
	end
	local ctx, errorCode = prepare('escort', officerSource, targetSource)
	if not ctx then
		return failure(errorCode)
	end
	if escorts[ctx.targetSource] then
		return failure('already_escorted')
	end
	escorts[ctx.targetSource] = ctx.officerSource
	TriggerClientEvent('coe_police:escort', ctx.targetSource, ctx.officerSource)
	TriggerEvent('coe_police:escortChanged', ctx.officerSource, ctx.targetSource, true, ctx.officer.businessId)
	audit('police_escort', { character_id = ctx.officer.characterId, target = ctx.targetId, action = ctx.officer.businessId })
	return true
end

exports('IsEscorted', function(source)
	return escorts[tonumber(source)] ~= nil
end)

exports('Search', function(officerSource, targetSource)
	return allowed() and search(officerSource, targetSource) or failure('forbidden')
end)

exports('Seize', function(officerSource, targetSource, slot, count)
	return allowed() and seize(officerSource, targetSource, slot, count) or failure('forbidden')
end)

exports('Escort', function(officerSource, targetSource)
	return allowed() and escort(officerSource, targetSource) or failure('forbidden')
end)

exports('IsCuffed', function(source)
	return cuffed[tonumber(source)] == true
end)

exports('IsJailed', function(source)
	return jailed[tonumber(source)] ~= nil
end)

exports('Cuff', function(officerSource, targetSource)
	return allowed() and cuff('cuff', officerSource, targetSource) or failure('forbidden')
end)

exports('Uncuff', function(officerSource, targetSource)
	return allowed() and cuff('uncuff', officerSource, targetSource) or failure('forbidden')
end)

exports('Fine', function(officerSource, targetSource, amount, charge)
	return allowed() and fine(officerSource, targetSource, amount, charge) or failure('forbidden')
end)

exports('Arrest', function(officerSource, targetSource, minutes, charge)
	return allowed() and arrest(officerSource, targetSource, minutes, charge) or failure('forbidden')
end)

-- Ficha criminal de um personagem: exige police.records em um negócio police de ponto.
exports('Records', function(officerSource, subjectCharacterId, limit)
	if not allowed() then
		return failure('forbidden')
	end
	local cop, copError = officer(tonumber(officerSource), 'police.records')
	if not cop then
		return failure(copError)
	end
	local subject = tostring(subjectCharacterId or '')
	if not subject:match('^%d+$') or #subject > 18 then
		return failure('invalid_character')
	end
	local rows, rowsError = PolicePersistence.Records(subject, math.min(math.max(tonumber(limit) or 20, 1), config.Limits.MaxRecords))
	return rows or failure(rowsError)
end)

local MESSAGES = {
	no_character = 'err_no_character', not_on_duty = 'err_not_on_duty',
	not_police = 'err_not_police', forbidden = 'err_forbidden',
	unknown_target = 'err_unknown_target', same_character = 'err_same_character',
	already_cuffed = 'err_already_cuffed', not_cuffed = 'err_not_cuffed',
	already_jailed = 'err_already_jailed', too_far = 'err_too_far', not_ready = 'err_not_ready',
	insufficient_funds = 'err_insufficient_funds', invalid_amount = 'err_invalid_amount',
	invalid_sentence = 'err_invalid_sentence', invalid_charge = 'err_invalid_charge',
	economy_unavailable = 'err_economy_unavailable', payment_failed = 'err_payment_failed',
	database_error = 'err_database_error', inventory_unavailable = 'err_inventory_unavailable',
	invalid_slot = 'err_invalid_slot', invalid_count = 'err_invalid_count',
	insufficient_items = 'err_insufficient_items', officer_inventory_full = 'err_officer_inventory_full',
	already_escorted = 'err_already_escorted'
}

local function respond(source, result, successKey)
	if result == true then
		if successKey and #successKey > 0 then
			notify(source, 'success', _t(successKey))
		end
	elseif type(result) == 'table' and result.error == nil then
		local lines = {}
		for _, item in ipairs(result) do
			lines[#lines + 1] = ('[%d] %s x%d'):format(item.slot, item.label, item.count)
		end
		notify(source, 'info', #lines > 0 and _t('search_prefix', { items = table.concat(lines, ', ') }) or _t('search_empty'))
	else
		local errCode = type(result) == 'table' and result.error or ''
		local msgKey = MESSAGES[errCode]
		notify(source, 'error', msgKey and _t(msgKey) or _t('generic_error'))
	end
end

RegisterCommand('revistar', function(source, args)
	if source ~= 0 then
		respond(source, search(source, args[1]), '')
	end
end, false)

RegisterCommand('apreender', function(source, args)
	if source ~= 0 then
		respond(source, seize(source, args[1], tonumber(args[2]), tonumber(args[3])), 'item_seized')
	end
end, false)

RegisterCommand('escoltar', function(source, args)
	if source ~= 0 then
		respond(source, escort(source, args[1]), 'escort_updated')
	end
end, false)

RegisterCommand('algemar', function(source, args)
	if source ~= 0 then
		respond(source, cuff('cuff', source, args[1]), 'cuffed_success')
	end
end, false)

RegisterCommand('soltar', function(source, args)
	if source ~= 0 then
		respond(source, cuff('uncuff', source, args[1]), 'uncuffed_success')
	end
end, false)

RegisterCommand('multar', function(source, args)
	if source ~= 0 then
		respond(source, fine(source, args[1], tonumber(args[2]), args[3]), 'fine_applied')
	end
end, false)

RegisterCommand('prender', function(source, args)
	if source ~= 0 then
		respond(source, arrest(source, args[1], tonumber(args[2]), args[3]), 'jailed_success')
	end
end, false)

AddEventHandler('playerDropped', function()
	local dropped = source
	cuffed[dropped], jailed[dropped], loaded[dropped] = nil, nil, nil
	escorts[dropped] = nil
	for target, copSource in pairs(escorts) do
		if copSource == dropped then
			stopEscort(target)
		end
	end
end)

local function registerPermissions()
	if GetResourceState('coe_businesses') ~= 'started' then
		return false
	end
	return businessCall('RegisterPermissions', config.Permissions) == true
end

AddEventHandler('onResourceStart', function(name)
	if name == 'coe_businesses' then
		SetTimeout(2000, registerPermissions)
	end
end)

CreateThread(function()
	local waitingLogged = false
	while true do
		local initialized, errorCode = PolicePersistence.Initialize()
		if initialized then
			break
		end
		if errorCode == 'database_not_ready' then
			if not waitingLogged then
				log('info', 'persistence', 'database_waiting', {})
				waitingLogged = true
			end
			Wait(1000)
		else
			log('error', 'persistence', 'database_initialization_failed', { error_code = errorCode or 'database_error', retry_ms = 5000 })
			Wait(5000)
		end
	end
	ready = true
	for _ = 1, 30 do
		if registerPermissions() then
			break
		end
		Wait(2000)
	end
	log('info', 'system', 'police_ready', {})
end)

-- Escolta cai quando o policial perde o alvo de vista ou sai de serviço.
CreateThread(function()
	while true do
		Wait(2000)
		for target, copSource in pairs(escorts) do
			local distance = distanceBetween(copSource, target)
			if not distance or distance > config.EscortMaxDistance or cuffed[target] ~= true or businessCall('CurrentDuty', copSource) == nil then
				stopEscort(target)
				TriggerEvent('coe_police:escortChanged', copSource, target, false, nil)
			end
		end
	end
end)

-- Pena e soltura: quem entra com um personagem que ainda tem pena volta para a cela; a pena acabada solta o preso.
CreateThread(function()
	while true do
		Wait(5000)
		if ready then
			local now = os.time()
			for _, playerId in ipairs(GetPlayers()) do
				local source = tonumber(playerId)
				local characterId = characterOf(source)
				if characterId and loaded[source] ~= characterId then
					loaded[source] = characterId
					local releaseAt = PolicePersistence.Sentence(characterId)
					if releaseAt and not jailed[source] then
						if PoliceRules.Remaining(releaseAt, now) > 0 then
							startSentence(source, characterId, releaseAt)
						else
							PolicePersistence.ClearSentence(characterId)
						end
					end
				end
			end
			for source, entry in pairs(jailed) do
				if PoliceRules.Remaining(entry.releaseAt, now) == 0 then
					release(source)
				end
			end
		end
	end
end)
