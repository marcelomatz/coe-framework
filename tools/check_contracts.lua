-- tools/check_contracts.lua
-- Valida manifestos (fxmanifest.lua), contratos de exports (types.lua), integridade de arquivos e chamadas entre resources.
-- Uso: lua tools/check_contracts.lua [--strict] [--verbose]

local isWin = package.config:sub(1, 1) == '\\'
local strict = false
local verbose = false
local auditNatives = false
local auditLocales = false

for i = 1, #(arg or {}) do
	if arg[i] == '--strict' then
		strict = true
	elseif arg[i] == '--verbose' then
		verbose = true
	elseif arg[i] == '--audit-natives' then
		auditNatives = true
	elseif arg[i] == '--audit-locales' then
		auditLocales = true
	elseif arg[i] == '--help' then
		print('Uso: lua tools/check_contracts.lua [opções]')
		print('Opções:')
		print('  --strict         Trata avisos (ex.: exports não anotados em types.lua) como erros')
		print('  --verbose        Exibe detalhes de cada verificação')
		print('  --audit-natives  Exibe relatório de auditoria de conformidade de natives da plataforma')
		print('  --audit-locales  Exibe relatório de auditoria de conformidade de internacionalização (i18n)')
		print('  --help           Exibe esta ajuda')
		os.exit(0)
	end
end

local function normalizePath(p)
	return p:gsub('\\', '/')
end

local function readFile(path)
	local f = io.open(path, 'rb')
	if not f then return nil end
	local content = f:read('*a'):gsub('\r\n', '\n')
	f:close()
	return content
end

local function fileExists(path)
	local f = io.open(path, 'rb')
	if f then
		f:close()
		return true
	end
	return false
end

