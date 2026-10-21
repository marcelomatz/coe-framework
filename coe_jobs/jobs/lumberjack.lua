-- Lenhador (coleta): corta árvores na floresta de Paleto com o machado e vende as toras na serraria.
-- Coordenadas provisórias: confira no jogo e ajuste (o centro é o NPC; `nodes` são as árvores; `sell` o comprador).
JobsCatalog[#JobsCatalog + 1] = {
	id = 'lumberjack',
	label = 'Lenhador',
	description = 'Corte árvores na floresta de Paleto e venda as toras na serraria.',
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
		'A serraria fica ao lado do responsável: venda sempre que encher as 24 toras.',
		'Cortar árvores treina Força e Campo, que ajudam no mineiro e no fazendeiro.'
	},
	-- Machado na mão durante o corte (só visual; o pacote não usa item do inventário).
	tool = { model = 'prop_w_me_hatchet', bone = 57005, offset = { 0.13, 0.02, -0.02 }, rotation = { -80.0, 0.0, 0.0 } },
	gather = {
		actionLabel = 'Cortar árvore',
		nodeProp = 'prop_tree_stump_01',
		nodes = {
			{ -501.4, 5394.5, 75.1 }, { -484.3, 5413.7, 77.2 }, { -522.0, 5427.8, 72.3 }, { -541.9, 5441.0, 69.9 },
			{ -470.6, 5453.8, 80.4 }, { -455.0, 5432.0, 81.0 }, { -510.8, 5468.2, 74.6 }, { -535.6, 5480.4, 70.8 },
			{ -563.2, 5462.9, 64.9 }, { -588.4, 5440.7, 60.1 }, { -605.8, 5413.2, 57.8 }, { -579.9, 5392.6, 62.3 }
		},
		seconds = 7,
		yield = { 1, 2 },
		capacity = 24,
		nodeCooldown = 120,
		xp = 3,
		unit = 'tora',
		units = 'toras',
		animation = { dict = 'melee@large_wpn@streamed_core', name = 'ground_attack_on_spot', flag = 1 },
		sell = {
			label = 'Vender toras',
			ped = 's_m_m_cntrybar_01',
			price = 12,
			points = { { -584.5, 5290.0, 70.3, 340.0 } }
		}
	}
}
