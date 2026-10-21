VehiclesPersistence = {}

local COLUMNS = 'vehicle_id, owner_character_id, model, plate, mileage_m, state'

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

local function toRecord(row)
	if type(row) ~= 'table' then
		return nil
	end
	return {
		id = tostring(row.vehicle_id),
		ownerCharacterId = row.owner_character_id ~= nil and tostring(row.owner_character_id) or nil,
		model = row.model,
		plate = row.plate,
		mileage = tonumber(row.mileage_m) or 0,
		state = row.state
	}
end

function VehiclesPersistence.Initialize()
	local migrated, errorCode = CoeMigrations.Run({
		tableName = 'coe_vehicles_schema_migrations',
		migrations = VehiclesMigrations,
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

function VehiclesPersistence.Insert(record)
	local result, errorCode = callDatabase(
		'Execute',
		"INSERT INTO coe_vehicles (owner_character_id, model, plate, mileage_m, state) VALUES (NULLIF(?, ''), ?, ?, ?, ?)",
		{ record.ownerCharacterId or '', record.model, record.plate, record.mileage, record.state }
	)
	if not result then
		if errorCode == 'ER_DUP_ENTRY' then
			return nil, 'plate_taken'
		end
		return nil, errorCode
	end
	return tostring(result.insertId)
end

local function findOne(where, value)
	local rows, errorCode = callDatabase(
		'Query',
		'SELECT ' .. COLUMNS .. ' FROM coe_vehicles WHERE ' .. where .. ' LIMIT 1',
		{ value }
	)
	if not rows then
		return nil, errorCode
	end
	local record = toRecord(rows[1])
	if not record then
		return nil, 'vehicle_not_found'
	end
	return record
end

function VehiclesPersistence.FindById(id)
	return findOne('vehicle_id = ?', id)
end

function VehiclesPersistence.FindByPlate(plate)
	return findOne('plate = ?', plate)
end

function VehiclesPersistence.ListByOwner(characterId, limit)
	local rows, errorCode = callDatabase(
		'Query',
		'SELECT ' .. COLUMNS .. ' FROM coe_vehicles WHERE owner_character_id = ? ORDER BY vehicle_id LIMIT ?',
		{ characterId, limit }
	)
	if not rows then
		return nil, errorCode
	end
	local list = {}
	for _, row in ipairs(rows) do
		list[#list + 1] = toRecord(row)
	end
	return list
end

function VehiclesPersistence.CountByOwner(characterId)
	local rows, errorCode = callDatabase(
		'Query',
		'SELECT COUNT(*) AS total FROM coe_vehicles WHERE owner_character_id = ?',
		{ characterId }
	)
	if not rows then
		return nil, errorCode
	end
	return tonumber(rows[1] and rows[1].total) or 0
end

function VehiclesPersistence.SetMileage(id, meters)
	local result, errorCode = callDatabase(
		'Execute',
		'UPDATE coe_vehicles SET mileage_m = ? WHERE vehicle_id = ?',
		{ meters, id }
	)
	if not result then
		return false, errorCode
	end
	return true
end

function VehiclesPersistence.SetState(id, state)
	local result, errorCode = callDatabase(
		'Execute',
		'UPDATE coe_vehicles SET state = ? WHERE vehicle_id = ?',
		{ state, id }
	)
	if not result then
		return false, errorCode
	end
	return true
end

-- Entidades não sobrevivem a reinício: veículos "out" de uma execução anterior voltam a "stored".
function VehiclesPersistence.ResetOutState()
	local result, errorCode = callDatabase('Execute', "UPDATE coe_vehicles SET state = 'stored' WHERE state = 'out'", {})
	if not result then
		return false, errorCode
	end
	return true
end

-- Todas as atualizações do lote entram numa transação: ou todas, ou nenhuma.
function VehiclesPersistence.UpdateMileageBatch(entries)
	local statements = {}
	for index, entry in ipairs(entries) do
		statements[index] = {
			sql = 'UPDATE coe_vehicles SET mileage_m = ? WHERE vehicle_id = ?',
			parameters = { entry.mileage, entry.id }
		}
	end
	local result, errorCode = callDatabase('Transaction', statements)
	if not result then
		return false, errorCode
	end
	return true
end

function VehiclesPersistence.AddKey(vehicleId, characterId, grantedBy)
	local result, errorCode = callDatabase(
		'Execute',
		"INSERT IGNORE INTO coe_vehicle_keys (vehicle_id, character_id, granted_by) VALUES (?, ?, NULLIF(?, ''))",
		{ vehicleId, characterId, grantedBy or '' }
	)
	if not result then
		return nil, errorCode
	end
	return true
end

function VehiclesPersistence.RemoveKey(vehicleId, characterId)
	local result, errorCode = callDatabase(
		'Execute',
		'DELETE FROM coe_vehicle_keys WHERE vehicle_id = ? AND character_id = ?',
		{ vehicleId, characterId }
	)
	if not result then
		return nil, errorCode
	end
	return true
end

function VehiclesPersistence.ListKeysByVehicle(vehicleId)
	local rows, errorCode = callDatabase(
		'Query',
		'SELECT character_id FROM coe_vehicle_keys WHERE vehicle_id = ? ORDER BY created_at',
		{ vehicleId }
	)
	if not rows then
		return nil, errorCode
	end
	local list = {}
	for _, row in ipairs(rows) do
		list[#list + 1] = tostring(row.character_id)
	end
	return list
end

function VehiclesPersistence.ListKeysByCharacter(characterId)
	local rows, errorCode = callDatabase(
		'Query',
		'SELECT vehicle_id FROM coe_vehicle_keys WHERE character_id = ? LIMIT 500',
		{ characterId }
	)
	if not rows then
		return nil, errorCode
	end
	local list = {}
	for _, row in ipairs(rows) do
		list[#list + 1] = tostring(row.vehicle_id)
	end
	return list
end
