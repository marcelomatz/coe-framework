-- Persistência das corridas (coe_database). Funções síncronas: resultado ou nil + código de erro.
RacesPersistence = {}

local function callDatabase(exportName, ...)
	if GetResourceState('coe_database') ~= 'started' then
		return nil, 'database_unavailable'
	end
	local response = promise.new()
	local database = exports['coe_database']
	local args = { database, ... }
	args[#args + 1] = function(success, result, errorCode)
		response:resolve({ success = success == true, result = result, error = errorCode })
	end
	if not pcall(function() database[exportName](table.unpack(args)) end) then
		return nil, 'database_unavailable'
	end
	local result = Citizen.Await(response)
	if not result.success then
		return nil, result.error or 'database_error'
	end
	return result.result
end

local function query(sql, params) return callDatabase('Query', sql, params or {}) end
local function execute(sql, params) return callDatabase('Execute', sql, params or {}) end
local function int(value) return math.tointeger(tonumber(value)) end
local function limit(value) return math.max(1, math.min(500, math.tointeger(value) or 1)) end

local function decode(text, fallback)
	local ok, value = pcall(json.decode, text or '')
	return (ok and type(value) == 'table') and value or fallback
end

function RacesPersistence.Initialize()
	return CoeMigrations.Run({ tableName = 'coe_races_schema_migrations', migrations = RacesMigrations, execute = execute, query = query })
end

-- Pistas -----------------------------------------------------------------------------------------------------------

local TRACK_COLUMNS = 'id, name, description, kind, start_json, checkpoints_json, length_m, creator_id, creator_name, status, races, created_at'

local function trackOf(row)
	return {
		id = int(row.id), name = row.name, description = row.description or '', kind = row.kind,
		start = decode(row.start_json, {}), checkpoints = decode(row.checkpoints_json, {}), length = int(row.length_m) or 0,
		creatorId = row.creator_id and tostring(row.creator_id) or nil, creatorName = row.creator_name or '',
		status = row.status, races = int(row.races) or 0, createdAt = int(row.created_at) or 0
	}
end

function RacesPersistence.Tracks()
	local rows, err = query('SELECT ' .. TRACK_COLUMNS .. ' FROM coe_races_tracks ORDER BY id LIMIT 2000')
	if not rows then return nil, err end
	local list = {}
	for _, row in ipairs(rows) do list[#list + 1] = trackOf(row) end
	return list
end

function RacesPersistence.InsertTrack(t)
	local result, err = execute([[
		INSERT INTO coe_races_tracks (name, description, kind, start_json, checkpoints_json, length_m, creator_id, creator_name, status, created_at)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
	]], { t.name, t.description or '', t.kind, json.encode(t.start), json.encode(t.checkpoints), t.length, t.creatorId,
		t.creatorName or '', t.status or 'active', os.time() })
	if not result then return nil, err end
	return int(result.insertId)
end

function RacesPersistence.SetTrackStatus(id, status)
	return execute('UPDATE coe_races_tracks SET status = ? WHERE id = ?', { status, id })
end

function RacesPersistence.CountRace(id)
	return execute('UPDATE coe_races_tracks SET races = races + 1 WHERE id = ?', { id })
end

-- Pilotos ----------------------------------------------------------------------------------------------------------

local PROFILE_COLUMNS = 'character_id, nickname, rating, races, wins, podiums, dnfs, prize'

local function profileOf(row)
	return {
		characterId = tostring(row.character_id), nickname = row.nickname, rating = int(row.rating) or 0,
		races = int(row.races) or 0, wins = int(row.wins) or 0, podiums = int(row.podiums) or 0,
		dnfs = int(row.dnfs) or 0, prize = int(tonumber(row.prize)) or 0
	}
end

function RacesPersistence.Profile(characterId)
	local rows, err = query('SELECT ' .. PROFILE_COLUMNS .. ' FROM coe_races_profiles WHERE character_id = ? LIMIT 1', { characterId })
	if not rows then return nil, err end
	return rows[1] and profileOf(rows[1]) or false
end

function RacesPersistence.Profiles(ids)
	if #ids == 0 then return {} end
	local marks = {}
	for index = 1, #ids do marks[index] = '?' end
	local rows, err = query('SELECT ' .. PROFILE_COLUMNS .. ' FROM coe_races_profiles WHERE character_id IN (' .. table.concat(marks, ',') .. ')', ids)
	if not rows then return nil, err end
	local map = {}
	for _, row in ipairs(rows) do
		local profile = profileOf(row)
		map[profile.characterId] = profile
	end
	return map
end

function RacesPersistence.SaveNickname(characterId, nickname, rating)
	local result, err = execute([[
		INSERT INTO coe_races_profiles (character_id, nickname, rating, created_at) VALUES (?, ?, ?, ?)
		ON DUPLICATE KEY UPDATE nickname = VALUES(nickname)
	]], { characterId, nickname, rating, os.time() })
	if not result then
		return nil, tostring(err):upper():find('DUP', 1, true) and 'nickname_taken' or err
	end
	return true
end

function RacesPersistence.Leaderboard(size)
	local rows, err = query(('SELECT ' .. PROFILE_COLUMNS .. ' FROM coe_races_profiles WHERE races > 0 ORDER BY rating DESC, wins DESC LIMIT %d')
		:format(limit(size)))
	if not rows then return nil, err end
	local list = {}
	for _, row in ipairs(rows) do list[#list + 1] = profileOf(row) end
	return list
end

function RacesPersistence.ApplyResult(characterId, change, minRating)
	return execute([[
		UPDATE coe_races_profiles SET rating = GREATEST(?, rating + ?), races = races + 1, wins = wins + ?, podiums = podiums + ?,
			dnfs = dnfs + ?, prize = prize + ? WHERE character_id = ?
	]], { minRating, change.delta, change.win and 1 or 0, change.podium and 1 or 0, change.dnf and 1 or 0, change.prize or 0, characterId })
end

-- Corridas e inscrições --------------------------------------------------------------------------------------------

function RacesPersistence.InsertRace(r)
	local result, err = execute([[
		INSERT INTO coe_races_races (track_id, organizer_id, laps, buy_in, class, status, payout_address, created_at)
		VALUES (?, ?, ?, ?, ?, 'lobby', ?, ?)
	]], { r.trackId, r.organizerId, r.laps, r.buyIn, r.class, r.payoutAddress, os.time() })
	if not result then return nil, err end
	return int(result.insertId)
end

function RacesPersistence.SetRaceStatus(id, status)
	return execute('UPDATE coe_races_races SET status = ?, finished_at = ? WHERE id = ?',
		{ status, (status == 'finished' or status == 'cancelled') and os.time() or nil, id })
end

function RacesPersistence.InsertEntry(raceId, characterId, payAddress, payoutAddress, amount)
	return execute([[
		INSERT INTO coe_races_entries (race_id, character_id, pay_address, payout_address, amount, created_at)
		VALUES (?, ?, ?, ?, ?, ?)
	]], { raceId, characterId, payAddress, payoutAddress, amount, os.time() })
end

function RacesPersistence.DeleteEntry(raceId, characterId)
	return execute('DELETE FROM coe_races_entries WHERE race_id = ? AND character_id = ?', { raceId, characterId })
end

function RacesPersistence.SettleEntry(raceId, characterId)
	return execute('UPDATE coe_races_entries SET settled = 1 WHERE race_id = ? AND character_id = ?', { raceId, characterId })
end

---Inscrições com dinheiro ainda na custódia de corridas que não terminaram (o resource caiu no meio): devolver.
function RacesPersistence.Unsettled()
	local rows, err = query([[
		SELECT e.race_id, e.character_id, e.pay_address, e.amount FROM coe_races_entries e
		JOIN coe_races_races r ON r.id = e.race_id
		WHERE e.settled = 0 AND e.amount > 0 AND r.status IN ('lobby', 'running')
	]])
	if not rows then return nil, err end
	local list = {}
	for _, row in ipairs(rows) do
		list[#list + 1] = { raceId = int(row.race_id), characterId = tostring(row.character_id), payAddress = row.pay_address, amount = int(tonumber(row.amount)) or 0 }
	end
	return list
end

function RacesPersistence.CancelStale()
	return execute("UPDATE coe_races_races SET status = 'cancelled', finished_at = ? WHERE status IN ('lobby', 'running')", { os.time() })
end

-- Resultados, recordes e histórico ---------------------------------------------------------------------------------

function RacesPersistence.InsertResult(r)
	return execute([[
		INSERT INTO coe_races_results (race_id, track_id, character_id, nickname, position, racers, time_ms, best_lap_ms, laps, class,
			vehicle, dnf, rating_delta, prize, created_at)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
	]], { r.raceId, r.trackId, r.characterId, r.nickname, r.position, r.racers, r.timeMs, r.bestLapMs, r.laps, r.class,
		r.vehicle or '', r.dnf and 1 or 0, r.ratingDelta or 0, r.prize or 0, os.time() })
end

---Recordes da pista: melhores voltas e melhores tempos totais (para o número de voltas pedido).
function RacesPersistence.Records(trackId, laps, size)
	local lapsRows, err = query(([[
		SELECT nickname, best_lap_ms AS ms, class, vehicle, created_at FROM coe_races_results
		WHERE track_id = ? AND dnf = 0 AND best_lap_ms IS NOT NULL ORDER BY best_lap_ms LIMIT %d
	]]):format(limit(size)), { trackId })
	if not lapsRows then return nil, err end
	local totalRows, totalErr = query(([[
		SELECT nickname, time_ms AS ms, class, vehicle, created_at FROM coe_races_results
		WHERE track_id = ? AND laps = ? AND dnf = 0 AND time_ms IS NOT NULL ORDER BY time_ms LIMIT %d
	]]):format(limit(size)), { trackId, laps })
	if not totalRows then return nil, totalErr end
	local function map(rows)
		local out = {}
		for _, row in ipairs(rows) do
			out[#out + 1] = { nickname = row.nickname, ms = int(row.ms), class = row.class, vehicle = row.vehicle, at = int(row.created_at) }
		end
		return out
	end
	return { laps = map(lapsRows), total = map(totalRows) }
end

function RacesPersistence.History(characterId, size)
	local rows, err = query(([[
		SELECT r.race_id, r.track_id, t.name AS track_name, r.position, r.racers, r.time_ms, r.best_lap_ms, r.laps, r.dnf,
			r.rating_delta, r.prize, r.created_at
		FROM coe_races_results r LEFT JOIN coe_races_tracks t ON t.id = r.track_id
		WHERE r.character_id = ? ORDER BY r.id DESC LIMIT %d
	]]):format(limit(size)), { characterId })
	if not rows then return nil, err end
	local list = {}
	for _, row in ipairs(rows) do
		list[#list + 1] = {
			raceId = int(row.race_id), trackId = int(row.track_id), track = row.track_name or '?', position = int(row.position),
			racers = int(row.racers), timeMs = int(row.time_ms), bestLapMs = int(row.best_lap_ms), laps = int(row.laps),
			dnf = tonumber(row.dnf) == 1, ratingDelta = int(row.rating_delta) or 0, prize = int(tonumber(row.prize)) or 0,
			at = int(row.created_at)
		}
	end
	return list
end
