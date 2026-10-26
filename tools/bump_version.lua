-- tools/bump_version.lua
-- Sincroniza a versão de release do COE Framework em:
--   1. version.json (raiz do repositório)
--   2. coe_supervisor/version.json (embutido no supervisor para leitura em runtime via LoadResourceFile)
--   3. fxmanifest.lua de todos os 27 resources do framework
--   4. recipe.yaml (txAdmin Recipe)
--
-- Uso:
--   lua tools/bump_version.lua <versao> [--notes "Notas da release"]
--   lua tools/bump_version.lua --check

local isWin = package.config:sub(1, 1) == '\\'

local function normalizePath(p)
	return (p:gsub('\\', '/'))
end

local function readFile(path)
	local f = io.open(path, 'rb')
	if not f then
		return nil
	end
	local content = f:read('*a')
	f:close()
	return content
end

local function writeFile(path, content)
	local f = assert(io.open(path, 'wb'))
	f:write(content)
	f:close()
end

local function fileExists(path)
	local f = io.open(path, 'rb')
	if f then
		f:close()
		return true
	end
	return false
end

local function toUtf8(str)
	if not str or str == '' then return str end
	if pcall(utf8.len, str) and utf8.len(str) ~= nil then
		return str
	end
	local out = {}
	local i = 1
	local len = #str
	while i <= len do
		local b = str:byte(i)
		if b < 128 then
			out[#out + 1] = string.char(b)
			i = i + 1
		elseif b >= 192 and b <= 223 and i + 1 <= len and str:byte(i + 1) >= 128 and str:byte(i + 1) <= 191 then
			out[#out + 1] = str:sub(i, i + 1)
			i = i + 2
		elseif b >= 224 and b <= 239 and i + 2 <= len and str:byte(i + 1) >= 128 and str:byte(i + 1) <= 191 and str:byte(i + 2) >= 128 and str:byte(i + 2) <= 191 then
			out[#out + 1] = str:sub(i, i + 2)
			i = i + 3
		elseif b >= 240 and b <= 247 and i + 3 <= len and str:byte(i + 1) >= 128 and str:byte(i + 1) <= 191 and str:byte(i + 2) >= 128 and str:byte(i + 2) <= 191 and str:byte(i + 3) >= 128 and str:byte(i + 3) <= 191 then
			out[#out + 1] = str:sub(i, i + 3)
			i = i + 4
		else
			if b >= 128 and b <= 255 then
				pcall(function() out[#out + 1] = utf8.char(b) end)
			else
				out[#out + 1] = string.char(b)
			end
			i = i + 1
		end
	end
	return table.concat(out)
end

local function parseChannel(version)
	local pre = version:match('^%d+%.%d+%.%d+%-(%a+)')
	if not pre then
		return 'stable'
	end
	pre = pre:lower()
	if pre == 'alpha' or pre == 'beta' or pre == 'rc' then
		return pre
	end
	return 'prerelease'
end

local function validateSemVer(version)
	if type(version) ~= 'string' then
		return false
	end
	local major, minor, patch, rest = version:match('^(%d+)%.(%d+)%.(%d+)(.*)$')
	if not major then
		return false
	end
	if rest == '' then
		return true
	end
	return rest:match('^%-[0-9A-Za-z%.%-]+$') ~= nil
end

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

local function listRuntimeFiles(res)
	local cmd = isWin and ('dir /b /s /a-d "' .. res .. '"') or ('find "' .. res .. '" -type f')
	local pipe = io.popen(cmd)
	if not pipe then
		return {}
	end
	local files = {}
	for line in pipe:lines() do
		line = normalizePath(line:gsub('[\r\n]', ''))
		local rel = line:match('^.*/' .. res:gsub('%-', '%%-') .. '/(.+)$') or line:match('^' .. res:gsub('%-', '%%-') .. '/(.+)$')
		if rel then
			local skip = false
			if rel:match('^test/') or rel:match('/test/') or rel:match('^tests/') or rel:match('/tests/') then
				skip = true
			elseif rel:match('^node_modules/') or rel:match('/node_modules/') then
				skip = true
			elseif rel == 'types.lua' or rel == 'package-lock.json' or rel == '.gitignore' or rel == '.luarc.json' then
				skip = true
			elseif rel:match('%.md$') or rel:match('%.log$') or rel:match('%.tmp$') or rel:match('%.bak$') then
				skip = true
			elseif rel:match('_test%.lua$') or rel:match('%.test%.js$') then
				skip = true
			end
			if not skip then
				files[#files + 1] = rel
			end
		end
	end
	pipe:close()
	table.sort(files)
	return files
end

local function jsonEscape(str)
	return (tostring(str):gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\r', '\\r'):gsub('\n', '\\n'):gsub('\t', '\\t'))
end

local function updateManifestVersion(manifestContent, newVersion)
	local eol = manifestContent:find('\r\n', 1, true) and '\r\n' or '\n'
	local norm = manifestContent:gsub('\r\n', '\n')
	if norm:match('\nversion%s+[\'"][^\'"]*[\'"]') or norm:match('^version%s+[\'"][^\'"]*[\'"]') then
		norm = norm:gsub('(\nversion%s+[\'"])[^\'"]*([\'"])', '%1' .. newVersion .. '%2', 1)
		norm = norm:gsub('(^version%s+[\'"])[^\'"]*([\'"])', '%1' .. newVersion .. '%2', 1)
	elseif norm:match('\nname%s+[\'"][^\'"]*[\'"]') then
		norm = norm:gsub('(\nname%s+[\'"][^\'"]*[\'"])', '%1\nversion \'' .. newVersion .. '\'', 1)
	elseif norm:match('\nlua54%s+[\'"][^\'"]*[\'"]') then
		norm = norm:gsub('(\nlua54%s+[\'"][^\'"]*[\'"])', '%1\nversion \'' .. newVersion .. '\'', 1)
	else
		norm = 'version \'' .. newVersion .. '\'\n' .. norm
	end
	if eol == '\r\n' then
		norm = norm:gsub('\n', '\r\n')
	end
	return norm
end

local function updateRecipeVersion(recipeContent, newVersion)
	local eol = recipeContent:find('\r\n', 1, true) and '\r\n' or '\n'
	local norm = recipeContent:gsub('\r\n', '\n')
	norm = norm:gsub('(\nversion:%s*")[^"]*(")', '%1' .. newVersion .. '%2', 1)
	if eol == '\r\n' then
		norm = norm:gsub('\n', '\r\n')
	end
	return norm
end

local function loadReleasesHistory(targetVersion, targetNotes)
	local list = {}
	local seen = {}
	local today = os.date('!%Y-%m-%d')

	list[#list + 1] = {
		version = targetVersion,
		tag = 'v' .. targetVersion,
		channel = parseChannel(targetVersion),
		date = today,
		notes = toUtf8(targetNotes or '')
	}
	seen[targetVersion] = true

	local function addCandidate(ver, tag, ch, dt, sm)
		if ver and not seen[ver] then
			seen[ver] = true
			list[#list + 1] = {
				version = ver,
				tag = tag or ('v' .. ver),
				channel = ch or parseChannel(ver),
				date = dt or today,
				notes = toUtf8(sm or '')
			}
		end
	end

	local webRel = readFile('../website/assets/data/releases.json') or readFile('website/assets/data/releases.json')
	if webRel then
		for block in webRel:gmatch('{([^{}]+)}') do
			local ver = block:match('"version"%s*:%s*"([^"]+)"')
			local tag = block:match('"tag"%s*:%s*"([^"]+)"')
			local ch = block:match('"channel"%s*:%s*"([^"]+)"')
			local dt = block:match('"date"%s*:%s*"([^"]+)"')
			local sm = block:match('"summaryPt"%s*:%s*"([^"]+)"') or block:match('"notes"%s*:%s*"([^"]+)"')
			if ver then
				addCandidate(ver, tag, ch, dt, sm)
			end
		end
	end

	local existRel = readFile('version.json')
	if existRel and existRel:find('"releases"%s*:', 1, true) then
		for block in existRel:gmatch('{([^{}]+)}') do
			local ver = block:match('"version"%s*:%s*"([^"]+)"')
			local tag = block:match('"tag"%s*:%s*"([^"]+)"')
			local ch = block:match('"channel"%s*:%s*"([^"]+)"')
			local dt = block:match('"date"%s*:%s*"([^"]+)"')
			local sm = block:match('"notes"%s*:%s*"([^"]+)"')
			if ver then
				addCandidate(ver, tag, ch, dt, sm)
			end
		end
	end

	return list
end

local function fnv1a(content, isBinary)
	if type(content) ~= 'string' then
		return '00000000'
	end
	local data = isBinary and content or content:gsub('\r\n', '\n')
	local hash = 0x811c9dc5
	for i = 1, #data do
		hash = ((hash ~ data:byte(i)) * 0x01000193) & 0xffffffff
	end
	return string.format('%08x', hash)
end

local function isBinaryFile(relPath)
	if not relPath then return false end
	local ext = relPath:match('%.([^%.]+)$')
	if not ext then return false end
	ext = ext:lower()
	return ext == 'webp' or ext == 'png' or ext == 'jpg' or ext == 'jpeg'
		or ext == 'gif' or ext == 'ogg' or ext == 'wav' or ext == 'mp3'
		or ext == 'ttf' or ext == 'woff' or ext == 'woff2' or ext == 'ytd' or ext == 'ydr'
end

local function buildVersionJson(version, notes, resources)
	local channel = parseChannel(version)
	local lines = {}
	lines[#lines + 1] = '{'
	lines[#lines + 1] = '\t"version": "' .. jsonEscape(version) .. '",'
	lines[#lines + 1] = '\t"tag": "v' .. jsonEscape(version) .. '",'
	lines[#lines + 1] = '\t"channel": "' .. jsonEscape(channel) .. '",'
	lines[#lines + 1] = '\t"repository": "marcelomatz/coe-framework",'
	lines[#lines + 1] = '\t"branch": "main",'
	lines[#lines + 1] = '\t"notes": "' .. jsonEscape(notes) .. '",'

	local rels = loadReleasesHistory(version, notes)
	if #rels > 0 then
		lines[#lines + 1] = '\t"releases": ['
		for rIdx, r in ipairs(rels) do
			lines[#lines + 1] = '\t\t{'
			lines[#lines + 1] = '\t\t\t"version": "' .. jsonEscape(r.version) .. '",'
			lines[#lines + 1] = '\t\t\t"tag": "' .. jsonEscape(r.tag) .. '",'
			lines[#lines + 1] = '\t\t\t"channel": "' .. jsonEscape(r.channel) .. '",'
			lines[#lines + 1] = '\t\t\t"date": "' .. jsonEscape(r.date) .. '",'
			lines[#lines + 1] = '\t\t\t"notes": "' .. jsonEscape(r.notes) .. '"'
			local rComma = rIdx < #rels and ',' or ''
			lines[#lines + 1] = '\t\t}' .. rComma
		end
		lines[#lines + 1] = '\t],'
	end

	lines[#lines + 1] = '\t"resources": {'
	for idx, res in ipairs(resources) do
		local files = listRuntimeFiles(res)
		lines[#lines + 1] = '\t\t"' .. jsonEscape(res) .. '": {'
		lines[#lines + 1] = '\t\t\t"version": "' .. jsonEscape(version) .. '",'
		lines[#lines + 1] = '\t\t\t"files": ['
		for fIdx, rel in ipairs(files) do
			local comma = fIdx < #files and ',' or ''
			lines[#lines + 1] = '\t\t\t\t"' .. jsonEscape(rel) .. '"' .. comma
		end
		lines[#lines + 1] = '\t\t\t],'
		lines[#lines + 1] = '\t\t\t"hashes": {'
		for fIdx, rel in ipairs(files) do
			local filePath = res .. '/' .. rel
			local f = io.open(filePath, 'rb')
			local fileContent = f and f:read('*a') or ''
			if f then f:close() end
			local h = fnv1a(fileContent, isBinaryFile(rel))
			local comma = fIdx < #files and ',' or ''
			lines[#lines + 1] = '\t\t\t\t"' .. jsonEscape(rel) .. '": "' .. h .. '"' .. comma
		end
		lines[#lines + 1] = '\t\t\t}'
		local resComma = idx < #resources and ',' or ''
		lines[#lines + 1] = '\t\t}' .. resComma
	end
	lines[#lines + 1] = '\t}'
	lines[#lines + 1] = '}\n'
	return table.concat(lines, '\n')
end

local mode = arg and arg[1]
if not mode or mode == '--help' then
	print('Uso:')
	print('  lua tools/bump_version.lua <versao> [--notes "Resumo da release"]')
	print('  lua tools/bump_version.lua --check')
	os.exit(0)
end

local resources = listResources()

if mode == '--check' then
	local rootJson = readFile('version.json')
	local supJson = readFile('coe_supervisor/version.json')
	if not rootJson then
		print('[ERRO] version.json não encontrado na raiz.')
		os.exit(1)
	end
	local version = rootJson:match('"version"%s*:%s*"([^"]+)"')
	if not version or not validateSemVer(version) then
		print('[ERRO] Versão inválida em version.json: ' .. tostring(version))
		os.exit(1)
	end
	if rootJson:gsub('\r\n', '\n') ~= (supJson or ''):gsub('\r\n', '\n') then
		print('[ERRO] coe_supervisor/version.json está dessincronizado de version.json.')
		os.exit(1)
	end
	local errors = 0
	for _, res in ipairs(resources) do
		local mf = readFile(res .. '/fxmanifest.lua') or ''
		local mfVer = mf:match('\nversion%s+[\'"]([^\'"]+)[\'"]') or mf:match('^version%s+[\'"]([^\'"]+)[\'"]')
		if mfVer ~= version then
			print(string.format('[ERRO] %s/fxmanifest.lua tem version=%s (esperado %s)', res, tostring(mfVer), version))
			errors = errors + 1
		end
	end
	if errors > 0 then
		os.exit(1)
	end
	print(string.format('[OK] Versão %s (%s) sincronizada em %d resources.', version, parseChannel(version), #resources))
	os.exit(0)
end

local targetVersion = mode:gsub('^v', '')
if not validateSemVer(targetVersion) then
	print('[ERRO] Versão SemVer inválida: ' .. tostring(mode) .. ' (ex.: 0.1.0-beta.1, 0.1.0-rc.1, 0.1.0)')
	os.exit(1)
end

local notes = nil
local notesFile = nil
local skipDocsSync = false
for i = 2, #(arg or {}) do
	if arg[i] == '--notes' and arg[i + 1] then
		notes = arg[i + 1]
	elseif arg[i] == '--notes-file' and arg[i + 1] then
		notesFile = arg[i + 1]
	elseif arg[i] == '--no-docs-sync' then
		skipDocsSync = true
	end
end
if not notes or notes == '' then
	local existing = readFile('version.json')
	local existingNotes = existing and existing:match('"notes"%s*:%s*"([^"]*)"')
	notes = existingNotes or ('COE Framework v' .. targetVersion .. ' — FiveM Enhanced Gen9 (Build 170+)')
end
notes = toUtf8(notes)

for _, res in ipairs(resources) do
	local path = res .. '/fxmanifest.lua'
	local content = readFile(path)
	if content then
		writeFile(path, updateManifestVersion(content, targetVersion))
	end
end

local recipe = readFile('recipe.yaml')
if recipe then
	writeFile('recipe.yaml', updateRecipeVersion(recipe, targetVersion))
end

-- Garante que coe_supervisor/version.json já exista antes de listar os arquivos de coe_supervisor
if not fileExists('coe_supervisor/version.json') then
	writeFile('coe_supervisor/version.json', '{}\n')
end

local jsonContent = buildVersionJson(targetVersion, notes, resources)
writeFile('version.json', jsonContent)
writeFile('coe_supervisor/version.json', jsonContent)

print(string.format('[OK] Versão atualizada para v%s (canal: %s) em %d resources, version.json e recipe.yaml.',
	targetVersion, parseChannel(targetVersion), #resources))

if not skipDocsSync and fileExists('tools/sync_release_docs_web.js') then
	local syncCmd = 'node tools/sync_release_docs_web.js'
	if notesFile and notesFile ~= '' then
		syncCmd = syncCmd .. ' --notes-file "' .. notesFile:gsub('"', '\\"') .. '"'
	end
	if notes and notes ~= '' then
		syncCmd = syncCmd .. ' --summary "' .. notes:gsub('"', '\\"') .. '"'
	end
	os.execute(syncCmd)
end
