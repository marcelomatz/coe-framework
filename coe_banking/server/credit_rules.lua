-- Regras do crédito (puras): pontuação, níveis, fatura e atraso. Tempos em segundos (epoch).
CreditRules = {}

local DAY = 86400

local function ceil(value)
	return math.tointeger(math.ceil(value - 1e-9)) or 0
end

local function clamp(value, low, high)
	return math.max(low, math.min(high, value))
end

function CreditRules.Tier(credit, tierId)
	for index, tier in ipairs(credit.Tiers) do
		if tier.id == tierId then
			return tier, index
		end
	end
	return nil
end

-- Pontuação de relacionamento 0..1000.
-- input: { now, firstAt (epoch do 1º lançamento ou nil), inflow, balance, onTime, lateCount, late }
function CreditRules.Score(input, credit)
	local s = credit.Score
	local ageDays = input.firstAt and math.max(0, (input.now - input.firstAt) / DAY) or 0
	local age = math.min(ageDays / s.AgeDays, 1) * s.AgePoints
	local inflow = math.min(math.max(input.inflow or 0, 0) / s.InflowTarget, 1) * s.InflowPoints
	local balance = math.min(math.max(input.balance or 0, 0) / s.BalanceTarget, 1) * s.BalancePoints
	local history = clamp(s.HistoryBase + (input.onTime or 0) * s.OnTimePoints - (input.lateCount or 0) * s.LatePenalty, 0, s.HistoryMax)
	local total = age + inflow + balance + history - (input.late and s.LateNowPenalty or 0)
	return math.tointeger(math.floor(clamp(total, 0, 1000))) or 0
end

-- Maior nível liberado pela pontuação (nil se nenhum).
function CreditRules.Eligible(score, credit)
	local best
	for _, tier in ipairs(credit.Tiers) do
		if score >= tier.minScore then
			best = tier
		end
	end
	return best
end

function CreditRules.New(tier, now, credit)
	return {
		tier = tier.id, limit = tier.limit, open = 0, invoice = 0, invoiceMin = 0, invoicePaid = 0,
		dueAt = nil, closesAt = now + credit.CycleDays * DAY, late = false, lateSince = nil, interestAt = nil,
		onTime = 0, lateCount = 0, points = 0
	}
end

function CreditRules.Available(state)
	return math.max(0, state.limit - state.open - state.invoice)
end

-- Compra no crédito: bloqueada em atraso ou acima do disponível.
function CreditRules.CanPurchase(state, amount)
	if state.late then
		return false, 'credit_late'
	end
	if amount > CreditRules.Available(state) then
		return false, 'credit_limit'
	end
	return true
end

function CreditRules.Purchase(state, amount)
	state.open = state.open + amount
end

-- Pontos de uma compra no crédito.
function CreditRules.Points(amount, tier)
	return math.tointeger(math.floor(amount * tier.pointsPer100 / 100)) or 0
end

-- Estorno de compra no crédito: abate das compras em aberto e depois da fatura fechada. Devolve o valor aplicado.
function CreditRules.Refund(state, amount)
	local fromOpen = math.min(amount, state.open)
	state.open = state.open - fromOpen
	local fromInvoice = math.min(amount - fromOpen, state.invoice)
	state.invoice = state.invoice - fromInvoice
	return fromOpen + fromInvoice
end

-- Quanto pode ser pago agora: fatura fechada e depois compras em aberto.
function CreditRules.Payable(state)
	return state.invoice + state.open
end

-- Abate o pagamento (fatura primeiro). Pagar o mínimo tira do atraso. Devolve o valor aplicado.
function CreditRules.Pay(state, amount)
	local applied = math.min(amount, CreditRules.Payable(state))
	local toInvoice = math.min(applied, state.invoice)
	state.invoice = state.invoice - toInvoice
	state.invoicePaid = state.invoicePaid + toInvoice
	state.open = state.open - (applied - toInvoice)
	if state.late and (state.invoicePaid >= state.invoiceMin or state.invoice == 0) then
		state.late = false
		state.lateSince = nil
		state.interestAt = nil
	end
	return applied
end

function CreditRules.MinPayment(amount, credit)
	if amount <= 0 then
		return 0
	end
	return math.min(amount, math.max(ceil(amount * credit.MinPaymentRate), credit.MinPaymentFloor))
end

