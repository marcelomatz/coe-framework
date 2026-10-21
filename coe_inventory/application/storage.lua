-- Serialização, persistência e carga de inventários.
local S = Inventory.Service

function S.getItemsWeight(items)
	local weight = 0
	for _, item in pairs(items) do
		weight = weight + item:getWeight()
	end
	return weight
end

function S.cloneTable(value)
	local ok, encoded = pcall(json.encode, value)
	if not ok or type(encoded) ~= 'string' then
		return nil
	end

	local decodedOk, copy = pcall(json.decode, encoded)
	if not decodedOk or type(copy) ~= 'table' then
		return nil
	end

	return copy
end

function S.serializeInventory(inventory)
	local stored = {
		id = inventory.id,
		slots = inventory.slots,
		maxWeight = inventory.maxWeight,
		starterItemsGranted = inventory.starterItemsGranted == true,
		items = {}
	}

	-- Só slots ocupados, com chave textual (objeto JSON): evita gravar false por slot vazio.
	for slot = 1, inventory.slots do
		local item = inventory.items[slot]
		if item then
			stored.items[tostring(slot)] = item:toStorage()
		end
	end

	local ok, encoded = pcall(json.encode, stored)
	if not ok or type(encoded) ~= 'string' then
		return nil, 'invalid_storage'
	end
	return encoded
end

-- Escrita síncrona: confirma no banco antes de devolver. Usada em tudo que cria, destrói ou
-- transfere itens (dupes/perdas não podem depender de um flush futuro).
S.dirtyInventories = {} -- id -> inventário com mudanças ainda não gravadas (write-behind)
S.syncWrites = {} -- id -> escritas síncronas em andamento (o flush não toca nesses ids)
S.persistStats = { flushes = 0, flushed = 0, failures = 0, lastMs = 0, maxMs = 0 }

local function beginSync(inventory)
	S.syncWrites[inventory.id] = (S.syncWrites[inventory.id] or 0) + 1
	return inventory.dirtySeq
end

local function endSync(inventory, seq, saved)
	local pending = (S.syncWrites[inventory.id] or 1) - 1
	S.syncWrites[inventory.id] = pending > 0 and pending or nil
	-- Só limpa o "sujo" se nada foi marcado enquanto a escrita aguardava o banco.
	if saved and inventory.dirtySeq == seq then
		S.dirtyInventories[inventory.id] = nil
	end
end

function S.persistInventory(inventory)
	local encoded, encodeError = S.serializeInventory(inventory)
	if not encoded then
		return false, encodeError
	end
	local seq = beginSync(inventory)
	local saved, saveError = Inventory.Persistence.Set(inventory.id, encoded)
	endSync(inventory, seq, saved)
	if not saved then
		return false, saveError or 'persistence_failed'
	end
	return saved
end

function S.persistInventories(...)
	local records = {}
	local inventories = { ... }
	for index = 1, select('#', ...) do
		local inventory = inventories[index]
		local encoded, encodeError = S.serializeInventory(inventory)
		if not encoded then
			return false, encodeError
		end
		records[#records + 1] = {
			key = inventory.id,
			value = encoded
		}
	end

	local seqs = {}
	for index, inventory in ipairs(inventories) do
		seqs[index] = beginSync(inventory)
	end
	local saved, saveError = Inventory.Persistence.SetMany(records)
	for index, inventory in ipairs(inventories) do
		endSync(inventory, seqs[index], saved)
	end
	return saved, saveError
end

-- Escrita adiada (write-behind): só para reorganizações (trocar/dividir slots), que não criam
-- nem destroem itens. Perder até `flushIntervalMs` numa queda apenas desfaz a organização.
-- Com `flushIntervalMs = 0` volta a gravar de forma síncrona.
function S.markInventoryDirty(inventory)
	if Config.Server.flushIntervalMs <= 0 then
		return S.persistInventory(inventory)
	end
	inventory.dirtySeq = (inventory.dirtySeq or 0) + 1
	S.dirtyInventories[inventory.id] = inventory
	return true
end

local flushing = false

