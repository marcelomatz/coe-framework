-- Handlers de rede de containers portáteis e de mundo.
local S = Inventory.Service

Core.Events.OnNet('inventory.containerWorldOpen', function(requestId, netId)
	local playerId = source
	if not S.isPositiveInteger(requestId) then return end
	if not S.allowInventoryAction(playerId) then
		S.sendActionResult(playerId, requestId, false, 'rate_limited')
		return
	end
	if not S.isPositiveInteger(netId) then
		S.sendActionResult(playerId, requestId, false, 'invalid_target', 'invalid_net_id')
		return
	end

	local container, reason = S.resolveWorldContainer(playerId, netId)
	if not container then
		S.sendActionResult(playerId, requestId, false, 'invalid_target', reason)
		return
	end
	local inventoryId, playerInventoryOrError = S.ensurePlayerInventory(playerId)
	if not inventoryId then
		S.sendActionResult(playerId, requestId, false, playerInventoryOrError)
		return
	end
	local index = S.getAvailableContainerIndex(playerId, netId)
	if not index then
		S.sendActionResult(playerId, requestId, false, 'container_limit')
		return
	end

	local opened = S.openedContainers[playerId] or {}
	opened[index] = {
		parentInventoryId = inventoryId,
		containerId = container.containerId,
		worldNetId = netId
	}
	S.openedContainers[playerId] = opened
	local playerSnapshot = S.GetInventory(inventoryId)
	local containerSnapshot, snapshotError = S.getOpenedContainerSnapshot(inventoryId, opened[index])
	if not playerSnapshot or not containerSnapshot then
		S.closeOpenedContainer(playerId, index, false)
		S.sendActionResult(playerId, requestId, false, snapshotError or 'invalid_storage')
		return
	end

	S.sendActionResult(playerId, requestId, true)
	Core.Events.ToClient(playerId, 'inventory.worldContainerOpened', playerSnapshot, containerSnapshot, index)
end)

Core.Events.OnNet('inventory.containerWorldPickup', function(requestId, netId)
	local playerId = source
	if not S.isPositiveInteger(requestId) then return end
	if not S.allowInventoryAction(playerId) then
		S.sendActionResult(playerId, requestId, false, 'rate_limited')
		return
	end
	if not S.isPositiveInteger(netId) then
		S.sendActionResult(playerId, requestId, false, 'invalid_target', 'invalid_net_id')
		return
	end

	local container, reason = S.resolveWorldContainer(playerId, netId)
	if not container then
		S.sendActionResult(playerId, requestId, false, 'invalid_target', reason)
		return
	end
	-- Trava atômica: a persistência do AddItem pode ceder a vez, e dois jogadores
	-- não podem reivindicar a mesma maleta ao mesmo tempo.
	if container.claimedBy then
		S.sendActionResult(playerId, requestId, false, 'invalid_target', 'already_claimed')
		return
	end
	container.claimedBy = playerId

	local inventoryId, inventoryOrError = S.ensurePlayerInventory(playerId)
	if not inventoryId then
		container.claimedBy = nil
		S.sendActionResult(playerId, requestId, false, inventoryOrError)
		return
	end
	local success, addedSlot = S.AddItem(inventoryId, container.itemName, 1, container.metadata)
	if not success then
		container.claimedBy = nil
		S.sendActionResult(playerId, requestId, false, addedSlot)
		return
	end

	local removed, removeError = S.removeWorldContainer(container)
	if not removed then
		container.claimedBy = nil
		S.RemoveItem(inventoryId, addedSlot, 1)
		S.sendActionResult(playerId, requestId, false, removeError)
		return
	end
	S.log('info', 'audit', 'world_container_picked_up', {
		item = container.itemName,
		player_id = playerId
	})
	S.sendActionResult(playerId, requestId, true)
	local snapshot = S.GetInventory(inventoryId)
	if snapshot then
		Core.Events.ToClient(playerId, 'inventory.updated', snapshot)
	end
	-- A maleta recolhida vai para a mão de quem pegou, até ser guardada.
	Core.Events.ToClient(playerId, 'inventory.containerPickedUp', container.itemName, container.metadata)
end)

