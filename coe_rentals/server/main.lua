-- Servidor de aluguel de veículos populares: estações cadastradas no banco (painel), cobrança com caução,
-- documento de locação e chave no inventário, devolução na zona ou no balcão e encerramento sem o veículo.
local activeRentals = {} -- characterId -> { entity, netId, plate, model, label, deposit, stationId, rentedAt, playerId }
local stations = {}      -- id -> estação (RentalsStations.Normalize)
local stationOrder = {}
local ready = false
local _t = Core.Locale.Init('coe_rentals', RentalsConfig.Locale or 'pt-BR')

local CONTRACT_ITEM = 'rental_contract'
local KEY_ITEM = 'carkey'

local function log(level, action, ctx)
	if exports and exports.coe_logging and exports.coe_logging.Log then
		pcall(function()
			exports.coe_logging:Log(level, 'rentals', action, ctx)
		end)
	end
end

local function notify(playerId, kind, message)
	if exports and exports.coe_notify and exports.coe_notify.Notify then
		pcall(function()
			exports.coe_notify:Notify(playerId, kind, message)
		end)
	end
end

local lastRequest = {}

-- Um pedido de aluguel/devolução por jogador a cada RentalsConfig.CooldownMs.
local function throttled(playerId)
	local now = GetGameTimer()
	local previous = lastRequest[playerId]
	if previous and now - previous < (RentalsConfig.CooldownMs or 2000) then
		return true
	end
	lastRequest[playerId] = now
	return false
end

local function playerCoords(playerId)
	local ped = GetPlayerPed(playerId)
	if not ped or ped == 0 then
		return nil
	end
	return GetEntityCoords(ped)
end

-- Fail-closed: sem coe_economy no ar, ninguém aluga de graça. Cada chamada à economia fica escrita por extenso
-- para o tools/check_contracts.lua conferir que coe_rentals está na allowlist da economia.
local function economy(call)
	if GetResourceState('coe_economy') ~= 'started' then
		return nil, 'economy_unavailable'
	end
	local ok, result, errorCode = pcall(call)
	if not ok then
		return nil, 'economy_unavailable'
	end
	return result, errorCode
end

local function getCharacterId(playerId)
	if not Core or not Core.Players or not Core.Players.GetActiveCharacterId then
		return nil
	end
	local characterId = Core.Players.GetActiveCharacterId(playerId)
	return characterId ~= nil and tostring(characterId) or nil
end

local function getCharacter(playerId)
	local ok, character = pcall(function()
		return Core.Players.GetActiveCharacter(playerId)
	end)
	return ok and type(character) == 'table' and character or nil
end

local function money(amount)
	local ok, formatted = pcall(function()
		return Core.Locale.FormatMoney(amount, RentalsConfig.Locale)
	end)
	return ok and type(formatted) == 'string' and formatted or ('R$ ' .. tostring(amount))
end

-- Inventário -------------------------------------------------------------------------------------------------

local function inventoryReady()
	return GetResourceState('coe_inventory') == 'started'
end

local function playerInventory(playerId)
	if not inventoryReady() then
		return nil
	end
	local ok, inventoryId = pcall(function()
		return exports.coe_inventory:GetPlayerInventory(playerId)
	end)
	return ok and type(inventoryId) == 'string' and inventoryId or nil
end

local function giveItem(playerId, itemName, metadata)
	local inventoryId = playerInventory(playerId)
	if not inventoryId then
		return false
	end
	local ok, added = pcall(function()
		return exports.coe_inventory:AddItem(inventoryId, itemName, 1, metadata)
	end)
	return ok and added ~= false and added ~= nil
end

-- Remove o contrato e a chave do aluguel `plate` do inventário (do jogador online ou pelo id do personagem).
local function removeRentalItems(inventoryId, plate)
	if not inventoryId or not inventoryReady() or type(plate) ~= 'string' then
		return
	end
	pcall(function()
		exports.coe_inventory:RemoveItemsByMetadata(inventoryId, CONTRACT_ITEM, { plate = plate })
	end)
	pcall(function()
		exports.coe_inventory:RemoveItemsByMetadata(inventoryId, KEY_ITEM, { plate = plate, rental = true })
	end)
end

local function inventoryIdOf(characterId, playerId)
	return (playerId and playerInventory(playerId)) or ('character:' .. tostring(characterId))
