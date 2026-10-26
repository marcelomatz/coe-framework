-- Última posição do personagem: lida no próprio servidor (o cliente não informa coordenadas),
-- amostrada só no mundo normal (bucket 0: fora de imóveis e visitas) e gravada periodicamente, ao trocar de personagem e ao sair.
local settings = CoeSpawnConfig.LastPosition
local ready = false
-- tracked[playerId] = { characterId, loaded, active, position, dirty, answered }
local tracked = {}
local defaultHotel = {
	name = 'Motel Pink Cage',
	enabled = true,
	entrance = { x = 325.5, y = -212.8, z = 54.0, h = 160.0 },
	room = { x = 151.4, y = -1007.8, z = -99.0, h = 0.0 },
	exit = { x = 151.3, y = -1004.8, z = -99.0, h = 180.0 },
	stash = { x = 151.8, y = -1001.2, z = -99.0, slots = 30, maxWeight = 50000 }
}
local starterHotel = defaultHotel


local function log(level, event, context)
	pcall(function()
		return exports.coe_logging:Log(level, 'spawn', event, context)
	end)
end

local function sample(playerId, entry)
	if not entry.active or GetPlayerRoutingBucket(playerId) ~= 0 then
		return
	end
	local ped = GetPlayerPed(playerId)
	if not ped or ped == 0 or not DoesEntityExist(ped) then
		return
	end
	local coords = GetEntityCoords(ped)
	local position = SpawnPositions.Normalize({ x = coords.x, y = coords.y, z = coords.z, heading = GetEntityHeading(ped) }, settings.Bounds)
	if position and SpawnPositions.Moved(entry.position, position, settings.MinMove) then
		entry.position = position
		entry.dirty = true
	end
end

local function flush(entry)
	if not ready or not entry.dirty or not entry.position then
		return
	end
	entry.dirty = false
	local saved, errorCode = SpawnPersistence.Save(entry.characterId, entry.position)
	if not saved then
		entry.dirty = true
		log('warn', 'position_save_failed', { character_id = entry.characterId, error_code = errorCode })
	end
end

-- Encerra o acompanhamento: última leitura e gravação imediata.
local function release(playerId)
	local entry = tracked[playerId]
	if not entry then
		return
	end
	tracked[playerId] = nil
	sample(playerId, entry)
	CreateThread(function()
		flush(entry)
	end)
end

AddEventHandler('coe_core:characterLoaded', function(playerId, characterId)
	if tracked[playerId] then
		release(playerId)
	end
	local entry = { characterId = tostring(characterId), loaded = false, active = false }
	tracked[playerId] = entry
	local deadline = GetGameTimer() + settings.TimeoutMs
	while not ready and GetGameTimer() < deadline do
		Wait(250)
	end
	if ready then
		local stored, errorCode = SpawnPersistence.Load(entry.characterId)
		if stored == nil then
			log('warn', 'position_load_failed', { character_id = entry.characterId, error_code = errorCode })
		elseif stored and not entry.position then
			entry.position = SpawnPositions.Normalize(stored, settings.Bounds)
		end
	end
	entry.loaded = true
end)

-- O cliente pede a posição uma vez por carregamento de personagem e aguarda a resposta antes do spawn.
RegisterNetEvent('coe_spawn:requestPosition', function()
	local playerId = source
	local entry = tracked[playerId]
	if not entry or entry.answered then
		TriggerClientEvent('coe_spawn:position', playerId, nil, starterHotel)
		return
	end
	entry.answered = true
	local deadline = GetGameTimer() + settings.TimeoutMs
	while not entry.loaded and GetGameTimer() < deadline do
		Wait(100)
	end
	local pos = tracked[playerId] == entry and entry.position or nil
	local isFirstSpawn = (pos == nil)
	if isFirstSpawn and starterHotel.enabled then
		pos = {
			x = starterHotel.room.x,
			y = starterHotel.room.y,
			z = starterHotel.room.z,
			heading = starterHotel.room.h
		}
	end
	TriggerClientEvent('coe_spawn:position', playerId, pos, starterHotel)
end)

