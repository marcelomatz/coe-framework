-- Banking Wallet, POS and Shop Charge API Exports
local Banking = Banking
local config = Banking.config
local log = function(...) return Banking.log(...) end
local audit = function(...) return Banking.audit(...) end
local notify = function(...) return Banking.notify(...) end
local playerOf = function(...) return Banking.playerOf(...) end
local cardView = function(...) return Banking.cardView(...) end
local hashKey = function(...) return Banking.hashKey(...) end
local debit = function(...) return Banking.debit(...) end
local credit = function(...) return Banking.credit(...) end
local withCreditLock = function(...) return Banking.withCreditLock(...) end
local issueVirtual = function(...) return Banking.issueVirtual(...) end
local ownCard = function(...) return Banking.ownCard(...) end
local remote = function(...) return Banking.remote(...) end

local function walletCaller()
	return config.WalletCallers[GetInvokingResource() or ''] == true
end

-- O que a carteira mostra do cartão (nunca o número inteiro nem a senha).
local function walletCard(card)
	if card.accountType == 'business' then
		local business = remote('coe_businesses', 'Get', card.accountRef)
		return {
			id = card.id, last4 = BankingRules.Last4(card.serial), holder = card.holderName, kind = card.kind,
			status = BankingRules.Status(card), expiresAt = card.expiresAt, tier = 'business',
			tierLabel = type(business) == 'table' and ('Empresarial · ' .. (business.label or business.id)):sub(1, 48) or 'Empresarial'
		}
	end
	local tier = creditTierOf(card.accountRef)
	return {
		id = card.id, last4 = BankingRules.Last4(card.serial), holder = card.holderName, kind = card.kind,
		status = BankingRules.Status(card), expiresAt = card.expiresAt, tier = tier and tier.id or nil, tierLabel = tier and tier.label or nil
	}
end

