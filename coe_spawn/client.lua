local characterLoaded = false
-- Última posição recebida do servidor; usada só no primeiro spawn após carregar o personagem.
local lastPosition = nil
local awaitingPosition = nil
-- Aparência salva do personagem carregado (coe_appearance); vale para o spawn e para os respawns.
local currentAppearance = nil
local currentHotel = nil

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

-- Interações do Hotel de Nascimento (0.00 ms em idle).
-- Usa o aviso de interação padrão do coe_ui (o mesmo dos imóveis, banco e garagem). Só reenvia quando muda.
local promptKey = nil

local function setPrompt(key, title, subtitle, label)
	if key == promptKey then
		return
	end
	promptKey = key
	if type(SendNUIMessage) ~= 'function' then
		return
	end
	if not key then
		SendNUIMessage({ action = 'prompt', data = nil })
		return
	end
	SendNUIMessage({
		action = 'prompt',
		data = { title = title, subtitle = subtitle, options = { { key = 'E', label = label } } }
	})
end

local hotelLoopRunning = false
local hotelBlip = nil

local function updateHotelBlip(hotel)
	if type(DoesBlipExist) == 'function' and hotelBlip and DoesBlipExist(hotelBlip) then
		RemoveBlip(hotelBlip)
		hotelBlip = nil
	end
	if not hotel or hotel.enabled == false or hotel.blip == false or not hotel.entrance then
		return
	end
	if type(AddBlipForCoord) == 'function' then
		hotelBlip = AddBlipForCoord(hotel.entrance.x + 0.0, hotel.entrance.y + 0.0, hotel.entrance.z + 0.0)
		SetBlipSprite(hotelBlip, 475)
		SetBlipDisplay(hotelBlip, 4)
		SetBlipScale(hotelBlip, 0.8)
		SetBlipColour(hotelBlip, 3)
		SetBlipAsShortRange(hotelBlip, true)
		BeginTextCommandSetBlipName('STRING')
		AddTextComponentSubstringPlayerName(hotel.name or 'Hotel de Início')
		EndTextCommandSetBlipName(hotelBlip)
	end
end

local function ensureHotelLoop()
	updateHotelBlip(currentHotel)
	if hotelLoopRunning or not NetworkIsPlayerActive or type(GetGameTimer) ~= 'function' then
		return
	end
	hotelLoopRunning = true
	CreateThread(function()
		while true do
			local sleep = 1000
			local prompting = false
			if characterLoaded and currentHotel and currentHotel.enabled then
				local ped = PlayerPedId()
				if ped > 0 and DoesEntityExist(ped) and not IsEntityDead(ped) then
					local coords = GetEntityCoords(ped)
					local h = currentHotel

					-- 1. Entrada na rua
					local dEntrance = #(coords - vector3(h.entrance.x, h.entrance.y, h.entrance.z))
					-- 2. Saída do quarto
					local dExit = #(coords - vector3(h.exit.x, h.exit.y, h.exit.z))
					-- 3. Baú do quarto
					local dStash = #(coords - vector3(h.stash.x, h.stash.y, h.stash.z))

					if dEntrance < 15.0 or dExit < 15.0 or dStash < 15.0 then
						sleep = 0
						if dEntrance <= 1.8 then
							prompting = true
							setPrompt('entrance', h.name or 'Hotel de Início', 'Entrada', 'Entrar no quarto')
							if IsControlJustReleased(0, 38) then
								DoScreenFadeOut(400)
								Wait(450)
								SetEntityCoords(ped, h.room.x, h.room.y, h.room.z, false, false, false, false)
								SetEntityHeading(ped, h.room.h or 0.0)
								Wait(150)
								DoScreenFadeIn(400)
							end
						elseif dExit <= 1.8 then
							prompting = true
							setPrompt('exit', h.name or 'Hotel de Início', 'Saída', 'Sair para a rua')
							if IsControlJustReleased(0, 38) then
								DoScreenFadeOut(400)
								Wait(450)
								SetEntityCoords(ped, h.entrance.x, h.entrance.y, h.entrance.z, false, false, false, false)
								SetEntityHeading(ped, h.entrance.h or 0.0)
								Wait(150)
								DoScreenFadeIn(400)
							end
						elseif dStash <= 1.8 then
							prompting = true
							setPrompt('stash', h.name or 'Hotel de Início', 'Baú', 'Abrir baú')
							if IsControlJustReleased(0, 38) then
								TriggerServerEvent('coe_spawn:openHotelStash')
							end
						end
					end
				end
			end
			if not prompting then
				setPrompt(nil)
			end
			Wait(sleep)
		end
	end)
end

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

RegisterNetEvent('coe_spawn:position', function(position, hotelConfig)
	if hotelConfig then
		currentHotel = hotelConfig
		ensureHotelLoop()
	end
	if not awaitingPosition or not characterLoaded then
		return
	end
	beginSpawn(SpawnPositions.Normalize(position, CoeSpawnConfig.LastPosition.Bounds))
end)

RegisterNetEvent('coe_spawn:syncHotel', function(hotelConfig)
	currentHotel = hotelConfig
	ensureHotelLoop()
end)

Core.Events.OnNet('player.characterUnloaded', function()
	if not acceptServerEvent() then
		return
	end

	characterLoaded = false
	awaitingPosition = nil
	lastPosition = nil
	currentAppearance = nil
	currentHotel = nil
	updateHotelBlip(nil)
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

