-- Gera reference/<resource>.md e reference/README.md a partir dos types.lua (anotações LuaLS).
-- Uso (na raiz do repositório): lua tools/gen_reference.lua [--check]
-- Com --check, falha se algum arquivo gerado estiver diferente do versionado.

local check = arg and arg[1] == '--check'

local function readLines(path)
	local file = assert(io.open(path, 'rb'))
	local content = file:read('a'):gsub('\r\n', '\n')
	file:close()
	local lines = {}
	for line in (content .. '\n'):gmatch('([^\n]*)\n') do
		lines[#lines + 1] = line
	end
	return lines
end

local function escapeCell(text)
	return (text:gsub('|', '\\|'))
end

local function parse(path)
	local result = { intro = {}, exports = {}, types = {} }
	local doc, typeLines = {}, nil
	local seenMeta = false

	local function flushType()
		if typeLines then
			-- A classe `Coe<Nome>Exports` só serve de receptor das funções; não entra em "Tipos".
			if not typeLines[1]:match('^%-%-%-@class%s+%w+Exports%s*$') then
				result.types[#result.types + 1] = table.concat(typeLines, '\n')
			end
			typeLines = nil
		end
	end

	for _, line in ipairs(readLines(path)) do
		local annotation = line:match('^%-%-%-(.*)$')
		local exportName, exportArgs = line:match('^function exports_[%w_]+:([%w_]+)%((.-)%)%s*end')
		if exportName then
			flushType()
			local item = { name = exportName, args = exportArgs, text = {}, params = {}, returns = {} }
			for _, entry in ipairs(doc) do
				local name, rest = entry:match('^@param%s+(%S+)%s*(.*)$')
				local ret = entry:match('^@return%s+(.*)$')
				if name then
					local typ, desc = rest:match('^(%S+)%s*(.*)$')
					item.params[#item.params + 1] = { name = name, type = typ or '', desc = desc or '' }
				elseif ret then
					local typ, rname, desc = ret:match('^(%S+)%s*(%S*)%s*(.*)$')
					item.returns[#item.returns + 1] = { type = typ or '', name = rname or '', desc = desc or '' }
				elseif not entry:match('^@') and entry ~= '' then
					item.text[#item.text + 1] = entry
				end
			end
			result.exports[#result.exports + 1] = item
			doc = {}
		elseif annotation then
			if annotation == '@meta' then
				seenMeta = true
			elseif annotation:match('^@class') or annotation:match('^@alias') then
				flushType()
				typeLines = { '---' .. annotation }
				doc = {}
			elseif typeLines and annotation:match('^@field') then
				typeLines[#typeLines + 1] = '---' .. annotation
			else
				doc[#doc + 1] = (annotation:gsub('^%s+', ''))
			end
		elseif line:match('^%-%- ') and seenMeta and #result.exports == 0 and not typeLines then
			local text = line:sub(4)
		if not text:match('^Contrato p') and not text:match('^Ver docs') then
				result.intro[#result.intro + 1] = text
			end
		elseif line:match('^local exports_') then
			flushType()
			doc = {}
		elseif line == '' then
			flushType()
		end
	end
	flushType()
	return result
end

local function render(resource, parsed)
	local out = { '# ' .. resource .. ' — referência da API', '' }
	out[#out + 1] = '> Gerado de `' .. resource .. '/types.lua` por `tools/gen_reference.lua`. Não edite à mão.'
	out[#out + 1] = ''
	for _, line in ipairs(parsed.intro) do
		out[#out + 1] = line
	end
	if #parsed.intro > 0 then
		out[#out + 1] = ''
	end

	out[#out + 1] = '## Exports'
	out[#out + 1] = ''
	for _, item in ipairs(parsed.exports) do
		out[#out + 1] = '### `' .. item.name .. '(' .. item.args .. ')`'
		out[#out + 1] = ''
		if #item.text > 0 then
			out[#out + 1] = table.concat(item.text, ' ')
			out[#out + 1] = ''
		end
		if #item.params > 0 then
			out[#out + 1] = '| Parâmetro | Tipo | Descrição |'
			out[#out + 1] = '|---|---|---|'
			for _, param in ipairs(item.params) do
				out[#out + 1] = ('| `%s` | `%s` | %s |'):format(param.name, escapeCell(param.type), escapeCell(param.desc))
			end
			out[#out + 1] = ''
		end
		if #item.returns > 0 then
			out[#out + 1] = '**Retorno**'
			out[#out + 1] = ''
			for _, ret in ipairs(item.returns) do
				local label = ret.name ~= '' and (' `' .. ret.name .. '`') or ''
				local desc = ret.desc ~= '' and (' — ' .. ret.desc) or ''
				out[#out + 1] = ('- `%s`%s%s'):format(ret.type, label, desc)
			end
			out[#out + 1] = ''
		end
	end

	if #parsed.types > 0 then
		out[#out + 1] = '## Tipos'
		out[#out + 1] = ''
		out[#out + 1] = '```lua'
		out[#out + 1] = table.concat(parsed.types, '\n\n')
		out[#out + 1] = '```'
		out[#out + 1] = ''
	end
	return table.concat(out, '\n')
end

local function listResources()
	local command = package.config:sub(1, 1) == '\\' and 'dir /b /ad' or 'ls -1'
	local names = {}
	local pipe = assert(io.popen(command))
	for name in pipe:lines() do
		name = name:gsub('[/\r]', '')
		local file = io.open(name .. '/types.lua', 'rb')
		if file then
			file:close()
			names[#names + 1] = name
		end
	end
	pipe:close()
	table.sort(names)
	return names
end

local function write(path, content)
	if check then
		local file = io.open(path, 'rb')
		local current = file and file:read('a'):gsub('\r\n', '\n')
		if file then
			file:close()
		end
		if current ~= content then
			io.stderr:write('Desatualizado: ' .. path .. '\n')
			return false
		end
		return true
	end
	local file = assert(io.open(path, 'wb'))
	file:write(content)
	file:close()
	return true
end

local ok = true
local index = {
	'# Referência da API dos resources',
	'',
	'> Gerado por `tools/gen_reference.lua` a partir dos `types.lua` (convenção em coe-docs/ANNOTATIONS.md).',
	'',
	'| Resource | Exports |',
	'|---|---|'
}
for _, resource in ipairs(listResources()) do
	local parsed = parse(resource .. '/types.lua')
	ok = write('reference/' .. resource .. '.md', render(resource, parsed) .. '\n') and ok
	local names = {}
	for _, item in ipairs(parsed.exports) do
		names[#names + 1] = '`' .. item.name .. '`'
	end
	index[#index + 1] = ('| [%s](%s.md) | %s |'):format(resource, resource, table.concat(names, ', '))
end
index[#index + 1] = ''
ok = write('reference/README.md', table.concat(index, '\n')) and ok

if not ok then
	os.exit(1)
end
