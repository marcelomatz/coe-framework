JobsPersistence = {}

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

function JobsPersistence.Initialize()
	return CoeMigrations.Run({
		tableName = 'coe_jobs_schema_migrations',
		migrations = JobsMigrations,
		execute = execute,
		query = query
	})
end

-- Progresso de um personagem em um emprego ({ xp, tasks, earned }), zerado se não existir; nil em erro.
function JobsPersistence.Progress(characterId, jobId)
	local rows, errorCode = query('SELECT xp, tasks, earned FROM coe_jobs_progress WHERE character_id = ? AND job_id = ?', { characterId, jobId })
	if not rows then
		return nil, errorCode
	end
	local row = rows[1]
	if not row then
		return { xp = 0, tasks = 0, earned = 0 }
	end
	return { xp = tonumber(row.xp) or 0, tasks = tonumber(row.tasks) or 0, earned = tonumber(row.earned) or 0 }
end

function JobsPersistence.AllProgress(characterId)
	local rows, errorCode = query('SELECT job_id, xp, tasks, earned, seconds, first_at, last_at FROM coe_jobs_progress WHERE character_id = ?', { characterId })
	if not rows then
		return nil, errorCode
	end
	local out = {}
	for _, row in ipairs(rows) do
		out[row.job_id] = {
			xp = tonumber(row.xp) or 0, tasks = tonumber(row.tasks) or 0, earned = tonumber(row.earned) or 0,
			seconds = tonumber(row.seconds) or 0, firstAt = tonumber(row.first_at), lastAt = tonumber(row.last_at)
		}
	end
	return out
end

function JobsPersistence.Save(characterId, jobId, progress)
	return execute([[
		INSERT INTO coe_jobs_progress (character_id, job_id, xp, tasks, earned, seconds, first_at, last_at, updated_at)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
		ON DUPLICATE KEY UPDATE xp = VALUES(xp), tasks = VALUES(tasks), earned = VALUES(earned), seconds = VALUES(seconds),
			first_at = VALUES(first_at), last_at = VALUES(last_at), updated_at = VALUES(updated_at)
	]], { characterId, jobId, progress.xp, progress.tasks, progress.earned, progress.seconds or 0, progress.firstAt, progress.lastAt, os.time() })
end

-- Reputação e contadores do personagem nos empregos (zerados se não existir); nil em erro.
function JobsPersistence.Profile(characterId)
	local rows, errorCode = query('SELECT reputation, completed, abandoned FROM coe_jobs_profile WHERE character_id = ?', { characterId })
	if not rows then
		return nil, errorCode
	end
	local row = rows[1]
	if not row then
		return { reputation = JobsConfig.Career.reputation.start or 0, completed = 0, abandoned = 0 }
	end
	return { reputation = tonumber(row.reputation) or 0, completed = tonumber(row.completed) or 0, abandoned = tonumber(row.abandoned) or 0 }
end

function JobsPersistence.SaveProfile(characterId, record)
	return execute([[
		INSERT INTO coe_jobs_profile (character_id, reputation, completed, abandoned, updated_at) VALUES (?, ?, ?, ?, ?)
		ON DUPLICATE KEY UPDATE reputation = VALUES(reputation), completed = VALUES(completed), abandoned = VALUES(abandoned), updated_at = VALUES(updated_at)
	]], { characterId, record.reputation, record.completed, record.abandoned, os.time() })
end

-- Grava o resumo de um trabalho encerrado ({ jobId, startedAt, endedAt, tasks, xp, earned, discarded, reason }).
function JobsPersistence.SaveSession(characterId, entry)
	return execute([[
		INSERT INTO coe_jobs_sessions (character_id, job_id, started_at, ended_at, tasks, xp, earned, discarded, reason)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
	]], { characterId, entry.jobId, entry.startedAt, entry.endedAt, entry.tasks, entry.xp, entry.earned, entry.discarded, entry.reason })
end

-- Últimos trabalhos do personagem, do mais recente ao mais antigo; nil em erro.
function JobsPersistence.Sessions(characterId, limit)
	limit = math.max(1, math.min(50, math.floor(tonumber(limit) or 10)))
	local rows, errorCode = query(([[
		SELECT job_id, started_at, ended_at, tasks, xp, earned, discarded, reason FROM coe_jobs_sessions
		WHERE character_id = ? ORDER BY ended_at DESC, id DESC LIMIT %d
	]]):format(limit), { characterId })
	if not rows then
		return nil, errorCode
	end
	local out = {}
	for _, row in ipairs(rows) do
		out[#out + 1] = {
			jobId = row.job_id, startedAt = tonumber(row.started_at) or 0, endedAt = tonumber(row.ended_at) or 0,
			tasks = tonumber(row.tasks) or 0, xp = tonumber(row.xp) or 0, earned = tonumber(row.earned) or 0,
			discarded = tonumber(row.discarded) or 0, reason = row.reason
		}
	end
	return out
end
