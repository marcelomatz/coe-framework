if not SupervisorAnsi then
	pcall(dofile, 'ansi.lua')
end
if not SupervisorUpdater then
	pcall(dofile, 'updater.lua')
end
local Ansi = SupervisorAnsi
local running = false
local Replace = SupervisorReplace
local Updater = SupervisorUpdater
local replaceConfig = SupervisorConfig.Replacements or {}
local updaterConfig = SupervisorConfig.Updater or {}
local held = {}            -- básicos que o supervisor impediu de iniciar ou parou por causa de um substituto
local allowStart = {}      -- básicos que o próprio supervisor está iniciando de volta
local settled = false      -- boot assentado (nenhum resource subindo/parando há SettleMs)
local startupUpdateChecked = false
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
	return CoeAccess.Allowed(GetInvokingResource(), SupervisorConfig.Ace, SupervisorConfig.Defaults)
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

-- Sistema de verificação de versão e atualização de scripts ------------------------------------------------------

local function readLocalManifest()
	local currentRes = type(GetCurrentResourceName) == 'function' and GetCurrentResourceName() or 'coe_supervisor'
	local raw = type(LoadResourceFile) == 'function' and LoadResourceFile(currentRes, 'version.json') or nil
	if type(raw) == 'string' and raw ~= '' and type(json) == 'table' and type(json.decode) == 'function' then
		local ok, decoded = pcall(json.decode, raw)
		if ok and type(decoded) == 'table' and type(decoded.version) == 'string' then
			return decoded
		end
	end
	local ver = (type(GetResourceMetadata) == 'function' and GetResourceMetadata(currentRes, 'version', 0)) or '0.1.0-beta.1'
	local parsed = Updater.ParseVersion(ver)
	return {
		version = parsed and parsed.raw or '0.1.0-beta.1',
		channel = parsed and parsed.channel or 'beta',
		repository = updaterConfig.Repository or 'marcelomatz/coe-framework',
		branch = updaterConfig.Branch or 'main',
		resources = {}
	}
end

local function readInstalledVersions()
	local versions = {}
	for _, name in ipairs(SupervisorConfig.Managed or {}) do
		if GetResourceState(name) ~= 'missing' then
			local ver = GetResourceMetadata(name, 'version', 0)
			if type(ver) == 'string' and ver ~= '' then
				versions[name] = ver
			end
		end
	end
	return versions
end

local initialLocal = readLocalManifest()
local updateState = {
	available = false,
	checking = false,
	updating = false,
	localVersion = initialLocal.version or '0.1.0-beta.1',
	remoteVersion = nil,
	tag = initialLocal.tag or ('v' .. (initialLocal.version or '0.1.0-beta.1')),
	channel = initialLocal.channel or 'beta',
	notes = initialLocal.notes or '',
	repository = initialLocal.repository or updaterConfig.Repository or 'marcelomatz/coe-framework',
	branch = initialLocal.branch or updaterConfig.Branch or 'main',
	outdatedCount = 0,
	outdatedResources = {},
	filesCount = 0,
	filesWritten = 0,
	filesSkipped = 0,
	pendingCount = 0,
	pendingReleases = {},
	pendingVersions = {},
	isCumulative = false,
	planType = 'direct',
	planSummary = nil,
	startTime = nil,
	lastProgressTime = nil,
	requester = nil,
	requiresFullRestart = false,
	needsRestart = false,
	lastError = nil
}
local lastUpdatePlan = nil
local lastRemoteRawJson = nil

local function publishUpdateState()
	local snapshot = {
		available = updateState.available == true,
		checking = updateState.checking == true,
		updating = updateState.updating == true,
		localVersion = updateState.localVersion,
		remoteVersion = updateState.remoteVersion,
		tag = updateState.tag,
		channel = updateState.channel,
		notes = updateState.notes,
		repository = updateState.repository,
		branch = updateState.branch,
		outdatedCount = updateState.outdatedCount or 0,
		outdatedResources = updateState.outdatedResources or {},
		filesCount = updateState.filesCount or 0,
		filesWritten = updateState.filesWritten or 0,
		filesSkipped = updateState.filesSkipped or 0,
		currentResource = updateState.currentResource,
		pendingCount = updateState.pendingCount or 0,
		pendingReleases = updateState.pendingReleases or {},
		pendingVersions = updateState.pendingVersions or {},
		isCumulative = updateState.isCumulative == true,
		planType = updateState.planType or 'direct',
		planSummary = updateState.planSummary,
		startTime = updateState.startTime,
		lastProgressTime = updateState.lastProgressTime,
		requester = updateState.requester,
		requiresFullRestart = updateState.requiresFullRestart == true,
		needsRestart = updateState.needsRestart == true,
		lastError = updateState.lastError
	}
	if type(GlobalState) == 'table' or type(GlobalState) == 'userdata' then
		pcall(function()
			GlobalState.coeFrameworkUpdate = snapshot
		end)
	end
	return snapshot
