GaragesPersistence = {}

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

function GaragesPersistence.Initialize()
	local migrated, errorCode = CoeMigrations.Run({
		tableName = 'coe_garages_schema_migrations',
		migrations = GaragesMigrations,
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

-- Quantos veículos do personagem estão guardados em vagas, por classe: { car = n, bike = n }.
function GaragesPersistence.SlotUsage(characterId)
	local rows, errorCode = callDatabase('Query', 'SELECT class, COUNT(*) AS total FROM coe_garage_slots WHERE character_id = ? GROUP BY class', { characterId })
	if not rows then
		return nil, errorCode or 'database_error'
	end
	local used = { car = 0, bike = 0 }
	for _, row in ipairs(rows) do
		used[row.class] = tonumber(row.total) or 0
	end
	return used
end

-- Em qual garagem pública cada veículo do personagem está guardado: { [vehicleId] = garageId }.
function GaragesPersistence.SlotsOf(characterId)
	local rows, errorCode = callDatabase('Query', 'SELECT vehicle_id, garage_id FROM coe_garage_slots WHERE character_id = ?', { characterId })
	if not rows then
		return nil, errorCode or 'database_error'
	end
	local slots = {}
	for _, row in ipairs(rows) do
		slots[tostring(row.vehicle_id)] = tostring(row.garage_id)
	end
	return slots
end

function GaragesPersistence.SaveSlot(vehicleId, garageId, characterId, class)
	return run([[
		INSERT INTO coe_garage_slots (vehicle_id, garage_id, character_id, class) VALUES (?, ?, ?, ?)
		ON DUPLICATE KEY UPDATE garage_id = VALUES(garage_id), character_id = VALUES(character_id), class = VALUES(class)
	]], { vehicleId, garageId, characterId, class })
end

function GaragesPersistence.DeleteSlot(vehicleId)
	return run('DELETE FROM coe_garage_slots WHERE vehicle_id = ?', { vehicleId })
end

-- Frota da garagem: { [vehicleId] = { vehicleId, staff, access = { [characterId] = name } } }.
function GaragesPersistence.ListFleet(garageId)
	local rows, errorCode = callDatabase('Query', 'SELECT vehicle_id, staff_access FROM coe_fleet WHERE garage_id = ? ORDER BY vehicle_id', { garageId })
	if not rows then
		return nil, errorCode or 'database_error'
	end
	local fleet, order = {}, {}
	for _, row in ipairs(rows) do
		local id = tostring(row.vehicle_id)
		fleet[id] = { vehicleId = id, staff = row.staff_access == 1 or row.staff_access == true, access = {} }
		order[#order + 1] = id
	end
	if #order > 0 then
		local access = callDatabase('Query', [[
			SELECT a.vehicle_id, a.character_id, a.name FROM coe_fleet_access a
			JOIN coe_fleet f ON f.vehicle_id = a.vehicle_id WHERE f.garage_id = ?
		]], { garageId })
		for _, row in ipairs(access or {}) do
			local entry = fleet[tostring(row.vehicle_id)]
			if entry then
				entry.access[tostring(row.character_id)] = row.name or ''
			end
		end
	end
	return fleet, order
end

-- Garagem a que o veículo pertence, ou nil.
function GaragesPersistence.FleetOf(vehicleId)
	local rows = callDatabase('Query', 'SELECT garage_id FROM coe_fleet WHERE vehicle_id = ?', { vehicleId })
	return rows and rows[1] and rows[1].garage_id or nil
end

function GaragesPersistence.CountFleet(garageId)
	local rows = callDatabase('Query', 'SELECT COUNT(*) AS total FROM coe_fleet WHERE garage_id = ?', { garageId })
	return rows and rows[1] and tonumber(rows[1].total) or 0
end

function GaragesPersistence.AddFleet(vehicleId, garageId)
	return run('INSERT INTO coe_fleet (vehicle_id, garage_id) VALUES (?, ?)', { vehicleId, garageId })
end

function GaragesPersistence.RemoveFleet(vehicleId)
	local removed = run('DELETE FROM coe_fleet_access WHERE vehicle_id = ?', { vehicleId })
	return removed and run('DELETE FROM coe_fleet WHERE vehicle_id = ?', { vehicleId })
end

function GaragesPersistence.SetStaffAccess(vehicleId, enabled)
	return run('UPDATE coe_fleet SET staff_access = ? WHERE vehicle_id = ?', { enabled and 1 or 0, vehicleId })
end

function GaragesPersistence.AddAccess(vehicleId, characterId, name)
	return run([[
		INSERT INTO coe_fleet_access (vehicle_id, character_id, name) VALUES (?, ?, ?)
		ON DUPLICATE KEY UPDATE name = VALUES(name)
	]], { vehicleId, characterId, name })
end

function GaragesPersistence.RemoveAccess(vehicleId, characterId)
	return run('DELETE FROM coe_fleet_access WHERE vehicle_id = ? AND character_id = ?', { vehicleId, characterId })
end

-- Garagens cadastradas no painel (JSON por garagem).
function GaragesPersistence.ListGarages()
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

function GaragesPersistence.SaveGarage(garage)
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

function GaragesPersistence.DeleteGarage(garageId)
	return run('DELETE FROM coe_garage_registry WHERE garage_id = ?', { garageId })
end

-- Personagem ativo (não arquivado) pelo stateId, mesmo offline: { characterId, name } ou nil,erro.
function GaragesPersistence.FindCharacterByStateId(stateId)
	local rows, errorCode = callDatabase('Query', [[
		SELECT character_id, first_name, last_name FROM coe_characters WHERE state_id = ? AND archived_at IS NULL LIMIT 1
	]], { stateId })
	if not rows then
		return nil, errorCode or 'database_error'
	end
	local row = rows[1]
	if not row then
		return nil, 'character_not_found'
	end
	return { characterId = tostring(row.character_id), name = ((row.first_name or '') .. ' ' .. (row.last_name or '')):gsub('^%s+', ''):gsub('%s+$', '') }
end
