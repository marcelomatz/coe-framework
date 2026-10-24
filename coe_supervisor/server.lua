local running = false
local Replace = SupervisorReplace
local replaceConfig = SupervisorConfig.Replacements or {}
local held = {}            -- básicos que o supervisor impediu de iniciar ou parou por causa de um substituto
local allowStart = {}      -- básicos que o próprio supervisor está iniciando de volta
local settled = false      -- boot assentado (nenhum resource subindo/parando há SettleMs)
local lastChange = 0
local dirty = true

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

-- Estado e metadados de substituição de todos os resources.
local function readReplacements()
	local resources = {}
	for index = 0, GetNumResources() - 1 do
		local name = GetResourceByFindIndex(index)
		if name then
			local replaces = {}
			for position = 0, (GetNumResourceMetadata(name, 'coe_supervisor_replaces') or 0) - 1 do
				local target = GetResourceMetadata(name, 'coe_supervisor_replaces', position)
				if type(target) == 'string' and target:match('^[%w_%-]+$') then
					replaces[#replaces + 1] = target
				end
			end
			resources[name] = {
				state = GetResourceState(name),
				replaceable = GetResourceMetadata(name, 'coe_supervisor_replaceable', 0) == 'yes',
				replaces = replaces
			}
		end
	end
	return resources, Replace.Map(resources)
end

local function callerAllowed()
	return CoeAccess.Allowed(GetInvokingResource(), SupervisorConfig.Ace)
end

-- Gerenciados: os do framework (config) e os que declaram a categoria no fxmanifest (coe_supervisor 'business').
local function managed()
	local list, catalog, seen = {}, {}, {}
	for _, name in ipairs(SupervisorConfig.Managed) do
		list[#list + 1] = name
		seen[name] = true
	end
	for name, meta in pairs(SupervisorConfig.Catalog) do
		catalog[name] = meta
	end
	for index = 0, GetNumResources() - 1 do
		local name = GetResourceByFindIndex(index)
		local category = name and not seen[name] and GetResourceMetadata(name, 'coe_supervisor', 0)
		if type(category) == 'string' and category:match('^[%w_]+$') then
			seen[name] = true
			list[#list + 1] = name
			catalog[name] = { category = category, critical = GetResourceMetadata(name, 'coe_supervisor_critical', 0) == 'yes' }
		end
	end
	return list, catalog
end

exports('List', function()
	if not callerAllowed() then
		return nil
	end

	local graph = readGraph()
	local names, catalog = managed()
	local replaceResources, replaceMap = readReplacements()
	local list = {}
	for _, name in ipairs(names) do
		if graph[name] then
			local plan = SupervisorPlan.Build(name, graph, names)
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
			local category, critical = SupervisorPlan.Meta(name, catalog, #restart, SupervisorConfig.CriticalRestartSize)
			local replacedBy = held[name] and replaceMap and Replace.ActiveReplacer(name, replaceMap, replaceResources) or nil
			list[#list + 1] = {
				name = name,
				category = category,
				critical = critical,
				description = GetResourceMetadata(name, 'description', 0),
				version = GetResourceMetadata(name, 'version', 0),
				dependents = dependents,
				state = graph[name].state,
				dependencies = dependencies,
				restart = restart,
				replacedBy = replacedBy
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
	if held[name] then
		return 'resource_replaced'
	end

	local plan, planError = SupervisorPlan.Build(name, readGraph(), (managed()))
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

-- Substituição de básicos por pacotes ---------------------------------------------------------------------------

local function markChange()
	lastChange = GetGameTimer()
	dirty = true
end

-- Um básico substituível só inicia se nenhum substituto roda (nem pode subir no boot).
AddEventHandler('onResourceStarting', function(name)
	markChange()
	if replaceConfig.Enabled == false then
		return
	end
	if allowStart[name] then
		allowStart[name] = nil
		return
	end
	local resources, map = readReplacements()
	if not map[name] then
		return
	end
	local allowed, replacer = Replace.CanStart(name, map, resources, settled)
	if not allowed then
		held[name] = true
		CancelEvent()
		say('INFO', 'resource_replaced', ('resource=%s by=%s'):format(name, replacer))
	end
end)

AddEventHandler('onResourceStart', markChange)
AddEventHandler('onResourceStop', markChange)
AddEventHandler('onResourceListRefresh', markChange)

local function reconcile()
	local resources, map = readReplacements()
	for _, action in ipairs(Replace.Reconcile(map, resources, held)) do
		if action.op == 'stop' then
			held[action.name] = true
			StopResource(action.name)
			say('INFO', 'resource_replaced', ('resource=%s by=%s'):format(action.name, action.replacer))
		else
			held[action.name] = nil
			allowStart[action.name] = true
			StartResource(action.name)
			say('INFO', 'resource_restored', 'resource=' .. action.name)
		end
	end
	-- Básico removido do servidor, ou iniciado por fora sem substituto rodando: deixa de ser segurado.
	for name in pairs(held) do
		local info = resources[name]
		if not info or info.state == 'missing' or (info.state == 'started' and not Replace.ActiveReplacer(name, map, resources)) then
			held[name] = nil
		end
	end
end

CreateThread(function()
	lastChange = GetGameTimer()
	while true do
		Wait(1000)
		if replaceConfig.Enabled ~= false and not running and GetGameTimer() - lastChange >= (replaceConfig.SettleMs or 4000) then
			settled = true
			if dirty then
				dirty = false
				local ok, err = pcall(reconcile)
				if not ok then
					say('ERROR', 'replace_reconcile_failed', tostring(err))
				end
			end
		end
	end
end)

-- Mapa DE > PARA no console: `coe_upgrades` (console do servidor ou ACE command.coe_upgrades). Para cada básico
-- substituível: quem o substitui, o estado de cada um e, se o pacote expõe `UpgradeStatus()`, o que ele importou do
-- básico (o framework não cita o pacote; o nome vem do fxmanifest dele).
local function describe(report)
	if type(report) ~= 'table' then
		return nil
	end
	if report.ok == false then
		return 'falhou (' .. tostring(report.error) .. ')'
	end
	if report.skipped then
		return 'nada a importar (' .. tostring(report.skipped) .. ')'
	end
	local parts = {}
	local keys = {}
	for key, value in pairs(report) do
		if type(value) == 'number' then keys[#keys + 1] = key end
	end
	table.sort(keys)
	for _, key in ipairs(keys) do
		parts[#parts + 1] = key .. '=' .. tostring(report[key])
	end
	return table.concat(parts, ' ')
end

function SupervisorUpgradeLines()
	local resources, map = readReplacements()
	local lines = {}
	local basics = {}
	for name, info in pairs(resources) do
		if info.replaceable then basics[#basics + 1] = name end
	end
	table.sort(basics)
	if #basics == 0 then
		return { 'Nenhum resource básico substituível encontrado.' }
	end
	for _, basic in ipairs(basics) do
		local replacers = map[basic] or {}
		local active = Replace.ActiveReplacer(basic, map, resources)
		if #replacers == 0 then
			lines[#lines + 1] = ('%s (%s) -> sem pacote instalado'):format(basic, resources[basic].state)
		else
			for _, replacer in ipairs(replacers) do
				local marker = replacer == active and 'ATIVO' or resources[replacer].state
				lines[#lines + 1] = ('%s (%s) -> %s (%s)'):format(basic, resources[basic].state, replacer, marker)
				if replacer == active then
					local ok, report = pcall(function() return exports[replacer]:UpgradeStatus() end)
					local text = ok and describe(report) or nil
					if text then
						lines[#lines + 1] = '    dados do básico: ' .. text
					end
				end
			end
		end
	end
	return lines
end

RegisterCommand('coe_upgrades', function(playerId)
	if playerId ~= 0 and not IsPlayerAceAllowed(playerId, 'command.coe_upgrades') then
		return
	end
	print('[coe_supervisor] DE (básico) -> PARA (pacote)')
	for _, line in ipairs(SupervisorUpgradeLines()) do
		print('  ' .. line)
	end
end, true)
