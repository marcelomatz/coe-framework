-- Operações de domínio sobre inventários e exports públicos.
local S = Inventory.Service

function S.CreateInventory(id, slotCount, maxWeight)
	if not S.isValidId(id) then
		return false, 'invalid_id'
	end

	local existing, loadError = S.loadInventory(id)
	if existing then
		return false, 'already_exists'
	end
	if loadError ~= 'not_found' then
		return false, loadError
	end

	slotCount = slotCount or Config.Server.defaultSlots
	if not S.isPositiveInteger(slotCount) or slotCount > Config.Server.maxSlots then
		return false, 'invalid_slot_count'
	end
	if maxWeight ~= nil and not S.isPositiveInteger(maxWeight) then
		return false, 'invalid_max_weight'
	end

	local inventory = {
		id = id,
		slots = slotCount,
		maxWeight = maxWeight,
		starterItemsGranted = false,
		items = {}
	}

	if not S.persistInventory(inventory) then
		return false, 'persistence_failed'
	end

	S.inventories[id] = inventory
	return true
end

function S.DeleteInventory(id)
	local inventory, errorMessage = S.getInventory(id)
	if not inventory then
		return false, errorMessage
	end

	S.dirtyInventories[id] = nil
	local deleted, deleteError = Inventory.Persistence.Delete(id)
	if not deleted then
		return false, deleteError or 'persistence_failed'
	end

	S.inventories[id] = nil
	return true
end

function S.GetInventory(id)
	local inventory, errorMessage = S.getInventory(id)
	if not inventory then
		return nil, errorMessage
	end

	local snapshot = {
		id = inventory.id,
		slots = inventory.slots,
		weight = S.getItemsWeight(inventory.items),
		maxWeight = inventory.maxWeight,
		items = {}
	}

	for slot = 1, inventory.slots do
		local item = inventory.items[slot]
		snapshot.items[slot] = item and item:toTable() or false
	end

	return snapshot
end

function S.GetSlot(id, slot)
	local inventory, errorMessage = S.getInventory(id)
	if not inventory then
		return nil, errorMessage
	end
	if not S.isPositiveInteger(slot) or slot > inventory.slots then
		return nil, 'invalid_slot'
	end

	local item = inventory.items[slot]
	if not item then
		return nil
	end

	return item:toTable()
end

function S.GetContainerInventory(parentId, parentSlot)
	local parentInventory, errorMessage = S.getInventory(parentId)
	if not parentInventory then
		return nil, errorMessage
	end
	if not S.isPositiveInteger(parentSlot) or parentSlot > parentInventory.slots then
		return nil, 'invalid_slot'
	end

	local item = parentInventory.items[parentSlot]
	if not item or not item.definition.container then
		return nil, 'not_a_container'
	end

	local containerId = item.metadata.containerId
	if type(containerId) ~= 'string' or not S.isValidId(containerId) or containerId:sub(1, 10) ~= 'container:' then
		containerId = S.generateContainerId()
		local metadata = Core.Functions.DeepCopy(item.metadata)
		metadata.containerId = containerId
		local replacement, createError = Inventory.Items.Create(item.name, item.count, metadata, parentSlot)
		if not replacement then
			return nil, createError
		end

		local previous = parentInventory.items[parentSlot]
		parentInventory.items[parentSlot] = replacement
		if not S.persistInventory(parentInventory) then
			parentInventory.items[parentSlot] = previous
			return nil, 'persistence_failed'
		end
		item = replacement
	end

	local containerInventory, containerError = S.loadInventory(containerId)
	if not containerInventory and containerError == 'not_found' then
		local profile = item.definition.container
		local created, createError = S.CreateInventory(containerId, profile.slots, profile.maxWeight)
		if not created and createError ~= 'already_exists' then
			return nil, createError
		end
		containerInventory, containerError = S.loadInventory(containerId)
	end
	if not containerInventory then
		return nil, containerError
	end

	local snapshot, snapshotError = S.GetInventory(containerId)
	if not snapshot then
		return nil, snapshotError
	end
	snapshot.container = {
		label = item.metadata.label or item.definition.label,
		slots = item.definition.container.slots,
		maxWeight = item.definition.container.maxWeight
	}
	return snapshot
end


