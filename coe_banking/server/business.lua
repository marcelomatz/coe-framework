-- Conta bancária empresarial: o caixa do negócio (sociedade do coe_economy) com acesso próprio, separado da conta
-- pessoal. Agência (escolha da conta ao abrir), caixa eletrônico com cartão empresarial, app do negócio no tablet
-- (via coe_businesses) e admin. Quem pode cada operação: permissões de cargo banking.* (BusinessRules.Rights).
-- Usa os helpers do server/main.lua expostos em BankingServer (carregado antes).
local config = BankingConfig
local settings = config.Business
local loanConfig = config.Loans

BankingBusiness = {}

local function S()
	return BankingServer
end

local function remote(...)
	return S().remote(...)
end

local function money(value)
	return S().money(value)
end

local function _t(key, params)
	return (S().t and S().t(key, params)) or key
end

local function businessGet(businessId)
	if type(businessId) ~= 'string' then
		return nil
	end
	local business = remote('coe_businesses', 'Get', businessId)
	if type(business) ~= 'table' or business.enabled == false then
		return nil
	end
	return business
end

local function can(businessId, characterId, permission)
	return remote('coe_businesses', 'Can', businessId, characterId, permission) == true
end

-- Negócio + o que o personagem pode fazer nele, ou nil se ele não é dono, equipe nem sócio.
function BankingBusiness.Rights(businessId, characterId)
	local business = businessGet(businessId)
	if not business then
		return nil
	end
	local access = remote('coe_businesses', 'Access', businessId, characterId)
	if type(access) ~= 'table' or not (access.owner or access.staff or access.partner) then
		return nil
	end
	local member = access.owner == true or access.staff == true
	local rights = BusinessRules.Rights(function(permission)
		return can(businessId, characterId, permission)
	end, member, settings.LegacyPermission)
	-- Sócio responde pelas dívidas: acompanha a conta mesmo sem cargo.
	if access.partner then
		rights.view = true
	end
	rights.owner, rights.partner, rights.staff = access.owner == true, access.partner == true, access.staff == true
	rights.requestLoans = access.owner == true
	return business, rights
end

local function roleLabel(rights)
	return rights.owner and 'Proprietário' or rights.partner and 'Sócio' or 'Equipe'
end

-- Contas empresariais que o personagem pode abrir (para a escolha na agência).
function BankingBusiness.Accounts(characterId)
	local list = {}
	for _, business in ipairs(remote('coe_businesses', 'List') or {}) do
		if business.enabled ~= false then
			local access = remote('coe_businesses', 'Access', business.id, characterId)
			if type(access) == 'table' and (access.owner or access.staff or access.partner) then
				list[#list + 1] = {
					id = business.id, label = business.label or business.id, category = business.category,
					role = access.owner and 'Proprietário' or access.partner and 'Sócio' or 'Equipe'
				}
			end
		end
	end
	table.sort(list, function(a, b) return a.label < b.label end)
	return list
end

local function societyBalance(businessId)
	local balance = remote('coe_economy', 'SocietyBalance', businessId)
	return type(balance) == 'number' and balance or nil
end

local function economyError(result)
	return type(result) == 'table' and result.error or 'economy_unavailable'
end

