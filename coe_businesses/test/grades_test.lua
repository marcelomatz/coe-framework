dofile('../coe_businesses/config.lua')
dofile('../coe_businesses/shared/area.lua')
dofile('../coe_businesses/server/registry.lua')
dofile('../coe_businesses/server/grades.lua')

local function eq(a, b, m)
	if a ~= b then error(('%s: esperado %s, veio %s'):format(m, tostring(b), tostring(a)), 2) end
end

local config = BusinessesConfig
local limits = config.Limits

local function grades()
	return {
		{ id = 'chefe', label = 'Chefe', level = 9, salary = 900, permissions = { 'police.arrest', 'business.funds' } },
		{ id = 'recruta', label = 'Recruta', level = 0, salary = 300 }
	}
end

-- Normalize
local list = BusinessGrades.Normalize(grades(), limits)
eq(list[1].id, 'recruta', 'ordenado pelo nível')
eq(list[2].permissions[1], 'business.funds', 'permissões ordenadas')
eq(#BusinessGrades.Normalize(nil, limits), 0, 'sem cargos')
local function bad(mutate)
	local raw = grades()
	mutate(raw)
	return select(2, BusinessGrades.Normalize(raw, limits))
end
eq(bad(function(r) r[1].id = 'Chefe!' end), 'invalid_grades', 'id inválido')
eq(bad(function(r) r[2].id = 'chefe' end), 'invalid_grades', 'id repetido')
eq(bad(function(r) r[2].level = 9 end), 'invalid_grades', 'nível repetido')
eq(bad(function(r) r[1].salary = -1 end), 'invalid_grades', 'salário negativo')
eq(bad(function(r) r[1].salary = limits.MaxSalary + 1 end), 'invalid_grades', 'salário acima do limite')
eq(bad(function(r) r[1].salary = 10.5 end), 'invalid_grades', 'salário fracionado')
eq(bad(function(r) r[1].label = '<b>' end), 'invalid_grades', 'rótulo com marcação')
eq(bad(function(r) r[1].permissions = { 'sem_prefixo' } end), 'invalid_grades', 'permissão sem prefixo')
eq(bad(function(r) r[1].level = 100 end), 'invalid_grades', 'nível alto')
eq(bad(function(r) for i = 3, 12 do r[i] = { id = 'c' .. i, label = 'C', level = i } end end), 'invalid_grades', 'cargos demais')

-- Assign
local staff = { { characterId = '1' }, { characterId = '2', grade = 'chefe' } }
eq(BusinessGrades.Assign(list, staff), true, 'atribui')
eq(staff[1].grade, 'recruta', 'cargo de entrada por padrão')
eq(select(2, BusinessGrades.Assign(list, { { characterId = '3', grade = 'fantasma' } })), 'invalid_staff_grade', 'cargo inexistente')
local none = { { characterId = '4', grade = 'chefe' } }
BusinessGrades.Assign({}, none)
eq(none[1].grade, nil, 'sem cargos no negócio, sem cargo')

-- Registro integra cargos e equipe
local function business(mutate)
	local raw = {
		id = 'delegacia', category = 'police', label = 'Delegacia',
		area = { kind = 'circle', x = 0.0, y = 0.0, z = 30.0, radius = 30 },
		grades = grades(), staff = { { characterId = '1', name = 'Ana' }, { characterId = '2', name = 'Bia', grade = 'chefe' } }
	}
	if mutate then mutate(raw) end
	return BusinessRegistry.Normalize(config, raw)
end
local saved = business()
eq(saved.category, 'police', 'categoria de polícia')
eq(saved.staff[1].grade, 'recruta', 'registro atribui cargo de entrada')
eq(select(2, business(function(r) r.staff[1].grade = 'fantasma' end)), 'invalid_staff_grade', 'cargo fora do negócio')
eq(select(2, business(function(r) r.grades[1].salary = -5 end)), 'invalid_grades', 'salário inválido no registro')
eq(BusinessRegistry.Normalize(config, { id = 'hospital', category = 'ems', label = 'Hospital', area = { kind = 'circle', x = 0, y = 0, z = 0, radius = 20 } }).category, 'ems', 'categoria ems')

-- Of / Can: cada negócio tem seus cargos; nada vale em outro
eq(BusinessGrades.Of(saved, '2').id, 'chefe', 'cargo do funcionário')
eq(BusinessGrades.Of(saved, '9'), nil, 'quem não é da equipe não tem cargo')
eq(BusinessGrades.Can(saved, '2', 'police.arrest', false), true, 'permissão do cargo')
eq(BusinessGrades.Can(saved, '1', 'police.arrest', false), false, 'cargo sem a permissão')
eq(BusinessGrades.Can(saved, '9', 'police.arrest', false), false, 'sem cargo')
eq(BusinessGrades.Can(saved, '9', 'police.arrest', true), true, 'dono tem tudo')
local other = business(function(r) r.id = 'delegacia2'; r.staff = {}; r.grades = {} end)
eq(BusinessGrades.Can(other, '2', 'police.arrest', false), false, 'cargo de um negócio não vale em outro')

-- Diff e Differ
local changed = business(function(r) r.staff = { { characterId = '1', name = 'Ana', grade = 'chefe' }, { characterId = '3', name = 'Caio' } } end)
local diff = BusinessGrades.Diff(saved, changed)
eq(#diff, 3, 'três mudanças')
eq(diff[1].change .. diff[1].grade, 'gradechefe', 'cargo mudou')
eq(diff[2].change, 'removed', 'removido')
eq(diff[3].change .. diff[3].grade, 'addedrecruta', 'adicionado com cargo de entrada')
eq(#BusinessGrades.Diff(nil, saved), 2, 'negócio novo adiciona toda a equipe')
eq(BusinessGrades.Differ(saved.grades, saved.grades), false, 'mesmas definições')
eq(BusinessGrades.Differ(saved.grades, changed.grades), false, 'mesmas definições em outro registro')
eq(BusinessGrades.Differ(saved.grades, other.grades), true, 'definições diferentes')

print('grades ok')
