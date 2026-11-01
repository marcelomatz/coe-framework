PolicePersistence = {}

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

function PolicePersistence.Initialize()
	local migrated, errorCode = CoeMigrations.Run({
		tableName = 'coe_police_schema_migrations',
		migrations = PoliceMigrations,
		execute = function(sql, parameters)
			return callDatabase('Execute', sql, parameters)
		end,
		query = function(sql, parameters)
			return callDatabase('Query', sql, parameters)
		end
	})
	return migrated == true, errorCode
end

function PolicePersistence.AddRecord(subjectId, officerId, businessId, kind, detail, amount, minutes)
	local result, errorCode = callDatabase('Execute',
		'INSERT INTO coe_police_records (subject_id, officer_id, business_id, kind, detail, amount, minutes) VALUES (?, ?, ?, ?, ?, ?, ?)',
		{ subjectId, officerId, businessId, kind, detail, amount, minutes })
	if not result then
		return nil, errorCode or 'database_error'
	end
	return true
end

function PolicePersistence.Records(subjectId, limit)
	local rows, errorCode = callDatabase('Query',
		'SELECT kind, detail, amount, minutes, officer_id, business_id, created_at FROM coe_police_records WHERE subject_id = ? ORDER BY id DESC LIMIT ' .. math.floor(limit),
		{ subjectId })
	if not rows then
		return nil, errorCode or 'database_error'
	end
	return rows
end

function PolicePersistence.SetSentence(characterId, releaseAt)
	local result, errorCode = callDatabase('Execute',
		'INSERT INTO coe_police_sentences (character_id, release_at) VALUES (?, ?) ON DUPLICATE KEY UPDATE release_at = VALUES(release_at)',
		{ characterId, releaseAt })
	if not result then
		return nil, errorCode or 'database_error'
	end
	return true
end

function PolicePersistence.Sentence(characterId)
	local rows, errorCode = callDatabase('Query', 'SELECT release_at FROM coe_police_sentences WHERE character_id = ?', { characterId })
	if not rows then
		return nil, errorCode or 'database_error'
	end
	return rows[1] and tonumber(rows[1].release_at) or false
end

function PolicePersistence.ClearSentence(characterId)
	local result, errorCode = callDatabase('Execute', 'DELETE FROM coe_police_sentences WHERE character_id = ?', { characterId })
	if not result then
		return nil, errorCode or 'database_error'
	end
	return true
end