-- Lista diretórios que possuem fxmanifest.lua
local function listResources()
	local cmd = isWin and 'dir /b /ad' or 'ls -1'
	local pipe = assert(io.popen(cmd))
	local resources = {}
	for name in pipe:lines() do
		name = name:gsub('[/\r\n]', '')
		if name ~= '' and not name:match('^%.') and name ~= 'node_modules' and name ~= 'Claude outputs' and name ~= 'reference' and name ~= 'tools' then
			if fileExists(name .. '/fxmanifest.lua') then
				resources[#resources + 1] = name
			end
		end
	end
	pipe:close()
	table.sort(resources)
	return resources
end

local resources = listResources()
local resourceSet = {}
for _, res in ipairs(resources) do
	resourceSet[res] = true
end

-- Varre arquivos .lua e .js de um resource (excluindo testes e node_modules)
local function listResourceFiles(res)
	local cmd = isWin and ('dir /b /s /a-d "' .. res .. '"') or ('find "' .. res .. '" -type f')
	local pipe = io.popen(cmd)
	if not pipe then return {} end
	local files = {}
	for line in pipe:lines() do
		line = normalizePath(line:gsub('[\r\n]', ''))
		if not line:match('/test/') and not line:match('/tests/') and not line:match('/node_modules/') and not line:match('/types%.lua$') then
			if line:match('%.lua$') or line:match('%.js$') then
				files[#files + 1] = line
			end
		end
	end
	pipe:close()
	table.sort(files)
	return files
end

local resData = {}
for _, res in ipairs(resources) do
	resData[res] = {
		name = res,
		manifestPath = res .. '/fxmanifest.lua',
		typesPath = res .. '/types.lua',
		hasTypes = fileExists(res .. '/types.lua'),
		manifestExports = {},
		manifestDeps = {},
		codeExports = {},
		typesExports = {},
		allExports = {},
		files = listResourceFiles(res)
	}
end

local errors = {}
local warnings = {}
local totalCrossCalls = 0
local totalVerifiedExports = 0

local function addError(category, res, msg, file, line)
	local loc = file and (file .. (line and (':' .. line) or '')) or res
	errors[#errors + 1] = string.format('[ERROR][%s] %s: %s', category, loc, msg)
end

local function addWarning(category, res, msg, file, line)
	local loc = file and (file .. (line and (':' .. line) or '')) or res
	warnings[#warnings + 1] = string.format('[WARN][%s] %s: %s', category, loc, msg)
end

-- 1. Validação de estrutura e arquivos declarados no fxmanifest.lua
for _, res in ipairs(resources) do
	local data = resData[res]
	local content = readFile(data.manifestPath)
	if not content then
		addError('manifest', res, 'Não foi possível ler fxmanifest.lua')
	else
		if not content:match('fx_version%s+[\'"][^\'"]+[\'"]') then
			addError('manifest', res, 'fx_version não declarada no fxmanifest.lua')
		end
		if not content:match('game%s+[\'"][^\'"]+[\'"]') and not content:match('games%s+%b{}') then
			addError('manifest', res, 'Declaração de game/games ausente no fxmanifest.lua')
		end

		local verStr = content:match('[\r\n]%s*version%s+[\'"]([^\'"]+)[\'"]') or content:match('^version%s+[\'"]([^\'"]+)[\'"]')
		if not verStr then
			addError('manifest-semver', res, 'Campo "version" ausente no fxmanifest.lua')
		else
			local cleanVer = verStr:gsub('^v', '')
			local withoutBuild = cleanVer:match('^([^%+]+)%+') or cleanVer
			local withoutPre = withoutBuild:match('^([^-]+)%-') or withoutBuild
			if not withoutPre:match('^%d+%.%d+%.%d+$') then
				addError('manifest-semver', res, string.format('Versão "%s" não segue o padrão SemVer 2.0 (ex: 1.0.0 ou 0.1.0-beta.10)', verStr))
			end
		end

		for exp in content:gmatch('(?:server_)?export%s+[\'"]([%w_]+)[\'"]') do
			data.manifestExports[exp] = true
			data.allExports[exp] = true
			totalVerifiedExports = totalVerifiedExports + 1
		end

		for dep in content:gmatch('dependency%s+[\'"]([%w_]+)[\'"]') do
			data.manifestDeps[dep] = true
		end
		for block in content:gmatch('dependencies%s*(%b{})') do
			for dep in block:gmatch('[\'"]([%w_]+)[\'"]') do
				data.manifestDeps[dep] = true
			end
		end

		local function checkFileEntry(relPath)
			if relPath:sub(1, 1) == '@' or relPath:find('*', 1, true) then
				return
			end
			local full = res .. '/' .. relPath
			if not fileExists(full) then
				addError('manifest-file', res, 'Arquivo declarado no fxmanifest não existe: ' .. relPath)
			end
		end

		for single in content:gmatch('(?:client_script|server_script|shared_script|file|ui_page)%s+[\'"]([^\'"]+)[\'"]') do
			checkFileEntry(single)
		end
		for block in content:gmatch('(?:client_scripts|server_scripts|shared_scripts|files)%s*(%b{})') do
			for path in block:gmatch('[\'"]([^\'"]+)[\'"]') do
				checkFileEntry(path)
			end
		end
	end
end

-- 2. Parsing de types.lua
for _, res in ipairs(resources) do
	local data = resData[res]
	if data.hasTypes then
		local content = readFile(data.typesPath)
		if content then
			for exp in content:gmatch('function%s+exports_[%w_]+:([%w_]+)%(') do
				data.typesExports[exp] = true
			end
		end
	end
end

-- 3. Parsing de exports registrados em código (.lua e .js)
for _, res in ipairs(resources) do
	local data = resData[res]
	for _, filePath in ipairs(data.files) do
		local content = readFile(filePath)
		if content then
			for exp in content:gmatch('exports%s*%(%s*[\'"]([%w_]+)[\'"]') do
				data.codeExports[exp] = true
				data.allExports[exp] = true
				totalVerifiedExports = totalVerifiedExports + 1
			end
			if res == 'coe_database' then
				for exp in content:gmatch('registerQueryExport%s*%(%s*[\'"]([%w_]+)[\'"]') do
					data.codeExports[exp] = true
					data.allExports[exp] = true
					totalVerifiedExports = totalVerifiedExports + 1
				end
			end
		end
	end
end

-- 4. Validação de contratos (types.lua vs Implementação)
for _, res in ipairs(resources) do
	local data = resData[res]
	if data.hasTypes then
		for exp in pairs(data.typesExports) do
			if not data.allExports[exp] then
				addError('contract', res, string.format("Export '%s' documentado em types.lua NÃO está implementado no código ou manifesto", exp))
			end
		end
		for exp in pairs(data.allExports) do
			if not data.typesExports[exp] then
				addWarning('contract', res, string.format("Export '%s' implementado no código mas não documentado em types.lua", exp))
			end
		end
	end
end

-- 5. Validação de chamadas cruzadas de exports (exports['res']:Method())
for _, res in ipairs(resources) do
	local data = resData[res]
	for _, filePath in ipairs(data.files) do
		local content = readFile(filePath)
		if content then
			local lineNum = 1
			for line in (content .. '\n'):gmatch('([^\n]*)\n') do
				for target, method in line:gmatch('exports%[[\'"]([%w_]+)[\'"]%]%s*[:.]([%w_]+)') do
					if target ~= res and resourceSet[target] then
						totalCrossCalls = totalCrossCalls + 1
						local targetData = resData[target]
						local targetHasExport = targetData.allExports[method] or targetData.typesExports[method]
						if not targetHasExport then
							addError('cross-call', res, string.format("Chama export inexistente 'exports.%s:%s()'", target, method), filePath, lineNum)
						end
					end
				end
				for target, method in line:gmatch('exports%.([%w_]+)%s*[:.]([%w_]+)') do
					if target ~= res and resourceSet[target] then
						totalCrossCalls = totalCrossCalls + 1
						local targetData = resData[target]
						local targetHasExport = targetData.allExports[method] or targetData.typesExports[method]
						if not targetHasExport then
							addError('cross-call', res, string.format("Chama export inexistente 'exports.%s:%s()'", target, method), filePath, lineNum)
						end
					end
				end
				lineNum = lineNum + 1
			end
		end
	end
end

-- 6. Validação do grafo de dependências e detecção de dependências circulares
local visited = {}
local recStack = {}

local function checkCycle(node, path)
	visited[node] = true
	recStack[node] = true
	path[#path + 1] = node

	local data = resData[node]
	if data then
		for dep in pairs(data.manifestDeps) do
			if resourceSet[dep] then
				if not visited[dep] then
					checkCycle(dep, path)
				elseif recStack[dep] then
					local cycleStr = table.concat(path, ' -> ') .. ' -> ' .. dep
					addError('dependency-cycle', node, 'Dependência circular detectada: ' .. cycleStr)
				end
			end
		end
	end

	recStack[node] = false
	path[#path] = nil
end

for _, res in ipairs(resources) do
	if not visited[res] then
		checkCycle(res, {})
	end
end

-- 7. Validação de Namespacing e Integridade de Eventos de Rede
local cfxNativeEvents = {
	['playerConnecting'] = true,
	['playerDropped'] = true,
	['playerEnteredScope'] = true,
	['playerLeftScope'] = true,
	['onResourceStart'] = true,
	['onResourceStop'] = true,
	['onResourceStarting'] = true,
	['onServerResourceStart'] = true,
	['onServerResourceStop'] = true,
	['onClientResourceStart'] = true,
	['onClientResourceStop'] = true,
	['entityCreated'] = true,
	['entityCreating'] = true,
	['entityDamaged'] = true,
	['entityRemoved'] = true,
	['gameEventTriggered'] = true,
	['populationPedCreating'] = true,
	['chat:addMessage'] = true,
	['chat:addSuggestion'] = true,
	['chat:removeSuggestion'] = true
}

local registeredNetEvents = {}
local registeredEventSet = {}
local triggeredNetEvents = {}

for _, res in ipairs(resources) do
	local data = resData[res]
	for _, filePath in ipairs(data.files) do
		local content = readFile(filePath)
		if content then
			local lineNum = 1
			for line in (content .. '\n'):gmatch('([^\n]*)\n') do
				for ev in line:gmatch('RegisterNetEvent%s*%(%s*[\'"]([^\'"]+)[\'"]') do
					registeredNetEvents[#registeredNetEvents + 1] = { resource = res, file = filePath, line = lineNum, event = ev }
					registeredEventSet[ev] = true
				end
				for ev in line:gmatch('RegisterServerEvent%s*%(%s*[\'"]([^\'"]+)[\'"]') do
					registeredNetEvents[#registeredNetEvents + 1] = { resource = res, file = filePath, line = lineNum, event = ev }
					registeredEventSet[ev] = true
				end
				for ev in line:gmatch('TriggerServerEvent%s*%(%s*[\'"]([^\'"]+)[\'"]') do
					triggeredNetEvents[#triggeredNetEvents + 1] = { resource = res, file = filePath, line = lineNum, event = ev }
				end
				for ev in line:gmatch('TriggerClientEvent%s*%(%s*[\'"]([^\'"]+)[\'"]') do
					triggeredNetEvents[#triggeredNetEvents + 1] = { resource = res, file = filePath, line = lineNum, event = ev }
				end
				lineNum = lineNum + 1
			end
		end
	end
end

-- Valida namespacing de eventos registrados
for _, e in ipairs(registeredNetEvents) do
	local ev = e.event
	if not cfxNativeEvents[ev] and not ev:match('^txAdmin:') then
		if not ev:match('^coe_') and not ev:match('^coetarget:') and not ev:match('^' .. e.resource .. ':') then
			addError('event-namespace', e.resource, string.format("Evento de rede '%s' registrado sem namespace do resource (deve iniciar com '%s:' ou 'coe_')", ev, e.resource), e.file, e.line)
		end
	end
end

-- Valida se eventos estáticos disparados possuem handler registrado no projeto
for _, e in ipairs(triggeredNetEvents) do
	local ev = e.event
	if not cfxNativeEvents[ev] and not ev:match('^txAdmin:') and not ev:match('^chat:') then
		if not ev:match(':$') and not registeredEventSet[ev] then
			addWarning('event-orphan', e.resource, string.format("Evento '%s' disparado não possui handler registrado (RegisterNetEvent) no projeto", ev), e.file, e.line)
		end
	end
end

-- 8. Linter de Conformidade de Natives da Plataforma (Platform / HAL)
local platformMigratedResources = {
	['coe_vehicles'] = true,
	['coe_fuel'] = true
}

local platformRestrictedNatives = {
	['DoesEntityExist'] = 'Core.Platform.Entities.Exists',
	['DeleteEntity'] = 'Core.Platform.Entities.Delete',
	['GetEntityCoords'] = 'Core.Platform.Entities.GetCoords',
	['SetEntityCoords'] = 'Core.Platform.Entities.SetCoords',
	['GetEntityHeading'] = 'Core.Platform.Entities.GetHeading',
	['SetEntityHeading'] = 'Core.Platform.Entities.SetHeading',
	['GetEntityModel'] = 'Core.Platform.Entities.GetModel',
	['NetworkGetNetworkIdFromEntity'] = 'Core.Platform.Entities.GetNetworkId',
	['NetworkGetEntityFromNetworkId'] = 'Core.Platform.Entities.FromNetworkId',
	['SetVehicleNumberPlateText'] = 'Core.Platform.Vehicles.SetPlate',
	['GetVehicleNumberPlateText'] = 'Core.Platform.Vehicles.GetPlate',
	['SetVehicleDoorsLocked'] = 'Core.Platform.Vehicles.SetLocked',
	['GetVehicleDoorLockStatus'] = 'Core.Platform.Vehicles.IsLocked',
	['SetVehicleEngineHealth'] = 'Core.Platform.Vehicles.SetEngineHealth',
	['GetVehicleEngineHealth'] = 'Core.Platform.Vehicles.GetEngineHealth',
	['GetIsVehicleEngineRunning'] = 'Core.Platform.Vehicles.IsEngineRunning',
	['GetPlayerRoutingBucket'] = 'Core.Platform.Routing.GetPlayerBucket',
	['SetPlayerRoutingBucket'] = 'Core.Platform.Routing.SetPlayerBucket',
	['GetEntityRoutingBucket'] = 'Core.Platform.Routing.GetEntityBucket',
	['SetEntityRoutingBucket'] = 'Core.Platform.Routing.SetEntityBucket',
	['SetRoutingBucketPopulationEnabled'] = 'Core.Platform.Routing.SetPopulationEnabled',
	['SetRoutingBucketEntityLockdownMode'] = 'Core.Platform.Routing.SetLockdownMode'
}

local totalPlatformAuditedCalls = 0
local nativeUsageByResource = {}

for _, res in ipairs(resources) do
	local isMigrated = platformMigratedResources[res] == true
	local data = resData[res]
	for _, filePath in ipairs(data.files) do
		-- Ignora o próprio adaptador da camada de plataforma
		if not filePath:match('/coe_core/lib/platform%.lua$') then
			local content = readFile(filePath)
			if content then
				local lineNum = 1
				for line in (content .. '\n'):gmatch('([^\n]*)\n') do
					-- Ignora comentários
					local cleanLine = line:gsub('^%s*%-%-.*$', '')
					if #cleanLine > 0 then
						for nativeName, replacement in pairs(platformRestrictedNatives) do
							if cleanLine:match('%f[%w_]' .. nativeName .. '%f[^%w_]') then
								totalPlatformAuditedCalls = totalPlatformAuditedCalls + 1
								nativeUsageByResource[res] = nativeUsageByResource[res] or {}
								nativeUsageByResource[res][nativeName] = (nativeUsageByResource[res][nativeName] or 0) + 1

								if isMigrated then
									addError('platform-compliance', res, string.format("Uso de native crua '%s' em recurso migrado. Substitua por '%s'", nativeName, replacement), filePath, lineNum)
								end
							end
						end
					end
					lineNum = lineNum + 1
				end
			end
		end
	end
end

-- 9. Linter e Auditoria de Internacionalização (i18n / Core.Locale)
local i18nMigratedResources = {
	['coe_vehicles'] = true,
	['coe_core'] = true,
	['coe_inventory'] = true,
	['coe_economy'] = true,
	['coe_banking'] = true,
	['coe_businesses'] = true,
	['coe_news'] = true,
	['coe_talk'] = true,
	['coe_telecom'] = true,
	['coe_fuel'] = true,
	['coe_amzg'] = true,
	['coe_police'] = true,
	['coe_ems'] = true,
	['coe_dispatch'] = true,
	['coe_mechanic'] = true,
	['coe_housing'] = true,
	['coe_deepweb'] = true,
	['coe_jobs'] = true,
	['coe_loot'] = true,
	['coe_tablet'] = true
}

local function loadLocaleTable(filePath, langKey)
	local content = readFile(filePath)
	if not content then return nil end
	local env = setmetatable({}, { __index = _G })
	local fn = load(content, '@' .. filePath, 't', env)
	if not fn then return nil end
	pcall(fn)
	local loc = env.Locales or {}
	return loc[langKey] or {}
end

local totalI18nAuditedResources = 0
local totalLocalizedKeys = 0
local totalRawNotificationStrings = 0
local localeKeysByResource = {}
local rawNotificationsByResource = {}

for _, res in ipairs(resources) do
	local isMigrated = i18nMigratedResources[res] == true
	local ptPath = res .. '/locales/pt-br.lua'
	local enPath = res .. '/locales/en-us.lua'
	local hasPt = fileExists(ptPath)
	local hasEn = fileExists(enPath)
	local manifestContent = readFile(res .. '/fxmanifest.lua') or ''

	if hasPt or hasEn or isMigrated then
		totalI18nAuditedResources = totalI18nAuditedResources + 1

		if hasPt and not manifestContent:match('locales/pt%-br%.lua') then
			addError('i18n-manifest', res, "Arquivo 'locales/pt-br.lua' não está declarado no fxmanifest.lua", res .. '/fxmanifest.lua')
		end
		if hasEn and not manifestContent:match('locales/en%-us%.lua') then
			addError('i18n-manifest', res, "Arquivo 'locales/en-us.lua' não está declarado no fxmanifest.lua", res .. '/fxmanifest.lua')
		end

		if isMigrated and not (hasPt and hasEn) then
			addError('i18n-missing-locale', res, "Recurso migrado deve conter 'locales/pt-br.lua' e 'locales/en-us.lua'")
		end

		if hasPt and hasEn then
			local ptDict = loadLocaleTable(ptPath, 'pt-BR') or {}
			local enDict = loadLocaleTable(enPath, 'en-US') or {}
			local ptCount = 0
			local missingInEn = {}
			for k in pairs(ptDict) do
				ptCount = ptCount + 1
				if not enDict[k] then
					missingInEn[#missingInEn + 1] = k
				end
			end
			table.sort(missingInEn)
			totalLocalizedKeys = totalLocalizedKeys + ptCount
			localeKeysByResource[res] = ptCount

			if #missingInEn > 0 then
				if isMigrated then
					addError('i18n-parity', res, string.format("Chaves ausentes em en-US: %s", table.concat(missingInEn, ', ')), enPath)
				else
					addWarning('i18n-parity', res, string.format("Chaves ausentes em en-US: %s", table.concat(missingInEn, ', ')), enPath)
				end
			end
		end
	end

	local data = resData[res]
	for _, filePath in ipairs(data.files) do
		local content = readFile(filePath)
		if content then
			local lineNum = 1
			for line in (content .. '\n'):gmatch('([^\n]*)\n') do
				local clean = line:gsub('^%s*%-%-.*$', '')
				if #clean > 0 and not clean:match('_t%(') and not clean:match('Loc%(') and not clean:match('C%.t%(') and not clean:match('Core%.Locale') then
					local lit = clean:match('exports%.coe_notify:Notify%s*%([^,]+,%s*[^,]+,%s*(%b\'\')')
						or clean:match('exports%.coe_notify:Notify%s*%([^,]+,%s*[^,]+,%s*(%b"")')
						or clean:match('exports%[\'coe_notify\'%]:Notify%s*%([^,]+,%s*[^,]+,%s*(%b\'\')')
						or clean:match('exports%[\'coe_notify\'%]:Notify%s*%([^,]+,%s*[^,]+,%s*(%b"")')
						or clean:match('exports%.coe_notify:Show%s*%([^,]+,%s*(%b\'\')')
						or clean:match('exports%.coe_notify:Show%s*%([^,]+,%s*(%b"")')
						or clean:match('exports%[\'coe_notify\'%]:Show%s*%([^,]+,%s*(%b\'\')')
						or clean:match('exports%[\'coe_notify\'%]:Show%s*%([^,]+,%s*(%b"")')
						or clean:match('TriggerClientEvent%s*%(%s*[\'"]coe_notify:display[\'"]%s*,%s*[^,]+,%s*[^,]+,%s*(%b\'\')')
						or clean:match('TriggerClientEvent%s*%(%s*[\'"]coe_notify:display[\'"]%s*,%s*[^,]+,%s*[^,]+,%s*(%b"")')
						or clean:match('%f[%w_]reply%s*%([^,]+,%s*[\'"][%w_]+[\'"]%s*,%s*(%b\'\')')
						or clean:match('%f[%w_]reply%s*%([^,]+,%s*[\'"][%w_]+[\'"]%s*,%s*(%b"")')
						or clean:match('%f[%w_]notify%s*%([^,]+,%s*[\'"][%w_]+[\'"]%s*,%s*(%b\'\')')
						or clean:match('%f[%w_]notify%s*%([^,]+,%s*[\'"][%w_]+[\'"]%s*,%s*(%b"")')

					if lit and #lit > 2 then
						totalRawNotificationStrings = totalRawNotificationStrings + 1
						rawNotificationsByResource[res] = (rawNotificationsByResource[res] or 0) + 1
						if isMigrated then
							addError('i18n-hardcoded', res, string.format("String literal hardcoded %s detectada em chamada de notificação. Migre para _t() ou Core.Locale", lit), filePath, lineNum)
						end
					end
				end
				lineNum = lineNum + 1
			end
		end
	end
end

-- Relatório e encerramento
print(string.rep('=', 70))
print('🔍 VALIDAÇÃO DE MANIFESTOS, CONTRATOS E DEPENDÊNCIAS')
print(string.rep('=', 70))
print(string.format('Resources verificados:       %d', #resources))
print(string.format('Exports mapeados:            %d', totalVerifiedExports))
print(string.format('Chamadas cross-resource:     %d', totalCrossCalls))
print(string.format('Eventos de rede registrados: %d', #registeredNetEvents))
print(string.format('Disparos de rede validados:  %d', #triggeredNetEvents))
print(string.format('Natives auditadas (Platform):%d', totalPlatformAuditedCalls))
print(string.format('Chaves mapeadas (i18n):      %d', totalLocalizedKeys))
print(string.format('Notificações literais (i18n):%d', totalRawNotificationStrings))

if auditNatives or verbose then
	print('\n' .. string.rep('-', 70))
	print('📊 AUDITORIA DA CAMADA DE PLATAFORMA (Core.Platform)')
	print(string.rep('-', 70))
	print('Recursos piloto migrados (100% de conformidade estrita):')
	for res in pairs(platformMigratedResources) do
		print(string.format('  ✅ %-24s [Conforme Core.Platform]', res))
	end
	print('\nChamadas de natives detectadas em recursos a migrar:')
	for _, res in ipairs(resources) do
		if not platformMigratedResources[res] and nativeUsageByResource[res] then
			local list = {}
			for n, c in pairs(nativeUsageByResource[res]) do
				list[#list + 1] = string.format('%s (%d)', n, c)
			end
			table.sort(list)
			print(string.format('  • %-24s: %s', res, table.concat(list, ', ')))
		end
	end
	print(string.rep('-', 70))
end

if auditLocales or verbose then
	print('\n' .. string.rep('-', 70))
	print('🌐 AUDITORIA DE INTERNACIONALIZAÇÃO (Core.Locale / i18n)')
	print(string.rep('-', 70))
	print('Recursos migrados (100% de conformidade com Core.Locale):')
	local sortedMigrated = {}
	for res in pairs(i18nMigratedResources) do
		sortedMigrated[#sortedMigrated + 1] = res
	end
	table.sort(sortedMigrated)
	for _, res in ipairs(sortedMigrated) do
		local keyCount = localeKeysByResource[res] or 0
		print(string.format('  ✅ %-24s [Conforme Core.Locale - %d chaves pt-BR / en-US]', res, keyCount))
	end
	if next(rawNotificationsByResource) then
		print('\nNotificações com strings literais detectadas a migrar:')
		for _, res in ipairs(resources) do
			if not i18nMigratedResources[res] and rawNotificationsByResource[res] then
				print(string.format('  • %-24s: %d notificação(ões) literal(is)', res, rawNotificationsByResource[res]))
			end
		end
	end
	print(string.rep('-', 70))
end

if verbose then
	print('\nResources validados:')
	for _, res in ipairs(resources) do
		local d = resData[res]
		local expCount = 0
		for _ in pairs(d.allExports) do expCount = expCount + 1 end
		print(string.format('  ✓ %-24s (%d exports, %d arquivos)', res, expCount, #d.files))
	end
end

if #errors > 0 then
	print(string.format('\n❌ %d ERRO(S) ENCONTRADO(S):', #errors))
	for _, err in ipairs(errors) do
		print('  ' .. err)
	end
else
	print('\n✅ Todos os contratos, manifestos e chamadas cruzadas foram validados com sucesso!')
end

if #warnings > 0 then
	print(string.format('\n⚠️  %d AVISO(S) (exports sem anotação em types.lua):', #warnings))
	for _, warn in ipairs(warnings) do
		print('  ' .. warn)
	end
end

print(string.rep('-', 70))
print(string.format('Resultado: %d erro(s), %d aviso(s)', #errors, #warnings))
print(string.rep('=', 70))

if #errors > 0 or (strict and #warnings > 0) then
	os.exit(1)
end
