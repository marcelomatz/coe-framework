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

	-- Somente estes resources movimentam dinheiro; o nome vem do runtime, nunca do payload.
	AllowedResources = {
		coe_economy = true,
		coe_admin = true,
		coe_banking = true,
		coe_businesses = true,
		coe_garages = true,
		coe_mechanic = true,
		coe_housing = true,
		coe_police = true,
		coe_apps = true,
		coe_telecom = true,
		coe_news = true,
		coe_pausemenu = true,
		-- Corretora cripto (compra e venda) e energia dos computadores de mineração.
		coe_crypto = true,
		coe_deepweb = true,
		-- Plataforma de empregos: paga os jobs dos pacotes (coe_basicjobs...) e cobra o depósito dos veículos.
		coe_jobs = true,
		-- Lojas de conveniência: receita das vendas no caixa do negócio e saldo no relatório da gestão.
		coe_shops = true,
		-- Postos: receita das bombas no caixa do negócio.
		coe_fuel = true
	},
	SocietyCollectors = {
		-- Vendas das lojas (coe_shops): o cliente já pagou (espécie, cartão ou Carteira); a receita entra no caixa.
		coe_shops = true,
		-- Vendas das bombas (coe_fuel): o cliente já pagou; a receita entra no caixa do posto.
		coe_fuel = true,
		coe_police = true,
		coe_housing = true,
		coe_banking = true,
		coe_news = true
	},
	-- Conta bancária empresarial (coe_banking): movimenta a sociedade em nome do negócio (exports Bank*) e roda a
	-- folha manualmente. Quem pode cada operação é conferido no banco pelas permissões de cargo.
	SocietyBankers = {
		coe_banking = true
	},
	-- Podem cobrar despesas da sociedade (sem personagem), ex.: aluguel de imóvel comercial.
	SocietyPayers = {
		coe_housing = true,
		coe_banking = true,
		coe_news = true
	}
}
