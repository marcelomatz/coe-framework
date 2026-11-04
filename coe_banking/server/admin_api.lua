-- Banking Admin API Exports
local Banking = Banking
local config = Banking.config
local creditConfig = Banking.creditConfig
local loanConfig = Banking.loanConfig
local log = function(...) return Banking.log(...) end
local audit = function(...) return Banking.audit(...) end
local notify = function(...) return Banking.notify(...) end
local playerOf = function(...) return Banking.playerOf(...) end
local scoreOf = function(...) return Banking.scoreOf(...) end
local tierView = function(...) return Banking.tierView(...) end
local creditView = function(...) return Banking.creditView(...) end
local creditTierOf = function(...) return Banking.creditTierOf(...) end
local loanView = function(...) return Banking.loanView(...) end
local withCreditLock = function(...) return Banking.withCreditLock(...) end
local settleCredit = function(...) return Banking.settleCredit(...) end
local hashKey = function(...) return Banking.hashKey(...) end

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
