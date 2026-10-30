NeedsPersistence = {}

local ready = false
local logger = CoeLogger.Create('coe_needs')

local function log(level, event, fields)
	logger.log(level, 'database', event, fields or {})
end

local function isValidId(value)
	return type(value) == 'string' and #value >= 1 and #value <= 64
end

-- Os exports do coe_database respondem por callback (sucesso, resultado, código de erro); aqui a chamada vira
-- síncrona dentro da thread com promise + Citizen.Await, como nos demais resources.
local function dbCall(method, ...)
	if GetResourceState('coe_database') ~= 'started' then
		return nil, 'database_unavailable'
	end
	local response = promise.new()
	local database = exports['coe_database']
	local args = { ... }
	args[#args + 1] = function(success, result, errorCode)
		response:resolve({ success = success == true, result = result, error = errorCode })
	end
	local dispatched, dispatchError = pcall(function()
		database[method](database, table.unpack(args))
	end)
	if not dispatched then
		log('error', 'database_call_failed', { method = method, error = tostring(dispatchError) })
		return nil, 'database_unavailable'
	end
	local outcome = Citizen.Await(response)
	if not outcome.success then
		return nil, outcome.error or 'database_error'
	end
	if outcome.result == nil then
		return true
	end
	return outcome.result
end

function NeedsPersistence.IsReady()
	return ready
end

function NeedsPersistence.Initialize()
	local ok, err = CoeMigrations.Run({
		tableName = 'coe_needs_schema_migrations',
		migrations = NeedsMigrations.versions,
		execute = function(sql, parameters)
			return dbCall('Execute', sql, parameters)
		end,
		query = function(sql, parameters)
			return dbCall('Query', sql, parameters)
		end
	})
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
	local rows, err = dbCall(
		'Query',
		'SELECT hunger, thirst, stress, alcohol, drugs FROM coe_needs_state WHERE character_id = ? LIMIT 1',
		{ characterId }
	)
	if not rows then
		return nil, err
	end
	local row = rows[1]
	if not row then
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
			sql = UPSERT_SQL,
			parameters = {
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
