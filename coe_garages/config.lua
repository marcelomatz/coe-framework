GaragesConfig = {
	-- Nível de garagem do jogador. Hoje todos começam no nível 1; os upgrades futuros só mudam o nível.
	DefaultLevel = 1,
	Levels = {
		[1] = { label = 'Garagem pequena', car = 1, bike = 1 }
	},

	-- Tipos do catálogo (coe_vehicle_catalog) que contam como moto; o resto conta como carro.
	BikeTypes = { bike = true },

	Limits = {
		MaxFleetPerBusiness = 30,
		MaxAccessPerVehicle = 20,
		MaxGarages = 100,
		MaxSpots = 8,
		MaxJobs = 5,
		MaxCoordinate = 10000.0,
		-- Folga, além do raio da vaga, para abrir a garagem ou guardar o veículo.
		StationReach = 3.0,
		ActionIntervalMs = 700
	},

	-- Tipos de garagem: public = veículos pessoais; business = frota de um negócio (dono define o acesso);
	-- job = frota de uma corporação (polícia, hospital, bombeiros...), toda a corporação usa.
	Kinds = { public = 'Pública', business = 'Negócio', job = 'Corporação' },
	-- Quem lê a frota de um negócio e liga o acesso da equipe (o tablet de negócios, que confere ponto e permissão).
	BusinessResources = { coe_businesses = true },
	-- Quem compra veículos para a frota de um negócio (AddBusinessFleet): o coe_fuel (frota de abastecimento dos postos).
	FleetResources = { coe_fuel = true },
	DefaultBlip = { sprite = 357, color = 3, scale = 0.8 }
}
