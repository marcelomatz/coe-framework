local config = CoeVehiclesConfig
local _t_inst = (Core and Core.Locale and Core.Locale.New) and Core.Locale.New({
	default = (config and config.Locale) or (Core and Core.Locale and Core.Locale.GetDefaultLang()) or 'pt-BR',
	locales = Locales or {}
})
local _t = function(k, params)
	if type(_t_inst) == 'table' then
		if _t_inst.T then
			return _t_inst:T(k, params)
		end
		local lang = _t_inst.lang or 'pt-BR'
		local dict = (_t_inst.locales and _t_inst.locales[lang]) or (Locales and Locales[lang]) or (Locales and Locales['pt-BR'])
		if dict and dict[k] then
			return dict[k]
		end
	elseif type(_t_inst) == 'function' then
		return _t_inst(k, params)
	end
	return (Locales and Locales['pt-BR'] and Locales['pt-BR'][k]) or k
end
local ready = false
local CACHE_TTL_MS = 30 * 60 * 1000

-- vehicleId -> entity e entity -> vehicleId dos veículos criados por este resource.
local trackedByVehicle = {}
local vehicleByEntity = {}
local mileageBucket = {}

local function log(level, category, event, context)
	pcall(function()
		return exports.coe_logging:Log(level, category, event, context)
	end)
end

local function audit(event, context)
	pcall(function()
		return exports.coe_audit:Record('info', 'audit', event, context)
	end)
end

local registry = VehicleRegistry.New({
	persistence = VehiclesPersistence,
	config = config,
	now = GetGameTimer,
	random = math.random,
	cacheTtlMs = CACHE_TTL_MS,
	audit = audit
})

local keys = VehicleKeys.New({
	persistence = VehiclesPersistence,
	registry = registry,
	config = config,
	audit = audit
})

local function callerName()
	return GetInvokingResource() or GetCurrentResourceName()
end

local function isWriter()
	return CoeAccess.Allowed(callerName(), config.Ace.Write, config.WriterResources)
end

local function isMileageEditor()
	return CoeAccess.Allowed(callerName(), config.Ace.Mileage, config.MileageEditors)
end

local function publicRecord(record)
	return {
		id = record.id,
		ownerCharacterId = record.ownerCharacterId,
		model = record.model,
		plate = record.plate,
		mileage = record.mileage,
		state = record.state
	}
end

local function bucketOf(meters)
	return meters // 100
end

local function attach(entity, record)
	Core.Platform.Entities.SetState(entity, 'coe:vehicleId', record.id, true)
	Core.Platform.Entities.SetState(entity, 'coe:mileage', record.mileage, true)
	trackedByVehicle[record.id] = entity
	vehicleByEntity[entity] = record.id
	mileageBucket[record.id] = bucketOf(record.mileage)
	registry.Pin(record.id)
	TriggerEvent('coe_vehicles:spawned', record.id, entity)
end

local function detach(vehicleId)
	local entity = trackedByVehicle[vehicleId]
	trackedByVehicle[vehicleId] = nil
	mileageBucket[vehicleId] = nil
	if entity then
		vehicleByEntity[entity] = nil
	end
	registry.Unpin(vehicleId)
	TriggerEvent('coe_vehicles:released', vehicleId)
	return entity
end

-- Atualiza o state bag (em passos de 100 m) e avisa outros resources do servidor.
local function publishMileage(vehicleId, entity, total)
	local bucket = bucketOf(total)
	if bucket ~= mileageBucket[vehicleId] then
		mileageBucket[vehicleId] = bucket
		Core.Platform.Entities.SetState(entity, 'coe:mileage', total, true)
		TriggerEvent('coe_vehicles:mileageChanged', vehicleId, entity, total)
	end
end

