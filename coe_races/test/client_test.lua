-- Client com natives simulados: tablet próprio (abrir, NUI, fechar), corrida (rota até a largada, alinhamento com
-- classe e sirene, contagem com carro preso, fantasma, checkpoint cruzado reenviado até a confirmação, chegada) e
-- gravador de pistas (largada com direção, espaçamento, desfazer, salvar).
local threads, serverEvents, netHandlers, nuiCallbacks, commands, nui, notices = {}, {}, {}, {}, {}, {}, {}
local now = 0
local ped, vehicle = 1, 50
local pos = { x = 0, y = 0, z = 30 }
local seatDriver = true
local frozen, noCollision, checkpoints, blips, routes = {}, {}, {}, {}, {}
local timeouts = {}

local function noop() end
for _, name in ipairs({ 'SetNuiFocus', 'StopAnimTask', 'DetachEntity', 'DeleteEntity', 'RequestAnimDict', 'RequestModel',
	'SetModelAsNoLongerNeeded', 'AttachEntityToEntity', 'TaskPlayAnim', 'SetNewWaypoint', 'AddEventHandler', 'SetBlipSprite',
	'SetBlipColour', 'SetBlipScale', 'ShowNumberOnBlip', 'SetBlipRouteColour', 'BeginTextCommandSetBlipName',
	'AddTextComponentSubstringPlayerName', 'EndTextCommandSetBlipName', 'SetCheckpointCylinderHeight', 'PlaySoundFrontend',
	'SetEntityAlpha', 'ResetEntityAlpha', 'DisableControlAction', 'RegisterKeyMapping', 'DrawMarker' }) do
	_G[name] = noop
