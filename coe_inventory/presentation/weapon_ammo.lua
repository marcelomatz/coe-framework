-- Munição da arma empunhada. A arma carrega só o que está em `metadata.ammo` (sem reserva), então
-- o R nativo não faz nada: aqui o R pede ao servidor para recarregar com a munição do calibre que
-- está no inventário. Os disparos são reportados para o servidor descontar do carregado.
local C = Inventory.Client
local RELOAD_CONTROL = 45
local REPORT_MS = 1000

local tracked = nil -- { slot, name, hash, ammo }
local reloading = false

local RELOAD_ERRORS = {
	no_ammo = 'Você não tem munição deste calibre.',
	weapon_full = 'A arma já está carregada.',
	not_reloadable = 'Esta arma não pode ser recarregada.'
}

--- Indica se o item é arma de fogo que usa munição do inventário.
function C.isReloadableWeapon(item)
	local profile = type(item) == 'table' and item.weapon
	return type(profile) == 'table' and profile.ammoType ~= nil and profile.category ~= 'throwable'
end

local function reportAmmo()
	if not tracked then
		return
	end
	local ammo = GetAmmoInPedWeapon(PlayerPedId(), tracked.hash)
	if ammo < tracked.ammo then
		tracked.ammo = math.max(0, ammo)
		Core.Events.ToServer('inventory.weaponAmmo', tracked.slot, tracked.name, tracked.ammo)
	end
end

--- Passa a acompanhar a arma recém-sacada (ou para, se não usar munição).
function C.trackWeapon(item, ammo)
	if tracked then
		reportAmmo()
	end
	tracked = nil
	reloading = false
	if C.isReloadableWeapon(item) and Core.Functions.IsInteger(item.slot) then
		tracked = { slot = item.slot, name = item.name, hash = GetHashKey(item.name), ammo = ammo }
	end
end

--- Mantém o slot da arma acompanhada quando o inventário muda (troca de slot, entrega, drop).
function C.reconcileTrackedWeapon(inventory)
	if not tracked or type(inventory) ~= 'table' or type(inventory.items) ~= 'table' then
		return
	end
	local atSlot = inventory.items[tracked.slot]
	if type(atSlot) == 'table' and atSlot.name == tracked.name then
		return
	end
	for slot, item in pairs(inventory.items) do
		if type(item) == 'table' and item.name == tracked.name then
			tracked.slot = slot
			return
		end
	end
	tracked = nil
end

local function requestReload(ped)
	local capacity = GetMaxAmmoInClip(ped, tracked.hash, true)
	local loaded = GetAmmoInPedWeapon(ped, tracked.hash)
	local _, clip = GetAmmoInClip(ped, tracked.hash)
	if capacity <= 0 then
		return
	end
	-- Já há munição carregada fora do pente (recarga anterior interrompida): só completa o pente.
	if loaded > (clip or 0) and (clip or 0) < capacity then
		MakePedReload(ped)
		return
	end
	if loaded >= capacity then
		C.feedback(RELOAD_ERRORS.weapon_full, true)
		return
	end
	reloading = true
	Core.Events.ToServer('inventory.reloadWeapon', tracked.slot, tracked.name, loaded, capacity)
	SetTimeout(3000, function()
		reloading = false
	end)
end

Core.Events.OnNet('inventory.weaponReloaded', function(slot, ok, result)
	reloading = false
	if not tracked or tracked.slot ~= slot then
		return
	end
	if not ok then
		C.feedback(RELOAD_ERRORS[result] or 'Não foi possível recarregar.', true)
		return
	end
	local ped = PlayerPedId()
	tracked.ammo = result
	-- O carregado novo vira reserva e o recarregamento passa a munição para o pente com animação.
	SetPedAmmo(ped, tracked.hash, result)
	MakePedReload(ped)
end)

CreateThread(function()
	local nextReport = 0
	while true do
		if not tracked then
			Wait(500)
		else
			local ped = PlayerPedId()
			if GetSelectedPedWeapon(ped) ~= tracked.hash then
				reportAmmo()
				tracked = nil
			else
				DisableControlAction(0, RELOAD_CONTROL, true)
				if IsDisabledControlJustPressed(0, RELOAD_CONTROL) and not reloading and not IsPedReloading(ped) then
					reportAmmo()
					requestReload(ped)
				end
				local now = GetGameTimer()
				if now >= nextReport then
					nextReport = now + REPORT_MS
					reportAmmo()
				end
				Wait(0)
			end
		end
	end
end)
