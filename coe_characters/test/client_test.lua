local eventHandlers = {}
local nuiCallbacks = {}
local commands = {}
local keyMappings = {}
local messages = {}
local requests = {}

Core = {
	Events = {
		OnNet = function(name, callback)
			eventHandlers[name] = callback
			return name
		end,
		ToServer = function(name, ...)
			requests[#requests + 1] = { name = name, args = { ... } }
			return true
		end
	}
}
RegisterNUICallback = function(name, callback)
	nuiCallbacks[name] = callback
end
RegisterCommand = function(name, callback)
	commands[name] = callback
end
RegisterKeyMapping = function(command, description, device, key)
	keyMappings[command] = { description = description, device = device, key = key }
end
SetNuiFocus = function() end
SendNUIMessage = function(message)
	messages[#messages + 1] = message
end
GetCurrentResourceName = function()
	return 'coe_characters'
end
CreateThread = function(callback)
	callback()
end
local resourceStates = { coe_appearance = 'missing' }
GetResourceState = function(name)
	return resourceStates[name] or 'missing'
end
local localHandlers = {}
AddEventHandler = function(name, callback)
	localHandlers[name] = callback
end
local creatorCalls = {}
exports = setmetatable({}, { __index = function(_, resource)
	return setmetatable({}, { __index = function(_, name)
		return function(_, ...)
			creatorCalls[#creatorCalls + 1] = { resource = resource, name = name, args = { ... } }
			return true
		end
	end })
end })
NetworkIsPlayerActive = function()
	return true
end
PlayerId = function()
	return 5
end
Wait = function() end
local hudEvents = {}
TriggerEvent = function(name, ...)
	if name == 'coe_hud:setHidden' then
		hudEvents[#hudEvents + 1] = { ... }
	end
end
IsScreenFadedOut = function() return false end
IsScreenFadingOut = function() return false end
IsScreenFadingIn = function() return false end
GetGameTimer = function() return 0 end
local loadingShutdowns = 0
ShutdownLoadingScreen = function() end
ShutdownLoadingScreenNui = function() loadingShutdowns = loadingShutdowns + 1 end

dofile('config.lua')
dofile('client.lua')

local function assertEqual(actual, expected, label)
	if actual ~= expected then
		error(('%s: expected %s, got %s'):format(label, tostring(expected), tostring(actual)))
	end
end

assertEqual(requests[1].name, 'player.clientReady', 'client announces readiness once active')
assertEqual(#requests, 1, 'only the readiness request is sent on start')

source = 42
eventHandlers['character.selectionRequired']({ { characterId = '10' } })
assertEqual(#messages, 0, 'client rejects a forged server event')

source = 65535
eventHandlers['character.selectionRequired']({ { characterId = '10' } })
local function findMessage(action, from)
	for index = from or 1, #messages do
		if messages[index].action == action then
			return messages[index], index
		end
	end
	return nil
end
local openMessage, openIndex = findMessage('open')
assertEqual(openMessage.waitScene, true, 'selection UI waits for the scene before showing')
local _, requiredIndex = findMessage('selectionRequired')
local _, revealIndex = findMessage('reveal')
assertEqual(requiredIndex > openIndex, true, 'server request opens selection UI')
assertEqual(revealIndex > requiredIndex, true, 'without the 3D scene the UI is revealed right away')
assertEqual(loadingShutdowns, 1, 'loading screen closes when the selection is revealed')
assertEqual(hudEvents[#hudEvents][1], 'coe_characters', 'HUD hidden by this resource')
assertEqual(hudEvents[#hudEvents][2], true, 'HUD hidden while selecting')

local callbackResponse
nuiCallbacks.createCharacter({ firstName = 'Ana', lastName = 'Silva' }, function(response)
	callbackResponse = response
end)
assertEqual(callbackResponse.success, true, 'valid NUI request is acknowledged')
assertEqual(requests[#requests].name, 'character.createRequest', 'NUI request uses Core event API')
assertEqual(requests[#requests].args[2], 'Ana', 'first name is forwarded')

nuiCallbacks.createCharacter({ firstName = 'Ana', lastName = 'Silva', birthDate = '1990-05-20', gender = 'female', appearance = { x = 1 } }, function() end)
local profileArg = requests[#requests].args[4]
assertEqual(profileArg.birthDate, '1990-05-20', 'birth date is forwarded')
assertEqual(profileArg.gender, 'female', 'gender is forwarded')
assertEqual(profileArg.appearance, nil, 'NUI cannot inject appearance')

nuiCallbacks.createCharacter({ firstName = 'Ana', lastName = 'Silva', birthDate = 19900520 }, function(response)
	callbackResponse = response
end)
assertEqual(callbackResponse.error, 'invalid_request', 'non-string birth date is rejected')

local requestCount = #requests
nuiCallbacks.selectCharacter({ characterId = 10 }, function(response)
	callbackResponse = response
end)
assertEqual(callbackResponse.error, 'invalid_request', 'invalid NUI payload is rejected')
assertEqual(#requests, requestCount, 'invalid NUI payload is not sent')

eventHandlers['character.selectResult'](1, true, { characterId = '10' })
assertEqual(messages[#messages - 1].action, 'selectResult', 'selection result is forwarded to NUI')
assertEqual(messages[#messages].action, 'close', 'successful selection closes UI')
assertEqual(hudEvents[#hudEvents][2], false, 'HUD back once the character is in and the screen is clear')
assertEqual(keyMappings[CoeCharactersConfig.Command].key, CoeCharactersConfig.OpenKey,
	'key mapping uses resource configuration')

-- Criador (coe_appearance) ------------------------------------------------------------------------------
resourceStates.coe_appearance = 'started'

-- Personagem sem aparência passa pelo criador antes de entrar; com aparência entra direto.
eventHandlers['character.selectionRequired']({
	{ characterId = '10', gender = 'female', firstName = 'Ana', lastName = 'Silva' },
	{ characterId = '11', gender = 'male', appearance = { model = 'mp_m_freemode_01' } }
})
requestCount = #requests
nuiCallbacks.selectCharacter({ characterId = '10' }, function(response) callbackResponse = response end)
assertEqual(callbackResponse.success, true, 'creator opens for a character without appearance')
assertEqual(#requests, requestCount, 'no select request before the appearance is saved')
assertEqual(creatorCalls[#creatorCalls].name, 'OpenCreator', 'creator export called')
assertEqual(creatorCalls[#creatorCalls].args[1].mode, 'appearance', 'appearance mode')
assertEqual(creatorCalls[#creatorCalls].args[1].gender, 'female', 'gender forwarded to the creator')

nuiCallbacks.selectCharacter({ characterId = '11' }, function() end)
assertEqual(requests[#requests].name, 'character.selectRequest', 'character with appearance is selected directly')

-- Envio do criador: aparência vai para o servidor; sucesso entra com o personagem.
localHandlers['coe_appearance:creatorSubmit']({ mode = 'appearance', characterId = '10', appearance = { model = 'mp_f_freemode_01' }, version = 1 })
local appearanceRequest = requests[#requests]
assertEqual(appearanceRequest.name, 'character.appearanceRequest', 'appearance request sent')
assertEqual(appearanceRequest.args[2], '10', 'appearance for the right character')
assertEqual(appearanceRequest.args[4], 1, 'appearance version forwarded')
eventHandlers['character.appearanceResult'](appearanceRequest.args[1], true, '10')
assertEqual(creatorCalls[#creatorCalls].name, 'CloseCreator', 'creator closed after saving')
assertEqual(requests[#requests].name, 'character.selectRequest', 'character selected after the appearance is saved')
assertEqual(requests[#requests].args[2], '10', 'selects the same character')

-- Criação completa pelo criador: perfil com aparência; erro do servidor volta para o criador.
localHandlers['coe_appearance:creatorSubmit']({
	mode = 'create', identity = { firstName = 'Bia', lastName = 'Lima', birthDate = '1995-01-01', gender = 'female' },
	appearance = { model = 'mp_f_freemode_01' }, version = 1
})
local createRequest = requests[#requests]
assertEqual(createRequest.name, 'character.createRequest', 'create request from the creator')
assertEqual(createRequest.args[4].appearance.model, 'mp_f_freemode_01', 'appearance in the profile')
assertEqual(createRequest.args[4].appearanceVersion, 1, 'appearance version in the profile')
eventHandlers['character.createResult'](createRequest.args[1], false, 'invalid_character_name')
assertEqual(creatorCalls[#creatorCalls].name, 'CreatorError', 'server error shown inside the creator')
assertEqual(creatorCalls[#creatorCalls].args[1], 'Nome ou sobrenome inválido.', 'translated error')

-- Cena 3D (client/scene.lua): condições de corrida entre Show e Destroy -----------------------------------
local deletedEntities = {}
local radarStates = {}
local onCreatePed = nil

vector3 = function(x, y, z)
	return setmetatable({ x = x, y = y, z = z }, {
		__add = function(a, b) return vector3(a.x + b.x, a.y + b.y, a.z + b.z) end,
		__mul = function(a, scalar) return vector3(a.x * scalar, a.y * scalar, a.z * scalar) end
	})
end
RequestCollisionAtCoord = function() end
GetGroundZFor_3dCoord = function(_, _, z) return true, z end
DoScreenFadeOut = function() end
IsScreenFadedOut = function() return true end
local gameTimer = 0
GetGameTimer = function() gameTimer = gameTimer + 100; return gameTimer end
DoScreenFadeIn = function() end
SetFocusPosAndVel = function() end
NewLoadSceneStart = function() end
IsNewLoadSceneLoaded = function() return true end
NewLoadSceneStop = function() end
NetworkOverrideClockTime = function() end
NetworkClearClockTimeOverride = function() end
ClearOverrideWeather = function() end
SetWeatherTypeNowPersist = function() end
SetOverrideWeather = function() end
ClearWeatherTypePersist = function() end
SetTimecycleModifier = function() end
SetTimecycleModifierStrength = function() end
ClearTimecycleModifier = function() end
DisplayRadar = function(state) radarStates[#radarStates + 1] = state end
HideHudAndRadarThisFrame = function() end
SetUseHiDof = function() end
TaskStartScenarioInPlace = function() end
DoesEntityExist = function(entity) return entity ~= nil and not deletedEntities[entity] end
DeleteEntity = function(entity) deletedEntities[entity] = true end
SetEntityHeading = function() end
ResetEntityAlpha = function() end
GetEntityCoords = function() return vector3(0, 0, 0) end
ClearPedTasks = function() end
TaskLookAtCoord = function() end
CreateCamWithParams = function() return 101 end
PointCamAtCoord = function() end
SetCamUseShallowDofMode = function() end
SetCamNearDof = function() end
SetCamFarDof = function() end
SetCamDofStrength = function() end
SetCamActive = function() end
SetCamActiveWithInterp = function() end
DoesCamExist = function() return true end
DestroyCam = function() end
RenderScriptCams = function() end
ClearFocus = function() end
SetTimeout = function(_, cb) cb() end

-- Threads rodam até o primeiro Wait e param ali (o frameThread da cena é um loop por quadro); Wait fora de thread
-- não faz nada.
Wait = function()
	if coroutine.isyieldable() then
		coroutine.yield()
	end
end
CreateThread = function(callback)
	assert(coroutine.resume(coroutine.create(callback)))
end

exports = setmetatable({}, { __index = function(_, resource)
	return setmetatable({}, { __index = function(_, name)
		return function(_, ...)
			if resource == 'coe_appearance' and name == 'CreatePed' and onCreatePed then
				return onCreatePed(...)
			end
			return 501
		end
	end })
end })

dofile('client/scene.lua')

-- Caso 1: Destroy chamado enquanto CreatePed está em andamento (não pode dar erro de scene nil nem vazar ped).
onCreatePed = function()
	CharacterScene.Destroy(true)
	return 777
end
CharacterScene.Show({ { characterId = '10', gender = 'female', appearance = { model = 'mp_f_freemode_01' } } }, '10')
assertEqual(CharacterScene.IsActive(), false, 'scene stays destroyed when Destroy runs during CreatePed')
assertEqual(deletedEntities[777], true, 'orphan ped created after Destroy is immediately deleted')

-- Caso 2: Destroy chamado enquanto loadScene aguarda streaming (não pode chamar DisplayRadar(false) depois).
onCreatePed = nil
radarStates = {}
local loadChecks = 0
IsNewLoadSceneLoaded = function()
	loadChecks = loadChecks + 1
	if loadChecks == 1 then
		CharacterScene.Destroy(true)
	end
	return true
end
CharacterScene.Show({ { characterId = '10', gender = 'female', appearance = { model = 'mp_f_freemode_01' } } }, '10')
assertEqual(#radarStates, 0, 'aborted Show during loadScene does not disable radar after Destroy')

-- Caso 3: com a cena, a interface só é revelada (e a tela de carregamento só fecha) depois de a cena montar.
IsNewLoadSceneLoaded = function() return true end
CoeCharactersConfig.Scene.Enabled = true
messages = {}
local revealedBeforeFadeIn = nil
DoScreenFadeIn = function()
	for _, message in ipairs(messages) do
		if message.action == 'reveal' then revealedBeforeFadeIn = true end
	end
	revealedBeforeFadeIn = revealedBeforeFadeIn or false
end
sceneThreads = {}
CreateThread = function(callback)
	local thread = coroutine.create(callback)
	sceneThreads[#sceneThreads + 1] = thread
	assert(coroutine.resume(thread))
end
dofile('client.lua')
eventHandlers['character.selectionRequired']({ { characterId = '10', gender = 'female', appearance = { model = 'mp_f_freemode_01' } } })
assertEqual(findMessage('open').waitScene, true, 'UI hidden while the scene loads')
assertEqual(findMessage('reveal'), nil, 'no reveal while the scene thread is still loading')
-- Termina as threads da cena (exceto o loop por quadro) e confere a ordem: cena pronta, fade in, revelar.
for _ = 1, 50 do
	for _, thread in ipairs(sceneThreads) do
		if coroutine.status(thread) == 'suspended' then coroutine.resume(thread) end
	end
	if findMessage('reveal') then break end
end
assertEqual(findMessage('reveal') ~= nil, true, 'UI revealed once the scene is ready')
assertEqual(revealedBeforeFadeIn, false, 'scene fades in before the UI is revealed')
assertEqual(loadingShutdowns >= 1, true, 'loading screen closed with the reveal')

print('character client tests passed')
