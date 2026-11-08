-- Servidor das corridas com natives e exports simulados: apelido, pista gravada, corrida com entrada em cripto,
-- grid, contagem, checkpoints conferidos (ordem, raio, velocidade, veículo), voltas, chegada, pote, rating, polícia,
-- abandono, cancelamentos com estorno, app no COE OS e estorno na inicialização.
local netHandlers, handlers, exported, clientEvents, notices, audits = {}, {}, {}, {}, {}, {}
local coreHandlers = {}
local now = 100000
local clock = 1792000000
os.time = function() return clock end
source = nil
local randomValue = 0.99
math.random = function() return randomValue end
math.randomseed = function() end

-- Relógio: timers (SetTimeout) e threads (CreateThread + Wait)
local timers, threads = {}, {}
function GetGameTimer() return now end
function SetTimeout(ms, fn) timers[#timers + 1] = { at = now + ms, fn = fn } end
function CreateThread(fn) local co = coroutine.create(fn); threads[#threads + 1] = co; assert(coroutine.resume(co)) end
function Wait() coroutine.yield() end
local function pump()
	for _, co in ipairs(threads) do
		if coroutine.status(co) == 'suspended' then
			local ok, err = coroutine.resume(co)
			if not ok then error(err) end
		end
	end
end
local function advance(ms)
	local target = now + ms
	while true do
		table.sort(timers, function(a, b) return a.at < b.at end)
		local nextTimer = timers[1]
		if not nextTimer or nextTimer.at > target then break end
		table.remove(timers, 1)
		now = nextTimer.at
		nextTimer.fn()
	end
	now = target
end

function GetResourceState() return 'started' end
function GetCurrentResourceName() return 'coe_races' end
local invoking = nil
function GetInvokingResource() return invoking end
function RegisterNetEvent(name, fn) netHandlers[name] = fn end
function AddEventHandler(name, fn) handlers[name] = fn end
function TriggerClientEvent(name, target, ...) clientEvents[#clientEvents + 1] = { name = name, target = target, args = { ... } } end
local aces = {}
-- O runtime devolve 1/0 (não boolean) em alguns builds.
function IsPlayerAceAllowed(id, ace) return (aces[id] == true and ace == 'coe_races.admin') and 1 or 0 end

-- Jogadores, peds, veículos
local online = { [1] = true, [2] = true, [3] = true }
local characters = { [1] = 11, [2] = 22, [3] = 33 }
local positions, vehicleOf, drivers = {}, {}, {}
function GetPlayers() local list = {} for id in pairs(online) do list[#list + 1] = tostring(id) end return list end
function GetPlayerName(id) return online[id] and ('p' .. id) or nil end
function GetPlayerPed(id) return online[id] and 1000 + id or 0 end
function GetEntityCoords(entity) return positions[entity] or { x = 9999, y = 9999, z = 0 } end
function GetVehiclePedIsIn(ped) return vehicleOf[ped] or 0 end
function NetworkGetNetworkIdFromEntity(entity) return entity end
function GetPedInVehicleSeat(vehicle) return drivers[vehicle] end
local function place(id, x, y, z) positions[1000 + id] = { x = x, y = y, z = z or 30 } end
local function seat(id, vehicle) vehicleOf[1000 + id] = vehicle; if vehicle then drivers[vehicle] = 1000 + id end end

json = {
	encode = function(value)
		local function enc(v)
			if type(v) == 'table' then
				local parts = {}
				for k, item in pairs(v) do parts[#parts + 1] = tostring(k) .. ':' .. enc(item) end
				return '{' .. table.concat(parts, ',') .. '}'
			end
			return tostring(v)
		end
		return enc(value)
	end
}

dofile('../coe_core/lib/algorithms/init.lua')
Core = {
	Algorithms = CoeAlgorithms,
	Platform = dofile('../coe_core/lib/platform.lua'),
	Players = { GetActiveCharacterId = function(id) return characters[id] end },
	Events = { On = function(name, fn) coreHandlers[name] = fn end }
}

-- Exports simulados
local tablets = { [11] = 1, [22] = 1, [33] = 1 }
local wallets = { NOXaaa = 100000, NOXbbb = 100000, NOXccc = 5000, NOXfee = 0, NOXpay = 0 }
local owner = { NOXaaa = 'phone:SER1', NOXbbb = 'phone:SER2', NOXccc = 'racepad:33' }
local escrow, locks, releases, alerts = 0, {}, {}, {}
local cryptoDown = false
exports = setmetatable({}, {
	__call = function(_, name, fn) exported[name] = fn end,
	__index = function(_, resource)
		if resource == 'coe_logging' then return { Log = function() end } end
		if resource == 'coe_audit' then return { Record = function(_, _, _, event, ctx) audits[#audits + 1] = { event = event, ctx = ctx } end } end
		if resource == 'coe_notify' then return { Notify = function(_, id, kind, message) notices[#notices + 1] = { id = id, kind = kind, message = message } end } end
		if resource == 'coe_inventory' then
			return { GetItemCount = function(_, inventoryId, item)
				local characterId = tonumber(inventoryId:match('^character:(%d+)$'))
				return item == 'race_tablet' and (tablets[characterId] or 0) or 0
			end }
		end
		if resource == 'coe_phone' then
			return { ActiveDevice = function(_, id) if id == 1 then return { serial = 'SER1' } elseif id == 2 then return { serial = 'SER2' } end return nil end }
		end
		if resource == 'coe_dispatch' then
			return { Alert = function(_, code, x, y, z) alerts[#alerts + 1] = { code = code, x = x, y = y } return { id = #alerts } end }
		end
		if resource == 'coe_crypto' then
			if cryptoDown then error('crypto down') end
			return {
				Format = function(_, units) return ('%.4f NOX'):format(units / 10000) end,
				IsAddress = function(_, address) return wallets[address] ~= nil end,
				HeldWallets = function(_, _, key)
					local list = {}
					for address, held in pairs(owner) do
						if held == key then list[#list + 1] = { address = address, balance = wallets[address] } end
					end
					return list
				end,
				EscrowLock = function(_, playerId, key, from, amount, memo)
					if owner[from] ~= key then return { ok = false, error = 'not_holder' } end
					if wallets[from] < amount then return { ok = false, error = 'insufficient_funds' } end
					wallets[from] = wallets[from] - amount
					escrow = escrow + amount
					locks[#locks + 1] = { from = from, amount = amount, memo = memo, key = key }
					return { ok = true, txId = #locks }
				end,
				EscrowRelease = function(_, to, amount, memo)
					if amount > escrow then return { ok = false, error = 'escrow_short' } end
					escrow = escrow - amount
					wallets[to] = (wallets[to] or 0) + amount
					releases[#releases + 1] = { to = to, amount = amount, memo = memo }
					return { ok = true }
				end
			}
		end
		return setmetatable({}, { __index = function() return function() return nil end end })
	end
})

-- Persistência em memória
local db = { tracks = {}, profiles = {}, races = {}, entries = {}, results = {}, nextTrack = 0, nextRace = 0 }
local unsettled = {}
local cancelStaleCalls = 0
local function copy(t) local out = {} for k, v in pairs(t) do out[k] = type(v) == 'table' and copy(v) or v end return out end
RacesPersistence = {
	Initialize = function() return true end,
	Tracks = function()
		local list = {}
		for _, t in pairs(db.tracks) do list[#list + 1] = copy(t) end
		return list
	end,
	InsertTrack = function(t)
		db.nextTrack = db.nextTrack + 1
		local row = copy(t)
		row.id = db.nextTrack
		db.tracks[row.id] = row
		return row.id
	end,
	SetTrackStatus = function(id, status) db.tracks[id].status = status return true end,
	CountRace = function(id) db.tracks[id].races = (db.tracks[id].races or 0) + 1 return true end,
	Profile = function(characterId) local p = db.profiles[characterId] return p and copy(p) or false end,
	Profiles = function(ids) local map = {} for _, id in ipairs(ids) do if db.profiles[id] then map[id] = copy(db.profiles[id]) end end return map end,
	SaveNickname = function(characterId, nickname, rating)
		for id, p in pairs(db.profiles) do
			if id ~= characterId and p.nickname:lower() == nickname:lower() then return nil, 'nickname_taken' end
		end
		local p = db.profiles[characterId] or { characterId = characterId, rating = rating, races = 0, wins = 0, podiums = 0, dnfs = 0, prize = 0 }
		p.nickname = nickname
		db.profiles[characterId] = p
		return true
	end,
	Leaderboard = function()
		local list = {}
		for _, p in pairs(db.profiles) do if p.races > 0 then list[#list + 1] = copy(p) end end
		table.sort(list, function(a, b) return a.rating > b.rating end)
		return list
	end,
	ApplyResult = function(characterId, change, minRating)
		local p = db.profiles[characterId]
		p.rating = math.max(minRating, p.rating + change.delta)
		p.races = p.races + 1
		p.wins = p.wins + (change.win and 1 or 0)
		p.podiums = p.podiums + (change.podium and 1 or 0)
		p.dnfs = p.dnfs + (change.dnf and 1 or 0)
		p.prize = p.prize + (change.prize or 0)
		return true
	end,
	InsertRace = function(r) db.nextRace = db.nextRace + 1 local row = copy(r) row.status = 'lobby' db.races[db.nextRace] = row return db.nextRace end,
	SetRaceStatus = function(id, status) if db.races[id] then db.races[id].status = status end return true end,
	InsertEntry = function(raceId, characterId, payAddress, payoutAddress, amount)
		db.entries[raceId .. ':' .. characterId] = { pay = payAddress, payout = payoutAddress, amount = amount, settled = false }
		return true
	end,
	DeleteEntry = function(raceId, characterId) db.entries[raceId .. ':' .. characterId] = nil return true end,
	SettleEntry = function(raceId, characterId)
		local e = db.entries[raceId .. ':' .. characterId]
		if e then e.settled = true end
		for _, u in ipairs(unsettled) do if u.raceId == raceId and u.characterId == characterId then u.done = true end end
		return true
	end,
	Unsettled = function() return unsettled end,
	CancelStale = function() cancelStaleCalls = cancelStaleCalls + 1 return true end,
	InsertResult = function(r) db.results[#db.results + 1] = copy(r) return true end,
	Records = function() return { laps = {}, total = {} } end,
	History = function(characterId)
		local list = {}
		for _, r in ipairs(db.results) do if r.characterId == characterId then list[#list + 1] = r end end
		return list
	end
}

-- Uma entrada pendente de uma corrida que caiu no meio: devolvida na inicialização.
unsettled[1] = { raceId = 99, characterId = '22', payAddress = 'NOXbbb', amount = 3000 }
escrow = 3000

dofile('config.lua')
dofile('shared/rules.lua')
dofile('server/main.lua')
local config = RacesConfig

local function eq(a, b, m)
	if a ~= b then error(('%s: esperado %s, veio %s'):format(m, tostring(b), tostring(a)), 2) end
end

local function eventsFor(name, target)
	local list = {}
	for _, e in ipairs(clientEvents) do
		if e.name == name and (target == nil or e.target == target) then list[#list + 1] = e end
	end
	return list
end
local function lastEvent(name, target) local list = eventsFor(name, target) return list[#list] end

local requestId = 0
local function call(playerId, action, payload)
	requestId = requestId + 1
	now = now + 1000
	source = playerId
	netHandlers['coe_races:call'](requestId, action, payload)
	local last = lastEvent('coe_races:result', playerId)
	eq(last.args[1], requestId, 'resposta do pedido')
	return last.args[2]
end

-- Inicialização: estorno do que ficou na custódia
pump()
eq(releases[1].to, 'NOXbbb', 'estorno da corrida que caiu')
eq(releases[1].amount, 3000, 'valor do estorno')
eq(unsettled[1].done, true, 'entrada liquidada')
eq(cancelStaleCalls, 1, 'corridas antigas canceladas')
wallets.NOXbbb = 100000

-- Sem tablet
tablets[33] = 0
eq(call(3, 'state').error, 'no_tablet', 'precisa do tablet')
tablets[33] = 1
eq(call(1, 'nope').error, 'unknown_action', 'acao desconhecida')
eq(call(1, 'state', 'x').error, 'invalid_payload', 'payload invalido')

-- Apelido
local state = call(1, 'state')
eq(state.ok, true, 'estado')
eq(state.data.profile, nil, 'sem perfil ainda')
eq(call(1, 'createRace', { trackId = 1 }).error, 'no_nickname', 'precisa de apelido')
eq(call(1, 'setNickname', { nickname = 'a b' }).error, 'invalid_nickname', 'apelido invalido')
eq(call(1, 'setNickname', { nickname = 'Toretto' }).data.profile.nickname, 'Toretto', 'apelido salvo')
eq(call(2, 'setNickname', { nickname = 'toretto' }).error, 'nickname_taken', 'apelido repetido')
eq(call(2, 'setNickname', { nickname = 'Brian' }).ok, true, 'segundo piloto')
eq(call(3, 'setNickname', { nickname = 'Letty' }).ok, true, 'terceiro piloto')

-- Pista: só quem já correu (ou a staff)
local trackData = { name = 'Volta do Porto', description = 'Pelo cais', kind = 'circuit', start = { x = 0, y = 0, z = 30, h = 90 },
	checkpoints = { { x = 200, y = 0, z = 30 }, { x = 200, y = 200, z = 30 }, { x = 0, y = 200, z = 30 } } }
eq(call(2, 'startRecording', trackData).error, 'not_enough_races', 'piloto novo nao cria')
eq(call(2, 'saveTrack', trackData).error, 'not_enough_races', 'piloto novo nao salva')
aces[1] = true
eq(call(1, 'startRecording', { name = 'x', kind = 'circuit' }).error, 'invalid_name', 'nome curto')
eq(call(1, 'startRecording', { name = 'Volta', kind = 'loop' }).error, 'invalid_kind', 'tipo invalido')
eq(call(1, 'startRecording', { name = 'Volta do Porto', kind = 'circuit', featured = true }).ok, true, 'staff grava')
local record = lastEvent('coe_races:record', 1)
eq(record.args[1].kind, 'circuit', 'client recebe o tipo')
eq(record.args[1].featured, true, 'staff pode destacar')
trackData.featured = true
local saved = call(1, 'saveTrack', trackData)
eq(saved.ok, true, 'pista salva')
eq(saved.data.track.checkpoints, 4, 'circuito fechado na largada')
eq(saved.data.track.status, 'featured', 'destaque da staff')
local trackId = saved.data.track.id
eq(call(1, 'saveTrack', { name = 'Ruim', kind = 'sprint', start = trackData.start, checkpoints = { { x = 5, y = 0, z = 30 } } }).error, 'checkpoints_too_close', 'pista ruim')
eq(#call(2, 'tracks').data.tracks, 1, 'pista na lista')
eq(call(2, 'track', { id = trackId, laps = 2 }).data.track.name, 'Volta do Porto', 'detalhe da pista')

-- Carteiras do celular
local held = call(1, 'wallets')
eq(held.data.wallets[1].address, 'NOXaaa', 'carteira do celular')
eq(held.data.wallets[1].balanceText, '10.0000 NOX', 'saldo formatado')

-- Criar corrida com entrada
local raceOptions = { trackId = trackId, laps = 2, buyIn = 10000, class = 'sports', maxRacers = 3, startIn = 5, join = true,
	from = 'NOXaaa', feeAddress = 'NOXfee' }
eq(call(1, 'createRace', { trackId = trackId, laps = 2, buyIn = 10000, class = 'sports', join = true, from = 'NOXaaa', feeAddress = 'nope' }).error, 'invalid_payout', 'carteira da taxa')
eq(call(1, 'createRace', { trackId = trackId, buyIn = 10000, class = 'sports', join = true, from = 'NOXbbb', feeAddress = 'NOXfee' }).error, 'not_holder', 'carteira de outro')
local created = call(1, 'createRace', raceOptions)
eq(created.ok, true, 'corrida criada')
eq(#created.data.races, 1, 'corrida aberta')
local race = created.data.races[1]
eq(race.joined, true, 'organizador inscrito')
eq(race.mine, true, 'organizador')
eq(wallets.NOXaaa, 90000, 'entrada travada')
eq(locks[#locks].key, 'phone:SER1', 'chave do celular')
eq(lastEvent('coe_races:joined', 1).args[1].laps, 2, 'client recebe a corrida')
eq(call(1, 'createRace', raceOptions).error, 'already_organizing', 'uma por organizador')

-- Inscrições
eq(call(2, 'join', { raceId = race.id, from = 'NOXaaa' }).error, 'not_holder', 'carteira alheia')
eq(call(3, 'join', { raceId = race.id, from = 'NOXccc' }).error, 'insufficient_funds', 'sem saldo')
eq(call(2, 'join', { raceId = race.id, from = 'NOXbbb', payout = 'NOXpay' }).ok, true, 'segundo inscrito')
eq(wallets.NOXbbb, 90000, 'entrada do segundo')
eq(call(2, 'join', { raceId = race.id, from = 'NOXbbb' }).error, 'already_racing', 'inscricao dupla')
eq(call(2, 'leave', { raceId = race.id }).ok, true, 'sai do lobby')
eq(wallets.NOXbbb, 100000, 'estorno ao sair')
eq(call(2, 'join', { raceId = race.id, from = 'NOXbbb', payout = 'NOXpay' }).ok, true, 'volta')
eq(call(2, 'startNow', { raceId = race.id }).error, 'not_organizer', 'so o organizador larga')
eq(call(2, 'setNickname', { nickname = 'Brian2' }).error, 'in_race', 'nao troca apelido inscrito')

-- Largada: grid e contagem
place(1, 5, 5); seat(1, 501)
place(2, -5, 5); seat(2, 502)
eq(call(1, 'startNow', { raceId = race.id }).ok, true, 'larga agora')
eq(lastEvent('coe_races:prepare', 2).args[1].id, race.id, 'preparar')
source = 1; netHandlers['coe_races:ready'](race.id, { netId = 501, classId = 6, label = 'Elegy<x>', sirens = false })
source = 2; netHandlers['coe_races:ready'](race.id, { netId = 502, classId = 6, label = 'Jester', sirens = true })
randomValue = 0.0 -- polícia sempre avisada
advance(3000)
local hud = lastEvent('coe_races:race', 1)
eq(hud.args[1].status, 'countdown', 'contagem')
eq(#hud.args[1].checkpoints, 4, 'checkpoints no client')
eq(hud.args[1].goIn, config.Races.CountdownSeconds * 1000, 'vai em')
eq(#hud.args[1].vehicles, 2, 'veiculos do grid para o fantasma')
eq(call(3, 'join', { raceId = race.id, from = 'NOXccc' }).error, 'race_started', 'nao entra depois')
advance(config.Races.CountdownSeconds * 1000)
eq(lastEvent('coe_races:go', 2) ~= nil, true, 'vai')
eq(alerts[1].code, 'street_race', 'policia avisada na largada')
eq(alerts[1].x, 0, 'na largada')

-- Checkpoints
local cps = { { 200, 0 }, { 200, 200 }, { 0, 200 }, { 0, 0 } }
local function cross(id, index, raceId)
	local cp = cps[((index - 1) % 4) + 1]
	place(id, cp[1] + 3, cp[2] - 2)
	source = id
	netHandlers['coe_races:checkpoint'](raceId or race.id, index)
end
now = now + 10000
cross(1, 2)
eq(lastEvent('coe_races:lap', 1), nil, 'fora de ordem ignorado')
cross(1, 1)
cross(2, 1)
place(1, 500, 500)
source = 1; netHandlers['coe_races:checkpoint'](race.id, 2)
cross(1, 2) -- logo depois do 1 (posição pulou 200 m em 0 s)
now = now + 10000
cross(1, 2)
now = now + 10000
seat(2, nil)
cross(2, 2)
seat(2, 502)
-- tick: posições
pump()
local standing = lastEvent('coe_races:standings', 2)
eq(standing.args[1].position, 2, 'segundo lugar')
eq(standing.args[1].list[1].nickname, 'Toretto', 'lider')
cross(2, 2)
for index = 3, 4 do now = now + 10000; cross(1, index); cross(2, index) end
eq(lastEvent('coe_races:checkpointOk', 1).args[2], 4, 'confirmacao do checkpoint')
local lap = lastEvent('coe_races:lap', 1)
eq(lap.args[2], 1, 'volta 1')
eq(lap.args[3] > 0, true, 'tempo da volta')
for index = 5, 8 do now = now + 10000; cross(1, index) end
eq(lastEvent('coe_races:finished', 1) ~= nil, true, 'chegou')
eq(lastEvent('coe_races:leaderFinished', 2).args[1].nickname, 'Toretto', 'aviso do vencedor')
for index = 5, 8 do now = now + 10000; cross(2, index) end

-- Resultado: pote, taxa e rating
local results = lastEvent('coe_races:results', 2).args[1]
eq(results.results[1].nickname, 'Toretto', 'vencedor')
eq(results.results[1].prize, 19000, 'premio do vencedor (pote - 5%)')
eq(results.results[2].prize, 0, 'segundo sem premio com 2 corredores')
eq(wallets.NOXaaa, 90000 + 19000, 'premio na carteira')
eq(wallets.NOXfee, 1000, 'taxa do organizador')
eq(escrow, 0, 'custodia zerada')
eq(results.results[1].ratingDelta, 12, 'rating sobe')
eq(db.profiles['11'].rating, 1012, 'rating gravado')
eq(db.profiles['11'].wins, 1, 'vitoria')
eq(db.profiles['22'].podiums, 1, 'podio')
eq(db.results[1].vehicle, 'Elegyx', 'veiculo limpo')
eq(db.results[1].bestLapMs ~= nil, true, 'melhor volta')
eq(db.races[race.id].status, 'finished', 'corrida encerrada')
eq(db.tracks[trackId].races, 1, 'contador da pista')
eq(call(1, 'history').data.history[1].position, 1, 'historico')
eq(call(1, 'leaderboard').data.leaders[1].nickname, 'Toretto', 'ranking')

-- Corrida 2: sem aposta, largada agendada, um fora do grid e outro fora do carro, polícia no meio
randomValue = 0.99
local second = call(2, 'createRace', { trackId = trackId, laps = 1, buyIn = 0, class = 'any', startIn = 1, join = true })
eq(second.ok, true, 'corrida sem aposta')
local race2 = second.data.races[1]
eq(call(1, 'join', { raceId = race2.id }).ok, true, 'inscrito sem carteira')
eq(call(3, 'join', { raceId = race2.id }).ok, true, 'terceiro inscrito')
place(1, 0, 0); seat(1, 501)
place(2, 2, 2); seat(2, 502)
place(3, 900, 900); seat(3, 503)
clock = clock + 61
pump()
eq(lastEvent('coe_races:prepare', 3).args[1].id, race2.id, 'largada agendada')
source = 1; netHandlers['coe_races:ready'](race2.id, { netId = 501, classId = 6 })
source = 2; netHandlers['coe_races:ready'](race2.id, { netId = 502, classId = 7 })
source = 3; netHandlers['coe_races:ready'](race2.id, { netId = 503, classId = 1 })
advance(3000)
eq(lastEvent('coe_races:left', 3).args[2], 'not_on_grid', 'fora do grid sai')
advance(config.Races.CountdownSeconds * 1000)
now = now + 1000
seat(1, nil)
pump()
now = now + (config.Races.OutOfVehicleSeconds + 1) * 1000
pump()
eq(lastEvent('coe_races:dnf', 1).args[2], 'left_vehicle', 'abandono fora do carro')
randomValue = 0.0
local alertsBefore = #alerts
now = now + config.Police.TickSeconds * 1000
pump()
eq(#alerts, alertsBefore + 1, 'policia na posicao do lider')
source = 2
netHandlers['coe_races:quit'](race2.id)
local results2 = lastEvent('coe_races:results', 2).args[1]
eq(results2.results[1].dnf, true, 'ninguem terminou')
eq(db.profiles['11'].dnfs, 1, 'abandono contado')

-- Corrida 3: cancelada pelo organizador com estorno; staff cancela qualquer uma
local third = call(3, 'createRace', { trackId = trackId, buyIn = 5000, class = 'any', join = true, from = 'NOXccc', feeAddress = 'NOXfee' })
eq(third.ok, true, 'corrida 3')
eq(wallets.NOXccc, 0, 'entrada travada')
eq(locks[#locks].key, 'racepad:33', 'sem celular: chave do personagem')
local race3 = third.data.races[1]
eq(call(2, 'cancelRace', { raceId = race3.id }).error, 'not_organizer', 'outro nao cancela')
eq(call(1, 'cancelRace', { raceId = race3.id }).ok, true, 'staff cancela')
eq(wallets.NOXccc, 5000, 'estorno no cancelamento')
eq(db.races[race3.id].status, 'cancelled', 'status cancelado')

-- Largada agendada sem gente suficiente
wallets.NOXccc = 5000
local fourth = call(3, 'createRace', { trackId = trackId, buyIn = 5000, class = 'any', startIn = 1, join = true, from = 'NOXccc', feeAddress = 'NOXfee' })
eq(fourth.ok, true, 'corrida 4')
clock = clock + 61
pump()
eq(wallets.NOXccc, 5000, 'estorno sem corredores')
eq(call(3, 'state').data.races[1], nil, 'nada aberto')

-- Moderação de pistas
eq(call(2, 'trackStatus', { id = trackId, status = 'hidden' }).error, 'forbidden', 'so staff ou criador')
eq(call(1, 'trackStatus', { id = trackId, status = 'hidden' }).ok, true, 'staff oculta')
eq(#call(2, 'tracks').data.tracks, 0, 'pista oculta some')
eq(call(2, 'createRace', { trackId = trackId, class = 'any' }).error, 'unknown_track', 'pista oculta nao corre')
eq(call(1, 'trackStatus', { id = trackId, status = 'active' }).ok, true, 'staff reativa')

-- Staff pelo txAdmin
eq(call(2, 'state').data.admin, false, 'jogador comum nao e staff')
handlers['txAdmin:events:adminAuth']({ netid = 2, isAdmin = true })
eq(call(2, 'state').data.admin, true, 'admin do txAdmin e staff')
handlers['txAdmin:events:adminAuth']({ netid = 2, isAdmin = false })
eq(call(2, 'state').data.admin, false, 'logout do txAdmin')
eq(call(1, 'state').data.admin, true, 'ACE que volta 1 vale')

-- App no COE OS
invoking = 'coe_other'
eq(exported.TabletCall(1, 'races', 'state', {}).error, 'forbidden', 'so o coe_tablet')
eq(exported.TabletVisible(1, 'races'), false, 'so o coe_tablet ve')
invoking = 'coe_tablet'
eq(exported.TabletVisible(1, 'races'), true, 'app visivel com o item')
tablets[11] = 0
eq(exported.TabletVisible(1, 'races'), false, 'sem item sem app')
tablets[11] = 1
now = now + 1000
eq(exported.TabletCall(1, 'races', 'state', {}).ok, true, 'acao pelo tablet')
invoking = nil

-- Usar o item abre o tablet
coreHandlers['inventory.itemUsed']('character:22', 1, { name = 'race_tablet' })
eq(lastEvent('coe_races:opened', 2) ~= nil, true, 'item abre o tablet')

-- Jogador cai no meio da corrida
local fifth = call(1, 'createRace', { trackId = trackId, class = 'any', join = true })
local race5 = fifth.data.races[1]
eq(call(2, 'join', { raceId = race5.id }).ok, true, 'inscrito na 5')
place(1, 0, 0); seat(1, 501)
place(2, 2, 2); seat(2, 502)
eq(call(1, 'startNow', { raceId = race5.id }).ok, true, 'larga a 5')
source = 1; netHandlers['coe_races:ready'](race5.id, { netId = 501, classId = 6 })
source = 2; netHandlers['coe_races:ready'](race5.id, { netId = 502, classId = 6 })
advance(3000 + config.Races.CountdownSeconds * 1000)
online[2] = nil
source = 2
handlers.playerDropped()
eq(lastEvent('coe_races:dnf', 2).args[2], 'offline', 'caiu: abandono')
for index = 1, 4 do now = now + 10000; cross(1, index, race5.id) end
eq(lastEvent('coe_races:results', 1).args[1].results[1].nickname, 'Toretto', 'termina sem quem caiu')
online[2] = true

-- Parar o resource devolve entradas abertas
wallets.NOXccc = 5000
call(3, 'createRace', { trackId = trackId, buyIn = 5000, class = 'any', join = true, from = 'NOXccc', feeAddress = 'NOXfee' })
eq(wallets.NOXccc, 0, 'travado antes de parar')
handlers.onResourceStop('coe_races')
eq(wallets.NOXccc, 5000, 'estorno ao parar')

print('coe_races server_test: ok')
