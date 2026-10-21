local config = EconomyConfig

local ready = false

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

local function money(value)
	if Core and Core.Locale and Core.Locale.FormatMoney then
		return Core.Locale.FormatMoney(value, (config and config.Locale) or Core.Locale.GetDefaultLang())
	end
	local text = tostring(math.floor(value))
	local formatted = text:reverse():gsub('(%d%d%d)', '%1.'):reverse():gsub('^%.', '')
	return config.Currency .. ' ' .. formatted
end

-- Só resources autorizados movimentam dinheiro; o nome vem do runtime.
local function caller()
	local resource = GetInvokingResource()
	if resource == nil then
		return 'coe_economy'
	end
	if config.AllowedResources[resource] then
		return resource
	end
	return nil
end

local function prepare(characterId, amount, reason, reference)
	local id, idError = EconomyRules.CharacterId(characterId)
	if not id then
		return nil, idError
	end
	local value, amountError = EconomyRules.Amount(amount, config)
	if not value then
		return nil, amountError
	end
	local cleanReason, reasonError = EconomyRules.Reason(reason)
	if not cleanReason then
		return nil, reasonError
	end
	local cleanReference, referenceError = EconomyRules.Reference(reference)
	if not cleanReference then
		return nil, referenceError
	end
	return { id = id, amount = value, reason = cleanReason, reference = cleanReference }
end

local function ensure(characterId, source)
	return EconomyPersistence.EnsureAccount(characterId, config.StartingBalance, source)
end

local function balanceOf(characterId, source)
	local ensured, ensureError = ensure(characterId, source)
	if not ensured then
		return nil, ensureError
	end
	return EconomyPersistence.Balance(characterId)
end

local function guard(source)
	if not source then
		return 'forbidden'
	end
	if not ready then
		return 'not_ready'
	end
	return nil
end

exports('IsReady', function()
	return ready and caller() ~= nil
end)

exports('Summary', function()
	local source = caller()
	local blocked = guard(source)
	if blocked or source ~= 'coe_admin' then
		return { error = blocked or 'forbidden' }
	end
	local summary, summaryError = EconomyPersistence.Summary()
	return summary or { error = summaryError }
end)

exports('GetBalance', function(characterId)
	local source = caller()
	local blocked = guard(source)
	if blocked then
		return nil, blocked
	end
	local id, idError = EconomyRules.CharacterId(characterId)
	if not id then
		return nil, idError
	end
	return balanceOf(id, source)
end)

exports('Credit', function(characterId, amount, reason, reference)
	local source = caller()
	local blocked = guard(source)
	if blocked then
		return nil, blocked
	end
	local op, errorCode = prepare(characterId, amount, reason, reference)
	if not op then
		return nil, errorCode
	end
	local balance, balanceError = balanceOf(op.id, source)
	if not balance then
		return nil, balanceError
	end
	if not EconomyRules.CanCredit(balance, op.amount, config) then
		return nil, 'balance_limit'
	end
	local done, creditError = EconomyPersistence.Credit(op.id, op.amount, op.reason, op.reference, source)
	if not done then
		return nil, creditError
	end
	audit('money_credited', { character_id = op.id, source = source, action = op.reason, count = op.amount })
	return true
end)

exports('Debit', function(characterId, amount, reason, reference)
	local source = caller()
	local blocked = guard(source)
	if blocked then
		return nil, blocked
	end
	local op, errorCode = prepare(characterId, amount, reason, reference)
	if not op then
		return nil, errorCode
	end
	local balance, balanceError = balanceOf(op.id, source)
	if not balance then
		return nil, balanceError
	end
	if balance < op.amount then
		return nil, 'insufficient_funds'
	end
	local done, debitError = EconomyPersistence.Debit(op.id, op.amount, op.reason, op.reference, source)
	if not done then
		-- Corrida com outro débito: o modo estrito desfez a transação.
		local current = EconomyPersistence.Balance(op.id)
		if current and current < op.amount then
			return nil, 'insufficient_funds'
		end
		return nil, debitError
	end
	audit('money_debited', { character_id = op.id, source = source, action = op.reason, count = op.amount })
	return true
end)

