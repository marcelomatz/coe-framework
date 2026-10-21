-- coe_shops (servidor): lojas de conveniência como negócios. Sem dono (da staff): estoque infinito e preço de tabela.
-- Com dono (jogador): vende o que a equipe pôs na prateleira, pelo preço do dono. A receita vai para o caixa do negócio.
local config = ShopsConfig
local catalog = assert(ShopsRules.Catalog(config))

local ready = false
local shelves = {}       -- negócio -> produto -> { quantity, price }
local lastCall = {}      -- playerId -> GetGameTimer()
local playerBusy = {}
local storeBusy = {}

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

local function remote(resource, name, ...)
	if GetResourceState(resource) ~= 'started' then
		return nil
	end
	local args = { ... }
	local ok, result = pcall(function()
		return exports[resource][name](exports[resource], table.unpack(args))
	end)
	if not ok then
		log('warn', 'system', 'shops_remote_failed', { target = resource .. ':' .. name, error_code = tostring(result):sub(1, 96) })
		return nil
	end
	return result
end

local function money(value)
	local textValue = tostring(math.floor(value))
	return '$' .. textValue:reverse():gsub('(%d%d%d)', '%1.'):reverse():gsub('^%.', '')
end

local function characterOf(playerId)
	local snapshot = Core.Players.GetActiveCharacter(playerId)
	if type(snapshot) ~= 'table' or not snapshot.characterId then
		return nil
	end
	return { id = tostring(snapshot.characterId) }
end

local function coordsOf(playerId)
	local ped = GetPlayerPed(playerId)
	if not ped or ped == 0 then
		return nil
	end
	local c = GetEntityCoords(ped)
	return { x = c.x, y = c.y, z = c.z }
end

local function nearCounter(playerId, store)
	local coords = coordsOf(playerId)
	if not coords then
		return false
	end
	local dx, dy, dz = coords.x - store.clerk.x, coords.y - store.clerk.y, coords.z - store.clerk.z
	return math.sqrt(dx * dx + dy * dy) <= config.CounterRadius and math.abs(dz) <= 4.0
end

local function businessOf(storeId)
	local business = remote('coe_businesses', 'Get', storeId)
	return type(business) == 'table' and business.id and business or nil
end

local function inventoryOf(playerId)
	return remote('coe_inventory', 'GetPlayerInventory', playerId)
end

local function countOf(inventoryId, item)
	return tonumber(remote('coe_inventory', 'GetItemCount', inventoryId, item)) or 0
end

-- Nome e imagem do item no catálogo do inventário (para a vitrine).
local itemInfo = {}
local function infoOf(item)
	if itemInfo[item] then
		return itemInfo[item]
	end
	local definition = remote('coe_inventory', 'Items', item)
	local info = {
		label = type(definition) == 'table' and type(definition.label) == 'string' and definition.label or item,
		image = type(definition) == 'table' and type(definition.image) == 'string' and definition.image or (item .. '.png')
	}
	itemInfo[item] = info
	return info
end

-- Acesso de gestão: `work` abastece (dono ou equipe de ponto), `prices` e `stock` pelo cargo, `report` vê as vendas.
local function accessOf(playerId, character, store, business, mode)
	local staffAce = IsPlayerAceAllowed(playerId, config.ManageAce)
	if mode == 'staff' then
		return { report = staffAce, staffView = staffAce }
	end
	local access = remote('coe_businesses', 'Access', store.id, character.id)
	local owner = type(access) == 'table' and access.owner == true
	local work = type(access) == 'table' and access.canWork == true
	local function can(permission)
		return owner or (work and remote('coe_businesses', 'Can', store.id, character.id, permission) == true)
	end
	local prices, stock = can('shops.prices'), can('shops.stock')
	return { work = work or owner, prices = prices, stock = stock, report = owner or prices or stock or staffAce, owner = owner }
end

