-- Phone NFC / QR Payments & Shop Payment Exports
local Phone = Phone
local config = Phone.config
local payments = Phone.payments
local active = Phone.active
local log = function(...) return Phone.log(...) end
local notify = function(...) return Phone.notify(...) end

local function consumePayment(playerId, token, amount)
	local payment = type(token) == 'string' and payments[token] or nil
	if not payment then
		return nil, 'payment_expired'
	end
	payments[token] = nil
	if payment.playerId ~= tonumber(playerId) or payment.amount ~= math.tointeger(tonumber(amount)) then
		return nil, 'payment_mismatch'
	end
	if os.time() > payment.expires or active[payment.playerId] ~= payment.serial then
		return nil, 'payment_expired'
	end
	return payment.cardId
end

exports('ConsumePayment', function(playerId, token, amount)
	if not config.Wallet.PaymentCallers[GetInvokingResource() or ''] then
		return nil, 'forbidden'
	end
	return consumePayment(playerId, token, amount)
end)

-- Carteira do celular nas lojas (coe_shops:RegisterPaymentMethod, meio `wallet`): o client da loja chama o export
-- RequestPayment deste resource e manda o token; a cobrança consome o token e lança no crédito do cartão escolhido.
exports('ShopCharge', function(playerId, payment, amount, description)
	if not config.Wallet.PaymentCallers[GetInvokingResource() or ''] then
		return { ok = false, error = 'forbidden' }
	end
	local cardId, errorCode = consumePayment(playerId, type(payment) == 'table' and payment.token or nil, amount)
	if not cardId then
		return { ok = false, error = errorCode or 'payment_expired' }
	end
	local ok, result = pcall(function()
		return exports.coe_banking:CardPurchase(cardId, amount, description)
	end)
	if not ok or type(result) ~= 'table' or not result.ok then
		return { ok = false, error = ok and type(result) == 'table' and result.error or 'payment_failed' }
	end
	return { ok = true, ref = cardId }
end)

exports('ShopOptions', function()
	return { detail = 'Paga pelo celular com um cartão da Carteira' }
end)

exports('ShopRefund', function(_, ref, amount, description)
	if not config.Wallet.PaymentCallers[GetInvokingResource() or ''] then
		return { ok = false, error = 'forbidden' }
	end
	local ok, result = pcall(function()
		return exports.coe_banking:CardRefund(ref, amount, description)
	end)
	return ok and result or { ok = false, error = 'payment_failed' }
end)

local function registerShopPayment()
	if GetResourceState('coe_shops') ~= 'started' then
		return
	end
	local ok, result = pcall(function()
		return exports.coe_shops:RegisterPaymentMethod({
			id = 'wallet', label = 'Carteira do celular', kind = 'device', order = 20,
			client = 'RequestPayment', options = 'ShopOptions', charge = 'ShopCharge', refund = 'ShopRefund'
		})
	end)
	if not ok or result ~= true then
		log('warn', 'system', 'phone_shop_payment_failed', { error_code = ok and type(result) == 'table' and tostring(result.error) or 'unavailable' })
	end
end

local upgradeReport = nil

AddEventHandler('onResourceStart', function(resource)
	if resource == 'coe_shops' then
		registerShopPayment()
	end
end)
CreateThread(registerShopPayment)
-- Número (formatado) do primeiro chip de que o personagem é titular; nil se nenhum.