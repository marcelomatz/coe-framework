HousingConfig = {
	Kinds = { apartment = 'Apartamento', hotel = 'Hotel', house = 'Casa', commercial = 'Imóvel comercial', hideout = 'Imóvel ilegal' },
	-- Ciclos de cobrança permitidos, em dias (semanal, quinzenal, mensal).
	RentCycles = { 7, 15, 30 },
	-- Dias de tolerância depois do vencimento; sem pagar, o contrato é encerrado.
	GraceDays = 3,
	TickMs = 60000,
	-- Cada contrato ganha seu próprio mundo (routing bucket) = BucketBase + id do contrato.
	BucketBase = 1000,
	-- Imóveis comerciais: mundo = CommercialBucketBase + id do contrato do negócio.
	CommercialBucketBase = 500000,
	-- Só estes resources leem os imóveis de um negócio (tablet de negócios).
	BusinessResources = { coe_businesses = true },
	-- Só estes resources leem endereços de entrega e o espaço em que o jogador está (DeliveryAddresses, CurrentSpace).
	-- coe_deepweb: instala desktop/servidor no espaço e confere o contrato antes de cada rodada de mineração.
	DeliveryCallers = { coe_amzg = true, coe_deepweb = true },
	-- Prévia de interiores pelo admin: mundo = PreviewBucketBase + id do jogador.
	PreviewBucketBase = 900000,
	-- Imóveis ilegais: um mundo compartilhado por imóvel = HideoutBucketBase + número do imóvel (world).
	HideoutBucketBase = 700000,

	-- Baú do imóvel (ponto marcado no admin). Cada morador tem o seu; em comerciais, um por negócio.
	-- Capacidade padrão por tipo; o admin pode ajustar por imóvel. Peso em gramas.
	Stash = {
		Defaults = {
			apartment = { slots = 40, maxWeight = 200000 },
			hotel = { slots = 20, maxWeight = 80000 },
			house = { slots = 60, maxWeight = 400000 },
			commercial = { slots = 80, maxWeight = 600000 },
			-- Imóvel ilegal: um baú compartilhado entre dono e membros.
			hideout = { slots = 50, maxWeight = 300000 }
		},
		MaxSlots = 200,
		MaxWeight = 2000000,
		-- Distância máxima entre o baú e o ponto interior (mesmo interior).
		MaxDistanceFromInterior = 80.0
	},

	Limits = {
		MaxProperties = 200,
		MaxUnits = 500,
		MaxTenancies = 3,
		-- Imóveis comerciais alugados por negócio (os cedidos pelo admin não contam).
		MaxLeasesPerBusiness = 3,
		-- Pessoas (além do dono) com acesso a um imóvel ilegal.
		MaxHideoutMembers = 10,
		MaxRentPerDay = 1000000,
		MaxCoordinate = 10000,
		ActionIntervalMs = 1000,
		-- Miniatura de interior (data URL JPEG gerada no admin).
		MaxThumbBytes = 120000
	},

	DefaultBlips = {
		apartment = { sprite = 40, color = 3, scale = 0.8 },
		hotel = { sprite = 40, color = 5, scale = 0.8 },
		house = { sprite = 40, color = 2, scale = 0.8 },
		commercial = { sprite = 475, color = 4, scale = 0.8 },
		-- Imóveis ilegais nunca aparecem no mapa; o estilo só existe para manter o formato.
		hideout = { sprite = 40, color = 1, scale = 0.8 }
	}
}
