Inventory.Persistence = {}

local ready = false
local locks = {}

local logger = CoeLogger.Create('coe_inventory')

local function callDatabase(exportName, ...)
	if GetResourceState('coe_database') ~= 'started' then
		return nil, 'database_unavailable'
	end

	local response = promise.new()
	local arguments = { ... }
	local databaseResource = exports['coe_database']
	local callArguments = { databaseResource }
	for _, argument in ipairs(arguments) do
		callArguments[#callArguments + 1] = argument
	end
	callArguments[#callArguments + 1] = function(success, result, errorCode)
		response:resolve({
			success = success == true,
			result = result,
			error = errorCode
		})
	end
	local dispatched = pcall(function()
		databaseResource[exportName](table.unpack(callArguments))
	end)
	if not dispatched then
		return nil, 'database_unavailable'
	end

	local result = Citizen.Await(response)
	if not result.success then
		return nil, result.error or 'database_error'
	end
	return result.result
end

local function acquire(keys)
	table.sort(keys)
	local held = {}
	for _, key in ipairs(keys) do
		local previous = locks[key]
		local gate = promise.new()
		locks[key] = gate
		if previous then
			Citizen.Await(previous)
		end
		held[#held + 1] = { key = key, gate = gate }
	end
	return held
end

local function release(held)
	for index = #held, 1, -1 do
		local lock = held[index]
		if locks[lock.key] == lock.gate then
			locks[lock.key] = nil
		end
		lock.gate:resolve(true)
	end
end

local function withLocks(keys, operation)
	local held = acquire(keys)
	local success, result, errorCode = pcall(operation)
	release(held)
	if not success then
		logger.log('error', 'persistence', 'inventory_adapter_operation_failed', {
			error_code = 'operation_failed'
		})
		return nil, 'persistence_failed'
	end
	return result, errorCode
end

local function validKey(key)
	return type(key) == 'string'
		and #key > 0
		and #key <= 160
		and key:match('^[%w_:%-%.]+$') ~= nil
end

local function execute(sql, parameters)
	return callDatabase('Execute', sql, parameters)
end

local function encodeRecord(value)
	if type(value) ~= 'string' then
		return nil, 'invalid_value'
	end
	local ok = pcall(json.decode, value)
	if not ok then
		return nil, 'invalid_value'
	end
	return value
end

function Inventory.Persistence.Initialize()
	local migrated, migrationError = CoeMigrations.Run({
		tableName = 'coe_inventory_schema_migrations',
		migrations = InventoryMigrations,
		execute = execute,
		query = function(sql, parameters)
			return callDatabase('Query', sql, parameters)
		end
	})
	if not migrated then
		return false, migrationError
	end

	ready = true
	return true
end

function Inventory.Persistence.IsReady()
	return ready
end

function Inventory.Persistence.Get(key)
	if not validKey(key) then
		return nil, 'invalid_key'
	end
	if not ready then
		return nil, 'database_not_ready'
	end

	return withLocks({ key }, function()
		local rows, queryError = callDatabase(
			'Query',
			'SELECT record_value FROM coe_inventory_records WHERE record_key = ? LIMIT 1',
			{ key }
		)
		if not rows then
			return nil, queryError
		end
		if not rows[1] then
			return nil
		end
		if type(rows[1].record_value) ~= 'string' then
			return nil, 'invalid_storage'
		end
		return rows[1].record_value
	end)
end

function Inventory.Persistence.Set(key, value)
	if not validKey(key) then
		return false, 'invalid_key'
	end
	local encoded, valueError = encodeRecord(value)
	if not encoded then
		return false, valueError
	end
	if not ready then
		return false, 'database_not_ready'
	end

	local result, errorCode = withLocks({ key }, function()
		return execute([[
			INSERT INTO coe_inventory_records (record_key, record_value)
			VALUES (?, ?)
			ON DUPLICATE KEY UPDATE record_value = VALUES(record_value)
		]], { key, encoded })
	end)
	if not result then
		return false, errorCode or 'database_error'
	end
	return true
end

function Inventory.Persistence.SetMany(records)
	if type(records) ~= 'table' or #records < 1 or #records > 64 then
		return false, 'invalid_records'
	end
	if not ready then
		return false, 'database_not_ready'
	end

	local statements = {}
	local keys = {}
	local seen = {}
	for _, record in ipairs(records) do
		if type(record) ~= 'table' or not validKey(record.key) then
			return false, 'invalid_key'
		end
		if seen[record.key] then
			return false, 'duplicate_key'
		end
		local value, valueError = encodeRecord(record.value)
		if not value then
			return false, valueError
		end
		seen[record.key] = true
		keys[#keys + 1] = record.key
		statements[#statements + 1] = {
			sql = [[
				INSERT INTO coe_inventory_records (record_key, record_value)
				VALUES (?, ?)
				ON DUPLICATE KEY UPDATE record_value = VALUES(record_value)
			]],
			parameters = { record.key, value }
		}
	end

	local result, errorCode = withLocks(keys, function()
		return callDatabase('Transaction', statements)
	end)
	if not result then
		return false, errorCode or 'database_error'
	end
	return true
end

-- Lista as chaves com o prefixo informado. Usa um intervalo sobre a chave (collation ascii_bin,
-- '{' vem depois de todo caractere válido), o que aproveita a PRIMARY KEY.
function Inventory.Persistence.ListKeys(prefix)
	if type(prefix) ~= 'string' or #prefix < 1 or #prefix > 64 or prefix:match('^[%w_:%-%.]+$') == nil then
		return nil, 'invalid_key'
	end
	if not ready then
		return nil, 'database_not_ready'
	end

	local rows, queryError = callDatabase(
		'Query',
		'SELECT record_key FROM coe_inventory_records WHERE record_key >= ? AND record_key < ?',
		{ prefix, prefix .. '{' }
	)
	if not rows then
		return nil, queryError or 'database_error'
	end
	local keys = {}
	for _, row in ipairs(rows) do
		if type(row.record_key) == 'string' then
			keys[#keys + 1] = row.record_key
		end
	end
	return keys
end

function Inventory.Persistence.Delete(key)
	if not validKey(key) then
		return false, 'invalid_key'
	end
	if not ready then
		return false, 'database_not_ready'
	end

	local result, errorCode = withLocks({ key }, function()
		return execute('DELETE FROM coe_inventory_records WHERE record_key = ?', { key })
	end)
	if not result then
		return false, errorCode or 'database_error'
	end
	return true
end