-- Grava em lote (transações de até 64 registros) os inventários marcados. Falhas mantêm o
-- inventário sujo para a próxima rodada.
function S.flushInventories()
	if flushing then return 0 end
	flushing = true

	local pending = {}
	for id, inventory in pairs(S.dirtyInventories) do
		if not S.syncWrites[id] then
			local encoded = S.serializeInventory(inventory)
			if encoded then
				pending[#pending + 1] = {
					inventory = inventory,
					seq = inventory.dirtySeq,
					record = { key = id, value = encoded }
				}
			else
				S.log('error', 'persistence', 'inventory_flush_serialize_failed', { error_code = 'invalid_storage' })
			end
		end
	end

	local startedAt = GetGameTimer()
	local flushed = 0
	for first = 1, #pending, 64 do
		local records, chunk = {}, {}
		for index = first, math.min(first + 63, #pending) do
			chunk[#chunk + 1] = pending[index]
			records[#records + 1] = pending[index].record
		end
		local saved, saveError = Inventory.Persistence.SetMany(records)
		if saved then
			for _, entry in ipairs(chunk) do
				local id = entry.record.key
				if entry.inventory.dirtySeq == entry.seq and S.dirtyInventories[id] == entry.inventory then
					S.dirtyInventories[id] = nil
				end
			end
			flushed = flushed + #chunk
		else
			S.persistStats.failures = S.persistStats.failures + 1
			S.log('error', 'persistence', 'inventory_flush_failed', {
				count = #chunk,
				error_code = saveError or 'persistence_failed'
			})
		end
	end

	if #pending > 0 then
		local elapsed = GetGameTimer() - startedAt
		local stats = S.persistStats
		stats.flushes = stats.flushes + 1
		stats.flushed = stats.flushed + flushed
		stats.lastMs = elapsed
		stats.maxMs = math.max(stats.maxMs, elapsed)
		S.log('debug', 'persistence', 'inventory_flush', { count = flushed, duration_ms = elapsed })
	end
	flushing = false
	return flushed
end

-- Remove do cache inventários ociosos (a próxima consulta recarrega do banco). Nunca toca em
-- inventários com escrita pendente ou em andamento.
function S.evictIdleInventories()
	local ttl = Config.Server.cacheTtlMs
	if ttl <= 0 then return 0 end
	local now = GetGameTimer()
	local evicted = 0
	for id, inventory in pairs(S.inventories) do
		if not S.dirtyInventories[id] and not S.syncWrites[id]
			and now - (inventory.lastUsed or 0) > ttl then
			S.inventories[id] = nil
			evicted = evicted + 1
		end
	end
	S.persistStats.evicted = (S.persistStats.evicted or 0) + evicted
	return evicted
end

function S.getPersistenceStats()
	local dirty, cached = 0, 0
	for _ in pairs(S.dirtyInventories) do dirty = dirty + 1 end
	for _ in pairs(S.inventories) do cached = cached + 1 end
	local stats = S.persistStats
	return {
		dirty = dirty,
		cached = cached,
		evicted = S.persistStats.evicted or 0,
		flushes = stats.flushes,
		flushed = stats.flushed,
		failures = stats.failures,
		lastFlushMs = stats.lastMs,
		maxFlushMs = stats.maxMs
	}
end
function S.loadInventory(id)
	local cached = S.inventories[id]
	if cached then
		cached.lastUsed = GetGameTimer()
		return cached
	end

	local encoded, storageError = Inventory.Persistence.Get(id)
	if not encoded then
		if storageError then
			return nil, storageError
		end
		return nil, 'not_found'
	end

	local decodedOk, stored = pcall(json.decode, encoded)
	if not decodedOk or type(stored) ~= 'table'
		or stored.id ~= id
		or not S.isPositiveInteger(stored.slots)
		or stored.slots > Config.Server.maxSlots
		or (stored.maxWeight ~= nil and not S.isPositiveInteger(stored.maxWeight))
		or type(stored.items) ~= 'table' then
		return nil, 'invalid_storage'
	end

	local inventory = {
		id = id,
		slots = stored.slots,
		maxWeight = stored.maxWeight,
		starterItemsGranted = stored.starterItemsGranted == true,
		items = {}
	}

	for slot = 1, inventory.slots do
		-- Aceita o formato antigo (array com false) e o compacto (chaves textuais).
		local item = stored.items[slot]
		if item == nil then item = stored.items[tostring(slot)] end
		if item ~= nil and item ~= false then
			if type(item) ~= 'table'
				or type(item.name) ~= 'string'
				or item.name:match('^[%w_%-%.]+$') == nil
				or not S.isPositiveInteger(item.count)
				or type(item.metadata) ~= 'table' then
				return nil, 'invalid_storage'
			end

			local metadata = S.cloneTable(item.metadata)
			if not metadata then
				return nil, 'invalid_storage'
			end

			local itemObject, itemError = Inventory.Items.Create(item.name, item.count, metadata, slot)
			if not itemObject then
				return nil, itemError
			end

			inventory.items[slot] = itemObject
		end
	end

	inventory.lastUsed = GetGameTimer()
	S.inventories[id] = inventory
	return inventory
end

function S.getInventory(id)
	if not S.isValidId(id) then
		return nil, 'invalid_id'
	end

	return S.loadInventory(id)
end
