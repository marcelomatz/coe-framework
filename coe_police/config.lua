PoliceConfig = {
	-- Permissões de cargo registradas no coe_businesses (prefixo = nome do resource sem "coe_").
	Permissions = {
		{ name = 'police.cuff', label = 'Algemar e soltar' },
		{ name = 'police.fine', label = 'Aplicar multas' },
		{ name = 'police.jail', label = 'Prender' },
		{ name = 'police.records', label = 'Consultar ficha criminal' },
		{ name = 'police.search', label = 'Revistar' },
		{ name = 'police.seize', label = 'Apreender itens' },
		{ name = 'police.escort', label = 'Escoltar' }
	},

	-- Escolta: o alvo acompanha o policial; se ficar além disso, a escolta cai.
	EscortMaxDistance = 15.0,
	SearchLimit = 30,
	-- Receita das multas: vai para a conta de sociedade do negócio do policial.
	FinesToSociety = true,

	-- Distância máxima entre o policial e o alvo (verificada no servidor).
	ActionRange = 4.0,
	MaxFine = 100000,
	MaxSentenceMinutes = 120,
	-- Onde o preso cumpre a pena e onde é solto.
	Jail = { x = 1691.2, y = 2565.1, z = 45.6, heading = 180.0, radius = 25.0 },
	Release = { x = 1848.0, y = 2585.9, z = 45.7, heading = 270.0 },

	-- Resources que podem chamar as ações (o policial é validado no servidor mesmo assim).
	ActionResources = { coe_police = true, coe_tablet = true, coe_admin = true, coe_mdt = true },
	Limits = { MaxRecords = 100 }
}
