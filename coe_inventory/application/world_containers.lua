-- Containers soltos no mundo: criação, adoção, restauração e sincronização.
local S = Inventory.Service

function S.getWorldContainerByNetId(netId)
	for _, container in pairs(S.worldContainers) do
		if container.netId == netId then
			return container
		end
	end
	return nil
end

-- Containers do mundo são efêmeros: existem só em memória e somem no restart. Cada um deixa
-- um marcador mínimo no banco (`worldref:<containerId>`), gravado ao soltar e apagado ao
-- recolher; no boot, marcadores restantes têm o conteúdo apagado (ver purgeWorldContainers).
-- Isso evita um blob único reescrito a cada ação e sobrevive a quedas do servidor.
S.WORLD_REF_PREFIX = 'worldref:'

function S.markWorldContainer(containerId)
	return Inventory.Persistence.Set(S.WORLD_REF_PREFIX .. containerId, '{}')
end

function S.unmarkWorldContainer(containerId)
	return Inventory.Persistence.Delete(S.WORLD_REF_PREFIX .. containerId)
end

function S.countWorldContainers(characterId)
	local total, owned = 0, 0
	for _, container in pairs(S.worldContainers) do
		total = total + 1
		if characterId and container.droppedBy == characterId then
			owned = owned + 1
		end
	end
	return total, owned
end

-- Valida o limite global e o limite por personagem antes de aceitar uma nova maleta.
function S.checkWorldContainerLimits(playerId)
	local characterId = Core.Players.GetActiveCharacterId(playerId)
	local total, owned = S.countWorldContainers(characterId)
	if total >= Config.Server.maxWorldContainers then
		return nil, 'world_container_limit'
	end
	if characterId and owned >= Config.Server.maxWorldContainersPerPlayer then
		return nil, 'world_container_limit_player'
	end
	return characterId
end
-- Publica o containerId estável na entidade para que outros resources a identifiquem
-- sem depender de netId ou de coordenadas.
S.CONTAINER_STATE_KEY = 'coe:containerId'
function S.tagWorldContainer(entity, containerId)
	Entity(entity).state:set(S.CONTAINER_STATE_KEY, containerId, true)
end

function S.createWorldContainer(itemName, metadata, coords, heading)
	local model = S.containerWorldModels[itemName]
	local definition = Inventory.Items.Get(itemName)
	if not model or not definition or not definition.container or type(metadata) ~= 'table'
		or type(metadata.containerId) ~= 'string' then
		return nil, 'invalid_container'
	end

	local modelHash = GetHashKey(model)
	if not modelHash or modelHash == 0 then
		return nil, 'invalid_container_model'
	end
	local created, entity = pcall(CreateObject, modelHash, coords.x, coords.y, coords.z, true, true, false)
	if not created then
		return nil, 'container_prop_unavailable'
	end
	if not entity or entity == 0 or not DoesEntityExist(entity) then
		return nil, 'container_prop_unavailable'
	end
	SetEntityHeading(entity, heading or 0.0)
	FreezeEntityPosition(entity, true)
	local netId = NetworkGetNetworkIdFromEntity(entity)
	if not netId or netId < 1 then
		DeleteEntity(entity)
		return nil, 'container_prop_unavailable'
	end
	S.tagWorldContainer(entity, metadata.containerId)

	local container = {
		entity = entity,
		netId = netId,
		itemName = itemName,
		metadata = Core.Functions.DeepCopy(metadata),
		containerId = metadata.containerId,
		coords = GetEntityCoords(entity),
		heading = heading or 0.0
	}
	S.worldContainers[container.containerId] = container
	return container
end

