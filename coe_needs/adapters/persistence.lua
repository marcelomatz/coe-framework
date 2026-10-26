NeedsPersistence = {}

local ready = false
local logger = CoeLogger.Create('coe_needs')

local function log(level, event, fields)
	logger:log(level, 'database', event, fields)
end

local function isValidId(value)
	return type(value) == 'string' and #value >= 1 and #value <= 64
end

local function dbCall(method, query, params)
	local ok, result, err = pcall(function()
		return exports.coe_database[method](exports.coe_database, query, params)
	end)
	if not ok then
		log('error', 'database_call_failed', { method = method, error = tostring(result) })
		return nil, 'database_unavailable'
	end
	if result == nil then
		return nil, err or 'database_error'
	end
	return result
end

function NeedsPersistence.IsReady()
	return ready
end

function NeedsPersistence.Initialize()
	local ok, err = CoeMigrations.Run(NeedsMigrations, dbCall, log)
	ready = ok == true
	return ready, err
end

function NeedsPersistence.Load(characterId)
	if not ready then
		return nil, 'persistence_not_ready'
	end
	if not isValidId(characterId) then
		return nil, 'invalid_character_id'
	end
	local row, err = dbCall(
		'Single',
		'SELECT hunger, thirst, stress, alcohol, drugs FROM coe_needs_state WHERE character_id = ? LIMIT 1',
		{ characterId }
	)
	if not row then
		return nil, err
	end
	if row == false then
		return false
	end
	return {
		hunger = tonumber(row.hunger),
		thirst = tonumber(row.thirst),
		stress = tonumber(row.stress),
		alcohol = tonumber(row.alcohol) or 0,
		drugs = tonumber(row.drugs) or 0
	}
end

local UPSERT_SQL = [=[
	INSERT INTO coe_needs_state (character_id, hunger, thirst, stress, alcohol, drugs)
	VALUES (?, ?, ?, ?, ?, ?)
	ON DUPLICATE KEY UPDATE
		hunger = VALUES(hunger),
		thirst = VALUES(thirst),
		stress = VALUES(stress),
		alcohol = VALUES(alcohol),
		drugs = VALUES(drugs)
]=]

function NeedsPersistence.Save(characterId, state)
	if not ready then
		return false, 'persistence_not_ready'
	end
	if not isValidId(characterId) or type(state) ~= 'table' then
		return false, 'invalid_payload'
	end
	local affected, err = dbCall(
		'Execute',
		UPSERT_SQL,
		{
			characterId,
			tonumber(state.hunger) or 0,
			tonumber(state.thirst) or 0,
			tonumber(state.stress) or 0,
			tonumber(state.alcohol) or 0,
			tonumber(state.drugs) or 0
		}
	)
	if affected == nil then
		return false, err
	end
	return true
end

-- Salva varios personagens em uma unica transacao (salvamento periodico).
-- rows = { { characterId, state }, ... }
function NeedsPersistence.SaveMany(rows)
	if not ready then
		return false, 'persistence_not_ready'
	end
	if type(rows) ~= 'table' then
		return false, 'invalid_payload'
	end
	if #rows == 0 then
		return true
	end
	local queries = {}
	for i = 1, #rows do
		local entry = rows[i]
		local id = type(entry) == 'table' and entry[1] or nil
		local state = type(entry) == 'table' and entry[2] or nil
		if not isValidId(id) or type(state) ~= 'table' then
			return false, 'invalid_payload'
		end
		queries[i] = {
			query = UPSERT_SQL,
			values = {
				id,
				tonumber(state.hunger) or 0,
				tonumber(state.thirst) or 0,
				tonumber(state.stress) or 0,
				tonumber(state.alcohol) or 0,
				tonumber(state.drugs) or 0
			}
		}
	end
	local ok, err = dbCall('Transaction', queries)
	if not ok then
		return false, err
	end
	return true
end
