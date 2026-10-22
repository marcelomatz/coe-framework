BankConfig = {
	Locale = 'pt-BR',
	Currency = '$',

	-- Tetos por operação (valores inteiros). Transferência só na agência.
	MaxAgencyAmount = 1000000,
	MaxAtmAmount = 5000,
	AtmQuickAmounts = { 100, 200, 500, 1000 },
	AgencyQuickAmounts = { 100, 500, 1000, 5000 },
	-- Lançamentos mostrados no extrato (agência) e no resumo do caixa eletrônico.
	StatementSize = 20,
	AtmStatementSize = 5,
	-- Intervalo mínimo entre operações do mesmo jogador.
	ActionIntervalMs = 700,
	-- Distância máxima do ponto onde a tela foi aberta (agência ou caixa); passou disso, a sessão fecha.
	SessionRadius = 3.0,

	-- Pacote que assume o banco (ex.: um banco comercial com cartões e crédito) chama o export Yield; o banco básico
	-- esconde agências, caixas e blips até esse resource parar. A capacidade vem do server.cfg:
	--   add_ace resource.<nome> coe.bank.yield allow
	Ace = { Yield = 'coe.bank.yield' },

	-- Caixas eletrônicos: qualquer prop destes modelos no mapa.
	AtmModels = { 'prop_atm_01', 'prop_atm_02', 'prop_atm_03', 'prop_fleeca_atm' },
	-- Distância da origem do prop até o jogador, raio de busca em volta do ponto mirado e alcance da mira.
	AtmDistance = 2.5,
	AtmSearchRadius = 1.5,
	AtmReach = 2.5,

	Blip = { sprite = 108, color = 2, scale = 0.7, label = 'Banco' },
	-- Agências: ponto do balcão (prompt "E").
	Agencies = {
		{ id = 'legion', label = 'Agência Legion Square', x = 149.05, y = -1041.3, z = 29.37, radius = 1.6 },
		{ id = 'hawick', label = 'Agência Hawick', x = 313.32, y = -280.03, z = 54.17, radius = 1.6 },
		{ id = 'burton', label = 'Agência Burton', x = -351.12, y = -51.13, z = 49.04, radius = 1.6 },
		{ id = 'rockford', label = 'Agência Rockford Hills', x = -1212.68, y = -331.24, z = 37.78, radius = 1.6 },
		{ id = 'banham', label = 'Agência Banham Canyon', x = -2961.67, y = 482.31, z = 15.7, radius = 1.6 },
		{ id = 'harmony', label = 'Agência Harmony', x = 1175.64, y = 2708.71, z = 38.09, radius = 1.6 },
		{ id = 'central', label = 'Banco Central', x = 246.64, y = 223.2, z = 106.29, radius = 1.8 },
		{ id = 'paleto', label = 'Agência Paleto Bay', x = -111.98, y = 6470.56, z = 31.63, radius = 1.6 }
	}
}