local function spawn(vehicleId, x, y, z, heading, vehicleType)
	if not ready then
		return nil, 'not_ready'
	end
	if trackedByVehicle[vehicleId] then
		return nil, 'already_spawned'
	end
	local record, errorCode = registry.Get(vehicleId)
	if not record then
		return nil, errorCode
	end
	if type(x) ~= 'number' or type(y) ~= 'number' or type(z) ~= 'number' then
		return nil, 'invalid_coords'
	end

	local entity = CreateVehicleServerSetter(joaat(record.model), vehicleType or 'automobile', x, y, z, heading or 0.0)
	if not entity or entity == 0 then
		return nil, 'spawn_failed'
	end
	local attempts = 0
	while not Core.Platform.Entities.Exists(entity) and attempts < 40 do
		attempts = attempts + 1
		Wait(50)
	end
	if not Core.Platform.Entities.Exists(entity) then
		return nil, 'spawn_failed'
	end

	Core.Platform.Vehicles.SetPlate(entity, record.plate)
	attach(entity, record)
	registry.SetState(record.id, 'out')
	return entity
end

-- Entidade na rua com o state bag do veículo, mas fora do rastreio (ex.: coe_vehicles reiniciou com o carro na rua).
local function findUntracked(vehicleId)
	for _, entity in ipairs(GetAllVehicles()) do
		if Core.Platform.Entities.Exists(entity) and tostring(Entity(entity).state['coe:vehicleId']) == vehicleId then
			return entity
		end
	end
	return nil
end

local function store(vehicleId)
	local entity = trackedByVehicle[vehicleId]
	if not entity then
		entity = findUntracked(vehicleId)
		if not entity then
			return nil, 'vehicle_not_spawned'
		end
		trackedByVehicle[vehicleId] = entity
		vehicleByEntity[entity] = vehicleId
	end
	registry.Flush(vehicleId)
	detach(vehicleId)
	if Core.Platform.Entities.Exists(entity) then
		Core.Platform.Entities.Delete(entity)
	end
	return registry.SetState(vehicleId, 'stored')
end

exports('Create', function(data)
	if not isWriter() then
		return 'forbidden'
	end
	if not ready then
		return 'not_ready'
	end
	local record, errorCode = registry.Create(data)
	if not record then
		return errorCode or 'unknown_error'
	end
	return publicRecord(record)
end)

exports('Get', function(vehicleId)
	local record = registry.Get(vehicleId)
	return record and publicRecord(record) or nil
end)

exports('GetByPlate', function(plate)
	local record = registry.GetByPlate(plate)
	return record and publicRecord(record) or nil
end)

exports('ListByOwner', function(characterId)
	local list = registry.ListByOwner(characterId)
	if not list then
		return nil
	end
	local result = {}
	for index, record in ipairs(list) do
		result[index] = publicRecord(record)
	end
	return result
end)

exports('GetEntity', function(vehicleId)
	local entity = trackedByVehicle[vehicleId]
	if entity and Core.Platform.Entities.Exists(entity) then
		return entity
	end
	return nil
end)

exports('GetMileage', function(vehicleId)
	local record = registry.Get(vehicleId)
	return record and record.mileage or nil
end)

exports('SetMileage', function(vehicleId, meters)
	if not isMileageEditor() then
		log('warn', 'security', 'vehicle_mileage_forbidden', { operation = callerName() })
		return 'forbidden'
	end
	local saved, errorCode = registry.SetMileage(vehicleId, meters, callerName())
	if not saved then
		return errorCode or 'unknown_error'
	end
	local entity = trackedByVehicle[vehicleId]
	if entity and Core.Platform.Entities.Exists(entity) then
		publishMileage(vehicleId, entity, saved)
	end
	return true
end)

exports('Spawn', function(vehicleId, x, y, z, heading, vehicleType)
	if not isWriter() then
		return 'forbidden'
	end
	local entity, errorCode = spawn(vehicleId, x, y, z, heading, vehicleType)
	if not entity then
		return errorCode or 'unknown_error'
	end
	return Core.Platform.Entities.GetNetworkId(entity)
end)

