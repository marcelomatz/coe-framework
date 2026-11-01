-- Regras puras da conta empresarial (sem natives), usadas pelo servidor e pelos testes.
BusinessRules = {}

local DAY = 86400

-- Permissões de cargo da conta empresarial (registradas no coe_businesses com o prefixo do resource).
BusinessRules.Permissions = {
	{ name = 'banking.view', label = 'Banco: ver a conta, o extrato e os relatórios' },
	{ name = 'banking.withdraw', label = 'Banco: sacar do caixa' },
	{ name = 'banking.transfer', label = 'Banco: transferir e pagar pela empresa' },
	{ name = 'banking.cards', label = 'Banco: emitir e gerenciar cartões empresariais' },
	{ name = 'banking.loans', label = 'Banco: pagar e pedir empréstimos da empresa' },
	{ name = 'banking.payroll', label = 'Banco: folha de pagamento e bônus' }
}

local KEYS = { view = 'banking.view', withdraw = 'banking.withdraw', transfer = 'banking.transfer', cards = 'banking.cards', loans = 'banking.loans', payroll = 'banking.payroll' }

-- O que o personagem pode fazer na conta. `can(permission)` consulta o cargo (o dono tem tudo). Quem tem a permissão
-- antiga (`legacy`, ex.: business.funds) tem todas. Ver a conta vem junto com qualquer outra permissão bancária.
-- Depositar vale para qualquer pessoa do negócio (member).
function BusinessRules.Rights(can, member, legacy)
	local rights = { deposit = member == true }
	local all = legacy and can(legacy) == true
	local any = false
	for key, permission in pairs(KEYS) do
		rights[key] = all or can(permission) == true
		any = any or rights[key]
	end
	rights.view = rights.view or any
	return rights
end

-- Dia do limite do cartão (dias desde a época, em UTC).
function BusinessRules.Day(now)
	return now // DAY
end

-- Gasto de hoje do cartão (zera na virada do dia).
function BusinessRules.SpentToday(card, now)
	if card.spentDay ~= BusinessRules.Day(now) then
		return 0
	end
	return card.spentAmount or 0
end

-- Quanto ainda cabe no limite do dia (nil = sem limite).
function BusinessRules.Remaining(card, now)
	if not card.dailyLimit then
		return nil
	end
	return math.max(0, card.dailyLimit - BusinessRules.SpentToday(card, now))
end

-- Limite diário pedido: inteiro de 0 (sem limite) até o teto.
function BusinessRules.DailyLimit(value, settings)
	value = tonumber(value)
	if not value or value ~= value or value % 1 ~= 0 or value < 0 or value > settings.MaxDailyLimit then
		return nil, 'invalid_limit'
	end
	return math.tointeger(value)
end

-- Observação livre de transferências: sem controle nem < >, espaços reduzidos.
function BusinessRules.Memo(value, max)
	if type(value) ~= 'string' then
		return ''
	end
	local text = value:gsub('[%c<>]', ' '):gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
	if not utf8.len(text) then
		return ''
	end
	if utf8.len(text) > max then
		text = text:sub(1, utf8.offset(text, max + 1) - 1)
	end
	return text
end

-- Destino da transferência: { kind = 'person', stateId } ou { kind = 'business', id }.
function BusinessRules.Target(raw)
	if type(raw) ~= 'table' then
		return nil, 'invalid_target'
	end
	if raw.kind == 'business' then
		local id = raw.id
		if type(id) ~= 'string' or #id > 32 or not id:match('^[a-z][a-z0-9_]*$') then
			return nil, 'invalid_target'
		end
		return { kind = 'business', id = id }
	end
	if raw.kind == 'person' then
		if type(raw.stateId) ~= 'string' then
			return nil, 'invalid_state_id'
		end
		local clean = raw.stateId:gsub('%s', ''):upper()
		if #clean < 4 or #clean > 16 or not clean:match('^[A-Z0-9]+$') then
			return nil, 'invalid_state_id'
		end
		return { kind = 'person', stateId = clean }
	end
	return nil, 'invalid_target'
end

-- Categorias do extrato: rótulo e motivos (reason) do coe_economy que entram em cada uma.
BusinessRules.Categories = {
	{ id = 'deposits', label = 'Depósitos', reasons = { 'society_deposit', 'bank_deposit', 'business_deposit' } },
	{ id = 'withdrawals', label = 'Saques', reasons = { 'society_withdraw', 'bank_withdraw', 'business_withdraw' } },
	{ id = 'transfers', label = 'Transferências', reasons = { 'business_transfer', 'business_received', 'business_payment' } },
	{ id = 'payroll', label = 'Folha e bônus', reasons = { 'payroll', 'business_bonus' } },
	{ id = 'cards', label = 'Cartões', reasons = { 'business_card', 'business_card_refund', 'card_fee', 'atm_fee' } },
	{ id = 'loans', label = 'Empréstimos', reasons = { 'bank_loan', 'loan_payment', 'bank_refund' } },
	{ id = 'revenue', label = 'Receitas e repasses', reasons = { 'news_ad', 'fine', 'fines', 'sale', 'service' } },
	{ id = 'expenses', label = 'Despesas', reasons = { 'rent', 'commercial_rent', 'news_ad_refund' } }
}

local byReason = {}
for _, category in ipairs(BusinessRules.Categories) do
	for _, reason in ipairs(category.reasons) do
		byReason[reason] = byReason[reason] or category.id
	end
end

function BusinessRules.CategoryOf(reason)
	return byReason[reason] or 'other'
end

-- Filtro do extrato vindo da NUI: { category, direction, days, beforeId } -> filtro do coe_economy + categoria.
function BusinessRules.Filter(raw, settings)
	raw = type(raw) == 'table' and raw or {}
	local filter = { limit = settings.StatementPage, days = settings.Periods[#settings.Periods] }
	for _, days in ipairs(settings.Periods) do
		if tonumber(raw.days) == days then
			filter.days = days
		end
	end
	if raw.direction == 'in' or raw.direction == 'out' then
		filter.direction = raw.direction
	end
	local beforeId = tonumber(raw.beforeId)
	if beforeId and beforeId % 1 == 0 and beforeId > 0 then
		filter.beforeId = math.tointeger(beforeId)
	end
	for _, category in ipairs(BusinessRules.Categories) do
		if raw.category == category.id then
			filter.category = category.id
			filter.reasons = category.reasons
		end
	end
	return filter
end

-- Id da operação do banco a partir da referência do extrato (`bop:<id>`).
function BusinessRules.OpId(reference)
	local id = type(reference) == 'string' and reference:match('^bop:(%d+)$')
	return id and math.tointeger(tonumber(id)) or nil
end

-- Folha prevista: quem recebe (de ponto) e quem fica de fora agora. entries: { characterId, name, salary, onDuty }.
function BusinessRules.PayrollPreview(entries, balance)
	local preview = { members = {}, due = 0, total = 0, covered = true }
	for _, entry in ipairs(entries or {}) do
		local salary = tonumber(entry.salary) or 0
		preview.total = preview.total + salary
		if entry.onDuty and salary > 0 then
			preview.due = preview.due + salary
		end
		preview.members[#preview.members + 1] = {
			characterId = entry.characterId, name = entry.name, grade = entry.grade, salary = salary, onDuty = entry.onDuty == true
		}
	end
	preview.covered = (balance or 0) >= preview.due
	table.sort(preview.members, function(a, b)
		if a.onDuty ~= b.onDuty then
			return a.onDuty
		end
		return (a.name or '') < (b.name or '')
	end)
	return preview
end
