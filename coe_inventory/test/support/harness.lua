-- Harness de testes do coe_inventory: stubs de FiveM/Core + carga dos arquivos
-- server `application/*` na ordem do fxmanifest.lua. Cada teste roda em um processo
-- Lua próprio, a partir da pasta do resource (`lua test/<arquivo>.lua`).
dofile([=[../coe_core/core/shared/bootstrap.lua]=])
dofile([=[../coe_core/core/shared/functions.lua]=])
dofile([=[../coe_core/core/shared/classes.lua]=])

local H = {
	storage = {},
	fail = { set = false, setMany = false },
	activeCharacters = {},
	networkHandlers = {},
	localHandlers = {},
	systemHandlers = {},
	sentClientEvents = {},
	broadcasts = {},
	emitted = {},
	exported = {},
	entities = {},
	netEntities = {},
	timer = { now = 0, step = 400 },
	logged = {},
	audited = {}
}

local jsonRecords = {}
local jsonSequence = 0
json = {
	encode = function(value)
		jsonSequence = jsonSequence + 1
		local key = 'record:' .. jsonSequence
		jsonRecords[key] = Core.Functions.DeepCopy(value)
		return key
	end,
	decode = function(key)
		if not jsonRecords[key] then
			error('invalid test JSON record')
		end
		return Core.Functions.DeepCopy(jsonRecords[key])
	end
}

