-- Operadora de telefonia do COE OS: linhas pré-pago e pós-pago, tarifação de voz, vídeo e SMS.
-- Quem liga paga; quem recebe não. Valores sempre inteiros (a economia só trabalha com inteiros).
CoeTelecomConfig = {
	-- Resources que podem tarifar ligações e mensagens (Authorize/Charge).
	AllowedCallers = { coe_phone = true },

	-- Operadoras. Nesta fase existe só uma; a fase 2 (#241) abre operadoras de jogadores.
	DefaultCarrier = 'coe',
	Carriers = {
		coe = { label = 'COE Telecom' }
	},

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
