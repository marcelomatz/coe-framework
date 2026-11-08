-- Testes do server/main.lua do coe_economy: guardas de acesso, validação de valores e movimentação de saldo.
-- Persistência em memória; rodar a partir da pasta do resource: lua test/server_test.lua

local function eq(actual, expected, message)
	if actual ~= expected then
		error(('%s: esperado %s, veio %s'):format(message, tostring(expected), tostring(actual)), 2)
	end
end

local registered, threads, audits = {}, {}, {}
local invoker = 'coe_banking'
local aces = {}

exports = setmetatable({}, {
	__call = function(_, name, fn) registered[name] = fn end,
	__index = function(_, res)
		if res == 'coe_audit' then
			return { Record = function(_, _, _, event, context) audits[#audits + 1] = { event = event, context = context } end }
		end
		return { Log = function() end, Notify = function() end }
	end
})
GetInvokingResource = function() return invoker end
IsPrincipalAceAllowed = function(principal, ace) return aces[principal .. '|' .. ace] == true end
GetResourceState = function() return 'stopped' end
GetGameTimer = function() return 0 end
CreateThread = function(fn) threads[#threads + 1] = fn end
RegisterCommand = function() end
RegisterNetEvent = function() end
AddEventHandler = function() end
-- Loops periódicos (folha etc.) param no primeiro Wait; a thread de inicialização não espera.
Wait = function() error('wait_called') end

-- Persistência em memória com a mesma interface usada pelo main.lua.
local balances, frozenBalances, ledger = {}, {}, {}
local persistenceReady = true
EconomyPersistence = {
	Initialize = function() return persistenceReady, persistenceReady and nil or 'database_not_ready' end,
	EnsureAccount = function(id, starting)
		if balances[id] == nil then
			balances[id] = starting
			frozenBalances[id] = 0
		end
		return true
	end,
	Balance = function(id) return balances[id] end,
	FrozenBalance = function(id) return frozenBalances[id] or 0 end,
	FreezeFunds = function(id, amount)
		if (balances[id] or 0) - (frozenBalances[id] or 0) < amount then
			return nil, 'insufficient_funds'
		end
		frozenBalances[id] = (frozenBalances[id] or 0) + amount
		return true
	end,
	UnfreezeFunds = function(id, amount)
		if (frozenBalances[id] or 0) < amount then
			return nil, 'insufficient_frozen_funds'
		end
		frozenBalances[id] = (frozenBalances[id] or 0) - amount
		return true
	end,
	Credit = function(id, amount, reason, reference, source)
		balances[id] = balances[id] + amount
		ledger[#ledger + 1] = { id = id, delta = amount, reason = reason, source = source }
		return true
	end,
	Debit = function(id, amount, reason, reference, source)
		if balances[id] < amount then
			return nil, 'insufficient_funds'
		end
		balances[id] = balances[id] - amount
		ledger[#ledger + 1] = { id = id, delta = -amount, reason = reason, source = source }
		return true
	end,
	Transfer = function(from, to, amount, reason, reference, source)
		balances[from] = balances[from] - amount
		balances[to] = balances[to] + amount
		return true
	end,
	Ledger = function(id, limit)
		local rows = {}
		for i = #ledger, 1, -1 do
			if ledger[i].id == id and #rows < limit then
				rows[#rows + 1] = ledger[i]
			end
		end
		return rows
	end,
	LedgerStats = function() return { inflow = 0 } end
}

dofile('../coe_core/lib/access.lua')
dofile('config.lua')
dofile('locales/pt-br.lua')
dofile('server/rules.lua')
dofile('server/main.lua')

local cfg = EconomyConfig

-- 1. Antes do banco ficar pronto, nada movimenta dinheiro.
eq(select(2, registered.Credit('1', 100, 'test_credit')), 'not_ready', 'credit antes do ready')
for _, fn in ipairs(threads) do
	pcall(fn)
end
eq(registered.IsReady(), true, 'pronto depois do Initialize')

-- 2. Resource sem allowlist nem ACE é recusado em todos os exports de dinheiro.
invoker = 'script_qualquer'
eq(select(2, registered.Credit('1', 100, 'test_credit')), 'forbidden', 'credit recusado')
eq(select(2, registered.Debit('1', 100, 'test_debit')), 'forbidden', 'debit recusado')
eq(select(2, registered.Transfer('1', '2', 100, 'test_transfer')), 'forbidden', 'transfer recusado')
eq(select(2, registered.GetBalance('1')), 'forbidden', 'saldo recusado')
eq(registered.Ledger('1').error, 'forbidden', 'extrato recusado')
eq(registered.IsReady(), false, 'IsReady não confirma para quem não tem acesso')
eq(balances['1'], nil, 'nenhuma conta criada por chamador recusado')

-- ACE concedida no server.cfg libera o mesmo resource.
aces['resource.script_qualquer|' .. cfg.Ace.Money] = true
CoeAccess.Reset()
eq(registered.GetBalance('1'), cfg.StartingBalance, 'ACE coe.economy.money libera o saldo')
aces = {}
CoeAccess.Reset()
invoker = 'coe_banking'

-- 3. Validação dos argumentos.
for _, bad in ipairs({ 0, -10, 1.5, '10', 0 / 0, cfg.MaxAmount + 1 }) do
	eq(select(2, registered.Credit('1', bad, 'test_credit')), 'invalid_amount', 'valor inválido ' .. tostring(bad))
end
eq(select(2, registered.Credit('1 OR 1', 10, 'test_credit')), 'invalid_character', 'id inválido')
eq(select(2, registered.Credit('1', 10, 'Texto Livre')), 'invalid_reason', 'motivo inválido')
eq(select(2, registered.Credit('1', 10, 'ok', "x'; --")), 'invalid_reference', 'referência inválida')

-- 4. Crédito, débito e saldo insuficiente.
local start = registered.GetBalance('1')
eq(registered.Credit('1', 500, 'test_credit', 'ref:1'), true, 'crédito')
eq(registered.GetBalance('1'), start + 500, 'saldo após crédito')
eq(registered.Debit('1', 200, 'test_debit'), true, 'débito')
eq(registered.GetBalance('1'), start + 300, 'saldo após débito')
eq(select(2, registered.Debit('1', start + 301, 'test_debit')), 'insufficient_funds', 'débito acima do saldo')
eq(registered.GetBalance('1'), start + 300, 'saldo intacto após recusa')
eq(audits[#audits].event, 'money_debited', 'débito auditado')

-- 5. Teto de saldo.
balances['3'] = cfg.MaxBalance
eq(select(2, registered.Credit('3', 1, 'test_credit')), 'balance_limit', 'crédito acima do teto')

-- 6. Transferência.
eq(select(2, registered.Transfer('1', '1', 10, 'test_transfer')), 'same_account', 'mesma conta')
eq(select(2, registered.Transfer('1', '2', start + 1000, 'test_transfer')), 'insufficient_funds', 'transferência sem saldo')
eq(registered.Transfer('1', '2', 100, 'test_transfer'), true, 'transferência')
eq(registered.GetBalance('2'), cfg.StartingBalance + 100, 'destino creditado')
eq(select(2, registered.Transfer('1', '3', 1, 'test_transfer')), 'balance_limit', 'destino no teto')

-- 7. Extrato limitado.
local rows = registered.Ledger('1', 1000)
eq(#rows <= 100, true, 'limite do extrato')

-- 8. Bloqueio judicial (FreezeFunds / UnfreezeFunds).
local curBal = registered.GetBalance('1')
eq(registered.FreezeFunds('1', 500, 'judicial_freeze', 'warrant:10'), true, 'congela 500')
eq(registered.GetFrozenBalance('1'), 500, 'saldo congelado = 500')
eq(select(2, registered.Debit('1', curBal - 200, 'test_debit')), 'funds_frozen', 'recusa débito que invade fatia congelada')
eq(registered.Debit('1', curBal - 500, 'test_debit'), true, 'permite gastar saldo livre não congelado')
eq(registered.UnfreezeFunds('1', 500, 'judicial_unfreeze', 'warrant:10'), true, 'desbloqueia 500')
eq(registered.GetFrozenBalance('1'), 0, 'saldo congelado zerado')
eq(registered.Debit('1', 500, 'test_debit'), true, 'permite gastar após desbloqueio')

-- 8. Cadeia forense SHA-256 anexada automaticamente às auditorias de transações
local auditChain = {}
for _, item in ipairs(audits) do
	if item.context and item.context.hash then
		auditChain[#auditChain + 1] = item.context
	end
end
eq(#auditChain >= 3, true, 'transações geram elos na cadeia forense')
eq(EconomyRules.VerifyForensicChain(auditChain), true, 'cadeia forense de auditoria íntegra de ponta a ponta')

io.write('coe_economy server_test: ok\n')
