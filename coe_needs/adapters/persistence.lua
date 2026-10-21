NeedsPersistence = {}

local ready = false

local function callDatabase(exportName, sql, parameters)
	if GetResourceState('coe_database') ~= 'started' then
		return nil, 'database_unavailable'
	end

	local response = promise.new()
	local database = exports['coe_database']
	local dispatched = pcall(function()
		database[exportName](database, sql, parameters, function(success, result, errorCode)
			response:resolve({ success = success == true, result = result, error = errorCode })
		end)
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

function NeedsPersistence.Initialize()
	local migrated, migrationError = CoeMigrations.Run({
		tableName = 'coe_needs_schema_migrations',
		migrations = NeedsMigrations,
		execute = function(sql, parameters)
			return callDatabase('Execute', sql, parameters)
		end,
		query = function(sql, parameters)
			return callDatabase('Query', sql, parameters)
		end
	})
	if not migrated then
		return false, migrationError
	end
	ready = true
	return true
end

function NeedsPersistence.IsReady()
	return ready
end

-- Retorna (state|false, errorCode): false sem erro quando o personagem ainda nao tem registro.
function NeedsPersistence.Load(characterId)
	local rows, errorCode = callDatabase('Query',
		'SELECT hunger, thirst, stress FROM coe_needs_state WHERE character_id = ? LIMIT 1',
		{ characterId })
	if not rows then
		return nil, errorCode
	end
	local row = rows[1]
	if not row then
		return false
	end
	return { hunger = row.hunger, thirst = row.thirst, stress = row.stress }
end

function NeedsPersistence.Save(characterId, state)
	local result, errorCode = callDatabase('Execute', [[
		INSERT INTO coe_needs_state (character_id, hunger, thirst, stress)
		VALUES (?, ?, ?, ?)
		ON DUPLICATE KEY UPDATE hunger = VALUES(hunger), thirst = VALUES(thirst), stress = VALUES(stress)
	]], { characterId, state.hunger, state.thirst, state.stress })
	if result == nil then
		return false, errorCode
	end
	return true
end

-- Grava varios personagens numa unica instrucao. rows = { { characterId, state }, ... }.
function NeedsPersistence.SaveMany(rows)
	if #rows == 0 then
		return true
	end
	local marks, parameters = {}, {}
	for index, row in ipairs(rows) do
		marks[index] = '(?, ?, ?, ?)'
		local base = (index - 1) * 4
		parameters[base + 1] = row[1]
		parameters[base + 2] = row[2].hunger
		parameters[base + 3] = row[2].thirst
		parameters[base + 4] = row[2].stress
	end
	local result, errorCode = callDatabase('Execute',
		'INSERT INTO coe_needs_state (character_id, hunger, thirst, stress) VALUES ' .. table.concat(marks, ', ')
			.. ' ON DUPLICATE KEY UPDATE hunger = VALUES(hunger), thirst = VALUES(thirst), stress = VALUES(stress)',
		parameters)
	if result == nil then
		return false, errorCode
	end
	return true
end
