dofile('server/analytics.lua')

local function eq(a, b, m)
	if a ~= b then error(('%s: esperado %s, veio %s'):format(m, tostring(b), tostring(a)), 2) end
end

local result = AdminAnalytics.Build({
	players = { { ping = 40, hasCharacter = true }, { ping = 61, hasCharacter = false } },
	businesses = { available = true, list = {
		{ id = 'a', label = 'A', category = 'mechanic', owner = { characterId = '1' }, staff = { {}, {} }, stations = { crafts = { {} }, stashes = { {}, {} }, clocks = {} } },
		{ id = 'b', label = 'B', category = 'restaurant', staff = {}, stations = { clocks = { {} } }, enabled = false }
	} },
	garages = { available = true, list = { { id = 'g1', kind = 'public', spots = { {}, {}, {} } }, { id = 'g2', kind = 'business', spots = { {} } } } },
	fleets = { g2 = { {}, {} } },
	housing = { available = true, list = { { kind = 'house', units = 2, occupied = 1 }, { kind = 'hotel', units = 10, occupied = 4 } } },
	duty = { total = 3, byBusiness = { a = 2, b = 1 } },
	economy = { accounts = 5, total = 1000 },
	database = { characters = 12 },
	resources = { { state = 'started', critical = true }, { state = 'stopped' }, { state = 'started' } }
})

eq(result.players.online, 2, 'online')
eq(result.players.withCharacter, 1, 'com personagem')
eq(result.players.averagePing, 51, 'ping médio arredondado')
eq(result.players.characters, 12, 'personagens')
eq(result.businesses.total, 2, 'negócios')
eq(result.businesses.byCategory.mechanic, 1, 'por categoria')
eq(result.businesses.withOwner, 1, 'com dono')
eq(result.businesses.withoutOwner, 1, 'sem dono')
eq(result.businesses.staff, 2, 'funcionários')
eq(result.businesses.withoutStaff, 1, 'sem equipe')
eq(result.businesses.disabled, 1, 'desligados')
eq(result.businesses.stations.stashes, 2, 'baús')
eq(result.businesses.stations.clocks, 1, 'pontos')
eq(result.businesses.onDuty, 3, 'de ponto')
eq(result.businesses.dutyByBusiness[1].id, 'a', 'ordenado por presença')
eq(result.garages.spots, 4, 'vagas')
eq(result.garages.fleetVehicles, 2, 'frota')
eq(result.garages.byKind.public, 1, 'garagens públicas')
eq(result.housing.units, 12, 'unidades')
eq(result.housing.occupied, 5, 'ocupadas')
eq(result.housing.vacant, 7, 'livres')
eq(result.economy.total, 1000, 'dinheiro')
eq(result.framework.started, 2, 'resources iniciados')
eq(result.framework.stopped, 1, 'parados')
eq(result.framework.critical, 1, 'críticos')

local empty = AdminAnalytics.Build({})
eq(empty.businesses.available, false, 'sem negócios')
eq(empty.economy.available, false, 'sem economia')
eq(AdminAnalytics.Build({ economy = { error = 'forbidden' } }).economy.available, false, 'erro da economia')

-- Cache: primeira chamada carrega; depois serve o antigo e atualiza em segundo plano
local clock, loads, queued = 0, 0, nil
local cache = AdminAnalytics.Cache({
	now = function() return clock end,
	load = function() loads = loads + 1; return { n = loads } end,
	async = function(fn) queued = fn end
}, 1000)
eq(cache.Get().n, 1, 'primeira carga')
eq(cache.Get().n, 1, 'dentro do TTL')
eq(loads, 1, 'sem recarga')
clock = 1500
eq(cache.Get().n, 1, 'expirado serve o valor antigo')
eq(type(queued), 'function', 'atualização agendada')
queued(); queued = nil
eq(cache.Get().n, 2, 'valor novo após a atualização')
eq(loads, 2, 'uma recarga só')
cache.Get()
eq(queued, nil, 'não agenda de novo dentro do TTL')

local failing = AdminAnalytics.Cache({ now = function() return 0 end, load = function() return nil end, async = function() end }, 1000)
eq(failing.Get(), nil, 'falha na primeira carga')

print('analytics_test ok')
