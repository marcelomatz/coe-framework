-- Regras do banco básico (sem natives).
dofile('config.lua')
dofile('shared/rules.lua')

local function eq(a, b, m)
	if a ~= b then error(('%s: esperado %s, veio %s'):format(m, tostring(b), tostring(a)), 2) end
end

-- Valor
eq(BankRules.Amount(100, 500), 100, 'valor valido')
eq(BankRules.Amount('250', 500), 250, 'valor em texto')
eq(BankRules.Amount(0, 500), nil, 'zero')
eq(BankRules.Amount(-5, 500), nil, 'negativo')
eq(BankRules.Amount(10.5, 500), nil, 'fracionado')
eq(BankRules.Amount(501, 500), nil, 'acima do teto')
eq(BankRules.Amount(0 / 0, 500), nil, 'NaN')
eq(select(2, BankRules.Amount(nil, 500)), 'invalid_amount', 'codigo do erro')

-- ID de cidadão
eq(BankRules.StateId('k7m2q9xa'), 'K7M2Q9XA', 'maiusculas')
eq(BankRules.StateId(' K7M2-Q9XA '), 'K7M2Q9XA', 'espacos e hifen')
eq(BankRules.StateId('K7M2Q9X'), nil, 'curto')
eq(BankRules.StateId('K7M2Q9XAB'), nil, 'longo')
eq(BankRules.StateId('K7M2Q9X0'), nil, 'zero fora do alfabeto')
eq(BankRules.StateId('K7M2Q9XI'), nil, 'I fora do alfabeto')
eq(BankRules.StateId(12345678), nil, 'numero')
eq(select(2, BankRules.StateId('x')), 'invalid_state_id', 'codigo do erro')

-- Operações por atendimento
eq(BankRules.Allowed('agency', 'transfer'), true, 'agencia transfere')
eq(BankRules.Allowed('agency', 'lookup'), true, 'agencia consulta destinatario')
eq(BankRules.Allowed('atm', 'withdraw'), true, 'caixa saca')
eq(BankRules.Allowed('atm', 'transfer'), false, 'caixa nao transfere')
eq(BankRules.Allowed('atm', 'lookup'), false, 'caixa nao consulta')
eq(BankRules.Allowed('other', 'withdraw'), false, 'modo desconhecido')
eq(BankRules.Allowed('agency', nil), false, 'acao ausente')

-- Agência e distância
eq(BankRules.Agency(BankConfig, 'legion').label, 'Agência Legion Square', 'agencia por id')
eq(BankRules.Agency(BankConfig, 'nope'), nil, 'agencia desconhecida')
eq(BankRules.Agency(BankConfig, 5), nil, 'id invalido')
eq(BankRules.Near({ x = 0, y = 0, z = 0 }, { x = 2, y = 0, z = 0 }, 3), true, 'perto')
eq(BankRules.Near({ x = 0, y = 0, z = 0 }, { x = 4, y = 0, z = 0 }, 3), false, 'longe')
eq(BankRules.Near({ x = 0, y = 0, z = 0 }, { x = 0, y = 0, z = 9 }, 3), false, 'outro andar')
eq(BankRules.Near(nil, { x = 0, y = 0, z = 0 }, 3), false, 'sem coordenada')

-- Atalhos
local quick = BankRules.Quick({ 100, 500, 1000, 5000, 'x', 0 }, 1000)
eq(#quick, 3, 'atalhos acima do teto e invalidos saem')
eq(quick[3], 1000, 'ordem preservada')

-- Extrato
local rows = BankRules.Statement({
	{ delta = '-200', reason = 'bank_withdraw', reference = 'atm', created_at = 1792000000 },
	{ delta = 500, reason = 'bank_transfer', reference = 'state:K7M2Q9XA' },
	{ delta = 1, reason = 'payroll' },
	'lixo'
}, 2)
eq(#rows, 2, 'extrato limitado')
eq(rows[1].delta, -200, 'delta numerico')
eq(rows[1].at, 1792000000, 'data')
eq(rows[2].reference, 'state:K7M2Q9XA', 'referencia')
eq(#BankRules.Statement({ error = 'forbidden' }, 5), 0, 'erro vira lista vazia')
eq(#BankRules.Statement(nil, 5), 0, 'sem extrato')

-- Nome
eq(BankRules.Name('Ana', 'Souza'), 'Ana Souza', 'nome')
eq(BankRules.Name('Ana', nil), 'Ana', 'so primeiro nome')
eq(BankRules.Name('', ''), nil, 'nome vazio')

print('coe_bank rules: ok')
