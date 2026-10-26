-- Eventos vindos do servidor (server -> client): respostas de inventário, containers,
-- containers do mundo e resultado de ações.
local C = Inventory.Client
local state = C.state

local function isPanelIndex(index)
	return index == 1 or index == 2
end

Core.Events.OnNet('inventory.response', function(requestId, inventory)
	if state.hotbarSyncRequestId and requestId == state.hotbarSyncRequestId then
		state.hotbarSyncRequestId = nil
		if type(inventory) == 'table' then
			state.cachedInventory = inventory
			SendNUIMessage({
				action = 'hotbarPeek',
				inventory = inventory,
				hotbarSlots = Config.Client.hotbarSlots,
				durationMs = Config.Client.hotbarPreviewMs
			})
		end
		return
	end
	if requestId ~= state.activeRequestId then
		return
	end

	state.requestPending = false
	state.activeRequestId = nil
	if type(inventory) ~= 'table' then
		return
	end

	state.cachedInventory = inventory
	C.reconcileContainerProps(inventory)
	C.syncCarriedState()
	C.openInventoryUi(inventory)
end)

Core.Events.OnNet('inventory.updated', function(inventory)
	if type(inventory) ~= 'table' then
		return
	end

	state.cachedInventory = inventory
	C.reconcileContainerProps(inventory)
	C.reconcileTrackedWeapon(inventory)
	if not state.inventoryOpen then
		SendNUIMessage({
			action = 'hotbarData',
			inventory = inventory,
			hotbarSlots = Config.Client.hotbarSlots
		})
		return
	end
	SendNUIMessage({
		action = 'update',
		inventory = inventory,
		openKey = Config.Client.openKey,
		hotbarSlots = Config.Client.hotbarSlots
	})
end)

Core.Events.OnNet('inventory.useItem', C.useItem)

Core.Events.OnNet('inventory.containerPickedUp', function(itemName, metadata)
	if type(itemName) ~= 'string' or type(metadata) ~= 'table' then return end
	local ok, errorCode = C.equipContainerWeapon({ name = itemName, metadata = metadata }, true)
	if not ok then
		C.feedback(C.errorMessage(errorCode, C.t('error_pickup_failed')), true)
	end
end)

Core.Events.OnNet('inventory.actionResult', function(requestId, success, errorMessage)
	local worldAction = state.pendingWorldActions[requestId]
	if worldAction then
		state.pendingWorldActions[requestId] = nil
		C.handleWorldActionResult(worldAction, success, errorMessage)
	elseif not success then
		exports.coe_notify:Show('error', C.t('error_action_failed'))
	end
	SendNUIMessage({
		action = 'actionResult',
		requestId = requestId,
		success = success == true,
		error = errorMessage
	})
end)

-- Painéis de container (1 e 2) -------------------------------------------------------------

Core.Events.OnNet('inventory.containerOpened', function(containerInventory, index)
	if not state.inventoryOpen or type(containerInventory) ~= 'table' or not isPanelIndex(index) then
		return
	end

	state.openedContainerPanels[index] = true
	SendNUIMessage({
		action = 'containerOpen',
		inventory = containerInventory,
		index = index
	})
end)

Core.Events.OnNet('inventory.containerUpdated', function(containerInventory, index)
	if not state.inventoryOpen or not state.openedContainerPanels[index] or type(containerInventory) ~= 'table' then
		return
	end

	SendNUIMessage({
		action = 'containerUpdate',
		inventory = containerInventory,
		index = index
	})
end)

Core.Events.OnNet('inventory.containerClosed', function(index)
	if index == nil then
		state.openedContainerPanels = {}
	else
		state.openedContainerPanels[index] = nil
	end
	SendNUIMessage({ action = 'containerClose', index = index })
end)

-- Containers do mundo ----------------------------------------------------------------------

Core.Events.OnNet('inventory.containerWorldAdded', function(netId, itemName)
	if Core.Functions.IsInteger(netId) and C.WORLD_CONTAINER_MODELS[itemName] then
		C.addWorldContainer(netId)
	end
end)

Core.Events.OnNet('inventory.containerWorldRemoved', function(netId)
	if Core.Functions.IsInteger(netId) then
		C.removeWorldContainer(netId)
	end
end)

--- Abertura de um container do mundo: abre o inventário do jogador e o painel do container.
Core.Events.OnNet('inventory.worldContainerOpened', function(playerInventory, containerInventory, index)
	if type(playerInventory) ~= 'table' or type(containerInventory) ~= 'table' or not isPanelIndex(index) then
		return
	end

	state.openedContainerPanels[index] = true
	C.reconcileContainerProps(playerInventory)
	local netId = state.lastOpenNetId
	state.lastOpenNetId = nil
	C.openInventoryUi(playerInventory)
	SendNUIMessage({
		action = 'containerOpen',
		inventory = containerInventory,
		index = index
	})
	C.startOpenCamera(netId)
end)

Core.Events.OnNet('inventory.containerDropResult', C.handleDropResult)