end

local function httpGet(url, timeoutMs, maxRetries)
	if type(PerformHttpRequest) ~= 'function' or type(promise) ~= 'table' or type(Citizen) ~= 'table' then
		return nil, 'http_unavailable'
	end
	local retries = tonumber(maxRetries) or 3
	local attempt = 0

	while attempt <= retries do
		attempt = attempt + 1
		local p = promise.new()
		local settledHttp = false
		SetTimeout(timeoutMs or updaterConfig.TimeoutMs or 10000, function()
			if not settledHttp then
				settledHttp = true
				p:resolve({ status = 0, body = nil, error = 'timeout' })
			end
		end)
		PerformHttpRequest(url, function(statusCode, responseBody)
			if not settledHttp then
				settledHttp = true
				p:resolve({ status = tonumber(statusCode) or 0, body = responseBody })
			end
		end, 'GET', '', {
			['User-Agent'] = 'COE-Framework-Supervisor/' .. tostring(updateState.localVersion),
			['Accept'] = 'application/json, text/plain, */*'
		})
		local res = Citizen.Await(p)
		if res and res.status == 200 and type(res.body) == 'string' and res.body ~= '' then
			return res.body, nil
		end

		local status = res and res.status or 0
		local isRateLimit = (status == 429)
		local isTimeout = (res and res.error == 'timeout')

		if (isRateLimit or isTimeout) and attempt <= retries then
			local backoffMs = isRateLimit and (attempt * 2500) or 1500
			if Ansi and Ansi.PrintRateLimitWait then
				Ansi.PrintRateLimitWait(attempt, retries, backoffMs, isRateLimit)
			else
				say('WARN', 'http_retry', ('Aguardando %dms para tentar novamente após %s (tentativa %d/%d)...'):format(
					backoffMs, isRateLimit and 'HTTP 429 Rate Limit' or 'timeout', attempt, retries))
			end
			Wait(backoffMs)
		else
			return nil, res and res.error or ('http_' .. tostring(status))
		end
	end
	return nil, 'max_retries_exceeded'
end

local function isWindowsHost()
	if type(package) == 'table' and type(package.config) == 'string' then
		return package.config:sub(1, 1) == '\\'
	end
	if type(os.getenv) == 'function' then
		local osName = os.getenv('OS')
		if type(osName) == 'string' and osName:find('Windows') then
			return true
		end
		if os.getenv('WINDIR') or os.getenv('SystemRoot') then
			return true
		end
	end
	if type(GetResourcePath) == 'function' and type(GetCurrentResourceName) == 'function' then
		local p = GetResourcePath(GetCurrentResourceName()) or ''
		if p:find('^[A-Za-z]:') or p:find('\\', 1, true) then
			return true
		end
	end
	return true
end

local function ensureParentDir(filePath)
	if type(filePath) ~= 'string' then
		return
	end
	local dir = filePath:match('^(.*)/[^/]+$') or filePath:match('^(.*)\\[^\\]+$')
	if not dir or dir == '' then
		return
	end
	if type(os.execute) == 'function' then
		pcall(function()
			local isWin = isWindowsHost()
			if isWin then
				os.execute('if not exist "' .. dir:gsub('/', '\\') .. '" mkdir "' .. dir:gsub('/', '\\') .. '" >nul 2>nul')
			else
				os.execute('mkdir -p "' .. dir .. '" >/dev/null 2>&1')
			end
		end)
	end
end

