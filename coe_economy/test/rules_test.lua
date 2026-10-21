dofile('../coe_economy/config.lua')
dofile('../coe_economy/server/rules.lua')

local function eq(a, b, m)
	if a ~= b then error(('%s: esperado %s, veio %s'):format(m, tostring(b), tostring(a)), 2) end
end

local c = EconomyConfig
eq(EconomyRules.Amount(10, c), 10, 'inteiro')
eq(select(2, EconomyRules.Amount(0, c)), 'invalid_amount', 'zero')
eq(select(2, EconomyRules.Amount(-5, c)), 'invalid_amount', 'negativo')
eq(select(2, EconomyRules.Amount(1.5, c)), 'invalid_amount', 'fracao')
eq(select(2, EconomyRules.Amount(c.MaxAmount + 1, c)), 'invalid_amount', 'acima do maximo')
eq(select(2, EconomyRules.Amount('10', c)), 'invalid_amount', 'string')
eq(select(2, EconomyRules.Amount(0 / 0, c)), 'invalid_amount', 'nan')

eq(EconomyRules.Reason('rent_payment'), 'rent_payment', 'motivo')
eq(select(2, EconomyRules.Reason('Rent payment')), 'invalid_reason', 'motivo invalido')
eq(select(2, EconomyRules.Reason(nil)), 'invalid_reason', 'motivo nil')

eq(EconomyRules.Reference(nil), '', 'ref vazia')
eq(EconomyRules.Reference('house:12'), 'house:12', 'ref')
eq(select(2, EconomyRules.Reference("x'; --")), 'invalid_reference', 'ref invalida')

eq(EconomyRules.CharacterId(7), '7', 'id numero')
eq(EconomyRules.CharacterId('42'), '42', 'id texto')
eq(select(2, EconomyRules.CharacterId('0')), 'invalid_character', 'id zero')
eq(select(2, EconomyRules.CharacterId('1 OR 1')), 'invalid_character', 'id injecao')

eq(EconomyRules.CanCredit(c.MaxBalance, 1, c), false, 'teto')
eq(EconomyRules.CanCredit(10, 5, c), true, 'dentro do teto')

eq(EconomyRules.BusinessId('mecanica_a'), 'mecanica_a', 'id de negocio')
eq(select(2, EconomyRules.BusinessId('Mec')), 'invalid_business', 'id de negocio invalido')
eq(select(2, EconomyRules.BusinessId("a'; --")), 'invalid_business', 'id de negocio injecao')

local plan = EconomyRules.PayrollPlan({
	{ characterId = '1', salary = 400, onDuty = true },
	{ characterId = '2', salary = 300, onDuty = false },
	{ characterId = '3', salary = 500, onDuty = true },
	{ characterId = '4', salary = 100, onDuty = true },
	{ characterId = '5', salary = 0, onDuty = true }
}, 600)
eq(#plan.payments, 2, 'paga quem tem saldo')
eq(plan.total, 500, 'total pago')
eq(plan.skipped[1].reason, 'off_duty', 'fora de ponto nao recebe')
eq(plan.skipped[2].reason, 'insufficient_funds', 'sem saldo nao recebe')
eq(#plan.skipped, 2, 'salario zero nao entra')
eq(#EconomyRules.PayrollPlan({ { characterId = '1', salary = 10, onDuty = true } }, 0).payments, 0, 'sociedade vazia')

-- Persistência: transações da sociedade sem personagem (ex.: bank_loan em SocietyCollect) não podem ter buracos nil nos parâmetros
local lastTransaction
_G.GetResourceState = function(name) return name == 'coe_database' and 'started' or 'missing' end
_G.promise = { new = function() return { value = nil, resolve = function(self, v) self.value = v end } end }
_G.Citizen = { Await = function(p) return p.value end }
_G.exports = {
	coe_database = {
		Transaction = function(_, statements, cb)
			lastTransaction = statements
			cb(true, { { affectedRows = 1 }, { affectedRows = 1 } }, nil)
		end
	}
}
dofile('../coe_economy/server/persistence.lua')

local function assertDenseStatements(statements, label)
	for idx, stmt in ipairs(statements) do
		local maxKey, count = 0, 0
		for k in pairs(stmt.parameters) do
			assert(type(k) == 'number' and k >= 1 and k % 1 == 0, label .. ': chave inválida')
			count = count + 1
			if k > maxKey then maxKey = k end
		end
		eq(count, maxKey, label .. ' statement #' .. idx .. ' sem buracos nil')
		local _, placeholders = stmt.sql:gsub('%?', '')
		eq(count, placeholders, label .. ' statement #' .. idx .. ' quantidade de ?')
	end
end

assert(EconomyPersistence.SocietyCredit('mecanica_a', 50000, 'bank_loan', '', 'coe_banking'))
assertDenseStatements(lastTransaction, 'SocietyCredit')
assert(lastTransaction[2].sql:find('VALUES (?, NULL, ?, ?, ?, ?)', 1, true), 'SocietyCredit usa NULL literal quando characterId é nil')

assert(EconomyPersistence.SocietyDebit('mecanica_a', 12500, 'loan_payment', 'loan:1', 'coe_banking'))
assertDenseStatements(lastTransaction, 'SocietyDebit')

assert(EconomyPersistence.SocietyDeposit('mecanica_a', '42', 1000, 'society_deposit', '', 'coe_banking'))
assertDenseStatements(lastTransaction, 'SocietyDeposit')

assert(EconomyPersistence.SocietyTransfer('mecanica_a', 'loja_b', 900, 'bank_transfer', 'bop:7', 'coe_banking'))
assertDenseStatements(lastTransaction, 'SocietyTransfer')
eq(#lastTransaction, 4, 'transferência entre empresas: dois saldos e dois extratos')

-- Filtro do extrato da conta empresarial
local filter = EconomyRules.LedgerFilter({ direction = 'out', days = 7, limit = 50, beforeId = 120, reasons = { 'payroll', 'bank_transfer' } })
eq(filter.direction, 'out', 'filtro: saídas')
eq(filter.days, 7, 'filtro: período')
eq(filter.limit, 50, 'filtro: linhas')
eq(filter.beforeId, 120, 'filtro: página')
eq(#filter.reasons, 2, 'filtro: motivos')
local default = EconomyRules.LedgerFilter({ direction = 'x', days = 9999, limit = 0, reasons = { 'Bad Reason' } })
eq(default.direction, nil, 'filtro: direção inválida vira todas')
eq(default.days, 30, 'filtro: período padrão')
eq(default.limit, 25, 'filtro: linhas padrão')
eq(default.reasons, nil, 'filtro: motivo inválido descarta a lista')
eq(EconomyRules.LedgerFilter(nil).days, 30, 'filtro: sem filtro')

print('economy rules ok')

