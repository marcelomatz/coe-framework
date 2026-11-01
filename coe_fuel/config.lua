-- Combustível do Coe (etapa A): consumo nos veículos, quatro combustíveis, postos com bandeira e bombas.
-- Postos sem dono (da staff) têm estoque infinito; com dono, vendem só o que está nos tanques do posto
-- (abastecidos na refinaria na etapa B; até lá, pelo comando de staff `coe_fuel_tank`).
FuelConfig = {
	CallCooldownMs = 400,
	-- Distância da bomba (jogador) e do veículo até o jogador para abastecer.
	PumpRadius = 4.0,
	VehicleRadius = 7.0,
	-- Vazão da bomba (litros por segundo): o tempo de abastecer é proporcional aos litros.
	PumpRate = 2.5,
	MaxLitersPerSale = 400,
	-- Consumo do GTA é em escala de mapa: multiplica o consumo real para um tanque cheio durar ~1 h de direção.
	ConsumptionScale = 8.0,
	-- Relatório do motorista: intervalo e limites aceitos pelo servidor.
	ReportSeconds = 5,
	MaxReportSeconds = 15,
	MaxSpeed = 95.0, -- m/s (~340 km/h)
	-- Veículos sem registro (NPC, admin) começam com um nível aleatório entre estes valores.
	UnregisteredLevel = { min = 0.2, max = 0.6 },
	-- Veículo registrado sem linha no banco começa com esta fração do tanque.
	RegisteredStartLevel = 0.5,
	-- Gravação dos tanques dos veículos registrados (em lote).
	FlushSeconds = 60,

	Payments = { cash = true, wallet = true, card = true },
	ManageAce = 'coe_fuel.manage',

	-- Combustíveis. consumption: multiplica o consumo; power: força do motor (coe_handling, fInitialDriveForce);
	-- wear: metros extras de desgaste por metro rodado nas peças de `WearParts` (coe_mechanic). Negativo limpa
	-- o desgaste acumulado pela comum (a aditivada "limpa" o motor), nunca deixa a peça mais nova que a troca.
	Fuels = {
		regular = { label = 'Gasolina comum', short = 'Comum', price = 6, consumption = 1.00, power = 1.00, wear = 0.5, engine = 'flex', color = '#e8b04b' },
		premium = { label = 'Gasolina aditivada', short = 'Aditivada', price = 7, consumption = 0.88, power = 1.02, wear = -0.25, engine = 'flex', color = '#4fb3ff' },
		ethanol = { label = 'Etanol', short = 'Etanol', price = 4, consumption = 1.30, power = 1.06, wear = 0.0, engine = 'flex', color = '#6fcf73' },
		diesel = { label = 'Diesel', short = 'Diesel', price = 5, consumption = 1.00, power = 1.00, wear = 0.0, engine = 'diesel', color = '#b0b6c0' }
	},
	FuelOrder = { 'regular', 'premium', 'ethanol', 'diesel' },
	WearParts = { 'spark_plugs', 'air_filter', 'engine_oil' },
	-- Desgaste extra acumulado (metros) antes de mandar para o coe_mechanic.
	WearFlushMeters = 500,

	-- Motor por classe do GTA (GetVehicleClass). diesel: comerciais, industriais, utilitários, serviço, militares.
	-- none: bicicletas, helicópteros, aviões e trens (não consomem; aeronaves entram depois).
	DieselClasses = { [10] = true, [11] = true, [17] = true, [19] = true, [20] = true },
	NoFuelClasses = { [13] = true, [15] = true, [16] = true, [21] = true },
	-- Exceções por modelo.
	DieselModels = {
		'bison', 'bison2', 'bison3', 'sandking', 'sandking2', 'rebel', 'rebel2', 'dubsta3', 'guardian', 'kamacho',
		'mesa3', 'brickade', 'boxville', 'boxville2', 'boxville3', 'boxville4', 'mule', 'mule2', 'mule3', 'benson',
		'pounder', 'burrito', 'burrito2', 'burrito3', 'burrito4', 'gburrito', 'speedo', 'speedo2', 'rumpo', 'rumpo2'
	},
	FlexModels = {},

	-- Tanque (litros) e consumo (L/100 km reais, antes da escala) por classe do GTA. Marcha lenta: L/h.
	Classes = {
		[0] = { tank = 40, per100 = 7 },   -- compactos
		[1] = { tank = 55, per100 = 9 },   -- sedãs
		[2] = { tank = 75, per100 = 13 },  -- SUVs
		[3] = { tank = 55, per100 = 10 },  -- cupês
		[4] = { tank = 70, per100 = 15 },  -- muscle
		[5] = { tank = 60, per100 = 13 },  -- clássicos esportivos
		[6] = { tank = 65, per100 = 14 },  -- esportivos
		[7] = { tank = 80, per100 = 18 },  -- super
		[8] = { tank = 15, per100 = 5 },   -- motos
		[9] = { tank = 80, per100 = 15 },  -- off-road
		[10] = { tank = 200, per100 = 35 }, -- industriais
		[11] = { tank = 120, per100 = 22 }, -- utilitários
		[12] = { tank = 80, per100 = 13 },  -- vans
		[14] = { tank = 150, per100 = 30 }, -- barcos
		[17] = { tank = 150, per100 = 25 }, -- serviço
		[18] = { tank = 80, per100 = 14 },  -- emergência
		[19] = { tank = 200, per100 = 35 }, -- militares
		[20] = { tank = 300, per100 = 30 }, -- comerciais
		[22] = { tank = 60, per100 = 20 }   -- open wheel
	},
	DefaultClass = { tank = 60, per100 = 12 },
	IdlePerHour = 0.8,

	-- Galão: item `fuel_can` (metadata { fuel, liters }). Comprado cheio na bomba ou reabastecido vazio.
	Can = { item = 'fuel_can', capacity = 20, price = 60, pourRate = 2.0 },

	-- Bombas do mapa (alvo "Abastecer"). Só funcionam dentro de um posto da lista.
	PumpModels = {
		'prop_gas_pump_1a', 'prop_gas_pump_1b', 'prop_gas_pump_1c', 'prop_gas_pump_1d',
		'prop_gas_pump_old2', 'prop_gas_pump_old3', 'prop_vintage_pump'
	},
	NozzleModel = 'prop_cs_fuel_nozle',

	-- Bandeiras: nome, cor do blip e identidade da bomba (`theme`: cor principal, cor de destaque, texto sobre a
	-- principal). As cores seguem as bandeiras do jogo e podem ser ajustadas aqui.
	Brands = {
		ron = { label = 'Ron', color = 47, theme = { primary = '#f26a1b', accent = '#1d2b4a', text = '#ffffff' } },
		globe = { label = 'Globe Oil', color = 3, theme = { primary = '#1f4fa8', accent = '#f5c518', text = '#ffffff' } },
		xero = { label = 'Xero', color = 38, theme = { primary = '#d42a2f', accent = '#f2f2f2', text = '#ffffff' } },
		ltd = { label = 'LTD Gasoline', color = 2, theme = { primary = '#1f8a3c', accent = '#ffd200', text = '#ffffff' } },
		none = { label = 'Sem bandeira', color = 4, theme = { primary = '#4a5360', accent = '#c9ced6', text = '#ffffff' } }
	},
	BlipSprite = 361,

	-- Postos de jogador -------------------------------------------------------------------------------------------
	-- Preço por litro nas bombas: o dono define entre Min e Max vezes o preço de tabela (aba Posto do tablet).
	PriceBand = { Min = 0.5, Max = 3.0 },

	-- Tanques: cada combustível tem o seu nível. O upgrade custa dinheiro (caixa do posto) e exige litros vendidos
	-- no posto como posto de jogador (histórico de funcionamento). O nível 1 vem com o posto.
	TankLevels = {
		{ capacity = 5000, price = 0, sold = 0 },
		{ capacity = 10000, price = 20000, sold = 10000 },
		{ capacity = 20000, price = 50000, sold = 40000 },
		{ capacity = 40000, price = 120000, sold = 120000 }
	},

	-- Frota de abastecimento: comprada em ordem (van → caminhão → caminhão-tanque). Cada nível entrega um veículo
	-- registrado na garagem de frota do posto (coe_garages; a staff cria a garagem de negócio do posto no admin).
	-- capacity: litros de carga (somando os combustíveis). sold: litros vendidos exigidos.
	FleetTiers = {
		{ id = 'van', label = 'Van pequena', model = 'speedo', capacity = 800, price = 8000, sold = 0 },
		{ id = 'truck', label = 'Caminhão', model = 'benson', capacity = 3500, price = 45000, sold = 15000 },
		{ id = 'tanker', label = 'Caminhão-tanque', model = 'phantom', capacity = 12000, price = 150000, sold = 80000 }
	},

	-- Refinaria: onde a frota carrega. Preço de atacado por litro (debitado do caixa do posto). Posição provisória.
	Refinery = {
		label = 'Refinaria de Murrieta',
		center = { 1733.5, -1608.3, 112.5 },
		radius = 45.0,
		blip = { sprite = 361, color = 1 },
		prices = { regular = 3.0, premium = 3.6, ethanol = 2.0, diesel = 2.5 }
	},
	-- Vazão de carga e descarga (litros por segundo): o tempo é proporcional aos litros.
	LoadRate = 100,
	-- Distância entre o jogador e o veículo da frota para carregar ou descarregar.
	CargoReach = 6.0,

	-- Postos: id, nome, bandeira, centro e raio. `business` aponta para um negócio que já existe (as lojas LTD do
	-- coe_shops); sem ele, o posto vira o negócio `posto_<id>` (categoria gas_station) criado sem dono.
	-- Bandeiras e posições são provisórias: confira a placa de cada posto no jogo e ajuste aqui.
	Stations = {
		{ id = 'route68_west', label = 'Route 68 Oeste', brand = 'globe', center = { 49.42, 2778.79, 58.04 } },
		{ id = 'harmony', label = 'Harmony', brand = 'xero', center = { 263.89, 2606.46, 44.98 } },
		{ id = 'route68_senora', label = 'Route 68 Grand Senora', brand = 'ron', center = { 1039.96, 2671.13, 39.55 } },
		{ id = 'route68_east', label = 'Route 68 Leste', brand = 'none', center = { 1207.26, 2660.18, 37.90 } },
		{ id = 'senora_rex', label = 'Senora Fwy (Rex\'s Diner)', brand = 'none', center = { 2539.69, 2594.19, 37.94 } },
		{ id = 'senora_fwy', label = 'Senora Fwy', brand = 'xero', center = { 2679.86, 3263.95, 55.24 } },
		{ id = 'sandy_shores', label = 'Sandy Shores', brand = 'globe', center = { 2005.06, 3773.89, 32.40 } },
		{ id = 'sandy_airfield', label = 'Sandy Shores (Aeródromo)', brand = 'none', center = { 1784.32, 3330.55, 41.25 } },
		{ id = 'grapeseed', label = 'LTD Grapeseed', brand = 'ltd', center = { 1687.16, 4929.39, 42.08 }, business = 'ltd_grapeseed' },
		{ id = 'paleto_highway', label = 'Paleto (Great Ocean Hwy)', brand = 'xero', center = { 1701.31, 6416.03, 32.76 } },
		{ id = 'paleto_bay', label = 'Paleto Bay', brand = 'ron', center = { 179.86, 6602.84, 31.87 } },
		{ id = 'paleto_blvd', label = 'Paleto Blvd', brand = 'xero', center = { -94.46, 6419.59, 31.49 } },
		{ id = 'zancudo', label = 'Lago Zancudo', brand = 'ron', center = { -2554.99, 2334.40, 33.08 } },
		{ id = 'richman', label = 'LTD Richman Glen', brand = 'ltd', center = { -1800.38, 803.66, 138.65 }, business = 'ltd_richman' },
		{ id = 'morningwood', label = 'Morningwood', brand = 'ron', center = { -1437.62, -276.75, 46.21 } },
		{ id = 'pacific_bluffs', label = 'Pacific Bluffs', brand = 'xero', center = { -2096.24, -320.29, 13.17 } },
		{ id = 'little_seoul', label = 'LTD Little Seoul', brand = 'ltd', center = { -724.62, -935.16, 19.21 }, business = 'ltd_little_seoul' },
		{ id = 'calais', label = 'Little Seoul (Calais Ave)', brand = 'xero', center = { -526.02, -1211.00, 18.18 } },
		{ id = 'grove', label = 'LTD Grove Street', brand = 'ltd', center = { -70.21, -1761.79, 29.53 }, business = 'ltd_grove' },
		{ id = 'davis', label = 'Davis', brand = 'ron', center = { 176.63, -1562.03, 29.26 } },
		{ id = 'davis_west', label = 'Davis (Strawberry Ave)', brand = 'globe', center = { -319.29, -1471.72, 30.55 } },
		{ id = 'strawberry', label = 'Strawberry', brand = 'xero', center = { 265.65, -1261.31, 29.29 } },
		{ id = 'la_mesa', label = 'La Mesa', brand = 'ron', center = { 819.65, -1028.85, 26.40 } },
		{ id = 'el_burro', label = 'El Burro Heights', brand = 'ron', center = { 1208.95, -1402.57, 35.22 } },
		{ id = 'mirror_park', label = 'LTD Mirror Park', brand = 'ltd', center = { 1181.38, -330.85, 69.32 }, business = 'ltd_mirror_park' },
		{ id = 'vinewood', label = 'Downtown Vinewood', brand = 'globe', center = { 620.84, 269.10, 103.09 } },
		{ id = 'tataviam', label = 'Tataviam (Palomino Fwy)', brand = 'ron', center = { 2581.32, 362.04, 108.47 } }
	},
	StationRadius = 28.0
}