end
CreateThread = function(fn) local co = coroutine.create(fn); threads[#threads + 1] = co; coroutine.resume(co) end
Wait = function() coroutine.yield() end
local function pump() for _, co in ipairs(threads) do if coroutine.status(co) == 'suspended' then assert(coroutine.resume(co)) end end end
SetTimeout = function(ms, fn) timeouts[#timeouts + 1] = { at = now + ms, fn = fn } end
GetGameTimer = function() return now end
joaat = function() return 1 end
local awaitValue = { ok = true }
promise = { new = function() return { resolve = function(self, v) self.value = v end } end }
Citizen = { Await = function() return awaitValue end }
RegisterNetEvent = function(name, fn) netHandlers[name] = fn end
RegisterNUICallback = function(name, fn) nuiCallbacks[name] = fn end
RegisterCommand = function(name, fn) commands[name] = fn end
TriggerServerEvent = function(name, ...) serverEvents[#serverEvents + 1] = { name = name, args = { ... } } end
SendNUIMessage = function(message) nui[#nui + 1] = message end
PlayerPedId = function() return ped end
IsPedDeadOrDying = function() return false end
IsPedInAnyVehicle = function() return true end
HasAnimDictLoaded = function() return true end
HasModelLoaded = function() return true end
GetCurrentResourceName = function() return 'coe_races' end
GetVehiclePedIsIn = function() return seatDriver and vehicle or 0 end
GetPedInVehicleSeat = function() return ped end
GetEntityCoords = function() return { x = pos.x, y = pos.y, z = pos.z } end
GetEntityHeading = function() return 271.5 end
GetVehicleClass = function(v) return v == vehicle and 6 or 18 end
IsVehicleSirenOn = function() return true end
GetGamePool = function() return { vehicle, 77 } end
GetEntityModel = function() return 1 end
GetDisplayNameFromVehicleModel = function() return 'ELEGY' end
GetLabelText = function() return 'Elegy RH8' end
NetworkGetNetworkIdFromEntity = function(v) return v + 1000 end
NetworkDoesNetworkIdExist = function() return true end
NetToVeh = function(netId) return netId - 1000 end
DoesEntityExist = function() return true end
FreezeEntityPosition = function(v, on) frozen[v] = on end
SetEntityNoCollisionEntity = function(a, b) noCollision[#noCollision + 1] = { a, b } end
local nextId = 0
CreateCheckpoint = function(kind) nextId = nextId + 1 checkpoints[nextId] = kind return nextId end
DeleteCheckpoint = function(id) checkpoints[id] = nil end
AddBlipForCoord = function() nextId = nextId + 1 blips[nextId] = true return nextId end
RemoveBlip = function(id) blips[id] = nil end
SetBlipRoute = function(id, on) routes[id] = on end
exports = setmetatable({}, { __index = function(_, resource)
	if resource == 'coe_notify' then return { Show = function(_, kind, message) notices[#notices + 1] = { kind = kind, message = message } end } end
	return setmetatable({}, { __index = function() return function() end end })
end })

dofile('config.lua')
dofile('locales/pt-br.lua')
dofile('client/main.lua')
dofile('client/race.lua')
dofile('client/recorder.lua')

local function eq(a, b, m)
	if a ~= b then error(('%s: esperado %s, veio %s'):format(m, tostring(b), tostring(a)), 2) end
end
local function count(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end
local function lastServer(name) for i = #serverEvents, 1, -1 do if serverEvents[i].name == name then return serverEvents[i] end end end
local function lastHud(kind) for i = #nui, 1, -1 do if nui[i].action == 'hud' and nui[i].type == kind then return nui[i].data end end end

-- Tablet próprio
commands.corridas()
eq(lastServer('coe_races:open') ~= nil, true, 'pede para abrir')
netHandlers['coe_races:opened']()
eq(nui[#nui].action, 'open', 'abre a NUI')
local reply
nuiCallbacks.call({ action = 'state', payload = {} }, function(r) reply = r end)
eq(lastServer('coe_races:call').args[2], 'state', 'acao pelo canal do app')
eq(reply.ok, true, 'resposta repassada')
nuiCallbacks.close({}, function() end)
eq(nui[#nui].action, 'close', 'fecha')

-- Inscrição: rota até a largada
local cps = { { x = 100, y = 0, z = 30, r = 12 }, { x = 200, y = 0, z = 30, r = 12 }, { x = 0, y = 0, z = 30, r = 12 } }
netHandlers['coe_races:joined']({ id = 9, name = 'Porto', kind = 'circuit', laps = 2, start = { x = 0, y = 0, z = 30, h = 90 }, checkpoints = cps, racers = 2, startsIn = 120 })
eq(count(routes), 1, 'rota para a largada')
eq(lastHud('lobby').startsIn, 120, 'hud do lobby')

-- Alinhamento
netHandlers['coe_races:prepare']({ id = 9 })
local ready = lastServer('coe_races:ready').args[2]
eq(ready.netId, 1050, 'veiculo')
eq(ready.classId, 6, 'classe')
eq(ready.label, 'Elegy RH8', 'nome do carro')
eq(ready.sirens, true, 'viatura com sirene perto')

-- Contagem: preso, checkpoints e fantasma
netHandlers['coe_races:race']({ id = 9, name = 'Porto', kind = 'circuit', laps = 2, start = { x = 0, y = 0, z = 30 }, checkpoints = cps,
	racers = 2, goIn = 5000, ghostSeconds = 8, vehicles = { 1050, 1060 } })
eq(frozen[vehicle], true, 'carro preso na contagem')
eq(count(checkpoints), 2, 'proximo e o seguinte')
eq(lastHud('progress').total, 6, 'total de checkpoints')
pump()
eq(#noCollision >= 2, true, 'fantasma entre os carros')
netHandlers['coe_races:go']({ id = 9 })
eq(frozen[vehicle], false, 'solta na largada')

-- Checkpoint: avisa uma vez, reenvia depois de 1 s, avança só com a confirmação
pos = { x = 105, y = 3, z = 30 }
now = now + 100
pump()
local sent = lastServer('coe_races:checkpoint')
eq(sent.args[2], 1, 'cruzou o 1')
local before = #serverEvents
now = now + 100
pump()
eq(#serverEvents, before, 'nao repete na hora')
now = now + 1200
pump()
eq(#serverEvents, before + 1, 'reenvia sem confirmacao')
netHandlers['coe_races:checkpointOk'](9, 1)
eq(lastHud('progress').checkpoint, 1, 'avancou')
now = now + 100
pump()
eq(lastServer('coe_races:checkpoint').args[2], 1, 'longe do 2: nada novo')
netHandlers['coe_races:finished'](9, 70000)
eq(count(checkpoints), 0, 'chegada limpa os marcadores')
netHandlers['coe_races:results']({ id = 9, track = 'Porto', results = {} })
eq(lastHud('results').track, 'Porto', 'resultado na tela')

-- Gravador
netHandlers['coe_races:record']({ name = 'Nova', description = '', kind = 'sprint', minSpacing = 25, maxCheckpoints = 60, minCheckpoints = 3, radius = 12 })
eq(lastHud('record').started, false, 'gravando sem largada')
pos = { x = 0, y = 0, z = 30 }
commands['+coe_races_mark']()
eq(lastHud('record').started, true, 'largada marcada')
pos = { x = 10, y = 0, z = 30 }
commands['+coe_races_mark']()
eq(lastHud('record').count, 0, 'perto demais')
eq(notices[#notices].kind, 'error', 'aviso de distancia')
for i = 1, 3 do pos = { x = i * 50, y = 0, z = 30 }; commands['+coe_races_mark']() end
eq(lastHud('record').count, 3, 'tres checkpoints')
commands['+coe_races_undo']()
eq(lastHud('record').count, 2, 'desfez')
pos = { x = 150, y = 0, z = 30 }
commands['+coe_races_mark']()
awaitValue = { ok = true }
commands['+coe_races_save']()
local save = lastServer('coe_races:call')
eq(save.args[2], 'saveTrack', 'salva pelo canal do app')
eq(save.args[3].start.h, 271.5, 'direcao da largada')
eq(#save.args[3].checkpoints, 3, 'pontos enviados')
eq(nui[#nui].type == 'record' and nui[#nui].data, false, 'gravador fechado')

print('coe_races client_test: ok')
