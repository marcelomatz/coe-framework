-- Controle de concorrência cooperativa por Striped Async Locks com ordenação lexicográfica anti-deadlock,
-- variáveis <close> (RAII), Session Generation Fencing, Orquestrador Saga e Write-Behind Coalescer.
local table_sort = table.sort

local Concurrency = {}

---@param yieldFn? fun(ms: integer) Função de espera cooperativa (Wait no FiveM ou coroutine.yield em testes offline)
---@param clockFn? fun(): integer Função de relógio em ms (GetGameTimer no FiveM ou relógio mockado)
---@return CoeStripedLockManager
function Concurrency.newLockManager(yieldFn, clockFn)
	local wait = yieldFn or (type(Wait) == 'function' and Wait) or function() end
	local now = clockFn or (type(GetGameTimer) == 'function' and GetGameTimer) or function()
		return math.floor(os.clock() * 1000)
	end

	local activeLocks = {}      -- key -> { token = int, owner = int, epoch = int, acquiredAt = int }
	local sessionEpochs = {}    -- source -> epoch integer (64-bit monotonic)
	local globalEpoch = 0

	local manager = {}

	local function resolveCurrentEpoch(source)
		if not source then
			return 0
		end
		if sessionEpochs[source] ~= nil then
			return sessionEpochs[source]
		end
		if type(Core) == 'table' and type(Core.SessionRegistry) == 'table' and type(Core.SessionRegistry.Get) == 'function' then
			local sess = Core.SessionRegistry.Get(source)
			if type(sess) == 'table' and type(sess.generation) == 'number' then
				return sess.generation
			end
		end
		return 0
	end

	function manager:registerSession(source)
		globalEpoch = globalEpoch + 1
		sessionEpochs[source] = globalEpoch
		return globalEpoch
	end

	function manager:dropSession(source)
		sessionEpochs[source] = nil
	end

	function manager:purgeOwner(source)
		sessionEpochs[source] = nil
		if not source then
			return
		end
		for key, lock in pairs(activeLocks) do
			if lock.owner == source then
				activeLocks[key] = nil
			end
		end
	end

	function manager:verifySession(source, expectedEpoch)
		if not source or not expectedEpoch or expectedEpoch == 0 then
			return true
		end
		if sessionEpochs[source] ~= nil then
			return sessionEpochs[source] == expectedEpoch
		end
		if type(Core) == 'table' and type(Core.SessionRegistry) == 'table' and type(Core.SessionRegistry.IsCurrent) == 'function' then
			return Core.SessionRegistry.IsCurrent(source, expectedEpoch) == true
		end
		return false
	end

	function manager:acquire(key, timeoutMs, ownerSource)
		local deadline = now() + (timeoutMs or 3000)
		local epoch = resolveCurrentEpoch(ownerSource)

		while activeLocks[key] ~= nil do
			if now() >= deadline then
				return nil, 'lock_timeout'
			end
			wait(0)
			if ownerSource and epoch > 0 and not self:verifySession(ownerSource, epoch) then
				return nil, 'session_expired_during_wait'
			end
		end

		globalEpoch = globalEpoch + 1
		local fenceToken = ((ownerSource or 0) << 32) | (globalEpoch & 0xFFFFFFFF)
		activeLocks[key] = {
			token = fenceToken,
			owner = ownerSource or 0,
			epoch = epoch,
			acquiredAt = now()
		}

		local released = false
		local guard = {
			ok = true,
			token = fenceToken,
			epoch = epoch,
			release = function()
				if not released then
					released = true
					local current = activeLocks[key]
					if current and current.token == fenceToken then
						activeLocks[key] = nil
					end
				end
			end
		}
		return setmetatable(guard, {
			__close = function(g)
				g.release()
			end
		}), nil
	end

	function manager:acquireMulti(keys, timeoutMs, ownerSource)
		local unique = {}
		local sorted = {}
		for i = 1, #keys do
			local k = keys[i]
			if k and not unique[k] then
				unique[k] = true
				sorted[#sorted + 1] = k
			end
		end
		table_sort(sorted)

		local acquiredGuards = {}
		for i = 1, #sorted do
			local g, err = self:acquire(sorted[i], timeoutMs, ownerSource)
			if not g then
				for j = #acquiredGuards, 1, -1 do
					acquiredGuards[j].release()
				end
				return nil, err
			end
			acquiredGuards[i] = g
		end

		local released = false
		local multiGuard = {
			ok = true,
			token = acquiredGuards[#acquiredGuards] and acquiredGuards[#acquiredGuards].token or 0,
			epoch = resolveCurrentEpoch(ownerSource),
			release = function()
				if not released then
					released = true
					for j = #acquiredGuards, 1, -1 do
						acquiredGuards[j].release()
					end
				end
			end
		}
		return setmetatable(multiGuard, {
			__close = function(g)
				g.release()
			end
		}), nil
	end

	return manager
end

--- Executor de Transações Distribuídas Saga (Fail-Closed com Rollback Reverso Determinístico)
function Concurrency.executeSaga(steps, context)
	local completed = {}
	for i = 1, #steps do
		local step = steps[i]
		local fn = step.action or step.forward
		local ok, resultOrErr, errCode = pcall(fn, context)
		if not ok or not resultOrErr then
			local reason = tostring((not ok and resultOrErr) or errCode or 'step_failed')
			for j = #completed, 1, -1 do
				local compStep = completed[j]
				if compStep.compensate then
					pcall(compStep.compensate, context, compStep.output)
				end
			end
			return false, step.name or ('step_' .. i), reason
		end
		completed[#completed + 1] = {
			name = step.name,
			compensate = step.compensate,
			output = resultOrErr
		}
	end
	return true, nil, nil
end

--- Coalescedor Write-Behind para mutações de alta frequência (SwapSlots / SplitItem / Quilometragem)
function Concurrency.newWriteBehindCoalescer(flushCallback)
	local dirtyMap = {}
	local dirtyList = {}

	return {
		markDirty = function(_, entityKey, statePatch)
			local existing = dirtyMap[entityKey]
			if not existing then
				dirtyMap[entityKey] = statePatch
				dirtyList[#dirtyList + 1] = entityKey
			else
				for k, v in pairs(statePatch) do
					existing[k] = v
				end
			end
		end,
		flush = function(_)
			local count = #dirtyList
			if count == 0 then
				return 0
			end
			local batch = {}
			for i = 1, count do
				local key = dirtyList[i]
				batch[i] = { key = key, data = dirtyMap[key] }
				dirtyMap[key] = nil
				dirtyList[i] = nil
			end
			flushCallback(batch, count)
			return count
		end,
		pendingCount = function(_)
			return #dirtyList
		end
	}
end

return Concurrency
