-- Containers abertos por jogador: validação, índices e snapshots.
local S = Inventory.Service

function S.closeOpenedContainer(playerId, index, notify)
	local opened = S.openedContainers[playerId]
	if index then
		if opened then opened[index] = nil end
		if opened and not opened[1] and not opened[2] then
			S.openedContainers[playerId] = nil
		end
	else
		S.openedContainers[playerId] = nil
	end
	if notify then
		Core.Events.ToClient(playerId, 'inventory.containerClosed', index)
	end
end


function S.validateOpenedContainer(playerId, playerInventory, index)
	local opened = S.openedContainers[playerId] and S.openedContainers[playerId][index]
	if not opened then
		return nil, nil, nil, 'container_not_open'
	end
	if opened.parentInventoryId ~= playerInventory.id then
		S.closeOpenedContainer(playerId, index, true)
		return nil, nil, nil, 'container_not_open'
	end
	if opened.stash then
		if not S.isNearStash(playerId, opened.stash, S.STASH_TOLERANCE) then
			S.closeOpenedContainer(playerId, index, true)
			return nil, nil, nil, 'too_far'
		end
		local stashInventory, stashError = S.getInventory(opened.containerId)
		if not stashInventory then
			S.closeOpenedContainer(playerId, index, true)
			return nil, nil, nil, stashError
		end
		return opened, playerInventory, stashInventory
	end
	if opened.worldNetId then
		local worldContainer = S.getWorldContainerByNetId(opened.worldNetId)
		if not worldContainer or worldContainer.containerId ~= opened.containerId then
			S.closeOpenedContainer(playerId, index, true)
			return nil, nil, nil, 'container_moved'
		end
		-- Abrir não dá acesso permanente: quem se afastou (ou foi teleportado) perde o painel.
		if not S.isNearWorldContainer(playerId, worldContainer, S.WORLD_OPEN_TOLERANCE) then
			S.closeOpenedContainer(playerId, index, true)
			return nil, nil, nil, 'too_far'
		end
		local containerInventory, errorMessage = S.getInventory(opened.containerId)
		if not containerInventory then
			S.closeOpenedContainer(playerId, index, true)
			return nil, nil, nil, errorMessage
		end
		return opened, playerInventory, containerInventory
	end

	local parentItem = playerInventory.items[opened.parentSlot]
	if not parentItem or not parentItem.definition.container
		or parentItem.metadata.containerId ~= opened.containerId then
		S.closeOpenedContainer(playerId, index, true)
		return nil, nil, nil, 'container_moved'
	end

	local containerInventory, errorMessage = S.getInventory(opened.containerId)
	if not containerInventory then
		S.closeOpenedContainer(playerId, index, true)
		return nil, nil, nil, errorMessage
	end

	return opened, playerInventory, containerInventory
end

function S.validateOpenedContainers(playerId, playerInventory)
	for index = 1, 2 do
		if S.openedContainers[playerId] and S.openedContainers[playerId][index] then
			S.validateOpenedContainer(playerId, playerInventory, index)
		end
	end
end

-- Folga sobre worldInteractDistance para quem abriu e deu um passo para trás.
S.WORLD_OPEN_TOLERANCE = 2.0

--- Reenvia o conteúdo de uma maleta do mundo a todos que a têm aberta, menos a quem agiu.
function S.refreshContainerViewers(containerId, exceptPlayerId)
	for viewerId, opened in pairs(S.openedContainers) do
		if viewerId ~= exceptPlayerId then
			for index = 1, 2 do
				local panel = opened[index]
				if panel and (panel.worldNetId or panel.stash) and panel.containerId == containerId then
					local snapshot = S.getOpenedContainerSnapshot(panel.parentInventoryId, panel)
					if snapshot then
						Core.Events.ToClient(viewerId, 'inventory.containerUpdated', snapshot, index)
					end
				end
			end
		end
	end
end

function S.containerIndexFromSide(side)
	if side == 'container-1' then return 1 end
	if side == 'container-2' then return 2 end
end


function S.getOpenedContainerSnapshot(inventoryId, opened)
	if opened.stash then
		return S.stashSnapshot(opened)
	end
	if not opened.worldNetId then
		return S.GetContainerInventory(inventoryId, opened.parentSlot)
	end

	local worldContainer = S.getWorldContainerByNetId(opened.worldNetId)
	local definition = worldContainer and Inventory.Items.Get(worldContainer.itemName)
	if not worldContainer or not definition then
		return nil, 'container_moved'
	end

	local snapshot, errorMessage = S.GetInventory(opened.containerId)
	if not snapshot and errorMessage == 'not_found' then
		-- Container solto antes de ser aberto pela primeira vez ainda não tem inventário.
		local profile = definition.container
		local created, createError = S.CreateInventory(opened.containerId, profile.slots, profile.maxWeight)
		if not created and createError ~= 'already_exists' then return nil, createError end
		snapshot, errorMessage = S.GetInventory(opened.containerId)
	end
	if not snapshot then return nil, errorMessage end
	snapshot.container = {
		label = worldContainer.metadata.label or definition.label,
		slots = definition.container.slots,
		maxWeight = definition.container.maxWeight
	}
	return snapshot
end


function S.getAvailableContainerIndex(playerId, worldNetId)
	local opened = S.openedContainers[playerId] or {}
	for index = 1, 2 do
		if opened[index] and opened[index].worldNetId == worldNetId then
			return index
		end
	end
	for index = 1, 2 do
		if not opened[index] then
			return index
		end
	end
end
