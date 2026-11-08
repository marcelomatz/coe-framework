-- Regras das corridas: pista gravada, opções da corrida, classes, checkpoints, posições, pote, rating e polícia.
dofile('../coe_core/lib/algorithms/init.lua')
dofile('config.lua')
dofile('shared/rules.lua')
local config, R = RacesConfig, RacesRules

local function eq(a, b, m)
	if a ~= b then error(('%s: esperado %s, veio %s'):format(m, tostring(b), tostring(a)), 2) end
end

-- Texto e apelido
eq(R.Text('  Rua  <b>Grove</b> ', 3, 32), 'Rua b Grove /b', 'texto limpo')
eq(R.Text('ab', 3, 32), nil, 'texto curto')
eq(R.Text(('x'):rep(40), 3, 32), nil, 'texto longo')
eq(R.Nickname('Toretto_99', config), 'Toretto_99', 'apelido valido')
eq(R.Nickname('to', config), nil, 'apelido curto')
eq(R.Nickname('com espaco', config), nil, 'apelido sem espaco')

-- Pista: sprint
local raw = { kind = 'sprint', start = { x = 0, y = 0, z = 30, h = 370 }, checkpoints = {
	{ x = 100, y = 0, z = 30 }, { x = 200, y = 0, z = 30 }, { x = 300, y = 0, z = 30 } } }