-- Processa em ordem cronológica vencimento, juros de atraso e fechamento até `now`.
-- Devolve a lista de eventos { kind, amount, at } (kinds: on_time, late_fee, late_interest, revolving_interest, annuity, closed).
function CreditRules.Advance(state, now, credit)
	local events = {}
	local function push(kind, amount, at)
		events[#events + 1] = { kind = kind, amount = amount, at = at }
	end
	for _ = 1, 1000 do
		local nextAt, kind = state.closesAt, 'close'
		if state.dueAt and state.dueAt <= nextAt then
			nextAt, kind = state.dueAt, 'due'
		end
		if state.late and state.interestAt and state.interestAt < nextAt then
			nextAt, kind = state.interestAt, 'interest'
		end
		if nextAt > now then
			break
		end
		if kind == 'due' then
			state.dueAt = nil
			if state.invoicePaid >= state.invoiceMin or state.invoice == 0 then
				state.onTime = state.onTime + 1
				push('on_time', 0, nextAt)
			else
				local fee = ceil(state.invoice * credit.LateFeeRate) + credit.LateFeeFlat
				state.invoice = state.invoice + fee
				state.late = true
				state.lateSince = nextAt
				state.interestAt = nextAt + DAY
				state.lateCount = state.lateCount + 1
				push('late_fee', fee, nextAt)
			end
		elseif kind == 'interest' then
			local interest = ceil(state.invoice * credit.LateDailyRate)
			state.invoice = state.invoice + interest
			state.interestAt = nextAt + DAY
			if interest > 0 then
				push('late_interest', interest, nextAt)
			end
		else
			local carried = state.invoice
			if carried > 0 and not state.late then
				local interest = ceil(carried * credit.RevolvingRate)
				state.invoice = state.invoice + interest
				if interest > 0 then
					push('revolving_interest', interest, nextAt)
				end
			end
			local tier = CreditRules.Tier(credit, state.tier)
			local fee = tier and tier.fee or 0
			if fee > 0 then
				state.invoice = state.invoice + fee
				push('annuity', fee, nextAt)
			end
			state.invoice = state.invoice + state.open
			state.open = 0
			state.invoiceMin = CreditRules.MinPayment(state.invoice, credit)
			state.invoicePaid = 0
			state.dueAt = (state.invoice > 0 and not state.late) and nextAt + credit.DueDays * DAY or nil
			state.closesAt = nextAt + credit.CycleDays * DAY
			push('closed', state.invoice, nextAt)
		end
	end
	return events
end

-- Débito automático: em atraso há `AutoDebitDays` dias ou mais.
function CreditRules.AutoDebitDue(state, now, credit)
	return state.late and state.lateSince ~= nil and now - state.lateSince >= credit.AutoDebitDays * DAY and state.invoice > 0
end

-- Rebaixa um nível quando a pontuação cai abaixo do mínimo do nível menos a margem. Devolve o novo nível ou nil.
-- Nível travado pela staff nunca rebaixa.
function CreditRules.Downgrade(state, score, credit)
	if state.tierLocked then
		return nil
	end
	local tier, index = CreditRules.Tier(credit, state.tier)
	if not tier or index <= 1 or score >= tier.minScore - credit.DowngradeMargin then
		return nil
	end
	return credit.Tiers[index - 1]
end

-- Pedido de cartão de crédito ou de upgrade: só para um nível maior liberado e sem atraso.
function CreditRules.Upgrade(state, score, credit)
	local target = CreditRules.Eligible(score, credit)
	if not target then
		return nil, 'credit_score'
	end
	if state then
		if state.late then
			return nil, 'credit_late'
		end
		local _, current = CreditRules.Tier(credit, state.tier)
		local _, wanted = CreditRules.Tier(credit, target.id)
		if current and wanted <= current then
			return nil, 'credit_no_upgrade'
		end
	end
	return target
end

function CreditRules.SetTier(state, tier)
	state.tier = tier.id
	state.limit = state.customLimit or tier.limit
end

-- Limite efetivo: o personalizado da staff ou o do nível atual (níveis podem ter sido editados).
function CreditRules.Refresh(state, credit)
	local tier = CreditRules.Tier(credit, state.tier)
	state.limit = state.customLimit or (tier and tier.limit) or state.limit
	return state
end

local function integer(value, low, high)
	value = tonumber(value)
	if not value or value ~= value or value % 1 ~= 0 or value < low or value > high then
		return nil
	end
	return math.tointeger(value)
end

-- Níveis editados no admin: mesmos ids e ordem do atual, pontuação mínima e limite crescentes.
-- Devolve a lista limpa ou nil + código.
function CreditRules.ValidateTiers(list, credit)
	if type(list) ~= 'table' or #list ~= #credit.Tiers then
		return nil, 'invalid_tiers'
	end
	local clean = {}
	for index, current in ipairs(credit.Tiers) do
		local raw = list[index]
		if type(raw) ~= 'table' or raw.id ~= current.id then
			return nil, 'invalid_tiers'
		end
		local label = type(raw.label) == 'string' and raw.label:gsub('^%s+', ''):gsub('%s+$', '') or ''
		if #label < 1 or #label > 24 or label:find('[<>]') then
			return nil, 'invalid_tier_label'
		end
		local minScore = integer(raw.minScore, 0, 1000)
		local limit = integer(raw.limit, 0, credit.AdminMaxLimit)
		local fee = integer(raw.fee, 0, credit.AdminMaxLimit)
		local points = tonumber(raw.pointsPer100)
		if not minScore or not limit or not fee then
			return nil, 'invalid_tier_values'
		end
		if not points or points ~= points or points < 0 or points > 100 then
			return nil, 'invalid_tier_values'
		end
		local previous = clean[index - 1]
		if previous and (minScore <= previous.minScore or limit < previous.limit) then
			return nil, 'invalid_tier_order'
		end
		clean[index] = {
			id = current.id, label = label, minScore = minScore, limit = limit,
			pointsPer100 = math.floor(points * 100 + 0.5) / 100, fee = fee, freeAtm = raw.freeAtm == true
		}
	end
	return clean
end
