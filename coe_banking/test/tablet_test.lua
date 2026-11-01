dofile('../coe_banking/config.lua')
dofile('../coe_banking/server/rules.lua')
dofile('../coe_banking/server/tablet.lua')

local function eq(a, b, m)
	if a ~= b then error(('%s: esperado %s, veio %s'):format(m, tostring(b), tostring(a)), 2) end
end

local callerName = 'coe_tablet'
local isReady = true
local busy = {}
local isThrottled = false
local characters = {
	[1] = { characterId = '10', name = 'Fulano' }
}
local balances = { ['10'] = 5000 }
local loggedError = nil

local actions = {
	transfer = function(_, who, data)
		local amount, amountError = BankingRules.Amount(data.amount, BankingConfig.MaxAgencyAmount)
		if not amount then
			return amountError
		end
		local stateId, stateError = BankingRules.StateId(data.stateId)
		if not stateId then
			return stateError
		end
		if balances[who.characterId] < amount then
			return 'insufficient_funds'
		end
		balances[who.characterId] = balances[who.characterId] - amount
		return nil
	end,
	blockCard = function(_, _, data)
		if data.boom then
			error('falha simulada no banco')
		end
		return nil
	end
}

local deps = {
	caller = function() return callerName end,
	ready = function() return isReady end,
	busy = busy,
	throttled = function() return isThrottled end,
	character = function(source) return characters[source] end,
	actions = actions,
	view = function(who)
		return {
			holder = who.name,
			balance = balances[who.characterId],
			maxAmount = BankingConfig.MaxAgencyAmount
		}
	end,
	messages = {
		not_ready = 'Banco indisponível.',
		busy = 'Aguarde.',
		no_character = 'Sem personagem.',
		amount_too_high = 'Valor acima do limite.',
		invalid_amount = 'Valor inválido.',
		insufficient_funds = 'Saldo insuficiente.',
		database_error = 'Erro interno.'
	},
	log = function(_, _, event, ctx)
		loggedError = { event = event, ctx = ctx }
	end
}

-- Caller restrito ao coe_tablet e appId
callerName = 'coe_phone'
eq(BankingTablet.Call(deps, 1, 'bank', 'overview').error, 'forbidden', 'caller fora do coe_tablet')
callerName = 'coe_tablet'
eq(BankingTablet.Call(deps, 1, 'vehicles', 'overview').error, 'forbidden', 'appId errado')

-- Estado ready
isReady = false
local notReady = BankingTablet.Call(deps, 1, 'bank', 'overview')
eq(notReady.ok, false, 'not_ready ok=false')
eq(notReady.error, 'not_ready', 'not_ready code')
eq(notReady.message, 'Banco indisponível.', 'not_ready message')
isReady = true

-- Ações desconhecidas ou de dinheiro físico (withdraw/deposit não são aceitas no tablet)
eq(BankingTablet.Call(deps, 1, 'bank', 'withdraw', { amount = 100 }).error, 'unknown_action', 'saque recusado no tablet')
eq(BankingTablet.Call(deps, 1, 'bank', 'deposit', { amount = 100 }).error, 'unknown_action', 'deposito recusado no tablet')
eq(BankingTablet.Call(deps, 1, 'bank', 'hack').error, 'unknown_action', 'acao inexistente')
eq(BankingTablet.Call(deps, 1, 'bank', nil).error, 'unknown_action', 'acao nula')

-- Sem personagem ativo
eq(BankingTablet.Call(deps, 99, 'bank', 'overview').error, 'no_character', 'sem personagem')

-- Overview ignora throttle, mas ações de escrita respeitam throttle e busy
isThrottled = true
local ov = BankingTablet.Call(deps, 1, 'bank', 'overview')
eq(ov.ok, true, 'overview passa mesmo com throttle')
eq(ov.bank.balance, 5000, 'saldo inicial no overview')
eq(BankingTablet.Call(deps, 1, 'bank', 'transfer', { amount = 100, stateId = 'AB12CD' }).error, 'busy', 'transfer bloqueado por throttle')
isThrottled = false

busy[1] = true
eq(BankingTablet.Call(deps, 1, 'bank', 'overview').error, 'busy', 'overview bloqueado quando busy')
busy[1] = nil

-- Validação de limites de valor na transferência e retorno da visão atualizada
local high = BankingTablet.Call(deps, 1, 'bank', 'transfer', { amount = BankingConfig.MaxAgencyAmount + 1, stateId = 'AB12CD' })
eq(high.ok, false, 'acima do limite falha')
eq(high.error, 'invalid_amount', 'erro invalid_amount acima do teto')
eq(high.message, 'Valor inválido.', 'mensagem traduzida')
eq(high.bank.balance, 5000, 'visao continua retornada em erro de regra')

local invalid = BankingTablet.Call(deps, 1, 'bank', 'transfer', { amount = -10, stateId = 'AB12CD' })
eq(invalid.error, 'invalid_amount', 'valor negativo recusado')

local okTransfer = BankingTablet.Call(deps, 1, 'bank', 'transfer', { amount = 1200, stateId = 'AB12CD' })
eq(okTransfer.ok, true, 'transferencia valida')
eq(okTransfer.error, nil, 'sem erro')
eq(okTransfer.bank.balance, 3800, 'saldo atualizado na resposta')

-- Exceção inesperada limpa o lock busy e retorna database_error
local crash = BankingTablet.Call(deps, 1, 'bank', 'blockCard', { boom = true })
eq(crash.ok, false, 'excecao capturada')
eq(crash.error, 'database_error', 'retorna database_error')
eq(busy[1], nil, 'busy limpo apos falha')
eq(loggedError and loggedError.event, 'tablet_failed', 'erro registrado no log')

print('banking tablet_test ok')
