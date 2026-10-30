RentalsConfig = {
	Locale = 'pt-BR',

	-- Distância máxima (m) entre o jogador e o balcão (coords) para alugar, ou a returnZone para devolver.
	InteractRadius = 6.0,
	-- Intervalo mínimo entre pedidos de aluguel/devolução do mesmo jogador (ms).
	CooldownMs = 2000,
	-- Devolver no balcão: o veículo alugado precisa estar a até esta distância (m) do atendente, da zona de
	-- devolução ou de um ponto de retirada da estação.
	CounterReturnDistance = 40.0,
	-- Ponto de retirada ocupado: algum veículo a menos desta distância (m). O aluguel usa o próximo livre.
	SpawnClearance = 2.5,
	Limits = { MaxSpawns = 8 },

	-- Quem edita as estações pelos exports. O painel do framework (coe_staff) usa o provedor; painéis de pacotes
	-- e scripts de terceiros recebem a ACE no server.cfg: add_ace resource.<nome> coe.rentals.admin allow
	AdminAce = 'coe.rentals.admin',
	AdminResources = { coe_staff = true },

	-- Atendente (NPC) no balcão de cada estação (coords). A estação pode trocar com ped = { model, h }.
	-- Só existe no client e só perto da estação (SpawnDistance).
	Ped = {
		Model = 'a_m_y_business_02',
		SpawnDistance = 60.0
	},

	-- Catálogo de veículos para aluguel inicial
	-- price: custo do serviço (não reembolsável)
	-- deposit: caução devolvido integralmente quando o veículo é devolvido em qualquer ponto
	Vehicles = {
		{ model = 'tribike', label = 'Bicicleta Tri-Bike', category = 'bike', price = 25, deposit = 15 },
		{ model = 'faggio', label = 'Scooter Faggio', category = 'moto', price = 70, deposit = 50 },
		{ model = 'panto', label = 'Compacto Panto', category = 'carro', price = 140, deposit = 90 },
		{ model = 'blista', label = 'Hatch Blista', category = 'carro', price = 220, deposit = 130 }
	},

	-- Estações iniciais: só semeiam o banco na primeira vez (depois o painel da staff edita as estações).
	-- coords = balcão/atendente, spawn = ponto de retirada, returnZone = zona de devolução.
	-- Opcional por estação: vehicles = { 'tribike', 'faggio' } limita o catálogo oferecido ali.
	Stations = {
		{
			id = 'pink_cage',
			label = 'Aluguel Pink Cage (Hotel)',
			coords = { x = 328.0, y = -218.0, z = 54.0 },
			spawn = { x = 323.5, y = -226.5, z = 54.0, h = 160.0 },
			returnZone = { x = 323.5, y = -226.5, z = 54.0, radius = 5.0 },
			blip = { enabled = true, sprite = 226, color = 3, scale = 0.7 }
		},
		{
			id = 'legion_square',
			label = 'Aluguel Praça Central',
			coords = { x = 219.0, y = -810.0, z = 30.8 },
			spawn = { x = 214.5, y = -815.0, z = 30.8, h = 250.0 },
			returnZone = { x = 214.5, y = -815.0, z = 30.8, radius = 5.0 },
			blip = { enabled = true, sprite = 226, color = 3, scale = 0.7 }
		},
		{
			id = 'sandy_shores',
			label = 'Aluguel Sandy Shores',
			coords = { x = 1978.0, y = 3778.0, z = 32.2 },
			spawn = { x = 1974.0, y = 3782.0, z = 32.2, h = 120.0 },
			returnZone = { x = 1974.0, y = 3782.0, z = 32.2, radius = 5.0 },
			blip = { enabled = true, sprite = 226, color = 3, scale = 0.7 }
		}
	}
}
