-- Client com natives simulados: balconistas e blips saem do config, sem esperar o servidor; o balconista aparece
-- perto da loja, ganha o alvo Comprar e some longe.
local threads, created, deleted, targets, blips = {}, {}, {}, {}, 0
local playerCoords
local function vec(x, y, z)
	return setmetatable({ x = x, y = y, z = z }, {
		__sub = function(a, b) return vec(a.x - b.x, a.y - b.y, a.z - b.z) end,
		__len = function(a) return math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z) end
	})
end
vector3 = vec
CreateThread = function(fn) threads[#threads + 1] = coroutine.create(fn) end
Wait = function() coroutine.yield() end
SetTimeout = function() end
GetGameTimer = function() return 0 end
joaat = function(name) return #name end
IsModelInCdimage = function() return true end
RequestModel = function() end
HasModelLoaded = function() return true end
SetModelAsNoLongerNeeded = function() end
local nextPed = 100
CreatePed = function(_, _, x, y, z) nextPed = nextPed + 1; created[#created + 1] = { id = nextPed, x = x, y = y, z = z }; return nextPed end
DoesEntityExist = function() return true end
DeleteEntity = function(ped) deleted[#deleted + 1] = ped end
for _, name in ipairs({ 'SetEntityInvincible', 'SetBlockingOfNonTemporaryEvents', 'SetPedCanRagdoll', 'FreezeEntityPosition',
	'SetBlipSprite', 'SetBlipDisplay', 'SetBlipColour', 'SetBlipScale', 'SetBlipAsShortRange', 'BeginTextCommandSetBlipName',
	'AddTextComponentSubstringPlayerName', 'EndTextCommandSetBlipName', 'RemoveBlip', 'SetNuiFocus', 'SendNUIMessage',
	'RegisterNUICallback', 'AddEventHandler', 'RequestCollisionAtCoord', 'PinInteriorInMemory',
	'SetEntityAsMissionEntity', 'SetPedDefaultComponentVariation', 'SetEntityHeading', 'RegisterCommand' }) do
	_G[name] = function() end
end
local rooms, forced = {}, {}
GetInteriorAtCoords = function() return 77 end
IsInteriorReady = function() return true end
GetGroundZFor_3dCoord = function(_, _, z) return true, z - 1.3 end
GetInteriorFromEntity = function(entity) return entity == 1 and 77 or 77 end
GetRoomKeyFromEntity = function(entity) return rooms[entity] or 0 end
ForceRoomForEntity = function(entity, interior, room) forced[#forced + 1] = { entity = entity, interior = interior, room = room }; rooms[entity] = room end
AddBlipForCoord = function() blips = blips + 1; return blips end
RegisterNetEvent = function() end
local statuses = {}
TriggerServerEvent = function(name, kind, info) if name == 'coe_shops:clientStatus' then statuses[#statuses + 1] = { kind = kind, info = info } end end
PlayerPedId = function() return 1 end
GetEntityCoords = function() return playerCoords end
GetCurrentResourceName = function() return 'coe_shops' end
promise = { new = function() return {} end }
exports = { coetarget = {
	AddTargetEntity = function(_, ped, options) targets[ped] = options end,
	RemoveTargetEntity = function(_, ped) targets[ped] = nil end
} }

dofile('config.lua')
dofile('shared/rules.lua')
dofile('client/main.lua')

local function tick()
	for _, co in ipairs(threads) do
		if coroutine.status(co) ~= 'dead' then
			assert(coroutine.resume(co))
		end
	end
end

local function eq(a, b, m)
	if a ~= b then error(('%s: esperado %s, veio %s'):format(m, tostring(b), tostring(a)), 2) end
end

local store = ShopsConfig.Stores[1]
playerCoords = vec(store.clerk[1] + 5, store.clerk[2], store.clerk[3])
tick()
local withBlip = 0
for _, entry in ipairs(ShopsConfig.Stores) do if ShopsConfig.Types[entry.type].blip ~= false then withBlip = withBlip + 1 end end
eq(blips, withBlip, 'blips sem servidor (LTD usa o blip do posto)')
eq(statuses[1].kind, 'loaded', 'avisa o servidor que carregou')
eq(statuses[1].info.blips, withBlip, 'quantos blips')
eq(statuses[2].kind, 'clerk', 'avisa o balconista criado')
eq(#created, 1, 'balconista perto da loja')
eq(math.abs(created[1].z - (store.clerk[3] - 0.8)) < 1e-9, true, 'pes no chao do interior')
local ped = created[1].id
eq(targets[ped][1].label, 'Comprar', 'alvo Comprar')
tick()
eq(#created, 1, 'nao duplica')
rooms[1] = 5
playerCoords = vec(store.clerk[1] + 2, store.clerk[2], store.clerk[3])
tick()
eq(forced[1] and forced[1].entity, ped, 'balconista vai para a sala do jogador')
eq(forced[1].room, 5, 'sala certa')
tick()
eq(#forced, 1, 'nao forca de novo')
playerCoords = vec(store.clerk[1] + 500, store.clerk[2], store.clerk[3])
tick()
eq(deleted[1], ped, 'some longe')
print('coe_shops client tests passed')
