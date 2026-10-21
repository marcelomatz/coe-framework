-- Uso de item vindo do servidor (`inventory.useItem`): containers portáteis, armas e demais itens.
local C = Inventory.Client
local state = C.state

--- Item container: arma-container alterna equipar; se já estiver na mão, guarda; senão pega.
local function useContainerItem(item)
	local containerId = type(item.metadata) == 'table' and item.metadata.containerId or nil
	local success, errorCode
	if C.isWeaponItem(item.name) then
		success, errorCode = C.equipContainerWeapon(item)
	elseif state.carriedContainerId == containerId then
		success, errorCode = C.storeContainerProp(containerId)
	else
		success, errorCode = C.pickupContainerProp(item.name, containerId)
	end
	if not success then
		C.feedback(C.errorMessage(errorCode, C.t('error_equip_failed')), true)
	end
end

--- Arma comum: guarda se já estiver empunhada, senão saca. Retorna false se não for possível
--- tratá-la como arma (hash/ped inválidos), para cair no fluxo genérico.
local function useWeaponItem(item, onUsed)
	local weaponHash = GetHashKey(item.name)
	local playerPed = PlayerPedId()
	if weaponHash == 0 or playerPed == 0 then
		return false
	end

	if GetSelectedPedWeapon(playerPed) == weaponHash then
		C.playItemAnimation('weapon_holster', function()
			SetCurrentPedWeapon(playerPed, GetHashKey('WEAPON_UNARMED'), true)
			onUsed()
		end, item)
	else
		C.playItemAnimation(item.animation or 'weapon_draw', onUsed, item, function()
			C.equipWeaponItem(item)
		end)
	end
	return true
end

--- Ponto de entrada. Ao terminar a animação dispara os eventos locais `inventory.itemUsed`
--- e `inventory.hotbarUsed`, que outros resources podem ouvir.
function C.useItem(item)
	if type(item) ~= 'table' or type(item.name) ~= 'string' then
		return
	end
	if item.container then
		useContainerItem(item)
		return
	end
	if state.equippedWeapon then
		C.clearEquippedWeapon(true)
	end

	local function onUsed()
		Core.Events.Emit('inventory.itemUsed', item)
		Core.Events.Emit('inventory.hotbarUsed', item.slot, item)
	end

	if C.isWeaponItem(item.name) and useWeaponItem(item, onUsed) then
		return
	end
	C.playItemAnimation(item.animation, onUsed, item)
end
