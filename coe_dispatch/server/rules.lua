DispatchRules = {}

local function finite(value)
	return type(value) == 'number' and value == value and value > -1e6 and value < 1e6
end

-- Definição do código ou nil, codigo. citizenOnly restringe aos códigos abertos ao cidadão.
function DispatchRules.Code(config, code, citizenOnly)
	local definition = type(code) == 'string' and config.Codes[code] or nil
	if not definition or not config.Categories[definition.category] then
		return nil, 'invalid_code'
	end
	if citizenOnly and definition.citizen ~= true then
		return nil, 'invalid_code'
	end
	return definition
end

function DispatchRules.Coords(x, y, z)
	if not (finite(x) and finite(y) and finite(z)) then
		return nil, 'invalid_coords'
	end
	return { x = x + 0.0, y = y + 0.0, z = z + 0.0 }
end

function DispatchRules.Distance(a, b)
	local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

-- Cria índice espacial O(1) para deduplicação de chamados próximos
function DispatchRules.NewSpatialIndex(cellSize)
	local alg = (type(Core) == 'table' and Core.Algorithms) or CoeAlgorithms
	local Spatial = alg and alg.Spatial or nil
	if Spatial and Spatial.newGrid then
		return Spatial.newGrid(cellSize or 120.0)
	end
	return nil
end

-- Cria Hierarchical Timing Wheel O(1) para expiração de chamados
function DispatchRules.NewTtlWheel(tickIntervalMs, onExpire)
	local alg = (type(Core) == 'table' and Core.Algorithms) or CoeAlgorithms
	local Containers = alg and alg.Containers or nil
	if Containers and Containers.newTimingWheel then
		return Containers.newTimingWheel(tickIntervalMs or 1000, onExpire)
	end
	return nil
end

-- Chamado aberto igual e recente por perto (para somar relatos em vez de duplicar).
-- Se spatialGrid for fornecido, faz consulta espacial O(1) nas células vizinhas.
function DispatchRules.Duplicate(calls, code, coords, now, config, spatialGrid)
	if spatialGrid and spatialGrid.queryRadius then
		local out, count = spatialGrid:queryRadius(coords.x, coords.y, coords.z, config.DedupeRadius, 0)
		for i = 1, count do
			local entry = out[i]
			local callId = entry and (entry.payload and entry.payload.id or entry.id)
			local call = callId and calls[callId]
			if call and call.code == code and now - call.createdAt <= config.DedupeSeconds then
				return call
			end
		end
		return nil
	end
	for _, call in pairs(calls) do
		if call.code == code
			and now - call.createdAt <= config.DedupeSeconds
			and DispatchRules.Distance(call, coords) <= config.DedupeRadius then
			return call
		end
	end
	return nil
end

-- Remove chamados vencidos e retorna a lista de ids removidos.
function DispatchRules.Prune(calls, now, config)
	local removed = {}
	for id, call in pairs(calls) do
		if now - call.createdAt > config.TtlSeconds then
			removed[#removed + 1] = id
		end
	end
	table.sort(removed)
	for _, id in ipairs(removed) do
		calls[id] = nil
	end
	return removed
end

function DispatchRules.CountActive(calls, category)
	local total = 0
	for _, call in pairs(calls) do
		if call.category == category then
			total = total + 1
		end
	end
	return total
end

-- Cooldown do cidadão: true quando já pode abrir outro chamado.
function DispatchRules.CooldownReady(lastAt, now, config)
	return lastAt == nil or now - lastAt >= config.CitizenCooldownSeconds
end

-- Ordena por urgência e, a igualdade, pelo mais recente via Binary Min-Heap O(N log N).
function DispatchRules.Sorted(calls, category)
	local alg = (type(Core) == 'table' and Core.Algorithms) or CoeAlgorithms
	local Containers = (type(alg) == 'table' and alg.Containers) or nil
	if Containers and Containers.newMinHeap then
		local heap = Containers.newMinHeap(64)
		for _, call in pairs(calls) do
			if call.category == category then
				local compositeKey = (call.priority * 1000000000) - (call.id or 0)
				heap:push(call.id, compositeKey, call)
			end
		end
		local list = {}
		while heap:size() > 0 do
			local _, _, call = heap:pop()
			list[#list + 1] = call
		end
		return list
	end
	local list = {}
	for _, call in pairs(calls) do
		if call.category == category then
			list[#list + 1] = call
		end
	end
	table.sort(list, function(a, b)
		if a.priority ~= b.priority then
			return a.priority < b.priority
		end
		return a.id > b.id
	end)
	return list
end

function DispatchRules.CallId(value)
	if type(value) ~= 'number' or value ~= value or value % 1 ~= 0 or value < 1 then
		return nil, 'invalid_call'
	end
	return math.tointeger(value)
end