Core.Events.OnNet('inventory.containerDrop', function(requestId, containerId, netId, position, heading)
	local playerId = source
	if not S.isPositiveInteger(requestId) then return end
	if not S.allowContainerDrop(playerId) then
		Core.Events.ToClient(playerId, 'inventory.containerDropResult', requestId, false, 'rate_limited')
		return
	end
	if type(containerId) ~= 'string'
		or type(position) ~= 'table'
		or type(position.x) ~= 'number'
		or type(position.y) ~= 'number'
		or type(position.z) ~= 'number'
		or math.abs(position.x) > 20000
		or math.abs(position.y) > 20000
		or math.abs(position.z) > 20000 then
		Core.Events.ToClient(playerId, 'inventory.containerDropResult', requestId, false, 'invalid_target')
		return
	end
	local inventoryId, playerInventoryOrError = S.ensurePlayerInventory(playerId)
	if not inventoryId then
		Core.Events.ToClient(playerId, 'inventory.containerDropResult', requestId, false, playerInventoryOrError)
		return
	end
	local playerPed = GetPlayerPed(playerId)
	if not playerPed or playerPed <= 0 then
		Core.Events.ToClient(playerId, 'inventory.containerDropResult', requestId, false, 'invalid_target')
		return
	end
	local coords = vector3(position.x, position.y, position.z)
	if #(GetEntityCoords(playerPed) - coords) > 5.0 then
		Core.Events.ToClient(playerId, 'inventory.containerDropResult', requestId, false, 'invalid_target')
		return
	end

	local containerSlot, containerItem
	for slot = 1, playerInventoryOrError.slots do
		local item = playerInventoryOrError.items[slot]
		if item and item.definition.container and item.metadata.containerId == containerId then
			containerSlot = slot
			containerItem = item
			break
		end
	end
	if not containerItem then
		Core.Events.ToClient(playerId, 'inventory.containerDropResult', requestId, false, 'invalid_target')
		return
	end

	local droppedBy, limitError = S.checkWorldContainerLimits(playerId)
	if limitError then
		Core.Events.ToClient(playerId, 'inventory.containerDropResult', requestId, false, limitError)
		return
	end

	local worldContainer, createError = S.adoptWorldContainer(
		playerId,
		containerItem.name,
		containerItem.metadata,
		netId,
		coords,
		type(heading) == 'number' and heading or 0.0,
		droppedBy
	)
	if not worldContainer then
		Core.Events.ToClient(playerId, 'inventory.containerDropResult', requestId, false, createError)
		return
	end
	local removed, removeError = S.RemoveItem(inventoryId, containerSlot, 1)
	if not removed then
		S.worldContainers[containerId] = nil
		DeleteEntity(worldContainer.entity)
		Core.Events.ToClient(playerId, 'inventory.containerDropResult', requestId, false, removeError)
		return
	end
	if not S.markWorldContainer(containerId) then
		S.worldContainers[containerId] = nil
		DeleteEntity(worldContainer.entity)
		S.AddItem(inventoryId, containerItem.name, 1, containerItem.metadata)
		Core.Events.ToClient(playerId, 'inventory.containerDropResult', requestId, false, 'persistence_failed')
		return
	end

	S.validateOpenedContainers(playerId, playerInventoryOrError)
	S.log('info', 'audit', 'world_container_dropped', {
		item = containerItem.name,
		player_id = playerId
	})
	Core.Events.ToClient(playerId, 'inventory.containerDropResult', requestId, true, worldContainer.netId)
	Core.Events.ToAll('inventory.containerWorldAdded', worldContainer.netId, worldContainer.itemName)
	local snapshot = S.GetInventory(inventoryId)
	if snapshot then
		Core.Events.ToClient(playerId, 'inventory.updated', snapshot)
	end
end)

Core.Events.OnNet('inventory.containerOpen', function(requestId, parentSlot)
	local playerId = source
	if not S.isPositiveInteger(requestId) then
		return
	end
	if not S.allowInventoryAction(playerId) then
		S.sendActionResult(playerId, requestId, false, 'rate_limited')
		return
	end
	local inventoryId, inventoryOrError = S.ensurePlayerInventory(playerId)
	if not inventoryId then
		S.sendActionResult(playerId, requestId, false, inventoryOrError)
		return
	end
	if not S.isPositiveInteger(parentSlot) then
		S.sendActionResult(playerId, requestId, false, 'invalid_slot')
		return
	end
	local parentItem = inventoryOrError.items[parentSlot]
	local previousContainerId = parentItem and parentItem.metadata.containerId

	local opened = S.openedContainers[playerId] or {}
	local containerIndex
	for index = 1, 2 do
		if opened[index] and opened[index].parentSlot == parentSlot then
			containerIndex = index
			break
		end
	end
	if not containerIndex then
		for index = 1, 2 do
			if not opened[index] then
				containerIndex = index
				break
			end
		end
	end
	if not containerIndex then
		S.sendActionResult(playerId, requestId, false, 'container_limit')
		return
	end

	local snapshot, errorMessage = S.GetContainerInventory(inventoryId, parentSlot)
	if not snapshot then
		S.sendActionResult(playerId, requestId, false, errorMessage)
		return
	end

	opened[containerIndex] = {
		parentInventoryId = inventoryId,
		parentSlot = parentSlot,
		containerId = snapshot.id
	}
	S.openedContainers[playerId] = opened
	if previousContainerId ~= snapshot.id then
		local inventorySnapshot = S.GetInventory(inventoryId)
		if inventorySnapshot then
			Core.Events.ToClient(playerId, 'inventory.updated', inventorySnapshot)
		end
	end
	S.sendActionResult(playerId, requestId, true)
	Core.Events.ToClient(playerId, 'inventory.containerOpened', snapshot, containerIndex)
end)

