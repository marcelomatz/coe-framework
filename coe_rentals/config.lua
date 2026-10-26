RentalsConfig = {
	Locale = 'pt-BR',

	-- Catálogo de veículos para aluguel inicial
	-- price: custo do serviço (não reembolsável)
	-- deposit: caução devolvido integralmente quando o veículo é devolvido em qualquer ponto
	Vehicles = {
		{ model = 'tribike', label = 'Bicicleta Tri-Bike', category = 'bike', price = 25, deposit = 15 },
		{ model = 'faggio', label = 'Scooter Faggio', category = 'moto', price = 70, deposit = 50 },
		{ model = 'panto', label = 'Compacto Panto', category = 'carro', price = 140, deposit = 90 },
		{ model = 'blista', label = 'Hatch Blista', category = 'carro', price = 220, deposit = 130 }
	},

	-- Estações de aluguel e devolução espalhadas pelo mapa
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
