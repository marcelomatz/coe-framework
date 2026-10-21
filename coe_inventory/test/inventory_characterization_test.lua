-- Testes de caracterização do coe_inventory: fixam o comportamento observável
-- (exports, handlers de rede e eventos) antes de qualquer refatoração.
local H = dofile([=[test/support/harness.lua]=])
local eq = H.assertEqual

H.activeCharacters[1] = 'char1'
H.activeCharacters[2] = 'char2'
H.placePlayer(1, 0.0, 0.0, 0.0)
H.placePlayer(2, 1.0, 0.0, 0.0)

local function export(name)
	return assert(H.exported[name], 'export ausente: ' .. name)
end
local function net(name)
	return assert(H.networkHandlers[name], 'handler ausente: ' .. name)
end
local function call(playerId, name, ...)
	H.as(playerId)
	return net(name)(...)
end
local function lastResult()
	local event = H.lastActionResult()
	assert(event, 'sem inventory.actionResult')
	return event.args[2], event.args[3]
end
local function snapshotOf(id)
	return export('GetInventory')(id)
end

local function freeze()
	H.timer.now = H.timer.now + 1000
	H.timer.step = 0
end

local id1 = export('GetPlayerInventory')(1)
eq(id1, 'character:char1', 'id do inventário')
local id2 = export('GetPlayerInventory')(2)

-- Starter: water(1) bread(2) bandage(3) phone(4).
eq(export('GetItemCount')(id1, 'water'), 2, 'starter water')

-- SwapSlots
eq(export('SwapSlots')(id1, 1, 10), true, 'swap para slot vazio')
eq(snapshotOf(id1).items[10].name, 'water', 'water foi para o slot 10')
eq(snapshotOf(id1).items[1], false, 'slot 1 ficou vazio')
eq(export('SwapSlots')(id1, 10, 2), true, 'swap entre ocupados')
eq(snapshotOf(id1).items[2].name, 'water', 'water no slot 2')
eq(snapshotOf(id1).items[10].name, 'bread', 'bread no slot 10')
local swapOk, swapError = export('SwapSlots')(id1, 1, 9999)
eq(swapOk, false, 'swap fora do limite')
eq(swapError, 'invalid_slot', 'erro swap fora do limite')
eq(export('SwapSlots')(id1, 2, 2), true, 'swap no mesmo slot é no-op bem-sucedido')

-- RemoveItem
local removeOk, removeError = export('RemoveItem')(id1, 2, 5)
eq(removeOk, false, 'remove mais do que há')
eq(removeError, 'insufficient_items', 'erro de remoção')
eq(select(2, export('RemoveItem')(id1, 2, 0)), 'invalid_count', 'count inválido')
eq(select(2, export('RemoveItem')(id1, 0, 1)), 'invalid_slot', 'slot inválido')
eq(export('RemoveItem')(id1, 2, 1), true, 'remove 1 water')
eq(export('GetItemCount')(id1, 'water'), 1, 'sobrou 1 water')
eq(export('RemoveItem')(id1, 2, 1), true, 'remove último water')
eq(snapshotOf(id1).items[2], false, 'slot vazio após remover tudo')

-- UseItem: consome e emite o evento local
H.clearEvents()
local used, usedItem = export('UseItem')(id1, 10)
eq(used, true, 'usar bread')
eq(usedItem.name, 'bread', 'item usado')
eq(export('GetItemCount')(id1, 'bread'), 1, 'bread consumido')
eq(H.emitted[1].name, 'inventory.itemUsed', 'evento itemUsed')
eq(H.emitted[1].args[1], id1, 'itemUsed inventário')
eq(H.emitted[1].args[2], 10, 'itemUsed slot')
eq(select(2, export('UseItem')(id1, 30)), 'empty_slot', 'usar slot vazio')
eq(select(2, export('UseItem')(id1, 31)), 'invalid_slot', 'usar slot fora do limite')

-- SetItemMetadata: mescla chaves e mantém as demais
eq(export('SetItemMetadata')(id1, 4, { serial = 'SN123' }), true, 'gravar serial no phone')
eq(snapshotOf(id1).items[4].metadata.serial, 'SN123', 'serial gravado')
eq(snapshotOf(id1).items[4].metadata.durability, 100, 'durability preservada')
eq(export('GetItemCount')(id1, 'phone', { serial = 'SN123' }, false), 1, 'conta por subconjunto da metadata')
eq(select(2, export('SetItemMetadata')(id1, 30, { a = 1 })), 'empty_slot', 'metadata em slot vazio')
eq(select(2, export('SetItemMetadata')(id1, 31, { a = 1 })), 'invalid_slot', 'metadata fora do limite')
eq(select(2, export('SetItemMetadata')(id1, 4, { 'x' })), 'invalid_item_metadata', 'chave não string')
eq(snapshotOf(id1).items[4].metadata[1], nil, 'patch inválido não altera')

