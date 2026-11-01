-- Caminhoneiro (rota longa): pega o caminhão no porto de Los Santos e entrega carga em armazéns pelo estado; paga
-- por km rodado. Exige Direção nível 2 (do entregador, lixeiro ou taxista) e reputação não negativa.
-- Coordenadas provisórias: confira no jogo e ajuste (o centro é o NPC; `spawn` a vaga; `stops` as docas).
JobsCatalog[#JobsCatalog + 1] = {
	id = 'trucker',
	label = 'Caminhoneiro',
	description = 'Leve carga do porto até armazéns pelo estado. Precisa de Direção nível 2 e reputação não negativa.',
	kind = 'route',
	center = { 1197.0, -3253.6, 7.1, 90.0 },
	centerPed = 's_m_m_trucker_01',
	blip = { sprite = 477, color = 21 },
	levels = { 0, 150, 450, 1000, 2000 },
	levelBonus = 0.05,
	skills = { 'driving', 'logistics' },
	-- Dicas extras do guia "Como funciona" (o passo a passo sai da própria definição).
	tips = {
		'As docas ficam longe: cada entrega paga pelos km rodados desde a anterior.',
		'Devolva o caminhão no porto para receber o depósito de volta.'
	},
	requires = { skills = { driving = 2 }, reputation = 0 },
	uniform = {
		label = 'Roupa de caminhoneiro',
		male = { components = { [3] = { 1, 0 }, [4] = { 4, 0 }, [6] = { 12, 0 }, [8] = { 15, 0 }, [11] = { 66, 0 } }, props = { [0] = { 58, 0 } } },
		female = { components = { [3] = { 3, 0 }, [4] = { 3, 0 }, [6] = { 4, 0 }, [8] = { 14, 0 }, [11] = { 60, 0 } }, props = { [0] = { 58, 0 } } }
	},
	vehicle = { model = 'mule3', plate = 'CARG', spawn = { 1179.6, -3239.6, 6.0, 90.0 }, deposit = 800, returnRadius = 50.0 },
	route = {
		actionLabel = 'Entregar a carga',
		pickupLabel = 'Pegar a carga',
		perRoute = 3,
		pay = 60,
		payPerKm = 35,
		bonus = 200,
		xp = 20,
		vehicleRange = 45.0,
		-- Caixa segurada com as duas mãos na frente do peito (osso da mão esquerda + andar de carga).
		carry = { model = 'prop_cs_cardbox_01', bone = 60309, offset = { 0.025, 0.08, 0.255 }, rotation = { -145.0, 290.0, 0.0 } },
		carryAnimation = { dict = 'anim@heists@box_carry@', name = 'idle', flag = 49 },
		recipients = { 's_m_y_dockwork_01', 's_m_m_dockwork_01', 's_m_y_construct_02', 's_m_m_gaffer_01' },
		stops = {
			{ 1736.0, 3290.4, 41.1 }, { 2550.2, 4680.6, 34.0 }, { -84.2, 6237.4, 31.1 }, { 546.4, 2665.0, 42.2 },
			{ 2680.4, 2800.2, 40.4 }, { 790.6, -2160.2, 29.3 }, { 1220.2, -1270.4, 35.3 }, { -3170.2, 1100.6, 20.8 },
			{ 1150.4, -480.0, 66.0 }, { 2580.6, 360.2, 108.5 }
		}
	}
}
