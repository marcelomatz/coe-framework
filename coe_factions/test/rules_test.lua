dofile('../coe_factions/config.lua')
dofile('../coe_factions/server/rules.lua')

local function eq(a, b, m)
	if a ~= b then error(('%s: esperado %s, veio %s'):format(m, tostring(b), tostring(a)), 2) end
end

local config = FactionsConfig
local function base(extra)
	local f = {
		id = 'vagos', label = 'Vagos', category = 'gang',
		grades = { { grade = 2, label = 'Líder' }, { grade = 0, label = 'Novato' }, { grade = 1, label = 'Soldado' } },
		crafts = { { recipe = 'weapon_pistol' }, { recipe = 'drug_pack', minGrade = 1 } }
	}
	for k, v in pairs(extra or {}) do f[k] = v end
	return f
end

local f = FactionsRules.Normalize(base(), config)
eq(f.id, 'vagos', 'válida')
eq(f.enabled, true, 'ativa por padrão')
eq(f.grades[1].grade, 0, 'graus ordenados')
eq(f.grades[3].label, 'Líder', 'último grau')
eq(f.crafts[1].minGrade, 0, 'grau mínimo padrão é o menor grau')
eq(f.crafts[2].minGrade, 1, 'grau mínimo explícito')

local _, e = FactionsRules.Normalize(base({ id = 'A B' }), config)
eq(e, 'invalid_id', 'id inválido')
_, e = FactionsRules.Normalize(base({ category = 'seita' }), config)
eq(e, 'invalid_category', 'categoria inválida')
_, e = FactionsRules.Normalize(base({ label = '<b>' }), config)
eq(e, 'invalid_label', 'rótulo inválido')
_, e = FactionsRules.Normalize(base({ grades = {} }), config)
eq(e, 'invalid_grades', 'sem graus')
_, e = FactionsRules.Normalize(base({ grades = { { grade = 0, label = 'A' }, { grade = 0, label = 'B' } } }), config)
eq(e, 'invalid_grades', 'grau duplicado')
_, e = FactionsRules.Normalize(base({ grades = { { grade = 10, label = 'A' } } }), config)
eq(e, 'invalid_grades', 'grau acima do limite')
_, e = FactionsRules.Normalize(base({ crafts = { { recipe = 'x' }, { recipe = 'x' } } }), config)
eq(e, 'invalid_crafts', 'receita duplicada')
_, e = FactionsRules.Normalize(base({ crafts = { { recipe = 'x', minGrade = 7 } } }), config)
eq(e, 'invalid_crafts', 'grau mínimo inexistente')
_, e = FactionsRules.Normalize(base({ crafts = { { recipe = 'Bad Id' } } }), config)
eq(e, 'invalid_crafts', 'receita inválida')
f = FactionsRules.Normalize(base({ crafts = false }), config)
eq(f, nil, 'crafts inválido não passa')
f = FactionsRules.Normalize(base({ crafts = {}, enabled = false }), config)
eq(f.enabled, false, 'inativa')
eq(#f.crafts, 0, 'sem crafts')

f = FactionsRules.Normalize(base(), config)
eq(#FactionsRules.RecipesFor(f, 0), 1, 'novato só a receita livre')
eq(#FactionsRules.RecipesFor(f, 1), 2, 'soldado tem as duas')
eq(FactionsRules.CanCraft(f, 0, 'drug_pack'), false, 'grau insuficiente')
eq(FactionsRules.CanCraft(f, 2, 'drug_pack'), true, 'grau suficiente')
eq(FactionsRules.CanCraft(f, 2, 'outra'), false, 'receita não liberada')
f.enabled = false
eq(#FactionsRules.RecipesFor(f, 2), 0, 'facção inativa não libera')
eq(FactionsRules.HasGrade(f, 1), true, 'HasGrade')
eq(FactionsRules.HasGrade(f, 5), false, 'HasGrade inexistente')

-- Estações (bancadas e baús da facção)
local withStations = FactionsRules.Normalize(base({
	stations = {
		crafts = { { id = 'mesa1', label = 'Mesa de armas', x = 10.5, y = -20.25, z = 30.0, radius = 2.0 } },
		stashes = { { id = 'bau1', label = 'Baú da facção', x = 12.0, y = -20.0, z = 30.0, radius = 1.5, slots = 60, maxWeight = 250000 } }
	}
}), config)
eq(#withStations.stations.crafts, 1, '1 bancada de faccao')
eq(withStations.stations.crafts[1].id, 'mesa1', 'id da bancada')
eq(#withStations.stations.stashes, 1, '1 bau de faccao')
eq(withStations.stations.stashes[1].slots, 60, 'slots do bau')
eq(withStations.stations.stashes[1].maxWeight, 250000, 'peso do bau')

_, e = FactionsRules.Normalize(base({ stations = { crafts = { { id = 'Bad Id', x = 0, y = 0, z = 0 } } } }), config)
eq(e, 'invalid_station', 'id de estacao invalido')
_, e = FactionsRules.Normalize(base({ stations = { crafts = { { id = 'm1', x = 0, y = 0, z = 0 }, { id = 'm1', x = 1, y = 1, z = 1 } } } }), config)
eq(e, 'duplicate_station', 'estacao duplicada')
_, e = FactionsRules.Normalize(base({ stations = { stashes = { { id = 'b1', x = 0, y = 0, z = 0, slots = 999 } } } }), config)
eq(e, 'invalid_station', 'slots acima do limite')

print('factions rules ok')
