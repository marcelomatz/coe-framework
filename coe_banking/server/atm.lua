-- ATM Network Events and Authorization
local Banking = Banking
local config = Banking.config
local log = function(...) return Banking.log(...) end
local audit = function(...) return Banking.audit(...) end
local notify = function(...) return Banking.notify(...) end
local fail = function(...) return Banking.fail(...) end
local throttled = function(...) return Banking.throttled(...) end
local character = function(...) return Banking.character(...) end
local playerOf = function(...) return Banking.playerOf(...) end
local cardView = function(...) return Banking.cardView(...) end
local withdrawCash = function(...) return Banking.withdrawCash(...) end
local depositCash = function(...) return Banking.depositCash(...) end
local statement = function(...) return Banking.statement(...) end
local atmFeeFor = function(...) return Banking.atmFeeFor(...) end
local debit = function(...) return Banking.debit(...) end
local credit = function(...) return Banking.credit(...) end
local ownCard = function(...) return Banking.ownCard(...) end
local hashKey = function(...) return Banking.hashKey(...) end
local inventoryOf = function(...) return Banking.inventoryOf(...) end
local remote = function(...) return Banking.remote(...) end
local creditTierOf = function(...) return Banking.creditTierOf(...) end
local balanceOf = function(...) return Banking.balanceOf(...) end
local cashOf = function(...) return Banking.cashOf(...) end
local guarded = function(...) return Banking.guarded(...) end
local _t = function(...) return Banking.t(...) end
local money = function(...) return Banking.money(...) end
local atmSessions = Banking.atmSessions

local function cardInHand(playerId, cardId)
	local inventoryId = inventoryOf(playerId)
	if not inventoryId then
		return false
	end
	return (tonumber(remote('coe_inventory', 'GetItemCount', inventoryId, 'card_bank', { cardId = cardId }, false)) or 0) > 0
end

local function atmView(playerId, card)
	if card.accountType == 'business' then
		local business = BankingBusiness.CardUsable(card)
		if business then
			return BankingBusiness.AtmView(playerId, card, business)
		end
	end
	local inventoryId = inventoryOf(playerId)
	local tier = creditTierOf(card.accountRef)
	return {
		mode = 'atm',
		step = 'menu',
		cardId = card.id,
		last4 = BankingRules.Last4(card.serial),
		holder = card.holderName,
		tier = tier and tier.id or nil,
		tierLabel = tier and tier.label or nil,
		fee = (tier and tier.freeAtm) and 0 or (config.AtmWithdrawFee or 0),
		balance = balanceOf(card.accountRef),
		cash = inventoryId and cashOf(inventoryId) or 0,
		maxAmount = config.MaxAtmAmount,
		quick = config.AtmQuickAmounts,
		statement = statement(card.accountRef, config.AtmStatementSize)
	}
end

RegisterNetEvent('coe_banking:atmOpen', function()
	local playerId = source
	guarded(playerId, function()
		atmSessions[playerId] = nil
		local inventoryId = inventoryOf(playerId)
		local snapshot = inventoryId and remote('coe_inventory', 'GetInventory', inventoryId) or nil
		local cards = {}
		for _, cardId in ipairs(BankingRules.CardsInInventory(snapshot)) do
			local card = BankingPersistence.Card(cardId)
			if card then
				local business = card.accountType == 'business' and remote('coe_businesses', 'Get', card.accountRef) or nil
				cards[#cards + 1] = {
					id = card.id, last4 = BankingRules.Last4(card.serial), holder = card.holderName, status = BankingRules.Status(card),
					business = type(business) == 'table' and (business.label or business.id) or nil
				}
			end
		end
		if #cards == 0 then
			return 'no_card'
		end
		TriggerClientEvent('coe_banking:open', playerId, { mode = 'atm', step = 'cards', cards = cards, maxAttempts = config.MaxPinAttempts })
	end)
end)

