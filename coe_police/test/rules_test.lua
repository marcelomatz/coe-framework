dofile('../coe_police/config.lua')
dofile('../coe_police/server/rules.lua')

local function eq(a, b, m)
	if a ~= b then error(('%s: esperado %s, veio %s'):format(m, tostring(b), tostring(a)), 2) end
end

local c = PoliceConfig

eq(PoliceRules.Fine(500, c), 500, 'multa')
eq(select(2, PoliceRules.Fine(0, c)), 'invalid_amount', 'multa zero')
eq(select(2, PoliceRules.Fine(-1, c)), 'invalid_amount', 'multa negativa')
eq(select(2, PoliceRules.Fine(1.5, c)), 'invalid_amount', 'multa fracionada')
eq(select(2, PoliceRules.Fine(c.MaxFine + 1, c)), 'invalid_amount', 'multa acima do limite')
eq(select(2, PoliceRules.Fine('10', c)), 'invalid_amount', 'multa texto')
eq(select(2, PoliceRules.Fine(0 / 0, c)), 'invalid_amount', 'multa nan')

eq(PoliceRules.Minutes(30, c), 30, 'pena')
eq(select(2, PoliceRules.Minutes(c.MaxSentenceMinutes + 1, c)), 'invalid_sentence', 'pena longa')
eq(select(2, PoliceRules.Minutes(0, c)), 'invalid_sentence', 'pena zero')

eq(PoliceRules.Charge('speeding'), 'speeding', 'motivo')
eq(select(2, PoliceRules.Charge('Excesso de velocidade')), 'invalid_charge', 'motivo livre')
eq(select(2, PoliceRules.Charge('x')), 'invalid_charge', 'motivo curto')
eq(select(2, PoliceRules.Charge(nil)), 'invalid_charge', 'motivo nil')

eq(PoliceRules.CanApply('cuff', false, false), true, 'algema livre')
eq(select(2, PoliceRules.CanApply('cuff', true, false)), 'already_cuffed', 'já algemado')
eq(PoliceRules.CanApply('uncuff', true, false), true, 'solta algemado')
eq(select(2, PoliceRules.CanApply('uncuff', false, false)), 'not_cuffed', 'não está algemado')
eq(PoliceRules.CanApply('jail', true, false), true, 'prende algemado')
eq(select(2, PoliceRules.CanApply('jail', false, false)), 'not_cuffed', 'prisão exige algema')
eq(select(2, PoliceRules.CanApply('jail', true, true)), 'already_jailed', 'já preso')
eq(select(2, PoliceRules.CanApply('fine', false, true)), 'already_jailed', 'preso não é multado')
eq(PoliceRules.CanApply('fine', false, false), true, 'multa livre')
eq(PoliceRules.CanApply('inventada', true, false), false, 'ação desconhecida')

eq(PoliceRules.InRange(3.9, c), true, 'dentro do alcance')
eq(PoliceRules.InRange(4.1, c), false, 'fora do alcance')
eq(PoliceRules.InRange(nil, c), false, 'sem posição')

eq(PoliceRules.ReleaseAt(1000, 2), 1120, 'soltura')
eq(PoliceRules.Remaining(1120, 1000), 120, 'resta')
eq(PoliceRules.Remaining(1120, 2000), 0, 'pena cumprida')

eq(PoliceRules.CanApply('search', true, false), true, 'revista algemado')
eq(select(2, PoliceRules.CanApply('search', false, false)), 'not_cuffed', 'revista exige algema')
eq(select(2, PoliceRules.CanApply('seize', false, false)), 'not_cuffed', 'apreensão exige algema')
eq(PoliceRules.CanApply('escort', true, false), true, 'escolta algemado')
eq(select(2, PoliceRules.CanApply('escort', true, true)), 'already_jailed', 'preso não é escoltado')

eq(PoliceRules.Seizure(3, 2), 3, 'apreensão slot')
eq(select(2, PoliceRules.Seizure(3, 2)), 2, 'apreensão qtd')
eq(select(2, PoliceRules.Seizure(0, 2)), 'invalid_slot', 'slot zero')
eq(select(2, PoliceRules.Seizure(201, 1)), 'invalid_slot', 'slot alto')
eq(select(2, PoliceRules.Seizure(1, 0)), 'invalid_count', 'qtd zero')
eq(select(2, PoliceRules.Seizure(1, 1.5)), 'invalid_count', 'qtd fracionada')

local list = PoliceRules.SearchList({ slots = 5, items = { { name = 'pao', label = 'Pão', count = 2 }, false, { name = 'x', count = 1 }, 'lixo' } }, 2)
eq(#list, 2, 'lista limitada')
eq(list[1].slot, 1, 'slot 1')
eq(list[2].label, 'x', 'rótulo cai no nome')
eq(#PoliceRules.SearchList(nil, 5), 0, 'sem inventário')

local seen = {}
for _, permission in ipairs(c.Permissions) do
	assert(permission.name:match('^police%.[a-z]+$'), 'prefixo police')
	assert(not seen[permission.name], 'permissão repetida')
	seen[permission.name] = true
end
print('police rules ok')
