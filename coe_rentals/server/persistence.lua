RentalsPersistence = {}

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

function RentalsPersistence.Initialize()
	return CoeMigrations.Run({
		tableName = 'coe_rentals_schema_migrations',
		migrations = RentalsMigrations,
		execute = function(sql, parameters)
			return callDatabase('Execute', sql, parameters)
		end,
		query = function(sql, parameters)
			return callDatabase('Query', sql, parameters)
		end
	})
end

function RentalsPersistence.ListStations()
	local rows, errorCode = callDatabase('Query', 'SELECT station_id, config FROM coe_rental_stations ORDER BY station_id', {})
	if not rows then
		return nil, errorCode or 'database_error'
	end
	local list = {}
	for _, row in ipairs(rows) do
		local decoded = type(row.config) == 'string' and json.decode(row.config) or row.config
		if type(decoded) == 'table' then
			decoded.id = tostring(row.station_id)
			list[#list + 1] = decoded
		end
	end
	return list
end

function RentalsPersistence.SaveStation(station)
	local stored = {}
	for key, value in pairs(station) do
		if key ~= 'id' then
			stored[key] = value
		end
	end
	local result, errorCode = callDatabase('Execute', [[
		INSERT INTO coe_rental_stations (station_id, config) VALUES (?, ?)
		ON DUPLICATE KEY UPDATE config = VALUES(config)
	]], { station.id, json.encode(stored) })
	if not result then
		return nil, errorCode or 'database_error'
	end
	return true
end

function RentalsPersistence.DeleteStation(stationId)
	local result, errorCode = callDatabase('Execute', 'DELETE FROM coe_rental_stations WHERE station_id = ?', { stationId })
	if not result then
		return nil, errorCode or 'database_error'
	end
	return true
end