-- AddItem: maxStack, validações e peso
eq(select(2, export('AddItem')(id1, 'water', 25)), 'stack_limit', 'adicionar mais que maxStack de uma vez')
eq(export('AddItem')(id1, 'water', 19), true, 'AddItem água em pilha cheia')
eq(export('AddItem')(id1, 'water', 5), true, 'excedente vai para nova pilha')
eq(export('GetItemCount')(id1, 'water'), 24, 'contagem após empilhar')
local stacks = 0
for _, item in ipairs(snapshotOf(id1).items) do
	if item and item.name == 'water' then
		stacks = stacks + 1
		assert(item.count <= 20, 'maxStack respeitado')
	end
end
eq(stacks, 2, 'água dividida em duas pilhas')
eq(select(2, export('AddItem')(id1, 'nao_existe', 1)), 'invalid_item', 'item desconhecido')
eq(export('AddItem')(id1, 'water', 0), false, 'quantidade inválida')

eq(export('CreateInventory')('small', 5, 1000), true, 'cria inventário pequeno')
local heavyOk, heavyError = export('AddItem')('small', 'water', 3)
eq(heavyOk, false, 'excede peso')
assert(heavyError, 'erro de peso')
eq(export('AddItem')('small', 'water', 2), true, 'cabe no peso')
eq(export('CreateInventory')('small'), false, 'duplicado')
eq(select(2, export('CreateInventory')('small')), 'already_exists', 'erro de duplicado')
eq(select(2, export('CreateInventory')('x y')), 'invalid_id', 'id inválido')
eq(export('GetSlot')('small', 1).name, 'water', 'GetSlot')
eq(select(2, export('GetSlot')('small', 99)), 'invalid_slot', 'GetSlot inválido')
eq(export('DeleteInventory')('small'), true, 'DeleteInventory')
eq(select(2, export('GetInventory')('small')), 'not_found', 'inventário removido')

-- Handlers: swap com rate limit e atualização
H.clearEvents()
call(1, 'inventory.swap', 3, 20)
eq(H.lastClientEvent('inventory.updated').target, 1, 'swap notifica o jogador')
eq(snapshotOf(id1).items[20].name, 'bandage', 'swap pelo handler')
H.clearEvents()
call(1, 'inventory.swap', 'a', 20)
eq(H.lastClientEvent('inventory.updated'), nil, 'swap com argumento inválido é ignorado')

freeze()
H.clearEvents()
call(1, 'inventory.swap', 20, 3)
call(1, 'inventory.swap', 3, 20)
eq(snapshotOf(id1).items[3].name, 'bandage', 'segundo swap imediato foi limitado')
H.timer.step = 400

-- Handler use: resultado, evento ao cliente e snapshot
H.clearEvents()
call(1, 'inventory.use', 7, 10)
local ok7 = lastResult()
eq(ok7, true, 'use pelo handler')
assert(H.lastClientEvent('inventory.useItem'), 'inventory.useItem enviado')
assert(H.lastClientEvent('inventory.updated'), 'inventory.updated enviado')
call(1, 'inventory.use', 8, 25)
local ok8, err8 = lastResult()
eq(ok8, false, 'use em slot vazio')
eq(err8, 'empty_slot', 'erro use')

-- Rate limit de ações
freeze()
call(1, 'inventory.use', 9, 25)
call(1, 'inventory.use', 10, 25)
local _, limited = lastResult()
eq(limited, 'rate_limited', 'rate limit de ações')
H.timer.step = 400

-- Split pelo handler
H.clearEvents()
call(1, 'inventory.split', 11, 1, 5)
eq((lastResult()), true, 'split pelo handler')

-- Inventário sem personagem
H.clearEvents()
call(3, 'inventory.use', 12, 1)
local noChar, noCharError = lastResult()
eq(noChar, false, 'sem personagem')
eq(noCharError, 'character_not_loaded', 'erro sem personagem')

-- inventory.request: rate limit
freeze()
H.clearEvents()
call(1, 'inventory.request', 1)
call(1, 'inventory.request', 2)
local responses = {}
for _, event in ipairs(H.sentClientEvents) do
	if event.name == 'inventory.response' then
		responses[#responses + 1] = event
	end
end
eq(#responses, 1 + 1, 'duas respostas (uma limitada)')
eq(responses[2].args[3], 'rate_limited', 'request limitado')
H.timer.step = 400

-- Limpeza ao descarregar personagem / jogador sair
freeze()
call(1, 'inventory.use', 13, 25)
H.sessions[1] = { generation = 5 }
H.localHandlers['player.characterUnloaded']({ source = 1, generation = 4 })
call(1, 'inventory.use', 14, 25)
local _, stillLimited = lastResult()
eq(stillLimited, 'rate_limited', 'geração antiga não limpa estado')
H.localHandlers['player.characterUnloaded']({ source = 1, generation = 5 })
call(1, 'inventory.use', 15, 25)
local _, cleared = lastResult()
eq(cleared, 'empty_slot', 'unload limpa rate limit')
H.as(1)
call(1, 'inventory.use', 16, 25)
H.systemHandlers['playerDropped']()
call(1, 'inventory.use', 17, 25)
eq(select(2, lastResult()), 'empty_slot', 'playerDropped limpa rate limit')
H.timer.step = 400

-- Give: auditoria e rollback já cobertos em inventory_service_test; aqui só a negação
H.clearEvents()
call(1, 'inventory.give', 18, 99, 3, 1)
eq((lastResult()), false, 'give para alvo inexistente')

print('inventory characterization (core) tests passed')
