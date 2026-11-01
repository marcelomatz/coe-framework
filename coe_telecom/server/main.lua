local config = CoeTelecomConfig

local ready = false
local busy = {}

local function log(level, category, event, context)
	pcall(function()
		return exports.coe_logging:Log(level, category, event, context)
	end)
end

local function notify(playerId, kind, message)
	pcall(function()
		exports.coe_notify:Notify(playerId, kind, message)
	end)
end

local _t = function(key, params)
	if Core and Core.Locale and Core.Locale.New then
		return Core.Locale.New({ default = Core.Locale.GetDefaultLang(), locales = Locales or {} })(key, params)
	end
	if Locales and Locales['pt-BR'] and Locales['pt-BR'][key] then
		return Locales['pt-BR'][key]
	end
	return key
end

local function money(amount)
	if Core and Core.Locale and Core.Locale.FormatMoney then
		return Core.Locale.FormatMoney(amount)
	end
	return string.format('$%d', amount)
end

local function characterIdOf(playerId)
	local id = Core.Players.GetActiveCharacterId(playerId)
	return id and tostring(id) or nil
end

local function playerOfCharacter(characterId)
	for _, value in ipairs(GetPlayers()) do
		local playerId = tonumber(value)
		if characterIdOf(playerId) == characterId then
			return playerId
		end
	end
	return nil
end

local function validCharacter(value)
	local text = tostring(value or '')
	if not text:match('^%d+$') or #text > 18 or text == '0' then
		return nil
	end
	return text
end

local function debit(characterId, amount, reference)
	local ok, done, errorCode = pcall(function()
		return exports.coe_economy:Debit(characterId, amount, 'telecom', reference)
	end)
	if not ok then
		return nil, 'economy_unavailable'
	end
	if not done then
		return nil, errorCode == 'insufficient_funds' and 'insufficient_funds' or 'economy_unavailable'
	end
	return true
end

local function refund(characterId, amount, reference)
	pcall(function()
		return exports.coe_economy:Credit(characterId, amount, 'telecom_refund', reference)
	end)
end

local function validNumber(value)
	return type(value) == 'string' and value:match('^%d+$') and #value <= 16 and value or nil
end

-- Linha do número; nasce no primeiro uso, no plano padrão e com o crédito de boas-vindas.
-- A linha antiga do titular (de antes dos chips) é associada ao primeiro número que ele usar.
local function lineOf(number, holder)
	local line, errorCode = TelecomPersistence.Line(number)
	if line == nil then
		return nil, errorCode or 'database_error'
	end
	if line then
		return line
	end
	if holder then
		local adopted = TelecomPersistence.Adopt(number, holder)
		if adopted then
			log('info', 'system', 'telecom_line_adopted', { character_id = holder })
		end
	end
	line = TelecomPersistence.Line(number)
	if line then
		return line
	end
	local created = TelecomPersistence.CreateLine(number, holder, config.DefaultCarrier, config.DefaultPlan, config.StartingCredit, os.time())
	if created == nil then
		return nil, 'database_error'
	end
	if created then
		log('info', 'system', 'telecom_line_created', { character_id = holder })
	end
	line = TelecomPersistence.Line(number)
	if not line then
		return nil, 'database_error'
	end
	return line
end

