ElosPersistence = {}

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

local function query(sql, parameters)
	return callDatabase('Query', sql, parameters or {})
end

local function execute(sql, parameters)
	return callDatabase('Execute', sql, parameters or {})
end

local function int(value)
	return math.tointeger(tonumber(value))
end

local function truthy(value)
	return value == true or tonumber(value) == 1
end

function ElosPersistence.Initialize()
	return CoeMigrations.Run({
		tableName = 'coe_elos_schema_migrations',
		migrations = ElosMigrations,
		execute = execute,
		query = query
	})
end

-- Perfis ------------------------------------------------------------------------------------------------

local PROFILE_COLUMNS = 'character_id, state_id, name, headline, about, visibility, show_earnings, show_career, created_at'

local function profileRow(row)
	if not row then
		return nil
	end
	return {
		characterId = tostring(row.character_id), stateId = row.state_id, name = row.name, headline = row.headline or '',
		about = row.about or '', visibility = row.visibility == 'closed' and 'closed' or 'open',
		showEarnings = truthy(row.show_earnings), showCareer = truthy(row.show_career), createdAt = int(row.created_at)
	}
end

-- Perfil do personagem; false se não existe; nil em erro.
function ElosPersistence.Profile(characterId)
	local rows, errorCode = query('SELECT ' .. PROFILE_COLUMNS .. ' FROM coe_elos_profiles WHERE character_id = ?', { characterId })
	if not rows then
		return nil, errorCode
	end
	return profileRow(rows[1]) or false
end

function ElosPersistence.ProfileByState(stateId)
	local rows, errorCode = query('SELECT ' .. PROFILE_COLUMNS .. ' FROM coe_elos_profiles WHERE state_id = ?', { stateId })
	if not rows then
		return nil, errorCode
	end
	return profileRow(rows[1]) or false
end

function ElosPersistence.SaveProfile(profile)
	local now = os.time()
	return execute([[
		INSERT INTO coe_elos_profiles (character_id, state_id, name, headline, about, visibility, show_earnings, show_career, created_at, updated_at)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
		ON DUPLICATE KEY UPDATE state_id = VALUES(state_id), name = VALUES(name), headline = VALUES(headline), about = VALUES(about),
			visibility = VALUES(visibility), show_earnings = VALUES(show_earnings), show_career = VALUES(show_career), updated_at = VALUES(updated_at)
	]], {
		profile.characterId, profile.stateId, profile.name, profile.headline, profile.about, profile.visibility,
		profile.showEarnings and 1 or 0, profile.showCareer and 1 or 0, profile.createdAt or now, now
	})
end

