-- Elos: rede profissional do COE OS. Perfil, currículo (empregos livres do coe_jobs e negócios do coe_businesses)
-- e conexões entre personagens. Vagas e candidaturas chegam na fase 2.
ElosConfig = {
	CallCooldownMs = 250,

	Profile = {
		HeadlineMax = 80,  -- frase de apresentação ("Mecânico na Benny's")
		AboutMax = 600,    -- texto "Sobre"
		NoteMax = 160,     -- comentário do jogador em cada experiência do currículo
		-- Padrões de quem abre o app pela primeira vez: perfil aberto, sem ganhos, com carreira e reputação.
		Defaults = { visibility = 'open', showEarnings = false, showCareer = true }
	},

	Resume = {
		MaxItems = 40,          -- experiências no currículo
		MinShiftSeconds = 60    -- ponto em negócio mais curto que isso não conta como turno
	},

	Network = {
		MaxConnections = 300,
		MaxPendingOut = 30,      -- pedidos enviados aguardando resposta
		SearchMin = 3,           -- letras mínimas para buscar por nome
		SearchLimit = 20
	},

	-- Rótulo de cada categoria de negócio no currículo (sem entrada usa o nome do coe_businesses).
	BusinessCategories = {
		mechanic = 'Oficina', shop = 'Loja', restaurant = 'Restaurante', gas_station = 'Posto',
		police = 'Polícia', ems = 'Saúde', media = 'Mídia', other = 'Negócio'
	}
}
