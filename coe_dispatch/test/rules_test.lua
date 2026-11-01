dofile('../coe_dispatch/config.lua')
dofile('../coe_dispatch/server/rules.lua')

local function eq(a, b, m)
	if a ~= b then error(('%s: esperado %s, veio %s'):format(m, tostring(b), tostring(a)), 2) end
end

local c = DispatchConfig

-- Códigos
eq(DispatchRules.Code(c, 'robbery').priority, 1, 'código válido')
eq(select(2, DispatchRules.Code(c, 'nao_existe')), 'invalid_code', 'código inexistente')
eq(select(2, DispatchRules.Code(c, nil)), 'invalid_code', 'código nil')
eq(DispatchRules.Code(c, 'help_ems', true).category, 'ems', 'cidadão pode pedir socorro')
eq(select(2, DispatchRules.Code(c, 'bank_robbery', true)), 'invalid_code', 'cidadão não abre assalto a banco')

for code, definition in pairs(c.Codes) do
	assert(c.Categories[definition.category], 'categoria de ' .. code)
	assert(definition.priority >= 1 and definition.priority <= 3, 'prioridade de ' .. code)
	assert(type(definition.label) == 'string' and definition.label ~= '', 'rótulo de ' .. code)
end

-- Coordenadas
eq(DispatchRules.Coords(1, 2, 3).y, 2.0, 'coords')
eq(select(2, DispatchRules.Coords(1, 'a', 3)), 'invalid_coords', 'coords texto')
eq(select(2, DispatchRules.Coords(0 / 0, 1, 1)), 'invalid_coords', 'coords nan')
eq(select(2, DispatchRules.Coords(1, 1, math.huge)), 'invalid_coords', 'coords infinito')

-- Duplicados
local calls = { [1] = { id = 1, code = 'shots_fired', category = 'police', priority = 2, x = 0.0, y = 0.0, z = 0.0, createdAt = 100 } }
eq(DispatchRules.Duplicate(calls, 'shots_fired', { x = 10.0, y = 0.0, z = 0.0 }, 150, c).id, 1, 'duplicado')
eq(DispatchRules.Duplicate(calls, 'shots_fired', { x = 500.0, y = 0.0, z = 0.0 }, 150, c), nil, 'longe não duplica')
eq(DispatchRules.Duplicate(calls, 'shots_fired', { x = 10.0, y = 0.0, z = 0.0 }, 100 + c.DedupeSeconds + 1, c), nil, 'antigo não duplica')
eq(DispatchRules.Duplicate(calls, 'assault', { x = 10.0, y = 0.0, z = 0.0 }, 150, c), nil, 'outro código não duplica')

-- Expiração
calls[2] = { id = 2, code = 'assault', category = 'police', priority = 2, x = 0, y = 0, z = 0, createdAt = 100 + c.TtlSeconds }
local removed = DispatchRules.Prune(calls, 100 + c.TtlSeconds + 1, c)
eq(#removed, 1, 'um vencido')
eq(removed[1], 1, 'vencido é o 1')
eq(calls[1], nil, 'removido')
assert(calls[2], 'o 2 permanece')

-- Contagem, cooldown e ordenação
eq(DispatchRules.CountActive(calls, 'police'), 1, 'contagem police')
eq(DispatchRules.CountActive(calls, 'ems'), 0, 'contagem ems')
eq(DispatchRules.CooldownReady(nil, 10, c), true, 'sem histórico')
eq(DispatchRules.CooldownReady(100, 120, c), false, 'em cooldown')
eq(DispatchRules.CooldownReady(100, 100 + c.CitizenCooldownSeconds, c), true, 'cooldown vencido')

local sorted = DispatchRules.Sorted({
	[1] = { id = 1, category = 'police', priority = 3 },
	[2] = { id = 2, category = 'police', priority = 1 },
	[3] = { id = 3, category = 'police', priority = 1 },
	[4] = { id = 4, category = 'ems', priority = 1 }
}, 'police')
eq(#sorted, 3, 'só a categoria')
eq(sorted[1].id, 3, 'urgente mais recente primeiro')
eq(sorted[2].id, 2, 'urgente mais antigo')
eq(sorted[3].id, 1, 'menos urgente por último')

-- Id de chamado
eq(DispatchRules.CallId(5), 5, 'id válido')
eq(select(2, DispatchRules.CallId(0)), 'invalid_call', 'id zero')
eq(select(2, DispatchRules.CallId(1.5)), 'invalid_call', 'id fracionado')
eq(select(2, DispatchRules.CallId('1')), 'invalid_call', 'id texto')
eq(select(2, DispatchRules.CallId(nil)), 'invalid_call', 'id nil')

print('dispatch rules ok')
