-- Client com natives simulados: blips por bandeira, alvo nas bombas, pedido do tanque ao entrar, relatório de
-- consumo, nível nativo pelo state bag, motor desligado com tanque vazio e galão pelo inventário.
local threads, serverEvents, blips, targets, stateHandlers, netHandlers = {}, {}, {}, {}, {}, {}
local blipNames, blipColors = {}, {}
local fuelLevels, engineOff = {}, {}
local now = 0
local ped, vehicle = 1, 50
local inVehicle = true
local pos = { x = 0, y = 0, z = 0 }
local engineRunning = true
local bags = { [vehicle] = {} }

local function vec(x, y, z)
	return setmetatable({ x = x, y = y, z = z }, {
		__sub = function(a, b) return vec(a.x - b.x, a.y - b.y, a.z - b.z) end,
		__len = function(a) return math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z) end
	})
end
vector3 = vec
local function hash(name) local h = 0 for i = 1, #name do h = (h * 31 + name:byte(i)) % 4294967296 end return h end
joaat = hash
CreateThread = function(fn) threads[#threads + 1] = coroutine.create(fn) end
Wait = function(ms) now = now + (ms or 0) coroutine.yield() end
SetTimeout = function() end
GetGameTimer = function() return now end
promise = { new = function() return {} end }
Citizen = { Await = function() return awaitResult end }
local blipCount = 0
AddBlipForCoord = function() blipCount = blipCount + 1 return blipCount end
SetBlipColour = function(blip, color) blipColors[blip] = color end
AddTextComponentSubstringPlayerName = function(name) blipNames[#blipNames + 1] = name end
for _, name in ipairs({ 'SetBlipSprite', 'SetBlipDisplay', 'SetBlipScale', 'SetBlipAsShortRange', 'BeginTextCommandSetBlipName',
	'EndTextCommandSetBlipName', 'RemoveBlip', 'SetNuiFocus', 'RegisterNUICallback', 'AddEventHandler', 'RegisterCommand',
	'TaskTurnPedToFaceEntity', 'RequestAnimDict', 'TaskPlayAnim', 'ClearPedTasks', 'RemoveAnimDict' }) do
	_G[name] = function() end
end
RegisterNetEvent = function(name, fn) netHandlers[name] = fn end
local nui = {}
SendNUIMessage = function(message) nui[#nui + 1] = message end
HasAnimDictLoaded = function() return true end
GetGamePool = function() return { vehicle } end
awaitResult = { ok = true }
TriggerServerEvent = function(name, ...) serverEvents[#serverEvents + 1] = { name = name, args = { ... } } end
AddStateBagChangeHandler = function(key, _, fn) stateHandlers[key] = fn end
GetEntityFromStateBagName = function(bag) return tonumber(bag:match('%d+')) or 0 end
PlayerPedId = function() return ped end
GetVehiclePedIsIn = function() return inVehicle and vehicle or 0 end
GetPedInVehicleSeat = function() return ped end
NetworkGetEntityIsNetworked = function() return true end
VehToNet = function(v) return v + 1000 end
GetVehicleClass = function() return 1 end
GetEntityModel = function() return hash('asea') end
DoesEntityExist = function() return true end
GetEntityCoords = function() return vec(pos.x, pos.y, pos.z) end
GetIsVehicleEngineRunning = function() return engineRunning end
GetVehicleCurrentRpm = function() return 0.5 end
SetVehicleFuelLevel = function(v, level) fuelLevels[#fuelLevels + 1] = level end
SetVehicleEngineOn = function(v, on) engineOff[#engineOff + 1] = not on end
Entity = function(entity) return { state = bags[entity] or {} } end
local useHandler
local function loadFramework(path)
	local candidates = {
		'../' .. path,
		'../tools/compat/' .. path,
		'../[coe-framework]/' .. path,
		'../../coe-framework/' .. path
	}
	for _, c in ipairs(candidates) do
		local f = io.open(c, 'r')
		if f then f:close() return dofile(c) end
	end
	error('Cannot find framework file: ' .. path)
end

loadFramework('coe_core/lib/platform.lua')
Core = {
	Platform = CoePlatform,
	Events = { OnNet = function(name, fn) if name == 'inventory.useItem' then useHandler = fn end end }
}
local entityTargets = {}
exports = { coetarget = { AddTargetModel = function(_, model, options) targets[model] = options end, RemoveTargetModel = function() end,
	AddTargetEntity = function(_, entity, options) entityTargets[entity] = options end, RemoveTargetEntity = function() end } }

dofile('config.lua')
dofile('locales/pt-br.lua')
dofile('shared/rules.lua')
dofile('client/main.lua')

local function tick(times)
	for _ = 1, times or 1 do
		for _, co in ipairs(threads) do
			if coroutine.status(co) ~= 'dead' then
				local ok, err = coroutine.resume(co)
				if not ok then error(err) end
			end
		end
	end
end

local function eq(a, b, m)
	if a ~= b then error(('%s: esperado %s, veio %s'):format(m, tostring(b), tostring(a)), 2) end
end
local function count(name) local n = 0 for _, e in ipairs(serverEvents) do if e.name == name then n = n + 1 end end return n end

tick()
eq(blipCount, #FuelConfig.Stations + 1, 'blip para cada posto e a refinaria')
eq(blipNames[1], 'Posto Globe Oil', 'nome pela bandeira')
eq(blipColors[1], FuelConfig.Brands.globe.color, 'cor da bandeira')
local unbranded = false
for _, name in ipairs(blipNames) do if name == 'Posto sem bandeira' then unbranded = true end end
eq(unbranded, true, 'posto sem bandeira')
eq(targets.prop_gas_pump_1a[1].label, 'Abastecer', 'alvo nas bombas')
eq(count('coe_fuel:init'), 1, 'pede o tanque ao entrar')
eq(serverEvents[1].args[1], vehicle + 1000, 'netId do veiculo')
eq(serverEvents[1].args[2], 1, 'classe')

-- chega o tanque: aplica o nivel e conta o consumo
bags[vehicle]['coe:fuel'] = { engine = 'flex', level = 0.5, liters = 27.5, capacity = 55, tank = { regular = 27.5 } }
stateHandlers['coe:fuel']('entity:' .. vehicle, 'coe:fuel', bags[vehicle]['coe:fuel'])
eq(fuelLevels[#fuelLevels], 50, 'nivel nativo pelo state bag')
for i = 1, 12 do
	pos.x = pos.x + 10
	tick()
end
eq(count('coe_fuel:report') >= 1, true, 'relata o consumo')
local reportEvent
for _, e in ipairs(serverEvents) do if e.name == 'coe_fuel:report' then reportEvent = e end end
eq(reportEvent.args[2] > 0, true, 'distancia percorrida')
eq(reportEvent.args[3] > 0, true, 'tempo com motor ligado')
eq(reportEvent.args[4], 0.5, 'rotacao media')
-- teleporte nao conta
local before = count('coe_fuel:report')
pos.x = pos.x + 5000
tick(12)
local last
for _, e in ipairs(serverEvents) do if e.name == 'coe_fuel:report' then last = e end end
eq(last.args[2] < 200, true, 'salto grande ignorado')
eq(count('coe_fuel:report') > before, true, 'segue relatando')

-- tanque vazio: motor desligado
bags[vehicle]['coe:fuel'] = { engine = 'flex', level = 0, liters = 0, capacity = 55, tank = {} }
tick()
eq(engineOff[#engineOff], true, 'motor desliga sem combustivel')
eq(fuelLevels[#fuelLevels], 0, 'nivel zero')

-- sai do veiculo: manda o que faltava
inVehicle = false
tick()
eq(useHandler ~= nil, true, 'escuta o uso do galao')
-- galao: mostrador conta os litros no tempo proporcional e o nivel sobe junto
bags[vehicle]['coe:fuel'] = { engine = 'flex', level = 0.2, liters = 11, capacity = 55, tank = { regular = 11 } }
awaitResult = { ok = true, liters = 10, seconds = 5, fuel = 'regular' }
bags[vehicle]['coe:fuel'] = { engine = 'flex', level = 0.2, liters = 11, capacity = 55, tank = { regular = 11 } }
useHandler({ name = 'fuel_can', slot = 2 })
local fillThread = threads[#threads]
assert(coroutine.resume(fillThread))
assert(coroutine.resume(fillThread)) -- vira para o veiculo e abre o mostrador
local meter
for _, m in ipairs(nui) do if m.action == 'meter' then meter = m.data end end
eq(meter ~= nil, true, 'abre o mostrador')
eq(meter.liters, 10, 'litros no mostrador')
eq(meter.seconds, 5, 'tempo proporcional')
eq(meter.fuel, 'Gasolina comum', 'combustivel no mostrador')
bags[vehicle]['coe:fuel'] = { engine = 'flex', level = 21 / 55, liters = 21, capacity = 55, tank = { regular = 21 } }
stateHandlers['coe:fuel']('entity:' .. vehicle, 'coe:fuel', bags[vehicle]['coe:fuel'])
local levelAfterBag = fuelLevels[#fuelLevels]
eq(levelAfterBag < 21 / 55 * 100, true, 'state bag nao pula o nivel durante o abastecimento')
local steps = 0
while coroutine.status(fillThread) ~= 'dead' and steps < 200 do
	steps = steps + 1
	coroutine.resume(fillThread)
end
eq(coroutine.status(fillThread), 'dead', 'termina')
eq(steps >= 40, true, 'dura o tempo do abastecimento (5 s em passos de 100 ms)')
eq(math.abs(fuelLevels[#fuelLevels] - 21 / 55 * 100) < 1e-6, true, 'termina no nivel real')
eq(nui[#nui].action, 'meterEnd', 'fecha o mostrador')
-- frota: alvo de carregar e descarregar no veiculo com carga
bags[vehicle]['coe:fuelCargo'] = { business = 'posto_davis', tier = 1, label = 'Van pequena', capacity = 800, liters = 0, cargo = {} }
for _ = 1, 3 do tick() end
eq(entityTargets[vehicle] ~= nil, true, 'alvo na van da frota')
eq(entityTargets[vehicle][1].label, 'Carregar combustível', 'opcao de carregar')
eq(entityTargets[vehicle][2].label, 'Descarregar no posto', 'opcao de descarregar')
eq(entityTargets[vehicle][2].canInteract(vehicle), false, 'vazia nao descarrega')
print('coe_fuel client tests passed')
