-- Mineiro (coleta): quebra rochas na pedreira Davis Quartz com a picareta e vende o minério no escritório.
-- Exige Força nível 2 (vem do lenhador, do fazendeiro ou do lixeiro) e paga mais que os empregos de entrada.
-- Coordenadas provisórias: confira no jogo e ajuste (o centro é o NPC; `nodes` são as rochas; `sell` o comprador).
JobsCatalog[#JobsCatalog + 1] = {
	id = 'miner',
	label = 'Mineiro',
	description = 'Quebre rochas na pedreira Davis Quartz e venda o minério. Precisa de Força nível 2.',
	kind = 'gather',
	center = { 2944.0, 2746.0, 43.4, 290.0 },
	centerPed = 's_m_y_construct_02',
	blip = { sprite = 618, color = 47 },
	levels = { 0, 150, 450, 1000, 2000 },
	levelBonus = 0.05,
	skills = { 'strength', 'outdoor' },
	-- Dicas extras do guia "Como funciona" (o passo a passo sai da própria definição).
	tips = {
		'O comprador fica no escritório da pedreira.',
		'Força aumenta quanto minério você carrega por viagem.'
	},
	-- Histórico pedido: força de outro emprego braçal.
	requires = { skills = { strength = 2 } },
	tool = { model = 'prop_tool_pickaxe', bone = 57005, offset = { 0.09, -0.53, -0.22 }, rotation = { 252.0, 180.0, 0.0 } },
	gather = {
		actionLabel = 'Quebrar rocha',
		nodeProp = 'prop_rock_1_d',
		nodes = {
			{ 2954.6, 2778.3, 41.3 }, { 2967.9, 2774.6, 40.1 }, { 2979.4, 2787.0, 39.8 }, { 2992.1, 2775.9, 42.6 },
			{ 2970.8, 2797.4, 41.0 }, { 2957.3, 2805.8, 41.9 }, { 2944.5, 2795.3, 40.6 }, { 2933.9, 2785.0, 39.5 },
			{ 2939.0, 2812.6, 42.8 }, { 2985.6, 2806.1, 43.4 }
		},
		seconds = 8,
		yield = { 1, 2 },
		capacity = 20,
		nodeCooldown = 150,
		xp = 4,
		unit = 'minério',
		units = 'minérios',
		animation = { dict = 'melee@large_wpn@streamed_core', name = 'ground_attack_on_spot', flag = 1 },
		sell = {
			label = 'Vender minério',
			ped = 's_m_m_gaffer_01',
			price = 20,
			points = { { 2903.2, 2741.0, 44.0, 200.0 } }
		}
	}
}
