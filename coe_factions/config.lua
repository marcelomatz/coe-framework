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

	-- Quem pode ler acessos e quem pode alterar facções e membros.
	ReaderResources = { coe_crafting = true, coe_admin = true, coe_doors = true },
	AdminResources = { coe_admin = true },
	-- Resource do tablet (COE OS): um app por facção do personagem, só leitura.
	TabletResources = { coe_tablet = true }
}
