EconomyConfig = {
	Locale = 'pt-BR',
	-- Saldo inicial de uma conta criada no primeiro acesso do personagem.
	StartingBalance = 5000,
	-- Maior valor aceito em uma única operação.
	MaxAmount = 1000000000,
	-- Maior saldo que uma conta pode acumular (BIGINT UNSIGNED comporta muito mais).
	MaxBalance = 9000000000000,
	Currency = '$',
	-- Ciclo da folha de pagamento dos negócios (minutos). 0 desliga o pagamento automático.
	PayrollIntervalMinutes = 30,

	-- Quem movimenta dinheiro. O nome vem do runtime, nunca do payload. As listas abaixo são os padrões do framework;
	-- pacotes e scripts de terceiros recebem a capacidade por ACE no server.cfg, sem editar este arquivo:
	--   add_ace resource.<nome> coe.economy.money allow          (contas de personagem)
	--   add_ace resource.<nome> coe.economy.society.collect allow (receita no caixa de um negócio)
	--   add_ace resource.<nome> coe.economy.society.pay allow     (despesa do caixa de um negócio)
	--   add_ace resource.<nome> coe.economy.society.bank allow    (conta empresarial e folha manual)
	--   add_ace resource.<nome> coe.economy.admin allow           (painel de staff: resumo, extratos, folha)
	Ace = {
		Money = 'coe.economy.money',
		Collect = 'coe.economy.society.collect',
		Pay = 'coe.economy.society.pay',
		Bank = 'coe.economy.society.bank',
		Admin = 'coe.economy.admin'
	},
	AllowedResources = {
		coe_economy = true,
		coe_businesses = true,
		-- Plataforma de empregos: paga os jobs e cobra o depósito dos veículos.
		coe_jobs = true,
		-- Lojas de conveniência: receita das vendas no caixa do negócio e saldo no relatório da gestão.
		coe_shops = true,
		-- Banco básico: saque, depósito, transferência e extrato da conta do personagem.
		coe_bank = true,
		-- Painel básico da staff: dar e retirar dinheiro da conta (motivo admin_adjustment).
		coe_staff = true
	},
	SocietyCollectors = {
		-- Vendas das lojas (coe_shops): o cliente já pagou; a receita entra no caixa.
		coe_shops = true
	},
	SocietyBankers = {},
	SocietyPayers = {}
}
