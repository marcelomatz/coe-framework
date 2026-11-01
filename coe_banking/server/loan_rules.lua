-- Regras dos empréstimos (puras): parcelas fixas a cada `IntervalDays`, juros totais do contrato. Tempos em epoch.
LoanRules = {}

local DAY = 86400

local function integer(value, low, high)
	value = tonumber(value)
	if not value or value ~= value or value % 1 ~= 0 or value < low or value > high then
		return nil
	end
	return math.tointeger(value)
end

-- { principal, rate (% total), installments } validados ou nil + código.
function LoanRules.Validate(input, loans)
	if type(input) ~= 'table' then
		return nil, 'invalid_loan'
	end
	local principal = integer(input.principal, 1, loans.MaxPrincipal)
	local installments = integer(input.installments, 1, loans.MaxInstallments)
	local rate = tonumber(input.rate)
	if not principal or not installments or not rate or rate ~= rate or rate < 0 or rate > loans.MaxRate then
		return nil, 'invalid_loan'
	end
	local note = type(input.note) == 'string' and input.note:gsub('[<>]', ''):sub(1, 64) or ''
	return { principal = principal, rate = math.floor(rate * 100 + 0.5) / 100, installments = installments, note = note }
end

-- Valor da parcela `index` (1..n): o resto da divisão vai nas primeiras.
function LoanRules.Installment(total, count, index)
	local base = total // count
	return base + ((index <= total % count) and 1 or 0)
end

-- Faixa de taxas da pontuação de relacionamento: { rate, lateDailyRate }. Pior relação, juros maiores.
function LoanRules.Pricing(score, loans)
	score = tonumber(score) or 0
	local chosen
	for _, band in ipairs(loans.Pricing or {}) do
		if score >= band.minScore and (not chosen or band.minScore > chosen.minScore) then
			chosen = band
		end
	end
	if not chosen then
		for _, band in ipairs(loans.Pricing or {}) do
			if not chosen or band.minScore < chosen.minScore then
				chosen = band
			end
		end
	end
	return { rate = chosen and chosen.rate or 0, lateDailyRate = chosen and chosen.lateDailyRate or 0 }
end

-- `lateRate`: juros diários (%) da parcela em atraso, fixados no contrato.
function LoanRules.New(input, now, loans, lateRate)
	local total = input.principal + math.tointeger(math.ceil(input.principal * input.rate / 100 - 1e-9))
	return {
		principal = input.principal, rate = input.rate, total = total, installments = input.installments,
		paidCount = 0, paidAmount = 0, remaining = LoanRules.Installment(total, input.installments, 1),
		dueAt = now + loans.IntervalDays * DAY, late = false, onTime = 0, lateCount = 0, status = 'active', note = input.note or '',
		lateRate = tonumber(lateRate) or 0, interest = 0, interestAt = nil
	}
end

-- Saldo devedor: contrato + juros de atraso já lançados - pago.
function LoanRules.Payable(loan)
	return loan.status == 'active' and (loan.total + (loan.interest or 0) - loan.paidAmount) or 0
end

-- Juros diários compostos sobre a parcela em atraso, por dia cheio desde `interestAt`. Devolve o valor lançado.
function LoanRules.Accrue(loan, now, loans)
	if loan.status ~= 'active' or not loan.late or not loan.interestAt or (loan.lateRate or 0) <= 0 or loan.remaining <= 0 then
		return 0
	end
	local days = (now - loan.interestAt) // DAY
	if days <= 0 then
		return 0
	end
	local applied = math.min(days, loans.MaxAccrueDays or days)
	local added = 0
	for _ = 1, applied do
		local charge = math.tointeger(math.ceil(loan.remaining * loan.lateRate / 100 - 1e-9))
		loan.remaining = loan.remaining + charge
		added = added + charge
	end
	loan.interest = (loan.interest or 0) + added
	loan.interestAt = loan.interestAt + applied * DAY
	return added
end

function LoanRules.Due(loan, now)
	return loan.status == 'active' and loan.dueAt ~= nil and loan.dueAt <= now
end

-- Abate parcelas em ordem (pode antecipar). Devolve o valor aplicado e quantas parcelas fechou.
function LoanRules.Pay(loan, amount, loans)
	local applied, closed = 0, 0
	while amount > 0 and loan.status == 'active' do
		local take = math.min(amount, loan.remaining)
		loan.remaining = loan.remaining - take
		loan.paidAmount = loan.paidAmount + take
		amount = amount - take
		applied = applied + take
		if loan.remaining > 0 then
			break
		end
		closed = closed + 1
		loan.paidCount = loan.paidCount + 1
		if not loan.late then
			loan.onTime = loan.onTime + 1
		end
		loan.late = false
		loan.interestAt = nil
		if loan.paidCount >= loan.installments then
			loan.status = 'paid'
			loan.dueAt = nil
		else
			loan.remaining = LoanRules.Installment(loan.total, loan.installments, loan.paidCount + 1)
			loan.dueAt = loan.dueAt + loans.IntervalDays * DAY
		end
	end
	return applied, closed
end

-- Parcela vencida e não paga: entra em atraso (uma vez por parcela). Devolve true se marcou agora.
function LoanRules.Advance(loan, now)
	if LoanRules.Due(loan, now) and not loan.late and loan.remaining > 0 then
		loan.late = true
		loan.lateCount = loan.lateCount + 1
		loan.interestAt = loan.dueAt
		return true
	end
	return false
end

function LoanRules.Forgive(loan)
	if loan.status ~= 'active' then
		return false
	end
	loan.status = 'forgiven'
	loan.late = false
	loan.dueAt = nil
	loan.interestAt = nil
	return true
end
