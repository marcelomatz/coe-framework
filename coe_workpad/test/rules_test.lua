-- Regras do tablet de trabalho (sem natives).
dofile('config.lua')
dofile('shared/rules.lua')

local function eq(a, b, m)
	if a ~= b then error(('%s: esperado %s, veio %s'):format(m, tostring(b), tostring(a)), 2) end
end
local config = WorkpadConfig

-- Scripts
eq(WorkpadRules.IsValidScript('nui://coe_jobs/html/career.js'), true, 'script valido')
eq(WorkpadRules.IsValidScript('https://x.com/a.js'), false, 'url externa')
eq(WorkpadRules.IsValidScript('nui://coe_jobs/html/../x.js'), false, 'caminho com ..')

-- Lista de apps
local up = { coe_jobs = true, coe_businesses = true }
local profile = WorkpadRules.Resolve(config, {
	started = function(r) return up[r] == true end,
	instances = function() return { { id = 'bennys', label = "Benny's", category = 'mechanic' }, { id = 'bad id!', label = 'x' } } end
})
local ids = {}
for _, app in ipairs(profile.apps) do ids[#ids + 1] = app.id end
eq(table.concat(ids, ','), 'duty,freejobs,career,business:bennys', 'apps em ordem, instancia invalida fora')
eq(profile.apps[4].kind, 'Mecânica', 'categoria do negocio')
eq(profile.apps[4].instance, 'bennys', 'instancia')
eq(profile.apps[4].base, 'business', 'base')
eq(#profile.groups, 2, 'secoes')

up.coe_jobs = false
profile = WorkpadRules.Resolve(config, { started = function(r) return up[r] == true end, instances = function() return {} end })
ids = {}
for _, app in ipairs(profile.apps) do ids[#ids + 1] = app.id end
eq(table.concat(ids, ','), 'duty', 'sem coe_jobs: so o Ponto')
eq(WorkpadRules.Find(profile, 'duty').base, 'duty', 'acha app')
eq(WorkpadRules.Find(profile, 'career'), nil, 'app fora do perfil')

local saved = config.Apps
config.Apps = { career = saved.career }
local none, reason = WorkpadRules.Resolve(config, { started = function() return false end, instances = function() return {} end })
eq(none, nil, 'sem apps')
eq(reason, 'no_apps', 'motivo')
config.Apps = saved

-- Pedido
local encode = function(t) return string.rep('x', t.size or 1) end
eq(WorkpadRules.Request('duty', 'overview', {}, 100, encode), true, 'pedido valido')
eq(select(2, WorkpadRules.Request(nil, 'x', {}, 100, encode)), 'invalid_request', 'sem app')
eq(select(2, WorkpadRules.Request('duty', string.rep('a', 33), {}, 100, encode)), 'invalid_request', 'acao longa')
eq(select(2, WorkpadRules.Request('duty', 'x', 'texto', 100, encode)), 'invalid_payload', 'payload nao tabela')
eq(select(2, WorkpadRules.Request('duty', 'x', { size = 101 }, 100, encode)), 'invalid_payload', 'payload grande')

-- Pagamento
eq(WorkpadRules.Money(1234567), '$ 1.234.567', 'dinheiro')
local lines = WorkpadRules.PayLines({ route = { pay = 45, bonus = 120, perRoute = 6 } })
eq(lines[1], '$ 45 por parada', 'por parada')
eq(lines[2], '$ 120 de bônus a cada 6 paradas', 'bonus')
lines = WorkpadRules.PayLines({ route = { mode = 'collect', pay = 10, payPerKm = 70 } })
eq(lines[1], '$ 10 por coleta', 'coleta')
eq(lines[2], '$ 70 por km rodado', 'por km')
lines = WorkpadRules.PayLines({ gather = { unit = 'minério', sell = { price = 20 } } })
eq(lines[1], '$ 20 por minério vendido', 'coleta e venda')

-- Empregos livres
local catalog = {
	{ id = 'miner', label = 'Mineiro', gather = { unit = 'minério', sell = { price = 20 } }, center = { 10, 20, 30 }, levels = { 0, 100 } },
	{ id = 'taxi', label = 'Taxista', route = { pay = 30, payPerKm = 70 }, vehicle = { deposit = 250 }, center = { 1, 2, 3 } },
	{ id = 'delivery', label = 'Entregador', route = { pay = 45 } }
}
local career = { jobs = {
	{ id = 'miner', allowed = false, lockedReason = 'Força nível 2', level = 1, maxLevel = 5, kindLabel = 'Coleta e venda' },
	{ id = 'taxi', allowed = true, level = 3, maxLevel = 5, earned = 900, kindLabel = 'Rota de passageiros' }
} }
local jobs = WorkpadRules.FreeJobs(catalog, career, 'taxi')
eq(jobs[1].id, 'taxi', 'trabalhando primeiro')
eq(jobs[1].working, true, 'marca o atual')
eq(jobs[1].deposit, 250, 'deposito do veiculo')
eq(jobs[1].level, 3, 'nivel')
eq(jobs[1].x, 1, 'gps')
eq(jobs[2].id, 'delivery', 'liberados antes dos bloqueados')
eq(jobs[2].allowed, true, 'sem carreira conta como liberado')
eq(jobs[2].x, nil, 'sem centro, sem gps')
eq(jobs[3].allowed, false, 'bloqueado')
eq(jobs[3].lockedReason, 'Força nível 2', 'motivo')
eq(#WorkpadRules.FreeJobs(nil, nil, nil), 0, 'catalogo vazio')

-- Ponto
eq(select(1, WorkpadRules.AreaCenter({ kind = 'circle', x = 5, y = 6 })), 5, 'centro do circulo')
local cx, cy = WorkpadRules.AreaCenter({ kind = 'polygon', points = { { x = 0, y = 0 }, { x = 10, y = 0 }, { x = 10, y = 10 }, { x = 0, y = 10 } } })
eq(cx, 5, 'centro do poligono x'); eq(cy, 5, 'centro do poligono y')
local view = WorkpadRules.Workplaces(config, {
	{ business = { id = 'b1', label = 'Burger', category = 'restaurant', area = { kind = 'circle', x = 1, y = 2 }, rules = { clockRequired = false } },
		access = { staff = true }, grade = { label = 'Chapeiro', salary = 300 } },
	{ business = { id = 'b2', label = 'Auto', category = 'mechanic', stations = { clocks = { { x = 7, y = 8 } } } }, access = { owner = true } },
	{ business = { id = 'b3', label = 'Outro' }, access = {} }
}, 'b2', 1000, 1600)
eq(#view.workplaces, 2, 'so onde e dono ou equipe')
eq(view.workplaces[1].id, 'b2', 'de ponto primeiro')
eq(view.workplaces[1].role, 'Dono', 'dono')
eq(view.workplaces[1].x, 7, 'gps no relogio')
eq(view.workplaces[1].salary, nil, 'dono sem salario')
eq(view.workplaces[2].role, 'Chapeiro', 'cargo')
eq(view.workplaces[2].salary, 300, 'salario do cargo')
eq(view.workplaces[2].clockRequired, false, 'ponto opcional')
eq(view.workplaces[2].x, 1, 'gps no centro da area')
eq(view.duty.label, 'Auto', 'ponto atual')
eq(view.duty.seconds, 600, 'tempo de ponto')
eq(WorkpadRules.Workplaces(config, {}, 'b9', nil, 1600).duty.seconds, nil, 'inicio desconhecido')
eq(WorkpadRules.Workplaces(config, {}, nil).duty, nil, 'sem ponto')

print('coe_workpad rules: ok')