function S.SwapSlots(id, fromSlot, toSlot)
	local inventory, errorMessage = S.getInventory(id)
	if not inventory then
		return false, errorMessage
	end
	if not S.isPositiveInteger(fromSlot) or fromSlot > inventory.slots
		or not S.isPositiveInteger(toSlot) or toSlot > inventory.slots then
		return false, 'invalid_slot'
	end
	if fromSlot == toSlot then
		return true
	end

	local sourceItem = inventory.items[fromSlot]
	if not sourceItem then
		return false, 'empty_slot'
	end

	local targetItem = inventory.items[toSlot]
	local movedItem, itemError = Inventory.Items.Create(sourceItem.name, sourceItem.count, sourceItem.metadata, toSlot)
	if not movedItem then
		return false, itemError
	end

	local movedTarget
	if targetItem then
		movedTarget, itemError = Inventory.Items.Create(targetItem.name, targetItem.count, targetItem.metadata, fromSlot)
		if not movedTarget then
			return false, itemError
		end
	end

	local previousItems = inventory.items
	local updatedItems = {}
	for slot, item in pairs(previousItems) do
		updatedItems[slot] = item
	end
	updatedItems[fromSlot] = movedTarget
	updatedItems[toSlot] = movedItem
	inventory.items = updatedItems

	if not S.markInventoryDirty(inventory) then
		inventory.items = previousItems
		return false, 'persistence_failed'
	end

	return true
end

function S.SplitItem(id, slot, splitCount)
	local inventory, errorMessage = S.getInventory(id)
	if not inventory then
		return false, errorMessage
	end
	if not S.isPositiveInteger(slot) or slot > inventory.slots then
		return false, 'invalid_slot'
	end
	if not S.isPositiveInteger(splitCount) then
		return false, 'invalid_count'
	end

	local item = inventory.items[slot]
	if not item or item.count < 2 or splitCount >= item.count then
		return false, 'invalid_split_count'
	end
	if not item.definition.stack then
		return false, 'item_not_stackable'
	end

	local emptySlot
	for index = 1, inventory.slots do
		if not inventory.items[index] then
			emptySlot = index
			break
		end
	end
	if not emptySlot then
		return false, 'inventory_full'
	end

	local remainingItem, itemError = Inventory.Items.Create(item.name, item.count - splitCount, item.metadata, slot)
	if not remainingItem then
		return false, itemError
	end
	local splitItem, splitError = Inventory.Items.Create(item.name, splitCount, item.metadata, emptySlot)
	if not splitItem then
		return false, splitError
	end

	local previousItems = inventory.items
	local updatedItems = {}
	for currentSlot, currentItem in pairs(previousItems) do
		updatedItems[currentSlot] = currentItem
	end
	updatedItems[slot] = remainingItem
	updatedItems[emptySlot] = splitItem
	inventory.items = updatedItems

	if not S.markInventoryDirty(inventory) then
		inventory.items = previousItems
		return false, 'persistence_failed'
	end

	return true, emptySlot
end

function S.addItemToSlots(items, slotCount, itemName, count, metadata, requestedSlot, maxWeight)
	local definition = Inventory.Items.Get(itemName)
	if not definition then
		return nil, 'invalid_item'
	end

	local newItem, itemError = Inventory.Items.Create(itemName, count, metadata)
	if not newItem then
		return nil, itemError
	end
	if definition.maxStack and count > definition.maxStack then
		return nil, 'stack_limit'
	end
	if definition.container and type(newItem.metadata.containerId) ~= 'string' then
		newItem.metadata.containerId = S.generateContainerId()
	end

	local slot = requestedSlot
	if slot ~= nil then
		if not S.isPositiveInteger(slot) or slot > slotCount then
			return nil, 'invalid_slot'
		end
	else
		if definition.stack then
			for index = 1, slotCount do
				local current = items[index]
				if current and current:canStack(newItem)
					and (not definition.maxStack or current.count + count <= definition.maxStack) then
					slot = index
					break
				end
			end
		end

		if not slot then
			for index = 1, slotCount do
				if not items[index] then
					slot = index
					break
				end
			end
		end
	end

	if not slot then
		return nil, 'inventory_full'
	end

	local current = items[slot]
	if current and not current:canStack(newItem) then
		return nil, 'slot_occupied'
	end
	if current and definition.maxStack and current.count + count > definition.maxStack then
		return nil, 'stack_limit'
	end

	newItem.count = (current and current.count or 0) + count
	newItem.slot = slot
	items[slot] = newItem
	if maxWeight and S.getItemsWeight(items) > maxWeight then
		items[slot] = current
		return nil, 'too_heavy'
	end

	return slot
end

