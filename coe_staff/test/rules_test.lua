-- Regras do painel da staff (sem natives).
dofile('config.lua')
dofile('shared/rules.lua')

local function eq(a, b, m)
	if a ~= b then error(('%s: esperado %s, veio %s'):format(m, tostring(b), tostring(a)), 2) end
end
local config = StaffConfig

-- Módulos por ACE
local modules, any = StaffRules.Modules(config, function(ace) return ace == 'coe.staff.players' end)
eq(any, true, 'algum modulo')
eq(modules.players, true, 'jogadores')
eq(modules.self, nil, 'sem pessoal')
eq(StaffRules.Allowed(modules, 'giveItem'), true, 'dar item liberado')
eq(StaffRules.Allowed(modules, 'noclip'), false, 'noclip bloqueado')
eq(StaffRules.Allowed(modules, 'hack'), false, 'acao desconhecida')
modules = StaffRules.Modules(config, function(ace) return ace == 'coe.staff.all' end)
eq(modules.self and modules.players and modules.vehicles and modules.world and modules.businesses, true, 'all libera tudo')
local _, none = StaffRules.Modules(config, function() return false end)
eq(none, false, 'sem ACE')
for action, module in pairs(StaffRules.Actions) do
	eq(config.Ace.Modules[module] ~= nil, true, 'modulo da acao ' .. action)
end

-- Entradas
eq(StaffRules.Integer('5', 1, 10), 5, 'inteiro')
eq(StaffRules.Integer(2.5, 1, 10), nil, 'fracionado')
eq(StaffRules.Integer(11, 1, 10), nil, 'acima')
eq(StaffRules.Text('  oi\n mundo <b> ', 20), 'oi mundo b', 'texto limpo')
eq(StaffRules.Text(string.rep('a', 21), 20), nil, 'texto longo')
eq(StaffRules.Text('   ', 20), nil, 'texto vazio')
local c = StaffRules.Coords({ x = '10.5', y = -20, z = 30 })
eq(c.x, 10.5, 'coord x')
eq(StaffRules.Coords({ x = 99999, y = 0 }), nil, 'fora do mapa')
eq(StaffRules.Coords({ x = 1, y = 2 }).z, 0, 'z padrao')
eq(StaffRules.StateId(' k7m2-q9xa '), 'K7M2Q9XA', 'state id')
eq(StaffRules.StateId('K7M2Q9X0'), nil, 'state id com 0')
eq(StaffRules.Model('Adder'), 'adder', 'modelo')
eq(StaffRules.Model('a b'), nil, 'modelo com espaco')
eq(StaffRules.ItemName('water'), 'water', 'item')
eq(StaffRules.ItemName('../x'), nil, 'item invalido')
eq(StaffRules.Weather(config, 'RAIN'), 'RAIN', 'clima')
eq(StaffRules.Weather(config, 'LAVA'), nil, 'clima invalido')
local t = StaffRules.Time({ hour = 13, minute = 5, freeze = true })
eq(t.hour, 13, 'hora'); eq(t.freeze, true, 'congelado')
eq(StaffRules.Time({ hour = 24 }), nil, 'hora invalida')
eq(StaffRules.Time({ hour = 6 }).minute, 0, 'minuto padrao')