-- Visão da loja para a vitrine (e a gestão, quando o jogador tem acesso).
local function storeView(playerId, character, store)
	local business = businessOf(store.id)
	if not business or business.enabled == false then
		return nil, 'store_closed'
	end
	local mode = ShopsRules.Mode(business)
	local kind = catalog.types[store.type]
	local own = shelves[store.id] or {}
	local products = {}
	for _, productId in ipairs(kind.products) do
		local product = catalog.products[productId]
		local info = infoOf(product.item)
		local shelf = own[productId]
		local low, high = ShopsRules.PriceBounds(config, product.price)
		products[#products + 1] = {
			id = productId, label = info.label, image = info.image, category = product.category,
			price = ShopsRules.Price(product, mode, shelf), base = product.price, min = low, max = high,
			stock = ShopsRules.Available(mode, shelf)
		}
	end
	local categories = {}
	for _, category in ipairs(config.Categories) do
		categories[#categories + 1] = { id = category.id, label = category.label }
	end
	local inventoryId = inventoryOf(playerId)
	local cards = {}
	if config.Payments.card then
		local result = remote('coe_banking', 'PosCards', playerId)
		cards = type(result) == 'table' and result.ok and result.cards or {}
	end
	return {
		store = { id = store.id, label = store.label, type = store.type, typeLabel = kind.label },
		mode = mode, owner = business.owner and business.owner.name or nil,
		products = products, categories = categories,
		payments = config.Payments, cash = inventoryId and countOf(inventoryId, 'money') or 0, cards = cards,
		limits = { lines = config.Cart.MaxLines, quantity = config.Cart.MaxQuantity, maxStock = config.MaxStock },
		access = accessOf(playerId, character, store, business, mode)
	}
end

-- Pagamento -------------------------------------------------------------------------------------------------

local function refund(playerId, charge, total, description)
	if charge.method == 'cash' then
		local inventoryId = inventoryOf(playerId)
		if not inventoryId or remote('coe_inventory', 'AddItem', inventoryId, 'money', total) ~= true then
			log('error', 'economy', 'shops_refund_failed', { player_id = playerId, count = total, operation = 'cash' })
		end
		return
	end
	local result = remote('coe_banking', 'CardRefund', charge.cardId, total, description)
	if type(result) ~= 'table' or not result.ok then
		log('error', 'economy', 'shops_refund_failed', { player_id = playerId, count = total, operation = charge.method })
	end
end

-- Cobra o total pelo meio escolhido. Devolve { method, cardId? } ou nil + erro (+ detalhe).
local function charge(playerId, payment, total, description)
	local method = type(payment) == 'table' and payment.method
	if not config.Payments[method or ''] then
		return nil, 'invalid_method'
	end
	if method == 'cash' then
		local inventoryId = inventoryOf(playerId)
		if not inventoryId or countOf(inventoryId, 'money') < total then
			return nil, 'insufficient_cash'
		end
		if remote('coe_inventory', 'RemoveItemByName', inventoryId, 'money', total) ~= true then
			return nil, 'payment_failed'
		end
		return { method = 'cash' }
	end
	if method == 'wallet' then
		local cardId = type(payment.token) == 'string' and remote('coe_phone', 'ConsumePayment', playerId, payment.token, total) or nil
		if not cardId then
			return nil, 'payment_expired'
		end
		local result = remote('coe_banking', 'CardPurchase', cardId, total, description)
		if type(result) ~= 'table' or not result.ok then
			return nil, type(result) == 'table' and result.error or 'payment_failed'
		end
		return { method = 'wallet', cardId = cardId }
	end
	local cardId = math.tointeger(tonumber(payment.cardId))
	local result = cardId and remote('coe_banking', 'PosPurchase', playerId, cardId, payment.pin, total, description) or nil
	if type(result) ~= 'table' or not result.ok then
		return nil, type(result) == 'table' and result.error or 'payment_failed', type(result) == 'table' and result.left or nil
	end
	return { method = 'card', cardId = cardId }
end

local function encodeLines(lines)
	local parts = {}
	for _, line in ipairs(lines) do
		parts[#parts + 1] = ('%s:%d:%d'):format(line.id, line.quantity, line.unit)
	end
	return table.concat(parts, ','):sub(1, 2048)
end

local function saveShelves(storeId, own, ids)
	for _, productId in ipairs(ids) do
		if not ShopsPersistence.SaveShelf(storeId, productId, own[productId]) then
			log('error', 'persistence', 'shops_shelf_save_failed', { target = storeId .. ':' .. productId })
		end
	end
end

local function buy(playerId, character, store, cart, payment)
	local business = businessOf(store.id)
	if not business or business.enabled == false then
		return { ok = false, error = 'store_closed' }
	end
	local mode = ShopsRules.Mode(business)
	local quote, quoteError, productId = ShopsRules.Quote(config, catalog, store, cart, { mode = mode, shelves = shelves[store.id] })
	if not quote then
		local product = productId and catalog.products[productId]
		return { ok = false, error = quoteError, product = product and infoOf(product.item).label or nil }
	end
	local inventoryId = inventoryOf(playerId)
	if not inventoryId then
		return { ok = false, error = 'no_inventory' }
	end
	local description = ShopsRules.Description(store, quote.units)
	local paid, payError, left = charge(playerId, payment, quote.total, description)
	if not paid then
		return { ok = false, error = payError, left = left }
	end
	-- Entrega os itens; se algum não couber, desfaz o que entrou e devolve o dinheiro.
	local given = {}
	for _, line in ipairs(quote.lines) do
		if remote('coe_inventory', 'AddItem', inventoryId, line.item, line.quantity) ~= true then
			for _, back in ipairs(given) do
				remote('coe_inventory', 'RemoveItemByName', inventoryId, back.item, back.quantity)
			end
			refund(playerId, paid, quote.total, description)
			return { ok = false, error = 'inventory_full' }
		end
		given[#given + 1] = line
	end
	if mode == 'player' then
		local after = ShopsRules.AfterSale(shelves[store.id], quote.lines)
		shelves[store.id] = after
		local ids = {}
		for _, line in ipairs(quote.lines) do
			ids[#ids + 1] = line.id
		end
		saveShelves(store.id, after, ids)
	end
	local collected = remote('coe_economy', 'SocietyCollect', store.id, quote.total, 'shop_sale')
	if type(collected) == 'table' and collected.error then
		log('error', 'economy', 'shops_collect_failed', { target = store.id, count = quote.total, error_code = tostring(collected.error) })
	end
	ShopsPersistence.RecordSale({
		businessId = store.id, characterId = character.id, mode = mode, method = paid.method, total = quote.total,
		units = quote.units, lines = encodeLines(quote.lines), at = os.time()
	})
	audit('shop_sale', { character_id = character.id, target = store.id, count = quote.total, operation = paid.method })
	notify(playerId, 'success', ('%s: compra de %s concluída.'):format(store.label, money(quote.total)))
	return { ok = true, total = quote.total, units = quote.units }
end

-- Gestão --------------------------------------------------------------------------------------------------

local function sells(store, productId)
	for _, id in ipairs(catalog.types[store.type].products) do
		if id == productId then
			return catalog.products[id]
		end
	end
	return nil
end

local function manage(playerId, character, store, op, args)
	local business = businessOf(store.id)
	if not business then
		return { ok = false, error = 'store_closed' }
	end
	local mode = ShopsRules.Mode(business)
	local access = accessOf(playerId, character, store, business, mode)
	args = type(args) == 'table' and args or {}
	if op == 'report' then
		if not access.report then
			return { ok = false, error = 'forbidden' }
		end
		local now = os.time()
		local report = ShopsPersistence.Report(store.id, config.ReportSales, now - (now % 86400), now - 7 * 86400)
		if not report then
			return { ok = false, error = 'database_error' }
		end
		report.balance = remote('coe_economy', 'SocietyBalance', store.id)
		return { ok = true, report = report }
	end
	if mode ~= 'player' then
		return { ok = false, error = 'staff_store' }
	end
	local product = sells(store, args.productId)
	if not product then
		return { ok = false, error = 'unknown_product' }
	end
	local own = shelves[store.id] or {}
	local shelf = own[product.id] or { quantity = 0 }
	if op == 'price' then
		if not access.prices then
			return { ok = false, error = 'forbidden' }
		end
		local price = nil
		if args.price ~= nil and args.price ~= false and tonumber(args.price) ~= product.price then
			price = ShopsRules.ValidPrice(config, product.price, args.price)
			if not price then
				return { ok = false, error = 'invalid_price' }
			end
		end
		own[product.id] = { quantity = shelf.quantity, price = price }
		shelves[store.id] = own
		if not ShopsPersistence.SaveShelf(store.id, product.id, own[product.id]) then
			return { ok = false, error = 'database_error' }
		end
		audit('shop_price', { character_id = character.id, target = store.id, item = product.id, count = price or product.price })
		return { ok = true }
	end
	local inventoryId = inventoryOf(playerId)
	if not inventoryId then
		return { ok = false, error = 'no_inventory' }
	end
	if op == 'restock' then
		if not access.work then
			return { ok = false, error = 'forbidden' }
		end
		local quantity = ShopsRules.Restock(config, shelf, args.quantity)
		if not quantity then
			return { ok = false, error = select(2, ShopsRules.Restock(config, shelf, args.quantity)) }
		end
		local amount = quantity - shelf.quantity
		if countOf(inventoryId, product.item) < amount or remote('coe_inventory', 'RemoveItemByName', inventoryId, product.item, amount) ~= true then
			return { ok = false, error = 'missing_items' }
		end
		own[product.id] = { quantity = quantity, price = shelf.price }
		shelves[store.id] = own
		if not ShopsPersistence.SaveShelf(store.id, product.id, own[product.id]) then
			own[product.id] = shelf
			remote('coe_inventory', 'AddItem', inventoryId, product.item, amount)
			return { ok = false, error = 'database_error' }
		end
		audit('shop_restock', { character_id = character.id, target = store.id, item = product.id, count = amount })
		return { ok = true }
	end
	if op == 'withdraw' then
		if not access.stock then
			return { ok = false, error = 'forbidden' }
		end
		local quantity, withdrawError = ShopsRules.Withdraw(shelf, args.quantity, config.MaxStock)
		if not quantity then
			return { ok = false, error = withdrawError }
		end
		local amount = shelf.quantity - quantity
		own[product.id] = { quantity = quantity, price = shelf.price }
		shelves[store.id] = own
		if remote('coe_inventory', 'AddItem', inventoryId, product.item, amount) ~= true then
			own[product.id] = shelf
			return { ok = false, error = 'inventory_full' }
		end
		if not ShopsPersistence.SaveShelf(store.id, product.id, own[product.id]) then
			log('error', 'persistence', 'shops_shelf_save_failed', { target = store.id .. ':' .. product.id })
		end
		audit('shop_withdraw', { character_id = character.id, target = store.id, item = product.id, count = amount })
		return { ok = true }
	end
	return { ok = false, error = 'unknown_action' }
end

-- Pedidos do client --------------------------------------------------------------------------------------

local function storeFor(playerId, payload)
	local store = type(payload) == 'table' and type(payload.storeId) == 'string' and catalog.byId[payload.storeId]
	if not store then
		return nil, 'unknown_store'
	end
	if not nearCounter(playerId, store) then
		return nil, 'too_far'
	end
	return store
end

local Actions = {}

function Actions.stores()
	local list = {}
	for _, store in ipairs(catalog.stores) do
		local kind = catalog.types[store.type]
		list[#list + 1] = { id = store.id, label = store.label, type = store.type, clerk = store.clerk, clerkModel = kind.clerk, blip = kind.blip }
	end
	return { ok = true, stores = list }
end

function Actions.open(playerId, character, payload)
	local store, errorCode = storeFor(playerId, payload)
	if not store then
		return { ok = false, error = errorCode }
	end
	local view, viewError = storeView(playerId, character, store)
	if not view then
		return { ok = false, error = viewError }
	end
	return { ok = true, view = view }
end

function Actions.quote(playerId, _, payload)
	local store, errorCode = storeFor(playerId, payload)
	if not store then
		return { ok = false, error = errorCode }
	end
	local business = businessOf(store.id)
	if not business or business.enabled == false then
		return { ok = false, error = 'store_closed' }
	end
	local quote, quoteError = ShopsRules.Quote(config, catalog, store, payload.cart,
		{ mode = ShopsRules.Mode(business), shelves = shelves[store.id] })
	if not quote then
		return { ok = false, error = quoteError }
	end
	return { ok = true, total = quote.total, units = quote.units, label = store.label }
end

function Actions.buy(playerId, character, payload)
	local store, errorCode = storeFor(playerId, payload)
	if not store then
		return { ok = false, error = errorCode }
	end
	if playerBusy[playerId] or storeBusy[store.id] then
		return { ok = false, error = 'busy' }
	end
	playerBusy[playerId], storeBusy[store.id] = true, true
	local ok, result = pcall(buy, playerId, character, store, payload.cart, payload.payment)
	playerBusy[playerId], storeBusy[store.id] = nil, nil
	if not ok then
		log('error', 'gameplay', 'shops_buy_failed', { player_id = playerId, target = store.id, error_code = tostring(result):sub(1, 96) })
		return { ok = false, error = 'internal_error' }
	end
	if result.ok then
		local view = storeView(playerId, character, store)
		result.view = view
	end
	return result
end

function Actions.manage(playerId, character, payload)
	local store, errorCode = storeFor(playerId, payload)
	if not store then
		return { ok = false, error = errorCode }
	end
	if storeBusy[store.id] then
		return { ok = false, error = 'busy' }
	end
	storeBusy[store.id] = true
	local ok, result = pcall(manage, playerId, character, store, payload.op, payload.args)
	storeBusy[store.id] = nil
	if not ok then
		log('error', 'gameplay', 'shops_manage_failed', { player_id = playerId, target = store.id, error_code = tostring(result):sub(1, 96) })
		return { ok = false, error = 'internal_error' }
	end
	if result.ok and payload.op ~= 'report' then
		result.view = storeView(playerId, character, store)
	end
	return result
end

RegisterNetEvent('coe_shops:request', function(requestId, action, payload)
	local playerId = source
	local function answer(result)
		TriggerClientEvent('coe_shops:response', playerId, requestId, result)
	end
	if type(action) ~= 'string' or not rawget(Actions, action) then
		return answer({ ok = false, error = 'unknown_action' })
	end
	if not ready then
		return answer({ ok = false, error = 'not_ready' })
	end
	local now = GetGameTimer()
	if action ~= 'stores' and lastCall[playerId] and now - lastCall[playerId] < config.CallCooldownMs then
		return answer({ ok = false, error = 'busy' })
	end
	lastCall[playerId] = now
	local character = characterOf(playerId)
	if not character and action ~= 'stores' then
		return answer({ ok = false, error = 'no_character' })
	end
	answer(Actions[action](playerId, character, type(payload) == 'table' and payload or {}))
end)

-- Diagnóstico enviado pelo client (lojas e blips montados, balconista criado, erros). Até 12 por jogador.
local clientReports = {}
RegisterNetEvent('coe_shops:clientStatus', function(kind, info)
	local playerId = source
	clientReports[playerId] = (clientReports[playerId] or 0) + 1
	if clientReports[playerId] > 12 or type(kind) ~= 'string' or type(info) ~= 'table' then
		return
	end
	local function text(value)
		return tostring(value):sub(1, 96)
	end
	if kind == 'loaded' then
		log('info', 'system', 'shops_client_loaded', { player_id = playerId, count = tonumber(info.stores) or 0, operation = 'blips=' .. text(info.blips) })
	elseif kind == 'clerk' then
		log('info', 'system', 'shops_client_clerk', { player_id = playerId, target = text(info.store),
			operation = ('interior=%s z=%s exists=%s'):format(text(info.interior), text(info.z), text(info.exists)) })
	elseif kind == 'error' then
		log('warn', 'system', 'shops_client_error', { player_id = playerId, target = text(info.store), error_code = text(info.message) })
	end
end)

AddEventHandler('playerDropped', function()
	lastCall[source], playerBusy[source], clientReports[source] = nil, nil, nil
end)

exports('IsReady', function()
	return ready
end)

-- É loja do coe_shops? (aba Loja do app do negócio no tablet)
exports('IsStore', function(businessId)
	return type(businessId) == 'string' and catalog.byId[businessId] ~= nil
end)

-- Aba Loja do app do negócio (coe_businesses, tablet): prateleira, preços e vendas. Abastecer e retirar mexem no
-- inventário de quem está no balcão e ficam na aba Gestão da vitrine.
local function tabletView(playerId, character, store)
	local business = businessOf(store.id)
	if not business then
		return { ok = false, error = 'store_closed' }
	end
	local mode = ShopsRules.Mode(business)
	local access = accessOf(playerId, character, store, business, mode)
	local kind = catalog.types[store.type]
	local own = shelves[store.id] or {}
	local products = {}
	for _, productId in ipairs(kind.products) do
		local product = catalog.products[productId]
		local info = infoOf(product.item)
		local shelf = own[productId]
		local low, high = ShopsRules.PriceBounds(config, product.price)
		products[#products + 1] = {
			id = productId, label = info.label, image = info.image, category = product.category,
			price = ShopsRules.Price(product, mode, shelf), base = product.price, min = low, max = high,
			custom = mode == 'player' and shelf ~= nil and shelf.price ~= nil, stock = ShopsRules.Available(mode, shelf)
		}
	end
	local result = {
		ok = true, store = { id = store.id, label = store.label, typeLabel = kind.label }, mode = mode,
		owner = business.owner and business.owner.name or nil, products = products, maxStock = config.MaxStock,
		access = { prices = mode == 'player' and access.prices == true, report = access.report == true }
	}
	-- Vendas: dono, cargos da loja e, nas lojas da staff, quem trabalha no negócio (o app já exige vínculo).
	if access.report or mode == 'staff' then
		local now = os.time()
		local report = ShopsPersistence.Report(store.id, config.ReportSales, now - (now % 86400), now - 7 * 86400)
		if report then
			report.balance = remote('coe_economy', 'SocietyBalance', store.id)
			result.report = report
		end
	end
	return result
end

exports('BusinessTablet', function(playerId, characterId, businessId, payload)
	if GetInvokingResource() ~= 'coe_businesses' then
		return { ok = false, error = 'forbidden' }
	end
	if not ready then
		return { ok = false, error = 'not_ready' }
	end
	local store = type(businessId) == 'string' and catalog.byId[businessId]
	if not store then
		return { ok = false, error = 'not_a_store' }
	end
	local character = { id = tostring(characterId) }
	payload = type(payload) == 'table' and payload or {}
	if payload.op == 'overview' or payload.op == nil then
		return tabletView(playerId, character, store)
	end
	if payload.op ~= 'price' then
		return { ok = false, error = 'unknown_action' }
	end
	if storeBusy[store.id] then
		return { ok = false, error = 'busy' }
	end
	storeBusy[store.id] = true
	local ok, result = pcall(manage, playerId, character, store, 'price', { productId = payload.productId, price = payload.price })
	storeBusy[store.id] = nil
	if not ok then
		log('error', 'gameplay', 'shops_manage_failed', { player_id = playerId, target = store.id, error_code = tostring(result):sub(1, 96) })
		return { ok = false, error = 'internal_error' }
	end
	if not result.ok then
		return result
	end
	return tabletView(playerId, character, store)
end)

-- Estoque de uma loja para outros resources (fase 4: carregamentos). nil = loja da staff (infinito).
exports('GetShelves', function(storeId)
	local store = type(storeId) == 'string' and catalog.byId[storeId]
	if not store then
		return nil
	end
	local business = businessOf(store.id)
	if ShopsRules.Mode(business) == 'staff' then
		return nil
	end
	local out = {}
	for productId, shelf in pairs(shelves[store.id] or {}) do
		out[productId] = { quantity = shelf.quantity, price = shelf.price }
	end
	return out
end)

-- Inicialização: banco, permissões de cargo e os negócios das lojas (criados só na primeira vez, sem dono).
CreateThread(function()
	local waitingLogged = false
	while true do
		local initialized, errorCode = ShopsPersistence.Initialize()
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
			-- Ex.: coe_database ainda sem o coe_shops na lista de chamadores (reinicie o coe_database). Tenta de novo.
			log('error', 'persistence', 'shops_migrations_failed', { error_code = tostring(errorCode) })
			Wait(15000)
		end
	end
	local loaded = ShopsPersistence.Shelves()
	while not loaded do
		log('error', 'persistence', 'shops_load_failed', {})
		Wait(15000)
		loaded = ShopsPersistence.Shelves()
	end
	shelves = loaded
	local deadline = GetGameTimer() + 120000
	while remote('coe_businesses', 'IsReady') ~= true and GetGameTimer() < deadline do
		Wait(1000)
	end
	remote('coe_businesses', 'RegisterPermissions', {
		{ name = 'shops.prices', label = 'Loja: definir preços' },
		{ name = 'shops.stock', label = 'Loja: retirar estoque da prateleira' }
	})
	for _, store in ipairs(catalog.stores) do
		local result = remote('coe_businesses', 'Seed', ShopsRules.BusinessSeed(catalog, store))
		if type(result) == 'table' and result.error then
			log('warn', 'system', 'shops_seed_failed', { target = store.id, error_code = tostring(result.error) })
		end
	end
	ready = true
	log('info', 'system', 'shops_ready', { count = #catalog.stores })
end)
