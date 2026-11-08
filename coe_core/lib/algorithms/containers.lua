-- Estruturas de dados Zero-GC e escalonamento temporal em Lua 5.4 puro:
-- RingBuffer Circular, LRU Cache Intrusivo em Arrays Paralelos, Binary Min-Heap Indexada e Hashed Timing Wheel O(1).
local Containers = {}

--- 1. RingBuffer Circular Zero-GC
---@generic T
---@param capacity integer
---@return CoeRingBuffer<T>
function Containers.newRingBuffer(capacity)
	assert(capacity and capacity > 0, 'Capacidade deve ser positiva')
	local storage = {}
	for i = 1, capacity do
		storage[i] = false
	end
	return {
		capacity = capacity,
		size = 0,
		head = 1,
		tail = 1,
		storage = storage,
		push = function(self, item)
			local overwritten = nil
			if self.size == self.capacity then
				overwritten = self.storage[self.head]
				self.head = (self.head % self.capacity) + 1
			else
				self.size = self.size + 1
			end
			self.storage[self.tail] = item
			self.tail = (self.tail % self.capacity) + 1
			return overwritten
		end,
		pop = function(self)
			if self.size == 0 then
				return nil
			end
			local item = self.storage[self.head]
			self.storage[self.head] = false
			self.head = (self.head % self.capacity) + 1
			self.size = self.size - 1
			return item
		end,
		peekNewest = function(self, offset)
			local off = offset or 0
			if off >= self.size then
				return nil
			end
			local idx = ((self.tail - 2 - off) % self.capacity) + 1
			return self.storage[idx]
		end,
		peekOldest = function(self)
			if self.size == 0 then
				return nil
			end
			return self.storage[self.head]
		end,
		toArray = function(self, out)
			local res = out or {}
			for i = #res, self.size + 1, -1 do
				res[i] = nil
			end
			for i = 1, self.size do
				local idx = ((self.head + i - 2) % self.capacity) + 1
				res[i] = self.storage[idx]
			end
			return res
		end,
		clear = function(self)
			for i = 1, self.capacity do
				self.storage[i] = false
			end
			self.size, self.head, self.tail = 0, 1, 1
		end
	}
end

--- 2. LRU Cache Intrusivo em Arrays Paralelos (Zero Alocação de Nós)
---@generic K, V
---@param capacity integer
---@return CoeLRUCache<K, V>
function Containers.newLRUCache(capacity)
	assert(capacity and capacity >= 2, 'Capacidade do LRU deve ser >= 2')
	local keys, vals, exp = {}, {}, {}
	local prev, nxt = {}, {}
	local freeList = {}
	for i = 1, capacity do
		freeList[i] = capacity - i + 1
	end

	local cache = {
		capacity = capacity,
		size = 0,
		head = 0,
		tail = 0,
		freeTop = capacity,
		freeList = freeList,
		keyToIdx = {},
		keys = keys,
		vals = vals,
		exp = exp,
		prev = prev,
		nxt = nxt
	}

	local function detach(self, idx)
		local p, n = self.prev[idx], self.nxt[idx]
		if p ~= 0 then
			self.nxt[p] = n
		else
			self.head = n
		end
		if n ~= 0 then
			self.prev[n] = p
		else
			self.tail = p
		end
		self.prev[idx], self.nxt[idx] = 0, 0
	end

	local function attachFront(self, idx)
		self.prev[idx] = 0
		self.nxt[idx] = self.head
		if self.head ~= 0 then
			self.prev[self.head] = idx
		end
		self.head = idx
		if self.tail == 0 then
			self.tail = idx
		end
	end

	function cache:invalidate(key)
		local idx = self.keyToIdx[key]
		if not idx then
			return false
		end
		detach(self, idx)
		self.keyToIdx[key] = nil
		self.keys[idx], self.vals[idx], self.exp[idx] = false, false, 0
		self.freeTop = self.freeTop + 1
		self.freeList[self.freeTop] = idx
		self.size = self.size - 1
		return true
	end

	function cache:get(key, nowMs)
		local idx = self.keyToIdx[key]
		if not idx then
			return nil
		end
		local e = self.exp[idx]
		if e > 0 and nowMs and nowMs >= e then
			self:invalidate(key)
			return nil
		end
		if idx ~= self.head then
			detach(self, idx)
			attachFront(self, idx)
		end
		return self.vals[idx]
	end

	function cache:put(key, value, ttlMs, nowMs)
		local idx = self.keyToIdx[key]
		local expiry = (ttlMs and nowMs) and (nowMs + ttlMs) or 0
		if idx then
			self.vals[idx] = value
			self.exp[idx] = expiry
			if idx ~= self.head then
				detach(self, idx)
				attachFront(self, idx)
			end
			return nil, nil
		end

		local evictedKey, evictedVal = nil, nil
		if self.freeTop == 0 then
			local victim = self.tail
			evictedKey, evictedVal = self.keys[victim], self.vals[victim]
			self:invalidate(evictedKey)
		end

		local newIdx = self.freeList[self.freeTop]
		self.freeTop = self.freeTop - 1
		self.keys[newIdx] = key
		self.vals[newIdx] = value
		self.exp[newIdx] = expiry
		self.keyToIdx[key] = newIdx
		attachFront(self, newIdx)
		self.size = self.size + 1
		return evictedKey, evictedVal
	end

	return cache
end

