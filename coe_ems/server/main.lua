local config = EmsConfig
local ready = false
-- Estado em memória por jogador: { characterId, state, since }. Cai ao sair do servidor.
local patients = {}
local lastReport = {}

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

local _t = (Core and Core.Locale and Core.Locale.Bind) and Core.Locale.Bind(Locales) or function(k) return (Locales and Locales['pt-BR'] and Locales['pt-BR'][k]) or k end

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

local function stateOf(source)
	local entry = patients[source]
	return entry and entry.state or 'healthy'
end

local function setState(source, state)
	local characterId = characterOf(source)
	if not characterId or not EmsRules.States[state] then
		return false
	end
	local from = stateOf(source)
	if from == state then
		return true
	end
	patients[source] = { characterId = characterId, state = state, since = os.time() }
	TriggerClientEvent('coe_ems:state', source, state)
	TriggerEvent('coe_ems:stateChanged', source, characterId, from, state)
	if state == 'unconscious' then
		notify(source, 'error', _t('unconscious_notify'))
		-- Alerta opcional ao despacho; sem o resource, o EMS segue funcionando.
		local ped = GetPlayerPed(source)
		if ped ~= 0 and GetResourceState('coe_dispatch') == 'started' then
			local position = Core.Platform.Entities.GetCoords(ped)
			pcall(function()
				return exports.coe_dispatch:Alert('person_down', position.x, position.y, position.z)
			end)
		end
	elseif state == 'dead' then
		notify(source, 'error', _t('dead_notify'))
	end
	return true
end

-- Vários retornos se perdem entre resources: valor único ou { error = codigo }.
local function failure(code)
	return { error = code }
end

-- Médico: personagem ativo, de ponto em um negócio ems e com a permissão de cargo.
local function medic(source, permission)
	local characterId = characterOf(source)
	if not characterId then
		return nil, 'no_character'
	end
	local businessId = businessCall('CurrentDuty', source)
	local business = type(businessId) == 'string' and businessCall('Get', businessId) or nil
	if type(business) ~= 'table' then
		return nil, 'not_on_duty'
	end
	if business.category ~= 'ems' then
		return nil, 'not_ems'
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

local function hospital()
	for _, business in ipairs(businessCall('List', 'ems') or {}) do
		local area = business.area
		if business.enabled ~= false and type(area) == 'table' and area.kind == 'circle' and area.x then
			return { x = area.x, y = area.y, z = area.z, heading = 0.0 }
		end
	end
	return config.Respawn
end

local ACTION_PERMISSION = { revive = 'ems.revive', treat = 'ems.treat' }

local function act(action, medicSource, targetSource, detail)
	local cleanDetail, detailError = EmsRules.Detail(detail)
	if not cleanDetail then
		return failure(detailError)
	end
	targetSource = tonumber(targetSource)
	if not ready or not targetSource or GetPlayerName(targetSource) == nil then
		return failure(ready and 'unknown_patient' or 'not_ready')
	end
	local doctor, doctorError = medic(medicSource, ACTION_PERMISSION[action])
	if not doctor then
		return failure(doctorError)
	end
	local patientId = characterOf(targetSource)
	if not patientId then
		return failure('unknown_patient')
	end
	if patientId == doctor.characterId then
		return failure('same_character')
	end
	local allowed, stateError = EmsRules.CanApply(action, stateOf(targetSource), config)
	if not allowed then
		return failure(stateError)
	end
	if not EmsRules.InRange(distanceBetween(medicSource, targetSource), config) then
		return failure('too_far')
	end
	local saved, saveError = EmsPersistence.AddRecord(patientId, doctor.characterId, doctor.businessId, action, cleanDetail)
	if not saved then
		return failure(saveError)
	end
	setState(targetSource, EmsRules.Outcome[action])
	TriggerClientEvent(action == 'revive' and 'coe_ems:revive' or 'coe_ems:heal', targetSource)
	TriggerEvent('coe_ems:treated', medicSource, targetSource, action, doctor.businessId)
	audit('ems_' .. action, { character_id = doctor.characterId, target = patientId, action = doctor.businessId })
	notify(targetSource, 'success', action == 'revive' and _t('revived') or _t('treated'))
	return true
end

exports('State', function(source)
	return stateOf(tonumber(source))
end)

