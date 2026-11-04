-- Ponte entre coe_businesses, coe_factions e o catálogo de bancadas ilegais livres com o coe_crafting.
local config = CraftingConfig
local benches, stations, byBusiness, byFaction = config.BusinessBenches, {}, {}, {}
local lastCheck = {}

local function benchType(category)
	return 'business_' .. category
end

local function registerBenches()
	for category, def in pairs(benches) do
		local _, errorCode = Crafting.registry.AddBench(benchType(category), def, GetCurrentResourceName())
		if errorCode then
			print(('[coe_crafting] bancada %s inválida: %s'):format(category, tostring(errorCode)))
		end
	end
	if config.FactionBench then
		local _, errorCode = Crafting.registry.AddBench('faction', config.FactionBench, GetCurrentResourceName())
		if errorCode then
			print(('[coe_crafting] bancada faction inválida: %s'):format(tostring(errorCode)))
		end
	end
	if config.IllegalBench then
		local _, errorCode = Crafting.registry.AddBench('illegal', config.IllegalBench, GetCurrentResourceName())
		if errorCode then
			print(('[coe_crafting] bancada illegal inválida: %s'):format(tostring(errorCode)))
		end
	end
end

-- Equipe e ponto são decididos pelo coe_businesses, por negócio. Retorna true ou false, motivo:
-- off_duty (é da equipe/dono, mas sem ponto batido), not_staff ou unavailable.
local function canWork(playerId, business)
	local characterId = Core.Players.GetActiveCharacterId(playerId)
	if not characterId then
		return false, 'not_staff'
	end
	local ok, access = pcall(function()
		return exports.coe_businesses:Access(business.id, characterId)
	end)
	if not ok or type(access) ~= 'table' then
		return false, 'unavailable'
	end
	if access.canWork == true then
		return true
	end
	return false, access.canClock == true and 'off_duty' or 'not_staff'
end

local function isFactionMember(playerId, factionId)
	local characterId = Core.Players.GetActiveCharacterId(playerId)
	if not characterId then
		return false, 'not_member'
	end
	local ok, memberships = pcall(function()
		return exports.coe_factions:Memberships(characterId)
	end)
	if not ok or type(memberships) ~= 'table' then
		return false, 'unavailable'
	end
	for _, entry in ipairs(memberships) do
		if type(entry) == 'table' and entry.factionId == factionId then
			return true, characterId
		end
	end
	return false, 'not_member'
end

local function canCraftInFaction(playerId, factionId, recipeId)
	local member, characterIdOrReason = isFactionMember(playerId, factionId)
	if not member then
		return false, characterIdOrReason
	end
	if recipeId ~= nil then
		local ok, allowed = pcall(function()
			return exports.coe_factions:CanCraftInFaction(factionId, characterIdOrReason, recipeId)
		end)
		if not ok then
			return false, 'unavailable'
		end
		if allowed ~= true then
			return false, 'grade_too_low'
		end
	end
	return true
end

local function factionRecipes(playerId, factionId)
	local characterId = Core.Players.GetActiveCharacterId(playerId)
	if not characterId then
		return {}
	end
	local ok, list = pcall(function()
		return exports.coe_factions:RecipesForFaction(factionId, characterId)
	end)
	return ok and type(list) == 'table' and list or {}
end

local function notify(playerId, message)
	pcall(function()
		exports.coe_notify:Notify(playerId, 'error', message)
	end)
end

