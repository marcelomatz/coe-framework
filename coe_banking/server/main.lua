local config = BankingConfig
local ready = false

local lastAction = {}
local busy = {}
-- Sessão do caixa eletrônico: [source] = { cardId, expires }.
local atmSessions = {}
-- Agência aberta: [source] = agencyId. Conta escolhida na agência: [source] = id do negócio (nil = pessoal).
local agencyOpen = {}
local agencyAccount = {}

local rawLocales = (type(Locales) == 'table' and Locales) or {}
local _t_inst = (Core and Core.Locale and Core.Locale.New) and Core.Locale.New({
	default = (config and config.Locale) or (Core and Core.Locale and Core.Locale.GetDefaultLang()) or 'pt-BR',
	locales = rawLocales
})
local _t = function(k, params)
	if type(_t_inst) == 'table' then
		if _t_inst.T then
			return _t_inst:T(k, params)
		end
		local lang = _t_inst.lang or 'pt-BR'
		local dict = (_t_inst.locales and _t_inst.locales[lang]) or rawLocales[lang] or rawLocales['pt-BR']
		if dict and dict[k] then
			return dict[k]
		end
	elseif type(_t_inst) == 'function' then
		return _t_inst(k, params)
	end
	return (rawLocales['pt-BR'] and rawLocales['pt-BR'][k]) or k
end

local MESSAGES = {
	not_ready = _t('not_ready'), too_far = _t('too_far'), busy = _t('busy'),
	invalid_amount = _t('invalid_amount'), insufficient_funds = _t('insufficient_funds'), insufficient_cash = _t('insufficient_cash'),
	invalid_pin = _t('invalid_pin'), invalid_state_id = _t('invalid_state_id'),
	character_not_found = _t('character_not_found'), same_account = _t('same_account'),
	card_not_found = _t('card_not_found'), not_owner = _t('not_owner'), card_blocked = _t('card_blocked'),
	no_card = _t('no_card'), session_expired = _t('session_expired'),
	inventory_full = _t('inventory_full'), economy_unavailable = _t('economy_unavailable'),
	not_staff = _t('not_staff'), forbidden = _t('forbidden'),
	balance_limit = _t('balance_limit'), database_error = _t('database_error'), no_character = _t('no_character'),
	credit_late = _t('credit_late'), credit_limit = _t('credit_limit'),
	credit_score = _t('credit_score'),
	credit_no_upgrade = _t('credit_no_upgrade'), no_credit = _t('no_credit'),
	nothing_to_pay = _t('nothing_to_pay'), conflict = _t('conflict'),
	card_expired = _t('card_expired'),
	loan_not_found = _t('loan_not_found'), invalid_loan = _t('invalid_loan'),
	not_business_owner = _t('not_business_owner'),
	request_pending = _t('request_pending'), request_not_found = _t('request_not_found'),
	business_loan_active = _t('business_loan_active'),
	virtual_no_pin = _t('virtual_no_pin'),
	transaction_failed = _t('transaction_failed'),
	invalid_parameters = _t('invalid_parameters'),
	invalid_transaction = _t('invalid_transaction'),
	account_not_found = _t('account_not_found'),
	unknown_business = _t('unknown_business'),
	invalid_target = _t('invalid_target'), invalid_limit = _t('invalid_limit'),
	max_cards = _t('max_cards'), not_staff_member = _t('not_staff_member'),
	card_daily_limit = _t('card_daily_limit'), card_holder_left = _t('card_holder_left'),
	agency_only = _t('agency_only'), not_business_owner_loans = _t('not_business_owner_loans'),
	bank_unavailable = _t('bank_unavailable')
}

local REASON_LABELS = { pin = 'senha', lost = 'perda/roubo', replaced = 'substituído', failed = 'falha na emissão', staff = 'bloqueado pela staff' }

local function log(level, category, event, context)
	pcall(function()
		return exports.coe_logging:Log(level, category, event, context)
	end)
end

local function audit(event, context)
	pcall(function()
		return exports.coe_audit:Record('info', 'audit', event, context)
	end)
end

local function notify(playerId, kind, message)
	pcall(function()
		exports.coe_notify:Notify(playerId, kind, message)
	end)
end

local function money(value)
	if Core and Core.Locale and Core.Locale.FormatMoney then
		return Core.Locale.FormatMoney(value, (config and config.Locale) or Core.Locale.GetDefaultLang())
	end
	local text = tostring(math.floor(value))
	local formatted = text:reverse():gsub('(%d%d%d)', '%1.'):reverse():gsub('^%.', '')
	return config.Currency .. ' ' .. formatted
end

-- Exports de outros resources (só o primeiro retorno); nil se o resource não está de pé ou falhou.
local function remote(resource, name, ...)
	if GetResourceState(resource) ~= 'started' then
		return nil
	end
	local args = { ... }
	local ok, result = pcall(function()
		return exports[resource][name](exports[resource], table.unpack(args))
	end)
	return ok and result or nil
end

local function fail(playerId, errorCode)
	TriggerClientEvent('coe_banking:failed', playerId, errorCode)
	notify(playerId, 'error', _t(errorCode, MESSAGES[errorCode] or _t('generic_error')))
end

local function throttled(playerId)
	local now = GetGameTimer()
	if lastAction[playerId] and now - lastAction[playerId] < config.ActionIntervalMs then
		return true
	end
	lastAction[playerId] = now
	return false
end

local function hashKey(text)
	return GetHashKey(text)
end

local function digit()
	return math.random(0, 9)
end

local function character(playerId)
	local snapshot = Core.Players.GetActiveCharacter(playerId)
	if type(snapshot) ~= 'table' or not snapshot.characterId then
		return nil
	end
	return {
		characterId = tostring(snapshot.characterId),
		name = (((snapshot.firstName or '') .. ' ' .. (snapshot.lastName or '')):gsub('^%s+', ''):gsub('%s+$', ''))
	}
end

local function playerOf(characterId)
	for _, playerId in ipairs(GetPlayers()) do
		local id = Core.Players.GetActiveCharacterId(tonumber(playerId))
		if id and tostring(id) == characterId then
			return tonumber(playerId)
		end
	end
	return nil
end

local function agencyById(agencyId)
	for _, agency in ipairs(config.Agencies) do
		if agency.id == agencyId then
			return agency
		end
	end
	return nil
end

local function nearAgency(playerId, agency)
	local ped = GetPlayerPed(playerId)
	if not agency or not ped or ped == 0 then
		return false
	end
	return #(Core.Platform.Entities.GetCoords(ped) - vector3(agency.x, agency.y, agency.z)) <= agency.radius + 2.0
end

-- Dinheiro: conta (coe_economy) e espécie (item `money` no coe_inventory).
local function inventoryOf(playerId)
	return remote('coe_inventory', 'GetPlayerInventory', playerId)
end

local function cashOf(inventoryId)
	return tonumber(remote('coe_inventory', 'GetItemCount', inventoryId, 'money')) or 0
end

local function balanceOf(accountId)
	local balance = remote('coe_economy', 'GetBalance', accountId)
	return type(balance) == 'number' and balance or nil
end

local function credit(accountId, amount, reason, reference)
	return remote('coe_economy', 'Credit', accountId, amount, reason, reference) == true
end

local function debit(accountId, amount, reason, reference)
	return remote('coe_economy', 'Debit', accountId, amount, reason, reference) == true
end

-- Saque: debita a conta e entrega espécie; se não couber no inventário, devolve à conta.
local function withdrawCash(playerId, accountId, amount, reference)
	local inventoryId = inventoryOf(playerId)
	if not inventoryId then
		return 'inventory_full'
	end
	local balance = balanceOf(accountId)
	if not balance then
		return 'economy_unavailable'
	end
	if balance < amount then
		return 'insufficient_funds'
	end
	if not debit(accountId, amount, 'bank_withdraw', reference) then
		return 'insufficient_funds'
	end
	if remote('coe_inventory', 'AddItem', inventoryId, 'money', amount) ~= true then
		if not credit(accountId, amount, 'bank_refund', reference) then
			log('error', 'banking', 'refund_failed', { character_id = accountId, count = amount, action = 'withdraw' })
		end
		return 'inventory_full'
	end
	return nil
end

-- Depósito: retira espécie e credita a conta; se o crédito falhar, devolve a espécie.
local function depositCash(playerId, accountId, amount, reference)
	local inventoryId = inventoryOf(playerId)
	if not inventoryId then
		return 'insufficient_cash'
	end
	if cashOf(inventoryId) < amount then
		return 'insufficient_cash'
	end
	if remote('coe_inventory', 'RemoveItemByName', inventoryId, 'money', amount) ~= true then
		return 'insufficient_cash'
	end
	if not credit(accountId, amount, 'bank_deposit', reference) then
		if remote('coe_inventory', 'AddItem', inventoryId, 'money', amount) ~= true then
			log('error', 'banking', 'refund_failed', { character_id = accountId, count = amount, action = 'deposit' })
		end
		return 'balance_limit'
	end
	return nil
end

