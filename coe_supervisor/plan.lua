-- Plano de reinício: o alvo e todos os resources iniciados que dependem dele (direta ou
-- indiretamente) são parados dos dependentes para a base e iniciados da base para os dependentes.
SupervisorPlan = {}

local function dependenciesOf(graph, name)
	local result = {}
	for _, dependency in ipairs(graph[name].dependencies or {}) do
		if graph[dependency] then
			result[#result + 1] = dependency
		end
	end
	return result
end

-- Categoria e criticidade de um resource; resources fora do catalogo viram 'other'.
function SupervisorPlan.Meta(name, catalog, restartSize, threshold)
	local entry = catalog and catalog[name] or {}
	local critical = entry.critical == true or (threshold ~= nil and (restartSize or 0) >= threshold)
	return entry.category or 'other', critical
end

-- graph = { [nome] = { state = 'started', dependencies = { nomes... } } }
-- managed = lista ordenada de nomes gerenciados (usada para desempate e validação).
function SupervisorPlan.Build(target, graph, managed)
	local order = {}
	for index, name in ipairs(managed) do
		order[name] = index
	end
	if type(target) ~= 'string' or not order[target] or not graph[target] then
		return nil, 'resource_not_managed'
	end

	local affected = { [target] = true }
	local changed = true
	while changed do
		changed = false
		for name, node in pairs(graph) do
			if not affected[name] and node.state == 'started' then
				for _, dependency in ipairs(dependenciesOf(graph, name)) do
					if affected[dependency] then
						affected[name] = true
						changed = true
						break
					end
				end
			end
		end
	end

	local function rank(name)
		return order[name] or (#managed + 1)
	end

	-- Ordenação topológica (Kahn) com desempate estável.
	local pending, remaining = {}, 0
	for name in pairs(affected) do
		local count = 0
		for _, dependency in ipairs(dependenciesOf(graph, name)) do
			if affected[dependency] then
				count = count + 1
			end
		end
		pending[name] = count
		remaining = remaining + 1
	end

	local start = {}
	while remaining > 0 do
		local ready = {}
		for name, count in pairs(pending) do
			if count == 0 then
				ready[#ready + 1] = name
			end
		end
		if #ready == 0 then
			return nil, 'dependency_cycle'
		end
		table.sort(ready, function(left, right)
			if rank(left) ~= rank(right) then
				return rank(left) < rank(right)
			end
			return left < right
		end)
		local name = ready[1]
		pending[name] = nil
		remaining = remaining - 1
		start[#start + 1] = name
		for other in pairs(pending) do
			for _, dependency in ipairs(dependenciesOf(graph, other)) do
				if dependency == name then
					pending[other] = pending[other] - 1
				end
			end
		end
	end

	local stop = {}
	for index = #start, 1, -1 do
		if graph[start[index]].state == 'started' then
			stop[#stop + 1] = start[index]
		end
	end

	local unmanaged = {}
	for _, name in ipairs(start) do
		if not order[name] then
			unmanaged[#unmanaged + 1] = name
		end
	end

	return { target = target, stop = stop, start = start, unmanaged = unmanaged }
end
