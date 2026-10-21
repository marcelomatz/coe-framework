VehicleCatalogPersistence = {}

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

function VehicleCatalogPersistence.Initialize()
	local migrated, errorCode = CoeMigrations.Run({
		tableName = 'coe_vehicle_catalog_schema_migrations',
		migrations = VehicleCatalogMigrations,
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

function VehicleCatalogPersistence.LoadOverrides()
	local rows, errorCode = callDatabase('Query', 'SELECT model, price, stock, category, hidden FROM coe_vehicle_overrides', {})
	if not rows then
		return nil, errorCode
	end
	local map = {}
	for _, row in ipairs(rows) do
		local override = {}
		if row.price ~= nil then override.price = math.tointeger(tonumber(row.price)) end
		if row.stock ~= nil then override.stock = math.tointeger(tonumber(row.stock)) end
		if row.category ~= nil then override.category = row.category end
		if row.hidden ~= nil then override.hidden = tonumber(row.hidden) == 1 end
		map[row.model] = override
	end
	return map
end

-- Parâmetros nulos viram '' para não quebrar o array; NULLIF devolve NULL no banco.
function VehicleCatalogPersistence.SaveOverride(model, override)
	local hidden = ''
	if override.hidden ~= nil then
		hidden = override.hidden and '1' or '0'
	end
	local result, errorCode = callDatabase(
		'Execute',
		[[INSERT INTO coe_vehicle_overrides (model, price, stock, category, hidden)
			VALUES (?, NULLIF(?, ''), NULLIF(?, ''), NULLIF(?, ''), NULLIF(?, ''))
			ON DUPLICATE KEY UPDATE price = VALUES(price), stock = VALUES(stock),
				category = VALUES(category), hidden = VALUES(hidden)]],
		{
			model,
			override.price ~= nil and tostring(override.price) or '',
			override.stock ~= nil and tostring(override.stock) or '',
			override.category or '',
			hidden
		}
	)
	if not result then
		return nil, errorCode
	end
	return true
end

function VehicleCatalogPersistence.DeleteOverride(model)
	local result, errorCode = callDatabase('Execute', 'DELETE FROM coe_vehicle_overrides WHERE model = ?', { model })
	if not result then
		return nil, errorCode
	end
	return true
end
