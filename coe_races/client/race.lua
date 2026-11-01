-- A corrida no client: rota até o grid, alinhamento, contagem com o carro preso, largada fantasma (sem colisão entre
-- os corredores nos primeiros segundos), checkpoints com marcador e GPS, HUD e resultado. Quem decide é o servidor:
-- o client avisa que cruzou e só avança quando ele confirma.
local config = RacesConfig
local Client = RacesClient
local T = Client.T

local race = nil         -- { id, data, phase, progress, total, perLap }
local startBlip = nil
local markers = {}       -- checkpoints nativos (o próximo e o seguinte)
local blips = {}
local ghostUntil = 0
local ghostVehicles = {}
local frozen = nil
local pendingIndex, pendingAt = nil, 0
local warnedAt = 0

local function dist2d(ax, ay, bx, by)
	local dx, dy = ax - bx, ay - by
	return math.sqrt(dx * dx + dy * dy)
end

local function myVehicle()
	local ped = PlayerPedId()
	local vehicle = GetVehiclePedIsIn(ped, false)
	if vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == ped then
		return vehicle
	end
	return nil
end

local function removeStartBlip()
	if startBlip then
		RemoveBlip(startBlip)
		startBlip = nil
	end
end

local function clearMarkers()
	for _, marker in ipairs(markers) do
		DeleteCheckpoint(marker)
	end
	markers = {}
	for _, blip in ipairs(blips) do
		RemoveBlip(blip)
	end
	blips = {}
end

local function unfreeze()
	if frozen and DoesEntityExist(frozen) then
		FreezeEntityPosition(frozen, false)
	end
	frozen = nil
end

local function resetGhost()
	for _, vehicle in ipairs(ghostVehicles) do
		if DoesEntityExist(vehicle) then
			ResetEntityAlpha(vehicle)
		end
	end
	ghostVehicles = {}
	ghostUntil = 0
end

local function clear()
	removeStartBlip()
	clearMarkers()
	unfreeze()
	resetGhost()
	pendingIndex = nil
	race = nil
end
Client.Cleanup = function()
	clear()
	Client.Hud('clear')
end

-- Checkpoint `index` (1..total) e o que vem depois dele (para a seta apontar).
local function checkpointAt(index)
	local list = race.data.checkpoints
	return list[((index - 1) % race.perLap) + 1]
end

local function isFinal(index)
	return index == race.total
end