-- Cartões que o jogador pode pôr na carteira: os físicos ativos no inventário e o virtual ativo da própria conta.
exports('WalletEligible', function(playerId)
	if not walletCaller() then
		return { ok = false, error = 'forbidden' }
	end
	local source = tonumber(playerId)
	local who = ready and source and character(source)
	if not who then
		return { ok = false, error = ready and 'no_character' or 'not_ready' }
	end
	local inventoryId = inventoryOf(source)
	local snapshot = inventoryId and remote('coe_inventory', 'GetInventory', inventoryId) or nil
	local found, errorCode = BankingPersistence.Cards(BankingRules.CardsInInventory(snapshot))
	if not found then
		return { ok = false, error = errorCode }
	end
	local cards, hasVirtual = {}, false
	for _, card in pairs(found) do
		if card.kind == 'physical' and BankingRules.Status(card) == 'active' then
			cards[#cards + 1] = walletCard(card)
		end
	end
	for _, card in ipairs(BankingPersistence.AccountCards('personal', who.characterId) or {}) do
		if card.kind == 'virtual' and BankingRules.Status(card) == 'active' then
			cards[#cards + 1] = walletCard(card)
			hasVirtual = true
		end
	end
	table.sort(cards, function(a, b) return a.id > b.id end)
	return { ok = true, cards = cards, hasVirtual = hasVirtual, virtualFee = config.VirtualCardFee or 0 }
end)

-- Vincula um cartão: virtual da própria conta, ou físico em mãos com a senha (erros contam como no caixa eletrônico).
exports('WalletLink', function(playerId, cardId, pin)
	if not walletCaller() then
		return { ok = false, error = 'forbidden' }
	end
	local source, id = tonumber(playerId), BankingRules.CardId(cardId)
	local who = ready and source and character(source)
	if not who then
		return { ok = false, error = ready and 'no_character' or 'not_ready' }
	end
	if not id then
		return { ok = false, error = 'card_not_found' }
	end
	if busy[source] then
		return { ok = false, error = 'busy' }
	end
	busy[source] = true
	local ok, result = pcall(function()
		local card, cardError = BankingPersistence.Card(id)
		if not card then
			return { ok = false, error = cardError }
		end
		local allowed, denied = BankingRules.CanLink(card, who.characterId, card.kind == 'physical' and cardInHand(source, id), os.time())
		if not allowed then
			return { ok = false, error = denied }
		end
		if card.kind == 'physical' then
			if type(pin) ~= 'string' then
				return { ok = false, error = 'invalid_pin' }
			end
			local check = BankingRules.CheckPin(card, pin, config, hashKey)
			if not check.ok then
				BankingPersistence.SetAttempts(card.id, check.attempts, check.blocked and 'pin' or nil)
				if check.blocked then
					audit('bank_card_blocked', { character_id = card.accountRef, item = 'card_bank', request_id = tostring(card.id), action = 'pin' })
					return { ok = false, error = 'card_blocked' }
				end
				return { ok = false, error = 'wrong_pin', left = config.MaxPinAttempts - check.attempts }
			end
			if card.attempts > 0 then
				BankingPersistence.SetAttempts(card.id, 0, nil)
			end
		end
		audit('bank_wallet_linked', { character_id = who.characterId, item = card.kind, request_id = tostring(card.id) })
		return { ok = true, card = walletCard(card) }
	end)
	busy[source] = nil
	if not ok then
		log('error', 'banking', 'wallet_link_failed', { player_id = source, error_code = tostring(result):sub(1, 96) })
		return { ok = false, error = 'database_error' }
	end
	return result
end)

-- Situação atual dos cartões de uma carteira (até 10 ids): { ok, cards = { [id] = view } }; cartão inexistente fica de fora.
exports('WalletCards', function(cardIds)
	if not walletCaller() then
		return { ok = false, error = 'forbidden' }
	end
	if not ready then
		return { ok = false, error = 'not_ready' }
	end
	local ids = {}
	for index, value in ipairs(type(cardIds) == 'table' and cardIds or {}) do
		local id = BankingRules.CardId(value)
		if index > 10 or not id then
			return { ok = false, error = 'card_not_found' }
		end
		ids[#ids + 1] = id
	end
	local found, errorCode = BankingPersistence.Cards(ids)
	if not found then
		return { ok = false, error = errorCode }
	end
	local cards = {}
	for id, card in pairs(found) do
		cards[tostring(id)] = walletCard(card)
	end
	return { ok = true, cards = cards }
end)

-- Pede um cartão virtual pela carteira (mesma regra da agência): devolve o cartão emitido.
exports('WalletIssueVirtual', function(playerId)
	if not walletCaller() then
		return { ok = false, error = 'forbidden' }
	end
	local source = tonumber(playerId)
	local who = ready and source and character(source)
	if not who then
		return { ok = false, error = ready and 'no_character' or 'not_ready' }
	end
	if busy[source] or throttled(source) then
		return { ok = false, error = 'busy' }
	end
	busy[source] = true
	local ok, card, errorCode = pcall(issueVirtual, source, who)
	busy[source] = nil
	if not ok or not card then
		return { ok = false, error = ok and errorCode or 'database_error' }
	end
	return { ok = true, card = walletCard(card) }
end)

-- Compra sem a maquininha, no crédito do cartão escolhido na carteira digital. Só para os resources em
-- `Credit.PurchaseCallers`. O cartão precisa estar ativo e a conta de crédito em dia.
local function purchaseInput(cardId, amount, description)
	if not creditConfig.PurchaseCallers[GetInvokingResource() or ''] then
		return nil, 'forbidden'
	end
	if not ready then
		return nil, 'not_ready'
	end
	local id = BankingRules.CardId(cardId)
	local value = wholeNumber(amount, 1, creditConfig.MaxPurchase)
	if not id then
		return nil, 'no_card'
	end
	if not value then
		return nil, 'invalid_amount'
	end
	local card, cardError = BankingPersistence.Card(id)
	if not card then
		return nil, cardError == 'card_not_found' and 'no_card' or cardError
	end
	local label = type(description) == 'string' and description:gsub('[%c<>]', ''):sub(1, 64) or ''
	return { card = card, characterId = card.accountRef, amount = value, label = label }
end

local function creditResult(result, errorCode)
	if type(result) ~= 'table' then
		return { ok = false, error = errorCode or (type(result) == 'string' and result) or 'database_error' }
	end
	result.ok = true
	return result
end

-- Devolve { ok = true, points, available } ou { ok = false, error } (no_card, card_blocked, card_expired, no_credit,
-- credit_late, credit_limit, busy).
-- Cobra uma compra já validada (`purchaseInput`) no crédito do titular ou no caixa do negócio (cartão empresarial).
local function chargeCard(input)
	local status = BankingRules.Status(input.card)
	if status ~= 'active' then
		return { ok = false, error = status == 'expired' and 'card_expired' or 'card_blocked' }
	end
	-- Cartão empresarial: débito no caixa do negócio, dentro do limite diário do cartão.
	if input.card.accountType == 'business' then
		return BankingBusiness.CardPurchase(input)
	end
	local result, errorCode = withCreditLock(input.characterId, function()
		local state, loadError = settleCredit(input.characterId)
		if state == nil then
			return nil, loadError
		end
		if state == false then
			return nil, 'no_credit'
		end
		local allowed, denied = CreditRules.CanPurchase(state, input.amount)
		if not allowed then
			return nil, denied
		end
		CreditRules.Purchase(state, input.amount)
		local tier = CreditRules.Tier(creditConfig, state.tier)
		local points = tier and CreditRules.Points(input.amount, tier) or 0
		state.points = state.points + points
		local saved, saveError = BankingPersistence.SaveCredit(state, {
			{ kind = 'purchase', amount = input.amount, description = input.label, at = os.time() }
		})
		if not saved then
			return nil, saveError
		end
		return { points = points, available = CreditRules.Available(state) }
	end)
	if type(result) == 'table' then
		audit('credit_purchase', { character_id = input.characterId, operation = GetInvokingResource(), request_id = tostring(input.card.id), count = input.amount })
	end
	return creditResult(result, errorCode)
end

-- Devolve { ok = true, points, available } ou { ok = false, error } (no_card, card_blocked, card_expired, no_credit,
-- credit_late, credit_limit, busy).
exports('CardPurchase', function(cardId, amount, description)
	local input, inputError = purchaseInput(cardId, amount, description)
	if not input then
		return { ok = false, error = inputError }
	end
	return chargeCard(input)
end)

-- Maquininha (balcão de loja): cartões físicos ativos que o jogador tem no inventário, para escolher na hora de pagar.
-- Só para `Credit.PurchaseCallers`. Devolve { ok, cards = { { id, last4, holder, kind, business } } }.
local function posCards(playerId)
	if not creditConfig.PurchaseCallers[GetInvokingResource() or ''] then
		return { ok = false, error = 'forbidden' }
	end
	local source = tonumber(playerId)
	if not ready or not source then
		return { ok = false, error = 'not_ready' }
	end
	local inventoryId = inventoryOf(source)
	local snapshot = inventoryId and remote('coe_inventory', 'GetInventory', inventoryId) or nil
	local found, errorCode = BankingPersistence.Cards(BankingRules.CardsInInventory(snapshot))
	if not found then
		return { ok = false, error = errorCode }
	end
	local cards = {}
	for _, card in pairs(found) do
		if card.kind == 'physical' and BankingRules.Status(card) == 'active' then
			cards[#cards + 1] = {
				id = card.id, last4 = BankingRules.Last4(card.serial), holder = card.holderName,
				business = card.accountType == 'business'
			}
		end
	end
	table.sort(cards, function(a, b) return a.id > b.id end)
	return { ok = true, cards = cards }
end
exports('PosCards', posCards)

-- Compra na maquininha: cartão físico em mãos e a senha (erros contam tentativas como no caixa eletrônico), depois a
-- mesma cobrança do CardPurchase. Só para `Credit.PurchaseCallers`. Erros extras: card_not_in_hand, wrong_pin (com
-- `left`), invalid_pin.
local function posPurchase(playerId, cardId, pin, amount, description)
	local input, inputError = purchaseInput(cardId, amount, description)
	if not input then
		return { ok = false, error = inputError }
	end
	local source = tonumber(playerId)
	if not source or input.card.kind ~= 'physical' or not cardInHand(source, input.card.id) then
		return { ok = false, error = 'card_not_in_hand' }
	end
	if busy[source] then
		return { ok = false, error = 'busy' }
	end
	if type(pin) ~= 'string' or not pin:match('^%d%d%d%d$') then
		return { ok = false, error = 'invalid_pin' }
	end
	busy[source] = true
	local ok, result = pcall(function()
		local check = BankingRules.CheckPin(input.card, pin, config, hashKey)
		if not check.ok then
			BankingPersistence.SetAttempts(input.card.id, check.attempts, check.blocked and 'pin' or nil)
			if check.blocked then
				audit('bank_card_blocked', { character_id = input.card.accountRef, item = 'card_bank', request_id = tostring(input.card.id), action = 'pin' })
				return { ok = false, error = 'card_blocked' }
			end
			return { ok = false, error = 'wrong_pin', left = config.MaxPinAttempts - check.attempts }
		end
		if input.card.attempts > 0 then
			BankingPersistence.SetAttempts(input.card.id, 0, nil)
		end
		return chargeCard(input)
	end)
	busy[source] = nil
	if not ok then
		log('error', 'banking', 'pos_purchase_failed', { player_id = source, error_code = tostring(result):sub(1, 96) })
		return { ok = false, error = 'database_error' }
	end
	return result
end
exports('PosPurchase', posPurchase)

-- Desfaz uma compra feita por CardPurchase (ex.: a loja não conseguiu gravar), mesmo com o cartão já bloqueado.
local function cardRefund(cardId, amount, description)
	local input, inputError = purchaseInput(cardId, amount, description)
	if not input then
		return { ok = false, error = inputError }
	end
	if input.card.accountType == 'business' then
		return BankingBusiness.CardRefund(input)
	end
	local result, errorCode = withCreditLock(input.characterId, function()
		local state, loadError = settleCredit(input.characterId)
		if state == nil then
			return nil, loadError
		end
		if state == false then
			return nil, 'no_credit'
		end
		local applied = CreditRules.Refund(state, input.amount)
		local tier = CreditRules.Tier(creditConfig, state.tier)
		state.points = math.max(0, state.points - (tier and CreditRules.Points(input.amount, tier) or 0))
		local saved, saveError = BankingPersistence.SaveCredit(state, {
			{ kind = 'refund', amount = applied, description = input.label, at = os.time() }
		})
		if not saved then
			return nil, saveError
		end
		return { refunded = applied }
	end)
	if type(result) == 'table' then
		audit('credit_refund', { character_id = input.characterId, operation = GetInvokingResource(), request_id = tostring(input.card.id), count = result.refunded })
	end
	return creditResult(result, errorCode)
end
exports('CardRefund', cardRefund)

-- Maquininha nas lojas (registrada com coe_shops:RegisterPaymentMethod, meio `card`): opções são os cartões físicos
-- ativos em mãos; a cobrança pede a senha. O chamador continua sendo a loja (Credit.PurchaseCallers).
exports('ShopOptions', function(playerId)
	local result = posCards(playerId)
	local options = {}
	for _, card in ipairs(type(result) == 'table' and result.ok and result.cards or {}) do
		options[#options + 1] = { id = card.id, label = (card.business and 'Empresa ' or '') .. '•••• ' .. card.last4 }
	end
	return {
		options = options,
		detail = #options > 0 and 'Cartão do banco que está com você, com a senha' or 'Nenhum cartão do banco com você'
	}
end)

exports('ShopCharge', function(playerId, payment, amount, description)
	local cardId = type(payment) == 'table' and math.tointeger(tonumber(payment.option)) or nil
	if not cardId then
		return { ok = false, error = 'no_card' }
	end
	local result = posPurchase(playerId, cardId, payment.pin, amount, description)
	if type(result) == 'table' and result.ok then
		result.ref = cardId
	end
	return result
end)

exports('ShopRefund', function(_, ref, amount, description)
	return cardRefund(ref, amount, description)
end)

-- Integrações registradas no framework: aba Banco no app do negócio (substitui o Financeiro) e a maquininha nas
-- lojas. De novo sempre que o coe_businesses ou o coe_shops reiniciarem.