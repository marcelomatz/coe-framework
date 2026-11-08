dofile('../coe_ems/config.lua')
dofile('../coe_ems/server/rules.lua')

local function eq(a, b, m)
	if a ~= b then error(('%s: esperado %s, veio %s'):format(m, tostring(b), tostring(a)), 2) end
end

local c = EmsConfig

eq(EmsRules.CanReport('healthy', 'injured'), true, 'saudável fica ferido')
eq(EmsRules.CanReport('injured', 'healthy'), true, 'ferido se recupera')
eq(EmsRules.CanReport('injured', 'unconscious'), true, 'ferido desmaia')
eq(EmsRules.CanReport('unconscious', 'healthy'), false, 'inconsciente não se cura sozinho')
eq(EmsRules.CanReport('dead', 'healthy'), false, 'morto não se cura sozinho')
eq(EmsRules.CanReport('unconscious', 'dead'), false, 'cliente não decreta óbito')
eq(EmsRules.CanReport('healthy', 'dead'), false, 'cliente não pula para morto')
eq(EmsRules.CanReport(nil, 'injured'), false, 'estado desconhecido')

eq(EmsRules.CanApply('revive', 'unconscious', c), true, 'reanima inconsciente')
eq(EmsRules.CanApply('revive', 'healthy', c), false, 'não reanima saudável')
eq(EmsRules.CanApply('revive', 'dead', c), false, 'morto exige respawn por padrão')
eq(EmsRules.CanApply('revive', 'dead', { ReviveDead = true }), true, 'morto reanimável por configuração')
eq(EmsRules.CanApply('treat', 'injured', c), true, 'trata ferido')
eq(EmsRules.CanApply('treat', 'unconscious', c), false, 'tratar não reanima')
eq(select(2, EmsRules.CanApply('treat', 'healthy', c)), 'invalid_state', 'código do estado')
eq(EmsRules.CanApply('respawn', 'dead', c), true, 'respawn só morto')
eq(EmsRules.CanApply('respawn', 'unconscious', c), false, 'respawn não vale inconsciente')
eq(EmsRules.CanApply('inventada', 'dead', c), false, 'ação desconhecida')
eq(EmsRules.Outcome.revive, 'healthy', 'resultado')

eq(EmsRules.Detail(nil), '', 'detalhe vazio')
eq(EmsRules.Detail('overdose'), 'overdose', 'detalhe')
eq(select(2, EmsRules.Detail('Texto livre')), 'invalid_detail', 'detalhe livre recusado')
eq(select(2, EmsRules.Detail(("x"):rep(33))), 'invalid_detail', 'detalhe longo')

eq(EmsRules.InRange(3.9, c), true, 'dentro do alcance')
eq(EmsRules.InRange(4.1, c), false, 'fora do alcance')
eq(EmsRules.InRange(nil, c), false, 'sem posição')

eq(EmsRules.BledOut(0, 299, c), false, 'ainda sangrando')
eq(EmsRules.BledOut(0, 300, c), true, 'óbito')
eq(EmsRules.BledOut(0, 99999, { BleedoutSeconds = 0 }), false, 'sangramento desligado')

local seen = {}
for _, permission in ipairs(c.Permissions) do
	assert(permission.name:match('^ems%.[a-z]+$'), 'prefixo ems')
	assert(not seen[permission.name], 'permissão repetida')
	seen[permission.name] = true
end

-- Hierarchical Hashed Timing Wheel O(1) para Bleed-Out e GCRA Report Limiter
local wheel = EmsRules.NewBleedoutWheel(5000)
eq(type(wheel), 'table', 'NewBleedoutWheel disponível')
local died = false
wheel:schedule('bleedout:10', 10000, function() died = true end)
wheel:tick()
eq(died, false, 'ainda inconsciente após 5s')
wheel:cancel('bleedout:10')
wheel:tick()
eq(died, false, 'reanimação cancela timer de sangramento em O(1)')

local limiter = EmsRules.NewReportLimiter(1000, 0)
eq(type(limiter), 'table', 'NewReportLimiter disponível')
eq(limiter:allow(10, 1000), true, 'primeiro report aceito')
eq(limiter:allow(10, 1400), false, 'report duplicado em <1000ms bloqueado')

print('ems rules ok')