-- Busca por nome (contém o termo), sem o próprio personagem.
function ElosPersistence.Search(term, excludeId, limit)
	local escaped = term:gsub('[%%_\\]', '\\%0')
	local rows, errorCode = query(([[
		SELECT ]] .. PROFILE_COLUMNS .. [[ FROM coe_elos_profiles
		WHERE name LIKE ? AND character_id <> ? ORDER BY name LIMIT %d
	]]):format(math.floor(limit)), { '%' .. escaped .. '%', excludeId })
	if not rows then
		return nil, errorCode
	end
	local out = {}
	for _, row in ipairs(rows) do
		out[#out + 1] = profileRow(row)
	end
	return out
end

-- Currículo ----------------------------------------------------------------------------------------------

-- Experiências no currículo: chave `kind:ref` -> { note, addedAt }.
function ElosPersistence.Items(characterId)
	local rows, errorCode = query('SELECT kind, ref, note, added_at FROM coe_elos_items WHERE character_id = ?', { characterId })
	if not rows then
		return nil, errorCode
	end
	local out = {}
	for _, row in ipairs(rows) do
		out[row.kind .. ':' .. row.ref] = { note = row.note or '', addedAt = int(row.added_at) }
	end
	return out
end

function ElosPersistence.SaveItem(characterId, kind, ref, note)
	return execute([[
		INSERT INTO coe_elos_items (character_id, kind, ref, note, added_at) VALUES (?, ?, ?, ?, ?)
		ON DUPLICATE KEY UPDATE note = VALUES(note)
	]], { characterId, kind, ref, note or '', os.time() })
end

function ElosPersistence.DeleteItem(characterId, kind, ref)
	return execute('DELETE FROM coe_elos_items WHERE character_id = ? AND kind = ? AND ref = ?', { characterId, kind, ref })
end

-- Horas de ponto em negócios.
function ElosPersistence.Works(characterId)
	local rows, errorCode = query([[
		SELECT business_id, label, category, role, seconds, shifts, first_at, last_at FROM coe_elos_work WHERE character_id = ?
	]], { characterId })
	if not rows then
		return nil, errorCode
	end
	local out = {}
	for _, row in ipairs(rows) do
		out[#out + 1] = {
			businessId = row.business_id, label = row.label, category = row.category ~= '' and row.category or nil,
			role = row.role ~= '' and row.role or nil, seconds = int(row.seconds) or 0, shifts = int(row.shifts) or 0,
			firstAt = int(row.first_at), lastAt = int(row.last_at)
		}
	end
	return out
end

-- Soma um turno: { businessId, label, category, role, seconds, startedAt, endedAt }.
function ElosPersistence.AddShift(characterId, shift)
	return execute([[
		INSERT INTO coe_elos_work (character_id, business_id, label, category, role, seconds, shifts, first_at, last_at)
		VALUES (?, ?, ?, ?, ?, ?, 1, ?, ?)
		ON DUPLICATE KEY UPDATE label = VALUES(label), category = VALUES(category),
			role = IF(VALUES(role) = '', role, VALUES(role)), seconds = seconds + VALUES(seconds), shifts = shifts + 1,
			first_at = LEAST(first_at, VALUES(first_at)), last_at = GREATEST(last_at, VALUES(last_at))
	]], {
		characterId, shift.businessId, shift.label, shift.category or '', shift.role or '', shift.seconds, shift.startedAt, shift.endedAt
	})
end

-- Conexões -----------------------------------------------------------------------------------------------

-- Todas as conexões e pedidos do personagem, com o perfil da outra pessoa.
function ElosPersistence.Connections(characterId)
	local rows, errorCode = query([[
		SELECT c.requester_id, c.target_id, c.status, c.created_at, c.accepted_at,
			p.state_id, p.name, p.headline
		FROM coe_elos_connections c
		JOIN coe_elos_profiles p ON p.character_id = IF(c.requester_id = ?, c.target_id, c.requester_id)
		WHERE c.requester_id = ? OR c.target_id = ?
		ORDER BY p.name
	]], { characterId, characterId, characterId })
	if not rows then
		return nil, errorCode
	end
	local out = {}
	for _, row in ipairs(rows) do
		out[#out + 1] = {
			requester = tostring(row.requester_id), target = tostring(row.target_id), status = row.status,
			createdAt = int(row.created_at), acceptedAt = int(row.accepted_at),
			stateId = row.state_id, name = row.name, headline = row.headline or ''
		}
	end
	return out
end

-- Linha entre dois personagens (em qualquer direção); false se não existe; nil em erro.
function ElosPersistence.Connection(a, b)
	local rows, errorCode = query([[
		SELECT requester_id, target_id, status FROM coe_elos_connections
		WHERE (requester_id = ? AND target_id = ?) OR (requester_id = ? AND target_id = ?)
	]], { a, b, b, a })
	if not rows then
		return nil, errorCode
	end
	local row = rows[1]
	if not row then
		return false
	end
	return { requester = tostring(row.requester_id), target = tostring(row.target_id), status = row.status }
end

function ElosPersistence.Count(characterId)
	local rows, errorCode = query([[
		SELECT COUNT(*) AS total FROM coe_elos_connections WHERE status = 'accepted' AND (requester_id = ? OR target_id = ?)
	]], { characterId, characterId })
	if not rows then
		return nil, errorCode
	end
	return int(rows[1] and rows[1].total) or 0
end

function ElosPersistence.Request(requester, target)
	return execute([[
		INSERT IGNORE INTO coe_elos_connections (requester_id, target_id, status, created_at) VALUES (?, ?, 'pending', ?)
	]], { requester, target, os.time() })
end

-- Aceita o pedido que `requester` fez para `target`.
function ElosPersistence.Accept(requester, target)
	local result, errorCode = execute([[
		UPDATE coe_elos_connections SET status = 'accepted', accepted_at = ?
		WHERE requester_id = ? AND target_id = ? AND status = 'pending'
	]], { os.time(), requester, target })
	if not result then
		return nil, errorCode
	end
	return (tonumber(result.affectedRows) or 0) > 0
end

-- Desfaz a ligação entre dois personagens (pedido recusado, cancelado ou conexão removida).
function ElosPersistence.Remove(a, b)
	local result, errorCode = execute([[
		DELETE FROM coe_elos_connections WHERE (requester_id = ? AND target_id = ?) OR (requester_id = ? AND target_id = ?)
	]], { a, b, b, a })
	if not result then
		return nil, errorCode
	end
	return (tonumber(result.affectedRows) or 0) > 0
end
