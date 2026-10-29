local ready = false
local garages = {}
local lastAction = {}

local function log(level, category, event, context)
	pcall(function()
		exports.coe_logging:Log(level, category, event, context)
	end)
end

local function notify(playerId, kind, message)
	pcall(function()
		exports.coe_notify:Notify(playerId, kind, message)
	end)
end

local function broadcastStations()
	local stations = GarageDomain.BuildStationList(garages)
	TriggerClientEvent('coe_garage:syncStations', -1, stations)
end

local function rebuild()
	local list = GaragePersistence.ListGarages() or {}
	garages = {}
	for _, g in ipairs(list) do
		garages[g.id] = g
	end
	broadcastStations()
end

local function throttled(playerId)
	local now = GetGameTimer()
	if lastAction[playerId] and now - lastAction[playerId] < (GarageConfig.Limits.ActionCooldownMs or 1000) then
		return true
	end
	lastAction[playerId] = now
	return false
end

-- Registro do provedor para o painel administrativo (coe_staff)
local function registerStaffProvider()
	if GetResourceState('coe_staff') ~= 'started' then
		return
	end
	pcall(function()
		exports.coe_staff:RegisterGaragesProvider({
			resource = GetCurrentResourceName(),
			List = function()
				local list = {}
				for _, g in pairs(garages) do
					list[#list + 1] = g
				end
				table.sort(list, function(a, b) return a.id < b.id end)
				return list
			end,
			Save = function(raw)
				local clean, err = GarageDomain.ValidateGarage(raw)
				if not clean then
					return { error = err }
				end
				local saved, saveErr = GaragePersistence.SaveGarage(clean)
				if not saved then
					return { error = saveErr }
				end
				garages[clean.id] = clean
				broadcastStations()
				return clean
			end,
			Delete = function(id)
				local deleted, delErr = GaragePersistence.DeleteGarage(id)
				if not deleted then
					return { error = delErr }
				end
				garages[id] = nil
				broadcastStations()
				return true
			end
		})
	end)
end

AddEventHandler('onResourceStart', function(resourceName)
	if resourceName == 'coe_staff' then
		registerStaffProvider()
	end
end)

-- Boot inicial assíncrono
CreateThread(function()
	while true do
		local initialized, errorCode = GaragePersistence.Initialize()
		if initialized then
			break
		end
		log('warn', 'persistence', 'database_waiting', { error = errorCode })
		Wait(1000)
	end

	while GetResourceState('coe_vehicles') ~= 'started' do
		Wait(500)
	end

	rebuild()
	ready = true
	registerStaffProvider()
	log('info', 'system', 'garage_ready', { count = #GarageDomain.BuildStationList(garages) })
end)

-- Exports públicos
exports('IsReady', function()
	return ready
end)

exports('ListGarages', function()
	local list = {}
	for _, g in pairs(garages) do
		list[#list + 1] = g
	end
	table.sort(list, function(a, b) return a.id < b.id end)
	return list
end)

exports('GetGarage', function(id)
	return garages[id]
end)

exports('GetVehicleGarage', function(vehicleId)
	return GaragePersistence.GetSlot(vehicleId)
end)

exports('SaveGarage', function(raw)
	local clean, err = GarageDomain.ValidateGarage(raw)
	if not clean then
		return nil, err
	end
	local saved, saveErr = GaragePersistence.SaveGarage(clean)
	if not saved then
		return nil, saveErr
	end
	garages[clean.id] = clean
	broadcastStations()
	return clean
end)

exports('DeleteGarage', function(id)
	local deleted, delErr = GaragePersistence.DeleteGarage(id)
	if not deleted then
		return nil, delErr
	end
	garages[id] = nil
	broadcastStations()
	return true
end)

-- Eventos de Rede
RegisterNetEvent('coe_garage:requestStations', function()
	local src = source
	local stations = GarageDomain.BuildStationList(garages)
	TriggerClientEvent('coe_garage:syncStations', src, stations)
end)

RegisterNetEvent('coe_garage:getStoredVehicles', function(garageId, spotId)
	local src = source
	if throttled(src) then
		return notify(src, 'error', _t('cooldown'))
	end

	local g = garages[garageId]
	if not g then
		return notify(src, 'error', _t('garage_not_found'))
	end

	local targetSpot = nil
	for _, spot in ipairs(g.spots or {}) do
		if spot.id == spotId then
			targetSpot = spot
			break
		end
	end
	if not targetSpot then
		return notify(src, 'error', _t('spot_not_found'))
	end

	local ped = GetPlayerPed(src)
	local coords = GetEntityCoords(ped)
	if not GarageDomain.ValidateDistance(coords, targetSpot, 4.0) then
		return notify(src, 'error', _t('too_far'))
	end

	local characterId = Core.Players.GetActiveCharacterId(src)
	if not characterId then
		return
	end

	local allVehicles = exports.coe_vehicles:ListByOwner(characterId) or {}
	local slots = GaragePersistence.SlotsOf(characterId) or {}

	local available = {}
	for _, veh in ipairs(allVehicles) do
		local vId = tostring(veh.id)
		local assignedGarage = slots[vId]
		local isStored = veh.state == 'stored'
		-- Pode retirar se o veículo estiver guardado e pertencer a esta garagem ou sem vaga fixa
		if isStored and (not assignedGarage or assignedGarage == garageId) then
			available[#available + 1] = {
				id = veh.id,
				model = veh.model,
				plate = veh.plate
			}
		end
	end

	TriggerClientEvent('coe_garage:openMenu', src, garageId, spotId, available)
end)

RegisterNetEvent('coe_garage:retrieveVehicle', function(garageId, spotId, vehicleId)
	local src = source
	if throttled(src) then
		return notify(src, 'error', _t('cooldown'))
	end

	local g = garages[garageId]
	if not g then
		return notify(src, 'error', _t('garage_not_found'))
	end

	local targetSpot = nil
	for _, spot in ipairs(g.spots or {}) do
		if spot.id == spotId then
			targetSpot = spot
			break
		end
	end
	if not targetSpot then
		return notify(src, 'error', _t('spot_not_found'))
	end

	local ped = GetPlayerPed(src)
	local coords = GetEntityCoords(ped)
	if not GarageDomain.ValidateDistance(coords, targetSpot, 4.0) then
		return notify(src, 'error', _t('too_far'))
	end

	local characterId = Core.Players.GetActiveCharacterId(src)
	if not characterId then
		return
	end

	local veh = exports.coe_vehicles:Get(vehicleId)
	if not veh or tostring(veh.owner_id) ~= tostring(characterId) then
		return notify(src, 'error', _t('not_your_vehicle'))
	end

	if veh.state ~= 'stored' then
		return notify(src, 'error', _t('vehicle_not_stored'))
	end

	-- Mesma regra da listagem: veículo com vaga fixa só sai da garagem onde foi guardado.
	local slots = GaragePersistence.SlotsOf(characterId) or {}
	local assignedGarage = slots[tostring(vehicleId)]
	if assignedGarage and assignedGarage ~= garageId then
		return notify(src, 'error', _t('wrong_garage'))
	end

	local netId = exports.coe_vehicles:Spawn(vehicleId, targetSpot.x, targetSpot.y, targetSpot.z, targetSpot.heading, 'automobile')
	if not netId or type(netId) ~= 'number' then
		return notify(src, 'error', _t('spawn_failed'))
	end

	exports.coe_vehicles:GiveKey(vehicleId, characterId)
	GaragePersistence.SaveSlot(vehicleId, garageId, characterId, 'car')

	notify(src, 'success', _t('vehicle_retrieved'))
	TriggerClientEvent('coe_garage:spawned', src, netId)
end)

RegisterNetEvent('coe_garage:storeVehicle', function(garageId, spotId, netId)
	local src = source
	if throttled(src) then
		return notify(src, 'error', _t('cooldown'))
	end

	local g = garages[garageId]
	if not g then
		return notify(src, 'error', _t('garage_not_found'))
	end

	local targetSpot = nil
	for _, spot in ipairs(g.spots or {}) do
		if spot.id == spotId then
			targetSpot = spot
			break
		end
	end
	if not targetSpot then
		return notify(src, 'error', _t('spot_not_found'))
	end

	local ped = GetPlayerPed(src)
	local entity = NetworkGetEntityFromNetworkId(netId)
	if not entity or not DoesEntityExist(entity) then
		return notify(src, 'error', _t('store_failed'))
	end

	local coords = GetEntityCoords(entity)
	if not GarageDomain.ValidateDistance(coords, targetSpot, 5.0) then
		return notify(src, 'error', _t('too_far'))
	end

	local characterId = Core.Players.GetActiveCharacterId(src)
	if not characterId then
		return
	end

	local stateBag = Entity(entity).state
	local vehicleId = stateBag and stateBag['coe:vehicleId']
	if not vehicleId then
		-- Fallback pelo GetByPlate
		local plate = GetVehicleNumberPlateText(entity)
		local record = exports.coe_vehicles:GetByPlate(plate)
		if record then
			vehicleId = record.id
		end
	end

	if not vehicleId then
		return notify(src, 'error', _t('not_your_vehicle'))
	end

	local vehRecord = exports.coe_vehicles:Get(vehicleId)
	if not vehRecord or tostring(vehRecord.owner_id) ~= tostring(characterId) then
		return notify(src, 'error', _t('not_your_vehicle'))
	end

	local stored = exports.coe_vehicles:Store(vehicleId)
	if not stored or stored ~= true then
		return notify(src, 'error', _t('store_failed'))
	end

	GaragePersistence.SaveSlot(vehicleId, garageId, characterId, 'car')
	notify(src, 'success', _t('vehicle_stored'))
	TriggerClientEvent('coe_garage:stored', src)
end)
