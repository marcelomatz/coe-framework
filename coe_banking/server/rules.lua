BankingRules = {}

-- Valor inteiro entre 1 e max.
function BankingRules.Amount(value, max)
	value = tonumber(value)
	if not value or value ~= value or value % 1 ~= 0 or value < 1 or value > max then
		return nil, 'invalid_amount'
	end
	return math.tointeger(value)
end

function BankingRules.Pin(value)
	if type(value) ~= 'string' or not value:match('^%d%d%d%d$') then
		return nil, 'invalid_pin'
	end
	return value
end

function BankingRules.StateId(value)
	if type(value) ~= 'string' then
		return nil, 'invalid_state_id'
	end
	local clean = value:gsub('%s', ''):upper()
	if #clean < 4 or #clean > 16 or not clean:match('^[A-Z0-9]+$') then
		return nil, 'invalid_state_id'
	end
	return clean
end

function BankingRules.CardId(value)
	value = tonumber(value)
	if not value or value ~= value or value % 1 ~= 0 or value < 1 then
		return nil
	end
	return math.tointeger(value)
end

-- Número de 16 dígitos; `digit()` devolve 0..9.
function BankingRules.Serial(digit)
	local parts = { '7' }
	for _ = 2, 16 do
		parts[#parts + 1] = tostring(digit())
	end
	return table.concat(parts)
end

function BankingRules.Salt(digit)
	local parts = {}
	for _ = 1, 12 do
		parts[#parts + 1] = string.char(97 + digit())
	end
	return table.concat(parts)
end

function BankingRules.Last4(serial)
	return tostring(serial or ''):sub(-4)
end

-- `hash(text)` devolve inteiro de 32 bits; rodadas encadeadas com o salt.
function BankingRules.HashPin(pin, salt, rounds, hash)
	local value = salt .. ':' .. pin
	for _ = 1, math.max(rounds, 1) do
		value = ('%08x'):format(hash(salt .. value) & 0xffffffff)
	end
	return value
end

function BankingRules.Status(card, now)
	if card.blockedReason and card.blockedReason ~= '' then
		return 'blocked'
	end
	if card.expiresAt and (now or os.time()) >= card.expiresAt then
		return 'expired'
	end
	return 'active'
end

-- Resultado da tentativa: { ok } ou { ok = false, attempts, blocked }.
function BankingRules.CheckPin(card, pin, config, hash)
	if BankingRules.Status(card) ~= 'active' then
		return { ok = false, attempts = card.attempts, blocked = true, already = true }
	end
	if BankingRules.HashPin(pin, card.pinSalt, config.PinHashRounds, hash) == card.pinHash then
		return { ok = true, attempts = 0 }
	end
	local attempts = (card.attempts or 0) + 1
	return { ok = false, attempts = attempts, blocked = attempts >= config.MaxPinAttempts }
end

-- Bloqueio por senha se desfaz com nova senha na agência; perda/roubo e substituição são definitivos.
function BankingRules.CanResetPin(card)
	return card.blockedReason == nil or card.blockedReason == '' or card.blockedReason == 'pin'
end

-- Pode entrar na carteira digital? Virtual: só da conta do personagem. Físico: o cartão em mãos (a senha é conferida depois).
-- Devolve true ou nil + código.
function BankingRules.CanLink(card, characterId, inHand, now)
	local status = BankingRules.Status(card, now)
	if status ~= 'active' then
		return nil, status == 'expired' and 'card_expired' or 'card_blocked'
	end
	if card.kind == 'virtual' then
		if card.accountRef ~= tostring(characterId) then
			return nil, 'not_owner'
		end
		return true
	end
	if not inHand then
		return nil, 'no_card'
	end
	return true
end

-- Ids de cartão (únicos, ordenados) presentes num snapshot de inventário.
function BankingRules.CardsInInventory(snapshot)
	local found, order = {}, {}
	for _, item in pairs(type(snapshot) == 'table' and type(snapshot.items) == 'table' and snapshot.items or {}) do
		if type(item) == 'table' and item.name == 'card_bank' and type(item.metadata) == 'table' then
			local id = BankingRules.CardId(item.metadata.cardId)
			if id and not found[id] then
				found[id] = true
				order[#order + 1] = id
			end
		end
	end
	table.sort(order)
	return order
end