exports('Store', function(vehicleId)
	if not isWriter() then
		return 'forbidden'
	end
	local stored, errorCode = store(vehicleId)
	return stored == true or errorCode or 'unknown_error'
end)

local function playerByCharacter(characterId)
	for _, id in ipairs(GetPlayers()) do
		local playerId = tonumber(id)
		if Core.Players.GetActiveCharacterId(playerId) == characterId then
			return playerId
		end
	end
	return nil
end

local function notifyKeysChanged(characterId)
	local playerId = playerByCharacter(characterId)
	if playerId then
		TriggerClientEvent('coe_vehicles:keysChanged', playerId)
	end
end

exports('HasKey', function(characterId, vehicleId)
	return keys.HasKey(characterId, vehicleId)
end)

exports('GiveKey', function(vehicleId, characterId)
	if not isWriter() then
		return 'forbidden'
	end
	local granted, errorCode = keys.Grant(vehicleId, characterId, nil)
	if not granted then
		return errorCode or 'unknown_error'
	end
	notifyKeysChanged(characterId)
	return true
end)

exports('RevokeKey', function(vehicleId, characterId)
	if not isWriter() then
		return 'forbidden'
	end
	local revoked, errorCode = keys.Revoke(vehicleId, characterId, nil)
	if not revoked then
		return errorCode or 'unknown_error'
	end
	notifyKeysChanged(characterId)
	return true
end)

exports('ListKeyHolders', function(vehicleId)
	return keys.ListHolders(vehicleId)
end)

exports('IsReady', function()
	return ready
end)

-- Reporte de distância do motorista (lote). Validado inteiramente no servidor.
RegisterNetEvent('coe_vehicles:reportMileage', function(netId, meters)
	local playerId = source
	if math.type(netId) ~= 'integer' or type(meters) ~= 'number' then
		return
	end
	local entity = Core.Platform.Entities.FromNetworkId(netId)
	if not entity or not Core.Platform.Entities.Exists(entity) then
		return
	end
	local vehicleId = vehicleByEntity[entity]
	if not vehicleId or GetPedInVehicleSeat(entity, -1) ~= GetPlayerPed(playerId) then
		return
	end

	local total, errorCode = registry.ReportMileage(vehicleId, meters, GetGameTimer())
	if not total then
		if errorCode == 'implausible_delta' then
			log('warn', 'security', 'vehicle_mileage_rejected', {
				source = playerId,
				error_code = errorCode,
				vehicle_id = vehicleId
			})
		end
		return
	end

	publishMileage(vehicleId, entity, total)
end)

AddEventHandler('entityRemoved', function(entity)
	local vehicleId = vehicleByEntity[entity]
	if not vehicleId then
		return
	end
	detach(vehicleId)
	CreateThread(function()
		registry.Flush(vehicleId)
		registry.SetState(vehicleId, 'stored')
	end)
end)

local function reply(playerId, kind, message)
	if playerId > 0 then
		pcall(function()
			exports.coe_notify:Notify(playerId, kind, message)
		end)
	end
	print(('[coe_vehicles] %s'):format(message))
end

-- Ferramentas de teste/administração (ACE: command.coe_vehicle_create / command.coe_vehicle_mileage).
RegisterCommand('coe_vehicle_create', function(playerId, args)
	if playerId <= 0 then
		reply(0, 'error', _t('in_game_only'))
		return
	end
	local characterId = Core.Players.GetActiveCharacterId(playerId)
	if not characterId then
		reply(playerId, 'error', _t('character_not_loaded'))
		return
	end
	local record = registry.Create({ characterId = characterId, model = args[1], plate = args[2] })
	if not record then
		reply(playerId, 'error', _t('create_failed'))
		return
	end
	local ped = GetPlayerPed(playerId)
	local coords = Core.Platform.Entities.GetCoords(ped)
	if not coords then
		reply(playerId, 'error', _t('coords_unavailable'))
		return
	end
	local entity = spawn(record.id, coords.x, coords.y, coords.z, Core.Platform.Entities.GetHeading(ped))
	if not entity then
		reply(playerId, 'error', _t('spawn_failed'))
		return
	end
	Core.Platform.Peds.SetIntoVehicle(ped, entity, -1)
	reply(playerId, 'success', _t('vehicle_created', { model = record.model, plate = record.plate }))
end, true)

