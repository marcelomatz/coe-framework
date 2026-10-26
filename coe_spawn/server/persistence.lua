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

function SpawnPersistence.LoadStarterHotel()
	local rows, errorCode = callDatabase('Query',
		'SELECT name, enabled, blip_enabled, entrance_x, entrance_y, entrance_z, entrance_h, room_x, room_y, room_z, room_h, exit_x, exit_y, exit_z, exit_h, stash_x, stash_y, stash_z, stash_slots, stash_weight FROM coe_starter_hotel WHERE id = 1 LIMIT 1')
	if not rows then
		return nil, errorCode or 'database_error'
	end
	local row = rows[1]
	if not row then
		return false
	end
	local blipActive = true
	if row.blip_enabled ~= nil then
		blipActive = tonumber(row.blip_enabled) == 1
	end
	return {
		name = tostring(row.name or 'Motel Pink Cage'),
		enabled = tonumber(row.enabled) == 1,
		blip = blipActive,
		entrance = { x = tonumber(row.entrance_x) or 325.5, y = tonumber(row.entrance_y) or -212.8, z = tonumber(row.entrance_z) or 54.0, h = tonumber(row.entrance_h) or 160.0 },
		room = { x = tonumber(row.room_x) or 151.4, y = tonumber(row.room_y) or -1007.8, z = tonumber(row.room_z) or -99.0, h = tonumber(row.room_h) or 0.0 },
		exit = { x = tonumber(row.exit_x) or 151.3, y = tonumber(row.exit_y) or -1004.8, z = tonumber(row.exit_z) or -99.0, h = tonumber(row.exit_h) or 180.0 },
		stash = { x = tonumber(row.stash_x) or 151.8, y = tonumber(row.stash_y) or -1001.2, z = tonumber(row.stash_z) or -99.0, slots = tonumber(row.stash_slots) or 30, maxWeight = tonumber(row.stash_weight) or 50000 }
	}
end

function SpawnPersistence.SaveStarterHotel(hotel)
	local result, errorCode = callDatabase('Execute', [[
		INSERT INTO coe_starter_hotel (id, name, enabled, blip_enabled, entrance_x, entrance_y, entrance_z, entrance_h, room_x, room_y, room_z, room_h, exit_x, exit_y, exit_z, exit_h, stash_x, stash_y, stash_z, stash_slots, stash_weight, updated_at)
		VALUES (1, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
		ON DUPLICATE KEY UPDATE
			name = VALUES(name),
			enabled = VALUES(enabled),
			blip_enabled = VALUES(blip_enabled),
			entrance_x = VALUES(entrance_x), entrance_y = VALUES(entrance_y), entrance_z = VALUES(entrance_z), entrance_h = VALUES(entrance_h),
			room_x = VALUES(room_x), room_y = VALUES(room_y), room_z = VALUES(room_z), room_h = VALUES(room_h),
			exit_x = VALUES(exit_x), exit_y = VALUES(exit_y), exit_z = VALUES(exit_z), exit_h = VALUES(exit_h),
			stash_x = VALUES(stash_x), stash_y = VALUES(stash_y), stash_z = VALUES(stash_z),
			stash_slots = VALUES(stash_slots), stash_weight = VALUES(stash_weight),
			updated_at = VALUES(updated_at)
	]], {
		hotel.name or 'Motel Pink Cage',
		hotel.enabled and 1 or 0,
		hotel.blip ~= false and 1 or 0,
		hotel.entrance.x or 325.5, hotel.entrance.y or -212.8, hotel.entrance.z or 54.0, hotel.entrance.h or 160.0,
		hotel.room.x or 151.4, hotel.room.y or -1007.8, hotel.room.z or -99.0, hotel.room.h or 0.0,
		hotel.exit.x or 151.3, hotel.exit.y or -1004.8, hotel.exit.z or -99.0, hotel.exit.h or 180.0,
		hotel.stash.x or 151.8, hotel.stash.y or -1001.2, hotel.stash.z or -99.0,
		hotel.stash.slots or 30, hotel.stash.maxWeight or 50000,
		os.time()
	})
	if not result then
		return nil, errorCode or 'database_error'
	end
	return true
end
