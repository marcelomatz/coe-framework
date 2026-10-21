local records = {}
local schemaReady = false
local transactionCount = 0
local failNextTransaction = false

local function copyRecords(source)
	local copy = {}
	for key, value in pairs(source) do
		copy[key] = value
	end
	return copy
end

local function complete(callback, success, result, errorCode)
	callback(success, result, errorCode)
end

json = {
	decode = function(value)
		if type(value) == 'string'
			and ((value:sub(1, 1) == '{' and value:sub(-1) == '}')
				or (value:sub(1, 1) == '[' and value:sub(-1) == ']')) then
			return {}
		end
		error('invalid JSON')
	end
}

local migrationVersions = {}
local migrationTableCreated = false

local database = {
	Execute = function(_, sql, parameters, callback)
		if sql:find('CREATE TABLE IF NOT EXISTS coe_inventory_schema_migrations', 1, true) then
			migrationTableCreated = true
			complete(callback, true, { affectedRows = 0 })
			return
		end
		if sql:find('INSERT INTO coe_inventory_schema_migrations', 1, true) then
			migrationVersions[#migrationVersions + 1] = { version = parameters[1], name = parameters[2] }
			complete(callback, true, { affectedRows = 1 })
			return
		end
		if sql:find('CREATE TABLE IF NOT EXISTS coe_inventory_records', 1, true) then
			schemaReady = true
			complete(callback, true, { affectedRows = 0 })
			return
		end

		if not schemaReady then
			complete(callback, false, nil, 'table_missing')
			return
		end
		if sql:find('INSERT INTO coe_inventory_records', 1, true) then
			records[parameters[1]] = parameters[2]
		elseif sql:find('DELETE FROM coe_inventory_records', 1, true) then
			records[parameters[1]] = nil
		else
			complete(callback, false, nil, 'unsupported_statement')
			return
		end
		complete(callback, true, { affectedRows = 1 })
	end,
	Query = function(_, sql, parameters, callback)
		if sql:find('SELECT version FROM coe_inventory_schema_migrations', 1, true) then
			complete(callback, migrationTableCreated, migrationVersions,
				migrationTableCreated and nil or 'table_missing')
			return
		end
		if not schemaReady then
			complete(callback, false, nil, 'table_missing')
			return
		end
		if sql:find('SELECT record_key FROM coe_inventory_records', 1, true) then
			local rows = {}
			for key in pairs(records) do
				if key >= parameters[1] and key < parameters[2] then rows[#rows + 1] = { record_key = key } end
			end
			complete(callback, true, rows)
			return
		end
		if not sql:find('SELECT record_value FROM coe_inventory_records', 1, true) then
			complete(callback, false, nil, 'unsupported_query')
			return
		end
		local value = records[parameters[1]]
		complete(callback, true, value and { { record_value = value } } or {})
	end,
	Transaction = function(_, statements, callback)
		transactionCount = transactionCount + 1
		if failNextTransaction then
			failNextTransaction = false
			complete(callback, false, nil, 'transaction_failed')
			return
		end

		local updated = copyRecords(records)
		local results = {}
		for _, statement in ipairs(statements) do
			if not statement.sql:find('INSERT INTO coe_inventory_records', 1, true) then
				complete(callback, false, nil, 'unsupported_statement')
				return
			end
			updated[statement.parameters[1]] = statement.parameters[2]
			results[#results + 1] = { affectedRows = 1 }
		end
		records = updated
		complete(callback, true, results)
	end
}

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
		assert(promiseValue.getValue(), 'test database callback did not resolve')
		return promiseValue.getValue()
	end
}

function GetResourceState(resourceName)
	assert(resourceName == 'coe_database')
	return 'started'
end

Inventory = {}
dofile([=[../coe_core/lib/migrations.lua]=])
dofile([=[adapters/migrations.lua]=])
dofile([=[../coe_core/lib/logger.lua]=])
dofile([=[adapters/persistence.lua]=])

local function assertEqual(actual, expected, message)
	if actual ~= expected then
		error(('%s: expected %s, got %s'):format(message, tostring(expected), tostring(actual)))
	end
end

local initialized, initializeError = Inventory.Persistence.Initialize()
assertEqual(initialized, true, 'initialize schema')
assertEqual(initializeError, nil, 'schema error')
assertEqual(#migrationVersions, 1, 'initial migration recorded')
assertEqual(migrationVersions[1].version, 1, 'initial migration version')
assertEqual(Inventory.Persistence.IsReady(), true, 'provider is ready')

local missing, missingError = Inventory.Persistence.Get('character:77')
assertEqual(missing, nil, 'missing record')
assertEqual(missingError, nil, 'missing record is not a database error')

assertEqual(Inventory.Persistence.Set('character:77', '{"items":[]}'), true, 'insert record')
assertEqual(Inventory.Persistence.Get('character:77'), '{"items":[]}', 'read inserted record')
assertEqual(Inventory.Persistence.Set('character:77', '{invalid'), false, 'reject invalid JSON')

local transactionBefore = transactionCount
assertEqual(Inventory.Persistence.SetMany({
	{ key = 'character:77', value = '{"items":[1]}' },
	{ key = 'character:78', value = '{"items":[2]}' }
}), true, 'persist inventory records atomically')
assertEqual(transactionCount, transactionBefore + 1, 'write uses exactly one database transaction')
assertEqual(Inventory.Persistence.Get('character:77'), '{"items":[1]}', 'transaction updates first record')
assertEqual(Inventory.Persistence.Get('character:78'), '{"items":[2]}', 'transaction updates second record')
assertEqual(Inventory.Persistence.SetMany({
	{ key = 'character:77', value = '{}' },
	{ key = 'character:77', value = '{}' }
}), false, 'reject duplicate keys in transaction')

failNextTransaction = true
local persisted, transactionError = Inventory.Persistence.SetMany({
	{ key = 'character:77', value = '{"items":[3]}' },
	{ key = 'character:78', value = '{"items":[4]}' }
})
assertEqual(persisted, false, 'failed transaction is rejected')
assertEqual(transactionError, 'transaction_failed', 'transaction error is returned')
assertEqual(Inventory.Persistence.Get('character:77'), '{"items":[1]}', 'failed transaction preserves first record')
assertEqual(Inventory.Persistence.Get('character:78'), '{"items":[2]}', 'failed transaction preserves second record')

assertEqual(Inventory.Persistence.Delete('character:77'), true, 'delete record')
assertEqual(Inventory.Persistence.Get('character:77'), nil, 'deleted record is absent')
Inventory.Persistence.Set('worldref:container:1', '{}')
Inventory.Persistence.Set('worldref:container:2', '{}')
Inventory.Persistence.Set('character:99', '{}')
local listed = Inventory.Persistence.ListKeys('worldref:')
assertEqual(#listed, 2, 'ListKeys returns only keys with the prefix')
assertEqual(Inventory.Persistence.ListKeys('bad prefix'), nil, 'ListKeys rejects invalid prefix')
print('inventory persistence tests passed')
