BusinessesPersistence = {}

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

function BusinessesPersistence.Initialize()
	local migrated, errorCode = CoeMigrations.Run({
		tableName = 'coe_businesses_schema_migrations',
		migrations = BusinessesMigrations,
		execute = function(sql, parameters)
			return callDatabase('Execute', sql, parameters)
		end,
		query = function(sql, parameters)
			return callDatabase('Query', sql, parameters)
		end
	})
	if not migrated then
		return false, errorCode
	end
	return true
end

-- Retorna a lista de definições completas (id, category, label, enabled, area, stations, rules).
function BusinessesPersistence.List()
	local rows, errorCode = callDatabase('Query', 'SELECT id, category, label, enabled, data FROM coe_businesses ORDER BY id', {})
	if not rows then
		return nil, errorCode or 'database_error'
	end
	local list = {}
	for _, row in ipairs(rows) do
		local ok, data = pcall(json.decode, row.data)
		if ok and type(data) == 'table' then
			data.id, data.category, data.label = row.id, row.category, row.label
			data.enabled = row.enabled == 1 or row.enabled == true
			list[#list + 1] = data
		end
	end
	return list
end

function BusinessesPersistence.Save(business)
	local data = json.encode({ area = business.area, stations = business.stations, rules = business.rules, owner = business.owner, staff = business.staff, partners = business.partners })
	local result, errorCode = callDatabase('Execute', [[
		INSERT INTO coe_businesses (id, category, label, enabled, data)
		VALUES (?, ?, ?, ?, ?)
		ON DUPLICATE KEY UPDATE category = VALUES(category), label = VALUES(label),
			enabled = VALUES(enabled), data = VALUES(data)
	]], { business.id, business.category, business.label, business.enabled and 1 or 0, data })
	if not result then
		return nil, errorCode or 'database_error'
	end
	return true
end

function BusinessesPersistence.Delete(id)
	local result, errorCode = callDatabase('Execute', 'DELETE FROM coe_businesses WHERE id = ?', { id })
	if not result then
		return nil, errorCode or 'database_error'
	end
	return true
end
