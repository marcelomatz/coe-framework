SupervisorConfig = {
	-- Quem pede reinícios (a autorização do operador é de quem chama): ACE no server.cfg, ex.:
	--   add_ace resource.coe_admin coe.supervisor allow
	Ace = 'coe.supervisor',
	-- Resources do framework que podem ser reiniciados. Pacotes e scripts de terceiros entram declarando no próprio
	-- fxmanifest a categoria: coe_supervisor 'business' (e coe_supervisor_critical 'yes' se derrubar o servidor).
	Managed = {
		'coe_logging',
		'coe_notify',
		'coe_ui',
		'coe_loadscreen',
		'coe_database',
		'coe_audit',
		'coe_core',
		'coe_spawn',
		'coe_characters',
		'coe_appearance',
		'coetarget',
		'coe_inventory',
		'coe_needs',
		'coe_hud',
		'coe_map',
		'coe_vehicles',
		'coe_vehicle_catalog',
		'coe_economy',
		'coe_businesses',
		'coe_jobs',
		'coe_shops',
		'coe_talk',
		'coe_pausemenu'
	},
	-- Categoria de cada resource gerenciado; critical = reiniciar pode derrubar o servidor inteiro.
	Catalog = {
		coe_logging = { category = 'infrastructure', critical = true },
		coe_database = { category = 'infrastructure', critical = true },
		coe_audit = { category = 'infrastructure', critical = true },
		coe_core = { category = 'core', critical = true },
		coe_ui = { category = 'interface', critical = true },
		coe_notify = { category = 'interface' },
		coe_hud = { category = 'interface' },
		coe_map = { category = 'interface' },
		coe_loadscreen = { category = 'interface' },
		coe_spawn = { category = 'gameplay' },
		coe_characters = { category = 'gameplay' },
		coe_appearance = { category = 'gameplay' },
		coetarget = { category = 'gameplay' },
		coe_inventory = { category = 'gameplay' },
		coe_needs = { category = 'gameplay' },
		coe_vehicles = { category = 'gameplay' },
		coe_vehicle_catalog = { category = 'gameplay' },
		coe_economy = { category = 'business' },
		coe_businesses = { category = 'business' },
		coe_jobs = { category = 'gameplay' },
		coe_shops = { category = 'business' },
		coe_talk = { category = 'gameplay' },
		coe_pausemenu = { category = 'gameplay' }
	},
	-- Reinício que derruba muitos resources também é tratado como crítico.
	CriticalRestartSize = 6,
	-- Reiniciar não relê o fxmanifest: sem refresh, arquivos novos ou renomeados não carregam.
	RefreshBeforeStart = true,
	RefreshWaitMs = 1000,
	StopTimeoutMs = 15000,
	StartTimeoutMs = 30000
}
