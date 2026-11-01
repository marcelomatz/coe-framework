dofile('../coe_banking/config.lua')
dofile('../coe_banking/server/loan_rules.lua')

local function eq(a, b, m)
	if a ~= b then error(('%s: esperado %s, veio %s'):format(m, tostring(b), tostring(a)), 2) end
end

local L = LoanRules
local cfg = BankingConfig.Loans
local DAY = 86400
local WEEK = cfg.IntervalDays * DAY

-- Validação
eq(select(2, L.Validate({ principal = 0, rate = 10, installments = 4 }, cfg)), 'invalid_loan', 'principal zero')
eq(select(2, L.Validate({ principal = 1000, rate = cfg.MaxRate + 1, installments = 4 }, cfg)), 'invalid_loan', 'juros acima do teto')
eq(select(2, L.Validate({ principal = 1000, rate = 10, installments = cfg.MaxInstallments + 1 }, cfg)), 'invalid_loan', 'parcelas acima do teto')
eq(select(2, L.Validate({ principal = 10.5, rate = 10, installments = 4 }, cfg)), 'invalid_loan', 'principal fracionado')
local input = assert(L.Validate({ principal = 1000, rate = 10.555, installments = 3, note = '<x>casa' }, cfg))
eq(input.rate, 10.56, 'juros com 2 casas')
eq(input.note, 'xcasa', 'nota sem html')

-- Parcelas: total 1106 em 3 = 369, 369, 368
local loan = L.New(input, 0, cfg)
eq(loan.total, 1106, 'total com juros arredondado pra cima')
eq(loan.remaining, 369, 'primeira parcela leva o resto')
eq(L.Installment(1106, 3, 3), 368, 'última parcela')
eq(loan.dueAt, WEEK, 'vence em uma semana')
eq(L.Payable(loan), 1106, 'a pagar')

-- Pagamento parcial não fecha parcela
eq(L.Pay(loan, 100, cfg), 100, 'aplicou parcial')
eq(loan.remaining, 269, 'resto da parcela')
eq(loan.paidCount, 0, 'parcela aberta')

-- Vence sem pagar: atraso uma vez só
eq(L.Advance(loan, WEEK - 1), false, 'antes do vencimento')
eq(L.Advance(loan, WEEK), true, 'entra em atraso')
eq(L.Advance(loan, WEEK + DAY), false, 'não marca de novo')
eq(loan.lateCount, 1, 'um atraso')

-- Paga a parcela atrasada: não conta em dia, próxima vence uma semana depois da anterior
local applied, closed = L.Pay(loan, 269, cfg)
eq(applied, 269, 'aplicou'); eq(closed, 1, 'fechou uma')
eq(loan.late, false, 'atraso limpo'); eq(loan.onTime, 0, 'não foi em dia')
eq(loan.dueAt, 2 * WEEK, 'próximo vencimento'); eq(loan.remaining, 369, 'segunda parcela')

-- Quitação antecipada com troco: aplica só o devido
applied, closed = L.Pay(loan, 5000, cfg)
eq(applied, 737, 'aplicou o saldo'); eq(closed, 2, 'fechou duas')
eq(loan.status, 'paid', 'quitado'); eq(loan.onTime, 2, 'duas em dia')
eq(loan.dueAt, nil, 'sem vencimento'); eq(loan.paidAmount, 1106, 'pago total')
eq(L.Payable(loan), 0, 'nada a pagar'); eq(L.Due(loan, 99 * WEEK), false, 'quitado não vence')

-- Juros zero e perdão
local zero = L.New(assert(L.Validate({ principal = 10, rate = 0, installments = 4 }, cfg)), 0, cfg)
eq(zero.total, 10, 'sem juros'); eq(zero.remaining, 3, '3,3,2,2')
eq(L.Forgive(zero), true, 'perdoado'); eq(zero.status, 'forgiven', 'status perdoado')
eq(L.Forgive(zero), false, 'já encerrado'); eq(L.Payable(zero), 0, 'perdoado não cobra')

-- Taxas pelo relacionamento: pior pontuação, juros maiores
local best, mid, worst = L.Pricing(950, cfg), L.Pricing(500, cfg), L.Pricing(0, cfg)
assert(best.rate < mid.rate and mid.rate < worst.rate, 'juros do contrato caem com a pontuação')
assert(best.lateDailyRate < mid.lateDailyRate and mid.lateDailyRate < worst.lateDailyRate, 'juros de atraso caem com a pontuação')
eq(L.Pricing(-5, cfg).rate, worst.rate, 'abaixo de tudo usa a pior faixa')
eq(L.Pricing(800, cfg).rate, best.rate, 'limite da faixa entra na faixa')

-- Juros diários compostos sobre a parcela em atraso
local late = L.New(assert(L.Validate({ principal = 1000, rate = 0, installments = 2 }, cfg)), 0, cfg, 10)
eq(late.lateRate, 10, 'taxa de atraso fixada no contrato')
eq(L.Accrue(late, WEEK + 5 * DAY, cfg), 0, 'sem atraso marcado não cobra')
eq(L.Advance(late, WEEK), true, 'atrasou')
eq(late.interestAt, WEEK, 'juros contam do vencimento')
eq(L.Accrue(late, WEEK + DAY - 1, cfg), 0, 'menos de um dia cheio')
eq(L.Accrue(late, WEEK + 2 * DAY + 10, cfg), 105, '500 -> 550 -> 605')
eq(late.remaining, 605, 'parcela com juros'); eq(late.interest, 105, 'juros acumulados')
eq(late.interestAt, WEEK + 2 * DAY, 'próximo dia de juros')
eq(L.Accrue(late, WEEK + 2 * DAY + 10, cfg), 0, 'não cobra duas vezes no mesmo dia')
eq(L.Payable(late), 1105, 'saldo devedor inclui juros')
eq(L.Pay(late, 605, cfg), 605, 'pagou a parcela com juros')
eq(late.late, false, 'atraso limpo'); eq(late.interestAt, nil, 'para de cobrar juros')
eq(late.remaining, 500, 'próxima parcela sem juros')
eq(L.Accrue(late, 99 * WEEK, cfg), 0, 'em dia não cobra')
eq(L.Pay(late, 500, cfg), 500, 'quitou'); eq(late.status, 'paid', 'quitado'); eq(late.paidAmount, 1105, 'pagou contrato + juros')

-- Teto de dias por cálculo: o restante fica para o próximo
local capped = L.New(assert(L.Validate({ principal = 100, rate = 0, installments = 1 }, cfg)), 0, cfg, 1)
L.Advance(capped, WEEK)
L.Accrue(capped, WEEK + (cfg.MaxAccrueDays + 10) * DAY, cfg)
eq(capped.interestAt, WEEK + cfg.MaxAccrueDays * DAY, 'cobra no máximo o teto por vez')
L.Accrue(capped, WEEK + (cfg.MaxAccrueDays + 10) * DAY, cfg)
eq(capped.interestAt, WEEK + (cfg.MaxAccrueDays + 10) * DAY, 'o restante entra no próximo cálculo')
eq(L.Forgive(capped), true, 'perdoa com juros'); eq(capped.interestAt, nil, 'perdoado para de cobrar')

print('loan_test ok')