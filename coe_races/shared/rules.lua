-- Regras das corridas, sem natives (testáveis fora do jogo).
RacesRules = {}

local function dist2d(a, b)
	local dx, dy = a.x - b.x, a.y - b.y
	return math.sqrt(dx * dx + dy * dy)
end

local function dist3d(a, b)
	local dx, dy, dz = a.x - b.x, a.y - b.y, (a.z or 0) - (b.z or 0)
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end
RacesRules.Distance = dist3d

local function number(value, min, max)
	value = tonumber(value)
	if not value or value ~= value or value < min or value > max then
		return nil
	end
	return value
end

local function integer(value, min, max)
	value = math.tointeger(tonumber(value))
	if not value or value < min or value > max then
		return nil
	end
	return value
end
RacesRules.Integer = integer

---Texto de uma linha, sem controle nem < >, com tamanho em caracteres (UTF-8).
function RacesRules.Text(value, min, max)
	if type(value) ~= 'string' or #value > max * 4 then
		return nil
	end
	value = value:gsub('[%c<>]', ' '):gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
	local length = utf8.len(value)
	if not length or length < min or length > max then
		return nil
	end
	return value
end

---Apelido de piloto: letras, números, _ e - (sem espaço), para aparecer igual em todo lugar.
function RacesRules.Nickname(value, config)
	if type(value) ~= 'string' then
		return nil, 'invalid_nickname'
	end
	value = value:gsub('^%s+', ''):gsub('%s+$', '')
	if #value < config.Nickname.Min or #value > config.Nickname.Max or not value:match('^[%w_%-]+$') then
		return nil, 'invalid_nickname'
	end
	return value
end

local function point(raw)
	if type(raw) ~= 'table' then
		return nil
	end
	local x, y = number(raw.x, -10000, 10000), number(raw.y, -10000, 10000)
	local z = number(raw.z, -500, 3000)
	if not (x and y and z) then
		return nil
	end
	return { x = math.floor(x * 100 + 0.5) / 100, y = math.floor(y * 100 + 0.5) / 100, z = math.floor(z * 100 + 0.5) / 100 }
end
RacesRules.Point = point

