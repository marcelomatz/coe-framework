-- Recarga de armas com munição do inventário e desconto dos disparos.
local H = dofile([=[test/support/harness.lua]=])
local eq = H.assertEqual

H.activeCharacters[1] = 'char1'
H.placePlayer(1, 0.0, 0.0, 0.0)

local function export(name)
	return assert(H.exported[name], 'export ausente: ' .. name)
end
local function call(name, ...)
	H.as(1)
	return assert(H.networkHandlers[name], 'handler ausente: ' .. name)(...)
end
local function reloaded()
	local event = assert(H.lastClientEvent('inventory.weaponReloaded'), 'sem inventory.weaponReloaded')
	return event.args[2], event.args[3]
end
local S = Inventory.Service

local id = export('GetPlayerInventory')(1)
local _, pistol = export('AddItem')(id, 'WEAPON_PISTOL', 1)
assert(pistol, 'pistola adicionada')
eq(export('GetSlot')(id, pistol).metadata.ammo, 0, 'arma nova vem descarregada')

-- Sem munição do calibre: recusa sem mexer no inventário.
H.clearEvents()
call('inventory.reloadWeapon', pistol, 'WEAPON_PISTOL', 0, 12)
eq(select(2, reloaded()), 'no_ammo', 'sem munição')

-- Calibre errado não serve; o certo é consumido até o tamanho do pente, em vários slots.
export('AddItem')(id, 'ammo-rifle', 30)
export('AddItem')(id, 'ammo-9', 5)
export('AddItem')(id, 'ammo-9', 4, { lote = 2 })
H.timer.now = H.timer.now + 1000
call('inventory.reloadWeapon', pistol, 'WEAPON_PISTOL', 0, 12)
local ok, ammo = reloaded()
eq(ok, true, 'recarregou')
eq(ammo, 9, 'usou toda a munição 9mm disponível')
eq(export('GetItemCount')(id, 'ammo-9'), 0, '9mm consumida')
eq(export('GetItemCount')(id, 'ammo-rifle'), 30, 'munição de fuzil intacta')
eq(export('GetSlot')(id, pistol).metadata.ammo, 9, 'carregado gravado na arma')

-- Disparos só diminuem; o cliente não consegue aumentar o carregado.
H.timer.now = H.timer.now + 1000
call('inventory.weaponAmmo', pistol, 'WEAPON_PISTOL', 50)
eq(export('GetSlot')(id, pistol).metadata.ammo, 9, 'não aumenta')
H.timer.now = H.timer.now + 1000
call('inventory.weaponAmmo', pistol, 'WEAPON_PISTOL', 3)
eq(export('GetSlot')(id, pistol).metadata.ammo, 3, 'desconta disparos')

-- Completa o pente a partir do que sobrou, sem passar do tamanho dele.
export('AddItem')(id, 'ammo-9', 40)
H.timer.now = H.timer.now + 1000
call('inventory.reloadWeapon', pistol, 'WEAPON_PISTOL', 3, 12)
eq(select(2, reloaded()), 12, 'completa o pente')
eq(export('GetItemCount')(id, 'ammo-9'), 31, 'consumiu só o que faltava')
H.timer.now = H.timer.now + 1000
call('inventory.reloadWeapon', pistol, 'WEAPON_PISTOL', 12, 12)
eq(select(2, reloaded()), 'weapon_full', 'pente cheio')

-- Slot errado, nome divergente ou item que não é arma de fogo são recusados.
eq(select(2, S.ReloadWeapon(id, pistol, 'WEAPON_SMG', 0, 30)), 'not_reloadable', 'nome divergente')
local _, water = export('AddItem')(id, 'water', 1)
eq(select(2, S.ReloadWeapon(id, water, 'water', 0, 30)), 'not_reloadable', 'item comum')
eq(select(2, S.ReloadWeapon(id, 999, 'WEAPON_PISTOL', 0, 30)), 'invalid_slot', 'slot inválido')
eq(select(2, S.ReloadWeapon(id, pistol, 'WEAPON_PISTOL', 0, 0)), 'invalid_count', 'capacidade inválida')

-- Falha ao gravar desfaz o consumo.
H.fail.set = true
local before = export('GetItemCount')(id, 'ammo-9')
eq(select(2, S.ReloadWeapon(id, pistol, 'WEAPON_PISTOL', 0, 12)), 'persistence_failed', 'falha de gravação')
eq(export('GetItemCount')(id, 'ammo-9'), before, 'munição devolvida')
eq(export('GetSlot')(id, pistol).metadata.ammo, 12, 'arma intacta')

print('inventory_weapons_test: todos os testes passaram')