exports('Transfer', function(fromId, toId, amount, reason, reference)
	local source = caller()
	local blocked = guard(source)
	if blocked then
		return nil, blocked
	end
	local op, errorCode = prepare(fromId, amount, reason, reference)
	if not op then
		return nil, errorCode
	end
	local target, targetError = EconomyRules.CharacterId(toId)
	if not target then
		return nil, targetError
	end
	if target == op.id then
		return nil, 'same_account'
	end
	local fromBalance, fromError = balanceOf(op.id, source)
	if not fromBalance then
		return nil, fromError
	end
	local toBalance, toError = balanceOf(target, source)
	if not toBalance then
		return nil, toError
	end
	if fromBalance < op.amount then
		return nil, 'insufficient_funds'
	end
	if not EconomyRules.CanCredit(toBalance, op.amount, config) then
		return nil, 'balance_limit'
	end
	local done, transferError = EconomyPersistence.Transfer(op.id, target, op.amount, op.reason, op.reference, source)
	if not done then
		local current = EconomyPersistence.Balance(op.id)
		if current and current < op.amount then
			return nil, 'insufficient_funds'
		end
		return nil, transferError
	end
	audit('money_transferred', { character_id = op.id, target = target, source = source, action = op.reason, count = op.amount })
	return true
end)

-- Extrato pessoal (mais recentes primeiro): lista de { delta, reason, reference, created_at } ou { error = codigo }.
exports('Ledger', function(characterId, limit)
	local source = caller()
	local blocked = guard(source)
	if blocked then
		return { error = blocked }
	end
	local id, idError = EconomyRules.CharacterId(characterId)
	if not id then
		return { error = idError }
	end
	local rows, rowsError = EconomyPersistence.Ledger(id, math.min(math.max(tonumber(limit) or 20, 1), 100))
	return rows or { error = rowsError }
end)

