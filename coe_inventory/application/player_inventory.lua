-- Resolução do inventário do personagem ativo.
local S = Inventory.Service

function S.getPlayerInventoryId(playerId)
	local characterId, errorMessage = Core.Players.GetActiveCharacterId(playerId)
	if not characterId then
		return nil, errorMessage or 'character_not_loaded'
	end
	return 'character:' .. characterId
end

function S.ensurePlayerInventory(playerId)
	local inventoryId, identityError = S.getPlayerInventoryId(playerId)
	if not inventoryId then
		return nil, identityError
	end

	local inventory, loadError = S.loadInventory(inventoryId)
	if not inventory and loadError == 'not_found' then
		local created, createError = S.CreateInventory(inventoryId)
		if not created and createError ~= 'already_exists' then
			return nil, createError
		end
		inventory, loadError = S.loadInventory(inventoryId)
	end
	if not inventory then
		return nil, loadError
	end

	local starterItemsGranted, starterError = S.grantStarterItems(inventory)
	if not starterItemsGranted then
		return nil, starterError
	end

	return inventoryId, inventory
end

exports('GetPlayerInventory', function(playerId)
	local inventoryId, inventoryOrError = S.ensurePlayerInventory(playerId)
	if not inventoryId then
		return nil, inventoryOrError
	end
	local snapshot, snapshotError = S.GetInventory(inventoryId)
	if not snapshot then
		return nil, snapshotError
	end
	return inventoryId, snapshot
end)