local function writeResourceFile(resName, relPath, content, isBinary)
	local safeRel = Updater.SanitizeRelativePath(relPath)
	if not safeRel or type(content) ~= 'string' then
		return false
	end

	local currentRes = type(GetCurrentResourceName) == 'function' and GetCurrentResourceName() or 'coe_supervisor'

	-- 1. GetResourcePath: caminho físico no host
	if type(GetResourcePath) == 'function' then
		local basePath = GetResourcePath(resName)
		if type(basePath) == 'string' and basePath ~= '' then
			local fullPath = basePath:gsub('\\', '/'):gsub('/+$', '') .. '/' .. safeRel

			-- 1a. Tenta via fs_writer (Node.js nativo do FXServer)
			local okNode, nodeRes = pcall(function()
				if exports and exports[currentRes] and exports[currentRes].WriteFile then
					return exports[currentRes]:WriteFile(fullPath, content, isBinary)
				end
				return nil
			end)
			if okNode and nodeRes == true then
				return true
			end

			-- 1b. Fallback para io.open nativo com criação de pasta pai
			ensureParentDir(fullPath)
			local handle = io.open(fullPath, 'wb')
			if handle then
				handle:write(content)
				handle:close()
				return true
			end
		end
	end

	-- 2. Tenta SaveResourceFile (permitido pelo VFS quando add_filesystem_permission estiver no server.cfg)
	if type(SaveResourceFile) == 'function' then
		local ok = SaveResourceFile(resName, safeRel, content, -1)
		if ok == true or ok == 1 then
			return true
		end
	end

	say('ERROR', 'file_write_failed', ('Falha ao gravar arquivo: %s/%s. Certifique-se de que "add_filesystem_permission %s write %s" está no server.cfg e reinicie o FXServer.'):format(
		tostring(resName), tostring(safeRel), tostring(currentRes), tostring(resName)))
	return false
end

local function readResourceFile(resName, relPath)
	local safeRel = Updater.SanitizeRelativePath(relPath)
	if not safeRel then
		return nil
	end

	local currentRes = type(GetCurrentResourceName) == 'function' and GetCurrentResourceName() or 'coe_supervisor'

	if type(GetResourcePath) == 'function' then
		local basePath = GetResourcePath(resName)
		if type(basePath) == 'string' and basePath ~= '' then
			local fullPath = basePath:gsub('\\', '/'):gsub('/+$', '') .. '/' .. safeRel

			local okNode, nodeRes = pcall(function()
				if exports and exports[currentRes] and exports[currentRes].ReadFile then
					return exports[currentRes]:ReadFile(fullPath)
				end
				return nil
			end)
			if okNode and type(nodeRes) == 'string' then
				return nodeRes
			end

			local handle = io.open(fullPath, 'rb')
			if handle then
				local content = handle:read('*a')
				handle:close()
				return content
			end
		end
	end

	if type(LoadResourceFile) == 'function' then
		local c = LoadResourceFile(resName, safeRel)
		if type(c) == 'string' then
			return c
		end
	end

	return nil
end

local function printUpdateBanner(plan)
	if Ansi and Ansi.PrintUpdateAvailable then
		Ansi.PrintUpdateAvailable(plan)
		return
	end
	print('======================================================================')
	print(('[COE Framework] NOVA VERSÃO DISPONÍVEL NO REPOSITÓRIO (%s)'):format(tostring(plan.channel or 'beta'):upper()))
	print(('  Versão instalada : v%s'):format(tostring(plan.localVersion)))
	print(('  Nova versão      : v%s (%s)'):format(tostring(plan.remoteVersion), tostring(plan.tag or ('v' .. plan.remoteVersion))))
	if type(plan.notes) == 'string' and plan.notes ~= '' then
		print(('  Notas da release : %s'):format(plan.notes))
	end
	print(('  Scripts pendentes: %d resource(s) (%d arquivo(s))'):format(plan.outdatedCount or 0, plan.filesCount or 0))
	print('  Como atualizar   : digite "coe_update apply" no console ou atualize pelo painel F10 (Staff).')
	print('======================================================================')
end

