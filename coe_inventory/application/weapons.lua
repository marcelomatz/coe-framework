-- Munição das armas: `metadata.ammo` é o que está carregado na arma. Recarregar consome a munição
-- do calibre da arma (`weapon.ammoType`) do inventário; disparos só podem diminuir o carregado.
local S = Inventory.Service

S.weaponAmmoTimes = {}
local MAX_CAPACITY = 250
local AMMO_SYNC_MS = 200

local function loadedAmmo(item)
	local ammo = tonumber(type(item.metadata) == 'table' and item.metadata.ammo or nil) or 0
	return math.max(0, math.floor(ammo))
end

local function withAmmo(item, slot, ammo)
	local metadata = Core.Functions.DeepCopy(item.metadata or {})
	metadata.ammo = ammo
	return Inventory.Items.Create(item.name, item.count, metadata, slot)
end

local function reloadableWeapon(inventory, slot, name)
	if not S.isPositiveInteger(slot) or slot > inventory.slots then
		return nil, 'invalid_slot'
	end
	local weapon = inventory.items[slot]
	local profile = weapon and weapon.definition.weapon
	if not profile or weapon.name ~= name or not profile.ammoType or profile.category == 'throwable' then
		return nil, 'not_reloadable'
	end
	return weapon, profile
end

--- Recarrega a arma `name` do slot até `capacity` (tamanho do pente informado pelo cliente).
--- `current` é a munição que o cliente vê na arma; só vale se for menor que a registrada.
---@return boolean ok, integer|string ammoOrError
function S.ReloadWeapon(id, slot, name, current, capacity)
	local inventory, errorMessage = S.getInventory(id)
	if not inventory then
		return false, errorMessage
	end
	local weapon, profile = reloadableWeapon(inventory, slot, name)
	if not weapon then
		return false, profile
	end
	if not S.isPositiveInteger(capacity) then
		return false, 'invalid_count'
	end

	local loaded = loadedAmmo(weapon)
	if Core.Functions.IsInteger(current) and current >= 0 and current < loaded then
		loaded = current
	end
	local missing = math.min(capacity, MAX_CAPACITY) - loaded
	if missing <= 0 then
		return false, 'weapon_full'
	end

	local previous = {}
	for index = 1, inventory.slots do
		previous[index] = inventory.items[index]
	end
	local function rollback(code)
		inventory.items = previous
		return false, code
	end

	local taken = 0
	for index = 1, inventory.slots do
		local item = inventory.items[index]
		if taken < missing and item and item.name == profile.ammoType then
			local take = math.min(item.count, missing - taken)
			if take == item.count then
				inventory.items[index] = nil
			else
				local rest, restError = Inventory.Items.Create(item.name, item.count - take, item.metadata, index)
				if not rest then
					return rollback(restError)
				end
				inventory.items[index] = rest
			end
			taken = taken + take
		end
	end
	if taken == 0 then
		return rollback('no_ammo')
	end

	local updated, updateError = withAmmo(weapon, slot, loaded + taken)
	if not updated then
		return rollback(updateError)
	end
	inventory.items[slot] = updated
	if not S.persistInventory(inventory) then
		return rollback('persistence_failed')
	end
	return true, loaded + taken
end

--- Registra a munição restante após disparos. Nunca aumenta o carregado.
function S.SyncWeaponAmmo(id, slot, name, ammo)
	local inventory, errorMessage = S.getInventory(id)
	if not inventory then
		return false, errorMessage
	end
	local weapon, profile = reloadableWeapon(inventory, slot, name)
	if not weapon then
		return false, profile
	end
	if not Core.Functions.IsInteger(ammo) or ammo < 0 then
		return false, 'invalid_count'
	end
	if ammo >= loadedAmmo(weapon) then
		return true
	end
	local updated, updateError = withAmmo(weapon, slot, ammo)
	if not updated then
		return false, updateError
	end
	inventory.items[slot] = updated
	-- Gasto de munição não cria item: pode ir no write-behind.
	return S.markInventoryDirty(inventory)
end

Core.Events.OnNet('inventory.reloadWeapon', function(slot, name, current, capacity)
	local playerId = source
	if not S.allowInventoryAction(playerId) then
		return
	end
	local inventoryId, inventoryOrError = S.ensurePlayerInventory(playerId)
	if not inventoryId then
		Core.Events.ToClient(playerId, 'inventory.weaponReloaded', slot, false, inventoryOrError)
		return
	end

	local ok, result = S.ReloadWeapon(inventoryId, slot, name, current, capacity)
	Core.Events.ToClient(playerId, 'inventory.weaponReloaded', slot, ok, result)
	if ok then
		local snapshot = S.GetInventory(inventoryId)
		if snapshot then
			Core.Events.ToClient(playerId, 'inventory.updated', snapshot)
		end
	end
end)

Core.Events.OnNet('inventory.weaponAmmo', function(slot, name, ammo)
	local playerId = source
	local now = GetGameTimer()
	local previous = S.weaponAmmoTimes[playerId]
	if previous and now - previous < AMMO_SYNC_MS then
		return
	end
	S.weaponAmmoTimes[playerId] = now

	local inventoryId = S.ensurePlayerInventory(playerId)
	if inventoryId then
		S.SyncWeaponAmmo(inventoryId, slot, name, ammo)
	end
end)