local track = assert(R.Track(config, raw))
eq(track.kind, 'sprint', 'tipo')
eq(track.start.h, 10, 'heading normalizado')
eq(#track.checkpoints, 3, 'checkpoints')
eq(track.checkpoints[1].r, config.Tracks.CheckpointRadius, 'raio padrao')
eq(track.length, 300, 'comprimento')
eq(select(2, R.Track(config, { kind = 'drag', start = raw.start, checkpoints = raw.checkpoints })), 'invalid_kind', 'tipo invalido')
eq(select(2, R.Track(config, { kind = 'sprint', start = raw.start, checkpoints = { raw.checkpoints[1], raw.checkpoints[2] } })), 'too_few_checkpoints', 'poucos')
eq(select(2, R.Track(config, { kind = 'sprint', start = raw.start, checkpoints = { { x = 10, y = 0, z = 30 }, raw.checkpoints[2], raw.checkpoints[3] } })), 'checkpoints_too_close', 'perto da largada')
eq(select(2, R.Track(config, { kind = 'sprint', start = raw.start, checkpoints = { { x = 'a' } } })), 'invalid_checkpoint', 'ponto invalido')
eq(select(2, R.Track(config, { kind = 'sprint', start = { x = 99999, y = 0, z = 0 }, checkpoints = raw.checkpoints })), 'invalid_start', 'largada fora do mapa')
local many = {}
for i = 1, config.Tracks.MaxCheckpoints + 1 do many[i] = { x = i * 30, y = 0, z = 30 } end
eq(select(2, R.Track(config, { kind = 'sprint', start = raw.start, checkpoints = many })), 'too_many_checkpoints', 'demais')

-- Pista: circuito fecha na largada
local circuit = assert(R.Track(config, { kind = 'circuit', start = { x = 0, y = 0, z = 30, h = 90 }, checkpoints = {
	{ x = 200, y = 0, z = 30 }, { x = 200, y = 200, z = 30 }, { x = 0, y = 200, z = 30 } } }))
eq(#circuit.checkpoints, 4, 'circuito ganha a chegada na largada')
eq(circuit.checkpoints[4].x, 0, 'chegada na largada')
eq(circuit.length, 800, 'volta completa')
local closed = assert(R.Track(config, { kind = 'circuit', start = { x = 0, y = 0, z = 30, h = 90 }, checkpoints = {
	{ x = 200, y = 0, z = 30 }, { x = 200, y = 200, z = 30 }, { x = 0, y = 200, z = 30 }, { x = 5, y = 15, z = 30 } } }))
eq(#closed.checkpoints, 4, 'volta ja fechada pelo piloto')

-- Opções da corrida
local options = assert(R.RaceOptions(config, circuit, { laps = 3, buyIn = 20000, class = 'sports', maxRacers = 6, startIn = 5 }))
eq(options.laps, 3, 'voltas')
eq(options.class, 'sports', 'classe')
eq(assert(R.RaceOptions(config, track, { laps = 5, class = 'any' })).laps, 1, 'sprint tem uma volta')
eq(select(2, R.RaceOptions(config, circuit, { laps = 99, class = 'any' })), 'invalid_laps', 'voltas demais')
eq(select(2, R.RaceOptions(config, circuit, { buyIn = -1, class = 'any' })), 'invalid_buy_in', 'entrada negativa')
eq(select(2, R.RaceOptions(config, circuit, { buyIn = 1.5, class = 'any' })), 'invalid_buy_in', 'entrada fracionada')
eq(select(2, R.RaceOptions(config, circuit, { class = 'tanks' })), 'invalid_class', 'classe desconhecida')
eq(select(2, R.RaceOptions(config, circuit, { class = 'any', maxRacers = 1 })), 'invalid_max_racers', 'corredores')
eq(select(2, R.RaceOptions(config, circuit, { class = 'any', startIn = 0 })), 'invalid_start_time', 'largada imediata')

-- Classes
eq(R.ClassAllowed(config, 'any', 7), true, 'livre aceita super')
eq(R.ClassAllowed(config, 'any', 15), false, 'helicoptero nunca')
eq(R.ClassAllowed(config, 'sports', 6), true, 'esportivo')
eq(R.ClassAllowed(config, 'sports', 7), false, 'super fora dos esportivos')
eq(R.ClassAllowed(config, 'tuners', 4), true, 'muscle nos tuners')
eq(R.ClassAllowed(config, 'any', nil), false, 'sem classe')

-- Duração máxima
eq(R.MaxDuration(config, 800, 1), config.Races.MinMaxSeconds, 'minimo')
eq(R.MaxDuration(config, 10000, 2), 3000, '20 km')

-- Checkpoint
local cp = { x = 100, y = 0, z = 30, r = 12 }
eq(R.CheckpointOk(config, cp, { x = 105, y = 5, z = 31 }, nil, 1000), true, 'dentro')
eq(select(2, R.CheckpointOk(config, cp, { x = 130, y = 0, z = 30 }, nil, 1000)), 'too_far', 'longe')
eq(select(2, R.CheckpointOk(config, cp, { x = 100, y = 0, z = 80 }, nil, 1000)), 'too_far', 'altura')
eq(select(2, R.CheckpointOk(config, cp, { x = 100, y = 0, z = 30 }, { at = { x = 0, y = 0 }, time = 1000 }, 1500)), 'too_fast', 'teleporte')
eq(R.CheckpointOk(config, cp, { x = 100, y = 0, z = 30 }, { at = { x = 0, y = 0 }, time = 1000 }, 5000), true, '25 m/s')
eq(select(2, R.CheckpointOk(config, cp, nil, nil, 0)), 'no_position', 'sem posicao')

-- Posições
local list = R.Standings({
	{ id = 'a', progress = 5, distance = 30 },
	{ id = 'b', progress = 5, distance = 10 },
	{ id = 'c', progress = 9, finishedAt = 2000 },
	{ id = 'd', progress = 9, finishedAt = 1500 },
	{ id = 'e', progress = 8, dnf = true },
	{ id = 'f', progress = 2 }
})
local ids = {}
for _, e in ipairs(list) do ids[#ids + 1] = e.id end
eq(table.concat(ids), 'dcbafe', 'ordem')
eq(list[1].position, 1, 'posicao gravada')

-- Pote
local split = R.Payouts(config, 100000, 5, 5)
eq(split.fee, 5000, 'taxa 5%')
eq(split.prizes[1], 57000, '60% do liquido')
eq(split.prizes[2], 23750, '25%')
eq(split.prizes[3], 14250, '15%')
eq(split.prizes[1] + split.prizes[2] + split.prizes[3] + split.fee, 100000, 'pote fecha')
local few = R.Payouts(config, 100000, 5, 1)
eq(few.prizes[1], 95000, 'so o 1o terminou: leva tudo')
eq(few.prizes[2], nil, 'sem 2o')
eq(R.Payouts(config, 100000, 5, 0), nil, 'ninguem terminou')
eq(R.Payouts(config, 0, 5, 3), nil, 'sem aposta')
local odd = R.Payouts(config, 30001, 3, 3)
eq(odd.prizes[1] + odd.prizes[2] + odd.fee, 30001, 'arredondamento vai ao 1o')
eq(R.Payouts(config, 20000, 2, 2).prizes[2], nil, 'dois corredores: vencedor leva')
eq(#R.Payouts(config, 120000, 12, 12).prizes, 4, '8+ corredores: 4 premiados')

-- Rating
local d = R.Rating(config, { { id = 'a', rating = 1000, place = 1 }, { id = 'b', rating = 1000, place = 2 } })
eq(d.a, 12, 'vencedor ganha K/2')
eq(d.b, -12, 'perdedor perde K/2')
local upset = R.Rating(config, { { id = 'a', rating = 800, place = 1 }, { id = 'b', rating = 1400, place = 2 }, { id = 'c', rating = 1000, place = 3 } })
eq(upset.a > 15, true, 'zebra ganha muito')
eq(upset.b < 0, true, 'favorito perde')
eq(R.Rating(config, { { id = 'a', rating = 1000, place = 1 } }).a, 0, 'sozinho nao muda')

-- Polícia
eq(R.PoliceChance(config, 2, false), 0.35, 'base')
eq(math.abs(R.PoliceChance(config, 6, true) - 0.85) < 1e-9, true, 'mais gente e sirene')
eq(R.PoliceChance(config, 12, true), 0.9, 'teto')

eq(R.FormatTime(83456), '1:23.456', 'tempo')
eq(R.FormatTime(nil), '0:00.000', 'tempo vazio')

local refunded = false
local okSaga = R.ExecuteSaga({
	{ name = 'lock', action = function() return true end, compensate = function() refunded = true end },
	{ name = 'insert', action = function() return false end }
})
eq(okSaga, false, 'Saga falha no segundo passo')
eq(refunded, true, 'Saga compensa EscrowLock automaticamente')

local limiter = R.NewCallLimiter(300)
eq(limiter:allow(1, 1000), true, 'GCRA primeira chamada')
eq(limiter:allow(1, 1100), false, 'GCRA bloqueia dentro da janela')
eq(limiter:allow(1, 1400), true, 'GCRA libera após janela')

print('coe_races rules_test: ok')