Core.Events.OnNet('inventory.containerClose', function(index)
	if index ~= nil and index ~= 1 and index ~= 2 then return end
	S.closeOpenedContainer(source, index, false)
end)

Core.Events.OnNet('inventory.containerMove', function(requestId, sourceSide, targetSide, fromSlot, toSlot)
	local playerId = source
	if not S.isPositiveInteger(requestId) then
		return
	end
	if not S.allowInventoryAction(playerId) then
		S.sendActionResult(playerId, requestId, false, 'rate_limited')
		return
	end
	local sourceContainerIndex = S.containerIndexFromSide(sourceSide)
	local targetContainerIndex = S.containerIndexFromSide(targetSide)
	if (sourceSide ~= 'player' and not sourceContainerIndex)
		or (targetSide ~= 'player' and not targetContainerIndex)
		or (sourceSide == 'player' and targetSide == 'player')
		or not S.isPositiveInteger(fromSlot) or not S.isPositiveInteger(toSlot) then
		S.sendActionResult(playerId, requestId, false, 'invalid_slot')
		return
	end

	local inventoryId, playerInventoryOrError = S.ensurePlayerInventory(playerId)
	if not inventoryId then
		S.sendActionResult(playerId, requestId, false, playerInventoryOrError)
		return
	end
	local playerInventory = playerInventoryOrError
	S.validateOpenedContainers(playerId, playerInventory)
	local openedContainersForPlayer = S.openedContainers[playerId] or {}
	if sourceSide == targetSide then
		local opened, _, containerInventory, openError = S.validateOpenedContainer(playerId, playerInventory, sourceContainerIndex)
		if not opened then
			S.sendActionResult(playerId, requestId, false, openError)
			return
		end
		local success, errorMessage = S.SwapSlots(containerInventory.id, fromSlot, toSlot)
		if not success then
			S.sendActionResult(playerId, requestId, false, errorMessage)
			return
		end
		S.sendActionResult(playerId, requestId, true)
		local snapshot = S.getOpenedContainerSnapshot(inventoryId, opened)
		if snapshot then
			Core.Events.ToClient(playerId, 'inventory.containerUpdated', snapshot, sourceContainerIndex)
		end
		S.refreshContainerViewers(opened.containerId, playerId)
		return
	end

	local sourceInventory = playerInventory
	local targetInventory = playerInventory
	if sourceContainerIndex then
		local opened, _, containerInventory, openError = S.validateOpenedContainer(playerId, playerInventory, sourceContainerIndex)
		if not opened then
			S.sendActionResult(playerId, requestId, false, openError)
			return
		end
		sourceInventory = containerInventory
	end
	if targetContainerIndex then
		local opened, _, containerInventory, openError = S.validateOpenedContainer(playerId, playerInventory, targetContainerIndex)
		if not opened then
			S.sendActionResult(playerId, requestId, false, openError)
			return
		end
		targetInventory = containerInventory
	end

	local sourceItem = sourceInventory.items[fromSlot]
	if not sourceItem then
		S.sendActionResult(playerId, requestId, false, 'empty_slot')
		return
	end
	if targetInventory.id ~= playerInventory.id and sourceItem.definition.container then
		S.sendActionResult(playerId, requestId, false, 'nested_container_not_supported')
		return
	end

	local success, errorMessage = S.transferItem(
		sourceInventory,
		targetInventory,
		fromSlot,
		sourceItem.count,
		toSlot
	)
	if not success then
		S.sendActionResult(playerId, requestId, false, errorMessage)
		return
	end

	S.sendActionResult(playerId, requestId, true)
	local playerSnapshot = S.GetInventory(inventoryId)
	if playerSnapshot then
		Core.Events.ToClient(playerId, 'inventory.updated', playerSnapshot)
	end
	for index = 1, 2 do
		local opened = openedContainersForPlayer[index]
		if opened then
			local containerSnapshot = S.getOpenedContainerSnapshot(inventoryId, opened)
			if containerSnapshot then
				Core.Events.ToClient(playerId, 'inventory.containerUpdated', containerSnapshot, index)
			end
			S.refreshContainerViewers(opened.containerId, playerId)
		end
	end
end)
