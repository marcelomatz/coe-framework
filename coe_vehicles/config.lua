CoeVehiclesConfig = {
	Locale = 'pt-BR',
	-- Resources que podem criar veículos e alterar estado (nome vem do runtime).
	WriterResources = {
		coe_admin = true,
		coe_garages = true,
		coe_vehicles = true
	},
	-- Somente estes resources podem corrigir a quilometragem (mecânica, admin). Auditado.
	MileageEditors = {
		coe_admin = true,
		coe_mechanic = true,
		coe_vehicles = true
	},
	-- Chaves emprestadas por veículo (a do dono é implícita). Raio máximo para emprestar em jogo.
	MaxLoanedKeysPerVehicle = 5,
	LendDistanceMeters = 10.0,
	KeyCheckCooldownMs = 250,
	PlatePattern = 'NNLLLNNN',
	PlateGenerationAttempts = 10,
	Mileage = {
		-- O client acumula e reporta em lote.
		SampleIntervalMs = 1000,
		IdleIntervalMs = 1500,
		ReportIntervalMs = 30000,
		MinStepMeters = 0.5,
		MaxJumpMeters = 400,
		-- Limites de plausibilidade no servidor (anti-exploit): orçamento em metros por veículo.
		MaxSpeedMetersPerSecond = 160,
		InitialCreditSeconds = 60,
		MaxCreditSeconds = 120
	},
	-- Persistência de quilometragem pendente no banco.
	FlushIntervalMs = 60000,
	FlushBatchSize = 50,
	MaxVehiclesPerCharacter = 200
}
