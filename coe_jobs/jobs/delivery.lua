-- Entregador (rota): pega a van da GoPostal e entrega encomendas de porta em porta em Mirror Park.
-- Coordenadas provisórias: confira no jogo e ajuste (o centro é o NPC; `spawn` a vaga da van; `stops` as portas).
JobsCatalog[#JobsCatalog + 1] = {
	id = 'delivery',
	label = 'Entregador',
	description = 'Entregue encomendas da GoPostal com a van da empresa.',
	kind = 'route',
	center = { 78.8, 111.9, 81.2, 160.0 },
	centerPed = 's_m_m_postal_01',
	blip = { sprite = 478, color = 5 },
	levels = { 0, 150, 450, 1000, 2000 },
	levelBonus = 0.05,
	-- Habilidades que este emprego treina (valem nos outros empregos que as usam).
	skills = { 'driving', 'logistics' },
	-- Dicas extras do guia "Como funciona" (o passo a passo sai da própria definição).
	tips = {
		'Estacione perto da porta: o veículo precisa estar a menos de 45 m da parada.',
		'Entregar treina Direção, exigida pelo caminhoneiro.'
	},
	-- Van da empresa: depósito devolvido ao encerrar com ela de volta no pátio.
	vehicle = { model = 'boxville2', plate = 'POST', spawn = { 66.0, 120.0, 79.1, 160.0 }, deposit = 300, returnRadius = 40.0 },
	route = {
		actionLabel = 'Entregar encomenda',
		pickupLabel = 'Pegar encomenda',
		perRoute = 6,
		pay = 45,
		bonus = 120,
		xp = 8,
		vehicleRange = 45.0,
		carry = { model = 'prop_cs_cardbox_01', bone = 28422, offset = { 0.0, -0.03, -0.12 }, rotation = { 0.0, 0.0, 0.0 } },
		carryAnimation = { dict = 'anim@heists@box_carry@', name = 'idle', flag = 49 },
		recipients = { 'a_m_y_hipster_01', 'a_f_y_hipster_02', 'a_m_m_bevhills_01', 'a_f_y_business_02', 'a_m_y_business_01' },
		stops = {
			{ 1060.6, -378.6, 68.2 }, { 1029.2, -409.0, 65.9 }, { 1010.3, -423.4, 65.3 }, { 987.9, -433.0, 63.7 },
			{ 967.4, -451.6, 62.4 }, { 944.5, -463.2, 61.5 }, { 921.9, -478.0, 61.1 }, { 906.4, -489.6, 59.4 },
			{ 878.9, -498.4, 58.0 }, { 850.3, -532.6, 57.9 }, { 861.6, -583.4, 58.2 }, { 886.7, -608.2, 58.4 },
			{ 903.3, -615.5, 58.5 }, { 928.9, -639.4, 58.2 }
		}
	}
}
