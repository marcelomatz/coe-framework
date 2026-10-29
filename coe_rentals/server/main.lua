-- Servidor de aluguel de veículos populares com caução e devolução.
local activeRentals = {} -- characterId -> { entity, netId, plate, model, deposit, stationId }
local _t = Core.Locale.Init('coe_rentals', RentalsConfig.Locale or 'pt-BR')

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
	return Core.Players.GetActiveCharacterId(playerId)
end

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

	local station = RentalsRules.FindStation(RentalsConfig, stationId)
	if not station then
		notify(playerId, 'error', _t('station_not_found'))
		return
	end
	if not RentalsRules.IsNear(playerCoords(playerId), station.coords, RentalsConfig.InteractRadius or 6.0) then
		log('warn', 'rental_denied', { player_id = playerId, error_code = 'too_far', station = stationId })
		notify(playerId, 'error', _t('too_far'))
		return
	end

	local vehicleDef = RentalsRules.FindVehicle(RentalsConfig, model)
	if not vehicleDef then
		notify(playerId, 'error', _t('vehicle_not_available'))
		return
	end

	local canRent, rentErr = RentalsRules.CanRent(characterId, activeRentals)
	if not canRent then
		notify(playerId, 'warning', _t(rentErr or 'already_rented'))
		return
	end

	local price, deposit, total = RentalsRules.CalculateTotal(vehicleDef)
	local debited, debitError = economy(function() return exports.coe_economy:Debit(characterId, total, 'vehicle_rental') end)
	if debited ~= true then
		notify(playerId, 'error', _t(debitError == 'economy_unavailable' and 'economy_unavailable' or 'not_enough_money'))
		return
	end

	local plate = RentalsRules.GenerateRentalPlate()
	local spawnPoint = station.spawn
	local modelHash = joaat(vehicleDef.model)

	local entity = CreateVehicle(modelHash, spawnPoint.x, spawnPoint.y, spawnPoint.z, spawnPoint.h or 0.0, true, true)
	if not DoesEntityExist(entity) then
		-- Reembolso de segurança caso o spawn falhe
		if economy(function() return exports.coe_economy:Credit(characterId, total, 'rental_refund_spawn_failed') end) ~= true then
			log('error', 'rental_refund_failed', { character_id = characterId, total = total })
		end
		notify(playerId, 'error', _t('vehicle_spawn_failed'))
		return
	end

	SetVehicleNumberPlateText(entity, plate)
	local netId = NetworkGetNetworkIdFromEntity(entity)

	activeRentals[characterId] = {
		entity = entity,
		netId = netId,
		plate = plate,
		model = vehicleDef.model,
		deposit = deposit,
		stationId = stationId,
		rentedAt = os.time()
	}

	-- Veículo destrancado para o locatário
	SetVehicleDoorsLocked(entity, 1)

	log('info', 'vehicle_rented', { character_id = characterId, model = vehicleDef.model, plate = plate, total = total, deposit = deposit })
	notify(playerId, 'success', _t('rent_success', { model = vehicleDef.label or vehicleDef.model, deposit = deposit }))
	Core.Events.ToClient(playerId, 'rentals.spawned', netId, plate, deposit)
end)

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

	local station = RentalsRules.FindStation(RentalsConfig, stationId)
	if not station then
		notify(playerId, 'error', _t('station_not_found'))
		return
	end

	if not RentalsRules.IsNear(playerCoords(playerId), station.returnZone or station.coords, (station.returnZone and station.returnZone.radius or 0) + (RentalsConfig.InteractRadius or 6.0)) then
		notify(playerId, 'error', _t('too_far'))
		return
	end

	local ped = GetPlayerPed(playerId)
	local veh = GetVehiclePedIsIn(ped, false)
	if veh == 0 or veh ~= rental.entity then
		notify(playerId, 'warning', _t('not_in_vehicle'))
		return
	end

	-- Deleta a entidade do veículo com segurança
	DeleteEntity(veh)
	local depositAmount = rental.deposit or 0

	-- Reembolsa o caução ao jogador
	local refunded = depositAmount
	if depositAmount > 0 and economy(function() return exports.coe_economy:Credit(characterId, depositAmount, 'vehicle_rental_deposit') end) ~= true then
		refunded = 0
		log('error', 'rental_refund_failed', { character_id = characterId, plate = rental.plate, total = depositAmount })
		notify(playerId, 'error', _t('refund_failed'))
	end

	activeRentals[characterId] = nil
	log('info', 'vehicle_returned', { character_id = characterId, plate = rental.plate, refunded_deposit = refunded })
	if refunded == depositAmount then
		notify(playerId, 'success', _t('return_success', { deposit = depositAmount }))
	end
	Core.Events.ToClient(playerId, 'rentals.returned')
end)

AddEventHandler('playerDropped', function()
	local playerId = source
	lastRequest[playerId] = nil
	local characterId = getCharacterId(playerId)
	if characterId and activeRentals[characterId] then
		local r = activeRentals[characterId]
		if DoesEntityExist(r.entity) then
			DeleteEntity(r.entity)
		end
		activeRentals[characterId] = nil
	end
end)

exports('GetActiveRental', function(characterId)
	return activeRentals[characterId]
end)