local function runCheckForUpdates(announceConsole)
	if updateState.checking or updateState.updating then
		return publishUpdateState()
	end
	updateState.checking = true
	updateState.lastError = nil
	publishUpdateState()

	local localManifest = readLocalManifest()
	updateState.localVersion = localManifest.version or updateState.localVersion
	updateState.channel = localManifest.channel or updateState.channel

	local manifestUrl = (type(GetConvar) == 'function' and GetConvar('coe_updater_manifest_url', '')) or ''
	if manifestUrl == '' then
		manifestUrl = updaterConfig.ManifestUrl or 'https://raw.githubusercontent.com/marcelomatz/coe-framework/main/version.json'
	end
	local rawBaseUrl = (type(GetConvar) == 'function' and GetConvar('coe_updater_raw_base_url', '')) or ''
	if rawBaseUrl == '' then
		rawBaseUrl = updaterConfig.RawBaseUrl
	end

	local body, httpErr = httpGet(manifestUrl, updaterConfig.TimeoutMs)
	if not body then
		updateState.checking = false
		updateState.lastError = httpErr or 'fetch_failed'
		return publishUpdateState()
	end

	local okDecode, remoteManifest = pcall(json.decode, body)
	if not okDecode or type(remoteManifest) ~= 'table' then
		updateState.checking = false
		updateState.lastError = 'invalid_json'
		return publishUpdateState()
	end

	local _, catalog = managed()
	local plan, planErr = Updater.BuildUpdatePlan(localManifest, remoteManifest, readInstalledVersions(), catalog, rawBaseUrl)
	updateState.checking = false
	if not plan then
		updateState.lastError = planErr or 'invalid_manifest'
		return publishUpdateState()
	end

	lastUpdatePlan = plan
	lastRemoteRawJson = body
	updateState.available = plan.available == true
	updateState.localVersion = plan.localVersion
	updateState.remoteVersion = plan.remoteVersion
	updateState.tag = plan.tag
	updateState.channel = plan.channel
	updateState.notes = plan.notes
	updateState.repository = plan.repository
	updateState.branch = plan.branch
	updateState.outdatedCount = plan.outdatedCount
	updateState.outdatedResources = plan.outdatedResources
	updateState.filesCount = plan.filesCount
	updateState.pendingCount = plan.pendingCount or 0
	updateState.pendingReleases = plan.pendingReleases or {}
	updateState.pendingVersions = plan.pendingVersions or {}
	updateState.isCumulative = plan.isCumulative == true
	updateState.planType = plan.planType or 'direct'
	updateState.planSummary = plan.planSummary
	updateState.requiresFullRestart = plan.requiresFullRestart
	updateState.lastError = nil

	local snapshot = publishUpdateState()
	if plan.available and announceConsole then
		printUpdateBanner(plan)
	elseif announceConsole then
		say('INFO', 'version_up_to_date', ('v%s (%s)'):format(plan.localVersion, plan.channel))
	end
	return snapshot
end