end

-- Estações -------------------------------------------------------------------------------------------------------

local function catalogConfig()
	return { Vehicles = RentalsConfig.Vehicles, Stations = stationOrder }
end

local function publicStations()
	local list = {}
	for _, station in ipairs(stationOrder) do
		if station.enabled then
			list[#list + 1] = station
		end
	end
	return list
end

local function broadcast(target)
	TriggerClientEvent('coe_rentals:stations', target or -1, publicStations())
end

local function setStations(list)
	stations, stationOrder = {}, {}
	for _, station in ipairs(list) do
		stations[station.id] = station
		stationOrder[#stationOrder + 1] = station
	end
	table.sort(stationOrder, function(a, b) return a.id < b.id end)
end

local function loadStations()
	local rows, errorCode = RentalsPersistence.ListStations()
	if not rows then
		return false, errorCode
	end
	-- Primeira vez: semeia o banco com as estações do config.lua.
	if #rows == 0 then
		for _, entry in ipairs(RentalsConfig.Stations or {}) do
			local station = RentalsStations.FromConfig(entry)
			if station and RentalsPersistence.SaveStation(station) then
				rows[#rows + 1] = station
			end
		end
	end
	local list = {}
	for _, raw in ipairs(rows) do
		local station = RentalsStations.Normalize(raw, RentalsConfig.Limits)
		if station then
			list[#list + 1] = station
		else
			log('warn', 'station_invalid', { station = tostring(raw.id) })
		end
	end
	setStations(list)
	return true
end

local function findStation(stationId)
	return type(stationId) == 'string' and stations[stationId] or nil
end

local function near(coords, point, radius)
	return RentalsRules.IsNear(coords, point, radius)
end

-- Ponto de retirada livre: nenhum veículo a menos de SpawnClearance metros.
local function spawnOccupied(point)
	local clearance = RentalsConfig.SpawnClearance or 2.5
	for _, vehicle in ipairs(GetAllVehicles and GetAllVehicles() or {}) do
		if DoesEntityExist(vehicle) and near(GetEntityCoords(vehicle), point, clearance) then
			return true
		end
	end
	return false
end

-- Situação do aluguel ativo para o menu e para devolver/encerrar no balcão.
local VEHICLE_OK, VEHICLE_FAR, VEHICLE_LOST = 'near', 'far', 'lost'

local function vehicleStatus(rental, station)
	local entity = rental.entity
	if not entity or not DoesEntityExist(entity) then
		return VEHICLE_LOST
	end
	if GetEntityHealth and GetEntityHealth(entity) <= 0 then
		return VEHICLE_LOST
	end
	local at = GetEntityCoords(entity)
	local reach = RentalsConfig.CounterReturnDistance or 40.0
	if near(at, station.ped, reach) or near(at, station.returnZone, reach) then
		return VEHICLE_OK
	end
	for _, spawn in ipairs(station.spawns) do
		if near(at, spawn, reach) then
			return VEHICLE_OK
		end
	end
	return VEHICLE_FAR
end

local function vehicleOccupied(entity)
	for seat = -1, 6 do
		local ped = GetPedInVehicleSeat and GetPedInVehicleSeat(entity, seat) or 0
		if ped and ped ~= 0 then
			return true
		end
	end
	return false
end

-- Encerra o aluguel: apaga o veículo, devolve (ou retém) a caução e tira o contrato e a chave do inventário.
local function finishRental(characterId, playerId, refund, reason)
	local rental = activeRentals[characterId]
	if not rental then
		return 0
	end
	activeRentals[characterId] = nil
	if rental.entity and DoesEntityExist(rental.entity) then
		DeleteEntity(rental.entity)
	end
	local refunded = 0
	local depositAmount = rental.deposit or 0
	if refund and depositAmount > 0 then
		if economy(function() return exports.coe_economy:Credit(characterId, depositAmount, 'vehicle_rental_deposit') end) == true then
			refunded = depositAmount
		else
			log('error', 'rental_refund_failed', { character_id = characterId, plate = rental.plate, total = depositAmount })
			if playerId then
				notify(playerId, 'error', _t('refund_failed'))
			end
		end
	end
	removeRentalItems(inventoryIdOf(characterId, playerId), rental.plate)
	log('info', 'vehicle_returned', { character_id = characterId, plate = rental.plate, refunded_deposit = refunded, reason = reason })
	if playerId then
		Core.Events.ToClient(playerId, 'rentals.returned')
	end
	return refunded, rental
end

-- Tipo do veículo para o spawn no servidor: catálogo (coe_vehicle_catalog) ou a categoria do config.
local CATEGORY_TYPES = { bike = 'bike', moto = 'bike', carro = 'automobile' }

local function vehicleType(vehicleDef)
	if GetResourceState('coe_vehicle_catalog') == 'started' then
		local ok, info = pcall(function()
			return exports.coe_vehicle_catalog:GetVehicleInfo(vehicleDef.model)
		end)
		if ok and type(info) == 'table' and type(info.type) == 'string' then
			return info.type
		end
	end
	return CATEGORY_TYPES[vehicleDef.category] or 'automobile'
end

-- O servidor cria a entidade de forma assíncrona: logo após a criação ela ainda não "existe". Espera até 3 s
-- antes de considerar falha (antes disso o aluguel era estornado com o veículo aparecendo na rua).
local function spawnRentalVehicle(vehicleDef, spawnPoint)
	local modelHash = joaat(vehicleDef.model)
	local entity
	if CreateVehicleServerSetter then
		entity = CreateVehicleServerSetter(modelHash, vehicleType(vehicleDef), spawnPoint.x + 0.0, spawnPoint.y + 0.0, spawnPoint.z + 0.0, (spawnPoint.h or 0.0) + 0.0)
	else
		entity = CreateVehicle(modelHash, spawnPoint.x, spawnPoint.y, spawnPoint.z, spawnPoint.h or 0.0, true, true)
	end
	if not entity or entity == 0 then
		return nil
	end
	for _ = 1, 60 do
		if DoesEntityExist(entity) then
			return entity
		end
		Wait(50)
	end
	return nil
end

-- Aluguel ------------------------------------------------------------------------------------------------------

Core.Events.OnNet('rentals.rent', function(stationId, model)
	local playerId = source
	if throttled(playerId) then
		notify(playerId, 'warning', _t('busy'))
		return
	end
	local characterId = getCharacterId(playerId)
	if not characterId then
		notify(playerId, 'error', _t('no_character'))
		return
	end

	local station = findStation(stationId)
	if not station or not station.enabled then
		notify(playerId, 'error', _t('station_not_found'))
		return
	end
	if not near(playerCoords(playerId), station.ped, RentalsConfig.InteractRadius or 6.0) then
		log('warn', 'rental_denied', { player_id = playerId, error_code = 'too_far', station = stationId })
		notify(playerId, 'error', _t('too_far'))
		return
	end

	local vehicleDef = RentalsRules.FindVehicleAt(catalogConfig(), station, model)
	if not vehicleDef then
		notify(playerId, 'error', _t('vehicle_not_available'))
		return
	end

	local canRent, rentErr = RentalsRules.CanRent(characterId, activeRentals)
	if not canRent then
		notify(playerId, 'warning', _t(rentErr or 'already_rented'))
		return
	end

	local spawnPoint = RentalsStations.FreeSpawn(station, spawnOccupied)
	if not spawnPoint then
		notify(playerId, 'warning', _t('spawn_blocked'))
		return
	end

	local price, deposit, total = RentalsRules.CalculateTotal(vehicleDef)
	local debited, debitError = economy(function() return exports.coe_economy:Debit(characterId, total, 'vehicle_rental') end)
	if debited ~= true then
		notify(playerId, 'error', _t(debitError == 'economy_unavailable' and 'economy_unavailable' or 'not_enough_money'))
		return
	end

	local plate = RentalsRules.GenerateRentalPlate()
	local entity = spawnRentalVehicle(vehicleDef, spawnPoint)
	if not entity then
		-- Reembolso de segurança caso o spawn falhe
		if economy(function() return exports.coe_economy:Credit(characterId, total, 'rental_refund_spawn_failed') end) ~= true then
			log('error', 'rental_refund_failed', { character_id = characterId, total = total })
		end
		notify(playerId, 'error', _t('vehicle_spawn_failed'))
		return
	end

	SetVehicleNumberPlateText(entity, plate)
	SetVehicleDoorsLocked(entity, 1)
	-- A chave (item) libera este veículo no coe_vehicles: sem ela não liga nem tranca.
	if Entity then
		pcall(function()
			Entity(entity).state:set('coe:keyPlate', plate, true)
		end)
	end
	local netId = NetworkGetNetworkIdFromEntity(entity)

	local character = getCharacter(playerId) or {}
	local renter = ((character.firstName or '') .. ' ' .. (character.lastName or '')):gsub('^%s+', ''):gsub('%s+$', '')
	local rentedAt = os.time()
	local vehicleLabel = vehicleDef.label or vehicleDef.model

	activeRentals[characterId] = {
		entity = entity,
		netId = netId,
		plate = plate,
		model = vehicleDef.model,
		label = vehicleLabel,
		deposit = deposit,
		stationId = station.id,
		rentedAt = rentedAt,
		playerId = playerId
	}

	local contractOk = giveItem(playerId, CONTRACT_ITEM, {
		label = _t('contract_label', { plate = plate }),
		plate = plate,
		model = vehicleDef.model,
		vehicle = vehicleLabel,
		renter = renter ~= '' and renter or _t('contract_unknown_renter'),
		stateId = character.stateId and tostring(character.stateId) or nil,
		station = station.label,
		rentedAt = rentedAt,
		rentedAtText = os.date('%d/%m/%Y %H:%M', rentedAt),
		price = money(price),
		deposit = money(deposit)
	})
	local keyOk = giveItem(playerId, KEY_ITEM, {
		label = _t('key_label', { plate = plate }),
		plate = plate,
		rental = true
	})
	if not contractOk or not keyOk then
		notify(playerId, 'warning', _t('items_not_delivered'))
	end

	log('info', 'vehicle_rented', { character_id = characterId, model = vehicleDef.model, plate = plate, total = total, deposit = deposit, station = station.id })
	notify(playerId, 'success', _t('rent_success', { model = vehicleLabel, deposit = deposit }))
	Core.Events.ToClient(playerId, 'rentals.spawned', netId, plate, deposit)
end)

-- Devolução na zona, dirigindo o veículo alugado.
Core.Events.OnNet('rentals.return', function(stationId)
	local playerId = source
	if throttled(playerId) then
		return
	end
	local characterId = getCharacterId(playerId)
	if not characterId then
		return
	end

	local rental = activeRentals[characterId]
	if not rental then
		notify(playerId, 'warning', _t('not_your_rental'))
		return
	end

	local station = findStation(stationId)
	if not station then
		notify(playerId, 'error', _t('station_not_found'))
		return
	end

	if not near(playerCoords(playerId), station.returnZone, station.returnZone.radius + (RentalsConfig.InteractRadius or 6.0)) then
		notify(playerId, 'error', _t('too_far'))
		return
	end

	local ped = GetPlayerPed(playerId)
	local veh = GetVehiclePedIsIn(ped, false)
	if veh == 0 or veh ~= rental.entity then
		notify(playerId, 'warning', _t('not_in_vehicle'))
		return
	end

	local refunded = finishRental(characterId, playerId, true, 'zone')
	if refunded == (rental.deposit or 0) then
		notify(playerId, 'success', _t('return_success', { deposit = refunded }))
	end
end)

-- Menu do balcão: o servidor diz o que o jogador pode fazer agora (alugar, devolver ou encerrar).
Core.Events.OnNet('rentals.menu', function(stationId)
	local playerId = source
	local characterId = getCharacterId(playerId)
	local station = findStation(stationId)
	if not characterId or not station or not station.enabled then
		return
	end
	if not near(playerCoords(playerId), station.ped, RentalsConfig.InteractRadius or 6.0) then
		notify(playerId, 'error', _t('too_far'))
		return
	end
	local vehicles = {}
	for _, vehicle in ipairs(RentalsRules.VehiclesFor(catalogConfig(), station)) do
		local price, deposit, total = RentalsRules.CalculateTotal(vehicle)
		vehicles[#vehicles + 1] = {
			model = vehicle.model, label = vehicle.label or vehicle.model, category = vehicle.category,
			price = price, deposit = deposit, total = total
		}
	end
	local rental = activeRentals[characterId]
	local current = nil
	if rental then
		current = {
			plate = rental.plate,
			label = rental.label,
			deposit = rental.deposit or 0,
			status = vehicleStatus(rental, station)
		}
	end
	Core.Events.ToClient(playerId, 'rentals.menu', station.id, vehicles, current)
end)

-- Devolução no balcão: o veículo alugado precisa estar estacionado perto da estação e vazio.
Core.Events.OnNet('rentals.returnAtCounter', function(stationId)
	local playerId = source
	if throttled(playerId) then
		notify(playerId, 'warning', _t('busy'))
		return
	end
	local characterId = getCharacterId(playerId)
	local station = findStation(stationId)
	local rental = characterId and activeRentals[characterId]
	if not station or not rental then
		notify(playerId, 'warning', _t('not_your_rental'))
		return
	end
	if not near(playerCoords(playerId), station.ped, RentalsConfig.InteractRadius or 6.0) then
		notify(playerId, 'error', _t('too_far'))
		return
	end
	local status = vehicleStatus(rental, station)
	if status == VEHICLE_LOST then
		notify(playerId, 'warning', _t('vehicle_lost_use_end'))
		return
	end
	if status ~= VEHICLE_OK then
		notify(playerId, 'warning', _t('vehicle_not_near_station'))
		return
	end
	if vehicleOccupied(rental.entity) then
		notify(playerId, 'warning', _t('vehicle_occupied'))
		return
	end
	local refunded = finishRental(characterId, playerId, true, 'counter')
	if refunded == (rental.deposit or 0) then
		notify(playerId, 'success', _t('return_success', { deposit = refunded }))
	end
end)

-- Encerrar sem o veículo (destruído ou sumiu): a caução fica retida e o jogador pode alugar de novo.
Core.Events.OnNet('rentals.endRental', function(stationId)
	local playerId = source
	if throttled(playerId) then
		notify(playerId, 'warning', _t('busy'))
		return
	end
	local characterId = getCharacterId(playerId)
	local station = findStation(stationId)
	local rental = characterId and activeRentals[characterId]
	if not station or not rental then
		notify(playerId, 'warning', _t('not_your_rental'))
		return
	end
	if not near(playerCoords(playerId), station.ped, RentalsConfig.InteractRadius or 6.0) then
		notify(playerId, 'error', _t('too_far'))
		return
	end
	if vehicleStatus(rental, station) ~= VEHICLE_LOST then
		notify(playerId, 'warning', _t('vehicle_still_exists'))
		return
	end
	finishRental(characterId, playerId, false, 'lost')
	notify(playerId, 'info', _t('rental_ended', { deposit = rental.deposit or 0 }))
end)

-- Documento: usar o contrato no inventário mostra os dados na tela.
Core.Events.On('inventory.itemUsed', function(inventoryId, _slot, item)
	if type(item) ~= 'table' or item.name ~= CONTRACT_ITEM or type(item.metadata) ~= 'table' then
		return
	end
	local characterId = type(inventoryId) == 'string' and inventoryId:match('^character:(.+)$')
	if not characterId then
		return
	end
	for _, id in ipairs(GetPlayers()) do
		local playerId = tonumber(id)
		if getCharacterId(playerId) == characterId then
			local data = item.metadata
			local rental = activeRentals[characterId]
			TriggerClientEvent('coe_rentals:document', playerId, {
				plate = data.plate, vehicle = data.vehicle, model = data.model, renter = data.renter, stateId = data.stateId,
				station = data.station, rentedAt = data.rentedAtText, price = data.price, deposit = data.deposit,
				active = rental ~= nil and rental.plate == data.plate
			})
			return
		end
	end
end)

-- Contratos e chaves de aluguéis que já acabaram (reinício, queda) saem do inventário ao carregar o personagem.
local function purgeStaleItems(playerId, characterId)
	local inventoryId = playerInventory(playerId)
	if not inventoryId then
		return
	end
	local ok, snapshot = pcall(function()
		return exports.coe_inventory:GetInventory(inventoryId)
	end)
	if not ok or type(snapshot) ~= 'table' or type(snapshot.items) ~= 'table' then
		return
	end
	local active = activeRentals[characterId]
	local plates = {}
	for _, item in pairs(snapshot.items) do
		if type(item) == 'table' and type(item.metadata) == 'table' and type(item.metadata.plate) == 'string'
			and (item.name == CONTRACT_ITEM or (item.name == KEY_ITEM and item.metadata.rental == true))
			and not (active and active.plate == item.metadata.plate) then
			plates[item.metadata.plate] = true
		end
	end
	for plate in pairs(plates) do
		removeRentalItems(inventoryId, plate)
	end
end

Core.Events.On('player.characterLoaded', function(payload)
	local playerId = type(payload) == 'table' and tonumber(payload.source) or nil
	local character = type(payload) == 'table' and payload.character or nil
	local characterId = type(character) == 'table' and (character.characterId or character.id) or nil
	if playerId and characterId then
		CreateThread(function()
			Wait(2000)
			purgeStaleItems(playerId, tostring(characterId))
		end)
	end
end)

AddEventHandler('playerDropped', function()
	local playerId = source
	lastRequest[playerId] = nil
	local characterId = getCharacterId(playerId)
	if characterId and activeRentals[characterId] then
		finishRental(characterId, nil, false, 'dropped')
	end
end)

-- Painel (coe_staff e pacotes com ACE) ----------------------------------------------------------------------------

local function saveStation(raw)
	if not ready then
		return nil, 'not_ready'
	end
	local station, errorCode = RentalsStations.Normalize(raw, RentalsConfig.Limits)
	if not station then
		return nil, errorCode
	end
	for _, model in ipairs(station.vehicles) do
		if not RentalsRules.FindVehicle(RentalsConfig, model) then
			return nil, 'invalid_vehicles'
		end
	end
	local saved, saveError = RentalsPersistence.SaveStation(station)
	if not saved then
		return nil, saveError
	end
	stations[station.id] = station
	local list = {}
	for _, entry in pairs(stations) do
		list[#list + 1] = entry
	end
	setStations(list)
	broadcast()
	log('info', 'station_saved', { station = station.id })
	return station
end

local function deleteStation(stationId)
	if not ready then
		return nil, 'not_ready'
	end
	if not findStation(stationId) then
		return nil, 'unknown_station'
	end
	local deleted, errorCode = RentalsPersistence.DeleteStation(stationId)
	if not deleted then
		return nil, errorCode
	end
	stations[stationId] = nil
	local list = {}
	for _, entry in pairs(stations) do
		list[#list + 1] = entry
	end
	setStations(list)
	broadcast()
	log('info', 'station_deleted', { station = stationId })
	return true
end

local function catalogList()
	local list = {}
	for _, vehicle in ipairs(RentalsConfig.Vehicles or {}) do
		list[#list + 1] = { model = vehicle.model, label = vehicle.label, category = vehicle.category, price = vehicle.price, deposit = vehicle.deposit }
	end
	return list
end

local function packed(result, errorCode)
	if result == nil then
		return { error = errorCode or 'database_error' }
	end
	return result
end

local function adminCaller()
	return CoeAccess.Allowed(GetInvokingResource(), RentalsConfig.AdminAce or 'coe.rentals.admin', RentalsConfig.AdminResources or {})
end

exports('ListStations', function()
	return adminCaller() and stationOrder or {}
end)

exports('SaveStation', function(raw)
	if not adminCaller() then
		return { error = 'forbidden' }
	end
	return packed(saveStation(raw))
end)

exports('DeleteStation', function(stationId)
	if not adminCaller() then
		return { error = 'forbidden' }
	end
	return packed(deleteStation(stationId))
end)

exports('Catalog', function()
	return catalogList()
end)

local function registerStaffProvider()
	if GetResourceState('coe_staff') ~= 'started' then
		return
	end
	pcall(function()
		exports.coe_staff:RegisterRentalsProvider({
			resource = GetCurrentResourceName(),
			List = function() return stationOrder end,
			Save = function(raw) return packed(saveStation(raw)) end,
			Delete = function(stationId) return packed(deleteStation(stationId)) end,
			Catalog = function() return catalogList() end
		})
	end)
end

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

RegisterNetEvent('coe_rentals:requestStations', function()
	broadcast(source)
end)

CreateThread(function()
	while true do
		local initialized, errorCode = RentalsPersistence.Initialize()
		if initialized then
			local loaded, loadError = loadStations()
			if loaded then
				break
			end
			errorCode = loadError
		end
		log('warn', 'database_waiting', { error_code = tostring(errorCode) })
		Wait(2000)
	end
	ready = true
	broadcast()
	registerStaffProvider()
	log('info', 'rentals_ready', { stations = #stationOrder })
end)

exports('GetActiveRental', function(characterId)
	return activeRentals[tostring(characterId)]
end)
