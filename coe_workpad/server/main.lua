-- coe_workpad (servidor): tablet de trabalho básico. Hospeda os apps de trabalho do framework (Carreira do coe_jobs e
-- um app por negócio do coe_businesses) e os próprios Ponto e Empregos livres. Só abre com o item no inventário.
-- O servidor monta a lista de apps, revalida o acesso a cada ação e encaminha para o resource do app.
-- Um pacote com tablet completo assume pelo export Yield (ACE coe.workpad.yield).
local config = WorkpadConfig

local yieldedBy = nil
local lastCall = {}
local lastOpen = {}
local dutySince = {}   -- playerId -> { businessId, at } (início do ponto visto por este resource)

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

local function started(resource)
	return GetResourceState(resource) == 'started'
end

-- Export de outro resource (só o primeiro retorno); nil se o resource não está de pé ou falhou.
local function remote(resource, name, ...)
	if not started(resource) then
		return nil
	end
	local args = table.pack(...)
	local ok, result = pcall(function()
		return exports[resource][name](exports[resource], table.unpack(args, 1, args.n))
	end)
	if not ok then
		log('warn', 'system', 'workpad_remote_failed', { action = resource .. ':' .. name, error_code = tostring(result):sub(1, 96) })
		return nil
	end
	return result
end

local function characterOf(playerId)
	local snapshot = Core.Players.GetActiveCharacter(playerId)
	return type(snapshot) == 'table' and snapshot.characterId and tostring(snapshot.characterId) or nil
end

local function hasTablet(playerId)
	local inventoryId = remote('coe_inventory', 'GetPlayerInventory', playerId)
	return inventoryId ~= nil and (tonumber(remote('coe_inventory', 'GetItemCount', inventoryId, config.Item)) or 0) > 0
end

local function profileOf(playerId)
	return WorkpadRules.Resolve(config, {
		started = started,
		instances = function(app)
			local list = remote(app.resource, 'TabletInstances', playerId)
			return type(list) == 'table' and list or nil
		end
	})
end

-- Apps deste resource ------------------------------------------------------------------------------------------

local NATIVE = { duty = {}, freejobs = {} }

local function dutyView(playerId, characterId)
	local entries = {}
	for _, business in ipairs(remote('coe_businesses', 'List') or {}) do
		local access = remote('coe_businesses', 'Access', business.id, characterId)
		if type(access) == 'table' and (access.owner or access.staff) then
			entries[#entries + 1] = {
				business = business, access = access,
				grade = not access.owner and remote('coe_businesses', 'GradeOf', business.id, characterId) or nil
			}
		end
	end
	local current = remote('coe_businesses', 'CurrentDuty', playerId)
	local since = dutySince[playerId]
	local at = (since and since.businessId == current) and since.at or nil
	return WorkpadRules.Workplaces(config, entries, current, at, os.time())
end

function NATIVE.duty.overview(playerId, characterId)
	if not started('coe_businesses') then
		return { ok = false, error = 'app_unavailable' }
	end
	return { ok = true, data = dutyView(playerId, characterId) }
end

function NATIVE.duty.clockOut(playerId, characterId)
	local current = remote('coe_businesses', 'CurrentDuty', playerId)
	if not current then
		return { ok = false, error = 'not_on_duty' }
	end
	local result = remote('coe_businesses', 'ClockOut', playerId, 'clock_out')
	if type(result) == 'table' and result.error then
		return { ok = false, error = result.error }
	end
	if result == nil then
		return { ok = false, error = 'app_unavailable' }
	end
	log('info', 'gameplay', 'workpad_clock_out', { player_id = playerId, target = current })
	return { ok = true, data = dutyView(playerId, characterId) }
end

function NATIVE.freejobs.list(playerId, characterId)
	if not started('coe_jobs') then
		return { ok = false, error = 'app_unavailable' }
	end
	local session = remote('coe_jobs', 'GetSession', playerId)
	local working = type(session) == 'table' and session.jobId or nil
	return {
		ok = true,
		data = {
			jobs = WorkpadRules.FreeJobs(remote('coe_jobs', 'ListJobs'), remote('coe_jobs', 'GetCareer', characterId), working)
		}
	}
end

local function nativeCall(playerId, appId, action)
	local handler = NATIVE[appId] and NATIVE[appId][action]
	if not handler then
		return { ok = false, error = 'invalid_action' }
	end
	local characterId = characterOf(playerId)
	if not characterId then
		return { ok = false, error = 'no_character' }
	end
	return handler(playerId, characterId)
end

-- Abrir e chamar -----------------------------------------------------------------------------------------------

local function reply(playerId, requestId, result)
	TriggerClientEvent('coe_workpad:result', playerId, requestId, result)
end

