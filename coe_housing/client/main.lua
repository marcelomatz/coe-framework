local doors = {}
local menuOpen = false
local busy = false
local current = nil
local promptShown = false
local insideInfo = nil
local blips = {}

local function send(message)
	SendNUIMessage(message)
end

local function setPrompt(prompt)
	local key = prompt and (prompt.title .. '|' .. prompt.options[1].label) or nil
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
	for _, door in ipairs(doors) do
		local style = door.blip
		if type(style) == 'table' then
			local blip = AddBlipForCoord(door.x + 0.0, door.y + 0.0, door.z + 0.0)
			SetBlipSprite(blip, style.sprite)
			SetBlipColour(blip, style.color)
			SetBlipScale(blip, style.scale + 0.0)
			SetBlipAsShortRange(blip, true)
			BeginTextCommandSetBlipName('STRING')
			AddTextComponentSubstringPlayerName(door.title)
			EndTextCommandSetBlipName(blip)
			blips[#blips + 1] = blip
		end
	end
end

AddEventHandler('onResourceStop', function(resourceName)
	if resourceName == GetCurrentResourceName() then
		clearBlips()
		if menuOpen then
			SetNuiFocus(false, false)
		end
	end
end)

local activeAction = nil

local function rebuildDoorZones()
	if not (Core and Core.Zones) then
		return
	end
	Core.Zones.Clear()
	for idx, door in ipairs(doors) do
		Core.Zones.AddSphere(('door:%d:%s'):format(idx, tostring(door.id)), {
			x = door.x,
			y = door.y,
			z = door.z,
			radius = door.radius,
			data = door
		})
	end
end

RegisterNetEvent('coe_housing:doors', function(list)
	doors = type(list) == 'table' and list or {}
	current = nil
	activeAction = nil
	createBlips()
	rebuildDoorZones()
end)

CreateThread(function()
	while GetResourceState('coe_economy') ~= 'started' do
		Wait(500)
	end
	Wait(1500)
	TriggerServerEvent('coe_housing:requestDoors')
end)

RegisterNetEvent('coe_housing:menu', function(menu)
	busy = false
	menuOpen = true
	SetNuiFocus(true, true)
	send({ type = 'open', menu = menu })
end)

RegisterNetEvent('coe_housing:failed', function()
	busy = false
end)

RegisterNetEvent('coe_housing:entered', function(info)
	closeMenu()
	insideInfo = info
	HousingInteriorLoader.Teleport(info.interior, info.interiorId, true)
	busy = false
end)

-- Ao logar dentro do imóvel, o servidor devolve o jogador ao interior junto com o spawn do personagem;
-- o spawn termina depois e o levaria à última posição na rua. Terminado o spawn, volta para o interior.
-- Espera um frame: o spawn ainda reacende a tela logo após este evento e cancelaria o fade do teleporte.
AddEventHandler('playerSpawned', function()
	CreateThread(function()
		Wait(250)
		if insideInfo then
			HousingInteriorLoader.Teleport(insideInfo.interior, insideInfo.interiorId, true)
		end
	end)
end)

RegisterNetEvent('coe_housing:left', function(door)
	insideInfo = nil
	if door then
		HousingInteriorLoader.Teleport(door, nil, true)
	end
	busy = false
end)

local function nearestDoor()
	local at = GetEntityCoords(PlayerPedId())
	local best, bestDistance
	for _, door in ipairs(doors) do
		local distance = #(at - vector3(door.x, door.y, door.z))
		if distance <= door.radius and (not bestDistance or distance < bestDistance) then
			best, bestDistance = door, distance
		end
	end
	return best
end

-- Longe do interior com o estado de dentro (teleporte de volta falhou): a porta continua disponível.
local function nearInterior()
	local exit = insideInfo and insideInfo.interior
	return exit and #(GetEntityCoords(PlayerPedId()) - vector3(exit.x, exit.y, exit.z)) <= 30.0
end

if Core and Core.Zones then
	Core.Zones.OnInteract(function()
		if menuOpen or busy or not activeAction then
			return
		end
		if activeAction.kind == 'stash' then
			TriggerServerEvent('coe_housing:openStash')
		elseif activeAction.kind == 'leave' then
			busy = true
			TriggerServerEvent('coe_housing:leave')
			SetTimeout(3000, function()
				busy = false
			end)
		elseif activeAction.kind == 'open' and activeAction.door then
			busy = true
			TriggerServerEvent('coe_housing:open', activeAction.door.id)
			SetTimeout(3000, function()
				busy = false
			end)
		end
	end)
end

CreateThread(function()
	while true do
		local wait = 600
		activeAction = nil
		if menuOpen or busy then
			setPrompt(nil)
		elseif insideInfo and nearInterior() then
			wait = 200
			local at = GetEntityCoords(PlayerPedId())
			local exit = insideInfo.interior
			local stash = insideInfo.stash
			local exitDistance = #(at - vector3(exit.x, exit.y, exit.z))
			local stashDistance = stash and #(at - vector3(stash.x, stash.y, stash.z)) or math.huge
			if stash and stashDistance <= stash.radius and stashDistance < exitDistance then
				activeAction = { kind = 'stash' }
				setPrompt({ title = insideInfo.title, subtitle = 'Baú', options = { { key = 'E', label = 'Abrir baú' } } })
			elseif exitDistance <= exit.radius then
				activeAction = { kind = 'leave' }
				setPrompt({ title = insideInfo.title, subtitle = 'Saída', options = { { key = 'E', label = 'Sair' } } })
			else
				setPrompt(nil)
			end
		elseif #doors > 0 and GetVehiclePedIsIn(PlayerPedId(), false) == 0 then
			local at = GetEntityCoords(PlayerPedId())
			local zone, _, nearAny = Core and Core.Zones and Core.Zones.Nearest(at.x, at.y, at.z)
			current = zone and zone.data or nearestDoor()
			if nearAny or current then
				wait = 200
			end
			if current then
				activeAction = { kind = 'open', door = current }
				local subtitle = current.hideout and 'Acesso restrito' or (current.kind == 'commercial' and 'Imóvel comercial' or 'Moradia')
				setPrompt({ title = current.title, subtitle = subtitle, options = { { key = 'E', label = current.hideout and 'Entrar' or 'Abrir' } } })
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

RegisterNUICallback('enter', function(data, cb)
	if current and type(data) == 'table' then
		TriggerServerEvent('coe_housing:enter', current.id)
	end
	cb({})
end)

RegisterNUICallback('rent', function(data, cb)
	if current and type(data) == 'table' and tonumber(data.days) then
		TriggerServerEvent('coe_housing:rent', current.id, tonumber(data.days))
	end
	cb({})
end)

RegisterNUICallback('cancel', function(_, cb)
	if current then
		TriggerServerEvent('coe_housing:cancel', current.id)
	end
	cb({})
end)
