-- Carreira: XP total, habilidades compartilhadas entre empregos, reputação e os bônus que isso dá em cada emprego.
dofile('config.lua')
dofile('shared/rules.lua')
dofile('shared/career.lua')

local function eq(a, b, m)
	if a ~= b then error(('%s: esperado %s, veio %s'):format(m, tostring(b), tostring(a)), 2) end
end
local function near(a, b, m)
	if math.abs(a - b) > 1e-9 then error(('%s: esperado %s, veio %s'):format(m, tostring(b), tostring(a)), 2) end
end

local career = JobsConfig.Career
local known = {}
for id in pairs(career.skills) do known[id] = true end

local function job(def)
	local clean, err = JobRules.Validate(def, known)
	assert(clean, err)
	return clean
end

local lumber = job({ id = 'lumberjack', label = 'Lenhador', kind = 'gather', center = { 0, 0, 0 }, levels = { 0, 150, 450 }, skills = { 'strength', 'outdoor' },
	gather = { nodes = { { 1, 1, 1 } }, seconds = 10, capacity = 20, sell = { points = { { 2, 2, 2 } }, price = 10 } } })
-- Um emprego futuro que também usa Força: o histórico do lenhador já vale aqui.
local miner = job({ id = 'miner', label = 'Mineiro', kind = 'gather', center = { 0, 0, 0 }, skills = { 'strength' },
	requires = { career = 2, skills = { strength = 2 } },
	gather = { nodes = { { 1, 1, 1 } }, seconds = 10, capacity = 20, sell = { points = { { 2, 2, 2 } }, price = 10 } } })
local delivery = job({ id = 'delivery', label = 'Entregador', kind = 'route', center = { 0, 0, 0 }, skills = { 'driving', 'logistics' },
	vehicle = { model = 'boxville2', spawn = { 1, 1, 1 }, deposit = 300 },
	route = { stops = { { 1, 0, 0 }, { 2, 0, 0 } }, perRoute = 2, pay = 45 } })
local jobs = { lumberjack = lumber, miner = miner, delivery = delivery }

local _, err = JobRules.Validate({ id = 'xx', label = 'X', kind = 'gather', center = { 0, 0, 0 }, skills = { 'magic' },
	gather = { nodes = { { 1, 1, 1 } }, sell = { points = { { 2, 2, 2 } }, price = 1 } } }, known)
eq(err, 'invalid_skill:magic', 'habilidade desconhecida')

-- perfil novo
local profile = JobCareer.Profile(career, jobs, {}, nil)
eq(profile.level, 1, 'carreira nivel 1')
eq(profile.skills.strength.level, 1, 'forca nivel 1')
eq(profile.tier.label, 'Regular', 'reputacao regular')
local allowed, reason = JobCareer.Allowed(career, miner, profile)
eq(allowed, false, 'mineiro bloqueado sem historico')
eq(reason, 'carreira nível 2', 'motivo do bloqueio')

-- historico do lenhador: carreira e Forca/Campo sobem e valem no mineiro
profile = JobCareer.Profile(career, jobs, { lumberjack = { xp = 800, tasks = 200, earned = 5000 } }, 0)
eq(profile.xp, 800, 'xp total')
eq(profile.level, 2, 'carreira nivel 2')
eq(profile.skills.strength.xp, 800, 'forca soma o xp do lenhador')
eq(profile.skills.strength.level, 3, 'forca nivel 3')
eq(profile.skills.driving.level, 1, 'direcao nao treinada')
eq(JobCareer.Allowed(career, miner, profile), true, 'mineiro liberado pelo historico do lenhador')

local mods = JobCareer.Modifiers(career, miner, profile, 0)
eq(mods.jobLevel, 1, 'mineiro ainda nivel 1')
near(mods.payBonus, 0.01, 'mineiro ganha so o bonus de carreira (+1%)')
near(mods.xpMultiplier, 1.03, 'XP +3% pela carreira')
eq(mods.capacity, 24, 'forca nivel 3: +20% de carga no mineiro')
eq(mods.seconds, 10, 'mineiro nao usa Campo')

mods = JobCareer.Modifiers(career, lumber, profile, 800)
eq(mods.jobLevel, 3, 'lenhador nivel 3')
near(mods.payBonus, 0.11, 'lenhador: +10% do nivel e +1% da carreira')
eq(mods.seconds, 9, 'campo nivel 3: -10% no tempo')
eq(mods.capacity, 24, 'forca na carga do lenhador')

-- entregador: direcao corta o deposito, logistica soma pagamento, reputacao muda deposito
profile = JobCareer.Profile(career, jobs, { delivery = { xp = 1800 } }, 0)
eq(profile.skills.driving.level, 4, 'direcao nivel 4')
mods = JobCareer.Modifiers(career, delivery, profile, 1800)
eq(mods.deposit, 165, 'deposito -45% pela direcao')
near(mods.payBonus, 0.02 + 0.09, 'carreira nivel 3 (+2%) + logistica nivel 4 (+9%)')
profile = JobCareer.Profile(career, jobs, { delivery = { xp = 1800 } }, 60)
eq(JobCareer.Modifiers(career, delivery, profile, 1800).deposit, 0, 'reputacao exemplar dispensa o deposito')
profile = JobCareer.Profile(career, jobs, {}, -40)
eq(profile.tier.label, 'Duvidosa', 'reputacao duvidosa')
eq(JobCareer.Modifiers(career, delivery, profile, 0).deposit, 600, 'deposito dobrado')

-- teto do bonus
local rich = JobCareer.Profile(career, jobs, { delivery = { xp = 99999 } }, 100)
near(JobCareer.Modifiers(career, delivery, rich, 99999).payBonus, 0.07 + 0.12 + 0.05, 'carreira 8 + logistica 5 + exemplar')
local capped = setmetatable({ maxPayBonus = 0.1 }, { __index = career })
near(JobCareer.Modifiers(capped, delivery, rich, 99999).payBonus, 0.1, 'bonus limitado ao teto')

-- reputacao
eq(JobCareer.Reputation(career, 0, 'complete'), 1, 'concluir soma')
eq(JobCareer.Reputation(career, 5, 'abandon'), -5, 'abandonar tira')
eq(JobCareer.Reputation(career, 100, 'complete'), 100, 'teto')
eq(JobCareer.Reputation(career, -95, 'abandon'), -100, 'piso')
eq(JobCareer.Apply(100, 0.11), 111, 'aplica o bonus')

print('coe_jobs career tests passed')
