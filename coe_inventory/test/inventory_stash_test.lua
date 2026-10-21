-- Baús fixos (OpenStash) e RemoveItemByName do coe_inventory.
local H = dofile([=[test/support/harness.lua]=])
local eq = H.assertEqual

H.activeCharacters[1] = 'char1'
H.activeCharacters[2] = 'char2'
H.placePlayer(1, 0.0, 0.0, 0.0)
H.placePlayer(2, 1.0, 0.0, 0.0)

local function export(name)
	return assert(H.exported[name], 'export ausente: ' .. name)
end
local function call(playerId, name, ...)
	H.as(playerId)
	return assert(H.networkHandlers[name], 'handler ausente: ' .. name)(...)
end
local function lastResult()
	local event = assert(H.lastActionResult(), 'sem inventory.actionResult')
	return event.args[2], event.args[3]
end

local id1 = export('GetPlayerInventory')(1)
export('GetPlayerInventory')(2)

local stash = { label = 'Bau da oficina', slots = 10, maxWeight = 50000, position = { x = 0.0, y = 0.0, z = 0.0 }, radius = 3.0 }

-- Validação de entrada.
eq(select(2, export('OpenStash')(1, 'container:x', stash)), 'invalid_id', 'prefixo obrigatório')
eq(select(2, export('OpenStash')(1, 'stash:a', { label = 'x' })), 'invalid_stash', 'definição incompleta')
eq(select(2, export('OpenStash')(1, 'stash:a', { label = 'x', slots = 10, position = { x = 0.0, y = 0.0, z = 0.0 }, radius = 99.0 })), 'invalid_stash', 'raio grande demais')

-- Abrir cria o inventário e notifica o cliente.
H.clearEvents()
eq((export('OpenStash')(1, 'stash:bennys', stash)), true, 'abre o baú')
local opened = H.lastClientEvent('inventory.worldContainerOpened')
eq(opened.args[2].id, 'stash:bennys', 'snapshot do baú')
eq(opened.args[2].container.label, 'Bau da oficina', 'rótulo do baú')
eq(opened.args[3], 1, 'índice 1')
eq((export('OpenStash')(1, 'stash:bennys', stash)), true, 'reabrir reutiliza o índice')
eq(H.lastClientEvent('inventory.worldContainerOpened').args[3], 1, 'mesmo índice')

-- Mover itens entre jogador e baú.
local _, slot = export('AddItem')(id1, 'water', 3)
call(1, 'inventory.containerMove', 1, 'player', 'container-1', slot, 1)
eq((lastResult()), true, 'guardar no baú')
eq(export('GetSlot')('stash:bennys', 1).name, 'water', 'item no baú')

-- Outro jogador perto vê a mudança; longe perde o acesso.
eq((export('OpenStash')(2, 'stash:bennys', stash)), true, 'segundo jogador abre')
call(2, 'inventory.containerMove', 2, 'container-1', 'player', 1, 5)
eq((lastResult()), true, 'retirar do baú')
H.placePlayer(2, 40.0, 0.0, 0.0)
call(2, 'inventory.containerMove', 3, 'player', 'container-1', 5, 1)
eq(select(2, lastResult()), 'container_not_open', 'longe do baú fecha o painel')
eq(Inventory.Service.openedContainers[2], nil, 'painel removido')

-- RemoveItemByName remove em vários slots e recusa excesso.
local id2 = export('GetPlayerInventory')(2)
export('AddItem')(id2, 'scrapmetal', 5)
local _, second = export('AddItem')(id2, 'scrapmetal', 1, { n = 2 })
assert(second, 'segundo slot de metal')
eq(export('GetItemCount')(id2, 'scrapmetal'), 6, 'seis sucatas')
eq(select(2, export('RemoveItemByName')(id2, 'scrapmetal', 7)), 'insufficient_items', 'excesso recusado')
eq(export('GetItemCount')(id2, 'scrapmetal'), 6, 'nada removido')
eq((export('RemoveItemByName')(id2, 'scrapmetal', 6)), true, 'remove tudo')
eq(export('GetItemCount')(id2, 'scrapmetal'), 0, 'zerou')
eq(select(2, export('RemoveItemByName')(id2, 'scrapmetal', 0)), 'invalid_count', 'contagem inválida')

print('inventory_stash_test: todos os testes passaram')
