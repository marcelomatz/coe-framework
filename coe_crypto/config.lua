-- Criptomoeda do jogo. Carteira = endereço público + chave privada: quem tem a chave move os fundos.
-- A chave mora num aparelho (smartphone, tablet ou computador do coe_deepweb), num pen drive ou num papel.
-- Valores sempre em unidades inteiras (1 moeda = 10^Decimals unidades).
CryptoConfig = {
	Coin = { Name = 'Noxcoin', Symbol = 'NOX', Decimals = 4 },

	-- Endereço: prefixo + caracteres base58. Chave: NXK- + 5 grupos de 5 caracteres (base32 sem letras ambíguas).
	Address = { Prefix = 'nx', Length = 30 },

	Wallets = {
		-- Chaves guardadas por aparelho (carteiras "quentes").
		MaxPerDevice = 8,
		-- Carteiras novas que um personagem cria por dia (evita spam de endereços).
		MaxCreatedPerDay = 5,
		LabelMax = 24,
		-- Erros seguidos de chave na importação, por aparelho, antes do bloqueio.
		ImportFailures = 5, ImportLockSeconds = 120
	},

	Transfer = {
		-- Taxa da rede por envio (em unidades), queimada. 10 = 0,0010 NOX.
		Fee = 10,
		MinAmount = 1,
		MaxAmount = 1000000000000,
		MemoMax = 60,
		CooldownSeconds = 3
	},

	-- Corretora: compra e venda contra o saldo do banco (coe_economy). Tem identificação: cada ordem fica ligada ao
	-- personagem. A liquidez sai de uma carteira de reserva (sem chave) criada com `Reserve` unidades.
	Exchange = {
		Enabled = true,
		Name = 'NoxEx',
		ReserveAddress = 'nxExchangeReserve1111111111111',
		Reserve = 5000000000, -- 500.000 NOX
		-- Cotação em $ por moeda inteira: passeio aleatório com volta à âncora e impacto do fluxo líquido de ordens.
		StartPrice = 2500, AnchorPrice = 2500, MinPrice = 150, MaxPrice = 60000,
		TickMinutes = 5, Volatility = 0.018, MeanReversion = 0.04,
		-- Variação (em log) para cada $1.000.000 de compra líquida no intervalo (venda líquida derruba).
		ImpactPerMillion = 0.08,
		-- Diferença entre compra e venda, em pontos-base de cada lado (300 = 3%).
		SpreadBps = 300,
		MinOrder = 50, MaxOrder = 250000,
		-- Limites por personagem em 24 horas, em $.
		DailyBuyLimit = 500000, DailySellLimit = 500000,
		-- Pontos guardados para o gráfico (288 x 5 min = 24 h).
		HistoryPoints = 288,
		OrderCooldownSeconds = 5
	},

	-- Mineração: só resources de `Callers` (computadores do coe_deepweb) pedem emissão. Cada rodada emite até
	-- `EmissionPerTick`, dividida pelo poder de cada máquina; com pouco poder total na rede (< ReferenceHash), sai menos.
	Mining = {
		Callers = { coe_deepweb = true },
		TickMinutes = 10,
		EmissionPerTick = 20000, -- 2 NOX
		ReferenceHash = 200,
		-- Teto de emissão por mineração (fora a reserva da corretora).
		MaxMined = 210000000000 -- 21.000.000 NOX
	},

	-- Custódia (escrow): carteira sem chave que segura valores até o desfecho (pagamento do mercado da DeepWeb até a
	-- entrega, entradas das corridas do coe_races até a chegada). Só os resources de `Callers` travam e liberam valores nela.
	Escrow = {
		Address = 'nxMarketEscrow1111111111111111',
		Callers = { coe_deepweb = true, coe_races = true }
	},

	-- Itens com a chave gravada (metadata { address, key, label }). Quem carrega o item usa a carteira.
	Items = { Paper = 'crypto_paper', Usb = 'crypto_usb', BlankUsb = 'usb_black' },

	-- Quem chama o app: smartphone, tablet e computadores do coe_deepweb (este passa a chave do aparelho).
	Hosts = { coe_phone = 'phone', coe_tablet = 'tablet' },
	ComputerHosts = { coe_deepweb = true },

	-- Explorador público (qualquer endereço): movimentações por página.
	HistoryPageSize = 30,
	CallCooldownMs = 250
}
