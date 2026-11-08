-- Operadora de telefonia do COE OS: linhas pré-pago e pós-pago, tarifação de voz, vídeo e SMS.
-- Quem liga paga; quem recebe não. Valores sempre inteiros (a economia só trabalha com inteiros).
CoeTelecomConfig = {
	-- Resources que podem tarifar ligações, mensagens e pacote de dados (Authorize/Charge).
	AllowedCallers = {
		coe_phone = true,
		coe_tablet = true,
		coe_amzg = true,
		coe_elos = true,
		coe_deepweb = true,
		coe_crypto = true
	},

	-- Operadoras Concessionárias Híbridas (Sistema -> Player-Owned no coe_businesses).
	DefaultCarrier = 'coe',
	Carriers = {
		coe = { label = 'COE Telecom', bands = { ['5G'] = true, ['4G'] = true, ['3G'] = true } },
		badger = { label = 'Badger Communications', businessId = 'telecom_badger', fiberProvider = true, bands = { ['5G'] = true, ['4G'] = true, ['3G'] = true } },
		tinkle = { label = 'Tinkle Mobile', businessId = 'telecom_tinkle', bands = { ['5G'] = true, ['4G'] = true } },
		whiz = { label = 'Whiz Wireless', businessId = 'telecom_whiz', bands = { ['4G'] = true, ['3G'] = true } },
		orbitlink = { label = 'OrbitLink Aeroespacial', businessId = 'telecom_orbitlink', satellite = true, bands = { ['SAT'] = true, ['5G'] = true } }
	},

	-- Antenas Rádio-Base (ERBs) mapeadas em San Andreas (5G Urbano, 4G Subúrbio/Rodovias, 3G Rural)
	Towers = {
		{ id = 'erb_hawick_badger', label = 'Torre Badger Hawick', band = '5G', radius = 350.0, x = 312.0, y = -278.0, z = 54.0, speedMbps = 800 },
		{ id = 'erb_pillbox_tinkle', label = 'Torre Tinkle Pillbox Hill', band = '5G', radius = 350.0, x = -265.0, y = -963.0, z = 31.0, speedMbps = 950 },
		{ id = 'erb_delperro_whiz', label = 'Torre Whiz Del Perro', band = '4G', radius = 850.0, x = -1450.0, y = -540.0, z = 35.0, speedMbps = 120 },
		{ id = 'erb_sandy_rural', label = 'Torre Sandy Shores', band = '3G', radius = 1800.0, x = 1850.0, y = 3680.0, z = 34.0, speedMbps = 8 },
		{ id = 'erb_paleto_rural', label = 'Torre Paleto Bay', band = '3G', radius = 1800.0, x = -140.0, y = 6300.0, z = 31.0, speedMbps = 8 }
	},

	-- Zonas de Sombra (Dead Zones sem cobertura celular terrestre: 0 barras sem Satélite/Wi-Fi)
	DeadZones = {
		{ id = 'dead_chiliad_peak', label = 'Topo do Mount Chiliad', x = 501.0, y = 5604.0, z = 797.0, radius = 320.0 },
		{ id = 'dead_raton_canyon', label = 'Desfiladeiro Raton Canyon', x = -1150.0, y = 4420.0, z = 12.0, radius = 400.0 }
	},

	SabotageDurationSeconds = 900, -- 15 minutos fora do ar quando sabotada por facção
	VehicleOrbitlinkBubbleRadius = 25.0, -- Bolha de 25m ao redor do veículo com Kit OrbitLink ativo

	-- Plano de toda linha nova (a linha nasce no primeiro uso) e o crédito de boas-vindas.
	DefaultPlan = 'prepaid',
	StartingCredit = 30,
	MaxBalance = 5000,
	Recharges = { 20, 50, 100, 200 },

	-- Segundos de tolerância antes de começar a cobrar (ligação que cai logo não paga).
	GraceSeconds = 3,

	-- Ciclo do pós-pago (dias reais), carência da fatura antes de suspender e intervalo entre trocas de plano.
	CycleDays = 7,
	GraceDays = 3,
	PlanChangeHours = 24,

	-- Rotina de faturamento e limpeza do histórico.
	TickSeconds = 300,
	UsageKeepDays = 30,
	UsageLimit = 30,
	InvoicesLimit = 12,

	-- Planos. kind: prepaid (desconta do crédito) ou postpaid (mensalidade + excedente na fatura).
	-- rates: preço por minuto iniciado (voice, video) e por mensagem (sms). Sem rates = ilimitado.
	-- allowance: minutos incluídos no ciclo do pós-pago.
	Plans = {
		prepaid = {
			label = 'Pré-pago', kind = 'prepaid', order = 1,
			description = 'Sem mensalidade. Recarregue e pague só o que usar.',
			rates = { voice = 2, video = 4, sms = 0 }
		},
		control = {
			label = 'Controle', kind = 'postpaid', order = 2, monthly = 150,
			description = '120 min de voz e 30 min de vídeo por ciclo; excedente na fatura.',
			allowance = { voice = 120, video = 30 },
			rates = { voice = 1, video = 3, sms = 0 }
		},
		unlimited = {
			label = 'Ilimitado', kind = 'postpaid', order = 3, monthly = 400,
			description = 'Voz, vídeo e mensagens à vontade.'
		}
	}
}
