FactionsConfig = {
	-- Categorias das facções ilegais; o painel e a validação usam esta lista.
	Categories = {
		gang = 'Gangue',
		mafia = 'Máfia',
		ghetto = 'Gueto',
		chop_shop = 'Desmanche',
		other = 'Outro'
	},

	Limits = {
		MaxGrade = 9,
		MaxGrades = 10,
		MaxCrafts = 64,
		MaxMembers = 200,
		MaxFactions = 200,
		MaxStationsPerKind = 8,
		MaxCoordinate = 10000.0
	},

	-- Capacidades ACE (`add_ace resource.<nome> coe.factions.read allow`) e allowlists padrão.
	Ace = {
		Read = 'coe.factions.read',
		Admin = 'coe.factions.admin',
		Tablet = 'coe.factions.tablet'
	},
	-- Quem pode ler acessos e quem pode alterar facções e membros.
	ReaderResources = { coe_crafting = true, coe_admin = true, coe_doors = true },
	AdminResources = { coe_admin = true },
	-- Resource do tablet (COE OS): um app por facção do personagem, só leitura.
	TabletResources = { coe_tablet = true }
}
