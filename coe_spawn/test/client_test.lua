local eventHandlers = {}
local resourceHandlers = {}
local spawnedWith
local spawnCallbackArg
local respawnCount = 0
local autoSpawnValues = {}
local controlValues = {}
local frozenValues = {}
local visibleValues = {}

local spawnManager = {}
spawnManager.spawnPlayer = function(_, location, callback)
		spawnedWith = location
		spawnCallbackArg = callback
	end
spawnManager.setAutoSpawn = function(_, enabled)
		autoSpawnValues[#autoSpawnValues + 1] = enabled
	end
spawnManager.setAutoSpawnCallback = function(_, callback)
		spawnManager.spawnCallback = callback
	end
spawnManager.forceRespawn = function()
		respawnCount = respawnCount + 1
	end
exports = { spawnmanager = spawnManager }
Core = {
	Events = {
		OnNet = function(name, callback)
			eventHandlers[name] = callback
		end
	}
}
PlayerPedId = function()
	return 20
end
PlayerId = function()
	return 5
end
DoesEntityExist = function(entity)
	return entity == 20
end
SetPlayerControl = function(_, enabled)
	controlValues[#controlValues + 1] = enabled
end
FreezeEntityPosition = function(_, frozen)
	frozenValues[#frozenValues + 1] = frozen
end
SetEntityVisible = function(_, visible)
	visibleValues[#visibleValues + 1] = visible
end
AddEventHandler = function(name, callback)
	resourceHandlers[name] = callback
end
local netHandlers = {}
RegisterNetEvent = function(name, callback)
	netHandlers[name] = callback
end
local serverEvents = {}
TriggerServerEvent = function(name)
	serverEvents[#serverEvents + 1] = name
end
local timeouts = {}
SetTimeout = function(_, callback)
	timeouts[#timeouts + 1] = callback
end
local loadingScreenShutdowns = 0
CreateThread = function(callback)
	callback()
end
Wait = function() end
GetEntityCoords = function()
	return { 1.0, 2.0, 3.0 }
end
GetEntityModel = function()
	return 123
end
IsEntityVisible = function()
	return true
end
IsEntityPositionFrozen = function()
	return false
end
GetEntityHealth = function()
	return 200
end
IsScreenFadedOut = function()
	return false
end
IsScreenFadedIn = function()
	return true
end
IsGameplayCamRendering = function()
	return true
end
HasCollisionLoadedAroundEntity = function()
	return true
end
local scriptCamsDisabled = 0
RenderScriptCams = function(render)
	if render == false then
		scriptCamsDisabled = scriptCamsDisabled + 1
	end
end
DisplayHud = function() end
GetClockHours = function()
	return 12
end
IsPauseMenuActive = function()
	return false
end
DisplayRadar = function() end
local loadingScreenNuiShutdowns = 0
local fadeIns = 0
ShutdownLoadingScreen = function()
	loadingScreenShutdowns = loadingScreenShutdowns + 1
end
ShutdownLoadingScreenNui = function()
	loadingScreenNuiShutdowns = loadingScreenNuiShutdowns + 1
end
DoScreenFadeIn = function()
	fadeIns = fadeIns + 1
end
local resourceStates = {}
GetResourceState = function(name)
	return resourceStates[name] or 'missing'
end
local appliedAppearance
exports.coe_appearance = {
	Apply = function(_, ped, appearance)
		appliedAppearance = { ped = ped, appearance = appearance }
		return true
	end
}

dofile('config.lua')
dofile('shared/positions.lua')
dofile('client.lua')

local function assertEqual(actual, expected, label)
	if actual ~= expected then
		error(('%s: expected %s, got %s'):format(label, tostring(expected), tostring(actual)))
	end
end

source = 42
eventHandlers['player.loaded']()
assertEqual(#autoSpawnValues, 0, 'non-server source cannot change spawn state')

source = 65535
eventHandlers['player.loaded']()
assertEqual(loadingScreenShutdowns, 1, 'selection closes the loading screen')
assertEqual(loadingScreenNuiShutdowns, 1, 'selection closes the loading screen NUI')
assertEqual(fadeIns, 1, 'selection fades the screen in')
assertEqual(autoSpawnValues[#autoSpawnValues], false, 'selection disables automatic spawn')
assertEqual(controlValues[#controlValues], false, 'player control is disabled before selection')
assertEqual(frozenValues[#frozenValues], true, 'player ped is frozen before selection')
assertEqual(visibleValues[#visibleValues], false, 'player ped is hidden before selection')

eventHandlers['player.characterLoaded']()
assertEqual(serverEvents[#serverEvents], 'coe_spawn:requestPosition', 'loaded character asks for the last position')
assertEqual(respawnCount, 0, 'spawn waits for the last position')
netHandlers['coe_spawn:position']({ x = 100.5, y = -200.25, z = 30.0, heading = 90.0 })
assertEqual(respawnCount, 1, 'last position triggers the respawn')
assertEqual(spawnManager.spawnCallback ~= nil, true, 'spawn callback is registered')
spawnManager.spawnCallback()
assertEqual(spawnedWith.x, 100.5, 'spawn uses the last position')
assertEqual(spawnedWith.heading, 90.0, 'spawn keeps the last heading')
timeouts[#timeouts]()
assertEqual(respawnCount, 1, 'late timeout does not respawn again')
spawnManager.spawnCallback()
assertEqual(spawnedWith.x, CoeSpawnConfig.location.x, 'later respawns use configured location')
local modelAllowed = false
for _, model in ipairs(CoeSpawnConfig.models) do
	modelAllowed = modelAllowed or model == spawnedWith.model
end
assertEqual(modelAllowed, true, 'spawn picks a ped from the configured list')
assertEqual(CoeSpawnConfig.location.model, nil, 'configured location is not mutated')

spawnCallbackArg()
assertEqual(serverEvents[#serverEvents], 'coe_spawn:spawned', 'spawn is reported to the server')
assertEqual(visibleValues[#visibleValues], true, 'spawned ped is made visible again')
assertEqual(frozenValues[#frozenValues], false, 'spawned ped is unfrozen')
assertEqual(controlValues[#controlValues], true, 'player control is restored after spawn')
assertEqual(scriptCamsDisabled, 1, 'script cameras are released after spawn')

eventHandlers['player.characterUnloaded']()
assertEqual(autoSpawnValues[#autoSpawnValues], false, 'unloading character returns to selection state')
assertEqual(controlValues[#controlValues], false, 'player remains disabled while selecting')

-- Sem posição salva (primeiro acesso) ou sem resposta: ponto padrão.
eventHandlers['player.characterLoaded']()
netHandlers['coe_spawn:position'](nil)
assertEqual(respawnCount, 2, 'missing last position still spawns')
spawnManager.spawnCallback()
assertEqual(spawnedWith.x, CoeSpawnConfig.location.x, 'first access uses configured location')
eventHandlers['player.characterLoaded']()
timeouts[#timeouts]()
assertEqual(respawnCount, 3, 'timeout falls back to configured location')
netHandlers['coe_spawn:position']({ x = 500, y = 500, z = 30 })
assertEqual(respawnCount, 3, 'late answer after timeout is ignored')
eventHandlers['player.characterLoaded']()
netHandlers['coe_spawn:position']({ x = 0, y = 0, z = 0 })
spawnManager.spawnCallback()
assertEqual(spawnedWith.x, CoeSpawnConfig.location.x, 'invalid last position falls back')

-- Personagem com aparência salva: nasce com o modelo dela e a aparência é aplicada (também nos respawns).
resourceStates.coe_appearance = 'started'
local appearance = { model = 'mp_f_freemode_01', hair = { style = 4 } }
eventHandlers['player.characterLoaded']({ characterId = '10', appearance = appearance })
netHandlers['coe_spawn:position'](nil)
spawnManager.spawnCallback()
assertEqual(spawnedWith.model, 'mp_f_freemode_01', 'spawn uses the saved appearance model')
spawnCallbackArg()
assertEqual(appliedAppearance.ped, 20, 'appearance applied to the player ped')
assertEqual(appliedAppearance.appearance.hair.style, 4, 'saved appearance applied')
spawnManager.spawnCallback()
assertEqual(spawnedWith.model, 'mp_f_freemode_01', 'respawn keeps the saved model')

-- Trocar de personagem limpa a aparência; personagem sem aparência volta ao sorteio.
eventHandlers['player.characterUnloaded']()
eventHandlers['player.characterLoaded']({ characterId = '11' })
netHandlers['coe_spawn:position'](nil)
spawnManager.spawnCallback()
local randomModel = false
for _, model in ipairs(CoeSpawnConfig.models) do
	randomModel = randomModel or model == spawnedWith.model
end
assertEqual(randomModel, true, 'character without appearance uses a random ped')

print('spawn client tests passed')
