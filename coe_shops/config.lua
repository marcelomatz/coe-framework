-- Lojas do Coe (fase 1: conveniência). Cada loja é um negócio do coe_businesses: enquanto não tem dono é da staff
-- (estoque sempre cheio e preço de tabela); com um jogador como dono, vende só o que a equipe pôs na prateleira, pelo
-- preço que o dono definir. A receita das vendas entra no caixa do negócio (coe_economy).
ShopsConfig = {
	CallCooldownMs = 350,
	-- Distância do balconista para comprar e gerenciar.
	CounterRadius = 4.0,
	-- Distância em que os balconistas aparecem (client).
	SpawnDistance = 60.0,

	Cart = { MaxLines = 20, MaxQuantity = 50, MaxTotal = 50000 },
	-- Faixa do preço que o dono pode definir, em relação ao preço de tabela.
	PriceBand = { Min = 0.5, Max = 3.0 },
	-- Estoque máximo de cada produto na prateleira (lojas de jogadores).
	MaxStock = 500,
	-- Vendas guardadas por loja para o relatório da gestão.
	ReportSales = 30,
	-- Meios de pagamento no balcão. Espécie (item `money`) é daqui; os demais (cartão na maquininha, carteira do
	-- celular...) são registrados por outros resources com RegisterPaymentMethod e entram ligados. `id = false` desliga.
	Payments = { cash = true },
	-- Registrar meios de pagamento: ACE no server.cfg (add_ace resource.<nome> coe.shops.payments allow).
	PaymentsAce = 'coe.shops.payments',

	-- Quem vê a gestão das lojas da staff (relatório de vendas). Lojas de jogadores usam o acesso do coe_businesses.
	ManageAce = 'coe_shops.manage',

	Categories = {
		{ id = 'food', label = 'Comida' },
		{ id = 'drinks', label = 'Bebidas' },
		{ id = 'alcohol', label = 'Bebidas alcoólicas' },
		{ id = 'tobacco', label = 'Tabacaria' },
		{ id = 'health', label = 'Saúde' },
		{ id = 'utility', label = 'Utilidades' }
	},

	-- Produtos: item do coe_inventory, categoria e preço de tabela (o que a loja da staff cobra).
	Products = {
		water = { item = 'water', category = 'drinks', price = 4 },
		sprunk = { item = 'sprunk', category = 'drinks', price = 6 },
		ecola = { item = 'ecola', category = 'drinks', price = 6 },
		coffee = { item = 'coffee', category = 'drinks', price = 5 },
		energy_drink = { item = 'energy_drink', category = 'drinks', price = 9 },
		sandwich = { item = 'sandwich', category = 'food', price = 12 },
		chips = { item = 'chips', category = 'food', price = 5 },
		chocolate = { item = 'chocolate', category = 'food', price = 4 },
		cereal_bar = { item = 'cereal_bar', category = 'food', price = 5 },
		donut = { item = 'donut', category = 'food', price = 4 },
		beer = { item = 'beer', category = 'alcohol', price = 8 },
		whiskey = { item = 'whiskey', category = 'alcohol', price = 35 },
		vodka = { item = 'vodka', category = 'alcohol', price = 30 },
		cigarettes = { item = 'cigarettes_redwood', category = 'tobacco', price = 18 },
		bandage = { item = 'bandage', category = 'health', price = 25 },
		painkillers = { item = 'painkillers', category = 'health', price = 20 },
		phone = { item = 'phone', category = 'utility', price = 450 },
		radio = { item = 'radio', category = 'utility', price = 300 }
	},

	-- Tipos de loja: o que vendem, balconista, blip e categoria do negócio no coe_businesses.
	Types = {
		convenience = {
			label = 'Loja de conveniência', category = 'shop', clerk = 'mp_m_shopkeep_01', blip = { sprite = 52, color = 2 },
			products = { 'water', 'sprunk', 'ecola', 'coffee', 'energy_drink', 'sandwich', 'chips', 'chocolate', 'cereal_bar', 'donut',
				'beer', 'cigarettes', 'bandage', 'painkillers', 'phone', 'radio' }
		},
		-- LTD: loja dentro do posto. O negócio é o posto (categoria gas_station); as bombas entram na fase 2.
		ltd = {
			label = 'LTD Gasoline', category = 'gas_station', clerk = 'mp_m_shopkeep_01', blip = false, -- o blip é o do posto (coe_fuel)
			products = { 'water', 'sprunk', 'ecola', 'coffee', 'energy_drink', 'sandwich', 'chips', 'chocolate', 'cereal_bar', 'donut',
				'beer', 'cigarettes', 'bandage', 'painkillers', 'radio' }
		},
		liquor = {
			label = "Rob's Liquor", category = 'shop', clerk = 'mp_m_shopkeep_01', blip = { sprite = 93, color = 27 },
			products = { 'beer', 'whiskey', 'vodka', 'cigarettes', 'water', 'ecola', 'sprunk', 'chips', 'chocolate' }
		}
	},

	-- Lojas: id do negócio, nome e o balconista ({ x, y, z, h }). Criadas no coe_businesses na primeira vez (sem dono).
	Stores = {
		{ id = 'shop_247_strawberry', label = '24/7 Strawberry', type = 'convenience', clerk = { 24.47, -1346.62, 29.50, 271.66 } },
		{ id = 'shop_247_vinewood', label = '24/7 Clinton Ave', type = 'convenience', clerk = { 372.66, 326.98, 103.57, 253.73 } },
		{ id = 'shop_247_tataviam', label = '24/7 Tataviam', type = 'convenience', clerk = { 2556.66, 380.84, 108.62, 356.67 } },
		{ id = 'shop_247_chumash', label = '24/7 Chumash', type = 'convenience', clerk = { -3039.54, 584.38, 7.91, 17.27 } },
		{ id = 'shop_247_banham', label = '24/7 Banham Canyon', type = 'convenience', clerk = { -3242.97, 1000.01, 12.83, 357.57 } },
		{ id = 'shop_247_harmony', label = '24/7 Harmony', type = 'convenience', clerk = { 549.13, 2670.85, 42.16, 99.39 } },
		{ id = 'shop_247_senora', label = '24/7 Grand Senora', type = 'convenience', clerk = { 2677.47, 3279.76, 55.24, 335.08 } },
		{ id = 'shop_247_sandy', label = '24/7 Sandy Shores', type = 'convenience', clerk = { 1959.82, 3740.48, 32.34, 301.57 } },
		{ id = 'shop_247_paleto', label = '24/7 Paleto Bay', type = 'convenience', clerk = { 1728.07, 6416.63, 35.04, 247.45 } },
		{ id = 'ltd_grove', label = 'LTD Grove Street', type = 'ltd', clerk = { -47.02, -1758.23, 29.42, 45.05 } },
		{ id = 'ltd_little_seoul', label = 'LTD Little Seoul', type = 'ltd', clerk = { -706.06, -913.97, 19.22, 88.04 } },
		{ id = 'ltd_richman', label = 'LTD Richman Glen', type = 'ltd', clerk = { -1820.02, 794.03, 138.09, 135.45 } },
		{ id = 'ltd_mirror_park', label = 'LTD Mirror Park', type = 'ltd', clerk = { 1164.71, -322.94, 69.21, 101.72 } },
		{ id = 'ltd_grapeseed', label = 'LTD Grapeseed', type = 'ltd', clerk = { 1697.87, 4922.96, 42.06, 324.71 } },
		{ id = 'robs_vespucci', label = "Rob's Liquor Vespucci", type = 'liquor', clerk = { -1221.58, -908.15, 12.33, 35.49 } },
		{ id = 'robs_morningwood', label = "Rob's Liquor Morningwood", type = 'liquor', clerk = { -1486.59, -377.68, 40.16, 139.51 } },
		{ id = 'robs_great_ocean', label = "Rob's Liquor Great Ocean", type = 'liquor', clerk = { -2966.39, 391.42, 15.04, 87.48 } },
		{ id = 'robs_route68', label = "Rob's Liquor Route 68", type = 'liquor', clerk = { 1165.17, 2710.88, 38.16, 179.43 } },
		{ id = 'robs_murrieta', label = "Rob's Liquor Murrieta", type = 'liquor', clerk = { 1134.20, -982.91, 46.42, 277.24 } }
	}
}
