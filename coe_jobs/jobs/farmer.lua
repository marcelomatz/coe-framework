-- Fazendeiro (coleta): colhe repolhos na plantação de Grapeseed e vende a colheita no mercado da cidade.
-- Coordenadas provisórias: confira no jogo e ajuste (o centro é o NPC; `nodes` são os pés; `sell` o comprador).
JobsCatalog[#JobsCatalog + 1] = {
	id = 'farmer',
	label = 'Fazendeiro',
	description = 'Colha na plantação de Grapeseed e venda no mercado.',
	kind = 'gather',
	center = { 2016.2, 4987.6, 42.1, 135.0 },
	centerPed = 'a_m_m_farmer_01',
	blip = { sprite = 285, color = 52 },
	levels = { 0, 150, 450, 1000, 2000 },
	levelBonus = 0.05,
	skills = { 'outdoor', 'strength' },
	-- Dicas extras do guia "Como funciona" (o passo a passo sai da própria definição).
	tips = {
		'O mercado fica no centro de Grapeseed, a oeste da plantação.',
		'Colher treina Força: com Força 2 você pode trabalhar de mineiro.'
	},
	gather = {
		actionLabel = 'Colher',
		nodeProp = 'prop_veg_crop_03_cab',
		nodes = {
			{ 2030.4, 4940.1, 41.1 }, { 2036.5, 4934.0, 41.1 }, { 2042.6, 4927.9, 41.1 }, { 2048.7, 4921.8, 41.1 },
			{ 2024.3, 4933.9, 41.1 }, { 2030.4, 4927.8, 41.1 }, { 2036.5, 4921.7, 41.1 }, { 2042.6, 4915.6, 41.1 },
			{ 2018.2, 4927.7, 41.1 }, { 2024.3, 4921.6, 41.1 }, { 2030.4, 4915.5, 41.1 }, { 2036.5, 4909.4, 41.1 },
			{ 2012.1, 4921.5, 41.1 }, { 2018.2, 4915.4, 41.1 }, { 2024.3, 4909.3, 41.1 }, { 2030.4, 4903.2, 41.1 }
		},
		seconds = 6,
		yield = { 2, 3 },
		capacity = 40,
		nodeCooldown = 180,
		xp = 3,
		unit = 'repolho',
		units = 'repolhos',
		animation = { scenario = 'WORLD_HUMAN_GARDENER_PLANT' },
		sell = {
			label = 'Vender colheita',
			ped = 'a_m_m_hillbilly_01',
			price = 8,
			points = { { 1702.6, 4917.3, 42.1, 55.0 } }
		}
	}
}
