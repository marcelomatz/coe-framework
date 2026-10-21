SpawnPersistence = {}

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

function SpawnPersistence.Initialize()
	return CoeMigrations.Run({
		tableName = 'coe_spawn_schema_migrations',
		migrations = SpawnMigrations,
		execute = function(sql, parameters)
			return callDatabase('Execute', sql, parameters)
		end,
		query = function(sql, parameters)
			return callDatabase('Query', sql, parameters)
		end
	})
end

-- Retorna (posição|false, errorCode): false sem erro quando o personagem ainda não tem posição salva.
function SpawnPersistence.Load(characterId)
	local rows, errorCode = callDatabase('Query',
		'SELECT x, y, z, heading FROM coe_spawn_positions WHERE character_id = ? LIMIT 1', { characterId })
	if not rows then
		return nil, errorCode or 'database_error'
	end
	local row = rows[1]
	if not row then
		return false
	end
	return { x = tonumber(row.x), y = tonumber(row.y), z = tonumber(row.z), heading = tonumber(row.heading) }
end

function SpawnPersistence.Save(characterId, position)
	local result, errorCode = callDatabase('Execute', [[
		INSERT INTO coe_spawn_positions (character_id, x, y, z, heading) VALUES (?, ?, ?, ?, ?)
		ON DUPLICATE KEY UPDATE x = VALUES(x), y = VALUES(y), z = VALUES(z), heading = VALUES(heading)
	]], { characterId, position.x, position.y, position.z, position.heading })
	if not result then
		return nil, errorCode or 'database_error'
	end
	return true
end
