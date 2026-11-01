dofile('../coe_banking/config.lua')
dofile('../coe_banking/server/credit_rules.lua')

local function eq(a, b, m)
	if a ~= b then error(('%s: esperado %s, veio %s'):format(m, tostring(b), tostring(a)), 2) end
end

local c = BankingConfig.Credit
local R = CreditRules
local DAY = 86400

local function kinds(events)
	local list = {}
	for _, event in ipairs(events) do
		list[#list + 1] = event.kind
	end
	return table.concat(list, ',')
end

-- Configuração dos níveis: pontuação mínima e limite crescentes.
for index = 2, #c.Tiers do
	assert(c.Tiers[index].minScore > c.Tiers[index - 1].minScore, 'minScore crescente')
	assert(c.Tiers[index].limit > c.Tiers[index - 1].limit, 'limite crescente')
end

-- Pontuação
local now = 100 * DAY
eq(R.Score({ now = now }, c), c.Score.HistoryBase, 'só a base do histórico')
eq(R.Score({ now = now, firstAt = now - 30 * DAY, inflow = 20000, balance = 25000, onTime = 7 }, c), 1000, 'pontuação máxima')
eq(R.Score({ now = now, firstAt = now - 30 * DAY, inflow = 20000, balance = 25000, onTime = 7, late = true }, c), 800, 'atraso atual pesa')
eq(R.Score({ now = now, firstAt = now - 300 * DAY, inflow = 1e9, balance = -50, lateCount = 10 }, c), 450, 'teto por componente e piso do histórico')

eq(R.Eligible(175, c), nil, 'sem nível')
eq(R.Eligible(200, c).id, 'essential', 'essencial')
eq(R.Eligible(500, c).id, 'gold', 'gold')
eq(R.Eligible(1000, c).id, 'black', 'black')

-- Estorno: compras em aberto primeiro, depois a fatura fechada
local r = R.New(R.Tier(c, 'essential'), 0, c)
R.Purchase(r, 300)
eq(R.Refund(r, 100), 100, 'estorno aplicado')
eq(r.open, 200, 'estorno abate compras em aberto')
r.invoice = 50
eq(R.Refund(r, 400), 250, 'estorno limitado ao devido')
eq(r.open + r.invoice, 0, 'nada a pagar após estorno')

-- Ciclo: compra, fechamento, mínimo pago em dia
local essential = R.Tier(c, 'essential')
local s = R.New(essential, 0, c)
eq(s.closesAt, 7 * DAY, 'fecha em 7 dias')
eq(R.Available(s), 2000, 'disponível inicial')
eq(R.CanPurchase(s, 2001), false, 'acima do limite')
assert(R.CanPurchase(s, 1000), 'compra permitida')
R.Purchase(s, 1000)
eq(R.Available(s), 1000, 'disponível após compra')
eq(kinds(R.Advance(s, 7 * DAY, c)), 'closed', 'fechamento')
eq(s.invoice, 1000, 'fatura')
eq(s.open, 0, 'compras zeradas')
eq(s.invoiceMin, 150, 'mínimo 15%')
eq(s.dueAt, 10 * DAY, 'vence 3 dias depois')
eq(R.Pay(s, 150), 150, 'pagamento do mínimo')
eq(kinds(R.Advance(s, 10 * DAY, c)), 'on_time', 'pago em dia')
eq(s.onTime, 1, 'contador em dia')

-- Rotativo no próximo fechamento, depois atraso
eq(kinds(R.Advance(s, 14 * DAY, c)), 'revolving_interest,closed', 'rotativo e fechamento')
eq(s.invoice, 918, 'fatura com juros do rotativo')
eq(s.invoiceMin, 138, 'novo mínimo')
eq(s.invoicePaid, 0, 'pago zerado')
eq(kinds(R.Advance(s, 17 * DAY, c)), 'late_fee', 'atraso')
eq(s.invoice, 962, 'multa 2% + fixa')
eq(s.late, true, 'em atraso')
eq(s.lateCount, 1, 'contador de atraso')
eq(select(2, R.CanPurchase(s, 1)), 'credit_late', 'crédito bloqueado')
eq(kinds(R.Advance(s, 18 * DAY, c)), 'late_interest', 'juros diário')
eq(s.invoice, 972, 'juros de 1%')
eq(R.AutoDebitDue(s, 21 * DAY, c), false, 'débito automático ainda não')
eq(R.AutoDebitDue(s, 22 * DAY, c), true, 'débito automático')
eq(R.Pay(s, 138), 138, 'paga o mínimo')
eq(s.late, false, 'sai do atraso')
eq(s.interestAt, nil, 'sem juros pendentes')

-- Pagamento: fatura primeiro, depois compras em aberto; nunca além do devido
local p = R.New(essential, 0, c)
p.invoice, p.open = 100, 50
eq(R.Payable(p), 150, 'a pagar')
eq(R.Pay(p, 500), 150, 'limitado ao devido')
eq(p.invoice, 0, 'fatura quitada')
eq(p.open, 0, 'aberto quitado')

eq(R.MinPayment(0, c), 0, 'mínimo sem fatura')
eq(R.MinPayment(40, c), 40, 'mínimo limitado ao valor')
eq(R.MinPayment(100, c), 50, 'piso do mínimo')

-- Anuidade e pontos
local gold = R.Tier(c, 'gold')
local g = R.New(gold, 0, c)
eq(kinds(R.Advance(g, 7 * DAY, c)), 'annuity,closed', 'anuidade no fechamento')
eq(g.invoice, 30, 'anuidade gold')
eq(R.Points(1000, gold), 15, 'pontos gold')
eq(R.Points(99, essential), 0, 'pontos arredondam para baixo')

-- Sem fatura: fecha sem vencimento
local e = R.New(essential, 0, c)
eq(kinds(R.Advance(e, 7 * DAY, c)), 'closed', 'fechamento vazio')
eq(e.dueAt, nil, 'sem vencimento')
eq(#R.Advance(e, 7 * DAY, c), 0, 'idempotente')

-- Rebaixamento e upgrade
eq(R.Downgrade(g, 340, c).id, 'essential', 'rebaixa abaixo da margem')
eq(R.Downgrade(g, 360, c), nil, 'dentro da margem')
eq(R.Downgrade(e, 0, c), nil, 'essencial não rebaixa')
eq(select(2, R.Upgrade(nil, 100, c)), 'credit_score', 'sem pontuação')
eq(R.Upgrade(nil, 300, c).id, 'essential', 'primeiro cartão')
eq(select(2, R.Upgrade(e, 300, c)), 'credit_no_upgrade', 'já no nível liberado')
eq(R.Upgrade(e, 500, c).id, 'gold', 'upgrade')
e.late = true
eq(select(2, R.Upgrade(e, 900, c)), 'credit_late', 'atraso impede upgrade')
R.SetTier(g, essential)
eq(g.limit, 2000, 'novo limite')

-- Limite personalizado e nível travado pela staff
g.customLimit = 7777
R.SetTier(g, R.Tier(c, 'gold'))
eq(g.limit, 7777, 'personalizado sobrepõe o nível')
g.customLimit = nil
R.Refresh(g, c)
eq(g.limit, R.Tier(c, 'gold').limit, 'refresh volta ao limite do nível')
g.tierLocked = true
eq(R.Downgrade(g, 0, c), nil, 'travado não rebaixa')
g.tierLocked = false

-- Edição dos níveis
local function copyTiers()
	local list = {}
	for index, tier in ipairs(c.Tiers) do
		list[index] = { id = tier.id, label = tier.label, minScore = tier.minScore, limit = tier.limit, pointsPer100 = tier.pointsPer100, fee = tier.fee, freeAtm = tier.freeAtm }
	end
	return list
end
local edited = copyTiers()
edited[1].label = '  Básico  '
edited[2].pointsPer100 = 1.234
local clean = assert(R.ValidateTiers(edited, c))
eq(clean[1].label, 'Básico', 'rótulo aparado')
eq(clean[2].pointsPer100, 1.23, 'pontos com 2 casas')
eq(clean[4].freeAtm, true, 'freeAtm preservado')
local bad = copyTiers(); bad[2].id = 'x'
eq(select(2, R.ValidateTiers(bad, c)), 'invalid_tiers', 'id trocado')
bad = copyTiers(); bad[3].minScore = bad[2].minScore
eq(select(2, R.ValidateTiers(bad, c)), 'invalid_tier_order', 'pontuação não crescente')
bad = copyTiers(); bad[3].limit = bad[2].limit - 1
eq(select(2, R.ValidateTiers(bad, c)), 'invalid_tier_order', 'limite decrescente')
bad = copyTiers(); bad[1].label = '<b>'
eq(select(2, R.ValidateTiers(bad, c)), 'invalid_tier_label', 'rótulo com html')
bad = copyTiers(); bad[1].limit = 1.5
eq(select(2, R.ValidateTiers(bad, c)), 'invalid_tier_values', 'limite fracionado')
bad = copyTiers(); table.remove(bad)
eq(select(2, R.ValidateTiers(bad, c)), 'invalid_tiers', 'faltando nível')
print('credit_test ok')