RegisterNetEvent('coe_spawn:openHotelStash', function()
	local playerId = source
	local charId = Core.Players.GetActiveCharacterId(playerId)
	if not charId then return end
	local ped = GetPlayerPed(playerId)
	if not ped or ped == 0 then return end
	local coords = GetEntityCoords(ped)
	local dx = coords.x - starterHotel.stash.x
	local dy = coords.y - starterHotel.stash.y
	local dz = coords.z - starterHotel.stash.z
	local distSq = dx * dx + dy * dy + dz * dz
	if distSq > 16.0 then return end

	pcall(function()
		exports.coe_inventory:OpenStash(playerId, 'stash:hotel:' .. charId, {
			label = starterHotel.name .. ' - Quarto',
			slots = starterHotel.stash.slots,
			maxWeight = starterHotel.stash.maxWeight,
			position = { x = starterHotel.stash.x, y = starterHotel.stash.y, z = starterHotel.stash.z },
			radius = 4.0
		})
	end)
end)

exports('GetStarterHotel', function()
	return starterHotel
end)

exports('SetStarterHotel', function(data)
	if type(data) ~= 'table' then
		return false, 'invalid_payload'
	end
	starterHotel = {
		name = tostring(data.name or starterHotel.name):sub(1, 64),
		enabled = data.enabled == true,
		entrance = {
			x = tonumber(data.entrance and data.entrance.x) or starterHotel.entrance.x,
			y = tonumber(data.entrance and data.entrance.y) or starterHotel.entrance.y,
			z = tonumber(data.entrance and data.entrance.z) or starterHotel.entrance.z,
			h = tonumber(data.entrance and data.entrance.h) or starterHotel.entrance.h
		},
		room = {
			x = tonumber(data.room and data.room.x) or starterHotel.room.x,
			y = tonumber(data.room and data.room.y) or starterHotel.room.y,
			z = tonumber(data.room and data.room.z) or starterHotel.room.z,
			h = tonumber(data.room and data.room.h) or starterHotel.room.h
		},
		exit = {
			x = tonumber(data.exit and data.exit.x) or starterHotel.exit.x,
			y = tonumber(data.exit and data.exit.y) or starterHotel.exit.y,
			z = tonumber(data.exit and data.exit.z) or starterHotel.exit.z,
			h = tonumber(data.exit and data.exit.h) or starterHotel.exit.h
		},
		stash = {
			x = tonumber(data.stash and data.stash.x) or starterHotel.stash.x,
			y = tonumber(data.stash and data.stash.y) or starterHotel.stash.y,
			z = tonumber(data.stash and data.stash.z) or starterHotel.stash.z,
			slots = math.tointeger(data.stash and data.stash.slots) or starterHotel.stash.slots,
			maxWeight = math.tointeger(data.stash and data.stash.maxWeight) or starterHotel.stash.maxWeight
		}
	}
	if ready then
		SpawnPersistence.SaveStarterHotel(starterHotel)
	end
	TriggerClientEvent('coe_spawn:syncHotel', -1, starterHotel)
	return true
end)

-- Só depois do spawn a posição do ped é a do personagem (antes ele está parado na seleção).
RegisterNetEvent('coe_spawn:spawned', function()
	local entry = tracked[source]
	if entry and entry.answered then
		entry.active = true
	end
end)

Core.Events.On('player.characterUnloaded', function(event)
	if type(event) == 'table' and event.source then
		release(event.source)
	end
end)

AddEventHandler('playerDropped', function()
	release(source)
end)

CreateThread(function()
	local lastFlush = GetGameTimer()
	while true do
		Wait(settings.SampleMs)
		for playerId, entry in pairs(tracked) do
			sample(playerId, entry)
		end
		if GetGameTimer() - lastFlush >= settings.FlushMs then
			lastFlush = GetGameTimer()
			for _, entry in pairs(tracked) do
				flush(entry)
			end
		end
	end
end)

CreateThread(function()
	while true do
		local initialized, errorCode = SpawnPersistence.Initialize()
		if initialized then
			break
		end
		if errorCode ~= 'database_not_ready' then
			log('error', 'database_initialization_failed', { error_code = errorCode or 'database_error', retry_ms = 5000 })
			Wait(5000)
		else
			Wait(1000)
		end
	end
	ready = true
	local loadedHotel = SpawnPersistence.LoadStarterHotel()
	if loadedHotel then
		starterHotel = loadedHotel
	end
end)
