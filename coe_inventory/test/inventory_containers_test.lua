-- Testes de caracterização de containers (portáteis e de mundo) do coe_inventory.
local H = dofile([=[test/support/harness.lua]=])
local eq = H.assertEqual

H.activeCharacters[1] = 'char1'
H.activeCharacters[2] = 'char2'
H.placePlayer(1, 0.0, 0.0, 0.0)
H.placePlayer(2, 50.0, 0.0, 0.0)

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
local function dropResult()
	local event = assert(H.lastClientEvent('inventory.containerDropResult'), 'sem containerDropResult')
	return event.args[2], event.args[3]
end

local id1 = export('GetPlayerInventory')(1)
export('GetPlayerInventory')(2)

-- Container portátil: abrir cria o inventário do container e notifica o cliente.
local _, bagSlot = export('AddItem')(id1, 'paperbag', 1)
assert(bagSlot, 'paperbag adicionada')
local bagId = export('GetSlot')(id1, bagSlot).metadata.containerId
assert(type(bagId) == 'string' and bagId:match('^container:'), 'containerId gerado')

H.clearEvents()
call(1, 'inventory.containerOpen', 1, bagSlot)
eq((lastResult()), true, 'abrir saco')
local opened = H.lastClientEvent('inventory.containerOpened')
eq(opened.args[1].id, bagId, 'snapshot do container')
eq(opened.args[2], 1, 'índice do container')
eq(opened.args[1].slots, 6, 'slots do saco')

call(1, 'inventory.containerOpen', 2, 9999)
eq(select(2, lastResult()), 'invalid_slot', 'slot inválido para abrir')

-- Mover item do jogador para o container e de volta.
local waterSlot
for slot, item in ipairs(export('GetInventory')(id1).items) do
	if item and item.name == 'water' then waterSlot = slot end
end
call(1, 'inventory.containerMove', 3, 'player', 'container-1', waterSlot, 2)
eq((lastResult()), true, 'mover para o container')
eq(export('GetSlot')(bagId, 2).name, 'water', 'water no container')
assert(H.lastClientEvent('inventory.containerUpdated'), 'containerUpdated enviado')

call(1, 'inventory.containerMove', 4, 'container-1', 'player', 2, 20)
eq((lastResult()), true, 'mover de volta')
eq(export('GetSlot')(bagId, 2), nil, 'container esvaziado')

call(1, 'inventory.containerMove', 5, 'player', 'player', 1, 2)
eq(select(2, lastResult()), 'invalid_slot', 'player para player é inválido')
call(1, 'inventory.containerMove', 6, 'container-2', 'player', 1, 2)
eq(select(2, lastResult()), 'container_not_open', 'container 2 fechado')
call(1, 'inventory.containerMove', 7, 'player', 'container-1', 19, 2)
eq(select(2, lastResult()), 'empty_slot', 'origem vazia')

-- Container dentro de container não é suportado.
export('AddItem')(id1, 'WEAPON_BRIEFCASE', 1)
local briefcaseSlot
for slot, item in ipairs(export('GetInventory')(id1).items) do
	if item and item.name == 'WEAPON_BRIEFCASE' then briefcaseSlot = slot end
end
call(1, 'inventory.containerMove', 8, 'player', 'container-1', briefcaseSlot, 3)
eq(select(2, lastResult()), 'nested_container_not_supported', 'container aninhado')

-- Fechar: abrir segundo e fechar o primeiro; terceiro excede o limite.
call(1, 'inventory.containerOpen', 9, briefcaseSlot)
eq((lastResult()), true, 'abrir segundo container')
export('AddItem')(id1, 'WEAPON_GARBAGEBAG', 1)
local garbageSlot
for slot, item in ipairs(export('GetInventory')(id1).items) do
	if item and item.name == 'WEAPON_GARBAGEBAG' then garbageSlot = slot end
end
call(1, 'inventory.containerOpen', 10, garbageSlot)
eq(select(2, lastResult()), 'container_limit', 'limite de dois containers')
call(1, 'inventory.containerClose', 1)
call(1, 'inventory.containerOpen', 11, garbageSlot)
eq((lastResult()), true, 'abre após fechar um')
call(1, 'inventory.containerClose')
call(1, 'inventory.containerMove', 12, 'player', 'container-1', waterSlot, 2)
eq(select(2, lastResult()), 'container_not_open', 'fechar tudo')

