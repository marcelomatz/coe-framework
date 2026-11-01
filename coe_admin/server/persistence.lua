AdminPersistence = {}

local function callDatabase(exportName, ...)
	if GetResourceState('coe_database') ~= 'started' then
		return nil, 'database_unavailable'
	end

	local response = promise.new()
	local arguments = { ... }
	local databaseResource = exports['coe_database']
	local callArguments = { databaseResource }
	for _, argument in ipairs(arguments) do
		callArguments[#callArguments + 1] = argument
	end
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

function AdminPersistence.Initialize()
	local migrated, errorCode = CoeMigrations.Run({
		tableName = 'coe_admin_schema_migrations',
		migrations = AdminMigrations,
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

-- Personagem (ativo, não arquivado) pelo stateId, online ou não. Retorna { characterId, name }|nil,erro.
function AdminPersistence.Query(sql, parameters)
	return callDatabase('Query', sql, parameters or {})
end

function AdminPersistence.FindCharacterByStateId(stateId)
	local rows, errorCode = callDatabase(
		'Query',
		'SELECT character_id, first_name, last_name FROM coe_characters WHERE state_id = ? AND archived_at IS NULL LIMIT 1',
		{ stateId }
	)
	if not rows then
		return nil, errorCode or 'database_error'
	end
	local row = rows[1]
	if not row then
		return nil, 'character_not_found'
	end
	local name = ('%s %s'):format(row.first_name or '', row.last_name or ''):gsub('^%s+', ''):gsub('%s+$', '')
	return { characterId = tostring(row.character_id), name = name:sub(1, 48) }
end

function AdminPersistence.Load()
	local rows, errorCode = callDatabase(
		'Query',
		'SELECT identifier_value, role_name FROM coe_admin_staff ORDER BY identifier_value',
		{}
	)
	if not rows then
		return nil, errorCode
	end

	local staff = {}
	for _, row in ipairs(rows) do
		if type(row.identifier_value) ~= 'string' or type(row.role_name) ~= 'string' then
			return nil, 'invalid_database_result'
		end
		staff[row.identifier_value] = { role = row.role_name }
	end
	return staff
end

function AdminPersistence.SetRole(identifier, roleName)
	local result, errorCode = callDatabase('Execute', [[
		INSERT INTO coe_admin_staff (identifier_value, role_name)
		VALUES (?, ?)
		ON DUPLICATE KEY UPDATE role_name = VALUES(role_name)
	]], { identifier, roleName })
	if not result then
		return false, errorCode
	end
	return true
end

function AdminPersistence.RemoveRole(identifier)
	local result, errorCode = callDatabase(
		'Execute',
		'DELETE FROM coe_admin_staff WHERE identifier_value = ?',
		{ identifier }
	)
	if not result then
		return false, errorCode
	end
	return true
end
