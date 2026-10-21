-- Pescador (coleta): pesca na ponta do píer de Del Perro e vende os peixes no restaurante da entrada do píer.
-- Coordenadas provisórias: confira no jogo e ajuste (o centro é o NPC; `nodes` são os pontos de pesca; `sell` o comprador).
JobsCatalog[#JobsCatalog + 1] = {
	id = 'fisher',
	label = 'Pescador',
	description = 'Pesque no píer de Del Perro e venda os peixes no restaurante.',
	kind = 'gather',
	center = { -1806.5, -1196.0, 13.0, 50.0 },
	centerPed = 's_m_m_cntrybar_01',
	blip = { sprite = 68, color = 3 },
	levels = { 0, 150, 450, 1000, 2000 },
	levelBonus = 0.05,
	skills = { 'outdoor' },
	-- Dicas extras do guia "Como funciona" (o passo a passo sai da própria definição).
	tips = {
		'O restaurante que compra os peixes fica na entrada do píer.',
		'Pescar treina Campo, que deixa as ações de coleta mais rápidas em todos os empregos.'
	},
	gather = {
		actionLabel = 'Pescar',
		-- Balde de isca marcando o ponto (o cenário de pesca já põe a vara na mão).
		nodeProp = 'prop_bucket_02a',
		nodes = {
			{ -1838.4, -1268.0, 8.6, 140.0 }, { -1846.0, -1259.6, 8.6, 140.0 }, { -1853.1, -1251.2, 8.6, 140.0 },
			{ -1860.5, -1242.4, 8.6, 230.0 }, { -1829.6, -1275.4, 8.6, 140.0 }, { -1820.7, -1282.9, 8.6, 50.0 },
			{ -1867.2, -1233.9, 8.6, 230.0 }, { -1812.0, -1290.5, 8.6, 50.0 }
		},
		seconds = 15,
		yield = { 1, 1 },
		capacity = 15,
		nodeCooldown = 60,
		xp = 4,
		unit = 'peixe',
		units = 'peixes',
		animation = { scenario = 'WORLD_HUMAN_STAND_FISHING' },
		sell = {
			label = 'Vender peixes',
			ped = 's_m_y_chef_01',
			price = 25,
			points = { { -1834.5, -1190.6, 14.3, 330.0 } }
		}
	}
}
