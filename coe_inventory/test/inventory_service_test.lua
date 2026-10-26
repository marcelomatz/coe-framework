dofile([=[../coe_core/core/shared/bootstrap.lua]=])
dofile([=[../coe_core/core/shared/functions.lua]=])
dofile([=[../coe_core/core/shared/classes.lua]=])

local jsonRecords = {}
local jsonSequence = 0
json = {
	encode = function(value)
		jsonSequence = jsonSequence + 1
		local key = 'record:' .. jsonSequence
		jsonRecords[key] = Core.Functions.DeepCopy(value)
		return key
	end,
	decode = function(key)
		if not jsonRecords[key] then
			error('invalid test JSON record')
		end
		return Core.Functions.DeepCopy(jsonRecords[key])
	end
}

dofile([=[../coe_core/lib/logger.lua]=])
dofile([=[domain/items.lua]=])
dofile([=[config.lua]=])
dofile([=[domain/config_schema.lua]=])
dofile([=[data/coe_animations.lua]=])
dofile([=[data/coe_weapon_profiles.lua]=])
dofile([=[data/coe_base_items.lua]=])
dofile([=[data/coe_catalog.lua]=])
dofile([=[data/coe_weapons.lua]=])
dofile([=[data/coe_ammo.lua]=])
dofile([=[data/coe_attachments.lua]=])
dofile([=[data/coe_food.lua]=])
dofile([=[data/coe_consumables.lua]=])
dofile([=[data/coe_containers.lua]=])
dofile([=[data/coe_misc.lua]=])
dofile([=[data/coe_parts.lua]=])
dofile([=[data/coe_ingredients.lua]=])
dofile([=[data/coe_shop_items.lua]=])

local storage = {
	['inventory:player:license:legacy'] = 'untouched legacy value'
}
local failNextSet = false
local failNextSetMany = false
Inventory.Persistence = {
	Get = function(key)
		return storage[key]
	end,
	Set = function(key, value)
		if failNextSet then
			failNextSet = false
			return false
		end
		storage[key] = value
		return true
	end,
	SetMany = function(records)
		if failNextSetMany then
			failNextSetMany = false
			return false, 'transaction_failed'
		end
		for _, record in ipairs(records) do
			storage[record.key] = record.value
		end
		return true
	end,
	Delete = function(key)
		storage[key] = nil
		return true
	end
}

local activeCharacters = {}
local networkHandlers = {}
local localHandlers = {}
local sentClientEvents = {}
local timer = 0
local handlerSequence = 0
local exported = {}

Core.Players = {
	GetActiveCharacterId = function(playerSource)
		local characterId = activeCharacters[playerSource]
		if not characterId then
			return nil, 'character_not_loaded'
		end
		return characterId
	end
}
Core.SessionRegistry = {
	Get = function()
		return nil
	end
}
Core.Events = {
	OnNet = function(name, callback)
		networkHandlers[name] = callback
		return callback
	end,
	On = function(name, callback)
		localHandlers[name] = callback
		return callback
	end,
	ToClient = function(target, name, ...)
		sentClientEvents[#sentClientEvents + 1] = {
			target = target,
			name = name,
			args = { ... }
		}
		return true
	end,
	ToAll = function()
		return true
	end,
	Emit = function()
		return true
	end
}

exports = setmetatable({
	coe_logging = {
		Log = function()
			return true
		end
	}
}, {
	__call = function(_, name, callback)
		exported[name] = callback
	end
})

function GetGameTimer()
	timer = timer + 400
	return timer
end

function GetPlayerName()
	return 'Test player'
end

function GetPlayerPed(playerId)
	return playerId
end

function GetEntityCoords(playerId)
	return setmetatable({ playerId = playerId }, {
		__sub = function()
			return setmetatable({}, {
				__len = function()
					return 1.0
				end
			})
		end
	})
end

function RegisterCommand() end
function AddEventHandler()
	handlerSequence = handlerSequence + 1
	return handlerSequence
end

function CreateThread()
	handlerSequence = handlerSequence + 1
	return handlerSequence
end

function SetTimeout() end

for _, file in ipairs({
	'state', 'storage', 'world_containers', 'opened_containers', 'inventory_ops', 'stashes',
	'player_inventory', 'action_guard', 'handlers_inventory', 'handlers_containers', 'lifecycle'
}) do
	dofile('application/' .. file .. '.lua')
end

local function assertEqual(actual, expected, message)
	if actual ~= expected then
		error(('%s: expected %s, got %s'):format(message, tostring(expected), tostring(actual)))
	end
end

local function lastClientEvent(name)
	for index = #sentClientEvents, 1, -1 do
		if sentClientEvents[index].name == name then
			return sentClientEvents[index]
		end
	end
end

