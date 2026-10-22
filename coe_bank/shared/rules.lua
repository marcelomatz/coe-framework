-- Regras do banco básico, sem natives (testáveis fora do jogo).
BankRules = {}

local STATE_ID_ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789'
local STATE_ID_LENGTH = 8

-- Operações aceitas em cada tipo de atendimento. Transferência e consulta de destinatário só na agência.
BankRules.Actions = {
	agency = { refresh = true, withdraw = true, deposit = true, lookup = true, transfer = true },
	atm = { refresh = true, withdraw = true, deposit = true }
}

---Valor inteiro entre 1 e max, ou nil + 'invalid_amount'.
function BankRules.Amount(value, max)
	value = tonumber(value)
	if not value or value ~= value or value % 1 ~= 0 or value < 1 or value > max then
		return nil, 'invalid_amount'
	end
	return math.tointeger(value)
end

---ID público do personagem (stateId): sem espaços, em maiúsculas e no alfabeto do coe_core.
function BankRules.StateId(value)
	if type(value) ~= 'string' then
		return nil, 'invalid_state_id'
	end
	local clean = value:gsub('[%s%-]', ''):upper()
	if #clean ~= STATE_ID_LENGTH then
		return nil, 'invalid_state_id'
	end
	for index = 1, #clean do
		if not STATE_ID_ALPHABET:find(clean:sub(index, index), 1, true) then
			return nil, 'invalid_state_id'
		end
	end
	return clean
end

function BankRules.Allowed(mode, action)
	local actions = BankRules.Actions[mode]
	return actions ~= nil and type(action) == 'string' and actions[action] == true
end

function BankRules.Agency(config, agencyId)
	if type(agencyId) ~= 'string' then
		return nil
	end
	for _, agency in ipairs(config.Agencies) do
		if agency.id == agencyId then
			return agency
		end
	end
	return nil
end

---Distância horizontal até `radius` e diferença de altura até 4 m.
function BankRules.Near(a, b, radius)
	if type(a) ~= 'table' or type(b) ~= 'table' then
		return false
	end
	local dx, dy, dz = (a.x or 0) - (b.x or 0), (a.y or 0) - (b.y or 0), (a.z or 0) - (b.z or 0)
	return math.sqrt(dx * dx + dy * dy) <= radius and math.abs(dz) <= 4.0
end

---Atalhos de valor que cabem no teto.
function BankRules.Quick(amounts, max)
	local list = {}
	for _, amount in ipairs(type(amounts) == 'table' and amounts or {}) do
		local value = BankRules.Amount(amount, max)
		if value then
			list[#list + 1] = value
		end
	end
	return list
end

---Extrato do coe_economy (mais recentes primeiro) no formato da tela: { delta, reason, reference, at }.
function BankRules.Statement(rows, size)
	local list = {}
	if type(rows) ~= 'table' or rows.error then
		return list
	end
	for _, row in ipairs(rows) do
		if #list >= size then
			break
		end
		if type(row) == 'table' then
			list[#list + 1] = {
				delta = math.tointeger(tonumber(row.delta) or 0) or 0,
				reason = type(row.reason) == 'string' and row.reason or '',
				reference = type(row.reference) == 'string' and row.reference or '',
				at = row.created_at
			}
		end
	end
	return list
end

---Nome de exibição do personagem.
function BankRules.Name(first, last)
	local name = ((first or '') .. ' ' .. (last or '')):gsub('^%s+', ''):gsub('%s+$', '')
	return name ~= '' and name or nil
end

return BankRules