local function runApplyUpdate(requester)
	if updateState.updating or running then
		return false, 'update_in_progress'
	end
	if not lastUpdatePlan or not updateState.available then
		runCheckForUpdates(false)
	end
	if not lastUpdatePlan or not lastUpdatePlan.available then
		return false, 'already_up_to_date'
	end

	updateState.updating = true
	updateState.filesWritten = 0
	updateState.filesSkipped = 0
	updateState.currentResource = nil
	updateState.lastError = nil
	updateState.startTime = os.time()
	updateState.lastProgressTime = os.time()
	updateState.requester = requester or 'console'
	publishUpdateState()

	local plan = lastUpdatePlan
	if Ansi and Ansi.PrintUpdateStart then
		Ansi.PrintUpdateStart(plan, requester)
	else
		say('INFO', 'update_started', ('from=v%s to=v%s resources=%d files=%d requester=%s'):format(
			tostring(plan.localVersion), tostring(plan.remoteVersion), plan.outdatedCount or 0, plan.filesCount or 0, tostring(requester or 'console')))
	end

	local updatedResources = {}
	local filesWritten = 0
	local filesSkipped = 0
	local failedFile = nil
	local lastPrintedRes = nil
	local totalDl = #(plan.downloads or {})

	for _, item in ipairs(plan.downloads or {}) do
		local resState = GetResourceState(item.resource)
		if resState ~= 'missing' then
			-- Tenta conceder permissão nativa de escrita no VFS do FXServer se suportado
			if type(ExecuteCommand) == 'function' then
				local currentRes = type(GetCurrentResourceName) == 'function' and GetCurrentResourceName() or 'coe_supervisor'
				pcall(function()
					ExecuteCommand(('add_filesystem_permission %s write %s'):format(currentRes, item.resource))
				end)
			end

			local shouldSkip = false
			-- Checagem diferencial: se o hash do arquivo local for idêntico ao remoto, dispensa o download
			if item.hash then
				local localRaw = readResourceFile(item.resource, item.file)
				if type(localRaw) == 'string' then
					local localHash = Updater.Hash(localRaw, item.isBinary)
					if localHash == item.hash then
						shouldSkip = true
					end
				end
			end

			if shouldSkip then
				filesSkipped = filesSkipped + 1
				filesWritten = filesWritten + 1
				updatedResources[item.resource] = true
				updateState.filesWritten = filesWritten
				updateState.filesSkipped = filesSkipped
				updateState.currentResource = item.resource
				updateState.lastProgressTime = os.time()
			else
				-- Pacing preventivo de 35ms para evitar acionar burst limiter do GitHub/Fastly
				Wait(35)

				local content, dlErr = httpGet(item.url, updaterConfig.TimeoutMs, 3)
				if not content then
					failedFile = ('%s/%s (%s)'):format(item.resource, item.file, tostring(dlErr))
					break
				end
				if not writeResourceFile(item.resource, item.file, content, item.isBinary) then
					failedFile = ('%s/%s (write_failed)'):format(item.resource, item.file)
					break
				end
				updatedResources[item.resource] = true
				filesWritten = filesWritten + 1
				updateState.filesWritten = filesWritten
				updateState.filesSkipped = filesSkipped
				updateState.currentResource = item.resource
				updateState.lastProgressTime = os.time()
			end

			if filesWritten % 10 == 0 or filesWritten == totalDl then
				publishUpdateState()
			end
			if Ansi and Ansi.PrintProgress and totalDl > 0 then
				local resChanged = (lastPrintedRes ~= item.resource)
				if filesWritten == 1 or filesWritten % 15 == 0 or filesWritten == totalDl or resChanged then
					lastPrintedRes = item.resource
					Ansi.PrintProgress(filesWritten, totalDl, item.resource)
				end
			end
		end
	end

	if failedFile then
		updateState.updating = false
		updateState.startTime = nil
		updateState.lastProgressTime = nil
		updateState.requester = nil
		updateState.lastError = 'download_failed'
		publishUpdateState()
		say('ERROR', 'update_failed', 'file=' .. failedFile)
		return false, 'update_download_failed'
	end

	if type(lastRemoteRawJson) == 'string' and lastRemoteRawJson ~= '' then
		local currentRes = type(GetCurrentResourceName) == 'function' and GetCurrentResourceName() or 'coe_supervisor'
		writeResourceFile(currentRes, 'version.json', lastRemoteRawJson)
	end

	ExecuteCommand('refresh')

	local updatedCount = 0
	for _ in pairs(updatedResources) do
		updatedCount = updatedCount + 1
	end

	updateState.updating = false
	updateState.available = false
	updateState.localVersion = plan.remoteVersion
	updateState.outdatedCount = 0
	updateState.outdatedResources = {}
	updateState.filesCount = 0
	updateState.filesWritten = filesWritten
	updateState.filesSkipped = filesSkipped
	updateState.currentResource = nil
	updateState.startTime = nil
	updateState.lastProgressTime = nil
	updateState.requester = nil
	updateState.needsRestart = true
	updateState.lastError = nil
	lastUpdatePlan = nil
	publishUpdateState()

	if Ansi and Ansi.PrintUpdateCompleted then
		Ansi.PrintUpdateCompleted({
			version = plan.remoteVersion,
			updatedResources = updatedCount,
			filesUpdated = filesWritten,
			filesSkipped = filesSkipped,
			requiresFullRestart = plan.requiresFullRestart == true
		})
	else
		say('INFO', 'update_completed', ('version=v%s resources=%d files=%d skipped=%d'):format(
			tostring(plan.remoteVersion), updatedCount, filesWritten, filesSkipped))
	end

	return true, {
		version = plan.remoteVersion,
		updatedResources = updatedCount,
		filesUpdated = filesWritten,
		filesSkipped = filesSkipped,
		requiresFullRestart = plan.requiresFullRestart == true
	}
end

exports('GetUpdateStatus', function()
	if not callerAllowed() then
		return nil
	end
	return publishUpdateState()
end)

exports('CheckForUpdates', function()
	if not callerAllowed() then
		return nil
	end
	return runCheckForUpdates(true)
end)

