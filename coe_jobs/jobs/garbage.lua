-- Lixeiro (rota por zonas): pega o caminhão no pátio da limpeza urbana, vai até a área sorteada e recolhe o lixo de
-- qualquer lixeira, caçamba ou saco do mapa dentro dela; abre a caçamba na traseira do caminhão e joga o saco.
-- Completa a área com `perZone` sacos e segue para a próxima. Coordenadas provisórias: confira no jogo e ajuste.
JobsCatalog[#JobsCatalog + 1] = {
	id = 'garbage',
	label = 'Lixeiro',
	description = 'Recolha o lixo das lixeiras de cada bairro com o caminhão da limpeza urbana.',
	kind = 'route',
	center = { -321.7, -1545.7, 31.0, 0.0 },
	centerPed = 's_m_y_garbage',
	blip = { sprite = 318, color = 25 },
	levels = { 0, 150, 450, 1000, 2000 },
	levelBonus = 0.05,
	skills = { 'strength', 'driving' },
	-- Dicas extras do guia "Como funciona" (o passo a passo sai da própria definição).
	tips = {
		'Qualquer lixeira, caçamba ou saco de lixo da área serve; a mesma lixeira só enche de novo depois de 10 minutos.',
		'Na traseira do caminhão, abra a caçamba antes de jogar o saco.',
		'Recolher lixo treina Força e Direção ao mesmo tempo.'
	},
	vehicle = { model = 'trash', plate = 'LIXO', spawn = { -337.2, -1561.3, 25.2, 60.0 }, deposit = 400, returnRadius = 45.0 },
	route = {
		-- zone: área com raio; o jogador procura as lixeiras do mapa e guarda no caminhão (que precisa estar na área).
		mode = 'zone',
		actionLabel = 'Recolher o lixo',
		dropLabel = 'Jogar na caçamba',
		openLabel = 'Abrir a caçamba',
		closeLabel = 'Fechar a caçamba',
		rearDoor = 5,
		perRoute = 3,
		perZone = 6,
		pay = 28,
		bonus = 180,
		xp = 6,
		binCooldown = 600,
		carry = {
			model = 'prop_cs_rub_binbag_01', fallback = 'hei_prop_heist_binbag', bone = 57005,
			offset = { 0.12, 0.0, -0.05 }, rotation = { 220.0, 120.0, 0.0 }
		},
		carryAnimation = { dict = 'missfbi4prepp1', name = '_bag_walk_garbage_man', flag = 49 },
		-- Lixeiras, caçambas e sacos do mapa onde dá para recolher.
		binModels = {
			'prop_bin_01a', 'prop_bin_02a', 'prop_bin_03a', 'prop_bin_04a', 'prop_bin_05a', 'prop_bin_06a', 'prop_bin_07a',
			'prop_bin_07b', 'prop_bin_07c', 'prop_bin_07d', 'prop_bin_08a', 'prop_bin_08open', 'prop_bin_09a', 'prop_bin_10a',
			'prop_bin_10b', 'prop_bin_11a', 'prop_bin_11b', 'prop_bin_12a', 'prop_bin_13a', 'prop_bin_14a', 'prop_bin_14b',
			'prop_dumpster_01a', 'prop_dumpster_02a', 'prop_dumpster_02b', 'prop_dumpster_3a', 'prop_dumpster_4a', 'prop_dumpster_4b',
			'prop_rub_binbag_01', 'prop_rub_binbag_03', 'prop_rub_binbag_03b', 'prop_rub_binbag_04', 'prop_rub_binbag_05',
			'prop_rub_binbag_06', 'prop_rub_binbag_08', 'prop_rub_binbag_sd_01', 'prop_rub_binbag_sd_02', 'prop_cs_rub_binbag_01',
			'prop_cs_bin_01', 'prop_cs_bin_02', 'prop_cs_bin_03', 'prop_cs_dumpster_01a', 'p_dumpster_t', 'prop_snow_dumpster_01'
		},
		-- Áreas sorteadas a cada rota (centro e raio em metros).
		zones = {
			{ -238.0, -1500.0, 31.0, radius = 120.0, label = 'Strawberry' },
			{ 120.0, -1460.0, 29.0, radius = 130.0, label = 'Davis' },
			{ 330.0, -1600.0, 29.0, radius = 120.0, label = 'Rancho' },
			{ -60.0, -1300.0, 29.0, radius = 110.0, label = 'Little Bighorn' },
			{ 300.0, -1000.0, 29.0, radius = 120.0, label = 'Mission Row' },
			{ -700.0, -900.0, 19.0, radius = 130.0, label = 'Little Seoul' },
			{ 1150.0, -450.0, 66.0, radius = 140.0, label = 'Mirror Park' },
			{ -1150.0, -1450.0, 4.0, radius = 140.0, label = 'Vespucci' },
			{ 450.0, -1850.0, 27.0, radius = 120.0, label = 'Chamberlain Hills' },
			{ -1250.0, -900.0, 11.0, radius = 120.0, label = 'Del Perro' }
		}
	}
}