local inventoryId, inventoryError = exported.GetPlayerInventory(42)
assertEqual(inventoryId, nil, 'inventory is unavailable before character selection')
assertEqual(inventoryError, 'character_not_loaded', 'missing character error')
assertEqual(storage['inventory:player:license:legacy'], 'untouched legacy value', 'legacy data remains untouched')

activeCharacters[42] = '71'
local inventory
inventoryId, inventory = exported.GetPlayerInventory(42)
assertEqual(inventoryId, 'character:71', 'inventory is keyed by active character')
assertEqual(inventory.id, 'character:71', 'snapshot uses character key')
assertEqual(exported.GetItemCount(inventoryId, 'water'), 3, 'starter items granted')
assertEqual(storage['inventory:player:license:legacy'], 'untouched legacy value', 'legacy data is not associated')

local added, waterSlot = exported.AddItem(inventoryId, 'water', 3)
assertEqual(added, true, 'add stackable items')
assertEqual(exported.GetItemCount(inventoryId, 'water'), 6, 'matching items stack')

local metadataAdded, metadataSlot = exported.AddItem(inventoryId, 'water', 1, { quality = 80 })
assertEqual(metadataAdded, true, 'add item with metadata')
assertEqual(metadataSlot ~= waterSlot, true, 'different metadata uses another slot')
assertEqual(exported.GetItemCount(inventoryId, 'water', { quality = 80 }), 1, 'metadata filters item counts')

local split, splitSlot = exported.SplitItem(inventoryId, waterSlot, 2)
assertEqual(split, true, 'split item stack')
assertEqual(splitSlot ~= waterSlot, true, 'split uses an empty slot')
assertEqual(exported.GetItemCount(inventoryId, 'water'), 7, 'split preserves total count')

for _, badCount in ipairs({ 0, -1, 1.5, 1e9, '2', true }) do
	local ok = exported.SplitItem(inventoryId, waterSlot, badCount)
	assertEqual(ok, false, 'split rejects count ' .. tostring(badCount))
end
assertEqual(exported.GetItemCount(inventoryId, 'water'), 7, 'rejected splits do not change totals')

local beforeFailedWrite = exported.GetItemCount(inventoryId, 'water')
failNextSet = true
local failedAdd, persistenceError = exported.AddItem(inventoryId, 'water', 1)
assertEqual(failedAdd, false, 'failed persistence rejects the change')
assertEqual(persistenceError, 'persistence_failed', 'persistence failure is explicit')
assertEqual(exported.GetItemCount(inventoryId, 'water'), beforeFailedWrite, 'failed write restores in-memory state')

activeCharacters[42] = '72'
local secondInventoryId, secondInventory = exported.GetPlayerInventory(42)
assertEqual(secondInventoryId, 'character:72', 'switching characters changes inventory identity')
assertEqual(secondInventory.id, 'character:72', 'second character has separate inventory')
assertEqual(exported.GetItemCount(secondInventoryId, 'water'), 3, 'second character gets independent starter items')
assertEqual(exported.GetItemCount('character:71', 'water'), beforeFailedWrite, 'first character inventory is unchanged')

activeCharacters[43] = '73'
local otherInventoryId = exported.GetPlayerInventory(43)
assertEqual(otherInventoryId, 'character:73', 'second player inventory is keyed by its character')
local sourceCountBeforeTransfer = exported.GetItemCount('character:71', 'water')
local targetCountBeforeTransfer = exported.GetItemCount('character:73', 'water')

activeCharacters[42] = '71'
source = 42
networkHandlers['inventory.give'](200, 43, waterSlot, 1)
local transferResult = lastClientEvent('inventory.actionResult')
assertEqual(transferResult ~= nil, true, 'give returns action result')
assertEqual(transferResult.args[2], true, 'give succeeds')
assertEqual(exported.GetItemCount('character:71', 'water'), sourceCountBeforeTransfer - 1, 'give removes from source')
assertEqual(exported.GetItemCount('character:73', 'water'), targetCountBeforeTransfer + 1, 'give adds to target')

sourceCountBeforeTransfer = exported.GetItemCount('character:71', 'water')
targetCountBeforeTransfer = exported.GetItemCount('character:73', 'water')
failNextSetMany = true
networkHandlers['inventory.give'](201, 43, waterSlot, 1)
transferResult = lastClientEvent('inventory.actionResult')
assertEqual(transferResult.args[2], false, 'failed transfer is rejected')
assertEqual(transferResult.args[3], 'transaction_failed', 'transaction error reaches caller')
assertEqual(exported.GetItemCount('character:71', 'water'), sourceCountBeforeTransfer, 'failed transfer restores source state')
assertEqual(exported.GetItemCount('character:73', 'water'), targetCountBeforeTransfer, 'failed transfer restores target state')

