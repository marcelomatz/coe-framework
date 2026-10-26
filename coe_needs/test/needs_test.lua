dofile('config.lua')
dofile('domain/needs.lua')

local function eq(a, b, msg)
	if a ~= b then error(('%s: esperado %s, obtido %s'):format(msg, tostring(b), tostring(a))) end
end

local state = Needs.New(nil)
eq(state.hunger, 90, 'valor inicial de fome')
eq(state.alcohol, 0, 'valor inicial de alcool')
eq(state.drugs, 0, 'valor inicial de drogas')
eq(Needs.New({ hunger = 500, thirst = -5, stress = 'x', alcohol = 120, drugs = -10 }).hunger, 100, 'limita acima')
eq(Needs.New({ hunger = 500, thirst = -5, stress = 'x' }).thirst, 0, 'limita abaixo')
eq(Needs.New({ alcohol = 120 }).alcohol, 100, 'limita alcool acima')
eq(Needs.New({ drugs = -10 }).drugs, 0, 'limita drogas abaixo')
eq(Needs.New({ stress = 'x' }).stress, 10, 'invalido usa padrao')

Needs.Step(state, 'sprint', 60)
eq(state.hunger, 90 - 1.2, 'sprint consome fome por minuto')
eq(state.stress, 10.2, 'sprint aumenta estresse')
Needs.Step(state, 'idle', 60)
eq(math.abs(state.stress - 9.6) < 1e-9, true, 'idle reduz estresse')

-- Metabolismo de alcool e drogas por atividade
Needs.Set(state, 'alcohol', 40)
Needs.Set(state, 'drugs', 30)
Needs.Step(state, 'walk', 60)
eq(math.abs(state.alcohol - 38.2) < 1e-9, true, 'walk metaboliza alcool')
eq(math.abs(state.drugs - 28.5) < 1e-9, true, 'walk metaboliza drogas')

local copy = Needs.Copy(state)
eq(Needs.SnapshotEquals(Needs.Snapshot(copy), Needs.Snapshot(state)), true, 'copy preserva valores')

local before = state.hunger
Needs.Step(state, 'inexistente', 60)
Needs.Step(state, 'walk', -5)
eq(state.hunger, before, 'atividade ou tempo invalido nao altera')

eq(Needs.Add(state, 'hunger', 1000), true, 'add valido')
eq(state.hunger, 100, 'add limita')
local ok, err = Needs.Add(state, 'sede', 1)
eq(ok, false, 'need invalido')
eq(err, 'invalid_need', 'codigo de erro')
eq(Needs.Add(state, 'hunger', 0 / 0), false, 'delta NaN rejeitado')
eq(Needs.Set(state, 'stress', 40), true, 'set')
eq(Needs.Snapshot(state).stress, 40, 'snapshot inteiro')
eq(Needs.IsActivity('combat'), true, 'atividade valida')
eq(Needs.IsActivity('fly'), false, 'atividade invalida')
eq(Needs.SnapshotEquals(Needs.Snapshot(state), Needs.Snapshot(state)), true, 'snapshots iguais')

print('coe_needs domain tests passed')