-- Pessoas do negócio (dono e equipe): titulares de cartão e quem recebe bônus.
local function members(business)
	local list, seen = {}, {}
	local function add(characterId, name, role)
		characterId = characterId and tostring(characterId)
		if characterId and not seen[characterId] then
			seen[characterId] = true
			list[#list + 1] = { characterId = characterId, name = name or ('#' .. characterId), role = role }
		end
	end
	if type(business.owner) == 'table' then
		add(business.owner.characterId, business.owner.name, 'Proprietário')
	end
	for _, member in ipairs(business.staff or {}) do
		add(member.characterId, member.name, member.grade or 'Equipe')
	end
	return list
end

local function isMember(business, characterId)
	for _, member in ipairs(members(business)) do
		if member.characterId == tostring(characterId) then
			return member
		end
	end
	return nil
end

-- Operação registrada (quem fez, para quem, observação) e o dinheiro movido com a referência `bop:<id>`.
-- run(reference) devolve true ou { error }. Sem registro, a operação não acontece.
local function withOp(op, run)
	local opId, insertError = BankingPersistence.InsertBusinessOp(op, os.time())
	if not opId then
		return insertError or 'database_error'
	end
	local result = run('bop:' .. opId)
	if result ~= true then
		BankingPersistence.FinishBusinessOp(opId, 'failed')
		return economyError(result)
	end
	BankingPersistence.FinishBusinessOp(opId, 'done')
	return nil
end

-- Espécie no inventário do jogador.
local function giveCash(playerId, amount)
	local inventoryId = S().inventoryOf(playerId)
	return inventoryId ~= nil and remote('coe_inventory', 'AddItem', inventoryId, 'money', amount) == true
end

local function takeCash(playerId, amount)
	local inventoryId = S().inventoryOf(playerId)
	if not inventoryId or S().cashOf(inventoryId) < amount then
		return false
	end
	return remote('coe_inventory', 'RemoveItemByName', inventoryId, 'money', amount) == true
end

-- Cartões ------------------------------------------------------------------------------------------

local function cardView(card, now, business)
	local view = S().cardView(card)
	view.holderId = card.holderId
	view.dailyLimit = card.dailyLimit
	view.spentToday = BusinessRules.SpentToday(card, now)
	view.remaining = BusinessRules.Remaining(card, now)
	view.holderActive = business and isMember(business, card.holderId) ~= nil or nil
	return view
end

-- O cartão empresarial ainda vale? Negócio ativo e titular ainda no negócio.
function BankingBusiness.CardUsable(card)
	local business = businessGet(card.accountRef)
	if not business then
		return nil, 'unknown_business'
	end
	if not isMember(business, card.holderId) then
		return nil, 'card_holder_left'
	end
	return business
end

local function businessCard(businessId, cardId)
	local id = BankingRules.CardId(cardId)
	if not id then
		return nil, 'card_not_found'
	end
	local card, cardError = BankingPersistence.Card(id)
	if not card then
		return nil, cardError
	end
	if card.accountType ~= 'business' or card.accountRef ~= businessId then
		return nil, 'card_not_found'
	end
	return card
end

-- Extrato -------------------------------------------------------------------------------------------

local function statementPage(businessId, filter)
	local page = remote('coe_economy', 'BankSocietyLedger', businessId, {
		direction = filter.direction, reasons = filter.reasons, days = filter.days, limit = filter.limit, beforeId = filter.beforeId
	})
	if type(page) ~= 'table' or page.error then
		return { rows = {}, totals = { inflow = 0, outflow = 0, count = 0 }, unavailable = true }
	end
	local opIds, characterIds, seen = {}, {}, {}
	for _, row in ipairs(page.rows or {}) do
		local opId = BusinessRules.OpId(row.reference)
		if opId then
			opIds[#opIds + 1] = opId
		elseif row.characterId and not seen[row.characterId] then
			seen[row.characterId] = true
			characterIds[#characterIds + 1] = row.characterId
		end
	end
	local ops = BankingPersistence.BusinessOps(opIds) or {}
	local names = BankingPersistence.CharacterNames(characterIds) or {}
	local rows = {}
	for _, row in ipairs(page.rows or {}) do
		local op = ops[BusinessRules.OpId(row.reference) or 0]
		rows[#rows + 1] = {
			id = row.id, delta = row.delta, reason = row.reason, at = row.at, category = BusinessRules.CategoryOf(row.reason),
			actor = op and op.actorName ~= '' and op.actorName or nil,
			counterparty = op and op.counterpartyLabel ~= '' and op.counterpartyLabel or (row.characterId and names[row.characterId]) or nil,
			memo = op and op.memo ~= '' and op.memo or nil
		}
	end
	return {
		rows = rows, totals = page.totals,
		nextBefore = #rows >= filter.limit and rows[#rows].id or nil
	}
end

local function payrollView(business, balance)
	local entries = {}
	for _, member in ipairs(remote('coe_businesses', 'Payroll', business.id) or {}) do
		entries[#entries + 1] = {
			characterId = tostring(member.characterId), name = member.name, grade = member.grade, salary = tonumber(member.salary) or 0,
			onDuty = remote('coe_businesses', 'IsOnDuty', business.id, tostring(member.characterId)) == true
		}
	end
	local preview = BusinessRules.PayrollPreview(entries, balance)
	local history = statementPage(business.id, { reasons = { 'payroll', 'business_bonus' }, days = 30, limit = 15 })
	preview.history = history.rows
	preview.paid30 = history.totals.outflow
	return preview
end

-- Visão da conta para a NUI (agência, tablet e admin). `filter` vem da última consulta do extrato.
function BankingBusiness.View(business, rights, who, filter, extra)
	local now = os.time()
	local balance = societyBalance(business.id)
	filter = filter or BusinessRules.Filter(nil, settings)
	local view = {
		mode = 'business',
		holder = who and who.name or nil,
		business = {
			id = business.id, label = business.label or business.id, category = business.category, role = roleLabel(rights),
			owner = type(business.owner) == 'table' and business.owner.name or nil
		},
		rights = {
			view = rights.view, deposit = rights.deposit, withdraw = rights.withdraw, transfer = rights.transfer, cards = rights.cards,
			loans = rights.loans, payroll = rights.payroll, requestLoans = rights.requestLoans
		},
		balance = rights.view and balance or nil,
		limits = {
			maxAmount = config.MaxAgencyAmount, maxTransfer = settings.MaxTransfer, memoMax = settings.MemoMax, cardFee = settings.CardFee,
			defaultDailyLimit = settings.DefaultDailyLimit, maxDailyLimit = settings.MaxDailyLimit, maxCards = settings.MaxCards,
			cardValidityDays = config.CardValidityDays
		},
		periods = settings.Periods,
		categories = {}
	}
	for _, category in ipairs(BusinessRules.Categories) do
		view.categories[#view.categories + 1] = { id = category.id, label = category.label }
	end
	for key, value in pairs(extra or {}) do
		view[key] = value
	end
	if not rights.view then
		return view
	end
	local page = statementPage(business.id, filter)
	view.filter = { category = filter.category, direction = filter.direction, days = filter.days, beforeId = filter.beforeId }
	view.statement = page.rows
	view.nextBefore = page.nextBefore
	view.report = { inflow = page.totals.inflow, outflow = page.totals.outflow, net = page.totals.inflow - page.totals.outflow, count = page.totals.count, days = filter.days }

	local cards = {}
	for _, card in ipairs(BankingPersistence.BusinessCards(business.id, 50) or {}) do
		cards[#cards + 1] = cardView(card, now, business)
	end
	view.cards = cards
	if rights.cards or rights.payroll then
		view.members = members(business)
	end
	if rights.payroll then
		view.payroll = payrollView(business, balance)
	end
	view.loans = {}
	for _, loan in ipairs(BankingPersistence.BusinessLoans(business.id, 5) or {}) do
		if loan.status == 'active' then
			view.loans[#view.loans + 1] = S().loanView(loan, now)
		end
	end
	if rights.requestLoans then
		local debtors = S().businessDebtors(business.id) or { who and who.characterId }
		local score = S().debtorsScore(debtors)
		local pending = BankingPersistence.Requests('pending', business.id, 1) or {}
		local last = BankingPersistence.Requests(nil, business.id, 1) or {}
		view.loanOffer = {
			score = score, pricing = LoanRules.Pricing(score, loanConfig), debtors = #debtors,
			maxPrincipal = loanConfig.MaxPrincipal, maxInstallments = loanConfig.MaxInstallments, intervalDays = loanConfig.IntervalDays,
			pending = pending[1] and S().requestView(pending[1]) or nil,
			last = last[1] and last[1].status ~= 'pending' and S().requestView(last[1]) or nil
		}
	end
	return view
end

-- Ações -----------------------------------------------------------------------------------------------
-- ctx = { playerId, who, business, rights, channel = 'agency' | 'tablet', agency? }. Devolvem código de erro ou nil.

local ACTIONS = {}
BankingBusiness.Actions = ACTIONS

local function needs(ctx, right)
	if not ctx.rights[right] then
		return 'forbidden'
	end
	return nil
end

local function opBase(ctx, kind, amount)
	return { businessId = ctx.business.id, characterId = ctx.who.characterId, actorName = ctx.who.name, kind = kind, amount = amount }
end

-- Depósito no caixa: da conta pessoal ou em espécie (só na agência). Qualquer pessoa do negócio.
function ACTIONS.deposit(ctx, data)
	if not ctx.rights.deposit then
		return 'not_staff'
	end
	local amount, amountError = BankingRules.Amount(data.amount, config.MaxAgencyAmount)
	if not amount then
		return amountError
	end
	local op = opBase(ctx, 'deposit', amount)
	if data.method == 'cash' then
		if ctx.channel ~= 'agency' then
			return 'agency_only'
		end
		if not takeCash(ctx.playerId, amount) then
			return 'insufficient_cash'
		end
		op.counterpartyLabel = 'Espécie'
		local errorCode = withOp(op, function(reference)
			return remote('coe_economy', 'BankSocietyCredit', ctx.business.id, amount, 'business_deposit', reference)
		end)
		if errorCode then
			if not giveCash(ctx.playerId, amount) then
				S().log('error', 'banking', 'refund_failed', { character_id = ctx.who.characterId, count = amount, action = 'business_cash_deposit' })
			end
			return errorCode
		end
	else
		op.counterpartyLabel = ctx.who.name
		local errorCode = withOp(op, function(reference)
			return remote('coe_economy', 'BankSocietyDeposit', ctx.business.id, ctx.who.characterId, amount, 'business_deposit', reference)
		end)
		if errorCode then
			return errorCode
		end
	end
	S().audit('bank_business_deposit', { character_id = ctx.who.characterId, count = amount, action = ctx.business.id, operation = data.method == 'cash' and 'cash' or 'account' })
	S().notify(ctx.playerId, 'success', _t('business_deposit_success', { amount = money(amount), business = ctx.business.label }))
end

-- Saque do caixa: para a conta pessoal de quem saca ou em espécie (só na agência).
function ACTIONS.withdraw(ctx, data)
	local denied = needs(ctx, 'withdraw')
	if denied then
		return denied
	end
	local amount, amountError = BankingRules.Amount(data.amount, config.MaxAgencyAmount)
	if not amount then
		return amountError
	end
	local op = opBase(ctx, 'withdraw', amount)
	if data.method == 'cash' then
		if ctx.channel ~= 'agency' then
			return 'agency_only'
		end
		op.counterpartyLabel = 'Espécie'
		local errorCode = withOp(op, function(reference)
			return remote('coe_economy', 'BankSocietyDebit', ctx.business.id, amount, 'business_withdraw', reference)
		end)
		if errorCode then
			return errorCode
		end
		if not giveCash(ctx.playerId, amount) then
			if remote('coe_economy', 'BankSocietyCredit', ctx.business.id, amount, 'bank_refund', '') ~= true then
				S().log('error', 'banking', 'refund_failed', { character_id = ctx.who.characterId, count = amount, action = 'business_cash_withdraw' })
			end
			return 'inventory_full'
		end
	else
		op.counterparty, op.counterpartyLabel = ctx.who.characterId, ctx.who.name
		local errorCode = withOp(op, function(reference)
			return remote('coe_economy', 'BankSocietyPay', ctx.business.id, ctx.who.characterId, amount, 'business_withdraw', reference)
		end)
		if errorCode then
			return errorCode
		end
	end
	S().audit('bank_business_withdraw', { character_id = ctx.who.characterId, count = amount, action = ctx.business.id, operation = data.method == 'cash' and 'cash' or 'account' })
	S().notify(ctx.playerId, 'success', _t('business_withdraw_success', { amount = money(amount), business = ctx.business.label }))
end

-- Transferência da empresa para uma pessoa (identidade) ou outra empresa (id), com observação.
function ACTIONS.transfer(ctx, data)
	local denied = needs(ctx, 'transfer')
	if denied then
		return denied
	end
	local amount, amountError = BankingRules.Amount(data.amount, settings.MaxTransfer)
	if not amount then
		return amountError
	end
	local target, targetError = BusinessRules.Target(data.target)
	if not target then
		return targetError
	end
	local memo = BusinessRules.Memo(data.memo, settings.MemoMax)
	local op = opBase(ctx, 'transfer', amount)
	op.memo = memo
	local notifyTarget
	if target.kind == 'person' then
		local person, personError = BankingPersistence.FindCharacterByStateId(target.stateId)
		if not person then
			return personError
		end
		op.counterparty, op.counterpartyLabel = person.characterId, person.name
		local errorCode = withOp(op, function(reference)
			return remote('coe_economy', 'BankSocietyPay', ctx.business.id, person.characterId, amount, 'business_payment', reference)
		end)
		if errorCode then
			return errorCode
		end
		notifyTarget = function()
			local recipient = S().playerOf(person.characterId)
			if recipient then
				S().notify(recipient, 'info', _t('business_payment_received', { amount = money(amount), business = ctx.business.label, memo = memo ~= '' and (' ' .. memo) or '' }))
			end
		end
		S().notify(ctx.playerId, 'success', _t('business_payment_sent', { amount = money(amount), target = person.name }))
	else
		if target.id == ctx.business.id then
			return 'same_account'
		end
		local other = businessGet(target.id)
		if not other then
			return 'unknown_business'
		end
		op.counterparty, op.counterpartyLabel = other.id, other.label or other.id
		local errorCode = withOp(op, function(reference)
			return remote('coe_economy', 'BankSocietyTransfer', ctx.business.id, other.id, amount, 'business_transfer', reference)
		end)
		if errorCode then
			return errorCode
		end
		S().notify(ctx.playerId, 'success', _t('business_transfer_sent', { amount = money(amount), target = other.label or other.id }))
	end
	S().audit('bank_business_transfer', { character_id = ctx.who.characterId, count = amount, action = ctx.business.id, target = op.counterparty })
	if notifyTarget then
		notifyTarget()
	end
end

-- Bônus para alguém do negócio (fora da folha).
function ACTIONS.bonus(ctx, data)
	local denied = needs(ctx, 'payroll')
	if denied then
		return denied
	end
	local amount, amountError = BankingRules.Amount(data.amount, settings.MaxTransfer)
	if not amount then
		return amountError
	end
	local member = isMember(ctx.business, data.characterId)
	if not member then
		return 'not_staff_member'
	end
	local op = opBase(ctx, 'bonus', amount)
	op.counterparty, op.counterpartyLabel, op.memo = member.characterId, member.name, BusinessRules.Memo(data.memo, settings.MemoMax)
	local errorCode = withOp(op, function(reference)
		return remote('coe_economy', 'BankSocietyPay', ctx.business.id, member.characterId, amount, 'business_bonus', reference)
	end)
	if errorCode then
		return errorCode
	end
	S().audit('bank_business_bonus', { character_id = ctx.who.characterId, count = amount, action = ctx.business.id, target = member.characterId })
	S().notify(ctx.playerId, 'success', _t('bonus_paid', { amount = money(amount), target = member.name }))
	local recipient = S().playerOf(member.characterId)
	if recipient then
		S().notify(recipient, 'success', _t('bonus_received', { amount = money(amount), business = ctx.business.label }))
	end
end

-- Roda a folha agora (mesma regra da automática: só quem está de ponto e enquanto houver saldo).
function ACTIONS.payrollRun(ctx)
	local denied = needs(ctx, 'payroll')
	if denied then
		return denied
	end
	local summary = remote('coe_economy', 'RunPayroll', ctx.business.id)
	if type(summary) ~= 'table' or summary.error then
		return economyError(summary)
	end
	S().audit('bank_business_payroll', { character_id = ctx.who.characterId, action = ctx.business.id, count = summary.total })
	local skipped = type(summary.skipped) == 'table' and #summary.skipped or 0
	S().notify(ctx.playerId, summary.paid > 0 and 'success' or 'info', _t('payroll_summary', {
		count = summary.paid,
		total = money(summary.total),
		pending = skipped > 0 and (' ' .. tostring(skipped) .. ' fora (fora de ponto ou sem saldo).') or ''
	}))
end

-- Cartão empresarial: emitido na agência para alguém do negócio; o plástico vai para quem pediu entregar ao titular.
function ACTIONS.issueCard(ctx, data)
	local denied = needs(ctx, 'cards')
	if denied then
		return denied
	end
	if ctx.channel ~= 'agency' then
		return 'agency_only'
	end
	local holder = isMember(ctx.business, data.holderId)
	if not holder then
		return 'not_staff_member'
	end
	local pin, pinError = BankingRules.Pin(data.pin)
	if not pin then
		return pinError
	end
	local limit, limitError = BusinessRules.DailyLimit(data.dailyLimit == nil and settings.DefaultDailyLimit or data.dailyLimit, settings)
	if not limit then
		return limitError
	end
	local active = BankingPersistence.CountBusinessCards(ctx.business.id, os.time())
	if not active then
		return 'database_error'
	end
	if active >= settings.MaxCards then
		return 'max_cards'
	end
	local inventoryId = S().inventoryOf(ctx.playerId)
	if not inventoryId then
		return 'inventory_full'
	end
	local fee = settings.CardFee or 0
	if fee > 0 then
		local op = opBase(ctx, 'card_fee', fee)
		op.counterpartyLabel = holder.name
		local feeError = withOp(op, function(reference)
			return remote('coe_economy', 'BankSocietyDebit', ctx.business.id, fee, 'card_fee', reference)
		end)
		if feeError then
			return feeError
		end
	end
	local refund = function()
		if fee > 0 and remote('coe_economy', 'BankSocietyCredit', ctx.business.id, fee, 'bank_refund', '') ~= true then
			S().log('error', 'banking', 'refund_failed', { action = ctx.business.id, count = fee, operation = 'business_card_fee' })
		end
	end
	local salt = BankingRules.Salt(S().digit)
	local card = {
		accountType = 'business', accountRef = ctx.business.id, holderId = holder.characterId, holderName = holder.name:sub(1, 64),
		pinSalt = salt, pinHash = BankingRules.HashPin(pin, salt, config.PinHashRounds, S().hashKey),
		expiresAt = os.time() + config.CardValidityDays * 86400, kind = 'physical', dailyLimit = limit
	}
	local cardId, insertError
	for _ = 1, 3 do
		card.serial = BankingRules.Serial(S().digit)
		cardId, insertError = BankingPersistence.InsertCard(card)
		if cardId or insertError ~= 'duplicate' then
			break
		end
	end
	if not cardId then
		refund()
		return 'database_error'
	end
	local last4 = BankingRules.Last4(card.serial)
	local label = (ctx.business.label or ctx.business.id):sub(1, 32)
	local metadata = {
		cardId = cardId, last4 = last4, holder = card.holderName, business = label,
		label = ('Cartão empresarial %s •••• %s'):format(label, last4), validUntil = os.date('%d/%m/%Y', card.expiresAt)
	}
	if remote('coe_inventory', 'AddItem', inventoryId, 'card_bank', 1, metadata) ~= true then
		BankingPersistence.Block(cardId, 'failed')
		refund()
		return 'inventory_full'
	end
	S().audit('bank_business_card_issued', { character_id = ctx.who.characterId, action = ctx.business.id, target = holder.characterId, request_id = tostring(cardId) })
	S().notify(ctx.playerId, 'success', _t('corporate_card_issued', { last4 = last4, target = holder.name }))
end

function ACTIONS.cardLimit(ctx, data)
	local denied = needs(ctx, 'cards')
	if denied then
		return denied
	end
	local card, cardError = businessCard(ctx.business.id, data.cardId)
	if not card then
		return cardError
	end
	local limit, limitError = BusinessRules.DailyLimit(data.dailyLimit, settings)
	if not limit then
		return limitError
	end
	if not BankingPersistence.SetDailyLimit(card.id, limit) then
		return 'database_error'
	end
	S().audit('bank_business_card_limit', { character_id = ctx.who.characterId, action = ctx.business.id, request_id = tostring(card.id), count = limit })
	S().notify(ctx.playerId, 'success', limit > 0 and _t('corporate_card_limit', { last4 = BankingRules.Last4(card.serial), limit = money(limit) })
		or _t('corporate_card_unlimited', { last4 = BankingRules.Last4(card.serial) }))
end

function ACTIONS.cardBlock(ctx, data)
	local denied = needs(ctx, 'cards')
	if denied then
		return denied
	end
	local card, cardError = businessCard(ctx.business.id, data.cardId)
	if not card then
		return cardError
	end
	if BankingRules.Status(card) == 'blocked' and card.blockedReason ~= 'pin' then
		return 'card_blocked'
	end
	local done = card.blockedReason == 'pin' and BankingPersistence.SetAttempts(card.id, card.attempts, 'lost') or BankingPersistence.Block(card.id, 'lost')
	if not done then
		return 'database_error'
	end
	S().audit('bank_business_card_blocked', { character_id = ctx.who.characterId, action = ctx.business.id, request_id = tostring(card.id) })
	S().notify(ctx.playerId, 'success', _t('corporate_card_blocked', { last4 = BankingRules.Last4(card.serial) }))
end

function ACTIONS.cardPin(ctx, data)
	local denied = needs(ctx, 'cards')
	if denied then
		return denied
	end
	if ctx.channel ~= 'agency' then
		return 'agency_only'
	end
	local card, cardError = businessCard(ctx.business.id, data.cardId)
	if not card then
		return cardError
	end
	if not BankingRules.CanResetPin(card) then
		return 'card_blocked'
	end
	local pin, pinError = BankingRules.Pin(data.pin)
	if not pin then
		return pinError
	end
	local salt = BankingRules.Salt(S().digit)
	if not BankingPersistence.SetPin(card.id, BankingRules.HashPin(pin, salt, config.PinHashRounds, S().hashKey), salt) then
		return 'database_error'
	end
	S().audit('bank_business_card_pin', { character_id = ctx.who.characterId, action = ctx.business.id, request_id = tostring(card.id) })
	S().notify(ctx.playerId, 'success', card.blockedReason == 'pin' and _t('corporate_card_pin_unblocked') or _t('corporate_card_pin_changed'))
end

-- Empréstimo da empresa: paga com o caixa.
function ACTIONS.loanPay(ctx, data)
	local denied = needs(ctx, 'loans')
	if denied then
		return denied
	end
	local loanId = math.tointeger(tonumber(data.loanId))
	if not loanId or (data.mode ~= 'installment' and data.mode ~= 'total') then
		return 'loan_not_found'
	end
	local paid, payError = S().withCreditLock('loan:' .. loanId, function()
		local loan, loanError = BankingPersistence.Loan(loanId)
		if not loan then
			return nil, loanError
		end
		if loan.status ~= 'active' or loan.businessId ~= ctx.business.id then
			return nil, 'loan_not_found'
		end
		return S().settleLoan(loan, os.time(), { payer = S().businessPayer(ctx.business.id), mode = data.mode, reference = 'loan:' .. loan.id })
	end)
	if type(paid) ~= 'number' then
		return payError or paid
	end
	S().audit('bank_loan_payment', { character_id = ctx.who.characterId, count = paid, request_id = tostring(loanId), action = ctx.business.id })
end

-- Pedido de empréstimo em nome da empresa (só o dono); a staff do banco aprova ou recusa no admin.
function ACTIONS.loanRequest(ctx, data)
	if not ctx.rights.requestLoans then
		return 'not_business_owner'
	end
	return S().requestBusinessLoan(ctx.playerId, ctx.who, ctx.business.id, data)
end

function ACTIONS.loanRequestCancel(ctx, data)
	if not ctx.rights.requestLoans then
		return 'not_business_owner'
	end
	return S().cancelBusinessLoan(ctx.playerId, ctx.who, ctx.business.id, data)
end

-- Só atualiza a visão com o novo filtro do extrato (guardado pelo chamador).
function ACTIONS.statement(ctx)
	if not ctx.rights.view then
		return 'forbidden'
	end
end

-- Caixa eletrônico com cartão empresarial ----------------------------------------------------------------

function BankingBusiness.AtmView(playerId, card, business)
	local inventoryId = S().inventoryOf(playerId)
	local now = os.time()
	local page = statementPage(card.accountRef, { days = 30, limit = config.AtmStatementSize })
	return {
		mode = 'atm', step = 'menu', business = business.label or business.id, cardId = card.id,
		last4 = BankingRules.Last4(card.serial), holder = card.holderName, fee = settings.AtmFee or 0,
		balance = societyBalance(card.accountRef), cash = inventoryId and S().cashOf(inventoryId) or 0,
		maxAmount = config.MaxAtmAmount, quick = config.AtmQuickAmounts,
		dailyLimit = card.dailyLimit, remaining = BusinessRules.Remaining(card, now),
		statement = page.rows
	}
end

local function holderOp(card, who, kind, amount)
	return {
		businessId = card.accountRef, characterId = who and who.characterId or card.holderId, actorName = who and who.name or card.holderName,
		kind = kind, amount = amount, counterpartyLabel = ('Cartão •••• %s'):format(BankingRules.Last4(card.serial))
	}
end

function BankingBusiness.AtmWithdraw(playerId, card, data, who)
	local amount, amountError = BankingRules.Amount(data.amount, config.MaxAtmAmount)
	if not amount then
		return amountError
	end
	local business, businessError = BankingBusiness.CardUsable(card)
	if not business then
		return businessError
	end
	local fee = settings.AtmFee or 0
	local day = BusinessRules.Day(os.time())
	if not BankingPersistence.Spend(card.id, amount, day) then
		return 'card_daily_limit'
	end
	local errorCode = withOp(holderOp(card, who, 'atm_withdraw', amount), function(reference)
		return remote('coe_economy', 'BankSocietyDebit', card.accountRef, amount, 'business_withdraw', reference)
	end)
	if errorCode then
		BankingPersistence.Unspend(card.id, amount, day)
		return errorCode
	end
	if not giveCash(playerId, amount) then
		BankingPersistence.Unspend(card.id, amount, day)
		if remote('coe_economy', 'BankSocietyCredit', card.accountRef, amount, 'bank_refund', '') ~= true then
			S().log('error', 'banking', 'refund_failed', { action = card.accountRef, count = amount, operation = 'business_atm' })
		end
		return 'inventory_full'
	end
	if fee > 0 and remote('coe_economy', 'BankSocietyDebit', card.accountRef, fee, 'atm_fee', 'atm:' .. card.id) ~= true then
		fee = 0
	end
	S().audit('bank_business_atm_withdraw', { character_id = who and who.characterId or nil, action = card.accountRef, request_id = tostring(card.id), count = amount })
	S().notify(playerId, 'success', fee > 0 and _t('business_withdraw_fee', { amount = money(amount), business = business.label or business.id, fee = money(fee) })
		or _t('business_withdraw_success', { amount = money(amount), business = business.label or business.id }))
end

function BankingBusiness.AtmDeposit(playerId, card, data, who)
	local amount, amountError = BankingRules.Amount(data.amount, config.MaxAtmAmount)
	if not amount then
		return amountError
	end
	local business, businessError = BankingBusiness.CardUsable(card)
	if not business then
		return businessError
	end
	if not takeCash(playerId, amount) then
		return 'insufficient_cash'
	end
	local errorCode = withOp(holderOp(card, who, 'atm_deposit', amount), function(reference)
		return remote('coe_economy', 'BankSocietyCredit', card.accountRef, amount, 'business_deposit', reference)
	end)
	if errorCode then
		if not giveCash(playerId, amount) then
			S().log('error', 'banking', 'refund_failed', { action = card.accountRef, count = amount, operation = 'business_atm_deposit' })
		end
		return errorCode
	end
	S().audit('bank_business_atm_deposit', { character_id = who and who.characterId or nil, action = card.accountRef, request_id = tostring(card.id), count = amount })
	S().notify(playerId, 'success', _t('business_deposit_success', { amount = money(amount), business = business.label or business.id }))
end

-- Compras pela carteira digital com cartão empresarial: débito no caixa, dentro do limite do dia.
function BankingBusiness.CardPurchase(input)
	local business, businessError = BankingBusiness.CardUsable(input.card)
	if not business then
		return { ok = false, error = businessError }
	end
	local day = BusinessRules.Day(os.time())
	if not BankingPersistence.Spend(input.card.id, input.amount, day) then
		return { ok = false, error = 'card_daily_limit' }
	end
	local op = holderOp(input.card, nil, 'card_purchase', input.amount)
	op.memo = input.label
	local errorCode = withOp(op, function(reference)
		return remote('coe_economy', 'BankSocietyDebit', input.card.accountRef, input.amount, 'business_card', reference)
	end)
	if errorCode then
		BankingPersistence.Unspend(input.card.id, input.amount, day)
		return { ok = false, error = errorCode }
	end
	S().audit('bank_business_card_purchase', { action = input.card.accountRef, request_id = tostring(input.card.id), count = input.amount, operation = GetInvokingResource() })
	return { ok = true, points = 0, business = business.label or business.id }
end

function BankingBusiness.CardRefund(input)
	local op = holderOp(input.card, nil, 'card_refund', input.amount)
	op.memo = input.label
	local errorCode = withOp(op, function(reference)
		return remote('coe_economy', 'BankSocietyCredit', input.card.accountRef, input.amount, 'business_card_refund', reference)
	end)
	if errorCode then
		return { ok = false, error = errorCode }
	end
	BankingPersistence.Unspend(input.card.id, input.amount, BusinessRules.Day(os.time()))
	return { ok = true, refunded = input.amount }
end

-- Agência: escolha da conta e operações ---------------------------------------------------------------

local filters = {} -- [source] = filtro do extrato da conta empresarial aberta

function BankingBusiness.ResetFilter(playerId)
	filters[playerId] = nil
end

function BankingBusiness.AgencyView(playerId, agency, who, businessId)
	local business, rights = BankingBusiness.Rights(businessId, who.characterId)
	if not business then
		return nil, 'not_staff'
	end
	local inventoryId = S().inventoryOf(playerId)
	return BankingBusiness.View(business, rights, who, filters[playerId], {
		title = agency.label, cash = inventoryId and S().cashOf(inventoryId) or 0, switchable = true
	})
end

RegisterNetEvent('coe_banking:business', function(action, data)
	local playerId = source
	local handler = type(action) == 'string' and ACTIONS[action] or nil
	if not handler or type(data) ~= 'table' then
		return
	end
	S().guarded(playerId, function()
		local agency = S().agencyById(S().agencyOpen[playerId])
		if not S().nearAgency(playerId, agency) then
			S().agencyOpen[playerId] = nil
			return 'too_far'
		end
		local who = S().character(playerId)
		if not who then
			return 'no_character'
		end
		local businessId = S().agencyAccount[playerId]
		local business, rights = BankingBusiness.Rights(businessId, who.characterId)
		if not business then
			S().agencyAccount[playerId] = nil
			return 'not_staff'
		end
		if action == 'statement' then
			filters[playerId] = BusinessRules.Filter(data.filter, settings)
		end
		local errorCode = handler({ playerId = playerId, who = who, business = business, rights = rights, channel = 'agency', agency = agency }, data)
		local view = BankingBusiness.AgencyView(playerId, agency, who, businessId)
		if view then
			TriggerClientEvent('coe_banking:update', playerId, view)
		end
		return errorCode
	end)
end)

AddEventHandler('playerDropped', function()
	filters[source] = nil
end)

-- App do negócio no tablet (via coe_businesses:TabletCall -> actions.bank) ---------------------------------

local TABLET_OPS = {
	overview = true, statement = true, deposit = true, withdraw = true, transfer = true, bonus = true, payrollRun = true,
	cardLimit = true, cardBlock = true, loanPay = true
}
local tabletFilters = {}

exports('BusinessTablet', function(playerId, characterId, businessId, payload)
	if GetInvokingResource() ~= 'coe_businesses' then
		return { ok = false, error = 'forbidden' }
	end
	if not S().isReady() then
		return { ok = false, error = 'not_ready', message = S().messages.not_ready }
	end
	payload = type(payload) == 'table' and payload or {}
	local op = payload.op
	if type(op) ~= 'string' or not TABLET_OPS[op] then
		return { ok = false, error = 'unknown_action' }
	end
	local source = tonumber(playerId)
	local who = source and S().character(source)
	if not who or who.characterId ~= tostring(characterId) then
		return { ok = false, error = 'no_character', message = S().messages.no_character }
	end
	local business, rights = BankingBusiness.Rights(businessId, who.characterId)
	if not business then
		return { ok = false, error = 'forbidden', message = S().messages.not_staff }
	end
	if op ~= 'overview' and op ~= 'statement' and (S().busy[source] or S().throttled(source)) then
		return { ok = false, error = 'busy', message = S().messages.busy }
	end
	local key = source .. ':' .. business.id
	if op == 'statement' then
		tabletFilters[key] = BusinessRules.Filter(payload.filter, settings)
	end
	S().busy[source] = true
	local ok, errorCode, view = pcall(function()
		local code = (op ~= 'overview' and op ~= 'statement') and ACTIONS[op]({ playerId = source, who = who, business = business, rights = rights, channel = 'tablet' }, payload) or nil
		local _, fresh = BankingBusiness.Rights(business.id, who.characterId)
		return code, BankingBusiness.View(business, fresh or rights, who, tabletFilters[key])
	end)
	S().busy[source] = nil
	if not ok then
		S().log('error', 'banking', 'business_tablet_failed', { player_id = source, action = op, error_code = tostring(errorCode):sub(1, 96) })
		return { ok = false, error = 'database_error', message = S().messages.database_error }
	end
	return { ok = errorCode == nil, error = errorCode, message = errorCode and S().messages[errorCode] or nil, bank = view }
end)

-- Admin (só coe_admin; a permissão da staff é checada lá) -----------------------------------------------

local ADMIN_RIGHTS = { view = true, deposit = false, withdraw = false, transfer = false, cards = true, loans = false, payroll = true, requestLoans = false }

exports('AdminBusinessAccounts', function()
	if GetInvokingResource() ~= 'coe_admin' then
		return { error = 'forbidden' }
	end
	if not S().isReady() then
		return { error = 'not_ready' }
	end
	local list = {}
	local now = os.time()
	for _, business in ipairs(remote('coe_businesses', 'List') or {}) do
		local cards = BankingPersistence.CountBusinessCards(business.id, now) or 0
		local loans = 0
		for _, loan in ipairs(BankingPersistence.BusinessLoans(business.id, 5) or {}) do
			if loan.status == 'active' then
				loans = loans + 1
			end
		end
		list[#list + 1] = {
			id = business.id, label = business.label or business.id, category = business.category, enabled = business.enabled ~= false,
			owner = type(business.owner) == 'table' and business.owner.name or nil, balance = societyBalance(business.id), cards = cards, loans = loans
		}
	end
	table.sort(list, function(a, b) return a.label < b.label end)
	return { accounts = list }
end)

exports('AdminBusinessAccount', function(businessId, filter)
	if GetInvokingResource() ~= 'coe_admin' then
		return { error = 'forbidden' }
	end
	local business = S().isReady() and type(businessId) == 'string' and remote('coe_businesses', 'Get', businessId) or nil
	if type(business) ~= 'table' then
		return { error = 'unknown_business' }
	end
	return BankingBusiness.View(business, ADMIN_RIGHTS, nil, BusinessRules.Filter(filter, settings))
end)

-- Ajuste da staff no caixa: delta positivo credita, negativo debita (motivo admin_adjustment, com a observação).
exports('AdminBusinessAdjust', function(businessId, delta, note)
	if GetInvokingResource() ~= 'coe_admin' then
		return { error = 'forbidden' }
	end
	local business = S().isReady() and type(businessId) == 'string' and remote('coe_businesses', 'Get', businessId) or nil
	if type(business) ~= 'table' then
		return { error = 'unknown_business' }
	end
	delta = math.tointeger(tonumber(delta))
	if not delta or delta == 0 or math.abs(delta) > config.MaxAgencyAmount * 100 then
		return { error = 'invalid_amount' }
	end
	local op = { businessId = business.id, actorName = 'Staff do banco', kind = 'adjust', amount = math.abs(delta), memo = BusinessRules.Memo(note, settings.MemoMax) }
	local errorCode = withOp(op, function(reference)
		if delta > 0 then
			return remote('coe_economy', 'BankSocietyCredit', business.id, delta, 'admin_adjustment', reference)
		end
		return remote('coe_economy', 'BankSocietyDebit', business.id, -delta, 'admin_adjustment', reference)
	end)
	if errorCode then
		return { error = errorCode }
	end
	return true
end)

-- op: limit (value = limite diário, 0 = sem limite). Bloqueio, desbloqueio e validade usam AdminCard.
exports('AdminBusinessCardLimit', function(cardId, value)
	if GetInvokingResource() ~= 'coe_admin' then
		return { error = 'forbidden' }
	end
	local id = BankingRules.CardId(cardId)
	local card = S().isReady() and id and BankingPersistence.Card(id) or nil
	if not card or card.accountType ~= 'business' then
		return { error = 'card_not_found' }
	end
	local limit = BusinessRules.DailyLimit(value, settings)
	if not limit then
		return { error = 'invalid_limit' }
	end
	if not BankingPersistence.SetDailyLimit(card.id, limit) then
		return { error = 'database_error' }
	end
	return true
end)

-- Permissões de cargo no coe_businesses (de novo quando ele reinicia).
local function registerPermissions()
	if remote('coe_businesses', 'IsReady') ~= true then
		return false
	end
	local result = remote('coe_businesses', 'RegisterPermissions', BusinessRules.Permissions)
	if result ~= true then
		S().log('warn', 'banking', 'business_permissions_failed', { error_code = type(result) == 'table' and tostring(result.error) or 'unknown' })
	end
	return true
end

AddEventHandler('onResourceStart', function(name)
	if name == 'coe_businesses' then
		SetTimeout(3000, registerPermissions)
	end
end)

CreateThread(function()
	for _ = 1, 60 do
		if BankingServer and registerPermissions() then
			return
		end
		Wait(5000)
	end
end)