---Pista gravada: largada { x, y, z, h } e checkpoints em ordem. Circuito: o último checkpoint é a linha de chegada,
---colada na largada (acrescentada aqui se o piloto não fechou a volta). Retorna { kind, start, checkpoints, length }.
function RacesRules.Track(config, raw)
	if type(raw) ~= 'table' then
		return nil, 'invalid_track'
	end
	local kind = raw.kind == 'circuit' and 'circuit' or (raw.kind == 'sprint' and 'sprint' or nil)
	if not kind then
		return nil, 'invalid_kind'
	end
	local start = point(raw.start)
	local heading = number(raw.start and raw.start.h or 0, -360, 720)
	if not start or not heading then
		return nil, 'invalid_start'
	end
	start.h = math.floor((heading % 360) * 10 + 0.5) / 10
	local list = type(raw.checkpoints) == 'table' and raw.checkpoints or {}
	local limits = config.Tracks
	local checkpoints = {}
	local previous = start
	for index, entry in ipairs(list) do
		local p = point(entry)
		if not p then
			return nil, 'invalid_checkpoint'
		end
		if index > limits.MaxCheckpoints then
			return nil, 'too_many_checkpoints'
		end
		if dist2d(previous, p) < limits.MinSpacing then
			return nil, 'checkpoints_too_close'
		end
		p.r = number(entry.r or limits.CheckpointRadius, 4, 30) or limits.CheckpointRadius
		checkpoints[#checkpoints + 1] = p
		previous = p
	end
	if kind == 'circuit' then
		local last = checkpoints[#checkpoints]
		if not last or dist2d(last, start) > limits.CheckpointRadius * 2 then
			checkpoints[#checkpoints + 1] = { x = start.x, y = start.y, z = start.z, r = limits.CheckpointRadius }
		end
	end
	if #checkpoints < limits.MinCheckpoints then
		return nil, 'too_few_checkpoints'
	end
	if #checkpoints > limits.MaxCheckpoints then
		return nil, 'too_many_checkpoints'
	end
	return { kind = kind, start = start, checkpoints = checkpoints, length = RacesRules.Length(start, checkpoints) }
end

---Comprimento de uma volta (m): da largada ao último checkpoint, em linha reta entre os pontos.
function RacesRules.Length(start, checkpoints)
	local total, previous = 0, start
	for _, cp in ipairs(checkpoints) do
		total = total + dist2d(previous, cp)
		previous = cp
	end
	return math.floor(total + 0.5)
end

-- Corrida ------------------------------------------------------------------------------------------------------

---Opções do organizador validadas contra a pista. Retorna { laps, buyIn, class, maxRacers, startIn } ou nil + erro.
function RacesRules.RaceOptions(config, track, data)
	if type(data) ~= 'table' then
		return nil, 'invalid_options'
	end
	local laps = 1
	if track.kind == 'circuit' then
		laps = integer(data.laps or 1, 1, config.Tracks.MaxLaps)
	end
	if not laps then
		return nil, 'invalid_laps'
	end
	local buyIn = integer(data.buyIn or 0, config.BuyIn.Min, config.BuyIn.Max)
	if not buyIn then
		return nil, 'invalid_buy_in'
	end
	local class = type(data.class) == 'string' and config.Classes[data.class] and data.class or nil
	if not class then
		return nil, 'invalid_class'
	end
	local maxRacers = integer(data.maxRacers or config.Races.MaxRacers, config.Races.MinRacers, config.Races.MaxRacers)
	if not maxRacers then
		return nil, 'invalid_max_racers'
	end
	local startIn = integer(data.startIn or 5, config.Races.MinStartMinutes, config.Races.MaxStartMinutes)
	if not startIn then
		return nil, 'invalid_start_time'
	end
	return { laps = laps, buyIn = buyIn, class = class, maxRacers = maxRacers, startIn = startIn }
end

---O veículo (classe do GetVehicleClass) pode correr nesta classe?
function RacesRules.ClassAllowed(config, classKey, classId)
	classId = math.tointeger(tonumber(classId))
	if not classId then
		return false
	end
	for _, blocked in ipairs(config.BlockedClasses) do
		if blocked == classId then
			return false
		end
	end
	local class = config.Classes[classKey]
	if not class then
		return false
	end
	if not class.ids then
		return true
	end
	for _, id in ipairs(class.ids) do
		if id == classId then
			return true
		end
	end
	return false
end

---Tempo máximo da prova (s), pelo tamanho total.
function RacesRules.MaxDuration(config, length, laps)
	local km = (length * laps) / 1000
	return math.max(config.Races.MinMaxSeconds, math.floor(km * config.Races.MaxSecondsPerKm + 0.5))
end

---Checkpoint cruzado de verdade? at = posição do corredor no servidor; previous = { at, time } do último.
---Retorna true ou nil + motivo.
function RacesRules.CheckpointOk(config, cp, at, previous, now)
	if type(at) ~= 'table' then
		return nil, 'no_position'
	end
	if dist2d(cp, at) > (cp.r or config.Tracks.CheckpointRadius) + config.Races.RadiusSlack or math.abs((at.z or 0) - (cp.z or 0)) > 25 then
		return nil, 'too_far'
	end
	if previous and previous.at and previous.time then
		local seconds = math.max(0.001, (now - previous.time) / 1000)
		if dist2d(previous.at, cp) / seconds > config.Races.MaxSpeed then
			return nil, 'too_fast'
		end
	end
	return true
end

local function getAlgorithms()
	return (type(Core) == 'table' and Core.Algorithms) or CoeAlgorithms
end

local function compareStandings(a, b)
	if (a.dnf == true) ~= (b.dnf == true) then
		return not a.dnf
	end
	if a.finishedAt and b.finishedAt then
		return a.finishedAt < b.finishedAt
	end
	if (a.finishedAt ~= nil) ~= (b.finishedAt ~= nil) then
		return a.finishedAt ~= nil
	end
	if a.progress ~= b.progress then
		return a.progress > b.progress
	end
	if (a.distance or 0) ~= (b.distance or 0) then
		return (a.distance or 0) < (b.distance or 0)
	end
	return tostring(a.id) < tostring(b.id)
end

local function standingPriority(entry, index)
	local base
	if entry.dnf == true then
		base = 2e11 - (entry.progress or 0) * 1e6 + math.min(999999, math.max(0, entry.distance or 0))
	elseif entry.finishedAt then
		base = math.max(0, entry.finishedAt)
	else
		base = 1e11 - (entry.progress or 0) * 1e6 + math.min(999999, math.max(0, entry.distance or 0))
	end
	return base + (index * 1e-4)
end

---Ordem atual: quem terminou (pelo tempo), depois quem anda (mais checkpoints e menor distância ao próximo), e por
---último os que abandonaram. entries: { id, progress, distance, finishedAt, dnf }.
function RacesRules.Standings(entries)
	local alg = getAlgorithms()
	local list = {}
	if alg and alg.Containers and alg.Containers.newMinHeap and #entries > 0 then
		local heap = alg.Containers.newMinHeap()
		local byKey = {}
		for i, entry in ipairs(entries) do
			local key = i
			byKey[key] = entry
			heap:push(key, standingPriority(entry, i))
		end
		while heap:size() > 0 do
			local key = heap:pop()
			list[#list + 1] = byKey[key]
		end
		table.sort(list, compareStandings)
	else
		for _, entry in ipairs(entries) do
			list[#list + 1] = entry
		end
		table.sort(list, compareStandings)
	end
	for index, entry in ipairs(list) do
		entry.position = index
	end
	return list
end

---Divisão do pote. starters = quantos largaram; finishers = colocações de quem terminou (1..n).
---Retorna { fee, prizes = { [posição] = unidades } }. Sem ninguém na chegada, devolve nil (estorno).
function RacesRules.Payouts(config, pot, starters, finishers)
	if pot <= 0 or finishers <= 0 then
		return nil
	end
	local fee = math.floor(pot * config.BuyIn.OrganizerFeeBps / 10000)
	local net = pot - fee
	local table_ = nil
	local best = 0
	for minimum, shares in pairs(config.BuyIn.Payouts) do
		if starters >= minimum and minimum > best then
			best, table_ = minimum, shares
		end
	end
	table_ = table_ or { 100 }
	local prizes, given = {}, 0
	for place, share in ipairs(table_) do
		if place <= finishers then
			prizes[place] = math.floor(net * share / 100)
			given = given + prizes[place]
		end
	end
	-- Sobra (posições sem quem terminou e arredondamento) vai para o 1º.
	prizes[1] = (prizes[1] or 0) + (net - given)
	return { fee = fee, prizes = prizes }
end

---Rating tipo Elo multijogador. results: { { id, rating, place } } (place 1 é o melhor; empates não acontecem).
---Retorna { [id] = delta }.
function RacesRules.Rating(config, results)
	local n = #results
	local deltas = {}
	if n < 2 then
		for _, r in ipairs(results) do deltas[r.id] = 0 end
		return deltas
	end
	local k = config.Rating.K / (n - 1)
	for _, a in ipairs(results) do
		local sum = 0
		for _, b in ipairs(results) do
			if a ~= b then
				local expected = 1 / (1 + 10 ^ ((b.rating - a.rating) / 400))
				local score = a.place < b.place and 1 or 0
				sum = sum + (score - expected)
			end
		end
		deltas[a.id] = math.floor(k * sum + 0.5)
	end
	return deltas
end

---Chance de a polícia ser avisada na largada.
function RacesRules.PoliceChance(config, racers, sirens)
	local police = config.Police
	local chance = police.StartChance + police.PerRacer * math.max(0, racers - 2) + (sirens and police.SirenBonus or 0)
	return math.min(police.MaxChance, chance)
end

---Tempo em ms como m:ss.mmm.
function RacesRules.FormatTime(ms)
	ms = math.max(0, math.floor(tonumber(ms) or 0))
	local minutes = ms // 60000
	local seconds = (ms % 60000) // 1000
	return ('%d:%02d.%03d'):format(minutes, seconds, ms % 1000)
end

---Executa uma Saga transacional com compensação LIFO (ex.: EscrowLock + InsertEntry).
function RacesRules.ExecuteSaga(steps, context)
	local alg = getAlgorithms()
	if alg and alg.Concurrency and alg.Concurrency.executeSaga then
		return alg.Concurrency.executeSaga(steps, context)
	end
	local completed = {}
	local ctx = context or {}
	for i = 1, #steps do
		local ok, res = pcall(steps[i].action, ctx)
		if not ok or res == false then
			for j = #completed, 1, -1 do
				if completed[j].compensate then
					pcall(completed[j].compensate, ctx)
				end
			end
			return false, not ok and res or 'step_failed'
		end
		completed[#completed + 1] = steps[i]
	end
	return true, ctx
end

---Cria rate limiter GCRA O(1) para ações do tablet de corridas.
function RacesRules.NewCallLimiter(cooldownMs)
	local alg = getAlgorithms()
	if alg and alg.RateLimit and alg.RateLimit.newGCRA then
		return alg.RateLimit.newGCRA(cooldownMs or 250, 0)
	end
	return nil
end