local function refresh()
	local nextStations, nextByBusiness, nextByFaction = {}, {}, {}
	local okBiz, bizList = pcall(function()
		return exports.coe_businesses:List()
	end)
	if okBiz and type(bizList) == 'table' then
		for _, business in pairs(bizList) do
			nextByBusiness[business.id] = business
			for _, station in ipairs(CraftingBusiness.Stations(business, benches)) do
				nextStations[#nextStations + 1] = station
			end
		end
	end
	local okFac, facList = pcall(function()
		return exports.coe_factions:List()
	end)
	if okFac and type(facList) == 'table' then
		for _, faction in pairs(facList) do
			nextByFaction[faction.id] = faction
			for _, station in ipairs(CraftingBusiness.FactionStations(faction)) do
				nextStations[#nextStations + 1] = station
			end
		end
	end
	if Crafting.catalog and Crafting.catalogReady and Crafting.catalogReady() then
		for _, station in ipairs(CraftingBusiness.IllegalStations(Crafting.catalog.Benches())) do
			nextStations[#nextStations + 1] = station
		end
	end
	stations, byBusiness, byFaction = nextStations, nextByBusiness, nextByFaction
	TriggerClientEvent('coe_crafting:stations', -1, stations)
end

local function stationOf(kind, ownerId, stationId)
	for _, station in ipairs(stations) do
		local stationKind = station.kind or 'business'
		if stationKind == kind and station.id == stationId then
			if kind == 'business' and station.businessId == ownerId then
				return station
			elseif (kind == 'faction' or kind == 'faction_stash') and station.factionId == ownerId then
				return station
			elseif kind == 'illegal' then
				return station
			end
		end
	end
end

RegisterNetEvent('coe_crafting:requestStations', function()
	TriggerClientEvent('coe_crafting:stations', source, stations)
end)

RegisterNetEvent('coe_crafting:checkAccess', function(arg1, arg2, arg3)
	local playerId = source
	local now = GetGameTimer()
	if lastCheck[playerId] and now - lastCheck[playerId] < 1000 then
		return
	end
	local kind, ownerId, stationId
	if arg3 ~= nil then
		kind, ownerId, stationId = arg1, arg2, arg3
	else
		kind, ownerId, stationId = 'business', arg1, arg2
	end
	if type(kind) ~= 'string' or type(ownerId) ~= 'string' or type(stationId) ~= 'string' then
		return
	end
	lastCheck[playerId] = now
	if kind == 'faction' or kind == 'faction_stash' then
		local faction = byFaction[ownerId]
		local station = stationOf(kind, ownerId, stationId)
		local allowed, reason = false, 'not_member'
		if faction and station then
			allowed, reason = isFactionMember(playerId, ownerId)
		end
		TriggerClientEvent('coe_crafting:access', playerId, 'faction:' .. ownerId, stationId, allowed == true, not allowed and reason or nil)
		return
	end
	local business, station = byBusiness[ownerId], stationOf('business', ownerId, stationId)
	local allowed, reason = false, 'not_staff'
	if business and station then
		allowed, reason = canWork(playerId, business)
	end
	TriggerClientEvent('coe_crafting:access', playerId, ownerId, stationId, allowed == true, reason)
end)

RegisterNetEvent('coe_crafting:openBusiness', function(businessId, stationId)
	local playerId = source
	if type(businessId) ~= 'string' or type(stationId) ~= 'string' or Crafting.throttled(playerId) then
		return
	end
	local business, station = byBusiness[businessId], stationOf('business', businessId, stationId)
	if not business or not station then
		notify(playerId, Crafting.messages.forbidden)
		return
	end
	local allowed, reason = canWork(playerId, business)
	if not allowed then
		notify(playerId, Crafting.messages[reason] or Crafting.messages.forbidden)
		return
	end
	local category = business.category
	local result = Crafting.Open(playerId, benchType(category), {
		recipes = Crafting.catalog.RecipesFor(business),
		label = station.label or benches[business.category].label,
		stashId = CraftingBusiness.StashFor(business, station),
		position = { x = station.x, y = station.y, z = station.z, radius = station.radius },
		access = function()
			local current = byBusiness[businessId]
			if current == nil or current.category ~= category then
				return false, 'forbidden'
			end
			return canWork(playerId, current)
		end
	})
	if result and result.error then
		notify(playerId, Crafting.messages[result.error] or 'Bancada indisponível.')
	end
end)

RegisterNetEvent('coe_crafting:openFaction', function(factionId, stationId)
	local playerId = source
	if type(factionId) ~= 'string' or type(stationId) ~= 'string' or Crafting.throttled(playerId) then
		return
	end
	local faction, station = byFaction[factionId], stationOf('faction', factionId, stationId)
	if not faction or not station then
		notify(playerId, Crafting.messages.forbidden)
		return
	end
	local allowed, reason = canCraftInFaction(playerId, factionId, nil)
	if not allowed then
		notify(playerId, Crafting.messages[reason] or Crafting.messages.forbidden)
		return
	end
	local result = Crafting.Open(playerId, 'faction', {
		recipes = function(pid)
			return factionRecipes(pid, factionId)
		end,
		label = station.label or (config.FactionBench and config.FactionBench.label) or 'Bancada da facção',
		stashId = CraftingBusiness.FactionStashFor(faction, station),
		position = { x = station.x, y = station.y, z = station.z, radius = station.radius },
		access = function(pid, recipeId)
			local current = byFaction[factionId]
			if not current or current.enabled == false then
				return false, 'forbidden'
			end
			return canCraftInFaction(pid, factionId, recipeId)
		end
	})
	if result and result.error then
		notify(playerId, Crafting.messages[result.error] or 'Bancada indisponível.')
	end
end)

local FACTION_STASH_MESSAGES = {
	not_member = 'Só membros deste grupo abrem este baú.',
	too_far = 'Chegue mais perto do baú.',
	no_stash = 'Baú indisponível.',
	container_limit = 'Feche um baú antes de abrir outro.'
}

RegisterNetEvent('coe_crafting:openFactionStash', function(factionId, stationId)
	local playerId = source
	if type(factionId) ~= 'string' or type(stationId) ~= 'string' or Crafting.throttled(playerId) then
		return
	end
	local function failed(errorCode)
		notify(playerId, FACTION_STASH_MESSAGES[errorCode] or 'Não foi possível abrir o baú.')
	end
	local faction, station = byFaction[factionId], stationOf('faction_stash', factionId, stationId)
	if not faction or faction.enabled == false or not station then
		return failed('no_stash')
	end
	local member, reason = isFactionMember(playerId, factionId)
	if not member then
		return failed(reason == 'not_member' and 'not_member' or 'no_stash')
	end
	local ped = GetPlayerPed(playerId)
	if not ped or ped == 0 or #(Core.Platform.Entities.GetCoords(ped) - vector3(station.x, station.y, station.z)) > (station.radius or 1.5) + 1.0 then
		return failed('too_far')
	end
	local ok, opened, openError = pcall(function()
		return exports.coe_inventory:OpenStash(playerId, CraftingBusiness.FactionStashId(factionId, stationId), {
			label = ('%s · %s'):format(station.label or 'Baú', faction.label or factionId),
			slots = station.slots or 50,
			maxWeight = station.maxWeight or 100000,
			position = { x = station.x, y = station.y, z = station.z },
			radius = (station.radius or 1.5) + 1.0
		})
	end)
	if not ok or opened ~= true then
		failed(ok and openError or 'no_stash')
	end
end)

RegisterNetEvent('coe_crafting:openIllegal', function(benchId)
	local playerId = source
	if type(benchId) ~= 'string' or Crafting.throttled(playerId) then
		return
	end
	local bench = Crafting.catalog and Crafting.catalog.Bench(benchId) or nil
	if not bench or bench.enabled == false or not Core.Players.GetActiveCharacterId(playerId) then
		notify(playerId, Crafting.messages.forbidden)
		return
	end
	local result = Crafting.Open(playerId, 'illegal', {
		recipes = bench.recipes,
		label = bench.label or (config.IllegalBench and config.IllegalBench.label) or 'Bancada clandestina',
		position = { x = bench.x, y = bench.y, z = bench.z, radius = bench.radius },
		access = function(pid)
			local current = Crafting.catalog and Crafting.catalog.Bench(benchId) or nil
			if not current or current.enabled == false or not Core.Players.GetActiveCharacterId(pid) then
				return false, 'forbidden'
			end
			return true
		end
	})
	if result and result.error then
		notify(playerId, Crafting.messages[result.error] or 'Bancada indisponível.')
	end
end)

AddEventHandler('playerDropped', function()
	lastCheck[source] = nil
end)

AddEventHandler('coe_businesses:changed', refresh)
AddEventHandler('coe_businesses:ready', refresh)
AddEventHandler('coe_factions:changed', refresh)
AddEventHandler('coe_factions:ready', refresh)
AddEventHandler('coe_crafting:catalogChanged', refresh)
AddEventHandler('coe_crafting:ready', registerBenches)

CreateThread(function()
	registerBenches()
	while not (GetResourceState('coe_businesses') == 'started' and exports.coe_businesses:IsReady()) do
		Wait(1000)
	end
	refresh()
end)
