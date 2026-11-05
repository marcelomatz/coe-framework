local config = BankingConfig
local ready = false

local lastAction = {}
local busy = {}
-- Sessão do caixa eletrônico: [source] = { cardId, expires }.
local atmSessions = {}
-- Agência aberta: [source] = agencyId. Conta escolhida na agência: [source] = id do negócio (nil = pessoal).
local agencyOpen = {}
local agencyAccount = {}

local _t = (Core and Core.Locale and Core.Locale.Bind) and Core.Locale.Bind(Locales) or function(k) return (Locales and Locales['pt-BR'] and Locales['pt-BR'][k]) or k end

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

Banking = {
	config = config,
	creditConfig = creditConfig,
	loanConfig = loanConfig,
	log = log,
	audit = audit,
	notify = notify,
	fail = fail,
	throttled = throttled,
	hashKey = hashKey,
	character = character,
	playerOf = playerOf,
	inventoryOf = inventoryOf,
	cashOf = cashOf,
	balanceOf = balanceOf,
	credit = credit,
	debit = debit,
	withdrawCash = withdrawCash,
	depositCash = depositCash,
	statement = statement,
	cardView = cardView,
	withCreditLock = withCreditLock,
	scoreOf = scoreOf,
	settleCredit = settleCredit,
	tierView = tierView,
	creditView = creditView,
	creditTierOf = creditTierOf,
	atmFeeFor = atmFeeFor,
	ownCard = ownCard,
	issueCard = issueCard,
	issueVirtual = issueVirtual,
	loanView = loanView,
	loanLabel = loanLabel,
	settleLoan = settleLoan,
	settleDueLoan = settleDueLoan,
	remote = remote,
	atmSessions = atmSessions,
	money = money,
	guarded = guarded,
	t = _t,
	businessDebtors = businessDebtors,
	debtorsScore = debtorsScore,
	requestView = requestView,
	notifyDebtors = notifyDebtors,
	applyTiers = function(stored) return applyTiers(stored) end,
	isReady = function() return ready end
}

local function _loadSub(relPath)
	local f = io.open(relPath, "r")
	if f then f:close() return dofile(relPath) end
	local f2 = io.open("coe_banking/" .. relPath, "r")
	if f2 then f2:close() return dofile("coe_banking/" .. relPath) end
end

if not IsDuplicityVersion or not IsDuplicityVersion() then
	_loadSub("server/atm.lua")
	_loadSub("server/admin_api.lua")
	_loadSub("server/payment_api.lua")
end

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

local function applyTiers(stored)
	for _, tier in ipairs(creditConfig.Tiers) do
		local saved = stored[tier.id]
		if saved then
			tier.label, tier.minScore, tier.limit = saved.label, saved.minScore, saved.limit
			tier.pointsPer100, tier.fee, tier.freeAtm = saved.pointsPer100, saved.fee, saved.freeAtm
		end
	end
end

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
