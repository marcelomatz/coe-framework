-- Ponte síncrona Lua <-> Node usada pelos testes de integração.
-- O Node executa o SQL no MariaDB real através do provider do coe_database.
-- Protocolo: uma linha JSON por requisição em stdout; resposta em stdin como
-- literal Lua `{ok=true,result=...}` ou `{ok=false,error='codigo'}`.
Bridge = {}

local escapes = {
	['"'] = '\\"',
	['\\'] = '\\\\',
	['\n'] = '\\n',
	['\r'] = '\\r',
	['\t'] = '\\t'
}

local function encodeString(value)
	return '"' .. value:gsub('[%c"\\]', function(character)
		return escapes[character] or string.format('\\u%04x', character:byte())
	end) .. '"'
end

local function encode(value)
	local kind = type(value)
	if kind == 'nil' then
		return 'null'
	elseif kind == 'boolean' then
		return tostring(value)
	elseif kind == 'number' then
		if math.type(value) == 'integer' then
			return string.format('%d', value)
		end
		return string.format('%.17g', value)
	elseif kind == 'string' then
		return encodeString(value)
	elseif kind == 'table' then
		if next(value) == nil or value[1] ~= nil then
			local items = {}
			for index = 1, #value do
				items[index] = encode(value[index])
			end
			return '[' .. table.concat(items, ',') .. ']'
		end

		local keys = {}
		for key in pairs(value) do
			keys[#keys + 1] = key
		end
		table.sort(keys)
		local items = {}
		for _, key in ipairs(keys) do
			items[#items + 1] = encodeString(key) .. ':' .. encode(value[key])
		end
		return '{' .. table.concat(items, ',') .. '}'
	end
	error('unsupported value type: ' .. kind)
end

local function send(request)
	io.stdout:write(encode(request), '\n')
	io.stdout:flush()
	local line = io.read('l')
	if not line then
		error('bridge closed before responding')
	end
	local chunk = assert(load('return ' .. line, 'response', 't', {}))
	return chunk()
end

function Bridge.Query(sql, parameters)
	return send({ op = 'Query', sql = sql, parameters = parameters or {} })
end

function Bridge.Execute(sql, parameters)
	return send({ op = 'Execute', sql = sql, parameters = parameters or {} })
end

function Bridge.Transaction(statements)
	return send({ op = 'Transaction', statements = statements })
end

function Bridge.Done()
	io.stdout:write('{"op":"Done"}\n')
	io.stdout:flush()
end

function Bridge.AssertEqual(actual, expected, message)
	if actual ~= expected then
		error(('%s: expected %s, got %s'):format(message, tostring(expected), tostring(actual)), 2)
	end
end

-- Chama uma função no estilo callback e devolve seus argumentos (os callbacks são síncronos).
function Bridge.Call(fn, ...)
	local arguments = { ... }
	local outcome
	arguments[#arguments + 1] = function(...)
		outcome = table.pack(...)
	end
	local dispatched, dispatchError = fn(table.unpack(arguments))
	if dispatched == false then
		return false, nil, dispatchError
	end
	assert(outcome, 'callback was not invoked')
	return table.unpack(outcome, 1, outcome.n)
end

-- Adaptador no formato dos exports do coe_database: (self, ..., callback).
function Bridge.DatabaseExports()
	local function respond(response, callback)
		callback(response.ok == true, response.result, response.error)
	end
	return {
		Query = function(_, sql, parameters, callback)
			respond(Bridge.Query(sql, parameters), callback)
		end,
		Execute = function(_, sql, parameters, callback)
			respond(Bridge.Execute(sql, parameters), callback)
		end,
		Transaction = function(_, statements, callback)
			respond(Bridge.Transaction(statements), callback)
		end
	}
end

function Bridge.InstallFiveMStubs()
	local database = Bridge.DatabaseExports()
	exports = setmetatable({}, {
		__index = function(_, resourceName)
			assert(resourceName == 'coe_database')
			return database
		end
	})
	promise = {
		new = function()
			local value
			return {
				resolve = function(_, result)
					value = result
				end,
				getValue = function()
					return value
				end
			}
		end
	}
	Citizen = {
		Await = function(promiseValue)
			return assert(promiseValue.getValue(), 'database callback did not resolve')
		end
	}
	function GetResourceState()
		return 'started'
	end
	json = {
		encode = encode,
		decode = function(value)
			if type(value) ~= 'string'
				or not ((value:sub(1, 1) == '{' and value:sub(-1) == '}')
					or (value:sub(1, 1) == '[' and value:sub(-1) == ']')) then
				error('invalid JSON')
			end
			local inString, escape, out = false, false, {}
			local i, len = 1, #value
			while i <= len do
				local c = value:sub(i, i)
				if inString then
					if escape then
						escape = false
						out[#out + 1] = c
					elseif c == '\\' then
						escape = true
						out[#out + 1] = c
					elseif c == '"' then
						inString = false
						out[#out + 1] = c
					else
						out[#out + 1] = c
					end
					i = i + 1
				else
					if c == '"' then
						inString = true
						out[#out + 1] = c
						i = i + 1
					elseif c == '[' then
						out[#out + 1] = '{'
						i = i + 1
					elseif c == ']' then
						out[#out + 1] = '}'
						i = i + 1
					elseif c == ':' then
						out[#out + 1] = '='
						i = i + 1
					elseif value:sub(i, i + 3) == 'null' then
						out[#out + 1] = 'nil'
						i = i + 4
					else
						out[#out + 1] = c
						i = i + 1
					end
				end
			end
			local luaCode = table.concat(out):gsub('"([^"]-)"%s*=', '["%1"]=')
			local ok, chunk = pcall(load, 'return ' .. luaCode, 'json', 't', {})
			if ok and chunk then
				local runOk, result = pcall(chunk)
				if runOk and type(result) == 'table' then
					return result
				end
			end
			return {}
		end
	}
end
