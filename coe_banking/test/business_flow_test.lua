-- Conta empresarial (server/business.lua) com o banco, a economia, os negócios e o inventário simulados.
local events, exported, handlers = {}, {}, {}
local invoking = nil
RegisterNetEvent = function(name, fn) events[name] = fn end
AddEventHandler = function(name, fn) handlers[name] = fn end
exports = function(name, fn) exported[name] = fn end
GetInvokingResource = function() return invoking end
TriggerClientEvent = function() end
CreateThread = function() end
SetTimeout = function() end
Wait = function() end

dofile('config.lua')
dofile('server/rules.lua')
dofile('server/loan_rules.lua')
dofile('server/business_rules.lua')

local failures = 0
local function eq(actual, expected, message)
	if actual ~= expected then
		failures = failures + 1
		print(('FAIL %s: esperado %s, obtido %s'):format(message, tostring(expected), tostring(actual)))
	end
end

-- Mundo simulado ---------------------------------------------------------------------------------------
local society = { bennys = 10000, loja = 500 }
local accounts = { ['1'] = 2000, ['2'] = 300, ['9'] = 0 }
local cash = { [11] = 400 }
local items = {}
local ledger = {}
local notices = {}
local businesses = {
	bennys = { id = 'bennys', label = "Benny's", category = 'mechanic', enabled = true,
		owner = { characterId = '1', name = 'Dona Ana' },
		staff = { { characterId = '2', name = 'Beto', grade = 'mecanico' } }, partners = {} },
	loja = { id = 'loja', label = 'Lojinha', enabled = true, staff = {}, partners = {} }
}
local grants = { ['2'] = { ['banking.transfer'] = true } }

local function economyResult(ok, code)
	return ok and true or { error = code }
end