for index, badCount in ipairs({ 0, -1, 1.5, 1e9, '1', false, 1 / 0 }) do
	networkHandlers['inventory.give'](300 + index, 43, waterSlot, badCount)
	transferResult = lastClientEvent('inventory.actionResult')
	assertEqual(transferResult.args[2], false, 'give rejects count ' .. tostring(badCount))
	assertEqual(transferResult.args[3] ~= 'rate_limited', true, 'give count check is not masked by rate limit')
end
assertEqual(exported.GetItemCount('character:71', 'water'), sourceCountBeforeTransfer, 'rejected gives keep source')
assertEqual(exported.GetItemCount('character:73', 'water'), targetCountBeforeTransfer, 'rejected gives keep target')

activeCharacters[42] = nil
networkHandlers['inventory.request'](99)
assertEqual(sentClientEvents[#sentClientEvents].name, 'inventory.response', 'inventory request always responds')
assertEqual(sentClientEvents[#sentClientEvents].args[3], 'character_not_loaded', 'network request rejects no active character')

activeCharacters[42] = '71'
networkHandlers['inventory.request'](100)
assertEqual(sentClientEvents[#sentClientEvents].args[2].id, 'character:71', 'network request loads active character inventory')

-- Write-behind: trocar/dividir slots só marca o inventário como sujo; o flush grava em lote.
do
	local S = Inventory.Service
	local id = 'character:71'
	local occupied
	for slot, item in ipairs(exported.GetInventory(id).items) do
		if item then occupied = slot break end
	end
	assert(occupied, 'inventário de teste tem item')
	local before = storage[id]
	local movedTo = 25
	assertEqual(exported.SwapSlots(id, occupied, movedTo), true, 'swap diferido')
	assertEqual(storage[id], before, 'swap não grava na hora')
	assertEqual(exported.GetPersistenceStats().dirty, 1, 'inventário marcado como sujo')
	assertEqual(exported.GetSlot(id, movedTo) ~= nil, true, 'estado em memória já reflete o swap')

	assertEqual(S.flushInventories(), 1, 'flush grava o inventário sujo')
	assertEqual(storage[id] ~= before, true, 'flush persistiu a troca')
	assertEqual(exported.GetPersistenceStats().dirty, 0, 'nada pendente após o flush')
	S.inventories[id] = nil
	assertEqual(exported.GetSlot(id, movedTo) ~= nil, true, 'estado recarregado do banco mantém a troca')

	-- Escrita síncrona posterior leva junto a troca pendente e limpa o estado sujo.
	exported.SwapSlots(id, movedTo, occupied)
	assertEqual(exported.AddItem(id, 'water', 1), true, 'escrita síncrona')
	assertEqual(exported.GetPersistenceStats().dirty, 0, 'escrita síncrona limpa o sujo')

	-- Falha no flush mantém o inventário sujo para a próxima rodada.
	exported.SwapSlots(id, occupied, movedTo)
	failNextSetMany = true
	assertEqual(S.flushInventories(), 0, 'flush com falha não conta gravados')
	assertEqual(exported.GetPersistenceStats().dirty, 1, 'falha mantém sujo')
	assertEqual(exported.GetPersistenceStats().failures, 1, 'falha contabilizada')
	assertEqual(S.flushInventories(), 1, 'nova rodada grava')

	-- flushIntervalMs = 0 volta a gravar na hora.
	local original = Config.Server.flushIntervalMs
	Config.Server.flushIntervalMs = 0
	local previous = storage[id]
	exported.SwapSlots(id, movedTo, occupied)
	assertEqual(storage[id] ~= previous, true, 'intervalo 0 grava sincronamente')
	assertEqual(exported.GetPersistenceStats().dirty, 0, 'intervalo 0 não deixa sujo')
	Config.Server.flushIntervalMs = original
end

-- Teste de suporte a formatos modernos de imagem (.webp, .png, .svg)
do
	local itemWebp, errWebp = Inventory.Items.Register('test_format_webp', {
		label = 'Item WebP',
		image = 'test_item.webp'
	})
	assertEqual(itemWebp ~= nil, true, 'registro com imagem .webp')
	assertEqual(itemWebp.image, 'test_item.webp', 'item preserva nome .webp')

	local itemSvg, errSvg = Inventory.Items.Register('test_format_svg', {
		label = 'Item SVG',
		image = 'test_icon.svg'
	})
	assertEqual(itemSvg ~= nil, true, 'registro com imagem .svg')
	assertEqual(itemSvg.image, 'test_icon.svg', 'item preserva nome .svg')

	local itemBmp, errBmp = Inventory.Items.Register('test_format_bmp', {
		label = 'Item BMP',
		image = 'test_item.bmp'
	})
	assertEqual(itemBmp, nil, 'recusa formatos não suportados (.bmp)')
	assertEqual(errBmp, 'invalid_item_image', 'erro correto para formato não suportado')
end

print('inventory service tests passed')
