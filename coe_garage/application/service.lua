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

-- Dono do veículo: o coe_vehicles devolve ownerCharacterId (string); o personagem ativo pode vir como número.
local function ownsVehicle(record, characterId)
	return type(record) == 'table' and record.ownerCharacterId ~= nil
		and tostring(record.ownerCharacterId) == tostring(characterId)
end

local function catalogInfo(model)
	local ok, info = pcall(function()
		return exports.coe_vehicle_catalog:GetVehicleInfo(model)
	end)
	return ok and type(info) == 'table' and info or nil
end

-- Vaga registrada: o veículo só sai da garagem onde foi guardado. Sem registro (veículo novo) ou com a
-- garagem removida, qualquer garagem pública serve na primeira retirada.
local function slotAllows(slotGarage, garageId)
	return slotGarage == nil or slotGarage == garageId or garages[slotGarage] == nil
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
			kinds = { 'public' },
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

-- O coe_staff pode (re)iniciar depois do boot: registra de novo assim que ele terminar de subir.
AddEventHandler('onResourceStart', function(resourceName)
	if resourceName == 'coe_staff' then
		CreateThread(function()
			for _ = 1, 20 do
				Wait(500)
				if GetResourceState('coe_staff') == 'started' then
					registerStaffProvider()
					return
				end
			end
		end)
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
		if veh.state == 'stored' and slotAllows(assignedGarage, garageId) then
			local info = catalogInfo(veh.model)
			available[#available + 1] = {
				id = vId,
				model = veh.model,
				label = info and info.name or veh.model,
				plate = veh.plate
			}
		end
	end

	TriggerClientEvent('coe_garage:openMenu', src, garageId, spotId, available, {
		title = g.label,
		spotLabel = targetSpot.label
	})
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

	vehicleId = tostring(vehicleId or '')
	local veh = exports.coe_vehicles:Get(vehicleId)
	if not ownsVehicle(veh, characterId) then
		return notify(src, 'error', _t('not_your_vehicle'))
	end

	if veh.state ~= 'stored' then
		return notify(src, 'error', _t('vehicle_not_stored'))
	end

	-- Mesma regra da listagem: veículo com vaga registrada só sai da garagem onde foi guardado.
	local slots = GaragePersistence.SlotsOf(characterId) or {}
	if not slotAllows(slots[vehicleId], garageId) then
		return notify(src, 'error', _t('wrong_garage'))
	end

	local info = catalogInfo(veh.model)
	local netId = exports.coe_vehicles:Spawn(vehicleId, targetSpot.x, targetSpot.y, targetSpot.z, targetSpot.heading, info and info.type or 'automobile')
	if not netId or type(netId) ~= 'number' then
		return notify(src, 'error', _t('spawn_failed'))
	end

	-- A vaga continua registrada nesta garagem: se o servidor reiniciar com o veículo na rua, o coe_vehicles
	-- devolve o estado 'stored' e ele volta a aparecer aqui (última garagem).
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
	if vehicleId ~= nil then
		vehicleId = tostring(vehicleId)
	end
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
	if not ownsVehicle(vehRecord, characterId) then
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
