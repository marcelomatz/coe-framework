local stations = {}
local menuOpen = false
local busy = false
local current = nil
local promptShown = false
local pendingStore = nil

local function send(message)
	SendNUIMessage(message)
end

local function setPrompt(prompt)
	local key = prompt and (prompt.subtitle .. '|' .. prompt.options[1].label) or nil
	if key ~= promptShown then
		send({ action = 'prompt', data = prompt })
		promptShown = key
	end
end

local function closeMenu()
	if menuOpen then
		menuOpen = false
		SetNuiFocus(false, false)
		send({ type = 'close' })
	end
end

local blips = {}

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
	for _, station in ipairs(stations) do
		local style = station.blip
		if type(style) == 'table' then
			local blip = AddBlipForCoord(station.x + 0.0, station.y + 0.0, station.z + 0.0)
			SetBlipSprite(blip, style.sprite)
			SetBlipColour(blip, style.color)
			SetBlipScale(blip, style.scale + 0.0)
			SetBlipAsShortRange(blip, true)
			BeginTextCommandSetBlipName('STRING')
			AddTextComponentSubstringPlayerName(station.title)
			EndTextCommandSetBlipName(blip)
			blips[#blips + 1] = blip
		end
	end
end

AddEventHandler('onResourceStop', function(resourceName)
	if resourceName == GetCurrentResourceName() then
		clearBlips()
	end
end)

local function rebuildZones()
	if not (Core and Core.Zones) then
		return
	end
	Core.Zones.Clear()
	for idx, station in ipairs(stations) do
		Core.Zones.AddSphere(('garage:%d:%s:%s'):format(idx, tostring(station.garageId), tostring(station.spotId)), {
			x = station.x,
			y = station.y,
			z = station.z,
			radius = station.radius,
			data = station
		})
	end
end

RegisterNetEvent('coe_garages:stations', function(list)
	stations = type(list) == 'table' and list or {}
	current = nil
	createBlips()
	rebuildZones()
end)

CreateThread(function()
	while GetResourceState('coe_vehicles') ~= 'started' do
		Wait(500)
	end
	Wait(1500)
	TriggerServerEvent('coe_garages:requestStations')
end)

RegisterNetEvent('coe_garages:menu', function(menu)
	busy = false
	menuOpen = true
	SetNuiFocus(true, true)
	send({ type = 'open', menu = menu })
end)

RegisterNetEvent('coe_garages:failed', function()
	busy = false
	pendingStore = nil
end)

-- Guardar aprovado: desembarca e confirma. O veículo some quando o servidor guarda.
RegisterNetEvent('coe_garages:storeApproved', function(netId)
	local request = pendingStore
	if not request or request.netId ~= netId then
		return
	end
	request.leaving = true
	local ped = PlayerPedId()
	local vehicle = NetworkDoesNetworkIdExist(netId) and NetworkGetEntityFromNetworkId(netId) or 0
	if vehicle ~= 0 and IsPedInVehicle(ped, vehicle, false) then
		TaskLeaveVehicle(ped, vehicle, 0)
		local deadline = GetGameTimer() + 4000
		while IsPedInVehicle(ped, vehicle, false) and GetGameTimer() < deadline do
			Wait(100)
		end
	end
	TriggerServerEvent('coe_garages:store', request.garageId, request.spotId, request.netId)
	pendingStore = nil
	SetTimeout(1500, function()
		busy = false
	end)
end)

RegisterNetEvent('coe_garages:spawned', function(netId)
	closeMenu()
	local deadline = GetGameTimer() + 5000
	while not NetworkDoesNetworkIdExist(netId) and GetGameTimer() < deadline do
		Wait(50)
	end
	local vehicle = NetworkDoesNetworkIdExist(netId) and NetworkGetEntityFromNetworkId(netId) or 0
	if vehicle ~= 0 and DoesEntityExist(vehicle) then
		TaskWarpPedIntoVehicle(PlayerPedId(), vehicle, -1)
	end
end)

local function nearest()
	local at = GetEntityCoords(PlayerPedId())
	local best, bestDistance
	for _, station in ipairs(stations) do
		local distance = #(at - vector3(station.x, station.y, station.z))
		if distance <= station.radius and (not bestDistance or distance < bestDistance) then
			best, bestDistance = station, distance
		end
	end
	return best
end

local function activate(station)
	if busy then
		return
	end
	local ped = PlayerPedId()
	local vehicle = GetVehiclePedIsIn(ped, false)
	if vehicle ~= 0 then
		if GetPedInVehicleSeat(vehicle, -1) ~= ped or not NetworkGetEntityIsNetworked(vehicle) then
			return
		end
		busy = true
		-- Primeiro o servidor confere se pode guardar; só então o ped desembarca (coe_garages:storeApproved).
		pendingStore = { garageId = station.garageId, spotId = station.spotId, netId = NetworkGetNetworkIdFromEntity(vehicle) }
		TriggerServerEvent('coe_garages:storeCheck', pendingStore.garageId, pendingStore.spotId, pendingStore.netId)
		SetTimeout(3000, function()
			if pendingStore and not pendingStore.leaving then
				pendingStore = nil
				busy = false
			end
		end)
		return
	end
	busy = true
	TriggerServerEvent('coe_garages:open', station.garageId, station.spotId)
	SetTimeout(3000, function()
		busy = false
	end)
end

if Core and Core.Zones then
	Core.Zones.OnInteract(function()
		if current and not menuOpen then
			activate(current)
		end
	end)
end

CreateThread(function()
	while true do
		local wait = 600
		if #stations > 0 and not menuOpen then
			local at = GetEntityCoords(PlayerPedId())
			local zone, _, nearAny = Core and Core.Zones and Core.Zones.Nearest(at.x, at.y, at.z)
			current = zone and zone.data or nearest()
			if nearAny or current then
				wait = 200
			end
			if current then
				local inVehicle = GetVehiclePedIsIn(PlayerPedId(), false) ~= 0
				setPrompt({
					title = current.title or 'Garagem', subtitle = current.label or '',
					options = { { key = 'E', label = inVehicle and 'Guardar veículo' or 'Abrir garagem' } }
				})
			else
				setPrompt(nil)
			end
		else
			setPrompt(nil)
		end
		Wait(wait)
	end
end)

RegisterNUICallback('close', function(_, cb)
	closeMenu()
	cb({})
end)

RegisterNUICallback('take', function(data, cb)
	if current and type(data) == 'table' and data.vehicleId and not IsAnyVehicleNearPoint(current.x, current.y, current.z, 2.5) then
		TriggerServerEvent('coe_garages:take', current.garageId, current.spotId, tostring(data.vehicleId))
	else
		send({ type = 'notice', text = 'A vaga está ocupada.' })
	end
	cb({})
end)

RegisterNUICallback('access', function(data, cb)
	if current and type(data) == 'table' then
		TriggerServerEvent('coe_garages:access', current.garageId, current.spotId, tostring(data.vehicleId), data.action, data.value)
	end
	cb({})
end)

AddEventHandler('onResourceStop', function(resource)
	if resource == GetCurrentResourceName() and menuOpen then
		SetNuiFocus(false, false)
	end
end)
