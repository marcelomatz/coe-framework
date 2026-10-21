-- Última posição do personagem: lida no próprio servidor (o cliente não informa coordenadas),
-- amostrada só no mundo normal (bucket 0: fora de imóveis e visitas) e gravada periodicamente, ao trocar de personagem e ao sair.
local settings = CoeSpawnConfig.LastPosition
local ready = false
-- tracked[playerId] = { characterId, loaded, active, position, dirty, answered }
local tracked = {}

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
		TriggerClientEvent('coe_spawn:position', playerId, nil)
		return
	end
	entry.answered = true
	local deadline = GetGameTimer() + settings.TimeoutMs
	while not entry.loaded and GetGameTimer() < deadline do
		Wait(100)
	end
	TriggerClientEvent('coe_spawn:position', playerId, tracked[playerId] == entry and entry.position or nil)
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
end)
