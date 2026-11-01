dofile('config.lua')
dofile('shared/rules.lua')
local config = FuelConfig

local function eq(a, b, m)
	if a ~= b then error(('%s: esperado %s, veio %s'):format(m, tostring(b), tostring(a)), 2) end
end
local function near(a, b, m) if math.abs(a - b) > 1e-6 then error(('%s: esperado %s, veio %s'):format(m, b, a), 2) end end
local function hash(name) local h = 0 for i = 1, #name do h = (h * 31 + name:byte(i)) % 4294967296 end return h end

local catalog, err = FuelRules.Catalog(config, hash)
eq(err, nil, 'config valido')
eq(#catalog.stations, #config.Stations, 'todos os postos')
eq(catalog.byId.grove.business, 'ltd_grove', 'LTD usa o negocio da loja')
eq(catalog.byId.davis.business, 'posto_davis', 'posto sem negocio vira posto_<id>')
for _, station in ipairs(catalog.stations) do
	eq(#station.business <= 24, true, station.id .. ' id de negocio curto')
	eq(config.Brands[station.brand] ~= nil, true, station.id .. ' bandeira')
end
local brands = {}
for _, station in ipairs(catalog.stations) do brands[station.brand] = true end
for _, brand in ipairs({ 'ron', 'globe', 'xero', 'ltd', 'none' }) do eq(brands[brand], true, 'tem posto ' .. brand) end
local bad = { FuelOrder = { 'x' }, Fuels = { x = { price = 0 } }, Brands = config.Brands, Stations = {} }
eq(select(2, FuelRules.Catalog(bad)), 'invalid_fuel:x', 'preco zero')
bad = { FuelOrder = {}, Fuels = {}, Brands = config.Brands, StationRadius = 20, Stations = { { id = 'aa', label = 'A', brand = 'shell', center = { 0, 0, 0 } } } }
eq(select(2, FuelRules.Catalog(bad)), 'invalid_station:1', 'bandeira desconhecida')

-- motor
eq(FuelRules.Engine(config, catalog, 1, hash('asea')), 'flex', 'sedan e flex')
eq(FuelRules.Engine(config, catalog, 20, hash('phantom')), 'diesel', 'comercial e diesel')
eq(FuelRules.Engine(config, catalog, 12, hash('burrito')), 'diesel', 'van da lista e diesel')
eq(FuelRules.Engine(config, catalog, 12, hash('youga')), 'flex', 'van fora da lista e flex')
eq(FuelRules.Engine(config, catalog, 13, hash('bmx')), 'none', 'bicicleta nao consome')
eq(FuelRules.Engine(config, catalog, 'x', nil), 'flex', 'classe invalida vira flex')
eq(FuelRules.Compatible(catalog, 'flex', 'ethanol'), true, 'flex aceita etanol')
eq(FuelRules.Compatible(catalog, 'flex', 'diesel'), false, 'flex nao aceita diesel')
eq(FuelRules.Compatible(catalog, 'diesel', 'regular'), false, 'diesel nao aceita gasolina')
eq(FuelRules.Compatible(catalog, 'diesel', 'diesel'), true, 'diesel aceita diesel')
eq(FuelRules.ClassSpec(config, 1).tank, 55, 'tanque do sedan')
eq(FuelRules.ClassSpec(config, 99).tank, config.DefaultClass.tank, 'classe desconhecida')

-- tanque e mistura
local tank = FuelRules.Empty(config)
local added
tank, added = FuelRules.Add(config, tank, 'regular', 30, 55)
eq(added, 30, 'entra tudo')
tank, added = FuelRules.Add(config, tank, 'ethanol', 40, 55)
eq(added, 25, 'so o espaco')
eq(FuelRules.Total(tank), 55, 'cheio')
local effects = FuelRules.Effects(config, catalog, tank)
near(effects.shares.ethanol, 25 / 55, 'parte de etanol')
near(effects.consumption, math.floor((30 / 55 * 1 + 25 / 55 * 1.3) * 1000 + 0.5) / 1000, 'consumo da mistura')
eq(effects.power > 1, true, 'etanol da forca')
eq(effects.wear > 0, true, 'comum desgasta')
eq(FuelRules.EffectsKey(effects), 'p3', 'chave do efeito')
local premium = FuelRules.Effects(config, catalog, { premium = 20 })
eq(premium.consumption < 1, true, 'aditivada rende mais')
eq(premium.wear < 0, true, 'aditivada limpa')
eq(FuelRules.Effects(config, catalog, FuelRules.Empty(config)).power, 1, 'vazio neutro')
local used
tank, used = FuelRules.Consume(config, tank, 11)
eq(used, 11, 'gasta')
near(FuelRules.Total(tank), 44, 'sobra')
near(tank.regular / FuelRules.Total(tank), 30 / 55, 'mantem a proporcao')
tank, used = FuelRules.Consume(config, tank, 100)
near(used, 44, 'gasta so o que tem')
eq(FuelRules.Total(tank), 0, 'vazio')
eq(FuelRules.Clean(config, { regular = -3, x = 4 }).regular, 0, 'sem negativo nem desconhecido')

-- consumo
local spec = FuelRules.ClassSpec(config, 1)
local liters = FuelRules.Usage(config, spec, { consumption = 1 }, 1000, 0, 0.5)
near(liters, 9 * config.ConsumptionScale / 100 * (0.6 + 0.4), '1 km no sedan')
near(FuelRules.Usage(config, spec, { consumption = 1.3 }, 1000, 0, 0.5), liters * 1.3, 'etanol queima mais')
near(FuelRules.Usage(config, spec, nil, 0, 3600, 0), config.IdlePerHour, 'marcha lenta')
local m, s = FuelRules.ClampReport(config, 99999, 60)
eq(s, config.MaxReportSeconds, 'tempo limitado')
eq(m, config.MaxReportSeconds * config.MaxSpeed, 'distancia limitada pela velocidade')
eq(select(1, FuelRules.ClampReport(config, -5, 5)), 0, 'sem distancia negativa')

-- bomba
eq(FuelRules.CleanLiters('12.37', 100), 12.3, 'arredonda')
eq(FuelRules.CleanLiters(0.2, 100), nil, 'pouco')
eq(FuelRules.CleanLiters(101, 100), nil, 'demais')
eq(FuelRules.CleanLiters('x', 100), nil, 'invalido')
eq(FuelRules.Price(6, 12.3), 74, 'total arredondado para cima')
eq(FuelRules.Price(5, 10), 50, 'total exato')
local station = catalog.byId.davis
eq(FuelRules.StationAt(catalog, station.x + 5, station.y, station.z).id, 'davis', 'dentro do posto')
eq(FuelRules.StationAt(catalog, 0, 0, 0), nil, 'fora de posto')
eq(FuelRules.Mode({ owner = { characterId = '1' } }), 'player', 'posto de jogador')
eq(FuelRules.Mode({}), 'staff', 'posto da staff')
local seed = FuelRules.BusinessSeed(station)
eq(seed.id, 'posto_davis', 'negocio do posto')
eq(seed.category, 'gas_station', 'categoria posto')
eq(seed.owner, nil, 'sem dono')
eq(FuelRules.WearMeters({ wear = 0.5 }, 1000), 500, 'desgaste extra')
local summary = FuelRules.Summary(config, catalog, { regular = 10, ethanol = 30 }, 40, 'flex')
eq(summary.level, 1, 'nivel cheio')
eq(summary.main, 'ethanol', 'combustivel principal')
-- preco do dono, tanques, frota, refinaria e descarga
local low, high = FuelRules.PriceBounds(config, 6)
eq(low, 3, 'piso do preco')
eq(high, 18, 'teto do preco')
eq(FuelRules.ValidPrice(config, 6, 8), 8, 'preco valido')
eq(FuelRules.ValidPrice(config, 6, 19), nil, 'acima do teto')
eq(FuelRules.ValidPrice(config, 6, 7.5), nil, 'inteiro')
eq(FuelRules.TankCapacity(config, 1), config.TankLevels[1].capacity, 'tanque nivel 1')
eq(FuelRules.TankCapacity(config, 99), config.TankLevels[#config.TankLevels].capacity, 'nivel acima do maximo')
eq(FuelRules.TankCapacity(config, nil), config.TankLevels[1].capacity, 'sem nivel')
local nextTank, tankError = FuelRules.NextTank(config, 1, 10 ^ 9, 0)
eq(tankError, 'not_enough_sales', 'tanque exige vendas')
nextTank, tankError = FuelRules.NextTank(config, 1, 0, 10 ^ 9)
eq(tankError, 'insufficient_funds', 'tanque exige dinheiro')
nextTank = FuelRules.NextTank(config, 1, config.TankLevels[2].price, config.TankLevels[2].sold)
eq(nextTank.capacity, config.TankLevels[2].capacity, 'upgrade do tanque')
eq(select(2, FuelRules.NextTank(config, #config.TankLevels, 10 ^ 9, 10 ^ 9)), 'max_level', 'tanque no maximo')
local van = FuelRules.NextFleet(config, 0, config.FleetTiers[1].price, 0)
eq(van.id, 'van', 'primeiro a van')
eq(select(2, FuelRules.NextFleet(config, 1, 10 ^ 9, 0)), 'not_enough_sales', 'caminhao exige vendas')
eq(FuelRules.NextFleet(config, 2, 10 ^ 9, 10 ^ 9).id, 'tanker', 'depois o caminhao-tanque')
eq(select(2, FuelRules.NextFleet(config, 3, 10 ^ 9, 10 ^ 9)), 'max_level', 'frota completa')
eq(FuelRules.FleetTier(config, 2).model, config.FleetTiers[2].model, 'modelo do nivel')

local order = FuelRules.LoadOrder(config, { regular = 100 }, 800, { regular = 300, diesel = 200 })
eq(order.liters, 500, 'litros da carga')
eq(order.cost, math.ceil(300 * config.Refinery.prices.regular + 200 * config.Refinery.prices.diesel), 'custo no atacado')
eq(order.add.diesel, 200, 'diesel na carga')
eq(select(2, FuelRules.LoadOrder(config, { regular = 100 }, 800, { regular = 701 })), 'over_capacity', 'acima da capacidade')
eq(select(2, FuelRules.LoadOrder(config, {}, 800, { regular = 0 })), 'empty_load', 'carga vazia')
eq(select(2, FuelRules.LoadOrder(config, {}, 800, { regular = 2.5 })), 'invalid_load', 'litros inteiros')
eq(select(2, FuelRules.LoadOrder(config, {}, 800, { regular = -1 })), 'invalid_load', 'sem negativo')
eq(select(2, FuelRules.LoadOrder(config, {}, 800, 'x')), 'invalid_load', 'pedido invalido')

local newCargo, newTanks, moved, total = FuelRules.Unload(config, { regular = 600, diesel = 200 }, { regular = 4800, diesel = 0 }, { regular = 5000, premium = 5000, ethanol = 5000, diesel = 5000 })
eq(moved.regular, 200, 'so o espaco do tanque')
eq(newCargo.regular, 400, 'sobra na carga')
eq(moved.diesel, 200, 'diesel todo')
eq(newCargo.diesel, 0, 'diesel descarregado')
eq(newTanks.regular, 5000, 'tanque cheio')
eq(total, 400, 'total descarregado')
print('coe_fuel rules tests passed')
