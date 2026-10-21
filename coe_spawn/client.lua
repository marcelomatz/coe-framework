local characterLoaded = false
-- Última posição recebida do servidor; usada só no primeiro spawn após carregar o personagem.
local lastPosition = nil
local awaitingPosition = nil
-- Aparência salva do personagem carregado (coe_appearance); vale para o spawn e para os respawns.
local currentAppearance = nil

local function debugPrint(text)
	if CoeSpawnConfig.Debug then
		print(('[coe_spawn] %s'):format(text))
	end
end

-- O ped foi ocultado e congelado durante a seleção; o spawnmanager não reverte isso.
local function dumpState()
	local ped = PlayerPedId()
	local x, y, z = table.unpack(GetEntityCoords(ped))
	debugPrint(('estado: ped=%s modelo=%s coords=%.1f,%.1f,%.1f visivel=%s congelado=%s vida=%s'):format(
		tostring(ped), tostring(GetEntityModel(ped)), x, y, z, tostring(IsEntityVisible(ped)),
		tostring(IsEntityPositionFrozen(ped)), tostring(GetEntityHealth(ped))))
	debugPrint(('estado: fadeOut=%s fadeIn=%s gameplayCam=%s colisao=%s'):format(
		tostring(IsScreenFadedOut()), tostring(IsScreenFadedIn()), tostring(IsGameplayCamRendering()),
		tostring(HasCollisionLoadedAroundEntity(ped))))
	debugPrint(('estado: hora=%s pausa=%s'):format(tostring(GetClockHours()), tostring(IsPauseMenuActive())))
end

local function restorePlayer()
	local ped = PlayerPedId()
	if ped > 0 and DoesEntityExist(ped) then
		SetEntityVisible(ped, true, false)
		FreezeEntityPosition(ped, false)
	end
	SetPlayerControl(PlayerId(), true, 0)
	RenderScriptCams(false, false, 0, true, true)
	DisplayHud(true)
	DisplayRadar(true)
	if currentAppearance and GetResourceState('coe_appearance') == 'started' then
		local applied = pcall(function()
			exports.coe_appearance:Apply(PlayerPedId(), currentAppearance)
		end)
		if not applied then
			debugPrint('falha ao aplicar a aparência')
		end
	end
	DoScreenFadeIn(500)
	debugPrint('personagem spawnado')
	TriggerServerEvent('coe_spawn:spawned')

	if CoeSpawnConfig.Debug then
		CreateThread(function()
			Wait(1500)
			dumpState()
		end)
	end
end

-- Com aparência salva usa o modelo dela (freemode); sem aparência (personagem antigo, ou sem o coe_appearance)
-- sorteia um ped comum, porque um ped freemode sem aparência fica sem rosto.
local function pickModel()
	if currentAppearance and type(currentAppearance.model) == 'string' and GetResourceState('coe_appearance') == 'started' then
		return currentAppearance.model
	end
	local models = CoeSpawnConfig.models
	return models[math.random(#models)]
end

local function spawnCharacter()
	local location = {}
	local origin = lastPosition or CoeSpawnConfig.location
	lastPosition = nil
	for key, value in pairs(origin) do
		location[key] = value
	end
	location.model = pickModel()

	debugPrint(('spawn solicitado em %.1f,%.1f,%.1f, modelo=%s'):format(location.x, location.y, location.z, location.model))
	local ok, errorMessage = pcall(function()
		exports.spawnmanager:spawnPlayer(location, restorePlayer)
	end)
	if not ok then
		debugPrint(('falha no spawn: %s'):format(tostring(errorMessage)))
	end
end

local function freezeForSelection()
	exports.spawnmanager:setAutoSpawn(false)

	-- Sem auto spawn o spawnmanager não encerra a tela de loading; ela cobriria a UI de seleção.
	ShutdownLoadingScreen()
	ShutdownLoadingScreenNui()
	DoScreenFadeIn(0)

	local ped = PlayerPedId()
	if ped > 0 and DoesEntityExist(ped) then
		SetPlayerControl(PlayerId(), false, 0)
		FreezeEntityPosition(ped, true)
		SetEntityVisible(ped, false, false)
	end
end

local function acceptServerEvent()
	return source == 65535
end

Core.Events.OnNet('player.loaded', function()
	if acceptServerEvent() then
		freezeForSelection()
	end
end)

local function beginSpawn(position)
	awaitingPosition = nil
	lastPosition = position
	exports.spawnmanager:setAutoSpawnCallback(spawnCharacter)
	exports.spawnmanager:forceRespawn()
end

Core.Events.OnNet('player.characterLoaded', function(character)
	if not acceptServerEvent() then
		return
	end

	characterLoaded = true
	currentAppearance = type(character) == 'table' and type(character.appearance) == 'table' and character.appearance or nil
	debugPrint('player.characterLoaded recebido')
	if not CoeSpawnConfig.LastPosition.Enabled then
		beginSpawn(nil)
		return
	end
	-- Pede a última posição; sem resposta a tempo, usa o ponto padrão.
	local token = {}
	awaitingPosition = token
	TriggerServerEvent('coe_spawn:requestPosition')
	SetTimeout(CoeSpawnConfig.LastPosition.TimeoutMs + 1000, function()
		if awaitingPosition == token and characterLoaded then
			debugPrint('última posição não chegou; usando o ponto padrão')
			beginSpawn(nil)
		end
	end)
end)

RegisterNetEvent('coe_spawn:position', function(position)
	if not awaitingPosition or not characterLoaded then
		return
	end
	beginSpawn(SpawnPositions.Normalize(position, CoeSpawnConfig.LastPosition.Bounds))
end)

Core.Events.OnNet('player.characterUnloaded', function()
	if not acceptServerEvent() then
		return
	end

	characterLoaded = false
	awaitingPosition = nil
	lastPosition = nil
	currentAppearance = nil
	freezeForSelection()
end)

AddEventHandler('onClientResourceStart', function(resourceName)
	if resourceName == GetCurrentResourceName() and not characterLoaded then
		CreateThread(function()
			exports.spawnmanager:setAutoSpawn(false)
			while not NetworkIsPlayerActive(PlayerId()) do
				Wait(100)
			end
			if not characterLoaded then
				freezeForSelection()
			end
		end)
	end
end)
