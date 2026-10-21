EconomyRules = {}

-- Valor sempre inteiro e positivo; retorna o inteiro ou nil, código.
function EconomyRules.Amount(value, config)
	if type(value) ~= 'number' or value ~= value or value % 1 ~= 0 then
		return nil, 'invalid_amount'
	end
	if value < 1 or value > config.MaxAmount then
		return nil, 'invalid_amount'
	end
	return math.tointeger(value)
end

-- Motivo e referência entram no extrato: formato curto e sem texto livre.
function EconomyRules.Reason(value)
	if type(value) ~= 'string' or not value:match('^[a-z0-9_]+$') or #value > 32 then
		return nil, 'invalid_reason'
	end
	return value
end

function EconomyRules.Reference(value)
	if value == nil then
		return ''
	end
	if type(value) ~= 'string' or #value > 64 or not value:match('^[%w_:%-]*$') then
		return nil, 'invalid_reference'
	end
	return value
end

function EconomyRules.CharacterId(value)
	local text = tostring(value or '')
	if not text:match('^%d+$') or #text > 18 or text == '0' then
		return nil, 'invalid_character'
	end
	return text
end

-- Mesmo formato do id de negócio em coe_businesses.
function EconomyRules.BusinessId(value)
	if type(value) ~= 'string' or #value > 32 or not value:match('^[a-z][a-z0-9_]*$') then
		return nil, 'invalid_business'
	end
	return value
end

-- Folha: paga na ordem recebida só quem está de ponto e enquanto houver saldo na sociedade.
-- Quem não puder ser pago fica em `skipped` (sem dívida acumulada). Retorna { payments, skipped, total }.
function EconomyRules.PayrollPlan(entries, balance)
	local plan = { payments = {}, skipped = {}, total = 0 }
	local remaining = balance
	for _, entry in ipairs(entries) do
		local salary = entry.salary
		if type(salary) == 'number' and salary >= 1 and salary % 1 == 0 then
			if not entry.onDuty then
				plan.skipped[#plan.skipped + 1] = { characterId = entry.characterId, salary = salary, reason = 'off_duty' }
			elseif remaining < salary then
				plan.skipped[#plan.skipped + 1] = { characterId = entry.characterId, salary = salary, reason = 'insufficient_funds' }
			else
				remaining = remaining - salary
				plan.total = plan.total + salary
				plan.payments[#plan.payments + 1] = { characterId = entry.characterId, salary = salary }
			end
		end
	end
	return plan
end

-- Soma sem estourar o teto da conta.
function EconomyRules.CanCredit(balance, amount, config)
	return balance + amount <= config.MaxBalance
end

-- Filtro do extrato da conta empresarial: { direction = 'in'|'out'|nil, reasons = {..}|nil, days, limit, beforeId }.
-- Valores fora do formato caem no padrão (sem filtro, 30 dias, 25 linhas).
function EconomyRules.LedgerFilter(raw)
	raw = type(raw) == 'table' and raw or {}
	local filter = { limit = 25, days = 30 }
	if raw.direction == 'in' or raw.direction == 'out' then
		filter.direction = raw.direction
	end
	local days = tonumber(raw.days)
	if days and days % 1 == 0 and days >= 1 and days <= 365 then
		filter.days = math.tointeger(days)
	end
	local limit = tonumber(raw.limit)
	if limit and limit % 1 == 0 and limit >= 1 and limit <= 100 then
		filter.limit = math.tointeger(limit)
	end
	local beforeId = tonumber(raw.beforeId)
	if beforeId and beforeId % 1 == 0 and beforeId > 0 then
		filter.beforeId = math.tointeger(beforeId)
	end
	if type(raw.reasons) == 'table' then
		local reasons = {}
		for index, reason in ipairs(raw.reasons) do
			if index > 20 or not EconomyRules.Reason(reason) then
				reasons = nil
				break
			end
			reasons[#reasons + 1] = reason
		end
		if reasons and #reasons > 0 then
			filter.reasons = reasons
		end
	end
	return filter
end
