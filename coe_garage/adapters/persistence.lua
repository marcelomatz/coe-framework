GaragePersistence = {}

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

function GaragePersistence.Initialize()
	local migrated, errorCode = CoeMigrations.Run({
		tableName = 'coe_garage_schema_migrations',
		migrations = GarageMigrations,
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

local function run(sql, parameters)
	local result, errorCode = callDatabase('Execute', sql, parameters)
	if not result then
		return nil, errorCode or 'database_error'
	end
	return true
end

function GaragePersistence.ListGarages()
	local rows, errorCode = callDatabase('Query', 'SELECT garage_id, config FROM coe_garage_registry ORDER BY garage_id', {})
	if not rows then
		return nil, errorCode or 'database_error'
	end
	local list = {}
	for _, row in ipairs(rows) do
		local decoded = type(row.config) == 'string' and json.decode(row.config) or row.config
		if type(decoded) == 'table' then
			decoded.id = tostring(row.garage_id)
			list[#list + 1] = decoded
		end
	end
	return list
end

function GaragePersistence.SaveGarage(garage)
	local stored = {}
	for key, value in pairs(garage) do
		if key ~= 'id' then
			stored[key] = value
		end
	end
	return run([[
		INSERT INTO coe_garage_registry (garage_id, config) VALUES (?, ?)
		ON DUPLICATE KEY UPDATE config = VALUES(config)
	]], { garage.id, json.encode(stored) })
end

function GaragePersistence.DeleteGarage(garageId)
	return run('DELETE FROM coe_garage_registry WHERE garage_id = ?', { garageId })
end

function GaragePersistence.GetSlot(vehicleId)
	local rows, errorCode = callDatabase('Query', 'SELECT garage_id FROM coe_garage_slots WHERE vehicle_id = ? LIMIT 1', { vehicleId })
	if not rows or not rows[1] then
		return nil, errorCode
	end
	return tostring(rows[1].garage_id)
end

function GaragePersistence.SaveSlot(vehicleId, garageId, characterId, class)
	return run([[
		INSERT INTO coe_garage_slots (vehicle_id, garage_id, character_id, class) VALUES (?, ?, ?, ?)
		ON DUPLICATE KEY UPDATE garage_id = VALUES(garage_id), character_id = VALUES(character_id), class = VALUES(class)
	]], { vehicleId, garageId, characterId, class or 'car' })
end

function GaragePersistence.RemoveSlot(vehicleId)
	return run('DELETE FROM coe_garage_slots WHERE vehicle_id = ?', { vehicleId })
end

function GaragePersistence.SlotsOf(characterId)
	local rows, errorCode = callDatabase('Query', 'SELECT vehicle_id, garage_id FROM coe_garage_slots WHERE character_id = ?', { characterId })
	if not rows then
		return {}
	end
	local slots = {}
	for _, row in ipairs(rows) do
		slots[tostring(row.vehicle_id)] = tostring(row.garage_id)
	end
	return slots
end
