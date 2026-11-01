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
print('ems rules ok')
