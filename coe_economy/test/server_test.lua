-- Testes do server/main.lua do coe_economy: guardas de acesso, validação de valores e movimentação de saldo.
-- Persistência em memória; rodar a partir da pasta do resource: lua test/server_test.lua

local function eq(actual, expected, message)
	if actual ~= expected then
		error(('%s: esperado %s, veio %s'):format(message, tostring(expected), tostring(actual)), 2)
	end
end

local registered, threads, audits = {}, {}, {}
local invoker = 'coe_bank'
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
local balances, ledger = {}, {}
local persistenceReady = true
EconomyPersistence = {
	Initialize = function() return persistenceReady, persistenceReady and nil or 'database_not_ready' end,
	EnsureAccount = function(id, starting)
		if balances[id] == nil then
			balances[id] = starting
		end
		return true
	end,
	Balance = function(id) return balances[id] end,
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
invoker = 'coe_bank'

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

io.write('coe_economy server_test: ok\n')
