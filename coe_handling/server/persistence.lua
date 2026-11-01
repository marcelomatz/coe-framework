HandlingPersistence = {}

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

function HandlingPersistence.Initialize()
	local migrated, errorCode = CoeMigrations.Run({
		tableName = 'coe_handling_schema_migrations',
		migrations = HandlingMigrations,
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

-- Sem linha: retorna nil, nil (pneu padrão). Com falha: nil, código.
function HandlingPersistence.FindTyre(vehicleId)
	local rows, errorCode = callDatabase(
		'Query',
		'SELECT compound, fitted_at_m FROM coe_vehicle_tyres WHERE vehicle_id = ? LIMIT 1',
		{ vehicleId }
	)
	if not rows then
		return nil, errorCode or 'database_error'
	end
	local row = rows[1]
	if not row then
		return nil, nil
	end
	return { compound = row.compound, fittedAt = tonumber(row.fitted_at_m) or 0 }
end

function HandlingPersistence.SaveTyre(vehicleId, compound, fittedAt)
	local result, errorCode = callDatabase(
		'Execute',
		[[INSERT INTO coe_vehicle_tyres (vehicle_id, compound, fitted_at_m) VALUES (?, ?, ?)
			ON DUPLICATE KEY UPDATE compound = VALUES(compound), fitted_at_m = VALUES(fitted_at_m)]],
		{ vehicleId, compound, math.floor(fittedAt) }
	)
	if not result then
		return nil, errorCode or 'database_error'
	end
	return true
end
