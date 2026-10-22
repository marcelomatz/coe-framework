-- Fronteira do open-core: o código deste repositório (MIT) não pode depender de resources que não estão nele.
-- Integração com pacotes e scripts de terceiros acontece por ACE (resource.<nome>), metadados de fxmanifest ou
-- exports de registro; nunca pelo nome do outro resource no código daqui.
--
-- Uso (na raiz do repositório):
--   lua tools/check_boundary.lua            falha se houver referência nova fora da baseline
--   lua tools/check_boundary.lua --update   reescreve a baseline com as referências atuais
--
-- A baseline (tools/boundary_baseline.txt) lista as referências antigas que ainda serão removidas. Ela só pode
-- diminuir: referência nova falha; referência que sumiu pede para atualizar a baseline.

local BASELINE = 'tools/boundary_baseline.txt'
-- Nomes do framework que não são resources (namespace de evento do Core.Locale).
local notResources = { coe_locale = true }
local update = (arg and arg[1] == '--update') or os.getenv('COE_BOUNDARY_UPDATE') == '1'

local function run(command)
	local pipe = assert(io.popen(command))
	local out = {}
	for line in pipe:lines() do
		out[#out + 1] = line
	end
	pipe:close()
	return out
end

local windows = package.config:sub(1, 1) == '\\'

local function listFiles()
	if windows then
		return run('dir /s /b /a-d *.lua *.js *.html 2>nul')
	end
	return run("find . -type f \\( -name '*.lua' -o -name '*.js' -o -name '*.html' \\) 2>/dev/null")
end

local function normalize(path)
	path = path:gsub('\\', '/')
	local cwd = (windows and run('cd')[1] or run('pwd')[1] or ''):gsub('\\', '/')
	if cwd ~= '' and path:sub(1, #cwd) == cwd then
		path = path:sub(#cwd + 2)
	end
	return (path:gsub('^%./', ''))
end

local function readFile(path)
	local handle = io.open(path, 'rb')
	if not handle then
		return nil
	end
	local content = handle:read('a')
	handle:close()
	return content
end

-- Resources deste repositório: pastas da raiz com fxmanifest.lua.
local own = {}
for _, file in ipairs(listFiles()) do
	local path = normalize(file)
	local resource = path:match('^([^/]+)/fxmanifest%.lua$')
	if resource then
		own[resource] = true
	end
end

local function isOwn(name)
	if own[name] or notResources[name] then
		return true
	end
	-- Prefixo de um resource daqui (tabela, convar, evento): coe_shops_items, coe_logging_level...
	for resource in pairs(own) do
		if name:sub(1, #resource + 1) == resource .. '_' then
			return true
		end
	end
	return false
end

local function stripComments(content, isLua)
	if isLua then
		content = content:gsub('%-%-%[(=*)%[.-%]%1%]', '')
		content = content:gsub('%-%-[^\n]*', '')
	else
		content = content:gsub('/%*.-%*/', '')
		content = content:gsub('([^:])//[^\n]*', '%1')
		content = content:gsub('<!%-%-.-%-%->', '')
	end
	return content
end

-- Formas de referência a um resource: exports.x, exports['x'], nui://x/, eventos 'x:...', chave de allowlist
-- (x = true), comparação com GetInvokingResource() e o nome como primeiro argumento de uma chamada.
local patterns = {
	'exports%.(coe[%w_]+)',
	'exports%[%s*[\'"](coe[%w_]+)[\'"]%s*%]',
	'nui://(coe[%w_]+)/',
	'[\'"](coe[%w_]+):%a',
	'%f[%w_](coe[%w_]+)%s*=%s*true',
	'GetInvokingResource%(%)%s*[~=]=%s*[\'"](coe[%w_]+)[\'"]'
}
-- Chamadas cujo primeiro argumento é nome de convar, comando, tecla, KVP ou state bag (não de resource).
local notResourceCalls = {
	GetConvar = true, GetConvarInt = true, RegisterCommand = true, RegisterKeyMapping = true, ExecuteCommand = true,
	SetResourceKvp = true, SetResourceKvpInt = true, GetResourceKvpString = true, GetResourceKvpInt = true,
	DeleteResourceKvp = true, AddEventHandler = true, RegisterNetEvent = true, TriggerEvent = true,
	TriggerServerEvent = true, TriggerClientEvent = true, RegisterNUICallback = true, post = true,
	getElementById = true, querySelector = true, AddStateBagChangeHandler = true
}
local callPattern = '([%w_%.:]+)%(%s*[\'"](coe[%w_]+)[\'"]'

local skipDir = { test = true, tests = true, tools = true, node_modules = true, ['.git'] = true }

local found = {}
for _, file in ipairs(listFiles()) do
	local path = normalize(file)
	local skip = false
	for part in path:gmatch('[^/]+') do
		if skipDir[part] then
			skip = true
		end
	end
	if not skip and path:find('/') then
		local content = readFile(path)
		if content then
			content = stripComments(content, path:match('%.lua$') ~= nil)
			for _, pattern in ipairs(patterns) do
				for name in content:gmatch(pattern) do
					if not isOwn(name) then
						found[path .. ' ' .. name] = true
					end
				end
			end
			for fn, name in content:gmatch(callPattern) do
				local short = fn:match('([%w_]+)$')
				if not notResourceCalls[short] and not isOwn(name) then
					found[path .. ' ' .. name] = true
				end
			end
		end
	end
end

local current = {}
for key in pairs(found) do
	current[#current + 1] = key
end
table.sort(current)

if update then
	local handle = assert(io.open(BASELINE, 'wb'))
	handle:write('# Referências a resources de fora deste repositório que ainda serão removidas (arquivo nome).\n')
	handle:write('# Gerado por lua tools/check_boundary.lua --update. Esta lista só pode diminuir.\n')
	for _, key in ipairs(current) do
		handle:write(key, '\n')
	end
	handle:close()
	print(('baseline atualizada: %d referência(s)'):format(#current))
	return
end

local baseline = {}
for line in (readFile(BASELINE) or ''):gmatch('[^\r\n]+') do
	if line:sub(1, 1) ~= '#' then
		baseline[line] = true
	end
end

local added, removed = {}, {}
for _, key in ipairs(current) do
	if not baseline[key] then
		added[#added + 1] = key
	end
end
for key in pairs(baseline) do
	if not found[key] then
		removed[#removed + 1] = key
	end
end
table.sort(removed)

for _, key in ipairs(added) do
	print('ERRO  referência a resource de fora do repositório: ' .. key)
end
for _, key in ipairs(removed) do
	print('AVISO referência removida; rode --update para encolher a baseline: ' .. key)
end
print(('fronteira: %d na baseline, %d nova(s), %d removida(s)'):format(#current - #added, #added, #removed))
if #added > 0 or #removed > 0 then
	os.exit(1)
end
