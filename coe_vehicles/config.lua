CoeVehiclesConfig = {
	Locale = 'pt-BR',
	-- Quem cria veículos e altera estado, e quem corrige a quilometragem (auditado). O nome vem do runtime. Padrão: o
	-- próprio resource; pacotes (garagens, oficina, painel) e scripts de terceiros recebem a ACE no server.cfg:
	--   add_ace resource.<nome> coe.vehicles.write allow
	--   add_ace resource.<nome> coe.vehicles.mileage allow
	Ace = { Write = 'coe.vehicles.write', Mileage = 'coe.vehicles.mileage' },
	-- coe_staff: o painel básico da staff cria veículos registrados e guarda os que apaga.
	-- coe_garage: retira (Spawn + GiveKey) e guarda (Store) os veículos do dono.
	WriterResources = { coe_vehicles = true, coe_staff = true, coe_garage = true },
	MileageEditors = { coe_vehicles = true },
	-- Chaves emprestadas por veículo (a do dono é implícita). Raio máximo para emprestar em jogo.
	MaxLoanedKeysPerVehicle = 5,
	-- Chave como item do inventário: entregue ao receber o veículo e recolhida ao guardar. Sem o item o veículo
	-- não liga nem tranca. Tecla padrão de trancar (cada jogador troca em Configurações > Teclas > FiveM).
	KeyItem = 'carkey',
	LockKey = 'L',
	LockDistanceMeters = 8.0,
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