local function postpaidPlans()
	local list = {}
	for id, plan in pairs(config.Plans) do
		if plan.kind == 'postpaid' then
			list[#list + 1] = id
		end
	end
	table.sort(list)
	return list
end

-- Paga a fatura pela conta do banco de `payer`. Retorna true ou nil, código.
local function payInvoice(payer, number, id, amount)
	if not TelecomPersistence.MarkPaid(id, os.time()) then
		return nil, 'already_paid'
	end
	if amount > 0 then
		local paid, errorCode = debit(payer, amount, 'invoice_' .. id)
		if not paid then
			TelecomPersistence.Reopen(id)
			return nil, errorCode
		end
	end
	TelecomPersistence.AddUsage(number, payer, 'invoice', nil, 0, amount, os.time())
	return true
end

-- Reativa a linha suspensa quando não restam faturas em aberto.
local function reactivate(number)
	local open = TelecomPersistence.OpenInvoices(number)
	if open == 0 then
		TelecomPersistence.SetStatus(number, 'active')
		return true
	end
	return false
end

-- Fecha o ciclo do pós-pago: gera a fatura e tenta o débito automático na conta do titular.
local function closeCycle(line, now, prorate)
	local invoice = TelecomRules.Invoice(config, line, now, prorate)
	if not TelecomPersistence.ResetCycle(line, now) then
		return nil
	end
	local details = ('base:%d;extra:%d;voice:%d;video:%d'):format(invoice.base, invoice.extra, invoice.voice, invoice.video)
	local id = TelecomPersistence.AddInvoice(line, now, invoice.amount, details, TelecomRules.DueAt(config, now))
	if not id then
		log('error', 'persistence', 'telecom_invoice_failed', { character_id = line.holder })
		return nil
	end
	local paid = line.holder and payInvoice(line.holder, line.number, id, invoice.amount)
	local playerId = line.holder and playerOfCharacter(line.holder)
	if playerId then
		if paid then
			notify(playerId, 'info', _t('invoice_paid_autopay', { amount = money(invoice.amount) }))
		else
			notify(playerId, 'warning', _t('invoice_open_warning', { amount = money(invoice.amount), days = config.GraceDays }))
		end
	end
	log('info', 'system', 'telecom_invoice', { character_id = line.holder, count = invoice.amount, result = paid and 'paid' or 'open' })
	return id
end

-- App Minha linha -------------------------------------------------------------------------------------
-- ctx: { characterId = quem está usando, number = linha do chip no aparelho, display, holder = titular do chip }.

-- Linha do chip no aparelho que o jogador está usando (coe_phone).
local function activeLine(playerId)
	if GetResourceState('coe_phone') ~= 'started' then
		return nil, 'no_phone'
	end
	local ok, result, errorCode = pcall(function()
		return exports.coe_phone:ActiveLine(playerId)
	end)
	if not ok then
		return nil, 'no_phone'
	end
	if type(result) ~= 'table' or not validNumber(result.number) then
		return nil, type(errorCode) == 'string' and errorCode or 'no_sim'
	end
	return result
end

local function overview(ctx)
	local line, errorCode = lineOf(ctx.number, ctx.holder)
	if not line then
		return { ok = false, error = errorCode }
	end
	local plan = TelecomRules.Plan(config, line.plan) or {}
	local carrier = config.Carriers[line.carrier] or {}
	return {
		ok = true,
		line = {
			number = ctx.display,
			carrier = carrier.label or line.carrier,
			plan = line.plan,
			planLabel = plan.label or line.plan,
			kind = plan.kind,
			monthly = plan.monthly or 0,
			rates = plan.rates,
			allowance = plan.allowance,
			balance = line.balance,
			status = line.status,
			cycleStart = line.cycleStart,
			cycleEnd = TelecomRules.CycleEnd(config, line),
			voiceUsed = line.voiceUsed,
			videoUsed = line.videoUsed,
			planChangeAt = line.planChangedAt > 0 and line.planChangedAt + config.PlanChangeHours * 3600 or 0,
			holder = line.holder ~= nil and line.holder == ctx.characterId
		},
		plans = TelecomRules.PlanList(config),
		recharges = config.Recharges,
		maxBalance = config.MaxBalance,
		invoices = TelecomPersistence.Invoices(ctx.number, config.InvoicesLimit) or {},
		usage = TelecomPersistence.Usage(ctx.number, config.UsageLimit) or {}
	}
end

local Actions = {}

function Actions.overview(ctx)
	return overview(ctx)
end

-- Qualquer um com o aparelho pode recarregar ou pagar a fatura; quem paga é quem está usando.
function Actions.recharge(ctx, payload)
	local line, errorCode = lineOf(ctx.number, ctx.holder)
	if not line then
		return { ok = false, error = errorCode }
	end
	local amount = math.tointeger(tonumber(payload.amount))
	local value, invalid = TelecomRules.Recharge(config, line, amount)
	if not value then
		return { ok = false, error = invalid }
	end
	local paid, payError = debit(ctx.characterId, value, 'recharge')
	if not paid then
		return { ok = false, error = payError }
	end
	if not TelecomPersistence.AddBalance(ctx.number, value, config.MaxBalance) then
		refund(ctx.characterId, value, 'recharge')
		return { ok = false, error = 'balance_full' }
	end
	TelecomPersistence.AddUsage(ctx.number, ctx.characterId, 'recharge', nil, 0, value, os.time())
	log('info', 'system', 'telecom_recharge', { character_id = ctx.characterId, count = value })
	return overview(ctx)
end

function Actions.pay(ctx, payload)
	local id = math.tointeger(tonumber(payload.id))
	if not id then
		return { ok = false, error = 'invalid_request' }
	end
	local invoice = TelecomPersistence.Invoice(ctx.number, id)
	if invoice == nil then
		return { ok = false, error = 'database_error' }
	end
	if not invoice or invoice.status ~= 'open' then
		return { ok = false, error = 'already_paid' }
	end
	local paid, errorCode = payInvoice(ctx.characterId, ctx.number, id, invoice.amount)
	if not paid then
		return { ok = false, error = errorCode }
	end
	local line = TelecomPersistence.Line(ctx.number)
	if line and line.status == 'suspended' and reactivate(ctx.number) then
		log('info', 'system', 'telecom_line_reactivated', { character_id = line.holder })
	end
	log('info', 'system', 'telecom_invoice_paid', { character_id = ctx.characterId, count = invoice.amount })
	return overview(ctx)
end

-- Plano: só o titular troca. Linha anônima troca entre planos pré-pagos (as regras barram o pós).
function Actions.plan(ctx, payload)
	local line, errorCode = lineOf(ctx.number, ctx.holder)
	if not line then
		return { ok = false, error = errorCode }
	end
	if line.holder and line.holder ~= ctx.characterId then
		return { ok = false, error = 'not_holder' }
	end
	local open = TelecomPersistence.OpenInvoices(ctx.number)
	if not open then
		return { ok = false, error = 'database_error' }
	end
	local now = os.time()
	local target = type(payload.plan) == 'string' and payload.plan or ''
	local plan, invalid = TelecomRules.ChangePlan(config, line, target, open, now)
	if not plan then
		return { ok = false, error = invalid }
	end
	-- Sair do pós-pago fecha o ciclo com a mensalidade proporcional.
	if TelecomRules.IsPostpaid(config, line.plan) then
		closeCycle(line, now, true)
	end
	if not TelecomPersistence.SetPlan(ctx.number, target, now) then
		return { ok = false, error = 'database_error' }
	end
	log('info', 'system', 'telecom_plan_changed', { character_id = ctx.characterId, operation = target })
	return overview(ctx)
end

-- Exports ---------------------------------------------------------------------------------------------

local function trusted()
	local resource = GetInvokingResource()
	return resource ~= nil and config.AllowedCallers[resource] == true
end

-- O telefone pergunta antes de ligar ou mandar mensagem pela linha `number` (chip do aparelho).
-- holder: titular do chip (nil = anônimo). Retorna { ok, maxSeconds } ou { ok = false, error }.
exports('Authorize', function(number, kind, holder)
	if not trusted() then
		return { ok = false, error = 'forbidden' }
	end
	if not ready then
		return { ok = false, error = 'not_ready' }
	end
	local id = validNumber(number)
	if not id or (holder ~= nil and not validCharacter(holder)) then
		return { ok = false, error = 'invalid_request' }
	end
	local line, errorCode = lineOf(id, holder ~= nil and validCharacter(holder) or nil)
	if not line then
		return { ok = false, error = errorCode }
	end
	local allowed, result = TelecomRules.Authorize(config, line, kind)
	if not allowed then
		return { ok = false, error = result }
	end
	return { ok = true, maxSeconds = result }
end)

-- Uso concluído (ligação encerrada ou mensagem enviada). seconds só vale para voz e vídeo.
exports('Charge', function(number, kind, seconds, peer, holder)
	if not trusted() then
		return { ok = false, error = 'forbidden' }
	end
	if not ready then
		return { ok = false, error = 'not_ready' }
	end
	local id = validNumber(number)
	if not id or not TelecomRules.IsKind(kind) or (holder ~= nil and not validCharacter(holder)) then
		return { ok = false, error = 'invalid_request' }
	end
	local holderId = holder ~= nil and validCharacter(holder) or nil
	local line, errorCode = lineOf(id, holderId)
	if not line then
		return { ok = false, error = errorCode }
	end
	local charge = TelecomRules.Charge(config, line, kind, seconds)
	if charge.units == 0 then
		return { ok = true, cost = 0 }
	end
	if charge.cost > 0 then
		TelecomPersistence.Spend(id, charge.cost)
	end
	if charge.field then
		TelecomPersistence.AddUsed(id, charge.field, charge.units)
	end
	if kind ~= 'sms' or charge.cost > 0 then
		TelecomPersistence.AddUsage(id, holderId, kind, validNumber(peer), charge.units, charge.cost, os.time())
	end
	return { ok = true, cost = charge.cost }
end)

-- Resumo da linha de um número para outros resources.
exports('LineOf', function(number)
	if not ready then
		return nil
	end
	local id = validNumber(number)
	local line = id and TelecomPersistence.Line(id)
	if not line then
		return nil
	end
	return { plan = line.plan, carrier = line.carrier, status = line.status, balance = line.balance, holder = line.holder }
end)

-- App no aparelho (coe_phone e coe_tablet encaminham as ações).
local HOSTS = { coe_phone = true, coe_tablet = true }

exports('TabletVisible', function(playerId, appId)
	return HOSTS[GetInvokingResource()] == true and ready and appId == 'line' and characterIdOf(playerId) ~= nil
end)

exports('TabletCall', function(playerId, appId, action, payload)
	if not HOSTS[GetInvokingResource()] then
		return { ok = false, error = 'forbidden' }
	end
	if not ready then
		return { ok = false, error = 'not_ready' }
	end
	if appId ~= 'line' then
		return { ok = false, error = 'unknown_app' }
	end
	local characterId = characterIdOf(playerId)
	if not characterId then
		return { ok = false, error = 'no_character' }
	end
	local handler = type(action) == 'string' and rawget(Actions, action)
	if type(handler) ~= 'function' then
		return { ok = false, error = 'unknown_action' }
	end
	local active, lineError = activeLine(playerId)
	if not active then
		return { ok = false, error = lineError }
	end
	local ctx = {
		characterId = characterId,
		number = active.number,
		display = type(active.display) == 'string' and active.display or active.number,
		holder = active.holder ~= nil and validCharacter(active.holder) or nil
	}
	-- Uma ação de dinheiro por vez em cada linha.
	if busy[ctx.number] then
		return { ok = false, error = 'rate_limited' }
	end
	busy[ctx.number] = true
	local called, result = pcall(handler, ctx, type(payload) == 'table' and payload or {})
	busy[ctx.number] = nil
	if not called or type(result) ~= 'table' then
		log('error', 'system', 'telecom_action_failed', { action = action, error_code = tostring(result):sub(1, 120) })
		return { ok = false, error = 'app_error' }
	end
	return result
end)

-- Faturamento -----------------------------------------------------------------------------------------

local function billingTick()
	local now = os.time()
	local due = TelecomPersistence.DueLines(postpaidPlans(), TelecomRules.CycleSeconds(config), now, 100) or {}
	for _, line in ipairs(due) do
		if not busy[line.number] then
			busy[line.number] = true
			pcall(closeCycle, line, now, false)
			busy[line.number] = nil
		end
	end
	local suspended = TelecomPersistence.SuspendOverdue(now) or {}
	for _, line in ipairs(suspended) do
		log('info', 'system', 'telecom_line_suspended', { character_id = line.holder })
		local playerId = line.holder and playerOfCharacter(line.holder)
		if playerId then
			notify(playerId, 'error', _t('line_suspended'))
		end
	end
	TelecomPersistence.PurgeUsage(now - config.UsageKeepDays * 86400)
end

CreateThread(function()
	local waitingLogged = false
	while true do
		local initialized, errorCode = TelecomPersistence.Initialize()
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
			log('error', 'persistence', 'migrations_failed', { error_code = tostring(errorCode) })
			return
		end
	end
	ready = true
	log('info', 'system', 'telecom_ready', {})
	while true do
		local ok, failure = pcall(billingTick)
		if not ok then
			log('error', 'system', 'telecom_billing_failed', { error_code = tostring(failure):sub(1, 120) })
		end
		Wait(config.TickSeconds * 1000)
	end
end)