dofile('../coe_garages/config.lua')
dofile('../coe_garages/server/rules.lua')

local function eq(a, b, m)
	if a ~= b then error(('%s: esperado %s, veio %s'):format(m, tostring(b), tostring(a)), 2) end
end

local config = GaragesConfig

eq(GaragesRules.ClassOf(config, { type = 'bike' }), 'bike', 'moto')
eq(GaragesRules.ClassOf(config, { type = 'automobile' }), 'car', 'carro')
eq(GaragesRules.ClassOf(config, nil), 'car', 'sem catálogo conta como carro')

eq(GaragesRules.Capacity(config, 1).car, 1, 'nível 1: um carro')
eq(GaragesRules.Capacity(config, 1).bike, 1, 'nível 1: uma moto')
eq(GaragesRules.Capacity(config, 99).car, 1, 'nível desconhecido usa o padrão')

eq(GaragesRules.CanStore(config, 1, { car = 0, bike = 0 }, 'car'), true, 'cabe um carro')
eq(select(2, GaragesRules.CanStore(config, 1, { car = 1, bike = 0 }, 'car')), 'garage_full', 'segundo carro não cabe')
eq(GaragesRules.CanStore(config, 1, { car = 1, bike = 0 }, 'bike'), true, 'moto tem vaga própria')
eq(select(2, GaragesRules.CanStore(config, 1, { car = 0, bike = 1 }, 'bike')), 'garage_full', 'segunda moto não cabe')

local entry = { staff = false, access = { ['8'] = true } }
eq(GaragesRules.CanUseFleet(entry, '7', true, false), true, 'dono usa tudo')
eq(GaragesRules.CanUseFleet(entry, 8, false, false), true, 'liberado pelo dono (id numérico)')
eq(GaragesRules.CanUseFleet(entry, '9', false, true), false, 'equipe sem liberação geral não usa')
entry.staff = true
eq(GaragesRules.CanUseFleet(entry, '9', false, true), true, 'equipe de ponto batido usa quando liberado')
eq(GaragesRules.CanUseFleet(entry, '9', false, false), false, 'equipe fora do ponto não usa')
eq(GaragesRules.CanUseFleet({}, '9', false, false), false, 'sem acesso')

local business = { owner = { characterId = '7', name = 'Fulano' } }
eq(GaragesRules.IsStaff({ staff = true, canWork = true }), true, 'equipe que pode operar')
eq(GaragesRules.IsStaff({ staff = true, canWork = false }), false, 'equipe sem ponto')
eq(GaragesRules.IsStaff({ staff = false, canWork = true }), false, 'não é da equipe')
eq(GaragesRules.IsStaff(nil), false, 'sem acesso')
eq(GaragesRules.IsOwner(business, 7), true, 'dono')
eq(GaragesRules.IsOwner(business, '8'), false, 'não é o dono')
eq(GaragesRules.IsOwner({}, '7'), false, 'sem dono')

print('rules_test ok')