exports('ApplyUpdate', function(requester)
	if not callerAllowed() then
		return false, 'forbidden'
	end
	return runApplyUpdate(requester)
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
	publishUpdateState()
	while true do
		Wait(1000)

		-- Watchdog: se uma atualização estiver ativa há mais de 300 segundos sem nenhum arquivo novo ser gravado
		if updateState.updating and updateState.lastProgressTime and (os.time() - updateState.lastProgressTime > 300) then
			say('WARN', 'update_watchdog_timeout', 'Processo de atualização travado há mais de 300s sem progresso. Redefinindo estado.')
			updateState.updating = false
			updateState.startTime = nil
			updateState.lastProgressTime = nil
			updateState.requester = nil
			updateState.lastError = 'watchdog_timeout'
			publishUpdateState()
		end

		if replaceConfig.Enabled ~= false and not running and GetGameTimer() - lastChange >= (replaceConfig.SettleMs or 4000) then
			settled = true
			if dirty then
				dirty = false
				local ok, err = pcall(reconcile)
				if not ok then
					say('ERROR', 'replace_reconcile_failed', tostring(err))
				end
			end
			if not startupUpdateChecked then
				startupUpdateChecked = true
				local enabledConvar = type(GetConvar) == 'function' and GetConvar('coe_updater_enabled', 'true') or 'true'
				if updaterConfig.Enabled ~= false and updaterConfig.CheckOnStartup ~= false and enabledConvar ~= 'false' and enabledConvar ~= '0' then
					CreateThread(function()
						pcall(runCheckForUpdates, true)
					end)
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

RegisterCommand('coe_version', function(playerId)
	if playerId ~= 0 and not IsPlayerAceAllowed(playerId, 'command.coe_version') and not IsPlayerAceAllowed(playerId, 'coe.staff.all') then
		return
	end
	local st = publishUpdateState()
	if Ansi and Ansi.PrintVersion then
		Ansi.PrintVersion(st)
	else
		print(('[coe_supervisor] COE Framework v%s (canal: %s) | Repositório: %s (%s)'):format(
			tostring(st.localVersion), tostring(st.channel), tostring(st.repository), tostring(st.branch)))
		if st.available then
			print(('[coe_supervisor] Atualização disponível: v%s (%d resource(s)). Use "coe_update apply" para atualizar.'):format(
				tostring(st.remoteVersion), st.outdatedCount or 0))
		elseif st.remoteVersion then
			print('[coe_supervisor] Todos os scripts estão na versão mais recente.')
		end
	end
end, false)

RegisterCommand('coe_update', function(playerId, args)
	if playerId ~= 0 and not IsPlayerAceAllowed(playerId, 'command.coe_update') and not IsPlayerAceAllowed(playerId, 'coe.staff.all') then
		return
	end
	local sub = type(args) == 'table' and type(args[1]) == 'string' and args[1]:lower() or 'status'
	CreateThread(function()
		if sub == 'apply' or sub == 'install' or sub == 'now' then
			if updateState.updating then
				if Ansi and Ansi.PrintUpdateInProgress then
					Ansi.PrintUpdateInProgress(updateState)
				else
					say('WARN', 'update_in_progress', ('Progresso: %d/%d arquivos em %s'):format(
						updateState.filesWritten or 0, updateState.filesCount or 0, tostring(updateState.currentResource or 'preparando')))
				end
				return
			end

			local ok, result = runApplyUpdate(playerId ~= 0 and playerId or nil)
			if not ok then
				if result == 'update_in_progress' then
					if Ansi and Ansi.PrintUpdateInProgress then
						Ansi.PrintUpdateInProgress(updateState)
					else
						say('WARN', 'coe_update_apply', 'update_in_progress')
					end
				elseif result == 'already_up_to_date' then
					print('[coe_supervisor] O servidor já está na versão mais recente.')
				else
					say('WARN', 'coe_update_apply', tostring(result))
				end
			end
		elseif sub == 'status' or sub == 'progress' or sub == 'info' then
			if updateState.updating then
				if Ansi and Ansi.PrintUpdateInProgress then
					Ansi.PrintUpdateInProgress(updateState)
				else
					print(('[coe_supervisor] Atualização em andamento: %d/%d arquivos (%s)'):format(
						updateState.filesWritten or 0, updateState.filesCount or 0, tostring(updateState.currentResource or 'preparando')))
				end
			elseif updateState.available then
				local plan = lastUpdatePlan or updateState
				printUpdateBanner(plan)
			else
				local st = publishUpdateState()
				if Ansi and Ansi.PrintVersion then
					Ansi.PrintVersion(st)
				else
					print('[coe_supervisor] Todos os scripts estão atualizados. Versão instalada: v' .. tostring(st.localVersion))
				end
			end
		elseif sub == 'reset' or sub == 'abort' or sub == 'cancel' then
			if updateState.updating then
				updateState.updating = false
				updateState.filesWritten = 0
				updateState.currentResource = nil
				updateState.startTime = nil
				updateState.lastProgressTime = nil
				updateState.requester = nil
				updateState.lastError = 'cancelled_by_admin'
				publishUpdateState()
				print('[coe_supervisor] Trava de atualização redefinida com sucesso. O processo foi cancelado.')
			else
				print('[coe_supervisor] Nenhuma atualização estava em andamento no momento.')
			end
		else
			runCheckForUpdates(true)
		end
	end)
end, false)
