dofile('config.lua')
dofile('shared/rules.lua')

local config = CoeTelecomConfig
local failures = 0
local DAY = 86400

local function eq(actual, expected, message)
	if actual ~= expected then
		failures = failures + 1
		print(('FAIL %s: esperado %s, obtido %s'):format(message, tostring(expected), tostring(actual)))
	end
end

local function line(fields)
	local base = { holder = '1', plan = 'prepaid', status = 'active', balance = 0, cycleStart = 0, voiceUsed = 0, videoUsed = 0, planChangedAt = 0 }
	for key, value in pairs(fields or {}) do
		base[key] = value
	end
	return base
end

-- Minutos cobrados
eq(TelecomRules.Minutes(config, 0), 0, 'zero segundos')
eq(TelecomRules.Minutes(config, 3), 0, 'dentro da tolerância')
eq(TelecomRules.Minutes(config, 4), 1, 'minuto iniciado')
eq(TelecomRules.Minutes(config, 63), 1, 'um minuto cheio')
eq(TelecomRules.Minutes(config, 64), 2, 'segundo minuto iniciado')

-- Autorização
local ok, max = TelecomRules.Authorize(config, line({ balance = 5 }), 'voice')
eq(ok, true, 'pré-pago com crédito')
eq(max, 123, 'crédito paga 2 minutos de voz + tolerância')
eq(TelecomRules.Minutes(config, max), 2, 'limite cobra exatamente o que o crédito paga')
ok, max = TelecomRules.Authorize(config, line({ balance = 5 }), 'video')
eq(max, 63, 'crédito paga 1 minuto de vídeo')
eq(select(2, TelecomRules.Authorize(config, line({ balance = 1 }), 'voice')), 'no_credit', 'sem crédito')
eq(TelecomRules.Authorize(config, line({ balance = 0 }), 'sms'), true, 'sms grátis no pré-pago')
eq(select(2, TelecomRules.Authorize(config, line({ balance = 50, status = 'suspended' }), 'voice')), 'line_suspended', 'suspensa')
eq(select(2, TelecomRules.Authorize(config, line(), 'fax')), 'invalid_kind', 'tipo inválido')
ok, max = TelecomRules.Authorize(config, line({ plan = 'control' }), 'voice')
eq(ok, true, 'pós-pago liberado')
eq(max, nil, 'pós-pago sem limite de tempo')
eq(select(2, TelecomRules.Authorize(config, line({ plan = 'sumiu' }), 'voice')), 'unknown_plan', 'plano removido do config')

-- Cobrança
local charge = TelecomRules.Charge(config, line({ balance = 50 }), 'voice', 90)
eq(charge.cost, 4, 'pré-pago: 2 minutos de voz')
eq(charge.field, nil, 'pré-pago não soma franquia')
eq(TelecomRules.Charge(config, line({ balance = 3 }), 'video', 300).cost, 3, 'nunca passa do crédito')
eq(TelecomRules.Charge(config, line({ balance = 50 }), 'voice', 2).units, 0, 'ligação curta é grátis')
charge = TelecomRules.Charge(config, line({ plan = 'control' }), 'video', 125)
eq(charge.cost, 0, 'pós-pago não desconta crédito')
eq(charge.units, 3, 'pós-pago conta minutos')
eq(charge.field, 'video_used', 'soma na franquia de vídeo')
eq(TelecomRules.Charge(config, line({ plan = 'control' }), 'sms', 0).field, nil, 'sms não soma franquia')

-- Ciclo e faturas
local post = line({ plan = 'control', cycleStart = 1000, voiceUsed = 130, videoUsed = 30 })
eq(TelecomRules.CycleDue(config, post, 1000 + 7 * DAY - 1), false, 'ciclo em andamento')
eq(TelecomRules.CycleDue(config, post, 1000 + 7 * DAY), true, 'ciclo vencido')
eq(TelecomRules.CycleDue(config, line({ cycleStart = 0 }), 10 * DAY), false, 'pré-pago não fecha ciclo')
local invoice = TelecomRules.Invoice(config, post, 1000 + 7 * DAY, false)
eq(invoice.base, 150, 'mensalidade cheia')
eq(invoice.voice, 10, 'excedente de voz')
eq(invoice.video, 0, 'vídeo dentro da franquia')
eq(invoice.amount, 160, 'mensalidade + excedente')
invoice = TelecomRules.Invoice(config, line({ plan = 'unlimited', cycleStart = 0, voiceUsed = 999 }), 7 * DAY, false)
eq(invoice.amount, 400, 'ilimitado não tem excedente')
invoice = TelecomRules.Invoice(config, line({ plan = 'control', cycleStart = 0 }), math.floor(3.5 * DAY), true)
eq(invoice.base, 75, 'mensalidade proporcional')
eq(TelecomRules.Invoice(config, line(), 7 * DAY, false).amount, 0, 'pré-pago sem fatura')
eq(TelecomRules.DueAt(config, 100), 100 + 3 * DAY, 'vencimento após a carência')

