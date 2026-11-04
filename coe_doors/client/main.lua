local doors = {}
local registered = {}
local nearest = nil
local promptShown = false
local pinOpen = false
local pending = false

local INTERACT = 38
-- Garagens e portões: "Abrir" mantém as folhas abertas (a pé ou de carro); "Fechar" fecha e tranca.
local WIDE_AUTOMATIC_DISTANCE = 20.0

local function isWide(door)
	return door.kind == 'garage' or door.kind == 'gate'
end

local function send(message)
	SendNUIMessage(message)
end

local function setPrompt(prompt)
	local key = prompt and (prompt.title .. '|' .. prompt.subtitle .. '|' .. prompt.options[1].label) or nil
	if key ~= promptShown then
		send({ action = 'prompt', data = prompt })
		promptShown = key
	end
end

local function leafHash(doorId, index)
	return joaat(('coe_door:%s:%d'):format(doorId, index))
end

local function applyState(door)
	local wide = isWide(door)
	for index in ipairs(door.doors) do
		local hash = leafHash(door.id, index)
		if IsDoorRegisteredWithSystem(hash) then
			if wide then
				-- A abertura automática do jogo só reage a veículos; mantém aberto à força para quem está a pé.
				DoorSystemSetHoldOpen(hash, not door.locked)
				if not door.locked then
					DoorSystemSetOpenRatio(hash, 1.0, false, false)
				end
			end
			DoorSystemSetDoorState(hash, door.locked and 1 or 0, false, false)
		end
	end
end

local function unregisterAll()
	for hash in pairs(registered) do
		if IsDoorRegisteredWithSystem(hash) then
			RemoveDoorFromSystem(hash)
		end
	end
	registered = {}
end

local function leafSignature(door, leaf)
	return ('%d|%.3f|%.3f|%.3f|%s'):format(leaf.model, leaf.x, leaf.y, leaf.z, isWide(door) and 'w' or 'n')
end

local syncGeneration = 0

-- Sincroniza o sistema de portas com a lista atual sem remover e re-adicionar a mesma folha no mesmo frame:
-- o jogo não conclui a remoção a tempo e o novo registro falha em silêncio (a porta para de trancar).
local function registerAll()
	syncGeneration = syncGeneration + 1
	local generation = syncGeneration
	local wanted = {}
	for _, door in pairs(doors) do
		for index, leaf in ipairs(door.doors) do
			wanted[leafHash(door.id, index)] = { door = door, leaf = leaf, signature = leafSignature(door, leaf) }
		end
	end
	local removed = false
	for hash, signature in pairs(registered) do
		local target = wanted[hash]
		if not target or target.signature ~= signature then
			if IsDoorRegisteredWithSystem(hash) then
				RemoveDoorFromSystem(hash)
			end
			registered[hash] = nil
			removed = true
		end
	end
	CreateThread(function()
		if removed then
			Wait(0)
		end
		for attempt = 1, 10 do
			if generation ~= syncGeneration then
				return
			end
			local missing = false
			for hash, target in pairs(wanted) do
				if not registered[hash] or not IsDoorRegisteredWithSystem(hash) then
					local leaf = target.leaf
					AddDoorToSystem(hash, leaf.model, leaf.x + 0.0, leaf.y + 0.0, leaf.z + 0.0, false, false, false)
					if IsDoorRegisteredWithSystem(hash) then
						if isWide(target.door) then
							DoorSystemSetAutomaticDistance(hash, WIDE_AUTOMATIC_DISTANCE, false, false)
						end
						registered[hash] = target.signature
					else
						missing = true
					end
				end
			end
			for _, door in pairs(doors) do
				applyState(door)
			end
			if not missing then
				return
			end
			Wait(100 * attempt)
		end
	end)
end

local function closePin()
	if pinOpen then
		pinOpen = false
		SetNuiFocus(false, false)
		send({ type = 'pinClose' })
	end
end

local function rebuildDoorZones()
	if not (Core and Core.Zones) then
		return
	end
	Core.Zones.Clear()
	for _, door in pairs(doors) do
		local center = door.center
		if center then
			Core.Zones.AddSphere('door:' .. tostring(door.id), {
				x = center.x,
				y = center.y,
				z = center.z,
				radius = door.distance or 2.0,
				data = door
			})
		end
	end
