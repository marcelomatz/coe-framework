local running = false

local function say(level, event, details)
	print(('[coe_supervisor] %s %s %s'):format(level, event, details or ''))
end

local function readGraph()
	local graph = {}
	for index = 0, GetNumResources() - 1 do
		local name = GetResourceByFindIndex(index)
		if name then
			local dependencies, seen = {}, {}
			for _, key in ipairs({ 'dependency', 'dependencies' }) do
				for position = 0, (GetNumResourceMetadata(name, key) or 0) - 1 do
					local dependency = GetResourceMetadata(name, key, position)
					if dependency and not seen[dependency] then
						seen[dependency] = true
						dependencies[#dependencies + 1] = dependency
					end
				end
			end
			graph[name] = { state = GetResourceState(name), dependencies = dependencies }
		end
	end
	return graph
end

local function callerAllowed()
	return GetInvokingResource() == SupervisorConfig.Caller
end

exports('List', function()
	if not callerAllowed() then
		return nil
	end

	local graph = readGraph()
	local list = {}
	for _, name in ipairs(SupervisorConfig.Managed) do
		if graph[name] then
			local plan = SupervisorPlan.Build(name, graph, SupervisorConfig.Managed)
			local dependencies = {}
			for _, dependency in ipairs(graph[name].dependencies) do
				if graph[dependency] then
					dependencies[#dependencies + 1] = dependency
				end
			end
			local dependents = {}
			for other, node in pairs(graph) do
				for _, dependency in ipairs(node.dependencies) do
					if dependency == name then
						dependents[#dependents + 1] = other
					end
				end
			end
			table.sort(dependents)
			local restart = plan and plan.start or { name }
			local category, critical = SupervisorPlan.Meta(name, SupervisorConfig.Catalog, #restart, SupervisorConfig.CriticalRestartSize)
			list[#list + 1] = {
				name = name,
				category = category,
				critical = critical,
				description = GetResourceMetadata(name, 'description', 0),
				version = GetResourceMetadata(name, 'version', 0),
				dependents = dependents,
				state = graph[name].state,
				dependencies = dependencies,
				restart = restart
			}
		end
	end
	return list
end)

local function waitForState(name, wanted, timeoutMs)
	local waited = 0
	while waited < timeoutMs do
		if GetResourceState(name) == wanted then
			return true
		end
		Wait(100)
		waited = waited + 100
	end
	return GetResourceState(name) == wanted
end

local function notify(requester, success, message)
	if requester then
		TriggerClientEvent('coe_supervisor:result', requester, success, message)
	end
end

local function execute(plan, requester)
	say('INFO', 'restart_started', ('target=%s order=%s'):format(plan.target, table.concat(plan.start, ',')))

	for _, name in ipairs(plan.stop) do
		StopResource(name)
		if not waitForState(name, 'stopped', SupervisorConfig.StopTimeoutMs) then
			say('ERROR', 'restart_stop_failed', 'resource=' .. name)
			notify(requester, false, ('Falha ao parar %s. Verifique o console.'):format(name))
			return
		end
	end

	if SupervisorConfig.RefreshBeforeStart then
		ExecuteCommand('refresh')
		Wait(SupervisorConfig.RefreshWaitMs)
	end

	for _, name in ipairs(plan.start) do
		StartResource(name)
		if not waitForState(name, 'started', SupervisorConfig.StartTimeoutMs) then
			say('ERROR', 'restart_start_failed', 'resource=' .. name)
			notify(requester, false, ('Falha ao iniciar %s. Verifique o console.'):format(name))
			return
		end
	end

	say('INFO', 'restart_completed', ('target=%s resources=%d'):format(plan.target, #plan.start))
	notify(requester, true, ('%s reiniciado (%d resource%s).'):format(plan.target, #plan.start, #plan.start == 1 and '' or 's'))
end

-- Retorna true quando o reinício foi agendado, ou um código de erro.
exports('Restart', function(name, requester)
	if not callerAllowed() then
		return 'forbidden'
	end
	if running then
		return 'restart_in_progress'
	end

	local plan, planError = SupervisorPlan.Build(name, readGraph(), SupervisorConfig.Managed)
	if not plan then
		return planError
	end

	running = true
	CreateThread(function()
		local ok, runError = pcall(execute, plan, requester)
		if not ok then
			say('ERROR', 'restart_crashed', tostring(runError))
		end
		running = false
	end)
	return true
end)