function S.adoptWorldContainer(playerId, itemName, metadata, netId, expectedCoords, heading, droppedBy)
	local model = S.containerWorldModels[itemName]
	local definition = Inventory.Items.Get(itemName)
	if not model or not definition or not definition.container or type(metadata) ~= 'table'
		or type(metadata.containerId) ~= 'string' or not S.isPositiveInteger(netId) then
		return nil, 'invalid_container'
	end

	local entity = NetworkGetEntityFromNetworkId(netId)
	local startedAt = GetGameTimer()
	while (entity == 0 or not DoesEntityExist(entity)) and GetGameTimer() - startedAt < Config.Server.adoptTimeoutMs do
		Wait(50)
		entity = NetworkGetEntityFromNetworkId(netId)
	end
	if entity == 0 or not DoesEntityExist(entity) then
		return nil, 'container_prop_unavailable'
	end
	if GetEntityModel(entity) ~= GetHashKey(model) then
		return nil, 'invalid_container_model'
	end
	local owner = NetworkGetEntityOwner(entity)
	if owner ~= playerId then
		return nil, 'invalid_target'
	end
	local coords = GetEntityCoords(entity)
	if #(coords - expectedCoords) > 1.5 then
		return nil, 'invalid_target'
	end
	SetEntityHeading(entity, heading or 0.0)
	FreezeEntityPosition(entity, true)
	S.tagWorldContainer(entity, metadata.containerId)

	local container = {
		entity = entity,
		netId = netId,
		itemName = itemName,
		metadata = Core.Functions.DeepCopy(metadata),
		containerId = metadata.containerId,
		coords = coords,
		heading = heading or 0.0,
		droppedBy = droppedBy
	}
	S.worldContainers[container.containerId] = container
	return container
end

