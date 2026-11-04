-- Digital Wallet & Cards Management
local Phone = Phone
local config = Phone.config
local log = function(...) return Phone.log(...) end
local notify = function(...) return Phone.notify(...) end
local banking = function(...) return Phone.banking(...) end

local function banking(exportName, ...)
	if GetResourceState('coe_banking') ~= 'started' then
		return nil, 'bank_unavailable'
	end
	local arguments = { ... }
	local ok, result = pcall(function()
		return exports.coe_banking[exportName](exports.coe_banking, table.unpack(arguments))
	end)
	if not ok or type(result) ~= 'table' then
		return nil, 'bank_unavailable'
	end
	return result
end

-- { [cardId] = isDefault } guardados no aparelho.
local function walletIds(serial)
	local rows = PhonePersistence.WalletCards(serial)
	if not rows then
		return nil
	end
	local list, ids = {}, {}
	for _, row in ipairs(rows) do
		local id = math.tointeger(tonumber(row.card_id))
		if id then
			list[#list + 1] = { id = id, default = tonumber(row.is_default) == 1 }
			ids[#ids + 1] = id
		end
	end
	return list, ids
end

local function walletView(me)
	local list, ids = walletIds(me.serial)
	if not list then
		return nil, 'database_error'
	end
	local views = {}
	if #ids > 0 then
		local result, errorCode = banking('WalletCards', ids)
		if not result then
			return nil, errorCode
		end
		views = result.ok and result.cards or {}
	end
	local cards = {}
	for _, entry in ipairs(list) do
		local view = views[tostring(entry.id)]
		cards[#cards + 1] = {
			id = entry.id, default = entry.default,
			last4 = view and view.last4 or '----', holder = view and view.holder or '',
			kind = view and view.kind or 'physical', tier = view and view.tier, tierLabel = view and view.tierLabel,
			status = view and view.status or 'missing', expiresAt = view and view.expiresAt
		}
	end
	return { cards = cards, max = config.Wallet.MaxCards, hasPasscode = me.prefs.passcode ~= false }
end

local function inWallet(serial, cardId)
	local list = walletIds(serial)
	if not list then
		return nil
	end
	for _, entry in ipairs(list) do
		if entry.id == cardId then
			return entry
		end
	end
	return false
end

-- Rosto cadastrado (se ligado) ou senha do aparelho.
local function confirmOwner(me, payload)
	if payload.face == true then
		if not me.prefs.settings.faceId or me.device.face ~= me.characterId then
			return { ok = false, error = 'face_mismatch' }
		end
		return nil
	end
	return verifyCurrent(me, payload.code)
end

local function newToken()
	local parts = {}
	for index = 1, 4 do
		parts[index] = ('%08x'):format(math.random(0, 0x7fffffff))
	end
	return table.concat(parts)
end

local function walletLocked(me, run)
	if walletBusy[me.playerId] then
		return { ok = false, error = 'busy' }
	end
	walletBusy[me.playerId] = true
	local ok, result = pcall(run)
	walletBusy[me.playerId] = nil
	if not ok then
		error(result, 0)
	end
	return result
end

Native.wallet = {
	list = function(me)
		local view, errorCode = walletView(me)
		if not view then
			return { ok = false, error = errorCode }
		end
		return { ok = true, data = view }
	end,
	-- Cartões que podem entrar: físicos no inventário e virtuais do personagem.
	eligible = function(me)
		local result, errorCode = banking('WalletEligible', me.playerId)
		if not result then
			return { ok = false, error = errorCode }
		end
		if not result.ok then
			return { ok = false, error = result.error }
		end
		local list = walletIds(me.serial)
		if not list then
			return { ok = false, error = 'database_error' }
		end
		local present = {}
		for _, entry in ipairs(list) do
			present[entry.id] = true
		end
		local cards = {}
		for _, card in ipairs(result.cards or {}) do
			card.added = present[card.id] == true
			cards[#cards + 1] = card
		end
		return { ok = true, data = { cards = cards, hasVirtual = result.hasVirtual, virtualFee = result.virtualFee } }
	end,
	-- payload.cardId; payload.pin (cartão físico).
	add = function(me, payload)
		if not me.prefs.passcode then
			return { ok = false, error = 'wallet_passcode' }
		end
		local cardId = math.tointeger(tonumber(payload.cardId))
		if not cardId or cardId < 1 or (payload.pin ~= nil and type(payload.pin) ~= 'string') then
			return { ok = false, error = 'invalid_request' }
		end
		return walletLocked(me, function()
			local list = walletIds(me.serial)
			if not list then
				return { ok = false, error = 'database_error' }
			end
			for _, entry in ipairs(list) do
				if entry.id == cardId then
					return { ok = false, error = 'already_in_wallet' }
				end
			end
			if #list >= config.Wallet.MaxCards then
				return { ok = false, error = 'wallet_full' }
			end
			local result, errorCode = banking('WalletLink', me.playerId, cardId, payload.pin)
			if not result then
				return { ok = false, error = errorCode }
			end
			if not result.ok then
				return { ok = false, error = result.error, data = result.left and { left = result.left } or nil }
			end
			if not PhonePersistence.WalletAdd(me.serial, cardId, #list == 0, os.time()) then
				return { ok = false, error = 'database_error' }
			end
			log('info', 'system', 'phone_wallet_added', { character_id = me.characterId, count = cardId })
			local view = walletView(me)
			return { ok = true, data = view }
		end)
	end,
	remove = function(me, payload)
		local cardId = math.tointeger(tonumber(payload.cardId))
		if not cardId then
			return { ok = false, error = 'invalid_request' }
		end
		return walletLocked(me, function()
			local entry = inWallet(me.serial, cardId)
			if entry == nil then
				return { ok = false, error = 'database_error' }
			end
			if not entry then
				return { ok = false, error = 'not_in_wallet' }
			end
			if not PhonePersistence.WalletRemove(me.serial, cardId) then
				return { ok = false, error = 'database_error' }
			end
			if entry.default then
				local list = walletIds(me.serial)
				if list and list[1] then
					PhonePersistence.WalletDefault(me.serial, list[1].id)
				end
			end
			for token, payment in pairs(payments) do
				if payment.serial == me.serial and payment.cardId == cardId then
					payments[token] = nil
				end
			end
			return { ok = true, data = walletView(me) }
		end)
	end,
	setDefault = function(me, payload)
		local cardId = math.tointeger(tonumber(payload.cardId))
		if not cardId then
			return { ok = false, error = 'invalid_request' }
		end
		local entry = inWallet(me.serial, cardId)
		if entry == nil then
			return { ok = false, error = 'database_error' }
		end
		if not entry then
			return { ok = false, error = 'not_in_wallet' }
		end
		if not PhonePersistence.WalletDefault(me.serial, cardId) then
			return { ok = false, error = 'database_error' }
		end
		return { ok = true, data = walletView(me) }
	end,
	-- Pede o cartão virtual ao banco (cobra a tarifa da conta) e já guarda na carteira.
	issueVirtual = function(me)
		if not me.prefs.passcode then
			return { ok = false, error = 'wallet_passcode' }
		end
		return walletLocked(me, function()
			local result, errorCode = banking('WalletIssueVirtual', me.playerId)
			if not result then
				return { ok = false, error = errorCode }
			end
			if not result.ok then
				return { ok = false, error = result.error }
			end
			local list = walletIds(me.serial)
			local view = list and walletView(me)
			if view and result.card and result.card.id then
				-- O virtual anterior foi substituído (bloqueado): sai da carteira e dá lugar ao novo.
				for _, card in ipairs(view.cards) do
					if card.kind == 'virtual' and card.status == 'blocked' and card.id ~= result.card.id then
						PhonePersistence.WalletRemove(me.serial, card.id)
					end
				end
				list = walletIds(me.serial)
			end
			if list and #list < config.Wallet.MaxCards and result.card and result.card.id then
				local hadDefault = false
				for _, entry in ipairs(list) do
					hadDefault = hadDefault or entry.default
				end
				PhonePersistence.WalletAdd(me.serial, result.card.id, not hadDefault, os.time())
			end
			return { ok = true, data = walletView(me) }
		end)
	end,
	-- Autoriza um pagamento: { cardId, amount, face | code } -> { token, expires }.
	authorize = function(me, payload)
		if not me.prefs.passcode then
			return { ok = false, error = 'wallet_passcode' }
		end
		local cardId = math.tointeger(tonumber(payload.cardId))
		local amount = math.tointeger(tonumber(payload.amount))
		if not cardId or not amount or amount < 1 or amount > config.Wallet.MaxAmount then
			return { ok = false, error = 'invalid_request' }
		end
		local entry = inWallet(me.serial, cardId)
		if entry == nil then
			return { ok = false, error = 'database_error' }
		end
		if not entry then
			return { ok = false, error = 'not_in_wallet' }
		end
		local denied = confirmOwner(me, payload)
		if denied then
			return denied
		end
		local result, errorCode = banking('WalletCards', { cardId })
		if not result then
			return { ok = false, error = errorCode }
		end
		local card = result.ok and result.cards and result.cards[tostring(cardId)]
		if not card then
			return { ok = false, error = 'no_card' }
		end
		if card.status ~= 'active' then
			return { ok = false, error = card.status == 'expired' and 'card_expired' or 'card_blocked' }
		end
		for token, payment in pairs(payments) do
			if payment.playerId == me.playerId then
				payments[token] = nil
			end
		end
		local token = newToken()
		payments[token] = { playerId = me.playerId, serial = me.serial, cardId = cardId, amount = amount, expires = os.time() + config.Wallet.PaymentSeconds }
		log('info', 'system', 'phone_wallet_authorized', { character_id = me.characterId, count = amount })
		return { ok = true, data = { token = token, expires = config.Wallet.PaymentSeconds } }
	end
}
local simErrors = {
	invalid_sim = 'Este chip não funciona.',
	in_call = 'Encerre a ligação antes de trocar o chip.',
	no_free_sim_slot = 'Não há espaço para outro chip neste celular. Retire o atual em Ajustes.',
	inventory_unavailable = 'O inventário não respondeu. Tente de novo.',
	slot_changed = 'O chip não está mais nesse lugar do inventário.'
Phone.walletView = walletView
Phone.inWallet = inWallet
Phone.confirmOwner = confirmOwner
Phone.newToken = newToken
Phone.walletLocked = walletLocked
Phone.WALLET_DISPATCH = WALLET_DISPATCH