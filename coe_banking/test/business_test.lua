dofile('config.lua')
dofile('server/business_rules.lua')

local settings = BankingConfig.Business
local failures = 0
local function eq(actual, expected, message)
	if actual ~= expected then
		failures = failures + 1
		print(('FAIL %s: esperado %s, obtido %s'):format(message, tostring(expected), tostring(actual)))
	end
end

-- Permissões
local granted = { ['banking.transfer'] = true }
local rights = BusinessRules.Rights(function(permission) return granted[permission] end, true, 'business.funds')
eq(rights.transfer, true, 'cargo com transferência')
eq(rights.view, true, 'qualquer permissão bancária libera ver a conta')
eq(rights.cards, false, 'sem cartões')
eq(rights.deposit, true, 'quem é do negócio deposita')
local legacy = BusinessRules.Rights(function(permission) return permission == 'business.funds' end, true, 'business.funds')
eq(legacy.cards and legacy.payroll and legacy.withdraw and legacy.loans, true, 'business.funds antigo tem tudo')
local none = BusinessRules.Rights(function() return false end, false, 'business.funds')
eq(none.view, false, 'sem cargo não vê')
eq(none.deposit, false, 'de fora não deposita')
eq(#BusinessRules.Permissions, 6, 'seis permissões')
for _, permission in ipairs(BusinessRules.Permissions) do
	eq(permission.name:sub(1, 8), 'banking.', 'prefixo do resource em ' .. permission.name)
	eq(#permission.label <= 64, true, 'rótulo cabe no coe_businesses: ' .. permission.name)
end

-- Limite diário do cartão
local now = 1800000000
local today = BusinessRules.Day(now)
eq(BusinessRules.SpentToday({ spentAmount = 900, spentDay = today }, now), 900, 'gasto de hoje')
eq(BusinessRules.SpentToday({ spentAmount = 900, spentDay = today - 1 }, now), 0, 'zera no outro dia')
eq(BusinessRules.Remaining({ dailyLimit = 1000, spentAmount = 900, spentDay = today }, now), 100, 'resta no limite')
eq(BusinessRules.Remaining({ dailyLimit = 1000, spentAmount = 1500, spentDay = today }, now), 0, 'nunca negativo')
eq(BusinessRules.Remaining({ spentAmount = 900, spentDay = today }, now), nil, 'sem limite')
eq(BusinessRules.DailyLimit(0, settings), 0, 'zero = sem limite')
eq(BusinessRules.DailyLimit('2500', settings), 2500, 'limite em texto')
eq(select(2, BusinessRules.DailyLimit(-1, settings)), 'invalid_limit', 'negativo')
eq(select(2, BusinessRules.DailyLimit(settings.MaxDailyLimit + 1, settings)), 'invalid_limit', 'acima do teto')
eq(select(2, BusinessRules.DailyLimit(1.5, settings)), 'invalid_limit', 'fracionado')

-- Destino e observação
eq(BusinessRules.Target({ kind = 'person', stateId = ' ab12cd ' }).stateId, 'AB12CD', 'identidade limpa')
eq(BusinessRules.Target({ kind = 'business', id = 'bennys' }).id, 'bennys', 'empresa')
eq(select(2, BusinessRules.Target({ kind = 'business', id = "x'; --" })), 'invalid_target', 'id de empresa inválido')
eq(select(2, BusinessRules.Target({ kind = 'person', stateId = '!!' })), 'invalid_state_id', 'identidade inválida')
eq(select(2, BusinessRules.Target({ kind = 'alien' })), 'invalid_target', 'tipo inválido')
eq(BusinessRules.Memo('  peças <b>do\nmês</b> ', 48), 'peças b do mês /b', 'observação limpa')
eq(BusinessRules.Memo(5, 48), '', 'observação não texto')

-- Extrato
eq(BusinessRules.CategoryOf('payroll'), 'payroll', 'folha')
eq(BusinessRules.CategoryOf('business_card'), 'cards', 'cartão')
eq(BusinessRules.CategoryOf('qualquer'), 'other', 'outros')
local filter = BusinessRules.Filter({ category = 'payroll', direction = 'out', days = 7, beforeId = 33 }, settings)
eq(filter.days, 7, 'período')
eq(filter.direction, 'out', 'direção')
eq(filter.category, 'payroll', 'categoria')
eq(#filter.reasons, 2, 'motivos da categoria')
eq(filter.beforeId, 33, 'página')
eq(filter.limit, settings.StatementPage, 'linhas por página')
local default = BusinessRules.Filter({ category = 'x', days = 3, direction = 'up' }, settings)
eq(default.category, nil, 'categoria inválida')
eq(default.days, settings.Periods[#settings.Periods], 'período inválido usa o maior')
eq(default.direction, nil, 'direção inválida')
eq(BusinessRules.OpId('bop:42'), 42, 'referência de operação')
eq(BusinessRules.OpId('loan:42'), nil, 'outra referência')

-- Folha prevista
local preview = BusinessRules.PayrollPreview({
	{ characterId = '1', name = 'Bia', salary = 500, onDuty = false },
	{ characterId = '2', name = 'Ana', salary = 300, onDuty = true },
	{ characterId = '3', name = 'Caio', salary = 0, onDuty = true }
}, 200)
eq(preview.due, 300, 'só quem está de ponto recebe agora')
eq(preview.total, 800, 'folha cheia')
eq(preview.covered, false, 'caixa não cobre')
eq(preview.members[1].name, 'Ana', 'de ponto primeiro')

if failures > 0 then
	error(('business_test: %d falha(s)'):format(failures))
end
print('coe_banking business_test: ok')
