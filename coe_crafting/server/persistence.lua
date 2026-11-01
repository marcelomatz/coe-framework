CraftingPersistence = {}

local function callDatabase(exportName, ...)
	if GetResourceState('coe_database') ~= 'started' then
		return nil, 'database_unavailable'
	end

	local response = promise.new()
	local databaseResource = exports['coe_database']
	local callArguments = { databaseResource, ... }
	callArguments[#callArguments + 1] = function(success, result, errorCode)
		response:resolve({ success = success == true, result = result, error = errorCode })
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

function CraftingPersistence.Initialize()
	return CoeMigrations.Run({
		tableName = 'coe_crafting_schema_migrations',
		migrations = CraftingMigrations,
		execute = function(sql, parameters)
			return callDatabase('Execute', sql, parameters)
		end,
		query = function(sql, parameters)
			return callDatabase('Query', sql, parameters)
		end
	})
end

-- { { kind, id, data } }
function CraftingPersistence.List()
	local rows, errorCode = callDatabase('Query',
		'SELECT record_kind, record_id, config FROM coe_crafting_catalog ORDER BY record_kind, record_id', {})
	if not rows then
		return nil, errorCode or 'database_error'
	end
	local list = {}
	for _, row in ipairs(rows) do
		local decoded = type(row.config) == 'string' and json.decode(row.config) or row.config
		if type(decoded) == 'table' then
			list[#list + 1] = { kind = tostring(row.record_kind), id = tostring(row.record_id), data = decoded }
		end
	end
	return list
end

function CraftingPersistence.Save(kind, id, data)
	local stored = {}
	for key, value in pairs(data) do
		if key ~= 'id' then
			stored[key] = value
		end
	end
	local result, errorCode = callDatabase('Execute', [[
		INSERT INTO coe_crafting_catalog (record_kind, record_id, config) VALUES (?, ?, ?)
		ON DUPLICATE KEY UPDATE config = VALUES(config)
	]], { kind, id, json.encode(stored) })
	if not result then
		return nil, errorCode or 'database_error'
	end
	return true
end

function CraftingPersistence.Delete(kind, id)
	local result, errorCode = callDatabase('Execute',
		'DELETE FROM coe_crafting_catalog WHERE record_kind = ? AND record_id = ?', { kind, id })
	if not result then
		return nil, errorCode or 'database_error'
	end
	return true
end