-- Executa só no boot: apaga o conteúdo de toda maleta que ficou no mundo na execução anterior
-- (e o blob legado `world:containers`). Devolve a quantidade removida.
function S.purgeWorldContainers()
	local removed = 0
	local function purge(containerId)
		if S.isValidId(containerId) and containerId:sub(1, 10) == 'container:' then
			local deleted = Inventory.Persistence.Delete(containerId)
			if deleted then removed = removed + 1 end
		end
	end

	local keys, listError = Inventory.Persistence.ListKeys(S.WORLD_REF_PREFIX)
	if not keys then
		return false, listError
	end
	for _, key in ipairs(keys) do
		purge(key:sub(#S.WORLD_REF_PREFIX + 1))
		Inventory.Persistence.Delete(key)
	end

	local legacy = Inventory.Persistence.Get(S.WORLD_CONTAINERS_KEY)
	if legacy then
		local ok, stored = pcall(json.decode, legacy)
		if ok and type(stored) == 'table' then
			for _, entry in ipairs(stored) do
				if type(entry) == 'table' and type(entry.metadata) == 'table' then
					purge(entry.metadata.containerId)
				end
			end
		end
		Inventory.Persistence.Delete(S.WORLD_CONTAINERS_KEY)
	end
	return removed
end
local function collectContainerRefs(items, referenced)
	if type(items) ~= 'table' then return end
	for _, item in pairs(items) do
		local metadata = type(item) == 'table' and (item.metadata or nil)
		if type(metadata) == 'table' and type(metadata.containerId) == 'string' then
			referenced[metadata.containerId] = true
		end
	end
end

-- Registros `container:*` que nenhum inventário referencia (nem maleta no mundo) são lixo. Sem
-- `apply`, só relata. Rodar sob demanda: lê todos os registros `character:*`.
function S.gcOrphanContainers(apply)
	local containers, listError = Inventory.Persistence.ListKeys('container:')
	if not containers then return nil, listError end
	local characters, charactersError = Inventory.Persistence.ListKeys('character:')
	if not characters then return nil, charactersError end
	local markers, markersError = Inventory.Persistence.ListKeys(S.WORLD_REF_PREFIX)
	if not markers then return nil, markersError end

	local referenced = {}
	for _, key in ipairs(markers) do
		referenced[key:sub(#S.WORLD_REF_PREFIX + 1)] = true
	end
	for _, key in ipairs(characters) do
		local encoded = Inventory.Persistence.Get(key)
		local ok, stored = pcall(json.decode, encoded or '')
		if ok and type(stored) == 'table' then
			collectContainerRefs(stored.items, referenced)
		end
	end
	-- Memória por último: cobre maletas recém-criadas ainda não visíveis no banco.
	for id, inventory in pairs(S.inventories) do
		referenced[id] = true
		collectContainerRefs(inventory.items, referenced)
	end
	for containerId in pairs(S.worldContainers) do
		referenced[containerId] = true
	end

	local orphans = {}
	for _, key in ipairs(containers) do
		if not referenced[key] then orphans[#orphans + 1] = key end
	end
	local removed = 0
	if apply then
		for _, key in ipairs(orphans) do
			if Inventory.Persistence.Delete(key) then removed = removed + 1 end
		end
	end
	return { orphans = #orphans, removed = removed, scanned = #containers }
end
-- Props de container deixados por execuções anteriores (sem registro no banco) viram lixo persistente.
-- Deve rodar só na inicialização, antes de qualquer container ser recriado.
function S.cleanupOrphanContainerProps()
	if type(GetAllObjects) ~= 'function' then
		return 0
	end
	local models = {}
	for _, modelName in pairs(S.containerWorldModels) do
		models[GetHashKey(modelName)] = true
	end
	local tracked = {}
	for _, container in pairs(S.worldContainers) do
		if container.entity then tracked[container.entity] = true end
	end
	local removed = 0
	for _, entity in ipairs(GetAllObjects()) do
		if not tracked[entity] and models[GetEntityModel(entity)] and DoesEntityExist(entity) then
			DeleteEntity(entity)
			removed = removed + 1
		end
	end
	return removed
end
-- Recria no mundo a entidade de uma maleta registrada que deixou de existir (o target do cliente
-- filtra por modelo, então não há mais lista de netIds para enviar a cada jogador).
function S.syncWorldContainers()
	for _, container in pairs(S.worldContainers) do
		if not container.entity or not DoesEntityExist(container.entity) then
			local spawned = S.createWorldContainer(
				container.itemName,
				container.metadata,
				container.coords,
				container.heading
			)
			if spawned then
				spawned.droppedBy = container.droppedBy
				Core.Events.ToAll('inventory.containerWorldAdded', spawned.netId, spawned.itemName)
			end
		end
	end
end

-- Resolve o container alvo de uma ação e informa o motivo exato da recusa (para o log).
function S.resolveWorldContainer(playerId, netId)
	local container = S.getWorldContainerByNetId(netId)
	if not container then
		return nil, 'container_not_registered'
	end
	if not S.isNearWorldContainer(playerId, container) then
		return nil, 'too_far'
	end
	return container
end
function S.isNearWorldContainer(playerId, container, tolerance)
	local ped = GetPlayerPed(playerId)
	if not ped or ped <= 0 or not container.entity or not DoesEntityExist(container.entity) then
		return false
	end
	return #(GetEntityCoords(ped) - GetEntityCoords(container.entity)) <= Config.Server.worldInteractDistance + (tolerance or 0)
end

function S.removeWorldContainer(container)
	if S.worldContainers[container.containerId] ~= container then
		return false, 'invalid_target'
	end
	S.worldContainers[container.containerId] = nil
	if not S.unmarkWorldContainer(container.containerId) then
		S.worldContainers[container.containerId] = container
		return false, 'persistence_failed'
	end
	for playerId, opened in pairs(S.openedContainers) do
		for index = 1, 2 do
			if opened[index] and opened[index].worldNetId == container.netId then
				S.closeOpenedContainer(playerId, index, true)
			end
		end
	end
	if container.entity and DoesEntityExist(container.entity) then
		DeleteEntity(container.entity)
	end
	Core.Events.ToAll('inventory.containerWorldRemoved', container.netId)
	return true
end
