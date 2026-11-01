EmsPersistence = {}

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

function EmsPersistence.Initialize()
	local migrated, errorCode = CoeMigrations.Run({
		tableName = 'coe_ems_schema_migrations',
		migrations = EmsMigrations,
		execute = function(sql, parameters)
			return callDatabase('Execute', sql, parameters)
		end,
		query = function(sql, parameters)
			return callDatabase('Query', sql, parameters)
		end
	})
	return migrated == true, errorCode
end

function EmsPersistence.AddRecord(patientId, medicId, businessId, kind, detail)
	local result, errorCode = callDatabase('Execute',
		'INSERT INTO coe_ems_records (patient_id, medic_id, business_id, kind, detail) VALUES (?, ?, ?, ?, ?)',
		{ patientId, medicId, businessId, kind, detail })
	if not result then
		return nil, errorCode or 'database_error'
	end
	return true
end

function EmsPersistence.Records(patientId, limit)
	local rows, errorCode = callDatabase('Query',
		'SELECT kind, detail, medic_id, business_id, created_at FROM coe_ems_records WHERE patient_id = ? ORDER BY id DESC LIMIT ' .. math.floor(limit),
		{ patientId })
	if not rows then
		return nil, errorCode or 'database_error'
	end
	return rows
end