RegisterNetEvent('coe_banking:atmAuth', function(cardId, pin)
	local playerId = source
	guarded(playerId, function()
		local id = BankingRules.CardId(cardId)
		if not id or type(pin) ~= 'string' or not cardInHand(playerId, id) then
			return 'no_card'
		end
		local card = BankingPersistence.Card(id)
		if not card then
			return 'no_card'
		end
		local check = BankingRules.CheckPin(card, pin, config, hashKey)
		if check.already then
			return BankingRules.Status(card) == 'expired' and 'card_expired' or 'card_blocked'
		end
		if not check.ok then
			BankingPersistence.SetAttempts(card.id, check.attempts, check.blocked and 'pin' or nil)
			if check.blocked then
				audit('bank_card_blocked', { character_id = card.accountRef, item = 'card_bank', request_id = tostring(card.id), action = 'pin' })
				TriggerClientEvent('coe_banking:close', playerId)
				notify(playerId, 'error', _t('wrong_pin_blocked'))
				return nil
			end
			TriggerClientEvent('coe_banking:pinError', playerId, config.MaxPinAttempts - check.attempts)
			return nil
		end
		if card.attempts > 0 then
			BankingPersistence.SetAttempts(card.id, 0, nil)
		end
		if card.accountType == 'business' then
			local business, businessError = BankingBusiness.CardUsable(card)
			if not business then
				TriggerClientEvent('coe_banking:close', playerId)
				return businessError
			end
		end
		atmSessions[playerId] = { cardId = card.id, expires = os.time() + config.AtmSessionSeconds }
		TriggerClientEvent('coe_banking:update', playerId, atmView(playerId, card))
	end)
end)

local ATM_ACTIONS = {}

function ATM_ACTIONS.withdraw(playerId, card, data, who)
	if card.accountType == 'business' then
		return BankingBusiness.AtmWithdraw(playerId, card, data, who)
	end
	local amount, amountError = BankingRules.Amount(data.amount, config.MaxAtmAmount)
	if not amount then
		return amountError
	end
	local fee = atmFeeFor(card.accountRef)
	if fee > 0 then
		local balance = balanceOf(card.accountRef)
		if not balance then
			return 'economy_unavailable'
		end
		if balance < amount + fee then
			return 'insufficient_funds'
		end
	end
	local errorCode = withdrawCash(playerId, card.accountRef, amount, 'atm:' .. card.id)
	if errorCode then
		return errorCode
	end
	if fee > 0 and not debit(card.accountRef, fee, 'atm_fee', 'atm:' .. card.id) then
		log('warn', 'banking', 'atm_fee_failed', { character_id = card.accountRef, count = fee })
		fee = 0
	end
	audit('bank_withdraw', { character_id = card.accountRef, target = who and who.characterId or nil, count = amount, action = 'atm' })
	notify(playerId, 'success', fee > 0 and _t('withdraw_fee', { amount = money(amount), fee = money(fee) }) or _t('withdraw_success', { amount = money(amount) }))
end

function ATM_ACTIONS.deposit(playerId, card, data, who)
	if card.accountType == 'business' then
		return BankingBusiness.AtmDeposit(playerId, card, data, who)
	end
	local amount, amountError = BankingRules.Amount(data.amount, config.MaxAtmAmount)
	if not amount then
		return amountError
	end
	local errorCode = depositCash(playerId, card.accountRef, amount, 'atm:' .. card.id)
	if errorCode then
		return errorCode
	end
	audit('bank_deposit', { character_id = card.accountRef, target = who and who.characterId or nil, count = amount, action = 'atm' })
	notify(playerId, 'success', _t('deposit_success', { amount = money(amount) }))
end

function ATM_ACTIONS.refresh()
	return nil
end

RegisterNetEvent('coe_banking:atm', function(action, data)
	local playerId = source
	local handler = type(action) == 'string' and ATM_ACTIONS[action] or nil
	if not handler or type(data) ~= 'table' then
		return
	end
	guarded(playerId, function()
		local session = atmSessions[playerId]
		if not session or session.expires < os.time() then
			atmSessions[playerId] = nil
			TriggerClientEvent('coe_banking:close', playerId)
			return 'session_expired'
		end
		local card = BankingPersistence.Card(session.cardId)
		if not card or BankingRules.Status(card) ~= 'active' or not cardInHand(playerId, card.id) then
			atmSessions[playerId] = nil
			TriggerClientEvent('coe_banking:close', playerId)
			local status = card and BankingRules.Status(card) or nil
			return (status == 'expired' and 'card_expired') or (status and status ~= 'active' and 'card_blocked') or 'no_card'
		end
		if card.accountType == 'business' then
			local business, businessError = BankingBusiness.CardUsable(card)
			if not business then
				atmSessions[playerId] = nil
				TriggerClientEvent('coe_banking:close', playerId)
				return businessError
			end
		end
		session.expires = os.time() + config.AtmSessionSeconds
		local errorCode = handler(playerId, card, data, character(playerId))
		TriggerClientEvent('coe_banking:update', playerId, atmView(playerId, card))
		return errorCode
	end)
end)

RegisterNetEvent('coe_banking:closed', function()
	atmSessions[source] = nil
	agencyOpen[source] = nil
	agencyAccount[source] = nil
end)