end

RegisterNetEvent('coe_doors:list', function(list)
	doors = {}
	for _, door in ipairs(type(list) == 'table' and list or {}) do
		doors[door.id] = door
	end
	nearest = nil
	rebuildDoorZones()
	registerAll()
end)

RegisterNetEvent('coe_doors:state', function(doorId, locked)
	local door = doors[doorId]
	if not door then
		return
	end
	door.locked = locked == true
	pending = false
	applyState(door)
end)

RegisterNetEvent('coe_doors:askPin', function(doorId, label, locked)
	pending = false
	if not doors[doorId] then
		return
	end
	pinOpen = true
	setPrompt(nil)
	SetNuiFocus(true, true)
	send({ type = 'pin', id = doorId, label = label, locked = locked == true })
end)

RegisterNetEvent('coe_doors:pinResult', function(doorId, success)
	if success then
		closePin()
	else
		send({ type = 'pinWrong', id = doorId })
	end
end)

RegisterNUICallback('pin', function(data, callback)
	callback({})
	if pinOpen and type(data) == 'table' and type(data.id) == 'string' and type(data.pin) == 'string' and #data.pin <= 8 then
		TriggerServerEvent('coe_doors:pin', data.id, data.pin)
	end
end)

RegisterNUICallback('close', function(_, callback)
	callback({})
	closePin()
end)

local function playKeyAnimation()
	local ped = PlayerPedId()
	if IsPedInAnyVehicle(ped, false) then
		return
	end
	local dict = 'anim@heists@keycard@'
	RequestAnimDict(dict)
	local deadline = GetGameTimer() + 1000
	while not HasAnimDictLoaded(dict) and GetGameTimer() < deadline do
		Wait(0)
	end
	if HasAnimDictLoaded(dict) then
		TaskPlayAnim(ped, dict, 'exit', 8.0, -8.0, 900, 48, 0.0, false, false, false)
		RemoveAnimDict(dict)
	end
end

local function distanceTo(coords, door)
	local center = door.center
	return #(coords - vector3(center.x, center.y, center.z))
end

if Core and Core.Zones then
	Core.Zones.OnInteract(function()
		local door = nearest
		if not door or pinOpen or pending or IsPauseMenuActive() then
			return
		end
		pending = true
		TriggerServerEvent('coe_doors:toggle', door.id)
		CreateThread(playKeyAnimation)
		SetTimeout(1500, function()
			pending = false
		end)
	end)
end

-- Busca a porta mais próxima via grade espacial (Core.Zones) e atualiza o prompt sem loop Wait(0).
CreateThread(function()
	while true do
		local coords = GetEntityCoords(PlayerPedId())
		local zone, _, nearAny = Core and Core.Zones and Core.Zones.Nearest(coords.x, coords.y, coords.z)
		local best = zone and zone.data or nil
		if not (Core and Core.Zones) then
			local bestDistance = nil
			for _, door in pairs(doors) do
				local distance = distanceTo(coords, door)
				if distance <= door.distance and (not bestDistance or distance < bestDistance) then
					best, bestDistance = door, distance
				end
			end
		end
		nearest = best
		if best and not pinOpen and not IsPauseMenuActive() then
			local wide = isWide(best)
			setPrompt({
				title = best.label,
				subtitle = wide and (best.locked and 'Fechado' or 'Aberto') or (best.locked and 'Trancada' or 'Destrancada'),
				options = { { key = 'E', label = wide and (best.locked and 'Abrir' or 'Fechar') or (best.locked and 'Destrancar' or 'Trancar') } }
			})
		else
			setPrompt(nil)
		end
		Wait((best or nearAny) and 200 or 600)
	end
end)

CreateThread(function()
	while GetResourceState('coe_core') ~= 'started' do
		Wait(500)
	end
	Wait(1000)
	TriggerServerEvent('coe_doors:request')
end)

AddEventHandler('onResourceStop', function(resourceName)
	if resourceName == GetCurrentResourceName() then
		unregisterAll()
		if pinOpen then
			SetNuiFocus(false, false)
		end
	end
end)
