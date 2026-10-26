-- Handlers de rede: request, swap, split, use e give.
local S = Inventory.Service

Core.Events.OnNet('inventory.request', function(requestId)
	local playerId = source
	if type(requestId) ~= 'number' or requestId % 1 ~= 0 then
		return
	end

	local now = GetGameTimer()
	local lastRequest = S.inventoryRequestTimes[playerId]
	if lastRequest and now - lastRequest < Config.Server.rateLimits.requestMs then
		Core.Events.ToClient(playerId, 'inventory.response', requestId, nil, 'rate_limited')
		return
	end
	S.inventoryRequestTimes[playerId] = now

	local inventoryId, inventoryOrError = S.ensurePlayerInventory(playerId)
	if not inventoryId then
		Core.Events.ToClient(playerId, 'inventory.response', requestId, nil, inventoryOrError)
		return
	end

	local snapshot, snapshotError = S.GetInventory(inventoryId)
	Core.Events.ToClient(playerId, 'inventory.response', requestId, snapshot, snapshotError)
end)

Core.Events.OnNet('inventory.containerWorldSync', function()
	local playerId = source
	local now = GetGameTimer()
	local previous = S.containerSyncTimes[playerId]
	if previous and now - previous < Config.Server.rateLimits.syncMs then
		return
	end

	S.containerSyncTimes[playerId] = now
	S.syncWorldContainers()
end)

Core.Events.OnNet('inventory.swap', function(fromSlot, toSlot)
	local playerId = source
	if not S.isPositiveInteger(fromSlot) or not S.isPositiveInteger(toSlot) then
		return
	end

	local now = GetGameTimer()
	local lastSwap = S.inventorySwapTimes[playerId]
	if lastSwap and now - lastSwap < Config.Server.rateLimits.swapMs then
		return
	end
	S.inventorySwapTimes[playerId] = now

	local inventoryId = S.ensurePlayerInventory(playerId)
	if not inventoryId then
		return
	end

	local swapped = S.SwapSlots(inventoryId, fromSlot, toSlot)
	if not swapped then
		return
	end

	local inventory = S.getInventory(inventoryId)
	if inventory then
		S.validateOpenedContainers(playerId, inventory)
	end

	local snapshot = S.GetInventory(inventoryId)
	if snapshot then
		Core.Events.ToClient(playerId, 'inventory.updated', snapshot)
	end
end)


Core.Events.OnNet('inventory.split', function(requestId, slot, count)
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

	local success, result = S.SplitItem(inventoryId, slot, count)
	if success then
		S.sendActionResult(playerId, requestId, true)
	else
		S.sendActionResult(playerId, requestId, false, result)
	end
	if success then
		local snapshot = S.GetInventory(inventoryId)
		if snapshot then
			Core.Events.ToClient(playerId, 'inventory.updated', snapshot)
		end
	end
end)

Core.Events.OnNet('inventory.use', function(requestId, slot)
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

	local success, itemOrError = S.UseItem(inventoryId, slot)
	if not success then
		S.sendActionResult(playerId, requestId, false, itemOrError)
		return
	end
	S.validateOpenedContainers(playerId, inventoryOrError)

	if type(itemOrError) == 'table' and (tonumber(itemOrError.consume) or 0) > 0 then
		S.activeConsumptions[playerId] = {
			inventoryId = inventoryId,
			slot = slot,
			item = itemOrError,
			startedAt = GetGameTimer(),
			durationMs = tonumber(itemOrError.consumeTime) or 3000
		}
	end

	S.sendActionResult(playerId, requestId, true)
	Core.Events.ToClient(playerId, 'inventory.useItem', itemOrError)

	local snapshot = S.GetInventory(inventoryId)
	if snapshot then
		Core.Events.ToClient(playerId, 'inventory.updated', snapshot)
	end
end)

Core.Events.OnNet('inventory.cancelUse', function()
	local playerId = source
	local active = S.activeConsumptions[playerId]
	if not active then
		return
	end
	S.activeConsumptions[playerId] = nil

	local now = GetGameTimer()
	local maxWindow = (tonumber(active.durationMs) or 3000) + 1500
	if now - active.startedAt > maxWindow then
		return
	end

	local inventoryId = S.ensurePlayerInventory(playerId)
	if not inventoryId or inventoryId ~= active.inventoryId then
		return
	end

	local item = active.item
	local refundCount = tonumber(item and item.consume) or 1
	local added = S.AddItem(inventoryId, item.name, refundCount, item.metadata, active.slot)
	if not added then
		added = S.AddItem(inventoryId, item.name, refundCount, item.metadata)
	end
	if not added then
		return
	end

	Core.Events.Emit('inventory.itemUseCancelled', inventoryId, active.slot, item)

	local snapshot = S.GetInventory(inventoryId)
	if snapshot then
		Core.Events.ToClient(playerId, 'inventory.updated', snapshot)
	end
end)

Core.Events.OnNet('inventory.give', function(requestId, targetId, slot, count)
	local playerId = source
	if not S.isPositiveInteger(requestId) then
		return
	end
	if not S.allowInventoryAction(playerId) then
		S.sendActionResult(playerId, requestId, false, 'rate_limited')
		return
	end
	if not S.isPositiveInteger(targetId) or targetId == playerId or not GetPlayerName(targetId) then
		S.sendActionResult(playerId, requestId, false, 'invalid_target')
		return
	end

	local sourcePed = GetPlayerPed(playerId)
	local targetPed = GetPlayerPed(targetId)
	if sourcePed <= 0 or targetPed <= 0 then
		S.sendActionResult(playerId, requestId, false, 'invalid_target')
		return
	end
	local distance = #(GetEntityCoords(sourcePed) - GetEntityCoords(targetPed))
	if distance > Config.Server.giveDistance then
		S.log('warn', 'security', 'inventory_give_denied', {
			action = 'give',
			error_code = 'too_far',
			source = playerId,
			target = targetId
		})
		S.sendActionResult(playerId, requestId, false, 'too_far')
		return
	end

	local sourceInventoryId, sourceInventoryOrError = S.ensurePlayerInventory(playerId)
	if not sourceInventoryId then
		S.sendActionResult(playerId, requestId, false, sourceInventoryOrError)
		return
	end
	local targetInventoryId, targetInventoryOrError = S.ensurePlayerInventory(targetId)
	if not targetInventoryId then
		S.sendActionResult(playerId, requestId, false, targetInventoryOrError)
		return
	end

	local givenItem = type(slot) == 'number' and sourceInventoryOrError.items[slot] or nil
	local givenName = givenItem and givenItem.name or nil
	local success, errorMessage = S.transferItem(sourceInventoryOrError, targetInventoryOrError, slot, count)
	if success then
		S.log('info', 'audit', 'inventory_item_given', {
			count = count,
			item = givenName,
			source = playerId,
			target = targetId
		})
		S.validateOpenedContainers(playerId, sourceInventoryOrError)
		S.sendActionResult(playerId, requestId, true)
	else
		S.sendActionResult(playerId, requestId, false, errorMessage)
	end
	if not success then
		return
	end

	local sourceSnapshot = S.GetInventory(sourceInventoryId)
	local targetSnapshot = S.GetInventory(targetInventoryId)
	if sourceSnapshot then
		Core.Events.ToClient(playerId, 'inventory.updated', sourceSnapshot)
	end
	if targetSnapshot then
		Core.Events.ToClient(targetId, 'inventory.updated', targetSnapshot)
	end
end)