function S.transferItem(sourceInventory, targetInventory, fromSlot, count, requestedSlot)
	if sourceInventory.id == targetInventory.id then
		return false, 'invalid_target'
	end
	if not S.isPositiveInteger(fromSlot) or fromSlot > sourceInventory.slots then
		return false, 'invalid_slot'
	end
	if not S.isPositiveInteger(count) then
		return false, 'invalid_count'
	end

	local sourceItem = sourceInventory.items[fromSlot]
	if not sourceItem or sourceItem.count < count then
		return false, 'insufficient_items'
	end

	local updatedTargetItems = {}
	for slot, item in pairs(targetInventory.items) do
		updatedTargetItems[slot] = item
	end
	local targetSlot, addError = S.addItemToSlots(
		updatedTargetItems,
		targetInventory.slots,
		sourceItem.name,
		count,
		sourceItem.metadata,
		requestedSlot,
		targetInventory.maxWeight
	)
	if not targetSlot then
		return false, addError
	end

	local updatedSourceItems = {}
	for slot, item in pairs(sourceInventory.items) do
		updatedSourceItems[slot] = item
	end
	if sourceItem.count == count then
		updatedSourceItems[fromSlot] = nil
	else
		local remainingItem, itemError = Inventory.Items.Create(
			sourceItem.name,
			sourceItem.count - count,
			sourceItem.metadata,
			fromSlot
		)
		if not remainingItem then
			return false, itemError
		end
		updatedSourceItems[fromSlot] = remainingItem
	end

	local previousSourceItems = sourceInventory.items
	local previousTargetItems = targetInventory.items
	sourceInventory.items = updatedSourceItems
	targetInventory.items = updatedTargetItems

	local function rollback(errorMessage)
		sourceInventory.items = previousSourceItems
		targetInventory.items = previousTargetItems
		return errorMessage or 'persistence_failed'
	end

	local persisted, persistenceError = S.persistInventories(sourceInventory, targetInventory)
	if not persisted then
		return false, rollback(persistenceError)
	end

	return true, targetSlot
end

function S.AddItem(id, itemName, count, metadata, requestedSlot)
	local inventory, errorMessage = S.getInventory(id)
	if not inventory then
		return false, errorMessage
	end
	local previousItems = inventory.items
	local updatedItems = {}
	for slot, item in pairs(previousItems) do
		updatedItems[slot] = item
	end

	local slot, addError = S.addItemToSlots(updatedItems, inventory.slots, itemName, count, metadata, requestedSlot, inventory.maxWeight)
	if not slot then
		return false, addError
	end

	inventory.items = updatedItems

	if not S.persistInventory(inventory) then
		inventory.items = previousItems
		return false, 'persistence_failed'
	end

	if type(GetInvokingResource) == 'function' and GetInvokingResource() ~= nil and S.notifyInventoryOwner then
		S.notifyInventoryOwner(id)
	end

	return true, slot
end

function S.grantStarterItems(inventory)
	if inventory.starterItemsGranted then
		return true
	end

	local starterItems = Config.Server.starterItems
	if type(starterItems) ~= 'table' then
		return false, 'invalid_starter_items'
	end

	local updatedItems = {}
	for slot, item in pairs(inventory.items) do
		updatedItems[slot] = item
	end

	for _, starterItem in ipairs(starterItems) do
		if type(starterItem) ~= 'table' then
			return false, 'invalid_starter_item'
		end

		local slot, addError = S.addItemToSlots(
			updatedItems,
			inventory.slots,
			starterItem.name,
			starterItem.count,
			starterItem.metadata,
			starterItem.slot,
			inventory.maxWeight
		)
		if not slot then
			return false, addError
		end
	end

	local previousItems = inventory.items
	local previousStarterState = inventory.starterItemsGranted
	inventory.items = updatedItems
	inventory.starterItemsGranted = true

	if not S.persistInventory(inventory) then
		inventory.items = previousItems
		inventory.starterItemsGranted = previousStarterState
		return false, 'persistence_failed'
	end

	return true
end

function S.RemoveItem(id, slot, count)
	local inventory, errorMessage = S.getInventory(id)
	if not inventory then
		return false, errorMessage
	end
	if not S.isPositiveInteger(slot) or slot > inventory.slots then
		return false, 'invalid_slot'
	end
	if not S.isPositiveInteger(count) then
		return false, 'invalid_count'
	end

	local item = inventory.items[slot]
	if not item or item.count < count then
		return false, 'insufficient_items'
	end

	local previous = item
	if item.count == count then
		inventory.items[slot] = nil
	else
		local remaining, itemError = Inventory.Items.Create(item.name, item.count - count, item.metadata, slot)
		if not remaining then
			return false, itemError
		end
		inventory.items[slot] = remaining
	end

	if not S.persistInventory(inventory) then
		inventory.items[slot] = previous
		return false, 'persistence_failed'
	end

	if type(GetInvokingResource) == 'function' and GetInvokingResource() ~= nil and S.notifyInventoryOwner then
		S.notifyInventoryOwner(id)
	end

	return true
