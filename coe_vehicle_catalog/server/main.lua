local config = CoeVehicleCatalogConfig
local ready = false
local scanPending = false

local function log(level, category, event, context)
	pcall(function()
		return exports.coe_logging:Log(level, category, event, context)
	end)
end

local function audit(event, context)
	pcall(function()
		return exports.coe_audit:Record('info', 'audit', event, context)
	end)
end

local catalog = VehicleCatalog.New({ config = config, seed = CoeNativeVehicles })

local function callerName()
	return GetInvokingResource() or GetCurrentResourceName()
end

local function isWriter()
	return CoeAccess.Allowed(callerName(), config.Ace, config.WriterResources)
end

-- Lê os data_file de um resource; vehicles.meta e handling.meta são os únicos tipos usados.
local function readSource(resourceName)
	local source = { resource = resourceName, vehicles = {}, handlings = {}, problems = {} }
	local found = false
	for index = 0, (GetNumResourceMetadata(resourceName, 'data_file') or 0) - 1 do
		local fileType = GetResourceMetadata(resourceName, 'data_file', index)
		local path = GetResourceMetadata(resourceName, 'data_file_extra', index)
		local isVehicle = config.VehicleMetaTypes[fileType] == true
		local isHandling = config.HandlingMetaTypes[fileType] == true
		if (isVehicle or isHandling) and type(path) == 'string' then
			found = true
			if path:find('*', 1, true) then
				source.problems[#source.problems + 1] = 'glob_not_supported'
			else
				local content = LoadResourceFile(resourceName, path)
				if not content then
					source.problems[#source.problems + 1] = 'meta_file_not_found'
				elseif isVehicle then
					for _, entry in ipairs(VehicleMeta.ParseVehicles(content) or {}) do
						source.vehicles[#source.vehicles + 1] = entry
					end
				else
					for _, entry in ipairs(VehicleMeta.ParseHandling(content) or {}) do
						source.handlings[#source.handlings + 1] = entry
					end
				end
			end
		end
	end
	return found and source or nil
end

local function scan()
	local sources = {}
	for index = 0, GetNumResources() - 1 do
		local resourceName = GetResourceByFindIndex(index)
		local state = resourceName and GetResourceState(resourceName)
		if resourceName and resourceName ~= GetCurrentResourceName() and (state == 'started' or state == 'starting') then
			local source = readSource(resourceName)
			if source then
				sources[#sources + 1] = source
			end
		end
	end
	table.sort(sources, function(a, b) return a.resource < b.resource end)
	catalog.Rebuild(sources)

	local errors = 0
	for _, issue in ipairs(catalog.Issues()) do
		if issue.level == 'error' then
			errors = errors + 1
		end
	end
	log('info', 'catalog', 'vehicle_catalog_scanned', { count = catalog.Count(), result = tostring(errors) })
end

-- Vários resources iniciando juntos disparam uma única varredura.
local function scheduleScan()
	if scanPending or not ready then
		return
	end
	scanPending = true
	SetTimeout(config.RescanDebounceMs, function()
		scanPending = false
		scan()
	end)
end

AddEventHandler('onResourceStart', function(resourceName)
	if resourceName ~= GetCurrentResourceName() then
		scheduleScan()
	end
end)

AddEventHandler('onResourceStop', function(resourceName)
	if resourceName ~= GetCurrentResourceName() then
		scheduleScan()
	end
end)

exports('GetVehicleInfo', function(model)
	return catalog.GetVehicleInfo(model)
end)

exports('ListVehicles', function(filter)
	return catalog.List(filter)
end)

exports('GetBaseHandling', function(model)
	return catalog.GetBaseHandling(model)
end)

exports('GetIssues', function()
	return catalog.Issues()
end)

exports('SetOverride', function(model, fields)
	if not isWriter() then
		return 'forbidden'
	end
	if not ready then
		return 'not_ready'
	end
	local previous = catalog.GetOverride(type(model) == 'string' and model:lower() or '')
	local merged, normalizedModel = catalog.MergeOverride(model, fields)
	if not merged then
		return normalizedModel or 'invalid_override'
	end
	local saved, errorCode = VehicleCatalogPersistence.SaveOverride(normalizedModel, merged)
	if not saved then
		catalog.RestoreOverride(normalizedModel, previous)
		return errorCode or 'database_error'
	end
	audit('vehicle_override_set', { model = normalizedModel, operation = callerName() })
	return true
end)

exports('ClearOverride', function(model)
	if not isWriter() then
		return 'forbidden'
	end
	if not ready then
		return 'not_ready'
	end
	local normalized = type(model) == 'string' and model:lower() or ''
	local previous = catalog.GetOverride(normalized)
	local removed, removeError = catalog.RemoveOverride(normalized)
	if not removed then
		return removeError
	end
	local deleted, errorCode = VehicleCatalogPersistence.DeleteOverride(normalized)
	if not deleted then
		catalog.RestoreOverride(normalized, previous)
		return errorCode or 'database_error'
	end
	audit('vehicle_override_cleared', { model = normalized, operation = callerName() })
	return true
end)

exports('Rescan', function()
	if not isWriter() then
		return 'forbidden'
	end
	scan()
	return true
end)

exports('IsReady', function()
	return ready
end)

-- Ferramentas de operação (ACE: command.coe_catalog_*).
RegisterCommand('coe_catalog_rescan', function()
	scan()
	print(('[coe_vehicle_catalog] %d veículos, %d avisos.'):format(catalog.Count(), #catalog.Issues()))
end, true)

RegisterCommand('coe_catalog_issues', function()
	local issues = catalog.Issues()
	if #issues == 0 then
		print('[coe_vehicle_catalog] Nenhum problema.')
	end
	for _, issue in ipairs(issues) do
		print(('[coe_vehicle_catalog] %s %s model=%s resource=%s'):format(
			issue.level, issue.code, tostring(issue.model), tostring(issue.resource)))
	end
end, true)

RegisterCommand('coe_catalog_info', function(_, args)
	local info = catalog.GetVehicleInfo(args[1])
	if not info then
		print('[coe_vehicle_catalog] Modelo não encontrado.')
		return
	end
	print(('[coe_vehicle_catalog] %s | %s %s | %s/%s | preço %d | addon=%s | handling=%s'):format(
		info.model, tostring(info.brand), tostring(info.name), info.class, info.type, info.price,
		tostring(info.isAddon), tostring(info.hasHandling)))
end, true)

CreateThread(function()
	local waitingLogged = false
	while true do
		local initialized, errorCode = VehicleCatalogPersistence.Initialize()
		local overrides
		if initialized then
			overrides, errorCode = VehicleCatalogPersistence.LoadOverrides()
			initialized = overrides ~= nil
		end
		if initialized then
			catalog.SetOverrides(overrides)
			break
		end
		if errorCode == 'database_not_ready' then
			if not waitingLogged then
				log('info', 'persistence', 'database_waiting', {})
				waitingLogged = true
			end
			Wait(1000)
		else
			log('error', 'persistence', 'database_initialization_failed', {
				error_code = errorCode or 'database_error',
				retry_ms = 5000
			})
			Wait(5000)
		end
	end
	ready = true
	scan()
end)
