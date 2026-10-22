CoeVehicleCatalogConfig = {
	-- Quem altera overrides e pede nova varredura (nome vem do runtime). Padrão: o próprio resource; painéis e scripts
	-- de terceiros recebem a ACE no server.cfg: add_ace resource.<nome> coe.vehicles.catalog allow
	Ace = 'coe.vehicles.catalog',
	WriterResources = { coe_vehicle_catalog = true },
	-- Preço usado quando não há override; o valor real vem de overrides/concessionária.
	DefaultPrice = 20000,
	PriceByClass = {
		compacts = 15000,
		sedans = 18000,
		suvs = 35000,
		coupes = 40000,
		muscle = 38000,
		sports_classics = 90000,
		sports = 80000,
		super = 250000,
		motorcycles = 12000,
		offroad = 30000,
		vans = 25000,
		commercial = 60000,
		emergency = 0,
		service = 0,
		utility = 20000,
		boats = 45000,
		helicopters = 400000,
		planes = 600000,
		cycles = 500
	},
	-- Resources de veículo são detectados por estes tipos de data_file.
	VehicleMetaTypes = { VEHICLE_METADATA_FILE = true },
	HandlingMetaTypes = { HANDLING_FILE = true },
	-- Varredura após start/stop de resources espera este tempo para agrupar vários eventos.
	RescanDebounceMs = 2000,
	ListDefaultLimit = 200,
	ListMaxLimit = 500
}