--- 3. Binary Min-Heap Indexada (O(log N) Push, Pop, UpdatePriority e Remove)
---@generic K
---@return CoeMinHeap<K>
function Containers.newMinHeap()
	local ids, prios, payloads, pos = {}, {}, {}, {}
	local n = 0

	local function swap(i, j)
		local idI, idJ = ids[i], ids[j]
		ids[i], ids[j] = idJ, idI
		prios[i], prios[j] = prios[j], prios[i]
		payloads[i], payloads[j] = payloads[j], payloads[i]
		pos[idI], pos[idJ] = j, i
	end

	local function siftUp(idx)
		while idx > 1 do
			local parent = idx >> 1
			if prios[idx] < prios[parent] then
				swap(idx, parent)
				idx = parent
			else
				break
			end
		end
	end

	local function siftDown(idx)
		while true do
			local left = idx << 1
			local right = left + 1
			local smallest = idx
			if left <= n and prios[left] < prios[smallest] then
				smallest = left
			end
			if right <= n and prios[right] < prios[smallest] then
				smallest = right
			end
			if smallest ~= idx then
				swap(idx, smallest)
				idx = smallest
			else
				break
			end
		end
	end

	local heap = {}
	function heap:size()
		return n
	end

	function heap:push(id, priority, payload)
		local existing = pos[id]
		if existing then
			local oldPrio = prios[existing]
			prios[existing] = priority
			if payload ~= nil then
				payloads[existing] = payload
			end
			if priority < oldPrio then
				siftUp(existing)
			else
				siftDown(existing)
			end
			return
		end
		n = n + 1
		ids[n], prios[n], payloads[n] = id, priority, payload or false
		pos[id] = n
		siftUp(n)
	end

	function heap:pop()
		if n == 0 then
			return nil, nil, nil
		end
		local topId, topPrio, topPayload = ids[1], prios[1], payloads[1]
		pos[topId] = nil
		if n == 1 then
			ids[1], prios[1], payloads[1] = nil, nil, nil
			n = 0
		else
			ids[1], prios[1], payloads[1] = ids[n], prios[n], payloads[n]
			pos[ids[1]] = 1
			ids[n], prios[n], payloads[n] = nil, nil, nil
			n = n - 1
			siftDown(1)
		end
		return topId, topPrio, (topPayload ~= false and topPayload or nil)
	end

	function heap:peek()
		if n == 0 then
			return nil, nil, nil
		end
		return ids[1], prios[1], (payloads[1] ~= false and payloads[1] or nil)
	end

	function heap:remove(id)
		local idx = pos[id]
		if not idx then
			return false
		end
		pos[id] = nil
		if idx == n then
			ids[n], prios[n], payloads[n] = nil, nil, nil
			n = n - 1
			return true
		end
		local lastPrio = prios[n]
		local removedPrio = prios[idx]
		ids[idx], prios[idx], payloads[idx] = ids[n], lastPrio, payloads[n]
		pos[ids[idx]] = idx
		ids[n], prios[n], payloads[n] = nil, nil, nil
		n = n - 1
		if lastPrio < removedPrio then
			siftUp(idx)
		else
			siftDown(idx)
		end
		return true
	end

	return heap
end

--- 4. Hashed Timing Wheel O(1) (256 Slots, Máscara Bitwise)
---@param tickIntervalMs? integer
---@param defaultCallback? fun(id: any, payload: any)
function Containers.newTimingWheel(tickIntervalMs, defaultCallback)
	local MASK = 255
	local slots = {}
	for i = 0, MASK do
		slots[i] = {}
	end

	return {
		tickIntervalMs = tickIntervalMs or 100,
		defaultCallback = defaultCallback,
		currentSlot = 0,
		slots = slots,
		timers = {},
		schedule = function(self, id, delayMs, callback, payload)
			self:cancel(id)
			local cb = type(callback) == 'function' and callback or self.defaultCallback
			local data = type(callback) == 'function' and payload or callback
			local ticks = math.max(1, math.ceil(delayMs / self.tickIntervalMs))
			local rounds = (ticks - 1) >> 8
			local targetSlot = (self.currentSlot + ticks) & MASK
			local bucket = self.slots[targetSlot]
			local idx = #bucket + 1
			local entry = {
				id = id,
				slot = targetSlot,
				slotIdx = idx,
				rounds = rounds,
				cb = cb,
				payload = data
			}
			bucket[idx] = entry
			self.timers[id] = entry
			return true
		end,
		cancel = function(self, id)
			local entry = self.timers[id]
			if not entry then
				return false
			end
			local bucket = self.slots[entry.slot]
			local n = #bucket
			local idx = entry.slotIdx
			local last = bucket[n]
			bucket[n] = nil
			if idx < n and last then
				bucket[idx] = last
				last.slotIdx = idx
			end
			self.timers[id] = nil
			return true
		end,
		advanceTick = function(self)
			self.currentSlot = (self.currentSlot + 1) & MASK
			local bucket = self.slots[self.currentSlot]
			local i = 1
			while i <= #bucket do
				local entry = bucket[i]
				if entry.rounds > 0 then
					entry.rounds = entry.rounds - 1
					i = i + 1
				else
					self:cancel(entry.id)
					entry.cb(entry.id, entry.payload)
				end
			end
		end,
		tick = function(self)
			return self:advanceTick()
		end
	}
end

return Containers