local function statement(accountId, limit)
	local rows = remote('coe_economy', 'Ledger', accountId, limit)
	local list = {}
	if type(rows) == 'table' and not rows.error then
		for _, row in ipairs(rows) do
			list[#list + 1] = { delta = tonumber(row.delta) or 0, reason = row.reason, reference = row.reference, at = row.created_at }
		end
	end
	return list
end

local function cardView(card)
	local status = BankingRules.Status(card)
	return {
		id = card.id,
		last4 = BankingRules.Last4(card.serial),
		holder = card.holderName,
		status = status,
		blockedReason = card.blockedReason and (REASON_LABELS[card.blockedReason] or card.blockedReason) or nil,
		canResetPin = card.kind ~= 'virtual' and status ~= 'expired' and BankingRules.CanResetPin(card),
		createdAt = card.createdAt,
		expiresAt = card.expiresAt,
		kind = card.kind
	}
end

-- Crédito --------------------------------------------------------------------------------------------

local creditConfig = config.Credit
local creditLocks = {}

-- Uma operação de crédito por personagem por vez (o fechamento automático também passa por aqui).
local function withCreditLock(characterId, run)
	local waited = 0
	while creditLocks[characterId] do
		if waited >= 5000 then
			return 'busy'
		end
		Wait(50)
		waited = waited + 50
	end
	creditLocks[characterId] = true
	local ok, first, second = pcall(run)
	creditLocks[characterId] = nil
	if not ok then
		log('error', 'banking', 'credit_failed', { character_id = characterId, error_code = tostring(first) })
		return 'database_error'
	end
	return first, second
end

local function scoreOf(characterId, state)
	local stats = remote('coe_economy', 'LedgerStats', characterId, creditConfig.Score.InflowDays, creditConfig.Score.IgnoredReasons)
	if type(stats) ~= 'table' or stats.error then
		stats = {}
	end
	-- Parcelas de empréstimo contam como faturas: em dia sobem, atrasadas derrubam.
	local onTime, lateCount, late = state and state.onTime or 0, state and state.lateCount or 0, state and state.late or false
	for _, loan in ipairs(BankingPersistence.Loans(characterId, 20) or {}) do
		onTime = onTime + loan.onTime
		lateCount = lateCount + loan.lateCount
		late = late or (loan.status == 'active' and loan.late)
	end
	return CreditRules.Score({
		now = os.time(), firstAt = stats.firstAt, inflow = stats.inflow, balance = balanceOf(characterId),
		onTime = onTime, lateCount = lateCount, late = late
	}, creditConfig)
end

local CREDIT_NOTICES = {
	closed = function(amount, state)
		if amount <= 0 then
			return nil
		end
		return 'info', ('Fatura do cartão fechada: %s (mínimo %s), vence em %d dias.'):format(money(amount), money(state.invoiceMin), creditConfig.DueDays)
	end,
	late_fee = function(amount)
		return 'error', ('Fatura do cartão em atraso: multa de %s e crédito bloqueado até pagar o mínimo.'):format(money(amount))
	end,
	auto_debit = function(amount)
		return 'info', ('Débito automático de %s na fatura em atraso.'):format(money(amount))
	end,
	downgrade = function(_, state)
		local tier = CreditRules.Tier(creditConfig, state.tier)
		return 'error', ('Seu cartão foi rebaixado para %s.'):format(tier and tier.label or state.tier)
	end
}

-- Leva a conta até agora (vencimento, juros, fechamento, rebaixamento, débito automático) e grava.
-- Devolve o estado, `false` sem conta de crédito, ou nil + código. Chamar dentro de withCreditLock.
local function settleCredit(characterId)
	local state, loadError = BankingPersistence.Credit(characterId)
	if state == nil then
		return nil, loadError
	end
	if state == false then
		return false
	end
	local previousLimit = state.limit
	CreditRules.Refresh(state, creditConfig)
	local now = os.time()
	local entries = {}
	local closed = false
	for _, event in ipairs(CreditRules.Advance(state, now, creditConfig)) do
		if event.kind ~= 'on_time' then
			entries[#entries + 1] = { kind = event.kind, amount = event.amount, at = event.at }
		end
		closed = closed or event.kind == 'closed'
	end
	if closed then
		local lower = CreditRules.Downgrade(state, scoreOf(characterId, state), creditConfig)
		if lower then
			CreditRules.SetTier(state, lower)
			entries[#entries + 1] = { kind = 'downgrade', amount = lower.limit, description = lower.label, at = now }
		end
	end
	local debited = 0
	if CreditRules.AutoDebitDue(state, now, creditConfig) then
		local amount = math.min(balanceOf(characterId) or 0, state.invoice)
		if amount > 0 and debit(characterId, amount, 'card_invoice', 'auto') then
			debited = CreditRules.Pay(state, amount)
			entries[#entries + 1] = { kind = 'auto_debit', amount = debited, at = now }
		end
	end
	if #entries == 0 and state.limit == previousLimit then
		return state
	end
	local saved, saveError = BankingPersistence.SaveCredit(state, entries)
	if not saved then
		if debited > 0 and not credit(characterId, debited, 'bank_refund', 'auto') then
			log('error', 'banking', 'refund_failed', { character_id = characterId, count = debited, action = 'auto_debit' })
		end
		return nil, saveError
	end
	local playerId = playerOf(characterId)
	if playerId then
		for _, entry in ipairs(entries) do
			local notice = CREDIT_NOTICES[entry.kind]
			if notice then
				local kind, message = notice(entry.amount, state)
				if kind then
					notify(playerId, kind, message)
				end
			end
		end
	end
	return state
end

local loanConfig = config.Loans

-- Pontuação do negócio para o empréstimo empresarial: média dos devedores (dono e sócios).
local function debtorsScore(debtors)
	local total = 0
	for _, characterId in ipairs(debtors) do
		local state = BankingPersistence.Credit(characterId)
		total = total + scoreOf(characterId, type(state) == 'table' and state or nil)
	end
	return #debtors > 0 and total // #debtors or 0
end

-- Devedores atuais do negócio (dono + sócios aceitos), ou nil sem dono.
local function businessDebtors(businessId)
	local list = remote('coe_businesses', 'Debtors', businessId)
	if type(list) ~= 'table' or #list == 0 then
		return nil
	end
	local debtors = {}
	for _, characterId in ipairs(list) do
		debtors[#debtors + 1] = tostring(characterId)
	end
	return debtors
end

-- Saldo a pagar já com os juros de atraso até agora (sem gravar).
local function loanView(loan, now)
	local preview = {}
	for key, value in pairs(loan) do
		preview[key] = value
	end
	LoanRules.Accrue(preview, now or os.time(), loanConfig)
	return {
		id = loan.id, principal = loan.principal, rate = loan.rate, total = loan.total, installments = loan.installments,
		paidCount = preview.paidCount, paidAmount = preview.paidAmount, remaining = preview.remaining, dueAt = preview.dueAt,
		late = preview.late, lateCount = preview.lateCount, status = preview.status, note = loan.note,
		payable = LoanRules.Payable(preview), createdAt = loan.createdAt, closedAt = loan.closedAt,
		lateRate = loan.lateRate, interest = preview.interest, businessId = loan.businessId, businessLabel = loan.businessLabel
	}
end

local LOAN_NOTICES = {
	loan_payment = function(amount, loan)
		return 'info', ('Parcela do empréstimo debitada: %s (%d/%d).'):format(money(amount), loan.paidCount, loan.installments)
	end,
	loan_late = function(_, loan)
		return 'error', ('Parcela do empréstimo em atraso: %s. Juros de %s%% ao dia até pagar.')
			:format(money(loan.remaining), tostring(loan.lateRate))
	end,
	loan_interest = function(amount, loan)
		return 'error', ('Juros de atraso de %s no empréstimo; parcela agora em %s.'):format(money(amount), money(loan.remaining))
	end,
	loan_paid = function()
		return 'success', 'Empréstimo quitado.'
	end
}

local function loanLabel(loan)
	return ('#%d %d/%d'):format(loan.id, math.min(loan.paidCount + 1, loan.installments), loan.installments)
end

local function notifyDebtors(loan, kind, message)
	local prefix = loan.businessId and ('[%s] '):format(loan.businessLabel ~= '' and loan.businessLabel or loan.businessId) or ''
	for _, characterId in ipairs(BankingPersistence.Debtors(loan.id) or { loan.characterId }) do
		local playerId = playerOf(characterId)
		if playerId then
			notify(playerId, kind, prefix .. message)
		end
	end
end

-- Quem paga: a conta de um personagem ou o caixa do negócio. Empresariais têm débito automático no caixa.
local function accountPayer(characterId)
	return {
		balance = function()
			return balanceOf(characterId)
		end,
		charge = function(amount, reference)
			return debit(characterId, amount, 'loan_payment', reference)
		end,
		refund = function(amount, reference)
			return credit(characterId, amount, 'bank_refund', reference)
		end
	}
end

local function businessPayer(businessId)
	return {
		balance = function()
			local balance = remote('coe_economy', 'SocietyBalance', businessId)
			return type(balance) == 'number' and balance or nil
		end,
		charge = function(amount, reference)
			return remote('coe_economy', 'SocietyCharge', businessId, amount, 'loan_payment', reference) == true
		end,
		refund = function(amount)
			return remote('coe_economy', 'SocietyCollect', businessId, amount, 'bank_refund') == true
		end
	}
end

local function loanPayer(loan)
	return loan.businessId and businessPayer(loan.businessId) or accountPayer(loan.characterId)
end

-- Leva o empréstimo até agora: juros de atraso, pagamento e atraso; grava e avisa os devedores.
-- payment: { payer, mode = 'auto' | 'installment' | 'total', reference }. Devolve o valor pago ou nil + código.
-- Chamar dentro de withCreditLock('loan:' .. id).
local function settleLoan(loan, now, payment)
	local entries = {}
	local interest = LoanRules.Accrue(loan, now, loanConfig)
	if interest > 0 then
		entries[#entries + 1] = { kind = 'loan_interest', amount = interest, description = loanLabel(loan), at = now }
	end
	local debited = 0
	if payment then
		local amount
		if payment.mode == 'auto' then
			amount = LoanRules.Due(loan, now) and math.min(payment.payer.balance() or 0, loan.remaining) or 0
		else
			amount = payment.mode == 'total' and LoanRules.Payable(loan) or loan.remaining
			if amount <= 0 then
				return nil, 'nothing_to_pay'
			end
			local balance = payment.payer.balance()
			if not balance then
				return nil, 'economy_unavailable'
			end
			if balance < amount then
				return nil, 'insufficient_funds'
			end
		end
		if amount > 0 then
			if payment.payer.charge(amount, payment.reference) then
				debited = amount
			elseif payment.mode ~= 'auto' then
				return nil, 'insufficient_funds'
			end
		end
	end
	if debited > 0 then
		local label = loanLabel(loan)
		LoanRules.Pay(loan, debited, loanConfig)
		entries[#entries + 1] = { kind = 'loan_payment', amount = debited, description = label, at = now }
	end
	if LoanRules.Advance(loan, now) then
		entries[#entries + 1] = { kind = 'loan_late', amount = loan.remaining, description = loanLabel(loan), at = now }
	end
	if loan.status == 'paid' then
		entries[#entries + 1] = { kind = 'loan_paid', amount = loan.total + loan.interest, description = '#' .. loan.id, at = now }
	end
	if #entries == 0 then
		return debited
	end
	local saved, saveError = BankingPersistence.SaveLoan(loan, entries, now)
	if not saved then
		if debited > 0 and not payment.payer.refund(debited, payment.reference) then
			log('error', 'banking', 'refund_failed', { character_id = loan.characterId, count = debited, action = 'loan_payment' })
		end
		return nil, saveError
	end
	for _, entry in ipairs(entries) do
		local kind, message = LOAN_NOTICES[entry.kind](entry.amount, loan)
		notifyDebtors(loan, kind, message)
	end
	return debited
end

-- Débito automático da parcela vencida (repete enquanto houver atraso) e juros diários.
local function settleDueLoan(loanId)
	return withCreditLock('loan:' .. loanId, function()
		local loan = BankingPersistence.Loan(loanId)
		if not loan or loan.status ~= 'active' then
			return nil
		end
		return settleLoan(loan, os.time(), { payer = loanPayer(loan), mode = 'auto', reference = 'loan:' .. loan.id })
	end)
end

local function isDebtor(loan, characterId)
	for _, debtor in ipairs(BankingPersistence.Debtors(loan.id) or {}) do
		if debtor == characterId then
			return true
		end
	end
	return false
end

local function requestView(request)
	return {
		id = request.id, businessId = request.businessId, businessLabel = request.businessLabel, characterId = request.characterId,
		principal = request.principal, installments = request.installments, note = request.note, score = request.score,
		rate = request.rate, lateRate = request.lateRate, status = request.status, reason = request.reason, loanId = request.loanId,
		createdAt = request.createdAt, decidedAt = request.decidedAt
	}
end

local function tierView(tier)
	return {
		id = tier.id, label = tier.label, minScore = tier.minScore, limit = tier.limit,
		pointsPer100 = tier.pointsPer100, fee = tier.fee, freeAtm = tier.freeAtm == true
	}
end

local function creditView(characterId)
	local state = withCreditLock(characterId, function()
		return settleCredit(characterId)
	end)
	if type(state) ~= 'table' then
		state = nil
	end
	local score = scoreOf(characterId, state)
	local tiers = {}
	for _, tier in ipairs(creditConfig.Tiers) do
		tiers[#tiers + 1] = tierView(tier)
	end
	local eligible = CreditRules.Eligible(score, creditConfig)
	local view = {
		score = score,
		tiers = tiers,
		eligible = eligible and eligible.id or nil,
		atmFee = config.AtmWithdrawFee,
		dueDays = creditConfig.DueDays,
		cycleDays = creditConfig.CycleDays
	}
	if state then
		view.account = {
			tier = state.tier, limit = state.limit, available = CreditRules.Available(state), open = state.open,
			invoice = state.invoice, invoiceMin = state.invoiceMin, invoicePaid = state.invoicePaid,
			minLeft = math.max(0, state.invoiceMin - state.invoicePaid), dueAt = state.dueAt, closesAt = state.closesAt,
			late = state.late, points = state.points, onTime = state.onTime, lateCount = state.lateCount,
			payable = CreditRules.Payable(state), now = os.time(), customLimit = state.customLimit, tierLocked = state.tierLocked
		}
	end
	view.entries = BankingPersistence.CreditEntries(characterId, creditConfig.StatementSize) or {}
	view.loans = {}
	for _, loan in ipairs(BankingPersistence.Loans(characterId, 10) or {}) do
		view.loans[#view.loans + 1] = loanView(loan)
	end
	view.now = os.time()
	return view
end

-- Nível de crédito da conta (nil sem cartão de crédito).
local function creditTierOf(characterId)
	local state = BankingPersistence.Credit(characterId)
	return type(state) == 'table' and CreditRules.Tier(creditConfig, state.tier) or nil
end

-- Tarifa de saque no caixa eletrônico para a conta (níveis com freeAtm não pagam).
local function atmFeeFor(characterId)
	local fee = config.AtmWithdrawFee or 0
	if fee <= 0 then
		return 0
	end
	local tier = creditTierOf(characterId)
	return (tier and tier.freeAtm) and 0 or fee
end

local function agencyView(playerId, agency, who)
	local inventoryId = inventoryOf(playerId)
	local cards = {}
	for _, card in ipairs(BankingPersistence.AccountCards('personal', who.characterId) or {}) do
		cards[#cards + 1] = cardView(card)
	end
	return {
		mode = 'agency',
		title = agency.label,
		holder = who.name,
		balance = balanceOf(who.characterId),
		cash = inventoryId and cashOf(inventoryId) or 0,
		cardFee = config.CardFee,
		cardRenewFee = config.CardRenewFee or 0,
		virtualCardFee = config.VirtualCardFee or 0,
		cardValidityDays = config.CardValidityDays,
		maxAmount = config.MaxAgencyAmount,
		cards = cards,
		statement = statement(who.characterId, config.StatementSize),
		credit = creditView(who.characterId),
		-- Tem conta empresarial para trocar (a conta da empresa abre separada, em BankingBusiness).
		switchable = #BankingBusiness.Accounts(who.characterId) > 0
	}
end

-- Tela de escolha da conta ao abrir a agência: pessoal ou uma das empresas.
local function chooseView(agency, who, accounts)
	return { mode = 'choose', title = agency.label, holder = who.name, accounts = accounts }
end

-- Conta aberta na agência: pessoal (businessId nil) ou empresarial.
local function accountView(playerId, agency, who)
	local businessId = agencyAccount[playerId]
	if businessId then
		local view = BankingBusiness.AgencyView(playerId, agency, who, businessId)
		if view then
			return view
		end
		agencyAccount[playerId] = nil
	end
	return agencyView(playerId, agency, who)
end

-- Executa uma operação com trava por jogador; `run()` devolve código de erro ou nil.
local function guarded(playerId, run)
	if not ready then
		return fail(playerId, 'not_ready')
	end
	if busy[playerId] or throttled(playerId) then
		return fail(playerId, 'busy')
	end
	busy[playerId] = true
	local ok, errorCode = pcall(run)
	busy[playerId] = nil
	if not ok then
		log('error', 'banking', 'operation_failed', { player_id = playerId, error_code = tostring(errorCode) })
		return fail(playerId, 'database_error')
	end
	if errorCode then
		fail(playerId, errorCode)
	end
end

RegisterNetEvent('coe_banking:openAgency', function(agencyId)
	local playerId = source
	guarded(playerId, function()
		local agency = agencyById(agencyId)
		if not nearAgency(playerId, agency) then
			return 'too_far'
		end
		local who = character(playerId)
		if not who then
			return 'no_character'
		end
		agencyOpen[playerId] = agency.id
		agencyAccount[playerId] = nil
		BankingBusiness.ResetFilter(playerId)
		local accounts = BankingBusiness.Accounts(who.characterId)
		if #accounts > 0 then
			TriggerClientEvent('coe_banking:open', playerId, chooseView(agency, who, accounts))
			return
		end
		TriggerClientEvent('coe_banking:open', playerId, agencyView(playerId, agency, who))
	end)
end)

-- Escolha (ou troca) da conta na agência: kind = 'personal' | 'business' (com businessId) | 'choose' (volta à escolha).
RegisterNetEvent('coe_banking:agencyAccount', function(kind, businessId)
	local playerId = source
	guarded(playerId, function()
		local agency = agencyById(agencyOpen[playerId])
		if not nearAgency(playerId, agency) then
			agencyOpen[playerId] = nil
			return 'too_far'
		end
		local who = character(playerId)
		if not who then
			return 'no_character'
		end
		BankingBusiness.ResetFilter(playerId)
		if kind == 'choose' then
			agencyAccount[playerId] = nil
			TriggerClientEvent('coe_banking:update', playerId, chooseView(agency, who, BankingBusiness.Accounts(who.characterId)))
			return nil
		end
		if kind == 'business' then
			local business = BankingBusiness.Rights(businessId, who.characterId)
			if not business then
				return 'not_staff'
			end
			agencyAccount[playerId] = business.id
			audit('bank_business_open', { character_id = who.characterId, action = business.id })
		else
			agencyAccount[playerId] = nil
		end
		TriggerClientEvent('coe_banking:update', playerId, accountView(playerId, agency, who))
	end)
end)

local function ownCard(cardId, who)
	local id = BankingRules.CardId(cardId)
	if not id then
		return nil, 'card_not_found'
	end
	local card, cardError = BankingPersistence.Card(id)
	if not card then
		return nil, cardError
	end
	if card.accountType ~= 'personal' or card.accountRef ~= who.characterId then
		return nil, 'not_owner'
	end
	return card
end

local function issueCard(playerId, who, data)
	local pin, pinError = BankingRules.Pin(data.pin)
	if not pin then
		return pinError
	end
	local inventoryId = inventoryOf(playerId)
	if not inventoryId then
		return 'inventory_full'
	end
	-- Troca de cartão vencido (sem nenhum ativo) usa a tarifa de renovação.
	local hasActive, hasExpired = false, false
	for _, existing in ipairs(BankingPersistence.AccountCards('personal', who.characterId) or {}) do
		if existing.kind == 'physical' then
			local status = BankingRules.Status(existing)
			hasActive = hasActive or status == 'active'
			hasExpired = hasExpired or status == 'expired'
		end
	end
	local fee = (hasExpired and not hasActive) and (config.CardRenewFee or 0) or config.CardFee
	if fee > 0 then
		local balance = balanceOf(who.characterId)
		if not balance then
			return 'economy_unavailable'
		end
		if balance < fee or not debit(who.characterId, fee, 'card_fee', '') then
			return 'insufficient_funds'
		end
	end
	local refund = function()
		if fee > 0 then
			credit(who.characterId, fee, 'bank_refund', '')
		end
	end
	local salt = BankingRules.Salt(digit)
	local card = {
		accountType = 'personal', accountRef = who.characterId, holderId = who.characterId, holderName = who.name:sub(1, 64),
		pinSalt = salt, pinHash = BankingRules.HashPin(pin, salt, config.PinHashRounds, hashKey),
		expiresAt = os.time() + config.CardValidityDays * 86400, kind = 'physical'
	}
	local cardId, insertError
	for _ = 1, 3 do
		card.serial = BankingRules.Serial(digit)
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
	local metadata = {
		cardId = cardId, last4 = last4, holder = card.holderName, label = 'Cartão bancário •••• ' .. last4,
		validUntil = os.date('%d/%m/%Y', card.expiresAt)
	}
	if remote('coe_inventory', 'AddItem', inventoryId, 'card_bank', 1, metadata) ~= true then
		BankingPersistence.Block(cardId, 'failed')
		refund()
		return 'inventory_full'
	end
	BankingPersistence.ReplaceOthers('personal', who.characterId, who.characterId, cardId, 'physical')
	audit('bank_card_issued', { character_id = who.characterId, item = 'card_bank', request_id = tostring(cardId) })
	notify(playerId, 'success', _t('card_issued', { last4 = last4, validUntil = metadata.validUntil }))
	return nil
end

-- Cartão virtual: sem item nem senha, usado só pela carteira do smartphone. Um ativo por conta (o novo bloqueia o anterior).
local function issueVirtual(playerId, who)
	local fee = config.VirtualCardFee or 0
	if fee > 0 then
		local balance = balanceOf(who.characterId)
		if not balance then
			return nil, 'economy_unavailable'
		end
		if balance < fee or not debit(who.characterId, fee, 'card_fee', '') then
			return nil, 'insufficient_funds'
		end
	end
	local card = {
		accountType = 'personal', accountRef = who.characterId, holderId = who.characterId, holderName = who.name:sub(1, 64),
		pinSalt = '', pinHash = '', expiresAt = os.time() + config.CardValidityDays * 86400, kind = 'virtual'
	}
	local cardId, insertError
	for _ = 1, 3 do
		card.serial = BankingRules.Serial(digit)
		cardId, insertError = BankingPersistence.InsertCard(card)
		if cardId or insertError ~= 'duplicate' then
			break
		end
	end
	if not cardId then
		if fee > 0 then
			credit(who.characterId, fee, 'bank_refund', '')
		end
		return nil, 'database_error'
	end
	BankingPersistence.ReplaceOthers('personal', who.characterId, who.characterId, cardId, 'virtual')
	card.id = cardId
	audit('bank_card_issued', { character_id = who.characterId, item = 'virtual', request_id = tostring(cardId) })
	notify(playerId, 'success', _t('virtual_card_issued', { last4 = BankingRules.Last4(card.serial) }))
	return card
end

local AGENCY_ACTIONS = {}

function AGENCY_ACTIONS.withdraw(playerId, who, data, agency)
	local amount, amountError = BankingRules.Amount(data.amount, config.MaxAgencyAmount)
	if not amount then
		return amountError
	end
	local errorCode = withdrawCash(playerId, who.characterId, amount, 'agency:' .. agency.id)
	if errorCode then
		return errorCode
	end
	audit('bank_withdraw', { character_id = who.characterId, count = amount, action = 'agency' })
	notify(playerId, 'success', _t('withdraw_success', { amount = money(amount) }))
end

function AGENCY_ACTIONS.deposit(playerId, who, data, agency)
	local amount, amountError = BankingRules.Amount(data.amount, config.MaxAgencyAmount)
	if not amount then
		return amountError
	end
	local errorCode = depositCash(playerId, who.characterId, amount, 'agency:' .. agency.id)
	if errorCode then
		return errorCode
	end
	audit('bank_deposit', { character_id = who.characterId, count = amount, action = 'agency' })
	notify(playerId, 'success', _t('deposit_success', { amount = money(amount) }))
end

function AGENCY_ACTIONS.transfer(playerId, who, data)
	local amount, amountError = BankingRules.Amount(data.amount, config.MaxAgencyAmount)
	if not amount then
		return amountError
	end
	local stateId, stateError = BankingRules.StateId(data.stateId)
	if not stateId then
		return stateError
	end
	local target, targetError = BankingPersistence.FindCharacterByStateId(stateId)
	if not target then
		return targetError
	end
	if target.characterId == who.characterId then
		return 'same_account'
	end
	local balance = balanceOf(who.characterId)
	if not balance then
		return 'economy_unavailable'
	end
	if balance < amount then
		return 'insufficient_funds'
	end
	if remote('coe_economy', 'Transfer', who.characterId, target.characterId, amount, 'bank_transfer', 'state:' .. stateId) ~= true then
		return 'balance_limit'
	end
	audit('bank_transfer', { character_id = who.characterId, target = target.characterId, count = amount })
	notify(playerId, 'success', _t('transfer_success', { amount = money(amount), target = target.name }))
	local recipient = playerOf(target.characterId)
	if recipient then
		notify(recipient, 'info', _t('transfer_received', { amount = money(amount), sender = who.name }))
	end
end

function AGENCY_ACTIONS.issueCard(playerId, who, data)
	return issueCard(playerId, who, data)
end

function AGENCY_ACTIONS.issueVirtual(playerId, who)
	local _, errorCode = issueVirtual(playerId, who)
	return errorCode
end

function AGENCY_ACTIONS.blockCard(playerId, who, data)
	local card, cardError = ownCard(data.cardId, who)
	if not card then
		return cardError
	end
	if not BankingRules.CanResetPin(card) then
		return 'card_blocked'
	end
	-- Bloqueado por senha vira bloqueio definitivo (perda/roubo).
	local done
	if card.blockedReason == 'pin' then
		done = BankingPersistence.SetAttempts(card.id, card.attempts, 'lost')
	else
		done = BankingPersistence.Block(card.id, 'lost')
	end
	if not done then
		return 'database_error'
	end
	audit('bank_card_blocked', { character_id = who.characterId, item = 'card_bank', request_id = tostring(card.id), action = 'lost' })
	notify(playerId, 'success', _t('card_blocked_success', { last4 = BankingRules.Last4(card.serial) }))
end

function AGENCY_ACTIONS.changePin(playerId, who, data)
	local card, cardError = ownCard(data.cardId, who)
	if not card then
		return cardError
	end
	if card.kind == 'virtual' then
		return 'virtual_no_pin'
	end
	if not BankingRules.CanResetPin(card) then
		return 'card_blocked'
	end
	local pin, pinError = BankingRules.Pin(data.pin)
	if not pin then
		return pinError
	end
	local salt = BankingRules.Salt(digit)
	if not BankingPersistence.SetPin(card.id, BankingRules.HashPin(pin, salt, config.PinHashRounds, hashKey), salt) then
		return 'database_error'
	end
	audit('bank_card_pin', { character_id = who.characterId, item = 'card_bank', request_id = tostring(card.id) })
	notify(playerId, 'success', card.blockedReason == 'pin' and _t('pin_changed_unblocked') or _t('pin_changed'))
end

-- Pede o cartão de crédito (primeiro nível liberado) ou o upgrade para o maior nível liberado pela pontuação.
function AGENCY_ACTIONS.creditRequest(playerId, who)
	local characterId = who.characterId
	local result, resultError = withCreditLock(characterId, function()
		local state, loadError = settleCredit(characterId)
		if state == nil then
			return nil, loadError
		end
		local current = state or nil
		local tier, tierError = CreditRules.Upgrade(current, scoreOf(characterId, current), creditConfig)
		if not tier then
			return nil, tierError
		end
		local entry = { kind = 'tier', amount = tier.limit, description = tier.label, at = os.time() }
		if current then
			CreditRules.SetTier(current, tier)
			local saved, saveError = BankingPersistence.SaveCredit(current, { entry })
			if not saved then
				return nil, saveError
			end
		else
			local fresh = CreditRules.New(tier, os.time(), creditConfig)
			fresh.characterId = characterId
			local inserted, insertError = BankingPersistence.InsertCredit(fresh, os.time(), { entry })
			if not inserted then
				return nil, insertError
			end
		end
		return tier
	end)
	if type(result) ~= 'table' then
		return resultError or result
	end
	audit('bank_credit_tier', { character_id = characterId, action = result.id, count = result.limit })
	notify(playerId, 'success', _t('credit_unlocked', { label = result.label, limit = money(result.limit) }))
end

-- Paga a fatura com o saldo da conta. mode: total | min | amount (valor livre).
function AGENCY_ACTIONS.creditPay(playerId, who, data)
	local characterId = who.characterId
	local requested
	if data.mode == 'amount' then
		local amount, amountError = BankingRules.Amount(data.amount, creditConfig.MaxPayment)
		if not amount then
			return amountError
		end
		requested = amount
	elseif data.mode ~= 'total' and data.mode ~= 'min' then
		return 'invalid_amount'
	end
	local paid, payError = withCreditLock(characterId, function()
		local state, loadError = settleCredit(characterId)
		if not state then
			return nil, state == false and 'no_credit' or loadError
		end
		local amount = requested
		if data.mode == 'total' then
			amount = CreditRules.Payable(state)
		elseif data.mode == 'min' then
			amount = math.max(0, state.invoiceMin - state.invoicePaid)
		end
		amount = math.min(amount, CreditRules.Payable(state))
		if amount <= 0 then
			return nil, 'nothing_to_pay'
		end
		local balance = balanceOf(characterId)
		if not balance then
			return nil, 'economy_unavailable'
		end
		if balance < amount or not debit(characterId, amount, 'card_invoice', 'agency') then
			return nil, 'insufficient_funds'
		end
		local applied = CreditRules.Pay(state, amount)
		local saved, saveError = BankingPersistence.SaveCredit(state, { { kind = 'payment', amount = applied, at = os.time() } })
		if not saved then
			if not credit(characterId, amount, 'bank_refund', 'agency') then
				log('error', 'banking', 'refund_failed', { character_id = characterId, count = amount, action = 'card_invoice' })
			end
			return nil, saveError
		end
		return applied
	end)
	if type(paid) ~= 'number' then
		return payError or paid
	end
	audit('bank_credit_payment', { character_id = characterId, count = paid })
	notify(playerId, 'success', _t('credit_payment_success', { amount = money(paid) }))
end

-- Paga a parcela atual ou quita o empréstimo com o saldo da conta pessoal (qualquer devedor, inclusive de empréstimo empresarial).
-- mode: installment | total.
function AGENCY_ACTIONS.loanPay(playerId, who, data)
	local characterId = who.characterId
	local loanId = math.tointeger(tonumber(data.loanId))
	if not loanId or (data.mode ~= 'installment' and data.mode ~= 'total') then
		return 'loan_not_found'
	end
	local paid, payError = withCreditLock('loan:' .. loanId, function()
		local loan, loanError = BankingPersistence.Loan(loanId)
		if not loan then
			return nil, loanError
		end
		if loan.status ~= 'active' or not isDebtor(loan, characterId) then
			return nil, 'loan_not_found'
		end
		return settleLoan(loan, os.time(), { payer = accountPayer(characterId), mode = data.mode, reference = 'agency' })
	end)
	if type(paid) ~= 'number' then
		return payError or paid
	end
	audit('bank_loan_payment', { character_id = characterId, count = paid, request_id = tostring(loanId) })
end

-- Pedido de empréstimo em nome do negócio (só o dono). Vai para a fila da staff; as taxas saem da pontuação dos devedores.
-- Chamado pela conta empresarial (server/business.lua), que já conferiu que quem pede é o dono.
local function requestBusinessLoan(playerId, who, businessId, data)
	local result, resultError = withCreditLock('business:' .. businessId, function()
		local debtors = businessDebtors(businessId)
		if not debtors then
			return nil, 'not_business_owner'
		end
		local score = debtorsScore(debtors)
		local pricing = LoanRules.Pricing(score, loanConfig)
		local clean, cleanError = LoanRules.Validate({
			principal = data.principal, installments = data.installments, rate = pricing.rate, note = data.note
		}, loanConfig)
		if not clean then
			return nil, cleanError
		end
		local pending = BankingPersistence.Requests('pending', businessId, loanConfig.MaxPendingRequests)
		if not pending then
			return nil, 'database_error'
		end
		if #pending >= loanConfig.MaxPendingRequests then
			return nil, 'request_pending'
		end
		local active = BankingPersistence.ActiveBusinessLoans(businessId)
		if not active then
			return nil, 'database_error'
		end
		if active >= loanConfig.MaxActiveBusiness then
			return nil, 'business_loan_active'
		end
		local business = remote('coe_businesses', 'Get', businessId)
		return BankingPersistence.InsertRequest({
			businessId = businessId, businessLabel = (type(business) == 'table' and business.label or businessId):sub(1, 64),
			characterId = who.characterId, principal = clean.principal, installments = clean.installments, note = clean.note,
			score = math.min(score, 65535), rate = pricing.rate, lateRate = pricing.lateDailyRate
		}, os.time())
	end)
	if type(result) ~= 'number' then
		return resultError or result
	end
	audit('bank_loan_requested', { character_id = who.characterId, action = businessId, request_id = tostring(result) })
	notify(playerId, 'success', _t('loan_requested'))
end

local function cancelBusinessLoan(playerId, who, businessId, data)
	local requestId = math.tointeger(tonumber(data.requestId))
	local result = requestId and withCreditLock('business:' .. businessId, function()
		local request = BankingPersistence.Request(requestId)
		if not request or request.businessId ~= businessId or request.characterId ~= who.characterId then
			return nil
		end
		return BankingPersistence.DecideRequest(requestId, 'pending', 'cancelled', '', 0, os.time())
	end)
	if result ~= true then
		return 'request_not_found'
	end
	notify(playerId, 'success', _t('loan_cancelled'))
end
RegisterNetEvent('coe_banking:agency', function(action, data)
	local playerId = source
	local handler = type(action) == 'string' and AGENCY_ACTIONS[action] or nil
	if not handler or type(data) ~= 'table' then
		return
	end
	guarded(playerId, function()
		local agency = agencyById(agencyOpen[playerId])
		if not nearAgency(playerId, agency) then
			agencyOpen[playerId] = nil
			return 'too_far'
		end
		local who = character(playerId)
		if not who then
			return 'no_character'
		end
		if agencyAccount[playerId] then
			-- Conta empresarial aberta: as operações pessoais não se aplicam.
			TriggerClientEvent('coe_banking:update', playerId, accountView(playerId, agency, who))
			return 'forbidden'
		end
		local errorCode = handler(playerId, who, data, agency)
		TriggerClientEvent('coe_banking:update', playerId, agencyView(playerId, agency, who))
		return errorCode
	end)
end)

-- Caixa eletrônico: cartão no inventário + senha. Vale para quem estiver com o cartão (roubo é RP).
local function cardInHand(playerId, cardId)
	local inventoryId = inventoryOf(playerId)
	if not inventoryId then
		return false
	end
	return (tonumber(remote('coe_inventory', 'GetItemCount', inventoryId, 'card_bank', { cardId = cardId }, false)) or 0) > 0
end

local function atmView(playerId, card)
	if card.accountType == 'business' then
		local business = BankingBusiness.CardUsable(card)
		if business then
			return BankingBusiness.AtmView(playerId, card, business)
		end
	end
	local inventoryId = inventoryOf(playerId)
	local tier = creditTierOf(card.accountRef)
	return {
		mode = 'atm',
		step = 'menu',
		cardId = card.id,
		last4 = BankingRules.Last4(card.serial),
		holder = card.holderName,
		tier = tier and tier.id or nil,
		tierLabel = tier and tier.label or nil,
		fee = (tier and tier.freeAtm) and 0 or (config.AtmWithdrawFee or 0),
		balance = balanceOf(card.accountRef),
		cash = inventoryId and cashOf(inventoryId) or 0,
		maxAmount = config.MaxAtmAmount,
		quick = config.AtmQuickAmounts,
		statement = statement(card.accountRef, config.AtmStatementSize)
	}
end

RegisterNetEvent('coe_banking:atmOpen', function()
	local playerId = source
	guarded(playerId, function()
		atmSessions[playerId] = nil
		local inventoryId = inventoryOf(playerId)
		local snapshot = inventoryId and remote('coe_inventory', 'GetInventory', inventoryId) or nil
		local cards = {}
		for _, cardId in ipairs(BankingRules.CardsInInventory(snapshot)) do
			local card = BankingPersistence.Card(cardId)
			if card then
				local business = card.accountType == 'business' and remote('coe_businesses', 'Get', card.accountRef) or nil
				cards[#cards + 1] = {
					id = card.id, last4 = BankingRules.Last4(card.serial), holder = card.holderName, status = BankingRules.Status(card),
					business = type(business) == 'table' and (business.label or business.id) or nil
				}
			end
		end
		if #cards == 0 then
			return 'no_card'
		end
		TriggerClientEvent('coe_banking:open', playerId, { mode = 'atm', step = 'cards', cards = cards, maxAttempts = config.MaxPinAttempts })
	end)
end)

RegisterNetEvent('coe_banking:atmAuth', function(cardId, pin)
	local playerId = source
	guarded(playerId, function()
		local id = BankingRules.CardId(cardId)
		if not id or type(pin) ~= 'string' or not cardInHand(playerId, id) then
			return 'no_card'
		end
		local card = BankingPersistence.Card(id)
		if not card then
			return 'no_card'
		end
		local check = BankingRules.CheckPin(card, pin, config, hashKey)
		if check.already then
			return BankingRules.Status(card) == 'expired' and 'card_expired' or 'card_blocked'
		end
		if not check.ok then
			BankingPersistence.SetAttempts(card.id, check.attempts, check.blocked and 'pin' or nil)
			if check.blocked then
				audit('bank_card_blocked', { character_id = card.accountRef, item = 'card_bank', request_id = tostring(card.id), action = 'pin' })
				TriggerClientEvent('coe_banking:close', playerId)
				notify(playerId, 'error', _t('wrong_pin_blocked'))
				return nil
			end
			TriggerClientEvent('coe_banking:pinError', playerId, config.MaxPinAttempts - check.attempts)
			return nil
		end
		if card.attempts > 0 then
			BankingPersistence.SetAttempts(card.id, 0, nil)
		end
		if card.accountType == 'business' then
			local business, businessError = BankingBusiness.CardUsable(card)
			if not business then
				TriggerClientEvent('coe_banking:close', playerId)
				return businessError
			end
		end
		atmSessions[playerId] = { cardId = card.id, expires = os.time() + config.AtmSessionSeconds }
		TriggerClientEvent('coe_banking:update', playerId, atmView(playerId, card))
	end)
end)

local ATM_ACTIONS = {}

function ATM_ACTIONS.withdraw(playerId, card, data, who)
	if card.accountType == 'business' then
		return BankingBusiness.AtmWithdraw(playerId, card, data, who)
	end
	local amount, amountError = BankingRules.Amount(data.amount, config.MaxAtmAmount)
	if not amount then
		return amountError
	end
	local fee = atmFeeFor(card.accountRef)
	if fee > 0 then
		local balance = balanceOf(card.accountRef)
		if not balance then
			return 'economy_unavailable'
		end
		if balance < amount + fee then
			return 'insufficient_funds'
		end
	end
	local errorCode = withdrawCash(playerId, card.accountRef, amount, 'atm:' .. card.id)
	if errorCode then
		return errorCode
	end
	if fee > 0 and not debit(card.accountRef, fee, 'atm_fee', 'atm:' .. card.id) then
		log('warn', 'banking', 'atm_fee_failed', { character_id = card.accountRef, count = fee })
		fee = 0
	end
	audit('bank_withdraw', { character_id = card.accountRef, target = who and who.characterId or nil, count = amount, action = 'atm' })
	notify(playerId, 'success', fee > 0 and _t('withdraw_fee', { amount = money(amount), fee = money(fee) }) or _t('withdraw_success', { amount = money(amount) }))
end

function ATM_ACTIONS.deposit(playerId, card, data, who)
	if card.accountType == 'business' then
		return BankingBusiness.AtmDeposit(playerId, card, data, who)
	end
	local amount, amountError = BankingRules.Amount(data.amount, config.MaxAtmAmount)
	if not amount then
		return amountError
	end
	local errorCode = depositCash(playerId, card.accountRef, amount, 'atm:' .. card.id)
	if errorCode then
		return errorCode
	end
	audit('bank_deposit', { character_id = card.accountRef, target = who and who.characterId or nil, count = amount, action = 'atm' })
	notify(playerId, 'success', _t('deposit_success', { amount = money(amount) }))
end

function ATM_ACTIONS.refresh()
	return nil
end

RegisterNetEvent('coe_banking:atm', function(action, data)
	local playerId = source
	local handler = type(action) == 'string' and ATM_ACTIONS[action] or nil
	if not handler or type(data) ~= 'table' then
		return
	end
	guarded(playerId, function()
		local session = atmSessions[playerId]
		if not session or session.expires < os.time() then
			atmSessions[playerId] = nil
			TriggerClientEvent('coe_banking:close', playerId)
			return 'session_expired'
		end
		local card = BankingPersistence.Card(session.cardId)
		if not card or BankingRules.Status(card) ~= 'active' or not cardInHand(playerId, card.id) then
			atmSessions[playerId] = nil
			TriggerClientEvent('coe_banking:close', playerId)
			local status = card and BankingRules.Status(card) or nil
			return (status == 'expired' and 'card_expired') or (status and status ~= 'active' and 'card_blocked') or 'no_card'
		end
		if card.accountType == 'business' then
			local business, businessError = BankingBusiness.CardUsable(card)
			if not business then
				atmSessions[playerId] = nil
				TriggerClientEvent('coe_banking:close', playerId)
				return businessError
			end
		end
		session.expires = os.time() + config.AtmSessionSeconds
		local errorCode = handler(playerId, card, data, character(playerId))
		TriggerClientEvent('coe_banking:update', playerId, atmView(playerId, card))
		return errorCode
	end)
end)

RegisterNetEvent('coe_banking:closed', function()
	atmSessions[source] = nil
	agencyOpen[source] = nil
	agencyAccount[source] = nil
end)

-- Admin (só coe_admin; a permissão da staff é checada lá) --------------------------------------------

local function adminOnly()
	return GetInvokingResource() == 'coe_admin'
end

local function characterIdOf(value)
	local text = tostring(value or '')
	return text:match('^%d+$') and #text <= 20 and text or nil
end

local function wholeNumber(value, low, high)
	value = tonumber(value)
	if not value or value ~= value or value % 1 ~= 0 or value < low or value > high then
		return nil
	end
	return math.tointeger(value)
end

local function tierList()
	local list = {}
	for _, tier in ipairs(creditConfig.Tiers) do
		list[#list + 1] = tierView(tier)
	end
	return list
end

local function applyTiers(stored)
	for _, tier in ipairs(creditConfig.Tiers) do
		local saved = stored[tier.id]
		if saved then
			tier.label, tier.minScore, tier.limit = saved.label, saved.minScore, saved.limit
			tier.pointsPer100, tier.fee, tier.freeAtm = saved.pointsPer100, saved.fee, saved.freeAtm
		end
	end
end

local function staffNotify(characterId, kind, message)
	local playerId = playerOf(characterId)
	if playerId then
		notify(playerId, kind, message)
	end
end

local function adminLimits()
	return {
		maxLimit = creditConfig.AdminMaxLimit, maxPrincipal = loanConfig.MaxPrincipal, maxRate = loanConfig.MaxRate,
		maxInstallments = loanConfig.MaxInstallments, intervalDays = loanConfig.IntervalDays, cardValidityDays = config.CardValidityDays,
		pricing = loanConfig.Pricing
	}
end

exports('AdminTiers', function()
	if not adminOnly() then
		return { error = 'forbidden' }
	end
	return { tiers = tierList(), limits = adminLimits() }
end)

exports('AdminSaveTiers', function(list)
	if not adminOnly() then
		return { error = 'forbidden' }
	end
	if not ready then
		return { error = 'not_ready' }
	end
	local clean, errorCode = CreditRules.ValidateTiers(list, creditConfig)
	if not clean then
		return { error = errorCode }
	end
	if not BankingPersistence.SaveTiers(clean, os.time()) then
		return { error = 'database_error' }
	end
	local byId = {}
	for _, tier in ipairs(clean) do
		byId[tier.id] = tier
	end
	applyTiers(byId)
	return true
end)

exports('AdminAccount', function(characterId)
	if not adminOnly() then
		return { error = 'forbidden' }
	end
	characterId = characterIdOf(characterId)
	if not ready or not characterId then
		return { error = not ready and 'not_ready' or 'character_not_found' }
	end
	local balance = balanceOf(characterId)
	if not balance then
		return { error = 'character_not_found' }
	end
	local cards = {}
	for _, card in ipairs(BankingPersistence.CharacterCards(characterId) or {}) do
		cards[#cards + 1] = cardView(card)
	end
	local view = creditView(characterId)
	return {
		characterId = characterId, balance = balance, cards = cards, score = view.score, eligible = view.eligible,
		credit = view.account or false, loans = view.loans, entries = view.entries, tiers = view.tiers, limits = adminLimits(),
		pricing = LoanRules.Pricing(view.score, loanConfig), now = os.time()
	}
end)

-- data: { tier, customLimit (número ou false), tierLocked }. Cria a conta de crédito se não existir.
exports('AdminSetCredit', function(characterId, data)
	if not adminOnly() then
		return { error = 'forbidden' }
	end
	characterId = characterIdOf(characterId)
	if not ready or not characterId or type(data) ~= 'table' or not balanceOf(characterId) then
		return { error = 'character_not_found' }
	end
	local tier = CreditRules.Tier(creditConfig, data.tier)
	if not tier then
		return { error = 'invalid_tier' }
	end
	local customLimit = nil
	if data.customLimit ~= false and data.customLimit ~= nil then
		customLimit = wholeNumber(data.customLimit, 0, creditConfig.AdminMaxLimit)
		if not customLimit then
			return { error = 'invalid_amount' }
		end
	end
	local result, resultError = withCreditLock(characterId, function()
		local state, loadError = settleCredit(characterId)
		if state == nil then
			return nil, loadError
		end
		local now = os.time()
		local fresh = state == false
		if fresh then
			state = CreditRules.New(tier, now, creditConfig)
			state.characterId = characterId
		end
		state.customLimit = customLimit
		state.tierLocked = data.tierLocked == true
		CreditRules.SetTier(state, tier)
		local entry = { kind = 'staff_tier', amount = state.limit, description = tier.label, at = now }
		if fresh then
			return BankingPersistence.InsertCredit(state, now, { entry })
		end
		return BankingPersistence.SaveCredit(state, { entry })
	end)
	if result ~= true then
		return { error = resultError or result or 'database_error' }
	end
	staffNotify(characterId, 'info', ('Seu cartão de crédito foi ajustado pelo banco: %s, limite atualizado.'):format(tier.label))
	return true
end)

exports('AdminPoints', function(characterId, delta)
	if not adminOnly() then
		return { error = 'forbidden' }
	end
	characterId = characterIdOf(characterId)
	delta = wholeNumber(delta, -10000000, 10000000)
	if not ready or not characterId or not delta or delta == 0 then
		return { error = 'invalid_amount' }
	end
	local result, resultError = withCreditLock(characterId, function()
		local state, loadError = settleCredit(characterId)
		if not state then
			return nil, state == false and 'no_credit' or loadError
		end
		state.points = math.max(0, state.points + delta)
		return BankingPersistence.SaveCredit(state, { { kind = 'staff_points', amount = delta, at = os.time() } })
	end)
	if result ~= true then
		return { error = resultError or result or 'database_error' }
	end
	return true
end)

-- action: block | unblock | extend (nova validade a partir de agora).
exports('AdminCard', function(cardId, action)
	if not adminOnly() then
		return { error = 'forbidden' }
	end
	local id = BankingRules.CardId(cardId)
	local card = ready and id and BankingPersistence.Card(id) or nil
	if not card then
		return { error = 'card_not_found' }
	end
	local done
	if action == 'block' then
		done = BankingRules.Status(card) ~= 'blocked' and BankingPersistence.Block(card.id, 'staff')
	elseif action == 'unblock' then
		done = BankingPersistence.Unblock(card.id)
	elseif action == 'extend' then
		done = BankingPersistence.Extend(card.id, os.time() + config.CardValidityDays * 86400)
	end
	if not done then
		return { error = 'card_blocked' }
	end
	local texts = { block = 'bloqueado pelo banco', unblock = 'desbloqueado pelo banco', extend = 'teve a validade renovada' }
	staffNotify(card.accountRef, 'info', ('Seu cartão •••• %s %s.'):format(BankingRules.Last4(card.serial), texts[action]))
	return true
end)

-- input: { principal, rate (% total), installments, note }. O valor cai na conta; parcelas debitadas automaticamente.
exports('AdminGrantLoan', function(characterId, input)
	if not adminOnly() then
		return { error = 'forbidden' }
	end
	characterId = characterIdOf(characterId)
	if not ready or not characterId or not balanceOf(characterId) then
		return { error = 'character_not_found' }
	end
	local clean, errorCode = LoanRules.Validate(input, loanConfig)
	if not clean then
		return { error = errorCode }
	end
	local state = BankingPersistence.Credit(characterId)
	local pricing = LoanRules.Pricing(scoreOf(characterId, type(state) == 'table' and state or nil), loanConfig)
	local result, resultError = withCreditLock('loans:' .. characterId, function()
		local active = BankingPersistence.ActiveLoans(characterId)
		if not active then
			return nil, 'database_error'
		end
		if active >= loanConfig.MaxActive then
			return nil, 'loan_active'
		end
		local now = os.time()
		local loan = LoanRules.New(clean, now, loanConfig, pricing.lateDailyRate)
		local inserted, insertError = BankingPersistence.InsertLoan(characterId, loan, now, { characterId })
		if not inserted then
			log('error', 'banking', 'loan_insert_failed', { character_id = characterId, error_code = tostring(insertError or 'database_error') })
			return nil, insertError or 'database_error'
		end
		if not credit(characterId, loan.principal, 'bank_loan', 'loan:' .. loan.id) then
			BankingPersistence.DeleteLoan(loan.id)
			log('error', 'banking', 'loan_credit_failed', { character_id = characterId, count = loan.principal, request_id = tostring(loan.id) })
			return nil, 'economy_unavailable'
		end
		BankingPersistence.CreditNote(characterId, {
			kind = 'loan_granted', amount = loan.principal, description = ('#%d %dx %s'):format(loan.id, loan.installments, money(loan.total)), at = now
		})
		return loan
	end)
	if type(result) ~= 'table' then
		return { error = resultError or result or 'database_error' }
	end
	staffNotify(characterId, 'success', ('Empréstimo de %s creditado. %d parcelas de cerca de %s, a primeira em %d dias.')
		:format(money(result.principal), result.installments, money(result.total // result.installments), loanConfig.IntervalDays))
	return true
end)

exports('AdminForgiveLoan', function(loanId)
	if not adminOnly() then
		return { error = 'forbidden' }
	end
	loanId = math.tointeger(tonumber(loanId))
	if not ready or not loanId then
		return { error = 'loan_not_found' }
	end
	local forgiven
	local result, resultError = withCreditLock('loan:' .. loanId, function()
		local current, loadError = BankingPersistence.Loan(loanId)
		if not current then
			return nil, loadError
		end
		local now = os.time()
		LoanRules.Accrue(current, now, loanConfig)
		local amount = LoanRules.Payable(current)
		if not LoanRules.Forgive(current) then
			return nil, 'loan_not_found'
		end
		local saved, saveError = BankingPersistence.SaveLoan(current, {
			{ kind = 'loan_forgiven', amount = amount, description = '#' .. current.id, at = now }
		}, now)
		forgiven = saved and current or nil
		return saved, saveError
	end)
	if result ~= true then
		return { error = resultError or result or 'database_error' }
	end
	notifyDebtors(forgiven, 'success', _t('loan_forgiven', { id = forgiven.id }))
	return true
end)

-- Fila de pedidos de empréstimo empresarial: pendentes e as últimas decisões.
exports('AdminLoanRequests', function()
	if not adminOnly() then
		return { error = 'forbidden' }
	end
	if not ready then
		return { error = 'not_ready' }
	end
	local pending = BankingPersistence.Requests('pending', nil, 50)
	local recent = BankingPersistence.Requests(nil, nil, 30)
	if not pending or not recent then
		return { error = 'database_error' }
	end
	local list = {}
	for _, request in ipairs(pending) do
		local view = requestView(request)
		local debtors = businessDebtors(request.businessId)
		view.debtors = debtors and #debtors or 0
		view.currentScore = debtors and debtorsScore(debtors) or 0
		view.suggested = LoanRules.Pricing(view.currentScore, loanConfig)
		list[#list + 1] = view
	end
	local history = {}
	for _, request in ipairs(recent) do
		if request.status ~= 'pending' then
			history[#history + 1] = requestView(request)
		end
	end
	return { pending = list, history = history, limits = adminLimits() }
end)

-- decision: { approve = bool, rate, installments, reason }. Aprovado: o valor cai no caixa do negócio e a dívida
-- fica com o dono e os sócios de agora; as parcelas saem do caixa e, se faltar, o atraso pesa em todos.
exports('AdminDecideRequest', function(requestId, decision)
	if not adminOnly() then
		return { error = 'forbidden' }
	end
	requestId = math.tointeger(tonumber(requestId))
	if not ready or not requestId or type(decision) ~= 'table' then
		return { error = 'request_not_found' }
	end
	local request = BankingPersistence.Request(requestId)
	if not request or request.status ~= 'pending' then
		return { error = 'request_not_found' }
	end
	local reason = type(decision.reason) == 'string' and decision.reason:gsub('[<>]', ''):sub(1, 64) or ''
	if decision.approve ~= true then
		local done = withCreditLock('business:' .. request.businessId, function()
			return BankingPersistence.DecideRequest(requestId, 'pending', 'rejected', reason, 0, os.time())
		end)
		if done ~= true then
			return { error = 'request_not_found' }
		end
		staffNotify(request.characterId, 'error', ('Pedido de empréstimo de %s para %s recusado pelo banco.%s')
			:format(money(request.principal), request.businessLabel, reason ~= '' and (' Motivo: ' .. reason) or ''))
		return true
	end
	local clean, cleanError = LoanRules.Validate({
		principal = request.principal, rate = decision.rate ~= nil and decision.rate or request.rate,
		installments = decision.installments ~= nil and decision.installments or request.installments, note = request.note
	}, loanConfig)
	if not clean then
		return { error = cleanError }
	end
	local result, resultError = withCreditLock('business:' .. request.businessId, function()
		local current = BankingPersistence.Request(requestId)
		if not current or current.status ~= 'pending' then
			return nil, 'request_not_found'
		end
		local business = remote('coe_businesses', 'Get', request.businessId)
		local debtors = type(business) == 'table' and businessDebtors(request.businessId) or nil
		if not debtors then
			return nil, 'business_not_found'
		end
		-- O negócio mudou de dono depois do pedido: quem pediu não responde mais por ele.
		if tostring(debtors[1]) ~= tostring(request.characterId) then
			return nil, 'owner_changed'
		end
		local active = BankingPersistence.ActiveBusinessLoans(request.businessId)
		if not active then
			return nil, 'database_error'
		end
		if active >= loanConfig.MaxActiveBusiness then
			return nil, 'business_loan_active'
		end
		local now = os.time()
		local loan = LoanRules.New(clean, now, loanConfig, current.lateRate)
		local label = (business.label or request.businessId):sub(1, 64)
		local inserted, insertError = BankingPersistence.InsertLoan(debtors[1], loan, now, debtors, { id = request.businessId, label = label })
		if not inserted then
			log('error', 'banking', 'loan_insert_failed', { character_id = debtors[1], action = request.businessId, error_code = tostring(insertError or 'database_error') })
			return nil, insertError or 'database_error'
		end
		local collected = remote('coe_economy', 'SocietyCollect', request.businessId, loan.principal, 'bank_loan')
		if collected ~= true then
			BankingPersistence.DeleteLoan(loan.id)
			local collectError = type(collected) == 'table' and collected.error or 'economy_unavailable'
			log('error', 'banking', 'loan_collect_failed', { character_id = debtors[1], action = request.businessId, count = loan.principal, error_code = tostring(collectError) })
			return nil, collectError
		end
		if not BankingPersistence.DecideRequest(requestId, 'pending', 'approved', reason, loan.id, now) then
			log('error', 'banking', 'loan_request_state', { request_id = tostring(requestId), operation = tostring(loan.id) })
		end
		for _, debtor in ipairs(debtors) do
			BankingPersistence.CreditNote(debtor, {
				kind = 'loan_granted', amount = loan.principal,
				description = ('#%d %s %dx %s'):format(loan.id, label, loan.installments, money(loan.total)), at = now
			})
		end
		return loan
	end)
	if type(result) ~= 'table' then
		return { error = resultError or result or 'database_error' }
	end
	notifyDebtors(result, 'success', _t('business_loan_approved', {
		amount = money(result.principal),
		installments = result.installments,
		perMonth = money(result.total // result.installments),
		days = loanConfig.IntervalDays
	}))
	return true
end)
AddEventHandler('playerDropped', function()
	local playerId = source
	atmSessions[playerId] = nil
	agencyOpen[playerId] = nil
	agencyAccount[playerId] = nil
	lastAction[playerId] = nil
	busy[playerId] = nil
end)

CreateThread(function()
	local waitingLogged = false
	while true do
		local initialized, errorCode = BankingPersistence.Initialize()
		if initialized then
			break
		end
		if errorCode == 'database_not_ready' or errorCode == 'database_unavailable' then
			if not waitingLogged then
				log('info', 'persistence', 'database_waiting', {})
				waitingLogged = true
			end
			Wait(1000)
		else
			log('error', 'persistence', 'banking_initialize_failed', { error_code = tostring(errorCode) })
			return
		end
	end
	-- Níveis: a tabela manda; vazia, grava os padrões do config.lua.
	local stored = BankingPersistence.Tiers()
	if stored and next(stored) == nil then
		BankingPersistence.SaveTiers(creditConfig.Tiers, os.time())
	elseif stored then
		applyTiers(stored)
	end
	ready = true
	log('info', 'banking', 'ready', {})
	-- Fechamento, vencimento, juros e débito automático das contas de crédito, mesmo com o jogador offline.
	while true do
		Wait(creditConfig.TickSeconds * 1000)
		local now = os.time()
		for _, characterId in ipairs(BankingPersistence.CreditPending(now, now - creditConfig.AutoDebitDays * 86400, 100) or {}) do
			withCreditLock(characterId, function()
				return settleCredit(characterId)
			end)
		end
		for _, loanId in ipairs(BankingPersistence.LoansDue(now, 100) or {}) do
			settleDueLoan(loanId)
		end
	end
end)

-- Carteira digital (smartphone) e compras no crédito ----------------------------------------------

local function walletCaller()
	return config.WalletCallers[GetInvokingResource() or ''] == true
end

-- O que a carteira mostra do cartão (nunca o número inteiro nem a senha).
local function walletCard(card)
	if card.accountType == 'business' then
		local business = remote('coe_businesses', 'Get', card.accountRef)
		return {
			id = card.id, last4 = BankingRules.Last4(card.serial), holder = card.holderName, kind = card.kind,
			status = BankingRules.Status(card), expiresAt = card.expiresAt, tier = 'business',
			tierLabel = type(business) == 'table' and ('Empresarial · ' .. (business.label or business.id)):sub(1, 48) or 'Empresarial'
		}
	end
	local tier = creditTierOf(card.accountRef)
	return {
		id = card.id, last4 = BankingRules.Last4(card.serial), holder = card.holderName, kind = card.kind,
		status = BankingRules.Status(card), expiresAt = card.expiresAt, tier = tier and tier.id or nil, tierLabel = tier and tier.label or nil
	}
end

-- Cartões que o jogador pode pôr na carteira: os físicos ativos no inventário e o virtual ativo da própria conta.
exports('WalletEligible', function(playerId)
	if not walletCaller() then
		return { ok = false, error = 'forbidden' }
	end
	local source = tonumber(playerId)
	local who = ready and source and character(source)
	if not who then
		return { ok = false, error = ready and 'no_character' or 'not_ready' }
	end
	local inventoryId = inventoryOf(source)
	local snapshot = inventoryId and remote('coe_inventory', 'GetInventory', inventoryId) or nil
	local found, errorCode = BankingPersistence.Cards(BankingRules.CardsInInventory(snapshot))
	if not found then
		return { ok = false, error = errorCode }
	end
	local cards, hasVirtual = {}, false
	for _, card in pairs(found) do
		if card.kind == 'physical' and BankingRules.Status(card) == 'active' then
			cards[#cards + 1] = walletCard(card)
		end
	end
	for _, card in ipairs(BankingPersistence.AccountCards('personal', who.characterId) or {}) do
		if card.kind == 'virtual' and BankingRules.Status(card) == 'active' then
			cards[#cards + 1] = walletCard(card)
			hasVirtual = true
		end
	end
	table.sort(cards, function(a, b) return a.id > b.id end)
	return { ok = true, cards = cards, hasVirtual = hasVirtual, virtualFee = config.VirtualCardFee or 0 }
end)

-- Vincula um cartão: virtual da própria conta, ou físico em mãos com a senha (erros contam como no caixa eletrônico).
exports('WalletLink', function(playerId, cardId, pin)
	if not walletCaller() then
		return { ok = false, error = 'forbidden' }
	end
	local source, id = tonumber(playerId), BankingRules.CardId(cardId)
	local who = ready and source and character(source)
	if not who then
		return { ok = false, error = ready and 'no_character' or 'not_ready' }
	end
	if not id then
		return { ok = false, error = 'card_not_found' }
	end
	if busy[source] then
		return { ok = false, error = 'busy' }
	end
	busy[source] = true
	local ok, result = pcall(function()
		local card, cardError = BankingPersistence.Card(id)
		if not card then
			return { ok = false, error = cardError }
		end
		local allowed, denied = BankingRules.CanLink(card, who.characterId, card.kind == 'physical' and cardInHand(source, id), os.time())
		if not allowed then
			return { ok = false, error = denied }
		end
		if card.kind == 'physical' then
			if type(pin) ~= 'string' then
				return { ok = false, error = 'invalid_pin' }
			end
			local check = BankingRules.CheckPin(card, pin, config, hashKey)
			if not check.ok then
				BankingPersistence.SetAttempts(card.id, check.attempts, check.blocked and 'pin' or nil)
				if check.blocked then
					audit('bank_card_blocked', { character_id = card.accountRef, item = 'card_bank', request_id = tostring(card.id), action = 'pin' })
					return { ok = false, error = 'card_blocked' }
				end
				return { ok = false, error = 'wrong_pin', left = config.MaxPinAttempts - check.attempts }
			end
			if card.attempts > 0 then
				BankingPersistence.SetAttempts(card.id, 0, nil)
			end
		end
		audit('bank_wallet_linked', { character_id = who.characterId, item = card.kind, request_id = tostring(card.id) })
		return { ok = true, card = walletCard(card) }
	end)
	busy[source] = nil
	if not ok then
		log('error', 'banking', 'wallet_link_failed', { player_id = source, error_code = tostring(result):sub(1, 96) })
		return { ok = false, error = 'database_error' }
	end
	return result
end)

-- Situação atual dos cartões de uma carteira (até 10 ids): { ok, cards = { [id] = view } }; cartão inexistente fica de fora.
exports('WalletCards', function(cardIds)
	if not walletCaller() then
		return { ok = false, error = 'forbidden' }
	end
	if not ready then
		return { ok = false, error = 'not_ready' }
	end
	local ids = {}
	for index, value in ipairs(type(cardIds) == 'table' and cardIds or {}) do
		local id = BankingRules.CardId(value)
		if index > 10 or not id then
			return { ok = false, error = 'card_not_found' }
		end
		ids[#ids + 1] = id
	end
	local found, errorCode = BankingPersistence.Cards(ids)
	if not found then
		return { ok = false, error = errorCode }
	end
	local cards = {}
	for id, card in pairs(found) do
		cards[tostring(id)] = walletCard(card)
	end
	return { ok = true, cards = cards }
end)

-- Pede um cartão virtual pela carteira (mesma regra da agência): devolve o cartão emitido.
exports('WalletIssueVirtual', function(playerId)
	if not walletCaller() then
		return { ok = false, error = 'forbidden' }
	end
	local source = tonumber(playerId)
	local who = ready and source and character(source)
	if not who then
		return { ok = false, error = ready and 'no_character' or 'not_ready' }
	end
	if busy[source] or throttled(source) then
		return { ok = false, error = 'busy' }
	end
	busy[source] = true
	local ok, card, errorCode = pcall(issueVirtual, source, who)
	busy[source] = nil
	if not ok or not card then
		return { ok = false, error = ok and errorCode or 'database_error' }
	end
	return { ok = true, card = walletCard(card) }
end)

-- Compra sem a maquininha, no crédito do cartão escolhido na carteira digital. Só para os resources em
-- `Credit.PurchaseCallers`. O cartão precisa estar ativo e a conta de crédito em dia.
local function purchaseInput(cardId, amount, description)
	if not creditConfig.PurchaseCallers[GetInvokingResource() or ''] then
		return nil, 'forbidden'
	end
	if not ready then
		return nil, 'not_ready'
	end
	local id = BankingRules.CardId(cardId)
	local value = wholeNumber(amount, 1, creditConfig.MaxPurchase)
	if not id then
		return nil, 'no_card'
	end
	if not value then
		return nil, 'invalid_amount'
	end
	local card, cardError = BankingPersistence.Card(id)
	if not card then
		return nil, cardError == 'card_not_found' and 'no_card' or cardError
	end
	local label = type(description) == 'string' and description:gsub('[%c<>]', ''):sub(1, 64) or ''
	return { card = card, characterId = card.accountRef, amount = value, label = label }
end

local function creditResult(result, errorCode)
	if type(result) ~= 'table' then
		return { ok = false, error = errorCode or (type(result) == 'string' and result) or 'database_error' }
	end
	result.ok = true
	return result
end

-- Devolve { ok = true, points, available } ou { ok = false, error } (no_card, card_blocked, card_expired, no_credit,
-- credit_late, credit_limit, busy).
-- Cobra uma compra já validada (`purchaseInput`) no crédito do titular ou no caixa do negócio (cartão empresarial).
local function chargeCard(input)
	local status = BankingRules.Status(input.card)
	if status ~= 'active' then
		return { ok = false, error = status == 'expired' and 'card_expired' or 'card_blocked' }
	end
	-- Cartão empresarial: débito no caixa do negócio, dentro do limite diário do cartão.
	if input.card.accountType == 'business' then
		return BankingBusiness.CardPurchase(input)
	end
	local result, errorCode = withCreditLock(input.characterId, function()
		local state, loadError = settleCredit(input.characterId)
		if state == nil then
			return nil, loadError
		end
		if state == false then
			return nil, 'no_credit'
		end
		local allowed, denied = CreditRules.CanPurchase(state, input.amount)
		if not allowed then
			return nil, denied
		end
		CreditRules.Purchase(state, input.amount)
		local tier = CreditRules.Tier(creditConfig, state.tier)
		local points = tier and CreditRules.Points(input.amount, tier) or 0
		state.points = state.points + points
		local saved, saveError = BankingPersistence.SaveCredit(state, {
			{ kind = 'purchase', amount = input.amount, description = input.label, at = os.time() }
		})
		if not saved then
			return nil, saveError
		end
		return { points = points, available = CreditRules.Available(state) }
	end)
	if type(result) == 'table' then
		audit('credit_purchase', { character_id = input.characterId, operation = GetInvokingResource(), request_id = tostring(input.card.id), count = input.amount })
	end
	return creditResult(result, errorCode)
end

-- Devolve { ok = true, points, available } ou { ok = false, error } (no_card, card_blocked, card_expired, no_credit,
-- credit_late, credit_limit, busy).
exports('CardPurchase', function(cardId, amount, description)
	local input, inputError = purchaseInput(cardId, amount, description)
	if not input then
		return { ok = false, error = inputError }
	end
	return chargeCard(input)
end)

-- Maquininha (balcão de loja): cartões físicos ativos que o jogador tem no inventário, para escolher na hora de pagar.
-- Só para `Credit.PurchaseCallers`. Devolve { ok, cards = { { id, last4, holder, kind, business } } }.
local function posCards(playerId)
	if not creditConfig.PurchaseCallers[GetInvokingResource() or ''] then
		return { ok = false, error = 'forbidden' }
	end
	local source = tonumber(playerId)
	if not ready or not source then
		return { ok = false, error = 'not_ready' }
	end
	local inventoryId = inventoryOf(source)
	local snapshot = inventoryId and remote('coe_inventory', 'GetInventory', inventoryId) or nil
	local found, errorCode = BankingPersistence.Cards(BankingRules.CardsInInventory(snapshot))
	if not found then
		return { ok = false, error = errorCode }
	end
	local cards = {}
	for _, card in pairs(found) do
		if card.kind == 'physical' and BankingRules.Status(card) == 'active' then
			cards[#cards + 1] = {
				id = card.id, last4 = BankingRules.Last4(card.serial), holder = card.holderName,
				business = card.accountType == 'business'
			}
		end
	end
	table.sort(cards, function(a, b) return a.id > b.id end)
	return { ok = true, cards = cards }
end
exports('PosCards', posCards)

-- Compra na maquininha: cartão físico em mãos e a senha (erros contam tentativas como no caixa eletrônico), depois a
-- mesma cobrança do CardPurchase. Só para `Credit.PurchaseCallers`. Erros extras: card_not_in_hand, wrong_pin (com
-- `left`), invalid_pin.
local function posPurchase(playerId, cardId, pin, amount, description)
	local input, inputError = purchaseInput(cardId, amount, description)
	if not input then
		return { ok = false, error = inputError }
	end
	local source = tonumber(playerId)
	if not source or input.card.kind ~= 'physical' or not cardInHand(source, input.card.id) then
		return { ok = false, error = 'card_not_in_hand' }
	end
	if busy[source] then
		return { ok = false, error = 'busy' }
	end
	if type(pin) ~= 'string' or not pin:match('^%d%d%d%d$') then
		return { ok = false, error = 'invalid_pin' }
	end
	busy[source] = true
	local ok, result = pcall(function()
		local check = BankingRules.CheckPin(input.card, pin, config, hashKey)
		if not check.ok then
			BankingPersistence.SetAttempts(input.card.id, check.attempts, check.blocked and 'pin' or nil)
			if check.blocked then
				audit('bank_card_blocked', { character_id = input.card.accountRef, item = 'card_bank', request_id = tostring(input.card.id), action = 'pin' })
				return { ok = false, error = 'card_blocked' }
			end
			return { ok = false, error = 'wrong_pin', left = config.MaxPinAttempts - check.attempts }
		end
		if input.card.attempts > 0 then
			BankingPersistence.SetAttempts(input.card.id, 0, nil)
		end
		return chargeCard(input)
	end)
	busy[source] = nil
	if not ok then
		log('error', 'banking', 'pos_purchase_failed', { player_id = source, error_code = tostring(result):sub(1, 96) })
		return { ok = false, error = 'database_error' }
	end
	return result
end
exports('PosPurchase', posPurchase)

-- Desfaz uma compra feita por CardPurchase (ex.: a loja não conseguiu gravar), mesmo com o cartão já bloqueado.
local function cardRefund(cardId, amount, description)
	local input, inputError = purchaseInput(cardId, amount, description)
	if not input then
		return { ok = false, error = inputError }
	end
	if input.card.accountType == 'business' then
		return BankingBusiness.CardRefund(input)
	end
	local result, errorCode = withCreditLock(input.characterId, function()
		local state, loadError = settleCredit(input.characterId)
		if state == nil then
			return nil, loadError
		end
		if state == false then
			return nil, 'no_credit'
		end
		local applied = CreditRules.Refund(state, input.amount)
		local tier = CreditRules.Tier(creditConfig, state.tier)
		state.points = math.max(0, state.points - (tier and CreditRules.Points(input.amount, tier) or 0))
		local saved, saveError = BankingPersistence.SaveCredit(state, {
			{ kind = 'refund', amount = applied, description = input.label, at = os.time() }
		})
		if not saved then
			return nil, saveError
		end
		return { refunded = applied }
	end)
	if type(result) == 'table' then
		audit('credit_refund', { character_id = input.characterId, operation = GetInvokingResource(), request_id = tostring(input.card.id), count = result.refunded })
	end
	return creditResult(result, errorCode)
end
exports('CardRefund', cardRefund)

-- Maquininha nas lojas (registrada com coe_shops:RegisterPaymentMethod, meio `card`): opções são os cartões físicos
-- ativos em mãos; a cobrança pede a senha. O chamador continua sendo a loja (Credit.PurchaseCallers).
exports('ShopOptions', function(playerId)
	local result = posCards(playerId)
	local options = {}
	for _, card in ipairs(type(result) == 'table' and result.ok and result.cards or {}) do
		options[#options + 1] = { id = card.id, label = (card.business and 'Empresa ' or '') .. '•••• ' .. card.last4 }
	end
	return {
		options = options,
		detail = #options > 0 and 'Cartão do banco que está com você, com a senha' or 'Nenhum cartão do banco com você'
	}
end)

exports('ShopCharge', function(playerId, payment, amount, description)
	local cardId = type(payment) == 'table' and math.tointeger(tonumber(payment.option)) or nil
	if not cardId then
		return { ok = false, error = 'no_card' }
	end
	local result = posPurchase(playerId, cardId, payment.pin, amount, description)
	if type(result) == 'table' and result.ok then
		result.ref = cardId
	end
	return result
end)

exports('ShopRefund', function(_, ref, amount, description)
	return cardRefund(ref, amount, description)
end)

-- Integrações registradas no framework: aba Banco no app do negócio (substitui o Financeiro) e a maquininha nas
-- lojas. De novo sempre que o coe_businesses ou o coe_shops reiniciarem.
local function registerExtensions()
	local results = {
		tab = remote('coe_businesses', 'RegisterTab', {
			id = 'bank', label = 'Banco', order = 30, script = 'html/business.js', css = 'html/bank-ui.css',
			handler = 'BusinessTablet', replaces = 'finance'
		}),
		payment = remote('coe_shops', 'RegisterPaymentMethod', {
			id = 'card', label = 'Cartão na maquininha', kind = 'pin', order = 30,
			options = 'ShopOptions', charge = 'ShopCharge', refund = 'ShopRefund'
		})
	}
	for kind, result in pairs(results) do
		if type(result) == 'table' and result.error then
			log('warn', 'system', 'banking_extension_failed', { action = kind, error_code = tostring(result.error) })
		end
	end
end

AddEventHandler('onResourceStart', function(resource)
	if resource == 'coe_businesses' or resource == 'coe_shops' then
		registerExtensions()
	end
end)
CreateThread(registerExtensions)

-- Internet banking no COE OS (app `bank` do coe_tablet): consulta e operações sem dinheiro em espécie.
local function tabletView(who)
	local cards = {}
	for _, card in ipairs(BankingPersistence.AccountCards('personal', who.characterId) or {}) do
		cards[#cards + 1] = cardView(card)
	end
	local creditInfo = creditView(who.characterId)
	return {
		holder = who.name,
		balance = balanceOf(who.characterId),
		cards = cards,
		statement = statement(who.characterId, config.StatementSize),
		credit = creditInfo.account,
		loans = creditInfo.loans,
		maxAmount = config.MaxAgencyAmount,
		virtualCardFee = config.VirtualCardFee or 0
	}
end

local tabletDeps = {
	caller = function() return GetInvokingResource() end,
	ready = function() return ready end,
	busy = busy,
	throttled = throttled,
	character = character,
	actions = AGENCY_ACTIONS,
	view = tabletView,
	messages = MESSAGES,
	log = log
}

-- App Banco no aparelho: o tablet mostra para todos (everyone); o smartphone pergunta aqui.
exports('TabletVisible', function(playerId, appId)
	return BankingTablet.Hosts[GetInvokingResource() or ''] == true and appId == 'bank' and ready == true
end)

-- Chamado só pelo coe_tablet e pelo coe_phone. Toda ação devolve o extrato atualizado em `bank`.
exports('TabletCall', function(playerId, appId, action, payload)
	return BankingTablet.Call(tabletDeps, playerId, appId, action, payload)
end)
-- Helpers para server/business.lua (conta empresarial). Não é API pública.
BankingServer = {
	isReady = function()
		return ready
	end,
	messages = MESSAGES,
	busy = busy,
	agencyOpen = agencyOpen,
	agencyAccount = agencyAccount,
	t = _t,
	log = log, audit = audit, notify = notify, money = money, remote = remote, throttled = throttled, guarded = guarded,
	character = character, playerOf = playerOf, agencyById = agencyById, nearAgency = nearAgency,
	inventoryOf = inventoryOf, cashOf = cashOf, digit = digit, hashKey = hashKey, cardView = cardView,
	withCreditLock = withCreditLock, settleLoan = settleLoan, businessPayer = businessPayer, loanView = loanView,
	businessDebtors = businessDebtors, debtorsScore = debtorsScore, requestView = requestView,
	requestBusinessLoan = requestBusinessLoan, cancelBusinessLoan = cancelBusinessLoan
}