-- Drop no mundo: valida entrada e posse da entidade.
local bagItem = export('GetSlot')(id1, bagSlot)
local _, netId = H.createWorldObject('prop_paper_bag_01', vector3(1.0, 0.0, 0.0), 1)
H.clearEvents()
call(1, 'inventory.containerDrop', 20, 'inexistente', netId, { x = 1.0, y = 0.0, z = 0.0 }, 0.0)
eq(select(2, dropResult()), 'invalid_target', 'containerId desconhecido')
call(1, 'inventory.containerDrop', 21, bagId, netId, { x = 90.0, y = 0.0, z = 0.0 }, 0.0)
eq(select(2, dropResult()), 'invalid_target', 'posição longe do jogador')
call(1, 'inventory.containerDrop', 22, bagId, netId, 'x', 0.0)
eq(select(2, dropResult()), 'invalid_target', 'posição inválida')

H.clearEvents()
call(1, 'inventory.containerDrop', 23, bagId, netId, { x = 1.0, y = 0.0, z = 0.0 }, 90.0)
local dropped, droppedNetId = dropResult()
eq(dropped, true, 'drop com sucesso')
eq(droppedNetId, netId, 'netId do container')
eq(export('GetSlot')(id1, bagSlot), nil, 'item saiu do inventário')
eq(H.broadcasts[1].name, 'inventory.containerWorldAdded', 'broadcast do container')
local audited = {}
for _, entry in ipairs(H.audited) do audited[entry.event] = true end
assert(audited.world_container_dropped, 'auditoria do drop')
assert(H.storage['worldref:' .. bagId], 'marcador do container de mundo gravado')
assert(not H.storage['world:containers'], 'sem blob único de containers')

-- Container solto antes da primeira abertura não tem inventário salvo; abrir deve criá-lo.
H.storage[bagId] = nil
Inventory.Service.inventories[bagId] = nil

-- Abrir container de mundo; longe, não abre.
H.clearEvents()
call(2, 'inventory.containerWorldOpen', 30, netId)
eq(select(2, lastResult()), 'invalid_target', 'longe do container')
call(1, 'inventory.containerWorldOpen', 31, netId)
eq((lastResult()), true, 'abre container de mundo')
local worldOpened = H.lastClientEvent('inventory.worldContainerOpened')
eq(worldOpened.args[2].id, bagId, 'snapshot do container de mundo')
call(1, 'inventory.containerWorldOpen', 32, 'x')
eq(select(2, lastResult()), 'invalid_target', 'netId inválido')

-- Netid desconhecido é rejeitado como alvo inválido (antes levantava erro).
call(1, 'inventory.containerWorldOpen', 33, 987654)
eq(select(2, lastResult()), 'invalid_target', 'netId desconhecido')

-- A entidade carrega o containerId estável em statebag.
local tagged = Inventory.Service.getWorldContainerByNetId(netId)
eq(H.entityStates[tagged.entity]['coe:containerId'], bagId, 'statebag com containerId na entidade')

-- Container já reivindicado por outro jogador não pode ser coletado de novo (anti-dupe).
local claimed = Inventory.Service.getWorldContainerByNetId(netId)
claimed.claimedBy = 2
H.clearEvents()
call(1, 'inventory.containerWorldPickup', 39, netId)
eq(select(2, lastResult()), 'invalid_target', 'container reivindicado é recusado')
claimed.claimedBy = nil
assert(Inventory.Service.worldContainers[claimed.containerId], 'recusa não remove o container')

