BankingConfig = {
	Locale = 'pt-BR',
	Currency = '$',
	-- Tarifa de emissão de cartão (inclui 2ª via). 0 = grátis.
	CardFee = 50,
	-- Validade do cartão em dias reais. Vencido não funciona; o cliente emite outro na agência sem perder nível, limite ou pontos.
	CardValidityDays = 60,
	-- Tarifa para trocar um cartão vencido (sem cartão ativo na conta). 0 = grátis.
	CardRenewFee = 0,
	-- Cartão virtual (só na carteira do smartphone, sem item nem senha): tarifa de emissão. Um ativo por conta; pedir
	-- outro bloqueia o anterior. Tem a mesma validade do físico e não serve no caixa eletrônico.
	VirtualCardFee = 0,
	-- Resources que podem ler, vincular e emitir cartões para a carteira digital (exports Wallet*).
	WalletCallers = { coe_phone = true },
	-- Senhas erradas seguidas até o cartão ser bloqueado (desbloqueio: nova senha na agência).
	MaxPinAttempts = 3,
	-- Maior valor por operação na agência e no caixa eletrônico.
	MaxAgencyAmount = 1000000,
	MaxAtmAmount = 5000,
	AtmQuickAmounts = { 100, 200, 500, 1000 },
	StatementSize = 20,
	AtmStatementSize = 5,
	BusinessStatementSize = 10,
	-- Sessão do caixa eletrônico após a senha (segundos sem operar).
	AtmSessionSeconds = 120,
	ActionIntervalMs = 700,
	-- Rodadas de hash da senha (salt por cartão).
	PinHashRounds = 500,
	-- Tarifa por saque no caixa eletrônico (níveis com `freeAtm` não pagam). 0 = grátis.
	AtmWithdrawFee = 5,

	-- Crédito: cartão múltiplo (débito usa a conta; crédito usa o limite do nível). Tempos em dias reais.
	Credit = {
		CycleDays = 7,
		DueDays = 3,
		-- Pagamento mínimo: maior entre a taxa e o piso (nunca acima da fatura).
		MinPaymentRate = 0.15,
		MinPaymentFloor = 50,
		-- Juros do rotativo (saldo não pago da fatura anterior), por fatura.
		RevolvingRate = 0.08,
		-- Atraso (mínimo não pago no vencimento): multa, juros diários e débito automático da conta.
		LateFeeRate = 0.02,
		LateFeeFlat = 25,
		LateDailyRate = 0.01,
		AutoDebitDays = 5,
		-- Rebaixa um nível no fechamento quando a pontuação cai abaixo do mínimo do nível menos esta margem.
		DowngradeMargin = 100,
		MaxPayment = 1000000,
		-- Compras no crédito sem a maquininha (exports CardPurchase/CardRefund, cartão vindo da carteira digital):
		-- resources autorizados e teto por compra.
		PurchaseCallers = { coe_apps = true, coe_amzg = true, coe_shops = true, coe_fuel = true, coe_phone = true },
		MaxPurchase = 100000,
		TickSeconds = 60,
		StatementSize = 15,
		Score = {
			AgeDays = 30, AgePoints = 200,
			InflowDays = 7, InflowTarget = 20000, InflowPoints = 250,
			BalanceTarget = 25000, BalancePoints = 200,
			HistoryBase = 175, HistoryMax = 350, OnTimePoints = 25, LatePenalty = 100,
			-- Desconto enquanto houver fatura em atraso.
			LateNowPenalty = 200,
			-- Entradas que não contam como movimentação (circulares ou estornos).
			IgnoredReasons = { 'bank_refund', 'bank_deposit', 'bank_transfer', 'starting_balance', 'admin_adjustment', 'bank_loan' }
		},
		-- Teto de limite que a staff pode definir (nível ou limite personalizado).
		AdminMaxLimit = 10000000,
		-- Do menor para o maior; padrão inicial, editável no admin (gravado em coe_banking_tiers).
		-- `pointsPer100`: pontos por $100 no crédito; `fee`: anuidade cobrada em cada fatura.
		Tiers = {
			{ id = 'essential', label = 'Essencial', minScore = 200, limit = 2000, pointsPer100 = 1, fee = 0, freeAtm = false },
			{ id = 'gold', label = 'Gold', minScore = 450, limit = 10000, pointsPer100 = 1.5, fee = 30, freeAtm = false },
			{ id = 'platinum', label = 'Platinum', minScore = 650, limit = 35000, pointsPer100 = 2, fee = 80, freeAtm = true },
			{ id = 'black', label = 'Black', minScore = 850, limit = 100000, pointsPer100 = 3, fee = 0, freeAtm = true }
		}
	},

	-- Empréstimos (concedidos só pela staff no admin): parcelas a cada `IntervalDays`, debitadas da conta no vencimento.
	-- Parcela não paga deixa o empréstimo em atraso (derruba a pontuação) e o débito é tentado de novo até quitar.
	Loans = {
		IntervalDays = 7,
		MaxPrincipal = 1000000,
		-- Juros totais do contrato, em %.
		MaxRate = 100,
		MaxInstallments = 52,
		MaxActive = 1,
		-- Empréstimos ativos por negócio (em nome da empresa).
		MaxActiveBusiness = 1,
		-- Pedidos de empréstimo empresarial aguardando a staff, por negócio.
		MaxPendingRequests = 1,
		-- Taxas pelo relacionamento (maior pontuação primeiro): `rate` = juros totais sugeridos do contrato (%),
		-- `lateDailyRate` = juros diários (%) sobre a parcela em atraso, compostos. Fixados no contrato.
		Pricing = {
			{ minScore = 800, rate = 8, lateDailyRate = 0.5 },
			{ minScore = 600, rate = 15, lateDailyRate = 1 },
			{ minScore = 400, rate = 25, lateDailyRate = 1.5 },
			{ minScore = 200, rate = 40, lateDailyRate = 2 },
			{ minScore = 0, rate = 60, lateDailyRate = 3 }
		},
		-- Teto de dias de juros calculados de uma vez (o tick roda bem antes disso).
		MaxAccrueDays = 60
	},

	-- Conta empresarial: o caixa do negócio (sociedade do coe_economy) com acesso próprio na agência, no caixa
	-- eletrônico (cartão empresarial), no app do negócio no tablet e no admin. Permissões de cargo `banking.*`
	-- (registradas no coe_businesses); quem tem `business.funds` continua com acesso total até o dono ajustar os cargos.
	Business = {
		-- Cartão empresarial: débito no caixa do negócio, emitido para alguém da equipe com limite diário por cartão.
		CardFee = 100,
		DefaultDailyLimit = 2500,
		MaxDailyLimit = 250000,
		MaxCards = 15,
		-- Tarifa por saque no caixa eletrônico com cartão empresarial. 0 = grátis.
		AtmFee = 0,
		-- Maior valor por transferência ou pagamento da empresa.
		MaxTransfer = 1000000,
		-- Extrato: linhas por página e períodos oferecidos (dias).
		StatementPage = 25,
		Periods = { 1, 7, 30, 90 },
		-- Observação de transferências e pagamentos.
		MemoMax = 48,
		-- Fallback de acesso: quem tem esta permissão antiga tem todas as banking.*.
		LegacyPermission = 'business.funds'
	},

	-- Caixas eletrônicos: qualquer prop destes modelos no mapa.	-- Caixas eletrônicos: qualquer prop destes modelos no mapa.
	AtmModels = { 'prop_atm_01', 'prop_atm_02', 'prop_atm_03', 'prop_fleeca_atm' },
	-- Distância da origem do prop (base, no chão) até o centro do jogador.
	AtmDistance = 2.5,
	-- Raio de busca do prop em volta do ponto mirado e alcance da mira até esse ponto.
	AtmSearchRadius = 1.5,
	AtmReach = 2.5,

	Blip = { sprite = 108, color = 2, scale = 0.7 },
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
