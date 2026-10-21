-- Baús fixos (stashes) abertos por outros resources e remoção de itens por nome.
-- O resource que chama decide QUEM pode abrir; aqui só se valida a presença física
-- (distância do ponto do baú) a cada ação, como nos containers do mundo.
local S = Inventory.Service

local STASH_PREFIX = 'stash:'
local STASH_TOLERANCE = 2.0

local function validDefinition(definition)
	if type(definition) ~= 'table' or type(definition.position) ~= 'table' then
		return false
	end
	local position = definition.position
	return type(position.x) == 'number' and type(position.y) == 'number' and type(position.z) == 'number'
		and S.isPositiveInteger(definition.slots) and definition.slots <= Config.Server.maxSlots
		and (definition.maxWeight == nil or S.isPositiveInteger(definition.maxWeight))
		and type(definition.radius) == 'number' and definition.radius > 0 and definition.radius <= 10.0
end

--- Um baú aberto por id continua válido enquanto o jogador estiver perto dele.
function S.isNearStash(playerId, stash, tolerance)
	local ped = GetPlayerPed(playerId)
	if not ped or ped <= 0 then
		return false
	end
	local position = stash.position
	return #(GetEntityCoords(ped) - vector3(position.x, position.y, position.z)) <= stash.radius + (tolerance or 0)
end

function S.stashSnapshot(opened)
	local snapshot, errorMessage = S.GetInventory(opened.containerId)
	if not snapshot then
		return nil, errorMessage
	end
	snapshot.container = {
		label = opened.stash.label,
		slots = opened.stash.slots,
		maxWeight = opened.stash.maxWeight
	}
	return snapshot
end

---@param playerId integer
---@param stashId string deve começar com `stash:`
---@param definition table { label, slots, maxWeight?, position = {x,y,z}, radius }
function S.OpenStash(playerId, stashId, definition)
	if type(stashId) ~= 'string' or stashId:sub(1, #STASH_PREFIX) ~= STASH_PREFIX or not S.isValidId(stashId) then
		return false, 'invalid_id'
	end
	if not validDefinition(definition) then
		return false, 'invalid_stash'
	end
	local inventoryId, playerInventoryOrError = S.ensurePlayerInventory(playerId)
	if not inventoryId then
		return false, playerInventoryOrError
	end

	local created, createError = S.CreateInventory(stashId, definition.slots, definition.maxWeight)
	if not created and createError ~= 'already_exists' then
		return false, createError
	end

	local opened = S.openedContainers[playerId] or {}
	local index
	for candidate = 1, 2 do
		if opened[candidate] and opened[candidate].containerId == stashId then
			index = candidate
			break
		end
	end
	if not index then
		for candidate = 1, 2 do
			if not opened[candidate] then
				index = candidate
				break
			end
		end
	end
	if not index then
		return false, 'container_limit'
	end

	opened[index] = {
		parentInventoryId = inventoryId,
		containerId = stashId,
		stash = {
			label = type(definition.label) == 'string' and definition.label or 'Baú',
			slots = definition.slots,
			maxWeight = definition.maxWeight,
			position = { x = definition.position.x, y = definition.position.y, z = definition.position.z },
			radius = definition.radius
		}
	}
	S.openedContainers[playerId] = opened

	local playerSnapshot = S.GetInventory(inventoryId)
	local containerSnapshot, snapshotError = S.stashSnapshot(opened[index])
	if not playerSnapshot or not containerSnapshot then
		S.closeOpenedContainer(playerId, index, false)
		return false, snapshotError or 'invalid_storage'
	end
	Core.Events.ToClient(playerId, 'inventory.worldContainerOpened', playerSnapshot, containerSnapshot, index)
	return true
end

--- Remove `count` unidades de `itemName` (qualquer metadata), varrendo os slots em ordem.
---@param id string
---@param itemName string
---@param count integer
function S.RemoveItemByName(id, itemName, count)
	if not S.isPositiveInteger(count) then
		return false, 'invalid_count'
	end
	local inventory, errorMessage = S.getInventory(id)
	if not inventory then
		return false, errorMessage
	end
	local available = 0
	for slot = 1, inventory.slots do
		local item = inventory.items[slot]
		if item and item.name == itemName then
			available = available + item.count
		end
	end
	if available < count then
		return false, 'insufficient_items'
	end

	local remaining = count
	for slot = 1, inventory.slots do
		local item = inventory.items[slot]
		if remaining > 0 and item and item.name == itemName then
			local take = math.min(item.count, remaining)
			local removed, removeError = S.RemoveItem(id, slot, take)
			if not removed then
				return false, removeError
			end
			remaining = remaining - take
		end
	end
	return true
end

exports('OpenStash', S.OpenStash)
exports('RemoveItemByName', S.RemoveItemByName)

S.STASH_TOLERANCE = STASH_TOLERANCE
