FactionsPersistence = {}

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

function FactionsPersistence.Initialize()
	local migrated, errorCode = CoeMigrations.Run({
		tableName = 'coe_factions_schema_migrations',
		migrations = FactionsMigrations,
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

function FactionsPersistence.ListFactions()
	local rows, errorCode = callDatabase('Query', 'SELECT faction_id, config FROM coe_faction_registry ORDER BY faction_id', {})
	if not rows then
		return nil, errorCode or 'database_error'
	end
	local list = {}
	for _, row in ipairs(rows) do
		local decoded = type(row.config) == 'string' and json.decode(row.config) or row.config
		if type(decoded) == 'table' then
			decoded.id = tostring(row.faction_id)
			list[#list + 1] = decoded
		end
	end
	return list
end

function FactionsPersistence.SaveFaction(faction)
	local stored = {}
	for key, value in pairs(faction) do
		if key ~= 'id' then
			stored[key] = value
		end
	end
	return run([[
		INSERT INTO coe_faction_registry (faction_id, config) VALUES (?, ?)
		ON DUPLICATE KEY UPDATE config = VALUES(config)
	]], { faction.id, json.encode(stored) })
end

function FactionsPersistence.DeleteFaction(factionId)
	local removed, errorCode = run('DELETE FROM coe_faction_members WHERE faction_id = ?', { factionId })
	if not removed then
		return nil, errorCode
	end
	return run('DELETE FROM coe_faction_registry WHERE faction_id = ?', { factionId })
end

-- Membros com o nome do personagem: { { characterId, name, grade } }.
function FactionsPersistence.ListMembers(factionId)
	local rows, errorCode = callDatabase('Query', [[
		SELECT m.character_id, m.grade, c.first_name, c.last_name, c.state_id
		FROM coe_faction_members m
		LEFT JOIN coe_characters c ON c.character_id = m.character_id
		WHERE m.faction_id = ?
		ORDER BY m.grade DESC, c.first_name, c.last_name
	]], { factionId })
	if not rows then
		return nil, errorCode or 'database_error'
	end
	local members = {}
	for _, row in ipairs(rows) do
		local name = ((row.first_name or '') .. ' ' .. (row.last_name or '')):gsub('^%s+', ''):gsub('%s+$', '')
		members[#members + 1] = {
			characterId = tostring(row.character_id),
			stateId = row.state_id and tostring(row.state_id) or nil,
			name = name,
			grade = tonumber(row.grade) or 0
		}
	end
	return members
end

function FactionsPersistence.CountMembers(factionId)
	local rows = callDatabase('Query', 'SELECT COUNT(*) AS total FROM coe_faction_members WHERE faction_id = ?', { factionId })
	return rows and rows[1] and tonumber(rows[1].total) or 0
end

-- Maior grau entre os membros, ou nil sem membros (para impedir remover um grau em uso).
function FactionsPersistence.GradesInUse(factionId)
	local rows, errorCode = callDatabase('Query', 'SELECT DISTINCT grade FROM coe_faction_members WHERE faction_id = ?', { factionId })
	if not rows then
		return nil, errorCode or 'database_error'
	end
	local used = {}
	for _, row in ipairs(rows) do
		used[tonumber(row.grade)] = true
	end
	return used
end

function FactionsPersistence.IsMember(factionId, characterId)
	local rows = callDatabase('Query', 'SELECT 1 AS found FROM coe_faction_members WHERE faction_id = ? AND character_id = ?', { factionId, characterId })
	return rows ~= nil and rows[1] ~= nil
end

function FactionsPersistence.SetMember(factionId, characterId, grade)
	return run([[
		INSERT INTO coe_faction_members (faction_id, character_id, grade) VALUES (?, ?, ?)
		ON DUPLICATE KEY UPDATE grade = VALUES(grade)
	]], { factionId, characterId, grade })
end

function FactionsPersistence.RemoveMember(factionId, characterId)
	return run('DELETE FROM coe_faction_members WHERE faction_id = ? AND character_id = ?', { factionId, characterId })
end

-- Vínculos do personagem: { [factionId] = grade }.
function FactionsPersistence.MembershipsOf(characterId)
	local rows, errorCode = callDatabase('Query', 'SELECT faction_id, grade FROM coe_faction_members WHERE character_id = ?', { characterId })
	if not rows then
		return nil, errorCode or 'database_error'
	end
	local memberships = {}
	for _, row in ipairs(rows) do
		memberships[tostring(row.faction_id)] = tonumber(row.grade) or 0
	end
	return memberships
end

function FactionsPersistence.CharacterExists(characterId)
	local rows = callDatabase('Query', 'SELECT 1 AS found FROM coe_characters WHERE character_id = ? AND archived_at IS NULL LIMIT 1', { characterId })
	return rows ~= nil and rows[1] ~= nil
end
