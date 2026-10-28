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

function S.notifyInventoryOwner(id)
	if type(id) ~= 'string' then
		return
	end
	local characterId = id:match('^character:(.+)$')
	if not characterId or type(GetPlayers) ~= 'function' or not (Core and Core.Players and Core.Players.GetActiveCharacterId) then
		return
	end
	for _, rawId in ipairs(GetPlayers()) do
		local playerId = tonumber(rawId)
		if playerId and tostring(Core.Players.GetActiveCharacterId(playerId) or '') == characterId then
			local snapshot = S.GetInventory(id)
			if snapshot and Core.Events and Core.Events.ToClient then
				Core.Events.ToClient(playerId, 'inventory.updated', snapshot)
			end
			return
		end
	end
end

local function unwrapExport(fn)
	return function(...)
		local args = table.pack(...)
		if args.n > 0 and (type(args[1]) == 'table' or type(args[1]) == 'userdata') then
			return fn(table.unpack(args, 2, args.n))
		end
		return fn(...)
	end
end

exports('GetPlayerInventory', unwrapExport(function(playerId)
	local inventoryId, inventoryOrError = S.ensurePlayerInventory(playerId)
	if not inventoryId then
		return nil, inventoryOrError
	end
	local snapshot, snapshotError = S.GetInventory(inventoryId)
	if not snapshot then
		return nil, snapshotError
	end
	return inventoryId, snapshot
end))