-- coe_needs, coe_hud e coe_admin podem definir o estado (ex.: dano vindo de outro sistema).
exports('SetState', function(source, state)
	if config.StateResources[GetInvokingResource() or ''] ~= true then
		return failure('forbidden')
	end
	return setState(tonumber(source), state) or failure('invalid_state')
end)

exports('Revive', function(medicSource, targetSource, detail)
	if config.ActionResources[GetInvokingResource() or ''] ~= true then
		return failure('forbidden')
	end
	return act('revive', tonumber(medicSource), targetSource, detail)
end)

exports('Treat', function(medicSource, targetSource, detail)
	if config.ActionResources[GetInvokingResource() or ''] ~= true then
		return failure('forbidden')
	end
	return act('treat', tonumber(medicSource), targetSource, detail)
end)

-- Prontuário de um paciente (personagem): exige o cargo com ems.records em um negócio ems de ponto.
exports('Records', function(medicSource, patientCharacterId, limit)
	if config.ActionResources[GetInvokingResource() or ''] ~= true then
		return failure('forbidden')
	end
	local doctor, doctorError = medic(tonumber(medicSource), 'ems.records')
	if not doctor then
		return failure(doctorError)
	end
	local patient = tostring(patientCharacterId or '')
	if not patient:match('^%d+$') or #patient > 18 then
		return failure('invalid_character')
	end
	local rows, rowsError = EmsPersistence.Records(patient, math.min(math.max(tonumber(limit) or 20, 1), config.Limits.MaxRecords))
	return rows or failure(rowsError)
end)

local MESSAGES = {
	no_character = 'err_no_character', not_on_duty = 'err_not_on_duty',
	not_ems = 'err_not_ems', forbidden = 'err_forbidden',
	unknown_patient = 'err_unknown_patient', same_character = 'err_same_character',
	invalid_state = 'err_invalid_state', too_far = 'err_too_far',
	not_ready = 'err_not_ready', database_error = 'err_database_error'
}

local function command(name, action)
	RegisterCommand(name, function(source, args)
		if source == 0 then
			return
		end
		local result = act(action, source, args[1], nil)
		if result ~= true then
			local errCode = type(result) == 'table' and result.error or ''
			local msgKey = MESSAGES[errCode]
			notify(source, 'error', msgKey and _t(msgKey) or _t('generic_error'))
		end
	end, false)
end

command('reanimar', 'revive')
command('tratar', 'treat')

-- Quem morreu e não foi socorrido volta ao hospital.
RegisterCommand('respawn', function(source)
	if source == 0 or not ready then
		return
	end
	if not EmsRules.CanApply('respawn', stateOf(source), config) then
		return notify(source, 'error', _t('respawn_only_dead'))
	end
	local characterId = characterOf(source)
	EmsPersistence.AddRecord(characterId, nil, nil, 'respawn', '')
	setState(source, 'healthy')
	local place = hospital()
	TriggerClientEvent('coe_ems:respawn', source, place.x, place.y, place.z, place.heading or 0.0)
	TriggerEvent('coe_ems:treated', nil, source, 'respawn', nil)
end, false)

-- O cliente reporta ferido/inconsciente; o servidor só aceita as transições de CanReport.
RegisterNetEvent('coe_ems:report', function(state)
	local source = source
	if type(state) ~= 'string' or not ready then
		return
	end
	local now = GetGameTimer()
	if lastReport[source] and now - lastReport[source] < 1000 then
		return
	end
	lastReport[source] = now
	if EmsRules.CanReport(stateOf(source), state) then
		setState(source, state)
	end
end)

AddEventHandler('playerDropped', function()
	patients[source], lastReport[source] = nil, nil
end)

local function registerPermissions()
	if GetResourceState('coe_businesses') ~= 'started' then
		return false
	end
	local result = businessCall('RegisterPermissions', config.Permissions)
	return result == true
end

AddEventHandler('onResourceStart', function(name)
	if name == 'coe_businesses' then
		SetTimeout(2000, registerPermissions)
	end
end)

CreateThread(function()
	local waitingLogged = false
	while true do
		local initialized, errorCode = EmsPersistence.Initialize()
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
	log('info', 'system', 'ems_ready', {})
end)

-- Sangramento: inconsciente sem socorro vira óbito.
CreateThread(function()
	while true do
		Wait(5000)
		local now = os.time()
		for source, entry in pairs(patients) do
			if entry.state == 'unconscious' and EmsRules.BledOut(entry.since, now, config) then
				setState(source, 'dead')
			end
		end
	end
end)