-- Itens
local items = { water = { label = 'Água', category = 'food' }, burger = { label = 'Hambúrguer' }, phone = { label = 'Celular' } }
local list = StaffRules.ItemList(items, 'ÁG', 10)
eq(list[1].name, 'water', 'busca pelo rotulo com acento')
list = StaffRules.ItemList(items, 'wat', 10)
eq(list[1].name, 'water', 'busca pelo nome')
list = StaffRules.ItemList(items, '', 2)
eq(#list, 2, 'limite')
eq(list[1].label, 'Celular', 'ordem por rotulo')

-- Negócios
local categories = {
	restaurant = { label = 'Restaurantes', stations = { 'stashes', 'crafts', 'clocks' }, rules = { 'clockRequired' } },
	mechanic = { label = 'Mecânicas', stations = { 'showroom', 'clocks' }, rules = {} }
}
local schema = { clockRequired = { type = 'boolean' }, priceMultiplier = { type = 'number', min = 0.5, max = 3 } }
local at = { x = 1, y = 2, z = 3 }
local b, err = StaffRules.NewBusiness(config, categories, { id = 'Burger_1', label = ' Burger ', category = 'restaurant', radius = 30 }, at)
eq(b.id, 'burger_1', 'id minusculo')
eq(b.label, 'Burger', 'nome')
eq(b.area.radius, 30, 'raio')
eq(b.area.x, 1, 'centro na posicao do admin')
b, err = StaffRules.NewBusiness(config, categories, { id = '1x', label = 'X', category = 'restaurant' }, at)
eq(err, 'invalid_id', 'id invalido')
b, err = StaffRules.NewBusiness(config, categories, { id = 'xx', label = 'X', category = 'bank' }, at)
eq(err, 'invalid_category', 'categoria invalida')
b, err = StaffRules.NewBusiness(config, categories, { id = 'xx', label = 'X', category = 'restaurant', radius = 1 }, at)
eq(err, 'invalid_area', 'raio pequeno')

local business = StaffRules.NewBusiness(config, categories, { id = 'burger', label = 'Burger', category = 'restaurant' }, at)
local ctx = { at = { x = 5, y = 6, z = 7 }, categories = categories, rules = schema }
local edited = StaffRules.Edit(config, business, 'businessInfo', { label = 'Burger Shot', enabled = false, rules = { clockRequired = false } }, ctx)
eq(edited.label, 'Burger Shot', 'renomeia')
eq(edited.enabled, false, 'desativa')
eq(edited.rules.clockRequired, false, 'regra')
eq(business.label, 'Burger', 'original intacto')
eq(select(2, StaffRules.Edit(config, business, 'businessInfo', { rules = { nope = true } }, ctx)), 'invalid_rule', 'regra desconhecida')
eq(select(2, StaffRules.Edit(config, business, 'businessInfo', { rules = { priceMultiplier = 9 } }, ctx)), 'invalid_rule', 'regra fora da faixa')

edited = StaffRules.Edit(config, business, 'businessArea', { radius = 50 }, ctx)
eq(edited.area.x, 5, 'area na nova posicao')
eq(edited.area.radius, 50, 'novo raio')

edited = StaffRules.Edit(config, business, 'stationAdd', { kind = 'clocks', label = 'Relógio' }, ctx)
edited = StaffRules.Edit(config, edited, 'stationAdd', { kind = 'clocks' }, ctx)
eq(edited.stations.clocks[1].id, 'clock_1', 'id do primeiro relogio')
eq(edited.stations.clocks[1].label, 'Relógio', 'rotulo')
eq(edited.stations.clocks[2].id, 'clock_2', 'id do segundo')
eq(edited.stations.clocks[2].label, 'clock_2', 'rotulo padrao')
edited = StaffRules.Edit(config, edited, 'stationAdd', { kind = 'stashes' }, ctx)
eq(edited.stations.stashes[1].slots, 40, 'bau com slots padrao')
eq(select(2, StaffRules.Edit(config, edited, 'stationAdd', { kind = 'showroom' }, ctx)), 'invalid_station', 'showroom fora da categoria')
edited = StaffRules.Edit(config, edited, 'stationRemove', { kind = 'clocks', stationId = 'clock_1' }, ctx)
eq(#edited.stations.clocks, 1, 'remove relogio')
eq(StaffRules.Edit(config, edited, 'stationAdd', { kind = 'clocks' }, ctx).stations.clocks[2].id, 'clock_1', 'reaproveita id livre')
eq(select(2, StaffRules.Edit(config, edited, 'stationRemove', { kind = 'clocks', stationId = 'x' }, ctx)), 'unknown_station', 'ponto inexistente')

local mech = StaffRules.NewBusiness(config, categories, { id = 'auto', label = 'Auto', category = 'mechanic' }, at)
local withShowroom = StaffRules.Edit(config, mech, 'stationAdd', { kind = 'showroom', radius = 8 }, ctx)
eq(withShowroom.stations.showroom.radius, 8, 'showroom')
eq(StaffRules.Edit(config, withShowroom, 'stationRemove', { kind = 'showroom' }, ctx).stations.showroom, nil, 'remove showroom')

-- Cargos e equipe
edited = StaffRules.Edit(config, business, 'gradeAdd', { label = 'Gerente Geral', level = 5, salary = 500, permissions = { 'business.staff' } }, ctx)
edited = StaffRules.Edit(config, edited, 'gradeAdd', { label = 'Atendente', level = 0, salary = 200 }, ctx)
eq(edited.grades[1].id, 'atendente', 'ordenado por nivel')
eq(edited.grades[2].id, 'gerente_geral', 'id do cargo')
eq(select(2, StaffRules.Edit(config, edited, 'gradeAdd', { label = 'Outro', level = 5 }, ctx)), 'duplicate_grade', 'nivel repetido')
ctx.character = { characterId = '11', name = 'Ana' }
edited = StaffRules.Edit(config, edited, 'staffAdd', { grade = 'atendente' }, ctx)
eq(edited.staff[1].characterId, '11', 'contrata')
eq(select(2, StaffRules.Edit(config, edited, 'staffAdd', {}, ctx)), 'already_staff', 'ja na equipe')
eq(select(2, StaffRules.Edit(config, edited, 'gradeRemove', { gradeId = 'atendente' }, ctx)), 'grade_in_use', 'cargo em uso')
edited = StaffRules.Edit(config, edited, 'staffGrade', { characterId = '11', grade = 'gerente_geral' }, ctx)
eq(edited.staff[1].grade, 'gerente_geral', 'promove')
edited = StaffRules.Edit(config, edited, 'gradeRemove', { gradeId = 'atendente' }, ctx)
eq(#edited.grades, 1, 'remove cargo vazio')
edited.partners = { { characterId = '77', name = 'Sócio' } }
edited = StaffRules.Edit(config, edited, 'businessOwner', {}, ctx)
eq(edited.owner.characterId, '11', 'dono')
eq(#edited.partners, 0, 'troca de dono desfaz a sociedade')
eq(#edited.staff, 0, 'dono sai da equipe')
ctx.character = { characterId = '11', name = 'Ana' }
eq(select(2, StaffRules.Edit(config, edited, 'staffAdd', {}, ctx)), 'is_owner', 'dono nao entra na equipe')
ctx.character = nil
eq(StaffRules.Edit(config, edited, 'businessOwner', {}, ctx).owner, nil, 'remove dono')
eq(select(2, StaffRules.Edit(config, edited, 'staffRemove', { characterId = '99' }, ctx)), 'unknown_member', 'funcionario inexistente')
eq(select(2, StaffRules.Edit(config, edited, 'hack', {}, ctx)), 'invalid_action', 'operacao desconhecida')

eq(StaffRules.Slug('Chefe de Cozinha'), 'chefe_de_cozinha', 'slug')
eq(StaffRules.Slug('1º Turno'), 'g_1_turno', 'slug comeca com letra')
local summary = StaffRules.BusinessSummary({ id = 'a', label = 'A', category = 'shop', owner = { name = 'Ana' }, staff = { {}, {} } })
eq(summary.owner, 'Ana', 'resumo dono'); eq(summary.staff, 2, 'resumo equipe'); eq(summary.enabled, true, 'resumo ativo')

print('coe_staff rules: ok')
