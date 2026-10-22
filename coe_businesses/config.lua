BusinessesConfig = {
	Locale = 'pt-BR',
	-- Categorias cujo ponto é operado pelo próprio resource (prompt e fluxo na oficina); as demais usam o prompt daqui.
	ClockPromptElsewhere = { mechanic = true },

	-- Acesso de outros resources. O nome vem do runtime. As listas são os padrões do framework; pacotes e scripts de
	-- terceiros recebem a ACE no server.cfg, sem editar este arquivo (add_ace resource.<nome> <ace> allow):
	--   coe.businesses.write        gravar/remover negócios (painel, ou pacotes que semeiam os seus)
	--   coe.businesses.clock        acionar o ponto em nome do jogador (o resource confere local e acesso antes)
	--   coe.businesses.tablet       app do negócio no tablet (o tablet valida o ponto e limita a taxa)
	--   coe.businesses.permissions  registrar permissões de cargo (prefixo = nome do resource sem "coe_")
	--   coe.businesses.payroll      ler salários para a folha de pagamento
	--   coe.businesses.admin        resumo de quem está de ponto (painel de staff)
	--   coe.businesses.extend       registrar abas no app do negócio e provedores de frota e propriedades
	Ace = {
		Write = 'coe.businesses.write',
		Clock = 'coe.businesses.clock',
		Tablet = 'coe.businesses.tablet',
		Permissions = 'coe.businesses.permissions',
		Payroll = 'coe.businesses.payroll',
		Admin = 'coe.businesses.admin',
		Extend = 'coe.businesses.extend'
	},
	-- coe_shops semeia as lojinhas (24/7, LTD, Rob's Liquor) até a staff passar uma para um jogador.
	WriterResources = { coe_shops = true },
	ClockResources = {},
	TabletResources = {},
	-- coe_shops registra a aba Loja.
	ExtensionResources = { coe_shops = true },

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
	-- Padrões de coe.businesses.permissions e coe.businesses.payroll (ver Ace acima).
	PermissionResources = { coe_economy = true, coe_shops = true },
	PayrollResources = { coe_economy = true },

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
