-- Fazendeiro (coleta): colhe em vários campos (repolho, abóbora e milho em Grapeseed, laranja no pomar e uva no
-- vinhedo Marlowe) e vende a colheita no mercado de Grapeseed ou na vinícola. Cada produto tem o seu preço.
-- Campos em grade (`fields`): origem = primeiro pé, `heading` = direção da fileira, `rows` x `cols` e espaçamento.
-- Com `soil`, só nascem pés em chão de terra (o client confere o material): pontos que caírem na estrada ou na
-- grama somem sozinhos. Coordenadas provisórias: confira no jogo e ajuste a origem/heading de cada campo.
JobsCatalog[#JobsCatalog + 1] = {
	id = 'farmer',
	label = 'Fazendeiro',
	description = 'Colha repolho, abóbora, milho, laranja e uva e venda no mercado ou na vinícola.',
	kind = 'gather',
	center = { 2016.2, 4987.6, 42.1, 135.0 },
	centerPed = 'a_m_m_farmer_01',
	blip = { sprite = 285, color = 52 },
	levels = { 0, 150, 450, 1000, 2000 },
	levelBonus = 0.05,
	skills = { 'outdoor', 'strength' },
	-- Dicas extras do guia "Como funciona" (o passo a passo sai da própria definição).
	tips = {
		'Cada campo tem o seu produto e preço: abóbora vale mais, milho sai mais rápido.',
		'O mercado de Grapeseed compra tudo; a vinícola Marlowe também compra, perto do vinhedo.',
		'Colher treina Força: com Força 2 você pode trabalhar de mineiro.'
	},
	-- Uniforme opcional (só visual): macacão e botas de trabalho. Valores provisórios: confira no jogo.
	uniform = {
		label = 'Macacão de fazendeiro',
		male = { components = { [3] = { 0, 0 }, [4] = { 43, 0 }, [6] = { 25, 0 }, [8] = { 15, 0 }, [11] = { 97, 0 } }, props = { [0] = { 20, 0 } } },
		female = { components = { [3] = { 0, 0 }, [4] = { 45, 0 }, [6] = { 25, 0 }, [8] = { 14, 0 }, [11] = { 88, 0 } }, props = { [0] = { 20, 0 } } }
	},
	gather = {
		actionLabel = 'Colher',
		seconds = 5,
		yield = { 2, 3 },
		capacity = 40,
		nodeCooldown = 180,
		xp = 3,
		unit = 'item',
		units = 'itens',
		soil = true,
		order = { 'repolho', 'abobora', 'milho', 'laranja', 'uva' },
		products = {
			repolho = {
				label = 'Repolho', unit = 'repolho', units = 'repolhos', price = 8, actionLabel = 'Colher repolho',
				prop = 'prop_veg_crop_03_cab', seconds = 5, yield = { 2, 3 },
				animation = { dict = 'amb@world_human_gardener_plant@male@base', name = 'base', flag = 1 }
			},
			abobora = {
				label = 'Abóbora', unit = 'abóbora', units = 'abóboras', price = 16, actionLabel = 'Colher abóbora',
				prop = 'prop_veg_crop_03_pump', seconds = 6, yield = { 1, 2 }, xp = 4,
				animation = { dict = 'amb@world_human_gardener_plant@male@base', name = 'base', flag = 1 }
			},
			milho = {
				label = 'Milho', unit = 'espiga', units = 'espigas', price = 5, actionLabel = 'Colher milho',
				prop = { 'prop_veg_corn_01', 'prop_plant_cane_01a', 'prop_veg_crop_03_cab' }, seconds = 4, yield = { 3, 4 },
				animation = { dict = 'amb@prop_human_movie_bulb@base', name = 'base', flag = 1 }
			},
			laranja = {
				label = 'Laranja', unit = 'laranja', units = 'laranjas', price = 4, actionLabel = 'Colher laranjas',
				prop = 'prop_veg_crop_orange', seconds = 5, yield = { 4, 5 }, cooldown = 240,
				animation = { dict = 'amb@prop_human_movie_bulb@base', name = 'base', flag = 1 }
			},
			uva = {
				label = 'Uva', unit = 'cacho', units = 'cachos', price = 7, actionLabel = 'Colher uvas',
				prop = { 'prop_bush_med_03', 'prop_veg_crop_04_leaf', 'prop_veg_crop_03_cab' }, seconds = 4, yield = { 2, 3 },
				animation = { dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', name = 'machinic_loop_mechandplayer', flag = 1 }
			}
		},
		fields = {
			-- Repolho: o campo de sempre, mais denso e recolhido para dentro do plantio.
			{ product = 'repolho', label = 'Campo de repolho', origin = { 2030.4, 4936.6, 41.1 }, heading = 225.0, rows = 5, cols = 5, spacing = 5.4 },
			{ product = 'abobora', label = 'Canteiro de abóbora', origin = { 2009.2, 4915.4, 41.1 }, heading = 225.0, rows = 3, cols = 5, spacing = 5.0 },
			{ product = 'milho', label = 'Milharal', origin = { 2051.6, 4915.4, 41.1 }, heading = 225.0, rows = 4, cols = 5, spacing = 3.5 },
			-- Pomar em gramado: sem filtro de terra.
			{ product = 'laranja', label = 'Pomar de laranja', origin = { 2068.0, 4962.0, 41.1 }, heading = 225.0, rows = 3, cols = 4, spacing = 7.0, soil = false },
			{ product = 'uva', label = 'Vinhedo Marlowe', origin = { -1860.0, 2140.0, 130.0 }, heading = 150.0, rows = 3, cols = 6, spacing = 3.0, rowSpacing = 6.0 }
		},
		sell = {
			label = 'Vender colheita',
			ped = 'a_m_m_hillbilly_01',
			points = { { 1702.6, 4917.3, 42.1, 55.0 }, { -1887.6, 2049.4, 140.9, 160.0 } }
		}
	}
}