end

function S.UseItem(id, slot)
	local inventory, errorMessage = S.getInventory(id)
	if not inventory then
		return false, errorMessage
	end
	if not S.isPositiveInteger(slot) or slot > inventory.slots then
		return false, 'invalid_slot'
	end

	local item = inventory.items[slot]
	if not item then
		return false, 'empty_slot'
	end
	if not item.definition.usable then
		return false, 'item_not_usable'
	end

	local itemData = item:toTable()
	if item.definition.consume > 0 then
		local removed, removeError = S.RemoveItem(id, slot, item.definition.consume)
		if not removed then
			return false, removeError
		end
	end

	Core.Events.Emit('inventory.itemUsed', inventory.id, slot, itemData)
	return true, itemData
end

-- Altera chaves da metadata de um item (as demais são mantidas). Gravação síncrona.
function S.SetItemMetadata(id, slot, patch)
	local inventory, errorMessage = S.getInventory(id)
	if not inventory then
		return false, errorMessage
	end
	if not S.isPositiveInteger(slot) or slot > inventory.slots then
		return false, 'invalid_slot'
	end
	if type(patch) ~= 'table' then
		return false, 'invalid_item_metadata'
	end

	local item = inventory.items[slot]
	if not item then
		return false, 'empty_slot'
	end

	local metadata = Core.Functions.DeepCopy(item.metadata)
	for key, value in pairs(patch) do
		if type(key) ~= 'string' then
			return false, 'invalid_item_metadata'
		end
		metadata[key] = value
	end
	local updated, itemError = Inventory.Items.Create(item.name, item.count, metadata, slot)
	if not updated then
		return false, itemError
	end

	inventory.items[slot] = updated
	if not S.persistInventory(inventory) then
		inventory.items[slot] = item
		return false, 'persistence_failed'
	end

	if type(GetInvokingResource) == 'function' and GetInvokingResource() ~= nil and S.notifyInventoryOwner then
		S.notifyInventoryOwner(id)
	end

	return true
end

function S.GetItemCount(id, itemName, metadata, strict)
	local inventory, errorMessage = S.getInventory(id)
	if not inventory then
		return nil, errorMessage
	end
	if type(itemName) ~= 'string' then
		return nil, 'invalid_item_name'
	end
	if metadata ~= nil and type(metadata) ~= 'table' and type(metadata) ~= 'string' then
		return nil, 'invalid_item_metadata'
	end

	local count = 0
	for slot = 1, inventory.slots do
		local item = inventory.items[slot]
		if item and item.name == itemName
			and Inventory.Items.MetadataMatches(item.metadata, metadata, strict) then
			count = count + item.count
		end
	end

	return count
end

function S.RegisterItem(name, definition)
	local item, errorMessage = Inventory.Items.Register(name, definition)
	if not item then
		return false, errorMessage
	end

	return true, item:toTable()
end

function S.GetItems(name)
	if name ~= nil then
		local item = Inventory.Items.Get(name)
		return item and item:toTable() or nil
	end

	return Inventory.Items.GetAll()
end

function S.GetItem(id, itemName, metadata, strict)
	local definition = Inventory.Items.Get(itemName)
	if not definition then
		return nil, 'invalid_item'
	end

	local count, errorMessage = S.GetItemCount(id, itemName, metadata, strict)
	if count == nil then
		return nil, errorMessage
	end

	local item = definition:toTable()
	item.count = count
	return item
end

exports('RegisterItem', S.RegisterItem)
exports('Items', S.GetItems)
exports('GetItem', S.GetItem)
exports('CreateInventory', S.CreateInventory)
exports('DeleteInventory', S.DeleteInventory)
exports('GetInventory', S.GetInventory)
exports('GetSlot', S.GetSlot)
exports('GetContainerInventory', S.GetContainerInventory)
exports('SwapSlots', S.SwapSlots)
exports('SplitItem', S.SplitItem)
exports('AddItem', S.AddItem)
exports('RemoveItem', S.RemoveItem)
exports('UseItem', S.UseItem)
exports('SetItemMetadata', S.SetItemMetadata)
exports('GetItemCount', S.GetItemCount)
exports('GetPersistenceStats', S.getPersistenceStats)
exports('GetInventoryObject', function()
	return Inventory
end)