local remotes = {
	coe_businesses = {
		Get = function(id) return businesses[id] end,
		List = function() return { businesses.bennys, businesses.loja } end,
		Access = function(id, characterId)
			local business = businesses[id]
			local owner = business.owner and business.owner.characterId == characterId
			local staff = false
			for _, member in ipairs(business.staff) do
				staff = staff or member.characterId == characterId
			end
			return { owner = owner, staff = staff, partner = false }
		end,
		Can = function(id, characterId, permission)
			local business = businesses[id]
			if business.owner and business.owner.characterId == characterId then
				return true
			end
			return (grants[characterId] or {})[permission] == true
		end,
		Payroll = function(id)
			return { { characterId = '2', name = 'Beto', grade = 'mecanico', salary = 400 } }
		end,
		IsOnDuty = function() return true end,
		IsReady = function() return true end,
		RegisterPermissions = function() return true end
	},
	coe_economy = {
		SocietyBalance = function(id) return society[id] or 0 end,
		BankSocietyDeposit = function(id, characterId, amount, reason, reference)
			if accounts[characterId] < amount then return { error = 'insufficient_funds' } end
			accounts[characterId] = accounts[characterId] - amount
			society[id] = society[id] + amount
			ledger[#ledger + 1] = { id = #ledger + 1, delta = amount, reason = reason, reference = reference, characterId = characterId }
			return true
		end,
		BankSocietyPay = function(id, characterId, amount, reason, reference)
			if society[id] < amount then return { error = 'insufficient_funds' } end
			society[id] = society[id] - amount
			accounts[characterId] = (accounts[characterId] or 0) + amount
			ledger[#ledger + 1] = { id = #ledger + 1, delta = -amount, reason = reason, reference = reference, characterId = characterId }
			return true
		end,
		BankSocietyDebit = function(id, amount, reason, reference)
			if society[id] < amount then return { error = 'insufficient_funds' } end
			society[id] = society[id] - amount
			ledger[#ledger + 1] = { id = #ledger + 1, delta = -amount, reason = reason, reference = reference }
			return true
		end,
		BankSocietyCredit = function(id, amount, reason, reference)
			society[id] = society[id] + amount
			ledger[#ledger + 1] = { id = #ledger + 1, delta = amount, reason = reason, reference = reference }
			return true
		end,
		BankSocietyTransfer = function(from, to, amount, reason, reference)
			if society[from] < amount then return { error = 'insufficient_funds' } end
			society[from] = society[from] - amount
			society[to] = society[to] + amount
			ledger[#ledger + 1] = { id = #ledger + 1, delta = -amount, reason = reason, reference = reference }
			return true
		end,
		BankSocietyLedger = function(id, filter)
			local rows = {}
			for index = #ledger, 1, -1 do
				rows[#rows + 1] = ledger[index]
			end
			return { rows = rows, totals = { inflow = 0, outflow = 0, count = #rows } }
		end,
		RunPayroll = function() return { paid = 1, total = 400, skipped = {} } end
	},
	coe_inventory = {
		AddItem = function(inventoryId, name, count, metadata)
			if name == 'money' then
				cash[inventoryId] = (cash[inventoryId] or 0) + count
			else
				items[#items + 1] = { name = name, metadata = metadata }
			end
			return true
		end,
		RemoveItemByName = function(inventoryId, name, count)
			if (cash[inventoryId] or 0) < count then return false end
			cash[inventoryId] = cash[inventoryId] - count
			return true
		end
	}
}

local cards, ops = {}, {}
BankingPersistence = {
	InsertBusinessOp = function(op) ops[#ops + 1] = op; op.status = 'pending'; return #ops end,
	FinishBusinessOp = function(id, status) ops[id].status = status; return true end,
	BusinessOps = function(ids)
		local found = {}
		for _, id in ipairs(ids) do
			local op = ops[id]
			found[id] = { id = id, actorName = op.actorName or '', counterpartyLabel = op.counterpartyLabel or '', memo = op.memo or '' }
		end
		return found
	end,
	CharacterNames = function() return {} end,
	FindCharacterByStateId = function(stateId)
		if stateId == 'ABC123' then return { characterId = '9', name = 'Cid Fornecedor' } end
		return nil, 'character_not_found'
	end,
	CountBusinessCards = function(id) local n = 0; for _, card in ipairs(cards) do if card.accountRef == id then n = n + 1 end end; return n end,
	InsertCard = function(card) cards[#cards + 1] = card; card.id = #cards; card.spentAmount = 0; return #cards end,
	BusinessCards = function(id) local list = {}; for _, card in ipairs(cards) do if card.accountRef == id then list[#list + 1] = card end end; return list end,
	Card = function(id) return cards[id] end,
	Block = function(id, reason) cards[id].blockedReason = reason; return true end,
	SetAttempts = function() return true end,
	SetDailyLimit = function(id, limit) cards[id].dailyLimit = limit > 0 and limit or nil; return true end,
	Spend = function(id, amount, day)
		local card = cards[id]
		local spent = card.spentDay == day and card.spentAmount or 0
		if card.dailyLimit and spent + amount > card.dailyLimit then return false end
		card.spentAmount, card.spentDay = spent + amount, day
		return true
	end,
	Unspend = function(id, amount) cards[id].spentAmount = math.max(0, cards[id].spentAmount - amount); return true end,
	BusinessLoans = function() return {} end,
	Requests = function() return {} end
}

BankingServer = {
	isReady = function() return true end,
	messages = { not_ready = 'x', no_character = 'x', not_staff = 'x', busy = 'x', database_error = 'x' },
	busy = {},
	agencyOpen = {}, agencyAccount = {},
	log = function() end, audit = function() end,
	notify = function(playerId, kind, message) notices[#notices + 1] = { playerId = playerId, kind = kind, message = message } end,
	money = function(value) return '$ ' .. value end,
	remote = function(resource, name, ...)
		return remotes[resource][name](...)
	end,
	throttled = function() return false end,
	character = function(playerId)
		if playerId == 11 then return { characterId = '1', name = 'Dona Ana' } end
		if playerId == 12 then return { characterId = '2', name = 'Beto' } end
	end,
	playerOf = function() return nil end,
	inventoryOf = function(playerId) return playerId end,
	cashOf = function(inventoryId) return cash[inventoryId] or 0 end,
	digit = function() return 3 end,
	hashKey = function(text) return #text end,
	cardView = function(card) return { id = card.id, last4 = '3333', holder = card.holderName, status = BankingRules.Status(card), blockedReason = card.blockedReason } end,
	loanView = function(loan) return loan end,
	businessDebtors = function() return { '1' } end,
	debtorsScore = function() return 500 end,
	requestView = function(request) return request end
}

dofile('server/business.lua')
local B = BankingBusiness

-- Permissões -----------------------------------------------------------------------------------------
local business, owner = B.Rights('bennys', '1')
eq(owner.withdraw and owner.cards and owner.payroll and owner.requestLoans, true, 'dono tem tudo')
local _, staff = B.Rights('bennys', '2')
eq(staff.transfer, true, 'cargo com banking.transfer transfere')
eq(staff.withdraw, false, 'cargo sem banking.withdraw não saca')
eq(staff.view, true, 'qualquer permissão bancária vê a conta')
eq(B.Rights('bennys', '9'), nil, 'de fora não acessa')
eq(#B.Accounts('2'), 1, 'contas empresariais da pessoa')

local function ctx(playerId, rights, channel)
	return { playerId = playerId, who = BankingServer.character(playerId), business = business, rights = rights, channel = channel or 'agency' }
end

-- Depósito e saque ---------------------------------------------------------------------------------------
eq(B.Actions.deposit(ctx(12, staff), { amount = 200, method = 'account' }), nil, 'depósito pela conta')
eq(society.bennys, 10200, 'caixa recebeu')
eq(accounts['2'], 100, 'conta de quem depositou')
eq(ops[#ops].status, 'done', 'operação concluída')
eq(ledger[#ledger].reference, 'bop:' .. #ops, 'extrato ligado à operação')
eq(B.Actions.withdraw(ctx(12, staff), { amount = 50 }), 'forbidden', 'equipe sem permissão não saca')
eq(B.Actions.withdraw(ctx(11, owner), { amount = 100, method = 'cash' }), nil, 'dono saca em espécie na agência')
eq(cash[11], 500, 'espécie entregue')
eq(B.Actions.withdraw(ctx(11, owner, 'tablet'), { amount = 100, method = 'cash' }), 'agency_only', 'espécie só na agência')
eq(B.Actions.deposit(ctx(11, owner), { amount = 9999, method = 'cash' }), 'insufficient_cash', 'sem espécie')

-- Transferências ------------------------------------------------------------------------------------------
eq(B.Actions.transfer(ctx(12, staff), { amount = 300, target = { kind = 'person', stateId = 'abc123' }, memo = 'peças' }), nil, 'paga fornecedor')
eq(accounts['9'], 300, 'fornecedor recebeu')
eq(ops[#ops].counterpartyLabel, 'Cid Fornecedor', 'registro com destinatário')
eq(ops[#ops].memo, 'peças', 'registro com descrição')
eq(B.Actions.transfer(ctx(12, staff), { amount = 10, target = { kind = 'business', id = 'bennys' } }), 'same_account', 'não transfere para si')
eq(B.Actions.transfer(ctx(12, staff), { amount = 10, target = { kind = 'person', stateId = 'ZZZZ99' } }), 'character_not_found', 'identidade desconhecida')
eq(B.Actions.transfer(ctx(11, owner), { amount = 1000, target = { kind = 'business', id = 'loja' } }), nil, 'paga outra empresa')
eq(society.loja, 1500, 'outra empresa recebeu')
eq(B.Actions.transfer(ctx(11, owner), { amount = 999999, target = { kind = 'business', id = 'loja' } }), 'insufficient_funds', 'sem saldo: a operação falha')
eq(ops[#ops].status, 'failed', 'operação marcada como falha')

-- Folha e bônus --------------------------------------------------------------------------------------------
eq(B.Actions.bonus(ctx(12, staff), { characterId = '2', amount = 50 }), 'forbidden', 'equipe sem banking.payroll')
eq(B.Actions.bonus(ctx(11, owner), { characterId = '9', amount = 50 }), 'not_staff_member', 'bônus só para quem é do negócio')
eq(B.Actions.bonus(ctx(11, owner), { characterId = '2', amount = 50, memo = 'meta' }), nil, 'bônus pago')
eq(B.Actions.payrollRun(ctx(11, owner), {}), nil, 'folha manual')

-- Cartões ---------------------------------------------------------------------------------------------------
local before = society.bennys
eq(B.Actions.issueCard(ctx(11, owner, 'tablet'), { holderId = '2', pin = '1234', dailyLimit = 500 }), 'agency_only', 'cartão só na agência')
eq(B.Actions.issueCard(ctx(11, owner), { holderId = '9', pin = '1234', dailyLimit = 500 }), 'not_staff_member', 'titular precisa ser do negócio')
eq(B.Actions.issueCard(ctx(11, owner), { holderId = '2', pin = '12', dailyLimit = 500 }), 'invalid_pin', 'senha inválida')
eq(B.Actions.issueCard(ctx(11, owner), { holderId = '2', pin = '1234', dailyLimit = 500 }), nil, 'cartão emitido')
eq(society.bennys, before - BankingConfig.Business.CardFee, 'tarifa sai do caixa')
eq(items[#items].metadata.business, "Benny's", 'cartão no inventário de quem pediu')
local card = cards[1]
eq(card.accountType, 'business', 'conta empresarial')
eq(card.holderId, '2', 'titular')
eq(card.dailyLimit, 500, 'limite diário')

-- Caixa eletrônico com o cartão: limite do dia
cash[12] = 0
eq(B.AtmWithdraw(12, card, { amount = 300 }, BankingServer.character(12)), nil, 'saque no limite')
eq(cash[12], 300, 'espécie no caixa eletrônico')
eq(B.AtmWithdraw(12, card, { amount = 300 }, BankingServer.character(12)), 'card_daily_limit', 'passa do limite do dia')
eq(card.spentAmount, 300, 'gasto do dia mantido')
eq(B.Actions.cardLimit(ctx(11, owner), { cardId = card.id, dailyLimit = 1000 }), nil, 'aumenta o limite')
eq(B.AtmWithdraw(12, card, { amount = 300 }, BankingServer.character(12)), nil, 'com limite maior, saca')

-- Compra pela carteira
local purchase = B.CardPurchase({ card = card, amount = 100, label = 'ferramentas' })
eq(purchase.ok, true, 'compra no débito da empresa')
eq(B.CardPurchase({ card = card, amount = 1000, label = 'x' }).error, 'card_daily_limit', 'compra acima do limite')
eq(B.CardRefund({ card = card, amount = 100, label = 'ferramentas' }).ok, true, 'estorno')

-- Titular saiu do negócio: o cartão para
businesses.bennys.staff = {}
eq(select(2, B.CardUsable(card)), 'card_holder_left', 'titular fora do negócio')
eq(B.AtmWithdraw(12, card, { amount = 10 }, BankingServer.character(12)), 'card_holder_left', 'saque recusado')
eq(B.CardPurchase({ card = card, amount = 10, label = 'x' }).error, 'card_holder_left', 'compra recusada')
businesses.bennys.staff = { { characterId = '2', name = 'Beto', grade = 'mecanico' } }

eq(B.Actions.cardBlock(ctx(12, staff), { cardId = card.id }), 'forbidden', 'equipe sem banking.cards não bloqueia')
eq(B.Actions.cardBlock(ctx(11, owner), { cardId = card.id }), nil, 'dono bloqueia')
eq(card.blockedReason, 'lost', 'cartão bloqueado')

-- Visão ---------------------------------------------------------------------------------------------------
local view = B.View(business, owner, BankingServer.character(11), nil)
eq(view.mode, 'business', 'modo empresarial')
eq(view.balance, society.bennys, 'saldo do caixa')
eq(#view.cards, 1, 'cartões listados')
eq(view.payroll.due, 400, 'folha prevista')
local withActor = nil
for _, entry in ipairs(view.statement) do
	if entry.memo == 'peças' then withActor = entry end
end
eq(withActor and withActor.actor, 'Beto', 'extrato mostra quem fez')
eq(withActor and withActor.counterparty, 'Cid Fornecedor', 'extrato mostra o destinatário')
eq(view.loanOffer ~= nil, true, 'dono vê o pedido de empréstimo')
local staffView = B.View(business, staff, BankingServer.character(12), nil)
eq(staffView.payroll, nil, 'equipe sem folha não vê a folha')
eq(staffView.loanOffer, nil, 'equipe não pede empréstimo')

-- App do negócio no tablet: só o coe_businesses chama
invoking = 'coe_tablet'
eq(exported.BusinessTablet(12, '2', 'bennys', { op = 'overview' }).error, 'forbidden', 'outro resource não chama')
invoking = 'coe_businesses'
local result = exported.BusinessTablet(12, '2', 'bennys', { op = 'overview' })
eq(result.ok, true, 'visão pelo tablet')
eq(result.bank.mode, 'business', 'conta no tablet')
eq(exported.BusinessTablet(12, '1', 'bennys', { op = 'overview' }).error, 'no_character', 'personagem do payload confere com o jogador')
eq(exported.BusinessTablet(12, '2', 'bennys', { op = 'issueCard' }).error, 'unknown_action', 'cartão não se emite pelo tablet')
local paid = exported.BusinessTablet(12, '2', 'bennys', { op = 'transfer', amount = 10, target = { kind = 'person', stateId = 'ABC123' } })
eq(paid.ok, true, 'pagamento pelo tablet')
invoking = 'coe_admin'
eq(exported.AdminBusinessAdjust('bennys', -50, 'correção'), true, 'ajuste da staff')
eq(type(exported.AdminBusinessAccounts().accounts), 'table', 'lista de contas no admin')

if failures > 0 then
	error(('business_flow_test: %d falha(s)'):format(failures))
end
print('coe_banking business_flow_test: ok')
