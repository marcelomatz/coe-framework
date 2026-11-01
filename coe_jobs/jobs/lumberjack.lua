-- Lenhador (coleta com transporte e beneficiamento): pega a pickup da madeireira, derruba árvores do próprio mapa
-- na floresta de Paleto (a árvore tomba e some para todos até rebrotar), leva as toras uma por uma até a caçamba,
-- volta à madeireira, desdobra as toras em tábuas na serra e vende as tábuas no comprador.
-- Coordenadas provisórias: confira no jogo e ajuste (o centro é o NPC; `world.area` a floresta; `process` a serra).
JobsCatalog[#JobsCatalog + 1] = {
	id = 'lumberjack',
	label = 'Lenhador',
	description = 'Derrube árvores na floresta de Paleto, leve as toras na pickup e desdobre-as em tábuas na madeireira.',
	kind = 'gather',
	center = { -570.9, 5251.5, 70.5, 65.0 },
	centerPed = 's_m_y_construct_01',
	blip = { sprite = 85, color = 25 },
	levels = { 0, 150, 450, 1000, 2000 },
	levelBonus = 0.05,
	-- Habilidades que este emprego treina (valem nos outros empregos que as usam).
	skills = { 'strength', 'outdoor' },
	-- Dicas extras do guia "Como funciona" (o passo a passo sai da própria definição).
	tips = {
		'Qualquer árvore da área da floresta serve; a árvore derrubada rebrota em 15 minutos.',
		'Carregue todas as toras do chão antes de derrubar a próxima árvore.',
		'Cada tora vira 4 tábuas na serra. Toras não se vendem: desdobre antes.',
		'Força aumenta quantas toras cabem na caçamba.'
	},
	-- Uniforme opcional: camisa xadrez, calça de trabalho e capacete. Valores provisórios: confira no jogo.
	uniform = {
		label = 'Roupa de lenhador',
		male = { components = { [3] = { 1, 0 }, [4] = { 43, 0 }, [6] = { 25, 0 }, [8] = { 15, 0 }, [11] = { 128, 0 } }, props = { [0] = { 145, 0 } } },
		female = { components = { [3] = { 3, 0 }, [4] = { 45, 0 }, [6] = { 25, 0 }, [8] = { 14, 0 }, [11] = { 124, 0 } }, props = { [0] = { 144, 0 } } }
	},
	-- Pickup da madeireira: depósito devolvido ao encerrar com ela de volta no pátio.
	vehicle = { model = 'bison', plate = 'MADE', spawn = { -575.6, 5240.2, 70.5, 155.0 }, deposit = 350, returnRadius = 45.0 },
	-- Machado na mão direita durante o corte (só visual; o pacote não usa item do inventário).
	tool = { model = 'prop_w_me_hatchet', bone = 57005, offset = { 0.10, 0.02, -0.02 }, rotation = { -90.0, 0.0, 0.0 } },
	gather = {
		actionLabel = 'Derrubar árvore',
		-- Golpes de machado no tronco na altura do peito.
		animation = { dict = 'amb@world_human_hammering@male@base', name = 'base', flag = 1 },
		seconds = 10,
		yield = { 2, 3 },
		capacity = 8,
		xp = 6,
		unit = 'tora',
		units = 'toras',
		order = { 'tabua', 'tora' },
		products = {
			-- Tora: o que sai da árvore (vai na caçamba, sem preço: precisa ser desdobrada).
			tora = { label = 'Tora', unit = 'tora', units = 'toras', price = 0, yield = { 2, 3 }, seconds = 10, xp = 6, actionLabel = 'Derrubar árvore' },
			-- Tábua: o produto da serra, o que paga.
			tabua = { label = 'Tábua', unit = 'tábua', units = 'tábuas', price = 7, xp = 4 }
		},
		-- Árvores do mapa dentro da floresta (qualquer um destes modelos). Modelo que não existir é ignorado.
		world = {
			{
				product = 'tora', fell = true, cooldown = 900,
				area = { -530.0, 5440.0, 72.0, radius = 120.0, label = 'Floresta de Paleto' },
				models = {
					'prop_tree_pine_01', 'prop_tree_pine_02', 'prop_tree_cedar_02', 'prop_tree_cedar_03', 'prop_tree_cedar_04',
					'prop_tree_cedar_s_01', 'prop_tree_cedar_s_02', 'prop_tree_cedar_s_04', 'prop_tree_cedar_s_05', 'prop_tree_cedar_s_06',
					'prop_tree_oak_01', 'prop_tree_eng_oak_01', 'prop_tree_birch_01', 'prop_tree_birch_02', 'prop_tree_birch_03',
					'prop_tree_birch_03b', 'prop_tree_birch_04', 'prop_tree_maple_02', 'prop_tree_maple_03', 'prop_s_pine_dead_01',
					'test_tree_cedar_trunk_001', 'test_tree_forest_trunk_01', 'test_tree_forest_trunk_02', 'test_tree_forest_trunk_03',
					'test_tree_forest_trunk_04', 'test_tree_forest_trunk_base_01'
				}
			}
		},
		-- Transporte: as toras caem ao lado do tronco; o jogador leva uma por vez nos braços até a caçamba.
		haul = {
			capacity = 8,
			takeLabel = 'Pegar tora',
			loadLabel = 'Colocar tora na caçamba',
			groundProp = { 'prop_log_break_01', 'prop_log_02', 'prop_log_01' },
			carry = { model = 'prop_log_break_01', fallback = 'prop_log_02', bone = 60309, offset = { 0.05, 0.10, 0.25 }, rotation = { -145.0, 290.0, 0.0 } },
			carryAnimation = { dict = 'anim@heists@box_carry@', name = 'idle', flag = 49 },
			-- Toras deitadas na caçamba da Bison (offsets do veículo: x lateral, y frente/trás, z altura, rotação).
			rack = {
				model = { 'prop_log_break_01', 'prop_log_02', 'prop_log_01' },
				slots = {
					{ -0.45, -1.75, 0.35, 0.0, 0.0, 90.0 }, { -0.15, -1.75, 0.35, 0.0, 0.0, 90.0 },
					{ 0.15, -1.75, 0.35, 0.0, 0.0, 90.0 }, { 0.45, -1.75, 0.35, 0.0, 0.0, 90.0 },
					{ -0.30, -1.75, 0.62, 0.0, 0.0, 90.0 }, { 0.0, -1.75, 0.62, 0.0, 0.0, 90.0 },
					{ 0.30, -1.75, 0.62, 0.0, 0.0, 90.0 }, { -0.15, -1.75, 0.88, 0.0, 0.0, 90.0 },
					{ 0.15, -1.75, 0.88, 0.0, 0.0, 90.0 }, { 0.0, -1.75, 1.12, 0.0, 0.0, 90.0 }
				}
			}
		},
		-- Serra da madeireira: com a pickup por perto, desdobra toda a caçamba (3 s por tora, até 24 s).
		process = {
			label = 'Desdobrar toras',
			product = 'tabua',
			ratio = 4,
			seconds = 3,
			maxSeconds = 24,
			vehicleRange = 25.0,
			prop = { 'prop_tool_bench02', 'prop_tool_bench02_ld' },
			animation = { dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', name = 'machinic_loop_mechandplayer', flag = 1 },
			points = { { -563.4, 5287.6, 70.2, 70.0 } }
		},
		sell = {
			label = 'Vender tábuas',
			ped = 's_m_m_cntrybar_01',
			points = { { -584.5, 5290.0, 70.3, 340.0 } }
		}
	}
}