H.storage['inventory:player:license:legacy'] = 'untouched legacy value'
local persistence = {
	Get = function(key)
		return H.storage[key]
	end,
	Set = function(key, value)
		if H.fail.set then
			H.fail.set = false
			return false
		end
		H.storage[key] = value
		return true
	end,
	SetMany = function(records)
		if H.fail.setMany then
			H.fail.setMany = false
			return false, 'transaction_failed'
		end
		for _, record in ipairs(records) do
			H.storage[record.key] = record.value
		end
		return true
	end,
	Delete = function(key)
		H.storage[key] = nil
		return true
	end,
	ListKeys = function(prefix)
		local keys = {}
		for key in pairs(H.storage) do
			if key:sub(1, #prefix) == prefix then keys[#keys + 1] = key end
		end
		return keys
	end,
	IsReady = function()
		return true
	end,
	Initialize = function()
		return true
	end
}

Core.Players = {
	GetActiveCharacterId = function(playerSource)
		local characterId = H.activeCharacters[playerSource]
		if not characterId then
			return nil, 'character_not_loaded'
		end
		return characterId
	end
}
H.sessions = {}
Core.SessionRegistry = {
	Get = function(playerSource)
		return H.sessions[playerSource]
	end
}
Core.Events = {
	OnNet = function(name, callback)
		H.networkHandlers[name] = callback
		return callback
	end,
	On = function(name, callback)
		H.localHandlers[name] = callback
		return callback
	end,
	ToClient = function(target, name, ...)
		H.sentClientEvents[#H.sentClientEvents + 1] = { target = target, name = name, args = { ... } }
		return true
	end,
	ToAll = function(name, ...)
		H.broadcasts[#H.broadcasts + 1] = { name = name, args = { ... } }
		return true
	end,
	Emit = function(name, ...)
		H.emitted[#H.emitted + 1] = { name = name, args = { ... } }
		return true
	end
}

exports = setmetatable({
	coe_logging = {
		Log = function(_, level, category, event, context)
			H.logged[#H.logged + 1] = { level = level, category = category, event = event, context = context }
			return true
		end
	},
	coe_audit = {
		Record = function(_, level, category, event, context)
			H.audited[#H.audited + 1] = { level = level, category = category, event = event, context = context }
			return true
		end
	}
}, {
	__call = function(_, name, callback)
		H.exported[name] = callback
	end
})

-- Vetores mínimos: subtração e comprimento (distância).
local vectorMeta = {}
vectorMeta.__index = vectorMeta
vectorMeta.__sub = function(a, b)
	return setmetatable({ x = a.x - b.x, y = a.y - b.y, z = a.z - b.z }, vectorMeta)
end
vectorMeta.__len = function(a)
	return math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z)
end
function vector3(x, y, z)
	return setmetatable({ x = x, y = y, z = z }, vectorMeta)
end

function GetGameTimer()
	H.timer.now = H.timer.now + H.timer.step
	return H.timer.now
end

function GetPlayerName()
	return 'Test player'
end

function GetCurrentResourceName()
	return 'coe_inventory'
end

function Wait()
	-- O harness não simula passagem de tempo; os waits só aparecem em esperas por entidade.
	H.timer.now = H.timer.now + 1000
end

-- Entidades: jogadores usam o ID como handle do ped; objetos recebem handles novos.
local nextEntity = 1000
local nextNetId = 500
function H.placePlayer(playerId, x, y, z)
	H.entities[playerId] = { coords = vector3(x or 0.0, y or 0.0, z or 0.0), heading = 0.0, player = true }
end

function H.createWorldObject(model, coords, ownerId)
	nextEntity = nextEntity + 1
	nextNetId = nextNetId + 1
	H.entities[nextEntity] = { model = model, coords = coords, heading = 0.0, owner = ownerId, netId = nextNetId }
	H.netEntities[nextNetId] = nextEntity
	return nextEntity, nextNetId
end

function GetPlayerPed(playerId)
	if not H.entities[playerId] then
		H.placePlayer(playerId, playerId * 1.0, 0.0, 0.0)
	end
	return playerId
end
function GetEntityCoords(handle)
	return H.entities[handle].coords
end
function GetEntityHeading(handle)
	return H.entities[handle].heading
end
function SetEntityHeading(handle, heading)
	H.entities[handle].heading = heading
end
function FreezeEntityPosition() end
H.entityStates = {}
function Entity(handle)
	H.entityStates[handle] = H.entityStates[handle] or {}
	return { state = { set = function(_, key, value) H.entityStates[handle][key] = value end } }
end
function DoesEntityExist(handle)
	return H.entities[handle] ~= nil
end
function DeleteEntity(handle)
	local entity = H.entities[handle]
	if entity and entity.netId then
		H.netEntities[entity.netId] = nil
	end
	H.entities[handle] = nil
end
function GetHashKey(model)
	return #model * 1000 + model:byte(1)
end
function GetEntityModel(handle)
	return GetHashKey(H.entities[handle].model)
end
function CreateObject(modelHash, x, y, z)
	if H.failCreateObject then
		error('CreateObject unavailable')
	end
	local handle, netId = H.createWorldObject(nil, vector3(x, y, z), nil)
	H.entities[handle].modelHash = modelHash
	H.entities[handle].model = ''
	return handle
end
function NetworkGetNetworkIdFromEntity(handle)
	return H.entities[handle] and H.entities[handle].netId or 0
end
function NetworkGetEntityFromNetworkId(netId)
	return H.netEntities[netId] or 0
end
function NetworkGetEntityOwner(handle)
	return H.entities[handle].owner
end

function RegisterCommand() end
function AddEventHandler(name, callback)
	H.systemHandlers[name] = callback
	return #H.systemHandlers
end

H.threads = {}
H.timers = {}
function SetTimeout(_, callback)
	H.timers[#H.timers + 1] = callback
end
function CreateThread(callback)
	H.threads[#H.threads + 1] = callback
end

function H.as(playerId)
	source = playerId
end

function H.assertEqual(actual, expected, message)
	if actual ~= expected then
		error(('%s: expected %s, got %s'):format(message, tostring(expected), tostring(actual)), 2)
	end
end

function H.lastClientEvent(name)
	for index = #H.sentClientEvents, 1, -1 do
		if H.sentClientEvents[index].name == name then
			return H.sentClientEvents[index]
		end
	end
end

function H.lastActionResult()
	return H.lastClientEvent('inventory.actionResult')
end

function H.clearEvents()
	H.sentClientEvents = {}
	H.broadcasts = {}
	H.emitted = {}
	H.logged = {}
	H.audited = {}
end

-- Carrega os arquivos `application/*` do server_scripts do fxmanifest, na ordem declarada.
local manifestFiles = {}
local manifestNames = {
	'fx_version', 'game', 'lua54', 'name', 'description', 'dependencies', 'ui_page',
	'files', 'client_scripts'
}
local savedGlobals = {}
for _, key in ipairs(manifestNames) do
	savedGlobals[key] = rawget(_G, key)
	_G[key] = function() end
end
local sharedFiles = {}
function shared_scripts(list)
	for _, entry in ipairs(list) do
		if entry:sub(1, 1) ~= '@' then
			sharedFiles[#sharedFiles + 1] = entry
		end
	end
end
function server_scripts(list)
	for _, entry in ipairs(list) do
		if entry:sub(1, 12) == 'application/' then
			manifestFiles[#manifestFiles + 1] = entry
		end
	end
end
dofile('fxmanifest.lua')
server_scripts = nil
for _, key in ipairs(manifestNames) do
	_G[key] = savedGlobals[key]
end

dofile([=[../coe_core/lib/logger.lua]=])

for _, file in ipairs(sharedFiles) do
	dofile((file:gsub('/', '/')))
end
Inventory.Persistence = persistence

assert(#manifestFiles > 0, 'fxmanifest.lua não lista arquivos application/')
H.files = manifestFiles
for _, file in ipairs(manifestFiles) do
	dofile((file:gsub('/', '/')))
end

return H
