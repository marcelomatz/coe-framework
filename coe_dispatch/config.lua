DispatchConfig = {
	-- Categorias de negócio que recebem chamados (equipe de ponto do negócio da categoria).
	Categories = { police = 'Polícia', ems = 'EMS' },

	-- Códigos de chamado. priority 1 = mais urgente. citizen = o cidadão pode abrir com /chamado.
	Codes = {
		help_police = { category = 'police', priority = 3, label = 'Pedido de ajuda à polícia', citizen = true },
		help_ems = { category = 'ems', priority = 2, label = 'Pedido de socorro médico', citizen = true },
		shots_fired = { category = 'police', priority = 2, label = 'Disparos de arma de fogo' },
		assault = { category = 'police', priority = 2, label = 'Agressão' },
		vehicle_theft = { category = 'police', priority = 3, label = 'Roubo de veículo' },
		robbery = { category = 'police', priority = 1, label = 'Roubo em andamento' },
		store_robbery = { category = 'police', priority = 1, label = 'Assalto a comércio' },
		bank_robbery = { category = 'police', priority = 1, label = 'Assalto a banco' },
		suspicious_deal = { category = 'police', priority = 3, label = 'Negociação suspeita' },
		officer_down = { category = 'police', priority = 1, label = 'Policial ferido' },
		person_down = { category = 'ems', priority = 1, label = 'Pessoa inconsciente' },
		accident = { category = 'ems', priority = 2, label = 'Acidente com vítimas' },
		street_race = { category = 'police', priority = 2, label = 'Racha / corrida ilegal' }
	},

	-- Resources que abrem chamados automáticos (heists, EMS, admin).
	ActionResources = { coe_police = true, coe_ems = true, coe_admin = true, coe_tablet = true, coe_heists = true, coe_mdt = true, coe_deepweb = true, coe_loot = true, coe_races = true },

	TtlSeconds = 900,
	MaxActivePerCategory = 50,
	-- Chamados iguais (mesmo código) por perto e recentes viram um só, com contagem de relatos.
	DedupeRadius = 60.0,
	DedupeSeconds = 90,
	-- Intervalo mínimo entre chamados do mesmo cidadão.
	CitizenCooldownSeconds = 60
}