-- Recarga
eq(TelecomRules.Recharge(config, line({ balance = 10 }), 50), 50, 'recarga válida')
eq(select(2, TelecomRules.Recharge(config, line(), 33)), 'invalid_amount', 'valor fora da tabela')
eq(select(2, TelecomRules.Recharge(config, line({ balance = 4990 }), 20)), 'balance_full', 'limite de crédito')
eq(select(2, TelecomRules.Recharge(config, line({ plan = 'control' }), 20)), 'not_prepaid', 'pós-pago não recarrega')

-- Troca de plano
local now = 10 * DAY
eq(TelecomRules.ChangePlan(config, line(), 'control', 0, now).kind, 'postpaid', 'pré para controle')
eq(select(2, TelecomRules.ChangePlan(config, line(), 'prepaid', 0, now)), 'same_plan', 'mesmo plano')
eq(select(2, TelecomRules.ChangePlan(config, line(), 'gold', 0, now)), 'unknown_plan', 'plano inexistente')
eq(select(2, TelecomRules.ChangePlan(config, line({ planChangedAt = now - 3600 }), 'control', 0, now)), 'plan_cooldown', 'troca recente')
eq(select(2, TelecomRules.ChangePlan(config, line(), 'control', 1, now)), 'open_invoice', 'fatura em aberto')
eq(select(2, TelecomRules.ChangePlan(config, line({ status = 'suspended' }), 'unlimited', 0, now)), 'open_invoice', 'suspensa não vai para o pós')
eq(TelecomRules.ChangePlan(config, line({ plan = 'control', status = 'suspended' }), 'prepaid', 1, now).kind, 'prepaid', 'suspensa pode voltar ao pré')
local anonymous = line()
anonymous.holder = nil
eq(select(2, TelecomRules.ChangePlan(config, anonymous, 'control', 0, now)), 'holder_required', 'linha sem titular não vai para o pós')

-- Lista de planos
local plans = TelecomRules.PlanList(config)
eq(#plans, 3, 'três planos')
eq(plans[1].id, 'prepaid', 'pré-pago primeiro')
eq(plans[3].id, 'unlimited', 'ilimitado por último')

-- TimingWheel O(1) para corte de chamada pré-paga e Saga Compensatória
local wheel = TelecomRules.NewTimingWheel(1000)
eq(type(wheel), 'table', 'NewTimingWheel disponível')
local cut = false
wheel:schedule('call:5550101', 3000, function() cut = true end)
wheel:tick()
wheel:tick()
eq(cut, false, 'chamada ativa antes do limite')
wheel:tick()
eq(cut, true, 'chamada encerrada no tick exato em O(1)')

-- Testes v2: Antenas 5G/4G/3G, DeadZones, Sabotagem de Torres, Fibra Wi-Fi 6 e Satélite OrbitLink
local sig5g = TelecomRules.EvaluateSignal(config, { x = 310.0, y = -275.0, z = 54.0 }, {}, {})
eq(sig5g.band, '5G', 'cobertura 5G no centro de Hawick')
eq(sig5g.bars, 4, '4 barras no 5G')
eq(TelecomRules.CanAccessBandFeature(sig5g.band, 'deepweb'), true, '5G abre DeepWeb')

-- Sabotagem da torre 5G de Hawick derruba o sinal na célula
local sigSabotaged = TelecomRules.EvaluateSignal(config, { x = 310.0, y = -275.0, z = 54.0 }, {
	erb_hawick_badger = { sabotaged = true }
}, {})
eq(sigSabotaged.band, 'NONE', 'torre sabotada derruba cobertura local')

-- Cobertura 3G rural bloqueia DeepWeb móvel mas permite voz/SMS
local sig3g = TelecomRules.EvaluateSignal(config, { x = 1850.0, y = 3680.0, z = 34.0 }, {}, {})
eq(sig3g.band, '3G', 'cobertura 3G em Sandy Shores')
eq(select(2, TelecomRules.CanAccessBandFeature(sig3g.band, 'deepweb')), 'band_too_slow', '3G bloqueia DeepWeb pesada')
eq(TelecomRules.CanAccessBandFeature(sig3g.band, 'voice'), true, '3G permite voz')

-- Zona de Sombra (Mount Chiliad) sem sinal vs Kit Veicular OrbitLink ativo
local sigDead = TelecomRules.EvaluateSignal(config, { x = 501.0, y = 5604.0, z = 797.0 }, {}, {})
eq(sigDead.band, 'NONE', 'Mount Chiliad é Dead Zone (0 barras)')
local sigOrbit = TelecomRules.EvaluateSignal(config, { x = 501.0, y = 5604.0, z = 797.0 }, {}, { orbitlinkBubble = true })
eq(sigOrbit.band, 'SAT', 'Kit Veicular OrbitLink dá sinal via satélite no Mount Chiliad')
eq(sigOrbit.freeData, true, 'Bolha Wi-Fi OrbitLink isenta franquia do chip SIM')

if failures > 0 then
	error(('%d falha(s)'):format(failures))
end
print('telecom_test: ok')
