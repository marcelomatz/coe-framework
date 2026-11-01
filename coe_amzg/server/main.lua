local config = AmzgConfig

local ready = false
local products = {}
local productsById = {}
local locks = {}
local watching = {}
local lastRequest = {}

local HOSTS = { coe_tablet = 'tablet', coe_phone = 'phone' }
local STASH_PREFIX = 'stash:amzg:'

local function log(level, category, event, context)
	pcall(function()
		return exports.coe_logging:Log(level, category, event, context)
	end)
end

local function audit(event, context)
	pcall(function()
		return exports.coe_audit:Record('info', 'audit', event, context)
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

local function characterOf(playerId)
	local snapshot = Core.Players.GetActiveCharacter(playerId)
	if type(snapshot) ~= 'table' or not snapshot.characterId then
		return nil
	end
	return { id = tostring(snapshot.characterId) }
end

local function playerOf(characterId)
	for _, id in ipairs(GetPlayers()) do
		local playerId = tonumber(id)
		local current = Core.Players.GetActiveCharacterId(playerId)
		if current and tostring(current) == characterId then
			return playerId
		end
	end
	return nil
end

local function throttled(playerId)
	local now = GetGameTimer()
	if lastRequest[playerId] and now - lastRequest[playerId] < 500 then
		return true
	end
	lastRequest[playerId] = now
	return false
end

local function withLock(characterId, run)
	if locks[characterId] then
		return { ok = false, error = 'busy' }
	end
	locks[characterId] = true
	local ok, result = pcall(run)
	locks[characterId] = nil
	if not ok then
		log('error', 'gameplay', 'amzg_lock_failed', { error_code = tostring(result) })
		return { ok = false, error = 'database_error' }
	end
	return result
end

local function housing(name, ...)
	if GetResourceState('coe_housing') ~= 'started' then
		return nil
	end
	local arguments = table.pack(...)
	local ok, result = pcall(function()
		return exports.coe_housing[name](exports.coe_housing, table.unpack(arguments, 1, arguments.n))
	end)
	return ok and result or nil
end

local function itemDefinition(name)
	local ok, definition = pcall(function()
		return exports.coe_inventory:Items(name)
	end)
	return ok and type(definition) == 'table' and definition or nil
end

local function inventory(name, ...)
	local arguments = table.pack(...)
	local ok, first, second = pcall(function()
		return exports.coe_inventory[name](exports.coe_inventory, table.unpack(arguments, 1, arguments.n))
	end)
	if not ok then
		return nil, 'inventory_unavailable'
	end
	return first, second
end

local function loadProducts()
	local list = AmzgPersistence.Products()
	if not list then
		return false
	end
	products = list
	productsById = {}
	for _, product in ipairs(list) do
		productsById[product.id] = product
	end
	return true
end

-- Cartão ----------------------------------------------------------------------------------------------

local function chargeCard(cardId, amount, description)
	if GetResourceState('coe_banking') ~= 'started' then
		return nil, 'bank_unavailable'
	end
	local ok, result = pcall(function()
		return exports.coe_banking:CardPurchase(cardId, amount, description)
	end)
	if not ok or type(result) ~= 'table' then
		return nil, 'bank_unavailable'
	end
	if not result.ok then
		return nil, result.error or 'bank_unavailable'
	end
	return true
end

local function refundCard(cardId, amount, description)
	local ok, result = pcall(function()
		return exports.coe_banking:CardRefund(cardId, amount, description)
	end)
	if not ok or type(result) ~= 'table' or not result.ok then
		log('error', 'gameplay', 'amzg_refund_failed', { request_id = tostring(cardId), count = amount })
		return false
	end
	return true
end

-- Caixas ----------------------------------------------------------------------------------------------

local function stashId(orderId)
	return STASH_PREFIX .. orderId
end

local function boxesOf(space)
	local list = AmzgPersistence.DeliveredInSpace(space.propertyId, space.owner)
	if not list then
		return nil
	end
	local boxes = {}
	for index, order in ipairs(list) do
		local x, y, z = AmzgRules.BoxPosition(config.Box, space.interior, index)
		boxes[#boxes + 1] = { id = order.id, x = x, y = y, z = z, characterId = order.characterId }
	end
	return boxes
end

local function clientBoxes(boxes)
	local list = {}
	for _, box in ipairs(boxes or {}) do
		list[#list + 1] = { id = box.id, x = box.x, y = box.y, z = box.z }
	end
	return list
end

local function sendBoxes(playerId)
	local space = housing('CurrentSpace', playerId)
	if not space then
		TriggerClientEvent('coe_amzg:boxes', playerId, {})
		return
	end
	TriggerClientEvent('coe_amzg:boxes', playerId, clientBoxes(boxesOf(space)))
end

local function refreshSpace(propertyId, owner)
	for _, playerId in ipairs(housing('PlayersInSpace', propertyId, owner) or {}) do
		sendBoxes(playerId)
	end
end

local function isEmpty(id)
	local snapshot = inventory('GetInventory', id)
	if type(snapshot) ~= 'table' then
		return nil
	end
	for _, item in pairs(snapshot.items or {}) do
		if type(item) == 'table' then
			return false
		end
	end
	return true
end

-- Caixa vazia some na hora; o conteúdo só é apagado depois do prazo (quem devolveu itens a vê voltar).
local function collect(order)
	if not AmzgPersistence.Transition(order.id, 'delivered', 'collected') then
		return
	end
	refreshSpace(order.propertyId, order.owner)
	SetTimeout(config.Box.CollectDelaySeconds * 1000, function()
		local empty = isEmpty(stashId(order.id))
		if empty == false then
			if AmzgPersistence.Transition(order.id, 'collected', 'delivered') then
				refreshSpace(order.propertyId, order.owner)
			end
			return
		end
		if empty then
			inventory('DeleteInventory', stashId(order.id))
		end
	end)
end

local function watch(order)
	if watching[order.id] then
		return
	end
	watching[order.id] = true
	CreateThread(function()
		local deadline = GetGameTimer() + config.Box.WatchSeconds * 1000
		while GetGameTimer() < deadline do
			Wait(1000)
			if isEmpty(stashId(order.id)) then
				collect(order)
				break
			end
		end
		watching[order.id] = nil
	end)
end

-- Entrega ---------------------------------------------------------------------------------------------

local function refundOrder(order, reason)
	if not AmzgPersistence.Transition(order.id, 'pending', 'refunded') then
		return
	end
	refundCard(order.cardId, order.total, _t('refund_desc', { id = order.id }))
	audit('amzg_order_refunded', { character_id = order.characterId, operation = tostring(order.id), count = order.total, error_code = reason })
	local playerId = playerOf(order.characterId)
	if playerId then
		notify(playerId, 'warning', _t('order_undelivered_refund', { id = order.id, address = order.addressLabel }))
	end
end

local function fill(id, items)
	for _, line in ipairs(items) do
		local definition = itemDefinition(line.item)
		local quantity = math.tointeger(tonumber(line.qty))
		if not definition or not quantity or quantity < 1 then
			return false, 'invalid_item'
		end
		for _, count in ipairs(AmzgRules.Stacks(definition.maxStack, quantity)) do
			local added, addError = inventory('AddItem', id, line.item, count)
			if not added then
				return false, addError or 'add_failed'
			end
		end
	end
	return true
end

local function deliver(order)
	if not housing('AddressActive', order.propertyId, order.owner) then
		return refundOrder(order, 'address_inactive')
	end
	local id = stashId(order.id)
	-- Sobra de uma entrega interrompida: recomeça a caixa do zero.
	local created, createError = inventory('CreateInventory', id, config.Cart.MaxSlots)
	if not created and createError == 'already_exists' then
		inventory('DeleteInventory', id)
		created, createError = inventory('CreateInventory', id, config.Cart.MaxSlots)
	end
	if not created then
		log('error', 'gameplay', 'amzg_box_failed', { operation = tostring(order.id), error_code = tostring(createError) })
		return
	end
	local filled, fillError = fill(id, order.items)
	if not filled then
		inventory('DeleteInventory', id)
		return refundOrder(order, fillError)
	end
	if not AmzgPersistence.Transition(order.id, 'pending', 'delivered', os.time()) then
		inventory('DeleteInventory', id)
		return
	end
	refreshSpace(order.propertyId, order.owner)
	local playerId = playerOf(order.characterId)
	if playerId then
		notify(playerId, 'success', _t('order_delivered', { id = order.id, address = order.addressLabel }))
	end
end

local function deliverDue()
	local due = AmzgPersistence.DueOrders(os.time(), 20)
	for _, order in ipairs(due or {}) do
		local ok, failure = pcall(deliver, order)
		if not ok then
			log('error', 'gameplay', 'amzg_delivery_failed', { operation = tostring(order.id), error_code = tostring(failure) })
		end
	end
end

-- App -------------------------------------------------------------------------------------------------

local App = {}

function App.catalog()
	local list = {}
	local now = os.time()
	for _, product in ipairs(products) do
		local definition = product.active and itemDefinition(product.item)
		if definition then
			local promo = AmzgRules.PromoActive(product, now)
			list[#list + 1] = {
				id = product.id, item = product.item, label = product.label, category = product.category,
				-- price: o que se paga agora; listPrice (só em promoção): o preço cheio, para o "De ... por ...".
				price = AmzgRules.UnitPrice(product, now), listPrice = promo and product.price or nil,
				discount = promo and AmzgRules.Discount(product.price, product.promoPrice) or nil,
				promoUntil = promo and product.promoUntil > 0 and product.promoUntil or nil,
				featured = promo and product.featured or nil, bannerText = promo and product.bannerText ~= '' and product.bannerText or nil,
				image = definition.image, maxStack = definition.maxStack
			}
		end
	end
	local shipping = {}
	for _, option in ipairs(config.Shipping) do
		shipping[#shipping + 1] = { id = option.id, label = option.label, minutes = option.minutes, fee = option.fee }
	end
	return {
		ok = true, categories = config.Categories, shipping = shipping, products = list, limits = config.Cart, now = now,
		promo = { rotateSeconds = config.Promo.RotateSeconds, inlineEvery = config.Promo.InlineEvery }
	}
end

function App.addresses(playerId)
	local list = {}
	for _, address in ipairs(housing('DeliveryAddresses', playerId) or {}) do
		list[#list + 1] = {
			property = address.propertyId, owner = address.owner, label = address.label,
			kind = address.kindLabel, detail = address.detail, x = address.x, y = address.y
		}
	end
	return { ok = true, addresses = list }
end

local function findAddress(playerId, propertyId, owner)
	if type(propertyId) ~= 'string' or type(owner) ~= 'string' then
		return nil
	end
	for _, address in ipairs(housing('DeliveryAddresses', playerId) or {}) do
		if address.propertyId == propertyId and address.owner == owner then
			return address
		end
	end
	return nil
end

function App.checkout(playerId, character, payload, device)
	if device ~= 'phone' or GetResourceState('coe_phone') ~= 'started' then
		return { ok = false, error = 'wallet_required' }
	end
	return withLock(character.id, function()
		local address = findAddress(playerId, payload.property, payload.owner)
		if not address then
			return { ok = false, error = 'invalid_address' }
		end
		local definitions = {}
		for _, entry in ipairs(type(payload.cart) == 'table' and payload.cart or {}) do
			local product = type(entry) == 'table' and productsById[math.tointeger(tonumber(entry.id)) or 0]
			if product and not definitions[product.item] then
				definitions[product.item] = itemDefinition(product.item)
			end
		end
		local priced, priceError = AmzgRules.Checkout(config, payload.cart, productsById, definitions, payload.shipping, os.time())
		if not priced then
			return { ok = false, error = priceError }
		end
		if type(payload.total) == 'number' and payload.total ~= priced.total then
			return { ok = false, error = 'price_changed' }
		end
		local pending = AmzgPersistence.PendingCount(character.id)
		if not pending then
			return { ok = false, error = 'database_error' }
		end
		if pending >= config.Orders.MaxPending then
			return { ok = false, error = 'too_many_orders' }
		end
		local consumed, outcome = pcall(function()
			return table.pack(exports.coe_phone:ConsumePayment(playerId, payload.payment, priced.total))
		end)
		if not consumed or type(outcome) ~= 'table' then
			return { ok = false, error = 'wallet_required' }
		end
		local cardId = math.tointeger(tonumber(outcome[1]))
		if not cardId then
			return { ok = false, error = outcome[2] or 'payment_expired' }
		end
		local charged, chargeError = chargeCard(cardId, priced.total, 'Compra Amzg')
		if not charged then
			return { ok = false, error = chargeError }
		end
		local now = os.time()
		local order = {
			characterId = character.id, propertyId = address.propertyId, owner = address.owner,
			addressLabel = tostring(address.label):sub(1, 96), items = AmzgRules.Summary(priced.lines),
			total = priced.total, fee = priced.fee, shipping = priced.shipping.id, cardId = cardId,
			createdAt = now, deliverAt = now + priced.shipping.minutes * 60
		}
		local orderId = AmzgPersistence.InsertOrder(order)
		if not orderId then
			refundCard(cardId, priced.total, 'Estorno Compra Amzg')
			return { ok = false, error = 'database_error' }
		end
		audit('amzg_order_placed', { source = playerId, character_id = character.id, operation = tostring(orderId), count = priced.total, target = address.propertyId })
		return { ok = true, order = orderId, total = priced.total, deliverAt = order.deliverAt, now = now }
	end)
end

function App.orders(_, character)
	local list = AmzgPersistence.CharacterOrders(character.id, config.Orders.History)
	if not list then
		return { ok = false, error = 'database_error' }
	end
	local orders = {}
	for _, order in ipairs(list) do
		local shipping = AmzgRules.Shipping(config, order.shipping)
		orders[#orders + 1] = {
			id = order.id, address = order.addressLabel, items = order.items, total = order.total, fee = order.fee,
			shipping = shipping and shipping.label or order.shipping, status = order.status,
			createdAt = order.createdAt, deliverAt = order.deliverAt, deliveredAt = order.deliveredAt
		}
	end
	return { ok = true, orders = orders, now = os.time() }
end

-- Exports para o tablet e o smartphone ----------------------------------------------------------------

local function installed(playerId, device)
	if GetResourceState('coe_apps') ~= 'started' then
		return false
	end
	local ok, result = pcall(function()
		return exports.coe_apps:HasApp(playerId, 'amzg', device)
	end)
	return ok and result == true
end

exports('TabletVisible', function(playerId, appId)
	local device = HOSTS[GetInvokingResource()]
	return device ~= nil and ready and appId == 'amzg' and installed(playerId, device)
end)

exports('TabletCall', function(playerId, appId, action, payload)
	local device = HOSTS[GetInvokingResource()]
	if not device then
		return { ok = false, error = 'forbidden' }
	end
	if not ready then
		return { ok = false, error = 'not_ready' }
	end
	local character = characterOf(playerId)
	if not character then
		return { ok = false, error = 'no_character' }
	end
	local handler = appId == 'amzg' and type(action) == 'string' and rawget(App, action)
	if type(handler) ~= 'function' then
		return { ok = false, error = 'unknown_action' }
	end
	if not installed(playerId, device) then
		return { ok = false, error = 'not_installed' }
	end
	return handler(playerId, character, type(payload) == 'table' and payload or {}, device)
end)

-- Caixas no imóvel ------------------------------------------------------------------------------------

RegisterNetEvent('coe_amzg:requestBoxes', function()
	local playerId = source
	if not ready or throttled(playerId) then
		return
	end
	sendBoxes(playerId)
end)

RegisterNetEvent('coe_amzg:openBox', function(orderId)
	local playerId = source
	orderId = math.tointeger(tonumber(orderId))
	if not ready or not orderId or throttled(playerId) then
		return
	end
	local space = housing('CurrentSpace', playerId)
	local boxes = space and boxesOf(space)
	local box
	for _, candidate in ipairs(boxes or {}) do
		if candidate.id == orderId then
			box = candidate
			break
		end
	end
	if not box then
		notify(playerId, 'error', _t('box_not_found'))
		sendBoxes(playerId)
		return
	end
	local ped = GetPlayerPed(playerId)
	local at = ped and ped > 0 and GetEntityCoords(ped)
	if not at or #(vector2(at.x, at.y) - vector2(box.x, box.y)) > config.Box.Reach or math.abs(at.z - box.z) > 3.0 then
		notify(playerId, 'error', _t('box_too_far'))
		return
	end
	local id = stashId(orderId)
	if isEmpty(id) then
		collect({ id = orderId, propertyId = space.propertyId, owner = space.owner })
		return
	end
	local ok, opened = pcall(function()
		return exports.coe_inventory:OpenStash(playerId, id, {
			label = _t('box_label', { id = orderId }), slots = config.Cart.MaxSlots,
			position = { x = at.x, y = at.y, z = at.z }, radius = config.Box.Reach + 1.0
		})
	end)
	if not ok or opened ~= true then
		notify(playerId, 'error', _t('box_open_failed'))
		return
	end
	watch({ id = orderId, propertyId = space.propertyId, owner = space.owner })
end)

AddEventHandler('playerDropped', function()
	lastRequest[source] = nil
end)

-- Painel admin ----------------------------------------------------------------------------------------

local function adminCaller()
	return config.AdminCallers[GetInvokingResource() or ''] == true
end

exports('AdminCatalog', function()
	if not adminCaller() then
		return nil
	end
	local list = {}
	for _, product in ipairs(products) do
		local definition = itemDefinition(product.item)
		list[#list + 1] = {
			id = product.id, item = product.item, label = product.label, category = product.category, price = product.price,
			active = product.active, sort = product.sort, itemLabel = definition and definition.label or nil, missing = definition == nil,
			promoPrice = product.promoPrice, promoUntil = product.promoUntil, featured = product.featured, bannerText = product.bannerText,
			promoActive = AmzgRules.PromoActive(product, os.time())
		}
	end
	return {
		available = ready, categories = config.Categories, products = list, max = config.Products.Max, priceMax = config.Products.PriceMax,
		bannerTextMax = config.Promo.BannerTextMax, now = os.time()
	}
end)

exports('AdminSaveProduct', function(input)
	if not adminCaller() then
		return { ok = false, error = 'forbidden' }
	end
	if not ready then
		return { ok = false, error = 'not_ready' }
	end
	local product, errorCode = AmzgRules.Product(config, input, type(input) == 'table' and type(input.item) == 'string' and itemDefinition(input.item) or nil, os.time())
	if not product then
		return { ok = false, error = errorCode }
	end
	local id = type(input.id) ~= 'nil' and math.tointeger(tonumber(input.id)) or nil
	if id then
		if not productsById[id] then
			return { ok = false, error = 'unknown_product' }
		end
		if not AmzgPersistence.UpdateProduct(id, product) then
			return { ok = false, error = 'database_error' }
		end
	else
		if #products >= config.Products.Max then
			return { ok = false, error = 'product_limit' }
		end
		id = AmzgPersistence.InsertProduct(product)
		if not id then
			return { ok = false, error = 'database_error' }
		end
	end
	loadProducts()
	audit('amzg_product_saved', { operation = tostring(id), item = product.item, count = product.price })
	return { ok = true, id = id }
end)

exports('AdminDeleteProduct', function(input)
	if not adminCaller() then
		return { ok = false, error = 'forbidden' }
	end
	if not ready then
		return { ok = false, error = 'not_ready' }
	end
	local id = math.tointeger(tonumber(type(input) == 'table' and input.id or input))
	if not id or not productsById[id] then
		return { ok = false, error = 'unknown_product' }
	end
	if not AmzgPersistence.DeleteProduct(id) then
		return { ok = false, error = 'database_error' }
	end
	loadProducts()
	audit('amzg_product_deleted', { operation = tostring(id) })
	return { ok = true }
end)

CreateThread(function()
	local waitingLogged = false
	while true do
		local initialized, errorCode = AmzgPersistence.Initialize()
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
	while not loadProducts() do
		Wait(5000)
	end
	ready = true
	log('info', 'system', 'amzg_ready', { count = #products })
	-- Quem já estava num imóvel quando o resource (re)iniciou recebe as caixas.
	for _, id in ipairs(GetPlayers()) do
		sendBoxes(tonumber(id))
	end
	while true do
		deliverDue()
		Wait(config.DeliveryTickSeconds * 1000)
	end
end)
