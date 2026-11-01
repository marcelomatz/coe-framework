MdtPersistence = {}

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

local function execute(sql, parameters)
	local result, errorCode = callDatabase('Execute', sql, parameters)
	if not result then
		return nil, errorCode or 'database_error'
	end
	return result
end

local function query(sql, parameters)
	local rows, errorCode = callDatabase('Query', sql, parameters)
	if not rows then
		return nil, errorCode or 'database_error'
	end
	return rows
end

function MdtPersistence.Initialize()
	local migrated, errorCode = CoeMigrations.Run({
		tableName = 'coe_mdt_schema_migrations',
		migrations = MdtMigrations,
		execute = function(sql, parameters)
			return callDatabase('Execute', sql, parameters)
		end,
		query = function(sql, parameters)
			return callDatabase('Query', sql, parameters)
		end
	})
	return migrated == true, errorCode
end

-- Registro de acesso: gravado ANTES de devolver qualquer dado sensível.
function MdtPersistence.LogAccess(officerId, businessId, action, subject)
	local result, errorCode = execute(
		'INSERT INTO coe_mdt_access_log (officer_id, business_id, action, subject) VALUES (?, ?, ?, ?)',
		{ officerId, businessId, action, subject or '' })
	if not result then
		return nil, errorCode
	end
	return true
end

function MdtPersistence.AccessLog(subject, limit)
	local sql = 'SELECT id, officer_id, business_id, action, subject, created_at FROM coe_mdt_access_log'
	local parameters = {}
	if subject and subject ~= '' then
		sql = sql .. ' WHERE subject = ?'
		parameters[1] = subject
	end
	return query(sql .. ' ORDER BY id DESC LIMIT ' .. math.floor(limit), parameters)
end

-- Busca por state_id exato ou por nomes (prefixo), só colunas mínimas.
function MdtPersistence.FindCharacters(stateId, tokens, limit)
	if stateId then
		return query(
			'SELECT character_id, first_name, last_name, state_id FROM coe_characters WHERE state_id = ? AND archived_at IS NULL LIMIT ' .. math.floor(limit),
			{ stateId })
	end
	local clauses, parameters = {}, {}
	for _, token in ipairs(tokens) do
		local escaped = token:gsub('[\\%%_]', '\\%0')
		clauses[#clauses + 1] = '(first_name LIKE ? OR last_name LIKE ?)'
		parameters[#parameters + 1] = escaped .. '%'
		parameters[#parameters + 1] = escaped .. '%'
	end
	return query(
		'SELECT character_id, first_name, last_name, state_id FROM coe_characters WHERE archived_at IS NULL AND ' ..
		table.concat(clauses, ' AND ') .. ' ORDER BY last_name, first_name LIMIT ' .. math.floor(limit),
		parameters)
end

function MdtPersistence.Character(characterId)
	local rows, errorCode = query(
		'SELECT character_id, first_name, last_name, state_id FROM coe_characters WHERE character_id = ? LIMIT 1',
		{ characterId })
	if not rows then
		return nil, errorCode
	end
	return rows[1] or false
end

function MdtPersistence.CharacterNames(ids)
	if #ids == 0 then
		return {}
	end
	local marks = {}
	for index = 1, #ids do
		marks[index] = '?'
	end
	local rows, errorCode = query(
		'SELECT character_id, first_name, last_name FROM coe_characters WHERE character_id IN (' .. table.concat(marks, ',') .. ')',
		ids)
	if not rows then
		return nil, errorCode
	end
	local names = {}
	for _, row in ipairs(rows) do
		names[tostring(row.character_id)] = ((row.first_name or '') .. ' ' .. (row.last_name or '')):gsub('^%s+', ''):gsub('%s+$', '')
	end
	return names
end

-- Mandados
function MdtPersistence.CountActiveWarrants(subjectId)
	local rows, errorCode = query('SELECT COUNT(*) AS total FROM coe_mdt_warrants WHERE subject_id = ? AND status = ?', { subjectId, 'active' })
	if not rows then
		return nil, errorCode
	end
	return tonumber(rows[1] and rows[1].total) or 0
end

function MdtPersistence.IssueWarrant(subjectId, issuedBy, businessId, charge, note)
	return execute(
		'INSERT INTO coe_mdt_warrants (subject_id, issued_by, business_id, charge, note) VALUES (?, ?, ?, ?, ?)',
		{ subjectId, issuedBy, businessId, charge, note })
end

function MdtPersistence.Warrant(id)
	local rows, errorCode = query('SELECT id, subject_id, status FROM coe_mdt_warrants WHERE id = ?', { id })
	if not rows then
		return nil, errorCode
	end
	return rows[1] or false
end

-- Transição atômica: só muda se ainda estiver ativo.
function MdtPersistence.CloseWarrant(id, status, resolvedBy)
	local result, errorCode = execute(
		'UPDATE coe_mdt_warrants SET status = ?, resolved_by = ?, resolved_at = CURRENT_TIMESTAMP(3) WHERE id = ? AND status = ?',
		{ status, resolvedBy, id, 'active' })
	if not result then
		return nil, errorCode
	end
	return (tonumber(result.affectedRows) or 0) > 0
end

function MdtPersistence.Warrants(subjectId, status, limit)
	local sql = 'SELECT id, subject_id, issued_by, charge, note, status, created_at FROM coe_mdt_warrants WHERE status = ?'
	local parameters = { status }
	if subjectId then
		sql = sql .. ' AND subject_id = ?'
		parameters[2] = subjectId
	end
	return query(sql .. ' ORDER BY id DESC LIMIT ' .. math.floor(limit), parameters)
end

-- Boletins
function MdtPersistence.IssueBulletin(issuedBy, businessId, title, body, plate, expiresAt)
	return execute(
		'INSERT INTO coe_mdt_bulletins (issued_by, business_id, title, body, plate, expires_at) VALUES (?, ?, ?, ?, ?, ?)',
		{ issuedBy, businessId, title, body, plate, expiresAt })
end

function MdtPersistence.CloseBulletin(id)
	local result, errorCode = execute('UPDATE coe_mdt_bulletins SET status = ? WHERE id = ? AND status = ?', { 'closed', id, 'active' })
	if not result then
		return nil, errorCode
	end
	return (tonumber(result.affectedRows) or 0) > 0
end

function MdtPersistence.Bulletins(plate, now, limit)
	local sql = 'SELECT id, issued_by, title, body, plate, expires_at, created_at FROM coe_mdt_bulletins WHERE status = ? AND expires_at > ?'
	local parameters = { 'active', now }
	if plate then
		sql = sql .. ' AND plate = ?'
		parameters[3] = plate
	end
	return query(sql .. ' ORDER BY id DESC LIMIT ' .. math.floor(limit), parameters)
end

-- Relatórios (imutáveis)
function MdtPersistence.AddReport(authorId, businessId, subjectId, title, body)
	return execute(
		'INSERT INTO coe_mdt_reports (author_id, business_id, subject_id, title, body) VALUES (?, ?, ?, ?, ?)',
		{ authorId, businessId, subjectId, title, body })
end

function MdtPersistence.Reports(subjectId, limit)
	local sql = 'SELECT id, author_id, subject_id, title, body, created_at FROM coe_mdt_reports'
	local parameters = {}
	if subjectId then
		sql = sql .. ' WHERE subject_id = ?'
		parameters[1] = subjectId
	end
	return query(sql .. ' ORDER BY id DESC LIMIT ' .. math.floor(limit), parameters)
end
