-- Plano de reinício: o alvo e todos os resources iniciados que dependem dele (direta ou
-- indiretamente) são parados dos dependentes para a base e iniciados da base para os dependentes.
-- Utiliza lista de adjacência reversa + BFS em O(V + E) e Ordenação Topológica de Kahn em O(V + E)
-- integrada a @coe_core/lib/algorithms/graph.lua.
SupervisorPlan = {}

local function resolveAlgorithms()
	if type(Core) == 'table' and type(Core.Algorithms) == 'table' then
		return Core.Algorithms
	end
	if type(CoeAlgorithms) == 'table' then
		return CoeAlgorithms
	end
	if type(LoadResourceFile) == 'function' then
		local src = LoadResourceFile('coe_core', 'lib/algorithms/init.lua')
		if type(src) == 'string' and src ~= '' then
			local fn = load(src, '@@coe_core/lib/algorithms/init.lua', 't', _G)
			if fn then pcall(fn) end
		end
	elseif type(io) == 'table' and type(io.open) == 'function' then
		for _, candidate in ipairs({
			'../coe_core/lib/algorithms/init.lua',
			'../../coe-framework/coe_core/lib/algorithms/init.lua'
		}) do
			local f = io.open(candidate, 'r')
			if f then
				f:close()
				pcall(dofile, candidate)
				break
			end
		end
	end
	return CoeAlgorithms
end

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

-- Calcula a ordenação topológica completa e ondas paralelas delegando para Graph.topologicalSort.
function SupervisorPlan.TopologicalSort(nodes, dependencies)
	local alg = resolveAlgorithms()
	if alg and alg.Graph and type(alg.Graph.topologicalSort) == 'function' then
		return alg.Graph.topologicalSort(nodes, dependencies)
	end
	return nil, nil, 'algorithms_unavailable'
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

	-- 1. Constrói lista de adjacência reversa (dependents) em uma única passagem O(V + E)
	local dependents = {}
	local validDeps = {}
	for name in pairs(graph) do
		dependents[name] = {}
	end
	for name in pairs(graph) do
		local deps = dependenciesOf(graph, name)
		validDeps[name] = deps
		for i = 1, #deps do
			local dep = deps[i]
			if dependents[dep] then
				local list = dependents[dep]
				list[#list + 1] = name
			end
		end
	end

	-- 2. BFS em O(V + E) para descobrir todos os resources 'started' afetados pelo target
	local affected = { [target] = true }
	local queue = { target }
	local head = 1
	while head <= #queue do
		local current = queue[head]
		head = head + 1
		local depList = dependents[current] or {}
		for i = 1, #depList do
			local depName = depList[i]
			local node = graph[depName]
			if not affected[depName] and node and node.state == 'started' then
				affected[depName] = true
				queue[#queue + 1] = depName
			end
		end
	end

	local function rank(name)
		return order[name] or (#managed + 1)
	end

	-- 3. Ordenação topológica de Kahn em O(V + E) usando a lista reversa `dependents` e desempate estável
	local pending, remaining = {}, 0
	for name in pairs(affected) do
		local count = 0
		for _, dependency in ipairs(validDeps[name] or {}) do
			if affected[dependency] then
				count = count + 1
			end
		end
		pending[name] = count
		remaining = remaining + 1
	end

	local start = {}
	local waves = {}
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
		waves[#waves + 1] = ready
		local name = ready[1]
		pending[name] = nil
		remaining = remaining - 1
		start[#start + 1] = name
		for _, other in ipairs(dependents[name] or {}) do
			if pending[other] ~= nil then
				pending[other] = pending[other] - 1
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

	return { target = target, stop = stop, start = start, unmanaged = unmanaged, waves = waves }
end
