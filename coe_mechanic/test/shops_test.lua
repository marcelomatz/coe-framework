local function loadFramework(path)
	local candidates = {
		'../' .. path,
		'../tools/compat/' .. path,
		'../[coe-framework]/' .. path,
		'../../coe-framework/' .. path
	}
	for _, c in ipairs(candidates) do
		local f = io.open(c, 'r')
		if f then f:close() return dofile(c) end
	end
	error('Cannot find framework file: ' .. path)
end

loadFramework('coe_businesses/config.lua')
loadFramework('coe_businesses/shared/area.lua')
loadFramework('coe_businesses/server/grades.lua')
loadFramework('coe_businesses/server/registry.lua')
dofile('../coe_mechanic/config.lua')
dofile('../coe_mechanic/server/shops.lua')

local function eq(a, b, m)
	if a ~= b then error(('%s: esperado %s, veio %s'):format(m, tostring(b), tostring(a)), 2) end
end

local config = CoeMechanicConfig

local function raw(id)
	return {
		id = id, category = 'mechanic', label = "Benny's Original Motorworks",
		area = { kind = 'circle', x = -205.7, y = -1312.2, z = 31.3, radius = 30 },
		stations = {
			showroom = { x = -205.7, y = -1312.2, z = 31.3, radius = 7 },
			crafts = { { id = 'bancada', label = 'Bancada de craft', x = -196.4, y = -1318.1, z = 31.1, radius = 1.6 } },
			stashes = { { id = 'main', label = 'Baú da oficina', x = -199.6, y = -1311.0, z = 31.1, radius = 1.6, slots = 40, maxWeight = 150000 } }
		},
		rules = {}
	}
end

eq(next(config.Shops), nil, 'sem oficinas hardcoded')

-- Um negócio válido vira oficina.
local business = BusinessRegistry.Normalize(BusinessesConfig, raw('bennys'))
eq(business ~= nil, true, 'negócio é válido')
eq(business.area.radius, 30, 'área')

local shop = MechanicShops.FromBusiness(business, config)
eq(shop.label, "Benny's Original Motorworks", 'rótulo')
eq(shop.ownerAccess, true, 'dono atende')
eq(#shop.crafts, 1, 'bancada')
eq(shop.crafts[1].point.radius, 1.6, 'ponto da bancada')
eq(shop.stashes[1].slots, 40, 'baú')
eq(MechanicShops.Station(shop, 'stashes', 'main').id, 'main', 'busca por id')
eq(MechanicShops.Station(shop, 'stashes', 'nada'), nil, 'id inexistente')
eq(MechanicShops.Station(nil, 'stashes', 'main'), nil, 'oficina inexistente')

-- Sem estação showroom usa o centro da área.
business.stations.showroom = nil
eq(MechanicShops.FromBusiness(business, config).showroom.x, business.area.x, 'showroom padrão')

-- Apply troca o conteúdo da tabela viva; desativado e outras categorias ficam de fora.
local live = { velha = {} }
local off = BusinessRegistry.Normalize(BusinessesConfig, raw('outra'))
off.enabled = false
local shopBusiness = BusinessRegistry.Normalize(BusinessesConfig, {
	id = 'loja', category = 'shop', label = 'Loja',
	area = { kind = 'circle', x = 0, y = 0, z = 0, radius = 10 }
})
MechanicShops.Apply(live, { business, off, shopBusiness }, config)
eq(live.velha, nil, 'substitui o conteúdo')
eq(live.bennys ~= nil, true, 'ativa entra')
eq(live.outra, nil, 'desativada fica de fora')
eq(live.loja, nil, 'outra categoria fica de fora')

print('shops_test ok')
