local stations = {}
local blips = {}
local menuOpen = false

local function showHelp(text)
	BeginTextCommandDisplayHelp('STRING')
	AddTextComponentSubstringPlayerName(text)
	EndTextCommandDisplayHelp(0, false, true, -1)
end

local function clearBlips()
	for _, blip in ipairs(blips) do
		if DoesBlipExist(blip) then
			RemoveBlip(blip)
		end
	end
	blips = {}
end

local function createBlips()
	clearBlips()
	for _, st in ipairs(stations) do
		local b = st.blip
		if b and b.enabled ~= false then
			local blip = AddBlipForCoord(st.x + 0.0, st.y + 0.0, st.z + 0.0)
			SetBlipSprite(blip, tonumber(b.sprite) or 357)
			SetBlipColour(blip, tonumber(b.color) or 3)
			SetBlipScale(blip, (tonumber(b.scale) or 0.8) + 0.0)
			SetBlipAsShortRange(blip, true)
			BeginTextCommandSetBlipName('STRING')
			AddTextComponentSubstringPlayerName(st.title or 'Garagem Pública')
			EndTextCommandSetBlipName(blip)
			blips[#blips + 1] = blip
		end
	end
end

RegisterNetEvent('coe_garage:syncStations', function(list)
	stations = type(list) == 'table' and list or {}
	createBlips()
end)

AddEventHandler('onResourceStop', function(res)
	if res == GetCurrentResourceName() then
		clearBlips()
		if menuOpen then
			SetNuiFocus(false, false)
		end
	end
end)

CreateThread(function()
	Wait(1000)
	TriggerServerEvent('coe_garage:requestStations')
end)

-- Loop principal otimizado (0.00ms em repouso)
CreateThread(function()
	while true do
		local sleep = 1000
		local ped = PlayerPedId()
		local coords = GetEntityCoords(ped)
		local inVeh = IsPedInAnyVehicle(ped, false)
		local vehicle = inVeh and GetVehiclePedIsIn(ped, false) or 0
		local isDriver = inVeh and GetPedInVehicleSeat(vehicle, -1) == ped

		local nearest = nil
		local nearestDist = 9999.0

		for _, st in ipairs(stations) do
			local dist = #(coords - vector3(st.x, st.y, st.z))
			if dist < nearestDist then
				nearestDist = dist
				nearest = st
			end
		end

		if nearest and nearestDist <= 20.0 then
			sleep = 100
			local radius = nearest.radius or 3.5
			if nearestDist <= radius then
				sleep = 0
				if not inVeh then
					showHelp(_t('prompt_open_garage'))
					if IsControlJustPressed(0, 38) then -- Tecla E
						TriggerServerEvent('coe_garage:getStoredVehicles', nearest.garageId, nearest.spotId)
						Wait(500)
					end
				elseif isDriver and NetworkGetEntityIsNetworked(vehicle) then
					showHelp(_t('prompt_store_vehicle'))
					if IsControlJustPressed(0, 38) then -- Tecla E
						local netId = NetworkGetNetworkIdFromEntity(vehicle)
						TriggerServerEvent('coe_garage:storeVehicle', nearest.garageId, nearest.spotId, netId)
						Wait(1000)
					end
				end
			end
		end

		Wait(sleep)
	end
end)

-- Interface NUI
RegisterNetEvent('coe_garage:openMenu', function(garageId, spotId, vehicles)
	if not vehicles or #vehicles == 0 then
		exports.coe_notify:Notify('info', _t('no_vehicles_stored'))
		return
	end

	menuOpen = true
	SetNuiFocus(true, true)
	SendNUIMessage({
		action = 'open',
		garageId = garageId,
		spotId = spotId,
		vehicles = vehicles
	})
end)

RegisterNetEvent('coe_garage:spawned', function(netId)
	if menuOpen then
		menuOpen = false
		SetNuiFocus(false, false)
		SendNUIMessage({ action = 'close' })
	end

	local deadline = GetGameTimer() + 5000
	while not NetworkDoesNetworkIdExist(netId) and GetGameTimer() < deadline do
		Wait(50)
	end

	local veh = NetworkDoesNetworkIdExist(netId) and NetworkGetEntityFromNetworkId(netId) or 0
	if veh ~= 0 and DoesEntityExist(veh) then
		TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1)
	end
end)

RegisterNetEvent('coe_garage:stored', function()
	-- Evento disparado quando o veículo é guardado com sucesso
end)

RegisterNUICallback('retrieve', function(data, cb)
	if data and data.garageId and data.spotId and data.vehicleId then
		TriggerServerEvent('coe_garage:retrieveVehicle', data.garageId, data.spotId, data.vehicleId)
	end
	cb({ ok = true })
end)

RegisterNUICallback('close', function(_, cb)
	menuOpen = false
	SetNuiFocus(false, false)
	cb({ ok = true })
end)
