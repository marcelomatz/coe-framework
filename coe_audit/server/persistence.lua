AuditPersistence = {}

local function callDatabase(exportName, ...)
	if GetResourceState('coe_database') ~= 'started' then
		return nil, 'database_unavailable'
	end

	local response = promise.new()
	local databaseResource = exports['coe_database']
	local callArguments = { databaseResource, ... }
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

function AuditPersistence.Initialize()
	local migrated, errorCode = CoeMigrations.Run({
		tableName = 'coe_audit_schema_migrations',
		migrations = AuditMigrations,
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

-- Uma única instrução multi-linha: o lote entra por inteiro ou não entra.
function AuditPersistence.InsertBatch(entries)
	if type(entries) ~= 'table' or #entries == 0 then
		return false, 'invalid_batch'
	end

	local rows = {}
	local parameters = {}
	for _, entry in ipairs(entries) do
		rows[#rows + 1] = "(?, ?, ?, ?, ?, NULLIF(?, ''), NULLIF(?, ''), ?)"
		parameters[#parameters + 1] = entry.occurred_at
		parameters[#parameters + 1] = entry.severity
		parameters[#parameters + 1] = entry.category
		parameters[#parameters + 1] = entry.event
		parameters[#parameters + 1] = entry.resource
		parameters[#parameters + 1] = entry.actor_license
		parameters[#parameters + 1] = entry.target_license
		parameters[#parameters + 1] = entry.context_json
	end

	local sql = 'INSERT INTO coe_audit_log '
		.. '(occurred_at, severity, category, event, resource, actor_license, target_license, context) VALUES '
		.. table.concat(rows, ', ')
	local result, errorCode = callDatabase('Execute', sql, parameters)
	if not result then
		return false, errorCode
	end
	return true
end

-- Remove até `limit` registros mais antigos que `days`. Retorna a quantidade removida.
function AuditPersistence.Purge(days, limit)
	local result, errorCode = callDatabase(
		'Execute',
		'DELETE FROM coe_audit_log WHERE occurred_at < (UTC_TIMESTAMP(3) - INTERVAL ? DAY) LIMIT ?',
		{ days, limit }
	)
	if not result then
		return nil, errorCode
	end
	return tonumber(result.affectedRows) or 0
end