RegisterNetEvent('coe_workpad:open', function()
	local playerId = source
	local now = GetGameTimer()
	if lastOpen[playerId] and now - lastOpen[playerId] < 1000 then
		return
	end
	lastOpen[playerId] = now
	if yieldedBy then
		return
	end
	if not characterOf(playerId) then
		return notify(playerId, 'error', _t('no_character'))
	end
	if not hasTablet(playerId) then
		return notify(playerId, 'error', _t('no_tablet'))
	end
	local profile = profileOf(playerId)
	if not profile then
		return notify(playerId, 'info', _t('no_apps'))
	end
	profile.duty = remote('coe_businesses', 'CurrentDuty', playerId)
	TriggerClientEvent('coe_workpad:opened', playerId, profile)
end)

RegisterNetEvent('coe_workpad:call', function(requestId, appId, action, payload)
	local playerId = source
	if type(requestId) ~= 'number' or requestId % 1 ~= 0 then
		return
	end
	local valid, invalid = WorkpadRules.Request(appId, action, payload, config.MaxPayloadBytes, json.encode)
	if not valid then
		return reply(playerId, requestId, { ok = false, error = invalid })
	end
	local now = GetGameTimer()
	if lastCall[playerId] and now - lastCall[playerId] < config.CallCooldownMs then
		return reply(playerId, requestId, { ok = false, error = 'rate_limited' })
	end
	lastCall[playerId] = now
	if yieldedBy then
		return reply(playerId, requestId, { ok = false, error = 'closed' })
	end
	if not hasTablet(playerId) then
		return reply(playerId, requestId, { ok = false, error = 'no_tablet' })
	end
	-- O acesso é recalculado a cada ação: o jogador pode ter perdido o negócio ou o app com o tablet aberto.
	local app = WorkpadRules.Find(profileOf(playerId), appId)
	if not app then
		log('warn', 'security', 'workpad_call_denied', { player_id = playerId, operation = appId:sub(1, 48), action = action })
		return reply(playerId, requestId, { ok = false, error = 'forbidden' })
	end
	local definition = config.Apps[app.base]
	local ok, result
	if definition.native then
		ok, result = pcall(nativeCall, playerId, app.base, action)
	else
		ok, result = pcall(function()
			return exports[definition.resource]:TabletCall(playerId, app.base, action, payload or {}, app.instance)
		end)
	end
	if not ok or type(result) ~= 'table' then
		log('error', 'system', 'workpad_app_failed', { operation = app.base, action = action, error_code = tostring(result):sub(1, 96) })
		return reply(playerId, requestId, { ok = false, error = 'app_error' })
	end
	reply(playerId, requestId, result)
end)

RegisterNetEvent('coe_workpad:refresh', function()
	local playerId = source
	local now = GetGameTimer()
	if yieldedBy or (lastOpen[playerId] and now - lastOpen[playerId] < 1000) then
		return
	end
	lastOpen[playerId] = now
	TriggerClientEvent('coe_workpad:profile', playerId, profileOf(playerId) or { apps = {}, groups = config.Groups })
end)

-- Usar o item abre o tablet.
Core.Events.On('inventory.itemUsed', function(inventoryId, _slot, item)
	local characterId = type(inventoryId) == 'string' and inventoryId:match('^character:(.+)$')
	if not characterId or type(item) ~= 'table' or item.name ~= config.Item or yieldedBy then
		return
	end
	for _, id in ipairs(GetPlayers()) do
		local playerId = tonumber(id)
		if playerId and characterOf(playerId) == characterId then
			TriggerClientEvent('coe_workpad:use', playerId)
			return
		end
	end
end)

-- Início do ponto (para o tempo no app Ponto).
AddEventHandler('coe_businesses:dutyChanged', function(playerId, businessId, onDuty)
	if type(playerId) ~= 'number' then
		return
	end
	dutySince[playerId] = onDuty and { businessId = businessId, at = os.time() } or nil
	TriggerClientEvent('coe_workpad:duty', playerId, onDuty and businessId or nil)
end)

AddEventHandler('playerDropped', function()
	lastCall[source], lastOpen[source], dutySince[source] = nil, nil, nil
end)

-- Pacote que assume o tablet -----------------------------------------------------------------------------------

local function setYield(resource)
	yieldedBy = resource
	GlobalState.coeWorkpadYielded = resource or false
	if resource then
		TriggerClientEvent('coe_workpad:close', -1)
	end
end

-- O tablet básico fecha as telas e para de abrir até o resource chamador parar. Valor único: true ou { error }.
exports('Yield', function()
	local caller = GetInvokingResource()
	if not caller or not CoeAccess.Allowed(caller, config.Ace.Yield) then
		return { error = 'forbidden' }
	end
	if yieldedBy ~= caller then
		setYield(caller)
		log('info', 'system', 'workpad_yielded', { action = caller })
	end
	return true
end)

-- { active, yieldedBy }: se o tablet básico está atendendo.
exports('Status', function()
	return { active = yieldedBy == nil, yieldedBy = yieldedBy }
end)

AddEventHandler('onResourceStop', function(resource)
	if yieldedBy and resource == yieldedBy then
		setYield(nil)
		log('info', 'system', 'workpad_resumed', { action = resource })
	end
end)

GlobalState.coeWorkpadYielded = false
