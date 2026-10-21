-- Maletas no mundo com vários jogadores: abertura simultânea, coleta concorrente, afastamento,
-- drop duplicado, entidade recriada e desconexão. O servidor é a única fonte de verdade.
local H = dofile([=[test/support/harness.lua]=])
local eq = H.assertEqual

for playerId = 1, 3 do H.activeCharacters[playerId] = 'char' .. playerId end
H.placePlayer(1, 0.0, 0.0, 0.0)
H.placePlayer(2, 1.0, 0.0, 0.0)
H.placePlayer(3, 40.0, 0.0, 0.0)

local function export(name) return assert(H.exported[name], 'export ausente: ' .. name) end
local function call(playerId, name, ...)
	H.as(playerId)
	return assert(H.networkHandlers[name], 'handler ausente: ' .. name)(...)
end
local function eventsTo(playerId, name)
	local found = {}
	for _, event in ipairs(H.sentClientEvents) do
		if event.target == playerId and event.name == name then found[#found + 1] = event end
	end
	return found
end
local function resultFor(playerId)
	local events = eventsTo(playerId, 'inventory.actionResult')
	local event = assert(events[#events], 'sem actionResult para ' .. playerId)
	return event.args[2], event.args[3]
end
local function countItem(inventoryId, name)
	local total = 0
	for _, item in pairs(export('GetInventory')(inventoryId).items) do
		if item and item.name == name then total = total + item.count end
	end
	return total
end
local function slotOf(inventoryId, name)
	for slot, item in pairs(export('GetInventory')(inventoryId).items) do
		if item and item.name == name then return slot end
	end
end

local inv = { export('GetPlayerInventory')(1), export('GetPlayerInventory')(2), export('GetPlayerInventory')(3) }
export('AddItem')(inv[1], 'water', 4)
export('AddItem')(inv[2], 'water', 4)

-- Solta uma maleta nova do jogador 1 em (1,0,0) e devolve containerId e netId.
local function dropCase(requestId)
	local _, slot = export('AddItem')(inv[1], 'paperbag', 1)
	local containerId = export('GetSlot')(inv[1], slot).metadata.containerId
	local _, netId = H.createWorldObject('prop_paper_bag_01', vector3(1.0, 0.0, 0.0), 1)
	call(1, 'inventory.containerDrop', requestId, containerId, netId, { x = 1.0, y = 0.0, z = 0.0 }, 0.0)
	return containerId, netId
end

-- Dois jogadores abrem a mesma maleta; o que um guarda aparece para o outro.
local containerId, netId = dropCase(1)
H.clearEvents()
call(1, 'inventory.containerWorldOpen', 10, netId)
call(2, 'inventory.containerWorldOpen', 11, netId)
eq((resultFor(1)), true, 'jogador 1 abre')
eq((resultFor(2)), true, 'jogador 2 abre')
H.clearEvents()
local water1 = slotOf(inv[1], 'water')
call(1, 'inventory.containerMove', 12, 'player', 'container-1', water1, 1)
eq((resultFor(1)), true, 'jogador 1 guarda água')
assert(#eventsTo(2, 'inventory.containerUpdated') >= 1, 'quem também tem a maleta aberta recebe a atualização')
eq(export('GetSlot')(containerId, 1).name, 'water', 'água na maleta')

-- Os dois tentam tirar o mesmo item: só um leva, nada é duplicado.
local before = countItem(inv[1], 'water') + countItem(inv[2], 'water') + export('GetSlot')(containerId, 1).count
call(1, 'inventory.containerMove', 13, 'container-1', 'player', 1, 30)
call(2, 'inventory.containerMove', 14, 'container-1', 'player', 1, 30)
eq((resultFor(1)), true, 'primeiro leva o item')
eq(select(2, resultFor(2)), 'empty_slot', 'segundo não encontra o item')
eq(countItem(inv[1], 'water') + countItem(inv[2], 'water') + (export('GetSlot')(containerId, 1) and 1 or 0) * 0,
	before, 'total de itens se conserva')

-- Coleta concorrente: o primeiro leva a maleta, o segundo é recusado e seu painel fecha.
H.clearEvents()
call(1, 'inventory.containerWorldPickup', 20, netId)
call(2, 'inventory.containerWorldPickup', 21, netId)
eq((resultFor(1)), true, 'primeiro recolhe')
eq(select(2, resultFor(2)), 'invalid_target', 'segundo é recusado')
eq(countItem(inv[1], 'paperbag') + countItem(inv[2], 'paperbag'), 1, 'a maleta existe uma única vez')
assert(#eventsTo(2, 'inventory.containerClosed') >= 1, 'painel do segundo jogador foi fechado')
call(2, 'inventory.containerMove', 22, 'container-1', 'player', 1, 30)
eq(select(2, resultFor(2)), 'container_not_open', 'sem painel não mexe no conteúdo')
eq(Inventory.Service.getWorldContainerByNetId(netId), nil, 'maleta saiu do mundo')

-- Drop duplicado do mesmo containerId com outra entidade é recusado.
local bagSlot = slotOf(inv[1], 'paperbag')
local dupId = export('GetSlot')(inv[1], bagSlot).metadata.containerId
local _, netA = H.createWorldObject('prop_paper_bag_01', vector3(1.0, 0.0, 0.0), 1)
local _, netB = H.createWorldObject('prop_paper_bag_01', vector3(1.0, 0.0, 0.0), 1)
call(1, 'inventory.containerDrop', 30, dupId, netA, { x = 1.0, y = 0.0, z = 0.0 }, 0.0)
call(1, 'inventory.containerDrop', 31, dupId, netB, { x = 1.0, y = 0.0, z = 0.0 }, 0.0)
local drops = eventsTo(1, 'inventory.containerDropResult')
eq(drops[#drops - 1].args[2], true, 'primeiro drop vale')
eq(drops[#drops].args[2], false, 'segundo drop do mesmo container é recusado')
local worldCount = 0
for _, container in pairs(Inventory.Service.worldContainers) do
	if container.containerId == dupId then worldCount = worldCount + 1 end
end
eq(worldCount, 1, 'um único container no mundo')

-- Afastar-se fecha o painel: abrir não dá acesso permanente.
H.clearEvents()
call(2, 'inventory.containerWorldOpen', 40, netA)
eq((resultFor(2)), true, 'abre perto')
H.placePlayer(2, 30.0, 0.0, 0.0)
call(2, 'inventory.containerMove', 41, 'player', 'container-1', slotOf(inv[2], 'water'), 1)
eq(select(2, resultFor(2)), 'container_not_open', 'longe não mexe no conteúdo')
assert(#eventsTo(2, 'inventory.containerClosed') >= 1, 'painel fechado ao se afastar')
H.placePlayer(2, 1.0, 0.0, 0.0)

-- Entidade que sumiu e foi recriada ganha novo netId; o antigo deixa de valer.
local world = Inventory.Service.getWorldContainerByNetId(netA)
DeleteEntity(world.entity)
Inventory.Service.syncWorldContainers()
call(2, 'inventory.containerWorldOpen', 50, netA)
eq(select(2, resultFor(2)), 'invalid_target', 'netId antigo é recusado')
local respawned = Inventory.Service.worldContainers[dupId]
assert(respawned and respawned.netId ~= netA, 'maleta recriada com novo netId')
call(2, 'inventory.containerWorldOpen', 51, respawned.netId)
eq((resultFor(2)), true, 'abre pelo novo netId')

-- Desconexão com a maleta aberta não deixa painel pendurado.
call(3, 'inventory.containerWorldOpen', 60, respawned.netId)
eq(select(2, resultFor(3)), 'invalid_target', 'jogador longe não abre')
H.placePlayer(3, 1.5, 0.0, 0.0)
call(3, 'inventory.containerWorldOpen', 61, respawned.netId)
eq((resultFor(3)), true, 'jogador 3 abre')
assert(Inventory.Service.openedContainers[3], 'painel registrado')
H.as(3)
H.systemHandlers['playerDropped']()
eq(Inventory.Service.openedContainers[3], nil, 'desconexão limpa o painel')

print('world concurrency tests passed')
