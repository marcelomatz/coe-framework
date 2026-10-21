BusinessesConfig = {
	Locale = 'pt-BR',
	-- Categorias cujo ponto é operado pelo próprio resource (prompt e fluxo na oficina); as demais usam o prompt daqui.
	ClockPromptElsewhere = { mechanic = true },

	-- Quem pode gravar/remover negócios (o coe_mechanic só semeia os padrões ausentes).
	WriterResources = {
		coe_admin = true,
		coe_mechanic = true,
		coe_news = true, -- semeia a Weazel News e a Rebel News
		coe_shops = true, -- semeia as lojinhas (24/7, LTD, Rob's Liquor), da staff até a staff passar para um jogador
		coe_fuel = true -- semeia os postos sem loja (os LTD são das lojinhas)
	},
	-- Quem pode acionar o ponto em nome do jogador (o resource confere local e acesso antes).
	ClockResources = { coe_mechanic = true },
	-- Quem pode chamar o tablet de negócios (o coe_tablet valida o ponto e limita a taxa).
	TabletResources = { coe_tablet = true },

	-- Categorias da aba "Negócios". `stations` diz quais pontos a categoria aceita; `rules`, quais regras.
	Categories = {
		mechanic = { label = 'Mecânicas', stations = { 'showroom', 'crafts', 'stashes', 'clocks' }, rules = { 'ownerAccess', 'priceMultiplier', 'clockRequired', 'clockOffsite', 'multiJob' } },
		shop = { label = 'Lojinhas', stations = { 'stashes', 'crafts', 'clocks' }, rules = { 'ownerAccess', 'clockRequired', 'clockOffsite', 'multiJob' } },
		gas_station = { label = 'Postos', stations = { 'stashes', 'clocks' }, rules = { 'ownerAccess', 'clockRequired', 'clockOffsite', 'multiJob' } },
		restaurant = { label = 'Restaurantes', stations = { 'stashes', 'crafts', 'clocks' }, rules = { 'ownerAccess', 'clockRequired', 'clockOffsite', 'multiJob' } },
		other = { label = 'Outros', stations = { 'stashes', 'crafts', 'clocks' }, rules = { 'ownerAccess', 'clockRequired', 'clockOffsite', 'multiJob' } },
		-- ruleDefaults: valor inicial das regras que mudam por categoria (polícia e EMS são dedicação exclusiva).
		police = { label = 'Delegacias', stations = { 'stashes', 'clocks' }, rules = { 'ownerAccess', 'clockRequired', 'clockOffsite', 'multiJob' }, ruleDefaults = { multiJob = false } },
		ems = { label = 'Hospitais', stations = { 'stashes', 'clocks' }, rules = { 'ownerAccess', 'clockRequired', 'clockOffsite', 'multiJob' }, ruleDefaults = { multiJob = false } },
		-- Veículos de comunicação (coe_news): a reportagem trabalha na rua, então o ponto segue aberto fora da área.
		media = { label = 'Mídia', stations = { 'stashes', 'clocks' }, rules = { 'ownerAccess', 'clockRequired', 'clockOffsite', 'multiJob' }, ruleDefaults = { clockOffsite = true } }
	},

	-- Permissões de cargo do próprio coe_businesses. Pacotes registram as suas (RegisterPermissions) com o prefixo do resource.
	Permissions = {
		['business.funds'] = 'Movimentar o caixa (sociedade)',
		['business.staff'] = 'Gerenciar equipe',
		['business.fleet'] = 'Gerenciar frota',
		['business.remote'] = 'Gerenciar sem ponto batido (remoto)'
	},
	-- Resources que podem registrar permissões de cargo (prefixo = nome sem "coe_").
	PermissionResources = { coe_police = true, coe_ems = true, coe_mechanic = true, coe_economy = true, coe_mdt = true, coe_news = true, coe_banking = true, coe_shops = true },
	-- Leitura de salários para a folha de pagamento (o coe_banking mostra a folha na conta empresarial).
	PayrollResources = { coe_economy = true, coe_admin = true, coe_banking = true },

	-- Validação de cada regra.
	Rules = {
			ownerAccess = { type = 'boolean', default = true },
		priceMultiplier = { type = 'number', min = 0.5, max = 3.0, default = 1.0 },
	-- Ponto: a equipe precisa estar de ponto batido para operar; clockOffsite deixa o ponto aberto fora da área.
	clockRequired = { type = 'boolean', default = true },
	clockOffsite = { type = 'boolean', default = false },
	-- Vários empregos: false = dedicação exclusiva (a equipe não pode ser de outro negócio). Sempre um ponto por vez.
	multiJob = { type = 'boolean', default = true }
	},

	Limits = {
		MaxBusinesses = 200,
		MaxStationsPerKind = 8,
		MaxStaff = 50,
		MaxPartners = 10,
		MaxGrades = 10,
		MaxGradeLevel = 99,
		MaxSalary = 1000000,
		MaxPermissionsPerGrade = 32,
		MaxPolygonPoints = 16,
		MaxCoordinate = 10000.0,
		DutySweepMs = 5000
	}
}
