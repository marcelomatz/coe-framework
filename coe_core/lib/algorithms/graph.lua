-- Algoritmos de grafos: Ordenação Topológica de Kahn, Subgrafo de Restart em Cascata e Pathfinding A* (A-Star) 3D.
local math_sqrt = math.sqrt

local function resolveContainers()
	if type(CoeAlgorithms) == 'table' and CoeAlgorithms.Containers then
		return CoeAlgorithms.Containers
	end
	if type(Core) == 'table' and type(Core.Algorithms) == 'table' and Core.Algorithms.Containers then
		return Core.Algorithms.Containers
	end
	if type(LoadResourceFile) == 'function' then
		local src = LoadResourceFile('coe_core', 'lib/algorithms/containers.lua')
		if src then
			local fn = load(src, '@coe_core/lib/algorithms/containers.lua')
			if fn then
				return fn()
			end
		end
	end
	for _, candidate in ipairs({
		'coe_core.lib.algorithms.containers',
		'lib.algorithms.containers',
		'@coe_core.lib.algorithms.containers'
	}) do
		local ok, mod = pcall(require, candidate)
		if ok and type(mod) == 'table' then
			return mod
		end
	end
	for _, rel in ipairs({
		'lib/algorithms/containers.lua',
		'../coe_core/lib/algorithms/containers.lua',
		'../../coe-framework/coe_core/lib/algorithms/containers.lua'
	}) do
		local f = io.open(rel, 'r')
		if f then
			f:close()
			return dofile(rel)
		end
	end
	return dofile('lib/algorithms/containers.lua')
end

local Containers = resolveContainers()

local Graph = {}

--- Ordenação Topológica de Kahn + Subgrafo de Restart em Cascata para coe_supervisor
---@param nodes string[] Lista de nomes de resources
---@param dependencies table<string, string[]> Mapa: resource -> lista de dependências
---@return string[]|nil bootOrder, string[][]|nil parallelWaves, string[]|nil cycleNodes
function Graph.topologicalSort(nodes, dependencies)
	local inDegree = {}
	local dependents = {}
	for i = 1, #nodes do
		local u = nodes[i]
		inDegree[u] = 0
		dependents[u] = {}
	end

	for i = 1, #nodes do
		local u = nodes[i]
		local deps = dependencies[u]
		if deps then
			for j = 1, #deps do
				local dep = deps[j]
				if inDegree[dep] ~= nil then
					inDegree[u] = inDegree[u] + 1
					local list = dependents[dep]
					list[#list + 1] = u
				end
			end
		end
	end

	local currentWave = {}
	for i = 1, #nodes do
		local u = nodes[i]
		if inDegree[u] == 0 then
			currentWave[#currentWave + 1] = u
		end
	end
	table.sort(currentWave)

	local bootOrder = {}
	local waves = {}
	while #currentWave > 0 do
		waves[#waves + 1] = currentWave
		local nextWave = {}
		for i = 1, #currentWave do
			local u = currentWave[i]
			bootOrder[#bootOrder + 1] = u
			local dList = dependents[u]
			for j = 1, #dList do
				local v = dList[j]
				inDegree[v] = inDegree[v] - 1
				if inDegree[v] == 0 then
					nextWave[#nextWave + 1] = v
				end
			end
		end
		table.sort(nextWave)
		currentWave = nextWave
	end

	if #bootOrder < #nodes then
		local cycleNodes = {}
		for i = 1, #nodes do
			local u = nodes[i]
			if inDegree[u] > 0 then
				cycleNodes[#cycleNodes + 1] = u
			end
		end
		return nil, nil, cycleNodes
	end

	return bootOrder, waves, nil
end

--- Calcula a sequência exata de parada (reversa) e reinício (direta) para coe_supervisor:Restart
function Graph.cascadeRestartPlan(targetNode, nodes, dependencies)
	local bootOrder, _, err = Graph.topologicalSort(nodes, dependencies)
	if not bootOrder then
		return nil, nil, err
	end

	local dependents = {}
	for i = 1, #nodes do
		dependents[nodes[i]] = {}
	end
	for i = 1, #nodes do
		local u = nodes[i]
		local deps = dependencies[u] or {}
		for j = 1, #deps do
			if dependents[deps[j]] then
				local list = dependents[deps[j]]
				list[#list + 1] = u
			end
		end
	end

	local affected = { [targetNode] = true }
	local queue = { targetNode }
	local head = 1
	while head <= #queue do
		local curr = queue[head]
		head = head + 1
		local dList = dependents[curr] or {}
		for i = 1, #dList do
			local dep = dList[i]
			if not affected[dep] then
				affected[dep] = true
				queue[#queue + 1] = dep
			end
		end
	end

	local startOrder = {}
	for i = 1, #bootOrder do
		local u = bootOrder[i]
		if affected[u] then
			startOrder[#startOrder + 1] = u
		end
	end

	local stopOrder = {}
	for i = #startOrder, 1, -1 do
		stopOrder[#stopOrder + 1] = startOrder[i]
	end

	return stopOrder, startOrder, nil
end

--- Pathfinding A* (A-Star) 3D para rotas procedurais de carga (coe_jobs) e despacho (coe_dispatch)
function Graph.astar(graphNodes, startId, goalId)
	local goalNode = graphNodes[goalId]
	if not graphNodes[startId] or not goalNode then
		return nil, math.huge
	end

	local openSet = Containers.newMinHeap()
	local cameFrom = {}
	local gScore = { [startId] = 0.0 }

	local function heuristic(nodeId)
		local n = graphNodes[nodeId]
		local dx, dy, dz = n.x - goalNode.x, n.y - goalNode.y, (n.z or 0) - (goalNode.z or 0)
		return math_sqrt(dx * dx + dy * dy + dz * dz)
	end

	openSet:push(startId, heuristic(startId))

	while openSet:size() > 0 do
		local current = openSet:pop()
		if current == goalId then
			local revPath = {}
			local curr = current
			while curr do
				revPath[#revPath + 1] = curr
				curr = cameFrom[curr]
			end
			local path = {}
			for i = #revPath, 1, -1 do
				path[#path + 1] = revPath[i]
			end
			return path, gScore[goalId]
		end

		local currG = gScore[current]
		local edges = graphNodes[current].edges or graphNodes[current].neighbors or {}
		for i = 1, #edges do
			local edge = edges[i]
			local neighbor = edge.to or edge.id
			local tentativeG = currG + (edge.cost or edge.weight or 0)
			local prevG = gScore[neighbor]
			if not prevG or tentativeG < prevG then
				cameFrom[neighbor] = current
				gScore[neighbor] = tentativeG
				openSet:push(neighbor, tentativeG + heuristic(neighbor))
			end
		end
	end

	return nil, math.huge
end

return Graph
