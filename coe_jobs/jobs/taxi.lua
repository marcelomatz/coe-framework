-- Taxista (rota de passageiros): pega o táxi na Downtown Cab Co., para no ponto, o passageiro embarca sozinho e a
-- corrida paga pela distância até o destino. Exige carreira nível 2 (qualquer histórico nos outros empregos).
-- Coordenadas provisórias: confira no jogo e ajuste (o centro é o NPC; `spawn` a vaga; `stops` os pontos).
JobsCatalog[#JobsCatalog + 1] = {
	id = 'taxi',
	label = 'Taxista',
	description = 'Leve passageiros pela cidade com o táxi da Downtown Cab Co. Precisa de carreira nível 2.',
	kind = 'route',
	center = { 895.4, -179.3, 74.7, 240.0 },
	centerPed = 's_m_m_gentransport',
	blip = { sprite = 198, color = 5 },
	levels = { 0, 150, 450, 1000, 2000 },
	levelBonus = 0.05,
	skills = { 'driving', 'logistics' },
	-- Dicas extras do guia "Como funciona" (o passo a passo sai da própria definição).
	tips = {
		'Pare bem perto do passageiro e espere: ele embarca sozinho.',
		'Corridas longas pagam mais: o valor cresce a cada km.'
	},
	requires = { career = 2 },
	vehicle = { model = 'taxi', plate = 'TAXI', spawn = { 909.1, -177.0, 74.2, 238.0 }, deposit = 250, returnRadius = 40.0 },
	route = {
		-- passenger: embarque na parada e desembarque na seguinte, com o táxi parado e o jogador ao volante.
		mode = 'passenger',
		perRoute = 4,
		pay = 30,
		payPerKm = 70,
		bonus = 100,
		xp = 10,
		stopRadius = 12.0,
		vehicleRange = 15.0,
		recipients = { 'a_m_y_business_02', 'a_f_y_business_01', 'a_m_m_tourist_01', 'a_f_y_tourist_02', 'a_m_y_hipster_02', 'a_f_m_bevhills_01' },
		stops = {
			{ -260.6, -900.2, 31.1 }, { 240.5, -860.1, 29.7 }, { -1035.4, -2730.6, 20.2 }, { -560.3, -1100.8, 22.2 },
			{ 110.6, -1090.2, 29.2 }, { -1370.4, -480.6, 33.2 }, { 300.2, -230.5, 54.0 }, { -620.4, 30.1, 43.2 },
			{ -1460.3, -280.6, 46.4 }, { 1150.4, -460.2, 66.7 }, { -30.6, -110.3, 57.0 }, { 420.1, -980.4, 29.4 },
			{ -710.2, -920.5, 19.2 }, { -1220.6, -1440.3, 4.3 }
		}
	}
}