-- Coletar: devolve o item ao inventário e remove do mundo.
H.clearEvents()
call(1, 'inventory.containerWorldPickup', 40, netId)
eq((lastResult()), true, 'coleta container')
eq(export('GetSlot')(id1, bagSlot).metadata.containerId, bagId, 'mesmo containerId após coleta')
assert(H.lastClientEvent('inventory.containerClosed'), 'container aberto foi fechado')
assert(H.lastClientEvent('inventory.containerPickedUp'), 'maleta recolhida vai para a mao')
eq(H.broadcasts[#H.broadcasts].name, 'inventory.containerWorldRemoved', 'remoção em broadcast')
audited = {}
for _, entry in ipairs(H.audited) do audited[entry.event] = true end
assert(audited.world_container_picked_up, 'auditoria da coleta')
eq(select(2, Inventory.Service.removeWorldContainer(claimed)), 'invalid_target', 'remoção dupla é recusada')
assert(not H.storage['worldref:' .. bagId], 'marcador removido ao recolher')

-- Limites: global e por personagem recusam o drop antes de adotar a entidade.
Config.Server.maxWorldContainersPerPlayer = 1
local _, limitNet1 = H.createWorldObject('prop_paper_bag_01', vector3(1.0, 0.0, 0.0), 1)
call(1, 'inventory.containerDrop', 50, bagId, limitNet1, { x = 1.0, y = 0.0, z = 0.0 }, 0.0)
eq((dropResult()), true, 'primeiro drop dentro do limite')
export('AddItem')(id1, 'paperbag', 1)
local extraSlot
for slot, item in ipairs(export('GetInventory')(id1).items) do
	if item and item.name == 'paperbag' then extraSlot = slot end
end
local extraId = export('GetSlot')(id1, extraSlot).metadata.containerId
local _, limitNet2 = H.createWorldObject('prop_paper_bag_01', vector3(1.0, 0.0, 0.0), 1)
call(1, 'inventory.containerDrop', 51, extraId, limitNet2, { x = 1.0, y = 0.0, z = 0.0 }, 0.0)
eq(select(2, dropResult()), 'world_container_limit_player', 'limite por personagem')
Config.Server.maxWorldContainersPerPlayer = 10
Config.Server.maxWorldContainers = 1
call(1, 'inventory.containerDrop', 52, extraId, limitNet2, { x = 1.0, y = 0.0, z = 0.0 }, 0.0)
eq(select(2, dropResult()), 'world_container_limit', 'limite global')
Config.Server.maxWorldContainers = 200

-- Purge no boot: maletas que ficaram no mundo perdem o conteúdo; o blob legado também.
H.storage['container:orphan:1'] = '{}'
H.storage['worldref:container:orphan:1'] = '{}'
H.storage['container:legacy:1'] = '{}'
H.storage['world:containers'] = '[]'
Inventory.Service.worldContainers = {}
local purged = Inventory.Service.purgeWorldContainers()
assert(purged >= 2, 'purge conta os conteúdos removidos')
assert(not H.storage['container:orphan:1'] and not H.storage['worldref:container:orphan:1'], 'purge apaga conteúdo e marcador')
assert(not H.storage['world:containers'], 'purge apaga o blob legado')
assert(H.storage['container:legacy:1'], 'conteúdo sem marcador não é tocado')

-- GC de registros container:* órfãos: só remove o que nenhum inventário/marcador referencia.
do
	local S = Inventory.Service
	H.storage['container:gc:orphan'] = '{}'
	local report = S.gcOrphanContainers(false)
	eq(report.orphans >= 1, true, 'dry-run encontra órfão')
	eq(H.storage['container:gc:orphan'] ~= nil, true, 'dry-run não remove')
	eq(S.inventories[bagId] ~= nil or H.storage[bagId] ~= nil, true, 'maleta referenciada existe')
	report = S.gcOrphanContainers(true)
	eq(H.storage['container:gc:orphan'], nil, 'apply remove o órfão')
	eq(report.removed >= 1, true, 'apply conta removidos')
	eq(H.storage[bagId] ~= nil or S.inventories[bagId] ~= nil, true, 'apply preserva maleta referenciada')
end

-- Eviction de cache: ocioso sai; sujo ou com escrita pendente fica.
do
	local S = Inventory.Service
	local evictId = 'container:evict:1'
	eq(export('CreateInventory')(evictId, 4, 10), true, 'cria inventário de teste')
	local idle = S.inventories[evictId]
	eq(idle ~= nil, true, 'inventário no cache')
	local before = Config.Server.cacheTtlMs
	Config.Server.cacheTtlMs = 1000
	S.dirtyInventories[evictId] = idle
	H.timer.now = H.timer.now + 5000
	eq(S.evictIdleInventories() >= 0, true, 'varredura roda')
	eq(S.inventories[evictId] ~= nil, true, 'inventário sujo não é despejado')
	S.dirtyInventories[evictId] = nil
	S.evictIdleInventories()
	eq(S.inventories[evictId], nil, 'inventário ocioso é despejado')
	eq(S.getInventory(evictId) ~= nil, true, 'recarrega do banco após eviction')
	Config.Server.cacheTtlMs = 0
	H.timer.now = H.timer.now + 5000
	eq(S.evictIdleInventories(), 0, 'ttl 0 desativa')
	Config.Server.cacheTtlMs = before
end
-- Sincronização com o cliente.
H.clearEvents()
call(1, 'inventory.containerWorldSync')
for _, thread in ipairs(H.threads) do thread() end
H.systemHandlers['onResourceStop']('outro_resource')
H.systemHandlers['onResourceStop']('coe_inventory')

print('inventory characterization (containers) tests passed')
