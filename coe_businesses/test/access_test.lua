dofile('../coe_businesses/config.lua')
dofile('../coe_businesses/shared/area.lua')
dofile('../coe_businesses/server/grades.lua')
dofile('../coe_businesses/server/registry.lua')
dofile('../coe_businesses/server/access.lua')
dofile('../coe_businesses/server/duty.lua')

local function eq(a, b, m)
	if a ~= b then error(('%s: esperado %s, veio %s'):format(m, tostring(b), tostring(a)), 2) end
end

local function biz(id, owner, staffIds, rules)
	local staff = {}
	for _, characterId in ipairs(staffIds or {}) do staff[#staff + 1] = { characterId = characterId, name = 'x' } end
	return { id = id, enabled = true, category = 'restaurant', area = { kind = 'circle', x = 0, y = 0, z = 30, radius = 20 }, owner = owner and { characterId = owner } or nil, staff = staff, rules = rules or {} }
end

local A = biz('rest_a', '10', { '11', '12' })
local B = biz('rest_b', '20', { '21' })
local E = BusinessAccess.Evaluate

-- Dono: opera/administra só de ponto batido naquele negócio
eq(E(A, 10, false).canWork, false, 'dono sem ponto não opera')
eq(E(A, 10, true).canWork, true, 'dono de ponto opera')
eq(E(A, 10, false).canClock, true, 'dono bate ponto')
eq(E(B, 10, true).canWork, false, 'dono de A não opera B, mesmo de ponto em B')
eq(E(B, 10, true).canClock, false, 'dono de A não bate ponto em B')
A.rules.clockRequired = false
eq(E(A, 10, false).canWork, true, 'clockRequired=false: dono opera sem ponto')
A.rules.clockRequired = nil
A.rules.ownerAccess = false
eq(E(A, 10, true).canWork, false, 'ownerAccess desligado: dono sem cadastro não opera')
A.rules.ownerAccess = nil

-- Equipe: só quem está cadastrado no negócio, de ponto
eq(E(A, 11, false).canClock, true, 'funcionário bate ponto')
eq(E(A, 11, false).canWork, false, 'funcionário sem ponto não opera')
eq(E(A, 11, true).canWork, true, 'funcionário de ponto opera')
eq(E(B, 11, true).canWork, false, 'funcionário de A não opera B, mesmo de ponto')
eq(E(B, 11, true).canClock, false, 'funcionário de A não bate ponto em B')

-- clockRequired=false: a equipe continua sendo de cada negócio
A.rules = { clockRequired = false }
B.rules = { clockRequired = false }
eq(E(A, 11, false).canWork, true, 'clockRequired=false: equipe de A opera A sem ponto')
eq(E(B, 11, false).canWork, false, 'clockRequired=false: equipe de A não opera B')
eq(E(B, 21, false).canWork, true, 'clockRequired=false: equipe de B opera B')
eq(E(A, 21, false).canWork, false, 'clockRequired=false: equipe de B não opera A')
eq(E(A, 99, false).canWork, false, 'quem não está cadastrado não opera')

-- Outros casos
eq(E(A, nil, true).canWork, false, 'sem personagem')
eq(E(nil, 11, true).canWork, false, 'negócio inexistente')
A.enabled = false
eq(E(A, 10, true).canWork, false, 'negócio desligado ninguém opera')
A.enabled = true
eq(BusinessAccess.IsStaff(A, 11), true, 'IsStaff')
eq(BusinessAccess.IsStaff(A, 21), false, 'IsStaff de outro negócio')

-- Normalize: equipe
local function valid(mutate)
	local raw = { id = 'rest_a', category = 'restaurant', label = 'Rest A',
		area = { kind = 'circle', x = 0, y = 0, z = 30, radius = 20 }, stations = {}, rules = {},
		staff = { { characterId = '11', name = 'Ana' }, { characterId = '11', name = 'Dup' }, { characterId = '12', name = 'Bia' } } }
	if mutate then mutate(raw) end
	return BusinessRegistry.Normalize(BusinessesConfig, raw)
end
eq(#valid().staff, 2, 'duplicados são ignorados')
eq(#valid(function(r) r.staff = nil end).staff, 0, 'sem equipe')
eq(select(2, valid(function(r) r.staff = { { characterId = 'a b' } } end)), 'invalid_staff', 'id inválido')
eq(select(2, valid(function(r) r.staff = 'x' end)), 'invalid_staff', 'tipo inválido')
eq(select(2, valid(function(r)
	r.staff = {}
	for i = 1, BusinessesConfig.Limits.MaxStaff + 1 do r.staff[i] = { characterId = tostring(i), name = 'n' } end
end)), 'invalid_staff', 'limite de equipe')

-- Ponto: sai quando deixa de ser da equipe
local businesses = { rest_a = A, rest_b = B }
local events = {}
local duty = BusinessDuty.New({
	get = function(id) return businesses[id] end,
	member = function(business, characterId) return E(business, characterId, false).canClock end,
	changed = function(source, id, on, reason) events[#events + 1] = ('%s:%s:%s'):format(id, tostring(on), reason) end
})
local at = { x = 0, y = 0, z = 30 }
eq(duty.ClockIn(1, '11', 'rest_a', at, false), true, 'bate ponto em A')
eq(select(2, duty.ClockIn(1, '11', 'rest_b', at, false)), 'on_duty_elsewhere', 'não bate ponto em dois negócios')
eq(duty.IsOnDuty('rest_b', '11'), false, 'ponto de A não vale em B')
eq(duty.Sweep(function() return at end), 0, 'continua na equipe')
A.staff = {}
eq(duty.Sweep(function() return at end), 1, 'removido da equipe encerra o ponto')
eq(events[#events], 'rest_a:false:not_staff', 'motivo')

print('access_test ok')