local function drawCheckpoints()
	clearMarkers()
	if not race or race.phase ~= 'countdown' and race.phase ~= 'running' then
		return
	end
	local index = race.progress + 1
	if index > race.total then
		return
	end
	for offset = 0, 1 do
		local i = index + offset
		if i <= race.total then
			local cp = checkpointAt(i)
			local after = (i < race.total) and checkpointAt(i + 1) or cp
			local radius = cp.r or config.Tracks.CheckpointRadius
			local final = isFinal(i)
			local alpha = offset == 0 and 170 or 70
			-- Tipo 4: bandeira quadriculada (chegada); tipo 0: seta para o checkpoint seguinte.
			local marker = CreateCheckpoint(final and 4 or 0, cp.x, cp.y, cp.z - 1.0, after.x, after.y, after.z, radius,
				final and 255 or 255, final and 255 or 196, final and 255 or 0, alpha, 0)
			SetCheckpointCylinderHeight(marker, 6.0, 6.0, radius)
			markers[#markers + 1] = marker
			local blip = AddBlipForCoord(cp.x, cp.y, cp.z)
			SetBlipSprite(blip, final and 38 or 1)
			SetBlipColour(blip, offset == 0 and 5 or 4)
			SetBlipScale(blip, offset == 0 and 1.0 or 0.7)
			if not final then
				ShowNumberOnBlip(blip, ((i - 1) % race.perLap) + 1)
			end
			if offset == 0 then
				SetBlipRoute(blip, true)
				SetBlipRouteColour(blip, 5)
			end
			blips[#blips + 1] = blip
		end
	end
end

local function lapOf(progress)
	return math.min(race.data.laps, (progress // race.perLap) + 1)
end

local function sendProgress()
	Client.Hud('progress', {
		checkpoint = race.progress, total = race.total, lap = lapOf(race.progress), laps = race.data.laps,
		perLap = race.perLap
	})
end

-- Inscrito: blip e rota até a largada.
RegisterNetEvent('coe_races:joined', function(data)
	if type(data) ~= 'table' or type(data.checkpoints) ~= 'table' then
		return
	end
	clear()
	race = { id = data.id, data = data, phase = 'lobby', progress = 0, perLap = #data.checkpoints, total = #data.checkpoints * data.laps }
	startBlip = AddBlipForCoord(data.start.x, data.start.y, data.start.z)
	SetBlipSprite(startBlip, 315)
	SetBlipColour(startBlip, 5)
	SetBlipRoute(startBlip, true)
	SetBlipRouteColour(startBlip, 5)
	BeginTextCommandSetBlipName('STRING')
	AddTextComponentSubstringPlayerName(T('blip_start', { track = data.name }))
	EndTextCommandSetBlipName(startBlip)
	Client.Hud('lobby', { name = data.name, laps = data.laps, kind = data.kind, startsIn = data.startsIn, racers = data.racers })
	Client.Notify('info', T('joined_go_to_grid', { track = data.name }))
end)

RegisterNetEvent('coe_races:left', function(raceId, reason)
	if race and race.id == raceId then
		clear()
		Client.Hud('clear')
		if reason == 'left' then
			Client.Notify('info', T('left_race'))
		end
	end
end)

-- Alinhamento: o servidor confere quem está no grid, no carro e na classe certa.
RegisterNetEvent('coe_races:prepare', function(data)
	if not race or type(data) ~= 'table' or data.id ~= race.id then
		return
	end
	race.phase = 'prepare'
	Client.Hud('prepare', { name = race.data.name })
	local vehicle = myVehicle()
	if not vehicle then
		Client.Notify('error', T('need_vehicle_on_grid'))
		return
	end
	local here = GetEntityCoords(vehicle)
	local sirens = false
	for _, other in ipairs(GetGamePool('CVehicle')) do
		if other ~= vehicle and GetVehicleClass(other) == 18 and IsVehicleSirenOn(other) then
			local at = GetEntityCoords(other)
			if dist2d(here.x, here.y, at.x, at.y) <= config.Police.SirenRadius then
				sirens = true
				break
			end
		end
	end
	local label = GetLabelText(GetDisplayNameFromVehicleModel(GetEntityModel(vehicle)))
	if label == 'NULL' then
		label = GetDisplayNameFromVehicleModel(GetEntityModel(vehicle))
	end
	TriggerServerEvent('coe_races:ready', race.id, {
		netId = NetworkGetNetworkIdFromEntity(vehicle), classId = GetVehicleClass(vehicle), label = label, sirens = sirens
	})
end)

-- Contagem: carro preso, checkpoints na tela e fantasma ligado.
RegisterNetEvent('coe_races:race', function(data)
	if not race or type(data) ~= 'table' or data.id ~= race.id then
		return
	end
	removeStartBlip()
	race.data = data
	race.phase = 'countdown'
	race.progress = 0
	race.perLap = #data.checkpoints
	race.total = race.perLap * data.laps
	local vehicle = myVehicle()
	if vehicle then
		frozen = vehicle
		FreezeEntityPosition(vehicle, true)
	end
	ghostVehicles = {}
	for _, netId in ipairs(data.vehicles or {}) do
		if NetworkDoesNetworkIdExist(netId) then
			local other = NetToVeh(netId)
			if other ~= 0 and other ~= vehicle then
				ghostVehicles[#ghostVehicles + 1] = other
			end
		end
	end
	ghostUntil = GetGameTimer() + (data.goIn or 0) + (data.ghostSeconds or config.Races.GhostSeconds) * 1000
	drawCheckpoints()
	Client.Hud('countdown', { name = data.name, goIn = data.goIn, laps = data.laps, racers = data.racers })
	sendProgress()
end)

RegisterNetEvent('coe_races:go', function(data)
	if not race or type(data) ~= 'table' or data.id ~= race.id then
		return
	end
	unfreeze()
	race.phase = 'running'
	ghostUntil = GetGameTimer() + (race.data.ghostSeconds or config.Races.GhostSeconds) * 1000
	PlaySoundFrontend(-1, 'GO', 'HUD_MINI_GAME_SOUNDSET', true)
	Client.Hud('go', { ghostSeconds = race.data.ghostSeconds })
end)

RegisterNetEvent('coe_races:checkpointOk', function(raceId, index)
	if not race or race.id ~= raceId or race.phase ~= 'running' or type(index) ~= 'number' or index <= race.progress then
		return
	end
	race.progress = index
	pendingIndex = nil
	PlaySoundFrontend(-1, 'CHECKPOINT_NORMAL', 'HUD_MINI_GAME_SOUNDSET', true)
	drawCheckpoints()
	sendProgress()
end)

RegisterNetEvent('coe_races:lap', function(raceId, lap, lapMs, bestMs)
	if race and race.id == raceId then
		Client.Hud('lap', { lap = lap, lapMs = lapMs, bestMs = bestMs, laps = race.data.laps })
	end
end)

RegisterNetEvent('coe_races:finished', function(raceId, timeMs)
	if race and race.id == raceId then
		race.phase = 'finished'
		clearMarkers()
		resetGhost()
		PlaySoundFrontend(-1, 'CHECKPOINT_PERFECT', 'HUD_MINI_GAME_SOUNDSET', true)
		Client.Hud('finished', { timeMs = timeMs })
	end
end)

RegisterNetEvent('coe_races:leaderFinished', function(data)
	if race and type(data) == 'table' and data.id == race.id and race.phase == 'running' then
		Client.Hud('leader', { nickname = data.nickname, seconds = data.seconds })
	end
end)

RegisterNetEvent('coe_races:dnf', function(raceId, reason)
	if race and race.id == raceId then
		race.phase = 'dnf'
		clearMarkers()
		unfreeze()
		resetGhost()
		Client.Hud('dnf', { reason = reason })
	end
end)

RegisterNetEvent('coe_races:standings', function(data)
	if race and type(data) == 'table' and data.id == race.id then
		Client.Hud('standings', data)
	end
end)

RegisterNetEvent('coe_races:results', function(data)
	if type(data) ~= 'table' then
		return
	end
	if race and race.id == data.id then
		clear()
	end
	Client.Hud('results', data)
end)

-- Sair da corrida (lobby: devolve a entrada; correndo: abandono).
RegisterCommand(config.QuitCommand, function()
	if race then
		TriggerServerEvent('coe_races:quit', race.id)
		if race.phase ~= 'lobby' then
			clear()
			Client.Hud('clear')
		end
	end
end, false)

-- Laço da corrida: fantasma, carro preso na contagem, checkpoint cruzado (reenvia enquanto não confirmar) e aviso de
-- quem saiu do carro.
CreateThread(function()
	while true do
		if race and (race.phase == 'countdown' or race.phase == 'running') then
			local now = GetGameTimer()
			local vehicle = myVehicle()
			if now < ghostUntil and vehicle then
				for _, other in ipairs(ghostVehicles) do
					if DoesEntityExist(other) then
						SetEntityNoCollisionEntity(vehicle, other, true)
						SetEntityNoCollisionEntity(other, vehicle, true)
						SetEntityAlpha(other, 150, false)
					end
				end
			elseif #ghostVehicles > 0 then
				resetGhost()
			end
			if race.phase == 'countdown' then
				DisableControlAction(0, 71, true) -- acelerar
				DisableControlAction(0, 72, true) -- ré
			elseif vehicle then
				local index = race.progress + 1
				if index <= race.total then
					local cp = checkpointAt(index)
					local at = GetEntityCoords(vehicle)
					local radius = cp.r or config.Tracks.CheckpointRadius
					if dist2d(at.x, at.y, cp.x, cp.y) <= radius and math.abs(at.z - cp.z) <= 15.0
						and (pendingIndex ~= index or now - pendingAt > 1000) then
						pendingIndex, pendingAt = index, now
						TriggerServerEvent('coe_races:checkpoint', race.id, index)
					end
				end
			end
			if race.phase == 'running' and not vehicle and now - warnedAt > 1000 then
				warnedAt = now
				Client.Hud('warning', { text = T('back_to_vehicle', { seconds = config.Races.OutOfVehicleSeconds }) })
			end
			Wait(0)
		else
			Wait(500)
		end
	end
end)