RegisterCommand('coe_vehicle_mileage', function(playerId, args)
	local record = registry.GetByPlate(table.concat(args, ' ', 1, math.max(#args - 1, 0)))
	local kilometers = tonumber(args[#args])
	if not record or not kilometers then
		reply(playerId, 'error', _t('mileage_usage'))
		return
	end
	local saved = registry.SetMileage(record.id, math.floor(kilometers * 1000), 'coe_vehicles')
	if not saved then
		reply(playerId, 'error', _t('invalid_value'))
		return
	end
	local entity = trackedByVehicle[record.id]
	if entity and Core.Platform.Entities.Exists(entity) then
		publishMileage(record.id, entity, saved)
	end
	reply(playerId, 'success', _t('mileage_updated', { plate = record.plate, kilometers = kilometers }))
end, true)

-- O client pergunta se o jogador pode dirigir o veículo; a decisão é sempre do servidor.
local lastKeyCheck = {}

RegisterNetEvent('coe_vehicles:checkKey', function(netId)
	local playerId = source
	if math.type(netId) ~= 'integer' then
		return
	end
	local nowMs = GetGameTimer()
	if lastKeyCheck[playerId] and nowMs - lastKeyCheck[playerId] < config.KeyCheckCooldownMs then
		return
	end
	lastKeyCheck[playerId] = nowMs

	local entity = Core.Platform.Entities.FromNetworkId(netId)
	local vehicleId = entity and vehicleByEntity[entity]
	if not vehicleId then
		return
	end
	local characterId = Core.Players.GetActiveCharacterId(playerId)
	TriggerClientEvent('coe_vehicles:keyResult', playerId, netId, characterId ~= nil and keys.HasKey(characterId, vehicleId))
end)

AddEventHandler('playerDropped', function()
	local playerId = source
	lastKeyCheck[playerId] = nil
	local characterId = Core.Players.GetActiveCharacterId(playerId)
	if characterId then
		keys.Forget(characterId)
	end
end)

-- Veículo ao alcance do jogador: o que ele ocupa ou o mais próximo dentro do raio de empréstimo.
local function vehicleNear(playerId)
	local ped = GetPlayerPed(playerId)
	local occupied = GetVehiclePedIsIn(ped, false)
	if occupied ~= 0 and vehicleByEntity[occupied] then
		return vehicleByEntity[occupied]
	end
	local origin = Core.Platform.Entities.GetCoords(ped)
	if not origin then
		return nil
	end
	local bestId, bestDistance = nil, config.LendDistanceMeters
	for vehicleId, entity in pairs(trackedByVehicle) do
		if Core.Platform.Entities.Exists(entity) then
			local coords = Core.Platform.Entities.GetCoords(entity)
			if coords then
				local distance = #(coords - origin)
				if distance <= bestDistance then
					bestId, bestDistance = vehicleId, distance
				end
			end
		end
	end
	return bestId
end

local function keyCommandContext(playerId, args)
	local characterId = Core.Players.GetActiveCharacterId(playerId)
	if not characterId then
		reply(playerId, 'error', _t('character_not_loaded'))
		return nil
	end
	local targetPlayer = tonumber(args[1])
	if not targetPlayer or targetPlayer == playerId or not GetPlayerName(targetPlayer) then
		reply(playerId, 'error', _t('target_player_invalid'))
		return nil
	end
	local targetCharacter = Core.Players.GetActiveCharacterId(targetPlayer)
	if not targetCharacter then
		reply(playerId, 'error', _t('target_character_missing'))
		return nil
	end
	local vehicleId = vehicleNear(playerId)
	if not vehicleId then
		reply(playerId, 'error', _t('no_vehicle_near'))
		return nil
	end
	return characterId, targetPlayer, targetCharacter, vehicleId
end

local KEY_ERRORS = {
	not_owner = 'key_error_not_owner',
	key_limit_reached = 'key_error_limit_reached',
	already_owner = 'key_error_already_owner'
}

RegisterCommand('chave_emprestar', function(playerId, args)
	if playerId <= 0 then
		return
	end
	local characterId, targetPlayer, targetCharacter, vehicleId = keyCommandContext(playerId, args)
	if not characterId then
		return
	end
	local origin = Core.Platform.Entities.GetCoords(GetPlayerPed(playerId))
	local targetCoords = Core.Platform.Entities.GetCoords(GetPlayerPed(targetPlayer))
	if not origin or not targetCoords or #(targetCoords - origin) > config.LendDistanceMeters then
		reply(playerId, 'error', _t('player_too_far'))
		return
	end
	local granted, errorCode = keys.Lend(characterId, vehicleId, targetCharacter)
	if not granted then
		reply(playerId, 'error', _t(KEY_ERRORS[errorCode] or 'lend_failed'))
		return
	end
	local record = registry.Get(vehicleId)
	TriggerClientEvent('coe_vehicles:keysChanged', targetPlayer)
	reply(playerId, 'success', _t('key_lent', { plate = record.plate }))
	reply(targetPlayer, 'success', _t('key_received', { plate = record.plate }))
end, false)

RegisterCommand('chave_retirar', function(playerId, args)
	if playerId <= 0 then
		return
	end
	local characterId, targetPlayer, targetCharacter, vehicleId = keyCommandContext(playerId, args)
	if not characterId then
		return
	end
	local revoked, errorCode = keys.Take(characterId, vehicleId, targetCharacter)
	if not revoked then
		reply(playerId, 'error', _t(KEY_ERRORS[errorCode] or 'take_failed'))
		return
	end
	local record = registry.Get(vehicleId)
	TriggerClientEvent('coe_vehicles:keysChanged', targetPlayer)
	reply(playerId, 'success', _t('key_revoked', { plate = record.plate }))
	reply(targetPlayer, 'warning', _t('key_revoked_target', { plate = record.plate }))
end, false)

CreateThread(function()
	local waitingLogged = false
	while true do
		local initialized, errorCode = VehiclesPersistence.Initialize()
		if initialized then
			initialized, errorCode = VehiclesPersistence.ResetOutState()
		end
		if initialized then
			break
		end
		if errorCode == 'database_not_ready' then
			if not waitingLogged then
				log('info', 'persistence', 'database_waiting', {})
				waitingLogged = true
			end
			Wait(1000)
		else
			log('error', 'persistence', 'database_initialization_failed', {
				error_code = errorCode or 'database_error',
				retry_ms = 5000
			})
			Wait(5000)
		end
	end
	ready = true

	local failureLogged = false
	while true do
		Wait(config.FlushIntervalMs)
		local ok, flushError = registry.Flush()
		if not ok then
			if not failureLogged then
				log('error', 'persistence', 'vehicle_mileage_flush_failed', { error_code = flushError or 'database_error' })
				failureLogged = true
			end
		else
			failureLogged = false
		end
	end
end)

AddEventHandler('onResourceStop', function(resourceName)
	if resourceName ~= GetCurrentResourceName() or not ready then
		return
	end
	-- Melhor esforço: grava a quilometragem pendente e remove os veículos gerados.
	for _ = 1, 10 do
		if registry.PendingCount() == 0 then
			break
		end
		local ok = registry.Flush()
		if not ok then
			break
		end
	end
	for _, entity in pairs(trackedByVehicle) do
		if Core.Platform.Entities.Exists(entity) then
			Core.Platform.Entities.Delete(entity)
		end
	end
end)
