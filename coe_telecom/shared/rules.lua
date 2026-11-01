TelecomRules = {}

local DAY = 86400
local KINDS = { voice = 'minute', video = 'minute', sms = 'unit' }

function TelecomRules.IsKind(kind)
	return type(kind) == 'string' and KINDS[kind] ~= nil
end

function TelecomRules.Plan(config, id)
	local plan = type(id) == 'string' and config.Plans[id] or nil
	return plan
end

function TelecomRules.IsPostpaid(config, id)
	local plan = TelecomRules.Plan(config, id)
	return plan ~= nil and plan.kind == 'postpaid'
end

-- Minutos cobrados: cada minuto iniciado conta, depois da tolerância.
function TelecomRules.Minutes(config, seconds)
	local value = math.floor(tonumber(seconds) or 0) - (config.GraceSeconds or 0)
	if value <= 0 then
		return 0
	end
	return math.ceil(value / 60)
end

-- Preço de uma unidade (minuto ou mensagem); nil quando o plano é ilimitado nesse tipo.
local function rate(plan, kind)
	return plan.rates and plan.rates[kind] or nil
end

-- Pode usar a linha? Retorna true, maxSeconds (nil = sem limite) ou nil, código.
function TelecomRules.Authorize(config, line, kind)
	if not TelecomRules.IsKind(kind) then
		return nil, 'invalid_kind'
	end
	local plan = TelecomRules.Plan(config, line.plan)
	if not plan then
		return nil, 'unknown_plan'
	end
	if line.status ~= 'active' then
		return nil, 'line_suspended'
	end
	if plan.kind ~= 'prepaid' then
		return true, nil
	end
	local price = rate(plan, kind) or 0
	if price <= 0 then
		return true, nil
	end
	local balance = math.max(0, math.floor(tonumber(line.balance) or 0))
	if balance < price then
		return nil, 'no_credit'
	end
	if KINDS[kind] == 'unit' then
		return true, nil
	end
	-- Minutos que o crédito paga, mais a tolerância (que não é cobrada).
	return true, math.floor(balance / price) * 60 + (config.GraceSeconds or 0)
end

-- O que um uso custa agora. Retorna { cost, units, field } onde:
-- cost  = valor a descontar do crédito (só pré-pago),
-- units = minutos (ou mensagens) usados,
-- field = 'voice_used'/'video_used' quando o uso soma na franquia do pós-pago.
function TelecomRules.Charge(config, line, kind, seconds)
	local plan = TelecomRules.Plan(config, line.plan)
	if not plan or not TelecomRules.IsKind(kind) then
		return { cost = 0, units = 0 }
	end
	local units = KINDS[kind] == 'unit' and 1 or TelecomRules.Minutes(config, seconds)
	if units == 0 then
		return { cost = 0, units = 0 }
	end
	if plan.kind == 'prepaid' then
		local price = rate(plan, kind) or 0
		local balance = math.max(0, math.floor(tonumber(line.balance) or 0))
		return { cost = math.min(balance, units * price), units = units }
	end
	if kind == 'sms' then
		return { cost = 0, units = units }
	end
	return { cost = 0, units = units, field = kind .. '_used' }
end

function TelecomRules.CycleSeconds(config)
	return config.CycleDays * DAY
end

function TelecomRules.CycleEnd(config, line)
	return (tonumber(line.cycleStart) or 0) + TelecomRules.CycleSeconds(config)
end

function TelecomRules.CycleDue(config, line, now)
	return TelecomRules.IsPostpaid(config, line.plan) and now >= TelecomRules.CycleEnd(config, line)
end

-- Fatura do ciclo do pós-pago. prorate: cobra a mensalidade proporcional ao tempo usado (troca de plano).
-- Retorna { amount, base, extra, voice, video } (voice/video = minutos excedentes).
function TelecomRules.Invoice(config, line, now, prorate)
	local plan = TelecomRules.Plan(config, line.plan)
	if not plan or plan.kind ~= 'postpaid' then
		return { amount = 0, base = 0, extra = 0, voice = 0, video = 0 }
	end
	local monthly = plan.monthly or 0
	local base = monthly
	if prorate then
		local elapsed = math.max(0, now - (tonumber(line.cycleStart) or now))
		local fraction = math.min(1, elapsed / TelecomRules.CycleSeconds(config))
		base = math.ceil(monthly * fraction)
	end
	local allowance = plan.allowance or {}
	local voice, video, extra = 0, 0, 0
	if plan.rates then
		voice = math.max(0, (tonumber(line.voiceUsed) or 0) - (allowance.voice or 0))
		video = math.max(0, (tonumber(line.videoUsed) or 0) - (allowance.video or 0))
		extra = voice * (plan.rates.voice or 0) + video * (plan.rates.video or 0)
	end
	return { amount = base + extra, base = base, extra = extra, voice = voice, video = video }
end

function TelecomRules.DueAt(config, now)
	return now + config.GraceDays * DAY
end

function TelecomRules.Recharge(config, line, amount)
	local plan = TelecomRules.Plan(config, line.plan)
	if not plan or plan.kind ~= 'prepaid' then
		return nil, 'not_prepaid'
	end
	local valid = false
	for _, value in ipairs(config.Recharges) do
		if value == amount then
			valid = true
			break
		end
	end
	if not valid then
		return nil, 'invalid_amount'
	end
	if (tonumber(line.balance) or 0) + amount > config.MaxBalance then
		return nil, 'balance_full'
	end
	return amount
end

-- Troca de plano. openInvoices: quantas faturas em aberto a linha tem.
function TelecomRules.ChangePlan(config, line, target, openInvoices, now)
	local plan = TelecomRules.Plan(config, target)
	if not plan then
		return nil, 'unknown_plan'
	end
	if target == line.plan then
		return nil, 'same_plan'
	end
	local changedAt = tonumber(line.planChangedAt) or 0
	if changedAt > 0 and now - changedAt < config.PlanChangeHours * 3600 then
		return nil, 'plan_cooldown'
	end
	-- Pós-pago é fatura no nome de alguém: linha sem titular (chip anônimo) fica no pré.
	if plan.kind == 'postpaid' and line.holder == nil then
		return nil, 'holder_required'
	end
	if plan.kind == 'postpaid' and (line.status ~= 'active' or (openInvoices or 0) > 0) then
		return nil, 'open_invoice'
	end
	return plan
end

-- Planos para a tela do app, na ordem do config.
function TelecomRules.PlanList(config)
	local list = {}
	for id, plan in pairs(config.Plans) do
		list[#list + 1] = {
			id = id, label = plan.label, kind = plan.kind, order = plan.order or 99, description = plan.description,
			monthly = plan.monthly or 0, allowance = plan.allowance, rates = plan.rates
		}
	end
	table.sort(list, function(a, b)
		if a.order ~= b.order then
			return a.order < b.order
		end
		return a.id < b.id
	end)
	return list
end
