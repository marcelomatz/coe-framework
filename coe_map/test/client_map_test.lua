local commands, keymaps, messages, events, bigmap = {}, {}, {}, {}, nil
local waypointBlip, hidden = nil, false
local threads = {}

SendNUIMessage = function(m) messages[#messages + 1] = m end
RegisterCommand = function(name, fn) commands[name] = fn end
RegisterKeyMapping = function(name, _, _, key) keymaps[name] = key end
AddEventHandler = function() end
TriggerEvent = function(name, ...) events[#events + 1] = { name = name, args = { ... } } end
CreateThread = function(fn) threads[#threads + 1] = coroutine.create(fn) end
Wait = function() coroutine.yield() end
DisableControlAction = function() end
GetCurrentResourceName = function() return 'coe_map' end
SetBigmapActive = function(v) bigmap = v end
local layout, zoom = {}, nil
SetMinimapComponentPosition = function(name, _, _, x, y, w, h) layout[name] = { x = x, y = y, w = w, h = h } end
SetMinimapClipType = function() end
SetRadarZoom = function(z) zoom = z end
IsPedInAnyVehicle = function() return false end
IsRadarHidden = function() return hidden end
GetSafeZoneSize = function() return 0.95 end
GetAspectRatio = function() return 16 / 9 end
PlayerPedId = function() return 1 end
GetEntityCoords = function() return { x = 0.0, y = 0.0, z = 0.0 } end
GetFirstBlipInfoId = function() return waypointBlip or 0 end
DoesBlipExist = function(b) return b ~= 0 end
GetBlipInfoIdCoord = function() return { x = 300.0, y = 400.0, z = 0.0 } end
SetWaypointOff = function() waypointBlip = nil end
GetHashKey = function(s) return #s end
local frontend = {}
ActivateFrontendMenu = function() frontend[#frontend + 1] = 'activate' end
PauseMenuceptionGoDeeper = function() frontend[#frontend + 1] = 'deeper' end
exports = function() end

local function resume()
	for _, thread in ipairs(threads) do
		if coroutine.status(thread) == 'suspended' then
			assert(coroutine.resume(thread))
		end
	end
end

local function lastMessage(action)
	for i = #messages, 1, -1 do
		if messages[i].action == action then
			return messages[i]
		end
	end
end

dofile('config.lua')
dofile('anchor.lua')
dofile('client.lua')

-- atalhos
assert(keymaps.coe_map_extended == 'Z' and keymaps.coe_map_full == 'M')
assert(commands.destino and commands.coe_map_extended)

-- ancora: normal e estendida
local normal = MapAnchor.Compute(1.0, 0.95, 16 / 9)
local big = MapAnchor.Compute(1.9, 0.95, 16 / 9)
assert(normal.l == big.l and normal.b == big.b)
assert(big.r - big.l > (normal.r - normal.l) * 1.8)
assert(MapAnchor.Distance({ x = 0, y = 0 }, { x = 3, y = 4 }) == 5)

-- Z abre o estendido, avisa o HUD e mostra o destino
waypointBlip = 5
commands.coe_map_extended()
resume()
assert(bigmap == true)
assert(zoom == Config.FootZoom)
assert(events[#events].name == 'coe_map:changed' and events[#events].args[1] == 'extended' and events[#events].args[2] == 1.9)
assert(lastMessage('mode').mode == 'extended' and lastMessage('mode').anchor.r == big.r)
local waypoint = lastMessage('waypoint')
assert(waypoint.active and waypoint.distance == 500)

-- Z de novo fecha
commands.coe_map_extended()
resume()
assert(bigmap == false and events[#events].args[2] == 1.0)
assert(lastMessage('waypoint').active == false)

-- radar escondido: Z nao abre
hidden = true
commands.coe_map_extended()
assert(bigmap == false)
hidden = false

-- mapa completo fecha o estendido e abre o menu do GTA
commands.coe_map_extended()
commands.coe_map_full()
resume()
resume()
assert(bigmap == false and frontend[1] == 'activate' and frontend[2] == 'deeper')

-- limpar destino
waypointBlip = 7
commands.destino(0, { 'limpar' })
assert(waypointBlip == nil)

print('coe_map tests passed')
