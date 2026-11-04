local config = CoeTabletConfig
local lastCall = {}
local lastRefresh = {}

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

local _t = (Core and Core.Locale and Core.Locale.Bind) and Core.Locale.Bind(Locales) or function(k) return (Locales and Locales['pt-BR'] and Locales['pt-BR'][k]) or k end

local function groupsOf(playerId)
	local ok, groups = pcall(function()
		return exports.coe_core:GetPlayerGroups(playerId)
	end)
	return ok and groups or nil
end

local function isAdmin(playerId)
	return IsPlayerAceAllowed(playerId, config.AdminAce)
end

-- Categoria do negócio em que o jogador está de ponto, ou nil.
local function dutyCategoryOf(playerId)
	if GetResourceState('coe_businesses') ~= 'started' then
		return nil
	end
	local ok, category = pcall(function()
		local businessId = exports.coe_businesses:CurrentDuty(playerId)
		local business = type(businessId) == 'string' and exports.coe_businesses:Get(businessId) or nil
		return type(business) == 'table' and business.category or nil
	end)
	return ok and type(category) == 'string' and category or nil
end

-- O jogador tem o item no inventário (exigido por apps com `item`)?
local function hasItemFn(playerId)
	local characterId = Core.Players.GetActiveCharacterId(playerId)
	return function(name)
		if not characterId or GetResourceState('coe_inventory') ~= 'started' then
			return false
		end
		local ok, count = pcall(function()
			return exports.coe_inventory:GetItemCount('character:' .. characterId, name)
		end)
		return ok and type(count) == 'number' and count > 0
	end
end

-- Apps com `ownerCheck`: o resource do app responde se o jogador vê o app (TabletVisible).
local function canSeeFn(playerId)
	return function(app, id)
		if GetResourceState(app.resource) ~= 'started' then
			return false
		end
		local ok, visible = pcall(function()
			-- config.Apps não guarda o id dentro do app: sem ele o resource recebia nil e escondia o app.
			return exports[app.resource]:TabletVisible(playerId, app.base or app.id or id)
		end)
		return ok and visible == true
	end
end

-- Apps com `instances`: o resource lista as instâncias do jogador (TabletInstances).
local function instancesFn(playerId)
	return function(app)
		if GetResourceState(app.resource) ~= 'started' then
			return nil
		end
		local ok, list = pcall(function()
			return exports[app.resource]:TabletInstances(playerId)
		end)
		return ok and type(list) == 'table' and list or nil
	end
end

-- shortcut: nome de um atalho de config.Shortcuts (tablet próprio do atalho) ou nil (tablet completo).
RegisterNetEvent('coe_tablet:open', function(shortcut)
	local playerId = source
	if shortcut ~= nil and (type(shortcut) ~= 'string' or not (config.Shortcuts or {})[shortcut]) then
		return
	end
	local groups = groupsOf(playerId)
	local profile, reason = TabletProfile.Resolve(config, groups, isAdmin(playerId), dutyCategoryOf(playerId), hasItemFn(playerId), canSeeFn(playerId), instancesFn(playerId))
	log('info', 'system', 'tablet_open_requested', {
		player_id = playerId,
		role = groups and groups.job and groups.job.name or 'none',
		result = profile and 'ok' or reason
	})
	if shortcut then
		local scoped, denied = TabletProfile.Scope(config, profile, shortcut)
		if not scoped then
			notify(playerId, 'info', denied or _t('nothing_to_show'))
			return
		end
		profile = scoped
	end
	if not profile then
		notify(playerId, 'info', _t('no_apps_available'))
		return
	end
	TriggerClientEvent('coe_tablet:opened', playerId, profile)
end)

RegisterNetEvent('coe_tablet:refresh', function()
	local playerId = source
	local now = GetGameTimer()
	if lastRefresh[playerId] and now - lastRefresh[playerId] < 1000 then
		return
	end
	lastRefresh[playerId] = now
	local profile = TabletProfile.Resolve(config, groupsOf(playerId), isAdmin(playerId), dutyCategoryOf(playerId), hasItemFn(playerId), canSeeFn(playerId), instancesFn(playerId))
	TriggerClientEvent('coe_tablet:profile', playerId, profile or { apps = {}, groups = config.Groups })
end)

-- Respostas grandes (ex.: fotos) vão por evento latente para não travar o canal confiável.
local function reply(playerId, requestId, result)
	if type(result) == 'table' and type(result.data) == 'string' and #result.data > config.LatentReplyBytes then
		TriggerLatentClientEvent('coe_tablet:result', playerId, config.LatentBytesPerSecond, requestId, result)
		return
	end
	TriggerClientEvent('coe_tablet:result', playerId, requestId, result)
end

RegisterNetEvent('coe_tablet:call', function(requestId, appId, action, payload)
	local playerId = source
	if type(requestId) ~= 'number' or requestId % 1 ~= 0 then
		return
	end
	if type(appId) ~= 'string' or type(action) ~= 'string' or #appId > 96 or #action > 32 then
		reply(playerId, requestId, { ok = false, error = 'invalid_request' })
		return
	end
	if payload ~= nil and (type(payload) ~= 'table' or #json.encode(payload) > config.MaxPayloadBytes) then
		reply(playerId, requestId, { ok = false, error = 'invalid_payload' })
		return
	end

	local now = GetGameTimer()
	if lastCall[playerId] and now - lastCall[playerId] < config.CallCooldownMs then
		reply(playerId, requestId, { ok = false, error = 'rate_limited' })
		return
	end
	lastCall[playerId] = now

	local app = TabletProfile.CanUse(config, groupsOf(playerId), isAdmin(playerId), appId, dutyCategoryOf(playerId), hasItemFn(playerId), canSeeFn(playerId), instancesFn(playerId))
	if not app then
		log('warn', 'security', 'tablet_call_denied', { source = playerId, operation = appId, action = action })
		reply(playerId, requestId, { ok = false, error = 'forbidden' })
		return
	end

	local resource = config.Apps[app.base].resource
	if GetResourceState(resource) ~= 'started' then
		reply(playerId, requestId, { ok = false, error = 'app_unavailable' })
		return
	end

	local called, result = pcall(function()
		return exports[resource]:TabletCall(playerId, app.base, action, payload or {}, app.instance)
	end)
	if not called or type(result) ~= 'table' then
		log('error', 'system', 'tablet_app_failed', { operation = appId, action = action })
		reply(playerId, requestId, { ok = false, error = 'app_error' })
		return
	end
	reply(playerId, requestId, result)
end)

AddEventHandler('playerDropped', function()
	lastCall[source] = nil
	lastRefresh[source] = nil
end)