-- Estatísticas do extrato: { firstAt (epoch ou nil), inflow } ou { error = codigo }.
-- `ignored`: motivos que não contam como entrada (ex.: estornos e depósitos de espécie).
exports('LedgerStats', function(characterId, days, ignored)
	local source = caller()
	local blocked = guard(source)
	if blocked then
		return { error = blocked }
	end
	local id, idError = EconomyRules.CharacterId(characterId)
	if not id then
		return { error = idError }
	end
	local reasons = {}
	for _, reason in ipairs(type(ignored) == 'table' and ignored or {}) do
		local clean = EconomyRules.Reason(reason)
		if not clean then
			return { error = 'invalid_reason' }
		end
		reasons[#reasons + 1] = clean
		if #reasons > 20 then
			return { error = 'invalid_reason' }
		end
	end
	local stats, statsError = EconomyPersistence.LedgerStats(id, math.min(math.max(math.floor(tonumber(days) or 7), 1), 365), reasons)
	return stats or { error = statsError }
end)

-- Sociedade: conta do negócio. Retornos de valor único ou { error = codigo } (multi-retorno se perde entre resources).
local function businessExport(name, ...)
	if GetResourceState('coe_businesses') ~= 'started' then
		return nil
	end
	local args = { ... }
	local ok, result = pcall(function()
		return exports.coe_businesses[name](exports.coe_businesses, table.unpack(args))
	end)
	return ok and result or nil
end

local function societyGate(businessId)
	local source = caller()
	local blocked = guard(source)
	if blocked then
		return nil, blocked
	end
	local id, idError = EconomyRules.BusinessId(businessId)
	if not id then
		return nil, idError
	end
	if type(businessExport('Get', id)) ~= 'table' then
		return nil, 'unknown_business'
	end
	return { source = source, id = id }
end

exports('SocietyBalance', function(businessId)
	local gate, gateError = societyGate(businessId)
	if not gate then
		return { error = gateError }
	end
	local balance, balanceError = EconomyPersistence.SocietyBalance(gate.id)
	return balance or { error = balanceError }
end)

exports('SocietyLedger', function(businessId, limit)
	local gate, gateError = societyGate(businessId)
	if not gate then
		return { error = gateError }
	end
	local rows, rowsError = EconomyPersistence.SocietyLedger(gate.id, math.min(math.max(tonumber(limit) or 20, 1), 100))
	return rows or { error = rowsError }
end)

-- Depósito: dono ou equipe do próprio negócio, do saldo pessoal para a sociedade.
exports('SocietyDeposit', function(businessId, characterId, amount)
	local gate, gateError = societyGate(businessId)
	if not gate then
		return { error = gateError }
	end
	local op, errorCode = prepare(characterId, amount, 'society_deposit', 'society:' .. gate.id)
	if not op then
		return { error = errorCode }
	end
	local access = businessExport('Access', gate.id, op.id)
	if type(access) ~= 'table' or not (access.owner or access.staff) then
		return { error = 'not_staff' }
	end
	local balance, balanceError = balanceOf(op.id, gate.source)
	if not balance then
		return { error = balanceError }
	end
	if balance < op.amount then
		return { error = 'insufficient_funds' }
	end
	local society = EconomyPersistence.SocietyBalance(gate.id)
	if not society or not EconomyRules.CanCredit(society, op.amount, config) then
		return { error = 'balance_limit' }
	end
	local ensured, ensureError = EconomyPersistence.EnsureSociety(gate.id)
	if not ensured then
		return { error = ensureError }
	end
	local done, depositError = EconomyPersistence.SocietyDeposit(gate.id, op.id, op.amount, 'society_deposit', '', gate.source)
	if not done then
		log('error', 'economy', 'society_deposit_failed', { character_id = op.id, source = gate.source, action = gate.id, count = op.amount, error_code = tostring(depositError) })
		return { error = depositError }
	end
	audit('society_deposit', { character_id = op.id, source = gate.source, action = gate.id, count = op.amount })
	return true
end)

-- Saque: exige a permissão de cargo business.funds (o dono tem tudo).
exports('SocietyWithdraw', function(businessId, characterId, amount)
	local gate, gateError = societyGate(businessId)
	if not gate then
		return { error = gateError }
	end
	local op, errorCode = prepare(characterId, amount, 'society_withdraw', 'society:' .. gate.id)
	if not op then
		return { error = errorCode }
	end
	if businessExport('Can', gate.id, op.id, 'business.funds') ~= true then
		return { error = 'forbidden' }
	end
	local balance, balanceError = balanceOf(op.id, gate.source)
	if not balance or not EconomyRules.CanCredit(balance, op.amount, config) then
		return { error = balanceError or 'balance_limit' }
	end
	local society = EconomyPersistence.SocietyBalance(gate.id)
	if not society or society < op.amount then
		return { error = 'insufficient_funds' }
	end
	local done, payError = EconomyPersistence.SocietyPay(gate.id, op.id, op.amount, 'society_withdraw', '', gate.source)
	if not done then
		local current = EconomyPersistence.SocietyBalance(gate.id)
		local finalError = (current and current < op.amount) and 'insufficient_funds' or payError
		if finalError ~= 'insufficient_funds' then
			log('error', 'economy', 'society_withdraw_failed', { character_id = op.id, source = gate.source, action = gate.id, count = op.amount, error_code = tostring(finalError) })
		end
		return { error = finalError }
	end
	audit('society_withdraw', { character_id = op.id, source = gate.source, action = gate.id, count = op.amount })
	return true
end)

-- Aporte administrativo, sem personagem.
exports('SocietyCredit', function(businessId, amount, reason)
	local gate, gateError = societyGate(businessId)
	if not gate then
		return { error = gateError }
	end
	if gate.source ~= 'coe_admin' then
		return { error = 'forbidden' }
	end
	local value, amountError = EconomyRules.Amount(amount, config)
	if not value then
		return { error = amountError }
	end
	local cleanReason, reasonError = EconomyRules.Reason(reason or 'admin_adjustment')
	if not cleanReason then
		return { error = reasonError }
	end
	local society = EconomyPersistence.SocietyBalance(gate.id)
	if not society or not EconomyRules.CanCredit(society, value, config) then
		return { error = 'balance_limit' }
	end
	local ensured, ensureError = EconomyPersistence.EnsureSociety(gate.id)
	if not ensured then
		log('error', 'economy', 'society_ensure_failed', { source = gate.source, action = gate.id, error_code = tostring(ensureError) })
		return { error = ensureError }
	end
	local done, creditError = EconomyPersistence.SocietyCredit(gate.id, value, cleanReason, '', gate.source)
	if not done then
		log('error', 'economy', 'society_credit_failed', { source = gate.source, action = gate.id, count = value, error_code = tostring(creditError) })
		return { error = creditError }
	end
	audit('society_credited', { source = gate.source, action = gate.id, count = value })
	return true
end)

-- Repasse de receita já debitada de um cidadão (ex.: multa). Só resources em SocietyCollectors.
exports('SocietyCollect', function(businessId, amount, reason)
	local gate, gateError = societyGate(businessId)
	if not gate then
		return { error = gateError }
	end
	if config.SocietyCollectors[gate.source] ~= true then
		return { error = 'forbidden' }
	end
	local value, amountError = EconomyRules.Amount(amount, config)
	if not value then
		return { error = amountError }
	end
	local cleanReason, reasonError = EconomyRules.Reason(reason)
	if not cleanReason then
		return { error = reasonError }
	end
	local society = EconomyPersistence.SocietyBalance(gate.id)
	if not society or not EconomyRules.CanCredit(society, value, config) then
		return { error = 'balance_limit' }
	end
	local ensured, ensureError = EconomyPersistence.EnsureSociety(gate.id)
	if not ensured then
		log('error', 'economy', 'society_ensure_failed', { source = gate.source, action = gate.id, error_code = tostring(ensureError) })
		return { error = ensureError }
	end
	local done, creditError = EconomyPersistence.SocietyCredit(gate.id, value, cleanReason, '', gate.source)
	if not done then
		log('error', 'economy', 'society_collect_failed', { source = gate.source, action = gate.id, count = value, error_code = tostring(creditError) })
		return { error = creditError }
	end
	audit('society_collected', { source = gate.source, action = gate.id, count = value })
	return true
end)

-- Despesa do negócio sem personagem (ex.: aluguel de imóvel comercial). Só resources em SocietyPayers.
exports('SocietyCharge', function(businessId, amount, reason, reference)
	local gate, gateError = societyGate(businessId)
	if not gate then
		return { error = gateError }
	end
	if config.SocietyPayers[gate.source] ~= true then
		return { error = 'forbidden' }
	end
	local value, amountError = EconomyRules.Amount(amount, config)
	if not value then
		return { error = amountError }
	end
	local cleanReason, reasonError = EconomyRules.Reason(reason)
	if not cleanReason then
		return { error = reasonError }
	end
	local cleanReference, referenceError = EconomyRules.Reference(reference)
	if not cleanReference then
		return { error = referenceError }
	end
	local society = EconomyPersistence.SocietyBalance(gate.id)
	if not society or society < value then
		return { error = 'insufficient_funds' }
	end
	local done, debitError = EconomyPersistence.SocietyDebit(gate.id, value, cleanReason, cleanReference, gate.source)
	if not done then
		local current = EconomyPersistence.SocietyBalance(gate.id)
		local finalError = (current and current < value) and 'insufficient_funds' or debitError
		if finalError ~= 'insufficient_funds' then
			log('error', 'economy', 'society_charge_failed', { source = gate.source, action = gate.id, count = value, error_code = tostring(finalError) })
		end
		return { error = finalError }
	end
	audit('society_charged', { source = gate.source, action = gate.id, count = value })
	return true
end)

-- Conta bancária empresarial (coe_banking) ------------------------------------------------------------------
-- Só resources de `SocietyBankers`. O banco confere quem pode cada operação (permissões de cargo) e grava quem fez;
-- aqui ficam a atomicidade, os limites de saldo e o extrato. Valor único ou { error = codigo }.

local function bankerGate(businessId, amount, reason, reference)
	local gate, gateError = societyGate(businessId)
	if not gate then
		return nil, gateError
	end
	if config.SocietyBankers[gate.source] ~= true then
		return nil, 'forbidden'
	end
	local value, amountError = EconomyRules.Amount(amount, config)
	if not value then
		return nil, amountError
	end
	local cleanReason, reasonError = EconomyRules.Reason(reason)
	if not cleanReason then
		return nil, reasonError
	end
	local cleanReference, referenceError = EconomyRules.Reference(reference)
	if not cleanReference then
		return nil, referenceError
	end
	gate.amount, gate.reason, gate.reference = value, cleanReason, cleanReference
	return gate
end

local function societyHas(businessId, amount)
	local society = EconomyPersistence.SocietyBalance(businessId)
	return society ~= nil and society >= amount, society
end

-- Da sociedade para a conta de um personagem (saque para a conta, pagamento, bônus).
exports('BankSocietyPay', function(businessId, characterId, amount, reason, reference)
	local gate, gateError = bankerGate(businessId, amount, reason, reference)
	if not gate then
		return { error = gateError }
	end
	local id, idError = EconomyRules.CharacterId(characterId)
	if not id then
		return { error = idError }
	end
	if not societyHas(gate.id, gate.amount) then
		return { error = 'insufficient_funds' }
	end
	local account, accountError = balanceOf(id, gate.source)
	if not account then
		return { error = accountError }
	end
	if not EconomyRules.CanCredit(account, gate.amount, config) then
		return { error = 'balance_limit' }
	end
	local done, payError = EconomyPersistence.SocietyPay(gate.id, id, gate.amount, gate.reason, gate.reference, gate.source)
	if not done then
		local enough = societyHas(gate.id, gate.amount)
		return { error = enough and (payError or 'database_error') or 'insufficient_funds' }
	end
	audit('society_bank_paid', { source = gate.source, action = gate.id, character_id = id, count = gate.amount })
	return true
end)

-- Da conta de um personagem para a sociedade (depósito pela conta, pagamento a uma empresa).
exports('BankSocietyDeposit', function(businessId, characterId, amount, reason, reference)
	local gate, gateError = bankerGate(businessId, amount, reason, reference)
	if not gate then
		return { error = gateError }
	end
	local id, idError = EconomyRules.CharacterId(characterId)
	if not id then
		return { error = idError }
	end
	local account, accountError = balanceOf(id, gate.source)
	if not account then
		return { error = accountError }
	end
	if account < gate.amount then
		return { error = 'insufficient_funds' }
	end
	local society = EconomyPersistence.SocietyBalance(gate.id)
	if not society or not EconomyRules.CanCredit(society, gate.amount, config) then
		return { error = 'balance_limit' }
	end
	local ensured, ensureError = EconomyPersistence.EnsureSociety(gate.id)
	if not ensured then
		return { error = ensureError }
	end
	local done, depositError = EconomyPersistence.SocietyDeposit(gate.id, id, gate.amount, gate.reason, gate.reference, gate.source)
	if not done then
		local current = EconomyPersistence.Balance(id)
		return { error = (current and current < gate.amount) and 'insufficient_funds' or (depositError or 'database_error') }
	end
	audit('society_bank_deposit', { source = gate.source, action = gate.id, character_id = id, count = gate.amount })
	return true
end)

-- Saída sem conta de personagem do outro lado (saque em espécie no caixa, compra com cartão empresarial).
exports('BankSocietyDebit', function(businessId, amount, reason, reference)
	local gate, gateError = bankerGate(businessId, amount, reason, reference)
	if not gate then
		return { error = gateError }
	end
	if not societyHas(gate.id, gate.amount) then
		return { error = 'insufficient_funds' }
	end
	local done, debitError = EconomyPersistence.SocietyDebit(gate.id, gate.amount, gate.reason, gate.reference, gate.source)
	if not done then
		local enough = societyHas(gate.id, gate.amount)
		return { error = enough and (debitError or 'database_error') or 'insufficient_funds' }
	end
	audit('society_bank_debit', { source = gate.source, action = gate.id, count = gate.amount })
	return true
end)

-- Entrada sem conta de personagem do outro lado (depósito em espécie, estorno de compra).
exports('BankSocietyCredit', function(businessId, amount, reason, reference)
	local gate, gateError = bankerGate(businessId, amount, reason, reference)
	if not gate then
		return { error = gateError }
	end
	local society = EconomyPersistence.SocietyBalance(gate.id)
	if not society or not EconomyRules.CanCredit(society, gate.amount, config) then
		return { error = 'balance_limit' }
	end
	local ensured, ensureError = EconomyPersistence.EnsureSociety(gate.id)
	if not ensured then
		return { error = ensureError }
	end
	local done, creditError = EconomyPersistence.SocietyCredit(gate.id, gate.amount, gate.reason, gate.reference, gate.source)
	if not done then
		return { error = creditError or 'database_error' }
	end
	audit('society_bank_credit', { source = gate.source, action = gate.id, count = gate.amount })
	return true
end)

-- Entre empresas.
exports('BankSocietyTransfer', function(fromId, toId, amount, reason, reference)
	local gate, gateError = bankerGate(fromId, amount, reason, reference)
	if not gate then
		return { error = gateError }
	end
	local target, targetError = EconomyRules.BusinessId(toId)
	if not target then
		return { error = targetError }
	end
	if target == gate.id then
		return { error = 'same_account' }
	end
	if type(businessExport('Get', target)) ~= 'table' then
		return { error = 'unknown_business' }
	end
	if not societyHas(gate.id, gate.amount) then
		return { error = 'insufficient_funds' }
	end
	local society = EconomyPersistence.SocietyBalance(target)
	if not society or not EconomyRules.CanCredit(society, gate.amount, config) then
		return { error = 'balance_limit' }
	end
	local ensured, ensureError = EconomyPersistence.EnsureSociety(target)
	if not ensured then
		return { error = ensureError }
	end
	local done, transferError = EconomyPersistence.SocietyTransfer(gate.id, target, gate.amount, gate.reason, gate.reference, gate.source)
	if not done then
		local enough = societyHas(gate.id, gate.amount)
		return { error = enough and (transferError or 'database_error') or 'insufficient_funds' }
	end
	audit('society_bank_transfer', { source = gate.source, action = gate.id, target = target, count = gate.amount })
	return true
end)

-- Extrato filtrado com totais do período: { rows = { id, characterId, delta, reason, reference, at }, totals }.
exports('BankSocietyLedger', function(businessId, filter)
	local gate, gateError = societyGate(businessId)
	if not gate then
		return { error = gateError }
	end
	if config.SocietyBankers[gate.source] ~= true and gate.source ~= 'coe_admin' then
		return { error = 'forbidden' }
	end
	local page, pageError = EconomyPersistence.SocietyLedgerPage(gate.id, EconomyRules.LedgerFilter(filter))
	return page or { error = pageError }
end)

-- Folha: paga o salário do cargo a quem está de ponto, da conta da sociedade. Sem saldo, não paga e não acumula dívida.
local payrolling = {}

local function runPayroll(businessId, sourceResource)
	if payrolling[businessId] then
		return { error = 'busy' }
	end
	payrolling[businessId] = true
	local ok, summary = pcall(function()
		local entries = {}
		for _, member in ipairs(businessExport('Payroll', businessId) or {}) do
			entries[#entries + 1] = {
				characterId = tostring(member.characterId),
				salary = member.salary,
				onDuty = businessExport('IsOnDuty', businessId, tostring(member.characterId)) == true
			}
		end
		local balance = EconomyPersistence.SocietyBalance(businessId)
		if not balance then
			return { error = 'database_error' }
		end
		local plan = EconomyRules.PayrollPlan(entries, balance)
		local paid, total = 0, 0
		local skipped = plan.skipped
		for _, payment in ipairs(plan.payments) do
			local account = balanceOf(payment.characterId, sourceResource)
			if not account or not EconomyRules.CanCredit(account, payment.salary, config) then
				skipped[#skipped + 1] = { characterId = payment.characterId, salary = payment.salary, reason = 'balance_limit' }
			elseif EconomyPersistence.SocietyPay(businessId, payment.characterId, payment.salary, 'payroll', 'payroll:' .. businessId, sourceResource) then
				paid = paid + 1
				total = total + payment.salary
			else
				skipped[#skipped + 1] = { characterId = payment.characterId, salary = payment.salary, reason = 'insufficient_funds' }
			end
		end
		return { paid = paid, total = total, skipped = skipped }
	end)
	payrolling[businessId] = nil
	if not ok then
		return { error = 'database_error' }
	end
	if not summary.error then
		TriggerEvent('coe_economy:payrollPaid', businessId, summary.paid, summary.total, #summary.skipped)
		if #summary.skipped > 0 then
			log('warn', 'payroll', 'payroll_skipped', { business = businessId, skipped = #summary.skipped })
		end
		audit('payroll_paid', { source = sourceResource, action = businessId, count = summary.total })
	end
	return summary
end

exports('RunPayroll', function(businessId)
	local gate, gateError = societyGate(businessId)
	if not gate then
		return { error = gateError }
	end
	if gate.source ~= 'coe_admin' and gate.source ~= 'coe_economy' and config.SocietyBankers[gate.source] ~= true then
		return { error = 'forbidden' }
	end
	return runPayroll(gate.id, gate.source)
end)

CreateThread(function()
	while not ready do
		Wait(1000)
	end
	local interval = (config.PayrollIntervalMinutes or 0) * 60000
	if interval <= 0 then
		return
	end
	while true do
		Wait(interval)
		for _, business in ipairs(businessExport('List') or {}) do
			if business.enabled ~= false then
				runPayroll(business.id, 'coe_economy')
			end
		end
	end
end)

local function reply(playerId, kind, message)
	if playerId == 0 then
		print(message)
	else
		notify(playerId, kind, message)
	end
end

RegisterCommand('saldo', function(playerId)
	if playerId == 0 then
		return
	end
	if not ready then
		return notify(playerId, 'error', _t('service_starting'))
	end
	local characterId = Core.Players.GetActiveCharacterId(playerId)
	if not characterId then
		return notify(playerId, 'error', _t('no_active_character'))
	end
	local balance = balanceOf(tostring(characterId), 'coe_economy')
	if not balance then
		return notify(playerId, 'error', _t('balance_query_failed'))
	end
	notify(playerId, 'info', _t('balance_display', { balance = money(balance) }))
end, false)

-- ACE: command.coe_economy_credit.
RegisterCommand('coe_economy_credit', function(playerId, args)
	if not ready then
		return reply(playerId, 'error', _t('service_starting'))
	end
	local op, errorCode = prepare(args[1], tonumber(args[2]), 'admin_adjustment', '')
	if not op then
		return reply(playerId, 'error', _t('credit_usage', { error = tostring(errorCode) }))
	end
	local balance = balanceOf(op.id, 'coe_economy')
	if not balance or not EconomyRules.CanCredit(balance, op.amount, config) then
		return reply(playerId, 'error', _t('credit_failed'))
	end
	local done, creditError = EconomyPersistence.Credit(op.id, op.amount, op.reason, op.reference, 'coe_economy')
	if not done then
		return reply(playerId, 'error', _t('credit_error', { error = tostring(creditError) }))
	end
	audit('money_credited', { character_id = op.id, source = 'coe_economy', action = op.reason, count = op.amount })
	reply(playerId, 'success', _t('credited_to_character', { amount = money(op.amount), id = op.id }))
end, true)

CreateThread(function()
	local waitingLogged = false
	while true do
		local initialized, errorCode = EconomyPersistence.Initialize()
		if initialized then
			break
		end
		if errorCode == 'database_not_ready' then
			if not waitingLogged then
				log('info', 'persistence', 'database_waiting', {})
				waitingLogged = true
			end
			Wait(1000)
		else
			log('error', 'persistence', 'database_initialization_failed', { error_code = errorCode or 'database_error', retry_ms = 5000 })
			Wait(5000)
		end
	end
	ready = true
	log('info', 'system', 'economy_ready', {})
end)
