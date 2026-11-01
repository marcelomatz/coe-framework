MdtConfig = {
	-- Permissões de cargo registradas no coe_businesses (prefixo = nome do resource sem "coe_").
	-- Todas exigem estar de ponto em um negócio police; `mdt.access` é a base de qualquer uso.
	Permissions = {
		{ name = 'mdt.access', label = 'Abrir o MDT (chamados, mandados e boletins)' },
		{ name = 'mdt.lookup', label = 'Consultar cidadãos e placas' },
		{ name = 'mdt.reports', label = 'Registrar e ler relatórios' },
		{ name = 'mdt.warrant_issue', label = 'Emitir mandados' },
		{ name = 'mdt.warrant_close', label = 'Cumprir ou revogar mandados' },
		{ name = 'mdt.bulletins', label = 'Publicar e encerrar boletins' }
	},

	-- Quem pode chamar TabletCall (o coe_tablet valida o ponto, o MDT revalida a cada ação).
	TabletResources = { coe_tablet = true },
	-- Quem lê o registro de acessos (corregedoria).
	AuditResources = { coe_admin = true },

	-- Consultas a dados de cidadãos e placas: cada uma é gravada no registro de acessos antes de responder.
	LookupsPerWindow = 20,
	LookupWindowSeconds = 60,
	-- Escritas (mandados, boletins, relatórios).
	WritesPerWindow = 12,
	WriteWindowSeconds = 60,

	Limits = {
		SearchResults = 10,
		Warrants = 50,
		PersonWarrants = 10,
		PersonReports = 5,
		PersonRecords = 15,
		Bulletins = 30,
		Reports = 30,
		AccessLog = 100
	},
	BulletinDefaultHours = 24,
	BulletinMaxHours = 72,
	MaxActiveWarrantsPerCharacter = 5
}
