local config = DispatchConfig
-- Chamados só em memória: são efêmeros (TTL). O registro durável fica na auditoria.
local calls, lastCitizenCall = {}, {}
local nextId = 1

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

-- Categoria e negócio em que o jogador está de ponto (ou nil).
local function dutyOf(source)
	local businessId = businessCall('CurrentDuty', source)
	if type(businessId) ~= 'string' then
		return nil
	end
	local business = businessCall('Get', businessId)
	if type(business) ~= 'table' or not config.Categories[business.category] then
		return nil
	end
	return business.category, businessId
end

local function recipients(category)
	local list = {}
	for _, playerId in ipairs(GetPlayers()) do
		local source = tonumber(playerId)
		if dutyOf(source) == category then
			list[#list + 1] = source
		end
	end
	return list
end

local function publicCall(call)
	return {
		id = call.id, code = call.code, label = call.label, category = call.category, priority = call.priority,
		x = call.x, y = call.y, z = call.z, reports = call.reports, createdAt = call.createdAt,
		responders = (function()
			local total = 0
			for _ in pairs(call.responders) do
				total = total + 1
			end
			return total
		end)()
	}
end

local function broadcast(call)
	local payload = publicCall(call)
	for _, source in ipairs(recipients(call.category)) do
		TriggerClientEvent('coe_dispatch:call', source, payload)
	end
end

-- Abre um chamado (ou soma um relato a um igual por perto). Retorna o id ou { error }.
local function open(code, x, y, z, origin)
	local definition, codeError = DispatchRules.Code(config, code)
	if not definition then
		return failure(codeError)
	end
	local coords, coordsError = DispatchRules.Coords(x, y, z)
	if not coords then
		return failure(coordsError)
	end
	local now = os.time()
	local duplicate = DispatchRules.Duplicate(calls, code, coords, now, config)
	if duplicate then
		duplicate.reports = duplicate.reports + 1
		broadcast(duplicate)
		return duplicate.id
	end
	if DispatchRules.CountActive(calls, definition.category) >= config.MaxActivePerCategory then
		return failure('too_many_calls')
	end
	local call = {
		id = nextId, code = code, label = definition.label, category = definition.category, priority = definition.priority,
		x = coords.x, y = coords.y, z = coords.z, reports = 1, createdAt = now, responders = {}, origin = origin
	}
	nextId = nextId + 1
	calls[call.id] = call
	broadcast(call)
	TriggerEvent('coe_dispatch:created', call.id, call.category, call.code, origin)
	audit('dispatch_created', { action = code, source = origin, count = call.id })
	return call.id
end

local function visible(source)
	local category, businessId = dutyOf(source)
	if not category then
		return nil, 'not_on_duty'
	end
	return category, businessId
end

local function accept(source, id)
	local callId, idError = DispatchRules.CallId(id)
	if not callId then
		return failure(idError)
	end
	local category, dutyError = visible(source)
	if not category then
		return failure(dutyError)
	end
	local call = calls[callId]
	if not call or call.category ~= category then
		return failure('unknown_call')
	end
	call.responders[source] = true
	TriggerClientEvent('coe_dispatch:route', source, publicCall(call))
	TriggerEvent('coe_dispatch:accepted', call.id, source)
	return true
end

local function close(source, id)
	local callId, idError = DispatchRules.CallId(id)
	if not callId then
		return failure(idError)
	end
	local category, dutyError = visible(source)
	if not category then
		return failure(dutyError)
	end
	local call = calls[callId]
	if not call or call.category ~= category then
		return failure('unknown_call')
	end
	calls[callId] = nil
	for _, target in ipairs(recipients(category)) do
		TriggerClientEvent('coe_dispatch:clear', target, callId)
	end
	TriggerEvent('coe_dispatch:closed', callId, source)
	audit('dispatch_closed', { source = source, action = call.code, count = callId })
	return true
end

local function listFor(source)
	local category, dutyError = visible(source)
	if not category then
		return failure(dutyError)
	end
	local list = {}
	for _, call in ipairs(DispatchRules.Sorted(calls, category)) do
		list[#list + 1] = publicCall(call)
	end
	return list
end

local function allowed()
	local resource = GetInvokingResource()
	if CoeAccess and CoeAccess.Allowed then
		return CoeAccess.Allowed(resource, config.Ace, config.ActionResources)
	end
	return config.ActionResources[resource or ''] == true
end

-- Alerta automático de outros resources: Alert(code, x, y, z). Retorna o id ou { error }.
exports('Alert', function(code, x, y, z)
	if not allowed() then
		return failure('forbidden')
	end
	return open(code, x, y, z, GetInvokingResource())
end)

exports('Active', function(source)
	if not allowed() then
		return failure('forbidden')
	end
	return listFor(tonumber(source))
end)

exports('Accept', function(source, id)
	return allowed() and accept(tonumber(source), id) or failure('forbidden')
end)

exports('Close', function(source, id)
	return allowed() and close(tonumber(source), id) or failure('forbidden')
end)

local MESSAGES = {
	invalid_code = 'err_invalid_code', invalid_coords = 'err_invalid_coords', too_many_calls = 'err_too_many_calls',
	not_on_duty = 'err_not_on_duty', unknown_call = 'err_unknown_call',
	invalid_call = 'err_invalid_call', cooldown = 'err_cooldown',
	no_character = 'err_no_character', forbidden = 'err_forbidden'
}

local function respond(source, result, successKey)
	if result == true or type(result) == 'number' then
		if successKey and #successKey > 0 then
			notify(source, 'success', _t(successKey))
		end
	elseif type(result) == 'table' and result.error == nil then
		local lines = {}
		for index, call in ipairs(result) do
			if index > 8 then
				break
			end
			lines[#lines + 1] = ('#%d %s (%d)'):format(call.id, call.label, call.priority)
		end
		notify(source, 'info', #lines > 0 and _t('calls_prefix', { list = table.concat(lines, '; ') }) or _t('calls_none'))
	else
		local errCode = type(result) == 'table' and result.error or ''
		local msgKey = MESSAGES[errCode]
		notify(source, 'error', msgKey and _t(msgKey) or _t('generic_error'))
	end
end

-- Cidadão: /chamado <codigo> abre um pedido de ajuda na própria posição.
RegisterCommand('chamado', function(source, args)
	if source == 0 then
		return
	end
	local characterId = Core.Players.GetActiveCharacterId(source)
	if not characterId then
		return respond(source, failure('no_character'))
	end
	local definition, codeError = DispatchRules.Code(config, args[1], true)
	if not definition then
		return respond(source, failure(codeError))
	end
	local now = os.time()
	if not DispatchRules.CooldownReady(lastCitizenCall[source], now, config) then
		return respond(source, failure('cooldown'))
	end
	local ped = GetPlayerPed(source)
	if ped == 0 then
		return respond(source, failure('invalid_coords'))
	end
	local position = Core.Platform.Entities.GetCoords(ped)
	local result = open(args[1], position.x, position.y, position.z, 'citizen')
	if type(result) == 'number' then
		lastCitizenCall[source] = now
	end
	respond(source, result, 'call_sent')
end, false)

RegisterCommand('chamados', function(source)
	if source ~= 0 then
		respond(source, listFor(source))
	end
end, false)

RegisterCommand('atender', function(source, args)
	if source ~= 0 then
		respond(source, accept(source, tonumber(args[1])), 'call_accepted')
	end
end, false)

RegisterCommand('encerrar', function(source, args)
	if source ~= 0 then
		respond(source, close(source, tonumber(args[1])), 'call_closed')
	end
end, false)

AddEventHandler('playerDropped', function()
	local dropped = source
	lastCitizenCall[dropped] = nil
	for _, call in pairs(calls) do
		call.responders[dropped] = nil
	end
end)

CreateThread(function()
	while true do
		Wait(30000)
		for _, id in ipairs(DispatchRules.Prune(calls, os.time(), config)) do
			TriggerClientEvent('coe_dispatch:clear', -1, id)
		end
	end
end)

CreateThread(function()
	Wait(1000)
	log('info', 'system', 'dispatch_ready', {})
end)
