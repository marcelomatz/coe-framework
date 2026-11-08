-- Deep Market (deepmarket.onion): anúncios de fornecedores NPC (admin) e de jogadores, pagos em cripto com custódia
-- (coe_crypto: EscrowLock/EscrowRelease). Itens são entregues num ponto de coleta (dead drop): o vendedor deixa,
-- o comprador busca. Serviços: o vendedor marca como feito; o comprador confirma ou contesta (a staff decide).
local config = DeepwebConfig
local market = config.Market
local App = DeepwebApp
local S = DeepwebServer
DeepwebMarket = {}

local FINAL = { completed = true, released = true, cancelled = true, refunded = true }

local function fail(code, extra)
	local result = extra or {}
	result.ok = false
	result.error = code
	return result
end

local function signedIn(context)
	local session = DeepwebPersistence.Session(context.key)
	if session == nil then
		return nil, 'database_error'
	end
	if not session then
		return nil, 'not_signed_in'
	end
	return session
end

local function format(units)
	return S.Call('coe_crypto', 'Format', units) or tostring(units)
end

local function cryptoReady()
	return GetResourceState('coe_crypto') == 'started' and S.Call('coe_crypto', 'IsReady') == true
end

local function level(context)
	return config.Tiers[context.kind].level
end

local function categories()
	local list = {}
	for _, category in ipairs(market.Categories) do
		list[#list + 1] = { id = category.id, label = category.label }
	end
	return list
end

local function itemLabel(name)
	if name == '' then
		return nil
	end
	local items = S.Call('coe_inventory', 'Items')
	local entry = type(items) == 'table' and items[name]
	return type(entry) == 'table' and entry.label or name
end

local function listingView(listing, session)
	return {
		id = listing.id, kind = listing.kind, category = listing.category, title = listing.title, description = listing.description,
		item = listing.item ~= '' and listing.item or nil, itemLabel = itemLabel(listing.item), count = listing.count,
		price = listing.price, priceText = format(listing.price), stock = listing.stock, sold = listing.sold, status = listing.status,
		npc = listing.sellerHandle == nil, seller = listing.seller or listing.vendor, reputation = listing.sellerHandle and listing.reputation or nil,
		mine = session ~= nil and listing.sellerHandle == session.id, updatedAt = listing.updatedAt
	}
end

local function dropOf(index)
	local spot = market.Drops[index]
	return spot and { x = spot.x, y = spot.y, z = spot.z, label = spot.label } or nil
end

-- O jogador está no ponto de coleta do pedido? Distância horizontal + tolerância de altura (coordenadas provisórias).
local function atDrop(context, order)
	local spot = market.Drops[order.dropIndex]
	local coords = S.PlayerCoords(context.playerId)
	return spot ~= nil and coords ~= nil
		and DeepwebRules.AtSpot(spot, coords.x, coords.y, coords.z, market.DropDistance, market.DropHeight or 4.0)
end

-- Pontos armados pelo site: orderId -> { playerId, character, handle, action, expires }. A ação (deixar/coletar)
-- acontece pelo alvo (coetarget) no local, num evento de rede validado aqui.
local tickets = {}

local function dropTask(order, action)
	local spot = dropOf(order.dropIndex)
	if not spot then
		return nil
	end
	spot.orderId, spot.action, spot.title = order.id, action, order.title
	return spot
end

local function alertAt(context)
	local alert = market.Alert
	if not alert or (alert.Chance or 0) <= 0 or math.random() >= alert.Chance then
		return
	end
	local coords = S.PlayerCoords(context.playerId)
	if coords then
		S.Call('coe_dispatch', 'Alert', alert.Code, coords.x, coords.y, coords.z)
	end
end

local function _t(k, p)
	return (S and S.T and S.T(k, p)) or k
end

-- Aviso no aparelho de quem está online (vendedor ou comprador), sem dizer quem é a outra parte.
local function notifyHandle(handleId, message)
	S.NotifyHandle(handleId, message)
end

-- Custódia -> quem deve receber no estado final. Marca `settled` só depois do pagamento principal.
local function settle(order)
	local to = DeepwebRules.Settlement(order.status)
	if not to or order.settled then
		return true
	end
	if to == 'buyer' then
		local result = S.Call('coe_crypto', 'EscrowRelease', order.buyerAddress, order.total, 'deep market #' .. order.id .. ' estorno')
		if type(result) ~= 'table' or not result.ok then
			S.Log('warn', 'gameplay', 'deepweb_settlement_failed', { target = 'order:' .. order.id, result = 'refund' })
			return false
		end
	else
		local net = order.total - order.fee
		if net > 0 then
			local result = S.Call('coe_crypto', 'EscrowRelease', order.payout, net, 'deep market #' .. order.id)
			if type(result) ~= 'table' or not result.ok then
				S.Log('warn', 'gameplay', 'deepweb_settlement_failed', { target = 'order:' .. order.id, result = 'payout' })
				return false
			end
		end
		if order.fee > 0 then
			local reserve = S.Call('coe_crypto', 'ReserveAddress')
			local result = reserve and S.Call('coe_crypto', 'EscrowRelease', reserve, order.fee, 'deep market #' .. order.id .. ' taxa')
			if type(result) ~= 'table' or not result.ok then
				S.Log('warn', 'gameplay', 'deepweb_fee_failed', { target = 'order:' .. order.id })
			end
		end
	end
	DeepwebPersistence.MarkSettled(order.id)
	order.settled = true
	return true
end

-- Troca o estado (só se ninguém trocou antes) e paga a custódia se for final.
local function move(order, to, fields, now)
	local moved = DeepwebPersistence.MoveOrder(order.id, order.status, to, fields, now)
	if moved == nil then
		return nil, 'database_error'
	end
	if not moved then
		return nil, 'invalid_status'
	end
	order.status = to
	if FINAL[to] then
		if to == 'cancelled' or to == 'refunded' then
			DeepwebPersistence.ReturnStock(order.listingId, order.quantity)
		end
		settle(order)
	end
	return true
end

-- Vitrine ---------------------------------------------------------------------------------------------

function App.marketHome(context, payload)
	local denied = S.RequireFeature(context, 'market_browse')
	if denied then
		return fail(denied)
	end
	local pageNumber = math.max(1, math.min(math.tointeger(tonumber(payload.page)) or 1, 50))
	local category = DeepwebRules.Category(config, payload.category) and payload.category or nil
	local _, pattern = DeepwebRules.SearchTerm(payload.q)
	local list = DeepwebPersistence.Listings({
		category = category, pattern = pattern, npc = payload.npc == true or nil, offset = (pageNumber - 1) * market.PageSize, limit = market.PageSize + 1
	})
	if not list then
		return fail('database_error')
	end
	local more = #list > market.PageSize
	if more then
		list[#list] = nil
	end
	local session = DeepwebPersistence.Session(context.key) or nil
	local listings = {}
	for _, listing in ipairs(list) do
		listings[#listings + 1] = listingView(listing, session)
	end
	return {
		ok = true, listings = listings, categories = categories(), category = category, page = pageNumber, more = more,
		me = session and session.handle or nil, canBuy = DeepwebRules.Allows(config, level(context), 'market_buy'),
		canSell = DeepwebRules.Allows(config, level(context), 'market_sell'), feeBps = market.FeeBps
	}
end

-- Carteiras com chave à mão neste aparelho (para escolher de onde pagar).
local function wallets(context)
	local list = S.Call('coe_crypto', 'HeldWallets', context.playerId, context.key)
	if type(list) ~= 'table' then
		return {}
	end
	for _, wallet in ipairs(list) do
		wallet.balanceText = format(wallet.balance)
	end
	return list
end

function App.marketListing(context, payload)
	local denied = S.RequireFeature(context, 'market_browse')
	if denied then
		return fail(denied)
	end
	local id = math.tointeger(tonumber(payload.id))
	local listing = id and DeepwebPersistence.ListingById(id)
	if listing == nil then
		return fail('database_error')
	end
	if not listing or listing.status == 'removed' then
		return fail('not_found')
	end
	local session = DeepwebPersistence.Session(context.key) or nil
	local view = listingView(listing, session)
	if listing.status ~= 'active' and not view.mine then
		return fail('not_found')
	end
	local reviews = listing.sellerHandle and DeepwebPersistence.SellerReviews(listing.sellerHandle, 5) or nil
	local canBuy = DeepwebRules.Allows(config, level(context), 'market_buy')
	return {
		ok = true, listing = view, reviews = reviews, canBuy = canBuy, me = session and session.handle or nil,
		wallets = canBuy and session and wallets(context) or {}, maxQuantity = math.min(market.MaxQuantity, listing.stock),
		feeBps = market.FeeBps, deliverHours = market.DeliverHours, autoReleaseHours = market.AutoReleaseHours
	}
end

-- Compra ----------------------------------------------------------------------------------------------

function App.marketBuy(context, payload)
	local denied = S.RequireFeature(context, 'market_buy')
	if denied then
		return fail(denied)
	end
	local session, errorCode = signedIn(context)
	if not session then
		return fail(errorCode)
	end
	if not cryptoReady() then
		return fail('crypto_unavailable')
	end
	local id = math.tointeger(tonumber(payload.id))
	local quantity = math.tointeger(tonumber(payload.quantity)) or 1
	if not id then
		return fail('not_found')
	end
	if quantity < 1 or quantity > market.MaxQuantity then
		return fail('invalid_quantity')
	end
	if type(payload.from) ~= 'string' or S.Call('coe_crypto', 'IsAddress', payload.from) ~= true then
		return fail('invalid_address')
	end
	return S.WithLock('listing:' .. id, function()
		local listing = DeepwebPersistence.ListingById(id)
		if not listing or listing.status ~= 'active' then
			return fail(listing == nil and 'database_error' or 'not_found')
		end
		if listing.sellerHandle then
			if listing.sellerHandle == session.id then
				return fail('own_listing')
			end
			local seller = DeepwebPersistence.HandleById(listing.sellerHandle)
			if seller and seller.owner == context.character then
				return fail('own_listing')
			end
		end
		if listing.stock < quantity then
			return fail('out_of_stock')
		end
		local total = listing.price * quantity
		local npc = listing.sellerHandle == nil
		local payout = npc and S.Call('coe_crypto', 'ReserveAddress') or listing.payout
		if type(payout) ~= 'string' or payout == '' then
			return fail('seller_unavailable')
		end
		local now = os.time()
		local dropIndex = listing.kind == 'item' and math.random(#market.Drops) or 0
		-- Fornecedor NPC: a mercadoria já está no ponto. Jogador: espera o vendedor deixar.
		local status = (npc and listing.kind == 'item') and 'dropped' or 'paid'
		local orderId = nil
		local sagaOk, sagaErr = DeepwebRules.ExecuteSaga({
			{
				name = 'take_stock',
				forward = function()
					local taken = DeepwebPersistence.TakeStock(id, quantity)
					if not taken then
						return false, taken == nil and 'database_error' or 'out_of_stock'
					end
					return true
				end,
				compensate = function()
					DeepwebPersistence.ReturnStock(id, quantity)
				end
			},
			{
				name = 'escrow_lock',
				forward = function()
					local locked = S.Call('coe_crypto', 'EscrowLock', context.playerId, context.key, payload.from, total, 'deep market: ' .. listing.title)
					if type(locked) ~= 'table' or not locked.ok then
						return false, type(locked) == 'table' and locked.error or 'crypto_unavailable'
					end
					return true
				end,
				compensate = function()
					S.Call('coe_crypto', 'EscrowRelease', payload.from, total, 'deep market: estorno')
				end
			},
			{
				name = 'insert_order',
				forward = function()
					orderId = DeepwebPersistence.InsertOrder({
						listingId = id, kind = listing.kind, title = listing.title, sellerHandle = listing.sellerHandle, vendor = listing.vendor,
						buyerHandle = session.id, buyerCharacter = context.character, item = listing.item, count = listing.count * quantity,
						quantity = quantity, total = total, fee = npc and 0 or DeepwebRules.Fee(total, market.FeeBps), buyerAddress = payload.from,
						payout = payout, dropIndex = dropIndex, status = status, deliveredAt = status == 'dropped' and now or 0
					}, now)
					if not orderId then
						return false, 'database_error'
					end
					return true
				end
			}
		}, {})
		if not sagaOk then
			return fail(sagaErr or 'database_error')
		end
		S.Audit('deepweb_market_order', { character_id = context.character, target = 'order:' .. orderId, count = total })
		if not npc then
			notifyHandle(listing.sellerHandle, _t('market_order_new', { id = orderId, title = listing.title }))
		end
		return { ok = true, orderId = orderId, status = status }
	end)
end

-- Painel do usuário: anúncios, compras e vendas --------------------------------------------------------

local function orderView(order, role, context)
	local view = {
		id = order.id, listingId = order.listingId, kind = order.kind, title = order.title, status = order.status, role = role,
		quantity = order.quantity, count = order.count, itemLabel = itemLabel(order.item), total = order.total, totalText = format(order.total),
		fee = order.fee, feeText = format(order.fee), netText = format(order.total - order.fee), note = order.note,
		createdAt = order.createdAt, deliveredAt = order.deliveredAt, closedAt = order.closedAt,
		seller = order.seller or order.vendor, npc = order.sellerHandle == nil, buyer = role == 'seller' and order.buyer or nil,
		rating = order.rating, deliverBy = order.createdAt + market.DeliverHours * 3600,
		releaseAt = order.deliveredAt > 0 and order.deliveredAt + market.AutoReleaseHours * 3600 or nil
	}
	-- O ponto de coleta só aparece para quem precisa ir até ele.
	if order.kind == 'item' and ((role == 'seller' and order.status == 'paid') or (role == 'buyer' and order.status == 'dropped')) then
		view.drop = dropOf(order.dropIndex)
	end
	local now = os.time()
	local actions = {}
	for _, action in ipairs({ 'deliver', 'collect', 'confirm', 'dispute', 'cancel' }) do
		if DeepwebRules.OrderNext(config, order, action, role, now) then
			actions[#actions + 1] = action
		end
	end
	view.actions = actions
	view.canReview = role == 'buyer' and order.sellerHandle ~= nil and order.rating == nil and (order.status == 'completed' or order.status == 'released')
	return view
end

function App.marketMine(context)
	local session, errorCode = signedIn(context)
	if not session then
		return fail(errorCode)
	end
	local listings = DeepwebPersistence.Listings({ sellerHandle = session.id, status = 'any', limit = market.MaxListingsPerHandle + 5 })
	local bought = DeepwebPersistence.OrdersOf(session.id, 'buyer', 30)
	local sold = DeepwebPersistence.OrdersOf(session.id, 'seller', 30)
	if not listings or not bought or not sold then
		return fail('database_error')
	end
	local result = { ok = true, me = session.handle, listings = {}, bought = {}, sold = {}, categories = categories(),
		canSell = DeepwebRules.Allows(config, level(context), 'market_sell'), maxListings = market.MaxListingsPerHandle, feeBps = market.FeeBps,
		decimals = market.CoinDecimals }
	for _, listing in ipairs(listings) do
		local view = listingView(listing, session)
		view.payout = listing.payout
		result.listings[#result.listings + 1] = view
	end
	for _, order in ipairs(bought) do
		result.bought[#result.bought + 1] = orderView(order, 'buyer', context)
	end
	for _, order in ipairs(sold) do
		result.sold[#result.sold + 1] = orderView(order, 'seller', context)
	end
	return result
end

local function roleOf(order, session)
	if order.buyerHandle == session.id then
		return 'buyer'
	end
	if order.sellerHandle and order.sellerHandle == session.id then
		return 'seller'
	end
	return nil
end

function App.marketOrder(context, payload)
	local session, errorCode = signedIn(context)
	if not session then
		return fail(errorCode)
	end
	local id = math.tointeger(tonumber(payload.id))
	local order = id and DeepwebPersistence.OrderById(id)
	if order == nil then
		return fail('database_error')
	end
	local role = order and roleOf(order, session)
	if not role then
		return fail('not_found')
	end
	return { ok = true, order = orderView(order, role, context), me = session.handle }
end

-- Anunciar --------------------------------------------------------------------------------------------

function App.marketSave(context, payload)
	local denied = S.RequireFeature(context, 'market_sell')
	if denied then
		return fail(denied)
	end
	local session, errorCode = signedIn(context)
	if not session then
		return fail(errorCode)
	end
	local raw = {}
	for key, value in pairs(payload) do
		raw[key] = value
	end
	raw.price = DeepwebRules.ParseCoin(payload.price, market.CoinDecimals)
	local clean
	clean, errorCode = DeepwebRules.Listing(config, raw)
	if not clean then
		return fail(errorCode)
	end
	if clean.kind == 'item' then
		local items = S.Call('coe_inventory', 'Items')
		if type(items) == 'table' and not items[clean.item] then
			return fail('unknown_item')
		end
	end
	local payout = type(payload.payout) == 'string' and payload.payout:gsub('^%s+', ''):gsub('%s+$', '') or ''
	if S.Call('coe_crypto', 'IsAddress', payout) ~= true then
		return fail('invalid_payout')
	end
	if S.Call('coe_crypto', 'Balance', payout) == nil then
		return fail('unknown_payout')
	end
	clean.payout = payout
	clean.sellerHandle = session.id
	local id = math.tointeger(tonumber(payload.id))
	return S.WithLock('handle:' .. session.id, function()
		local now = os.time()
		if id then
			local existing = DeepwebPersistence.ListingById(id)
			if not existing or existing.status == 'removed' or existing.sellerHandle ~= session.id then
				return fail(existing == nil and 'database_error' or 'not_found')
			end
			clean.status = payload.status == 'paused' and 'paused' or 'active'
			if not DeepwebPersistence.UpdateListing(id, clean, now) then
				return fail('database_error')
			end
			return { ok = true, id = id }
		end
		local count = DeepwebPersistence.CountListings(session.id)
		if count == nil then
			return fail('database_error')
		end
		if count >= market.MaxListingsPerHandle then
			return fail('listing_limit')
		end
		clean.status = 'active'
		local newId = DeepwebPersistence.InsertListing(clean, now)
		if not newId then
			return fail('database_error')
		end
		S.Log('info', 'gameplay', 'deepweb_listing_created', { character_id = context.character, target = 'listing:' .. newId })
		return { ok = true, id = newId }
	end)
end

-- Pausar, reativar ou remover o próprio anúncio. Pedidos em andamento continuam.
function App.marketListingStatus(context, payload)
	local session, errorCode = signedIn(context)
	if not session then
		return fail(errorCode)
	end
	local id = math.tointeger(tonumber(payload.id))
	local status = ({ active = 'active', paused = 'paused', removed = 'removed' })[payload.status]
	if not id or not status then
		return fail('invalid_listing')
	end
	local listing = DeepwebPersistence.ListingById(id)
	if not listing or listing.status == 'removed' or listing.sellerHandle ~= session.id then
		return fail(listing == nil and 'database_error' or 'not_found')
	end
	if status == 'active' and DeepwebRules.Allows(config, level(context), 'market_sell') == false then
		return fail('tier_too_low')
	end
	if not DeepwebPersistence.SetListingStatus(id, status, os.time()) then
		return fail('database_error')
	end
	return { ok = true }
end

-- Andamento do pedido ---------------------------------------------------------------------------------

-- session: o apelido que age (do site, ou o do ponto armado quando vem do alvo no local).
local function act(context, session, payload)
	local errorCode
	local id = math.tointeger(tonumber(payload.id))
	local action = payload.action
	if not id or (action ~= 'deliver' and action ~= 'collect' and action ~= 'confirm' and action ~= 'dispute' and action ~= 'cancel') then
		return fail('invalid_action')
	end
	if not cryptoReady() then
		return fail('crypto_unavailable')
	end
	return S.WithLock('order:' .. id, function()
		local order = DeepwebPersistence.OrderById(id)
		if order == nil then
			return fail('database_error')
		end
		local role = order and roleOf(order, session)
		if not role then
			return fail('not_found')
		end
		local now = os.time()
		local nextStatus
		nextStatus, errorCode = DeepwebRules.OrderNext(config, order, action, role, now)
		if not nextStatus then
			return fail(errorCode)
		end
		-- Itens: o site só arma o ponto; deixar/coletar é pelo alvo no local (DeepwebMarket.DropUse).
		if order.kind == 'item' and (action == 'deliver' or action == 'collect') and not context.atDrop then
			local task = dropTask(order, action)
			if not task or not context.character then
				return fail('not_found')
			end
			tickets[order.id] = {
				playerId = context.playerId, character = context.character, handle = session.id, action = action,
				expires = now + (market.DropTicketMinutes or 120) * 60
			}
			TriggerClientEvent('coe_deepweb:drop:arm', context.playerId, task)
			return { ok = true, armed = true, drop = dropOf(order.dropIndex) }
		end
		local inventory = S.InventoryOf(context.character)
		if action == 'deliver' and order.kind == 'item' then
			if not atDrop(context, order) then
				return fail('not_at_drop', { drop = dropOf(order.dropIndex) })
			end
			local have = S.Call('coe_inventory', 'GetItemCount', inventory, order.item)
			if type(have) ~= 'number' or have < order.count then
				return fail('missing_items')
			end
			if S.Call('coe_inventory', 'RemoveItemByName', inventory, order.item, order.count) ~= true then
				return fail('missing_items')
			end
			local ok
			ok, errorCode = move(order, nextStatus, { delivered = true }, now)
			if not ok then
				S.Call('coe_inventory', 'AddItem', inventory, order.item, order.count)
				return fail(errorCode)
			end
			alertAt(context)
			notifyHandle(order.buyerHandle, _t('market_order_at_drop', { id = order.id }))
			return { ok = true, status = order.status }
		end
		if action == 'collect' then
			if not atDrop(context, order) then
				return fail('not_at_drop', { drop = dropOf(order.dropIndex) })
			end
			-- Estado intermediário: ninguém mais mexe no pedido enquanto o item entra no inventário.
			local claimed = DeepwebPersistence.MoveOrder(order.id, 'dropped', 'collecting', { closed = true }, now)
			if not claimed then
				return fail(claimed == nil and 'database_error' or 'invalid_status')
			end
			if S.Call('coe_inventory', 'AddItem', inventory, order.item, order.count) ~= true then
				DeepwebPersistence.MoveOrder(order.id, 'collecting', 'dropped', nil, now)
				return fail('inventory_full')
			end
			order.status = 'collecting'
			move(order, 'completed', { closed = true }, now)
			alertAt(context)
			notifyHandle(order.sellerHandle, _t('market_order_collected', { id = order.id }))
			return { ok = true, status = 'completed' }
		end
		local fields = { delivered = action == 'deliver' or nil, closed = FINAL[nextStatus] or nil }
		if action == 'dispute' then
			local note = DeepwebRules.Text(payload.note, market.DisputeMax, false)
			if not note then
				return fail('invalid_note')
			end
			fields.note = note
		end
		local ok
		ok, errorCode = move(order, nextStatus, fields, now)
		if not ok then
			return fail(errorCode)
		end
		local other = role == 'buyer' and order.sellerHandle or order.buyerHandle
		local messages = {
			deliver = 'market_order_delivered',
			confirm = 'market_order_confirmed',
			dispute = 'market_order_disputed',
			cancel = 'market_order_cancelled'
		}
		local key = messages[action]
		if key then
			notifyHandle(other, _t(key, { id = order.id }))
		end
		if action == 'dispute' then
			S.Audit('deepweb_market_dispute', { character_id = context.character, target = 'order:' .. order.id })
		end
		return { ok = true, status = order.status }
	end)
end

function App.marketAct(context, payload)
	local session, errorCode = signedIn(context)
	if not session then
		return fail(errorCode)
	end
	return act(context, session, payload)
end

-- Alvo no ponto de coleta: o client manda o pedido; o ponto precisa ter sido armado por este personagem no site.
function DeepwebMarket.DropUse(playerId, orderId)
	local id = math.tointeger(tonumber(orderId))
	local ticket = id and tickets[id]
	local character = S.CharacterOf(playerId)
	if not ticket or not character or ticket.character ~= character or ticket.playerId ~= playerId then
		return fail('not_armed')
	end
	if os.time() > ticket.expires then
		tickets[id] = nil
		TriggerClientEvent('coe_deepweb:drop:clear', playerId, id)
		return fail('ticket_expired')
	end
	if not cryptoReady() then
		return fail('crypto_unavailable')
	end
	-- Mesmo caminho do site (estado, papel, inventário, custódia), agora no local e com o apelido do ponto armado.
	local context = { playerId = playerId, character = character, atDrop = true }
	local ok, acted = pcall(act, context, { id = ticket.handle }, { id = id, action = ticket.action })
	if not ok then
		S.Log('error', 'gameplay', 'deepweb_drop_use_failed', { target = 'order:' .. id, error = tostring(acted) })
		return fail('database_error')
	end
	if acted.ok or acted.error == 'invalid_status' or acted.error == 'not_found' then
		tickets[id] = nil
		TriggerClientEvent('coe_deepweb:drop:clear', playerId, id)
	end
	return acted
end

local DROP_MESSAGES = {
	collect = 'drop_collect',
	deliver = 'drop_deliver'
}
local DROP_ERRORS = {
	not_at_drop = 'err_not_at_drop',
	missing_items = 'err_missing_items',
	inventory_full = 'err_inventory_full',
	invalid_status = 'err_invalid_status',
	not_armed = 'err_not_armed',
	ticket_expired = 'err_ticket_expired',
	crypto_unavailable = 'err_crypto_unavailable'
}
local dropCooldown = {}

RegisterNetEvent('coe_deepweb:drop:use', function(orderId)
	local playerId = source
	local now = GetGameTimer()
	if dropCooldown[playerId] and now - dropCooldown[playerId] < 1500 then
		return
	end
	dropCooldown[playerId] = now
	local ticket = tickets[math.tointeger(tonumber(orderId)) or -1]
	local result = DeepwebMarket.DropUse(playerId, orderId)
	if result.ok then
		local msgKey = DROP_MESSAGES[ticket and ticket.action]
		S.Notify(playerId, 'success', msgKey and _t(msgKey) or _t('drop_updated'))
	else
		local errKey = DROP_ERRORS[result.error]
		S.Notify(playerId, 'error', errKey and _t(errKey) or _t('drop_failed'))
	end
end)

AddEventHandler('playerDropped', function()
	dropCooldown[source] = nil
end)

function App.marketReview(context, payload)
	local session, errorCode = signedIn(context)
	if not session then
		return fail(errorCode)
	end
	local id = math.tointeger(tonumber(payload.id))
	local rating = math.tointeger(tonumber(payload.rating))
	if not id or not rating or rating < 1 or rating > 5 then
		return fail('invalid_rating')
	end
	local body = payload.body == nil and '' or DeepwebRules.Text(payload.body, market.ReviewMax, false, 0)
	if not body then
		return fail('invalid_review')
	end
	local order = DeepwebPersistence.OrderById(id)
	if order == nil then
		return fail('database_error')
	end
	if not order or order.buyerHandle ~= session.id or not order.sellerHandle then
		return fail('not_found')
	end
	if order.status ~= 'completed' and order.status ~= 'released' then
		return fail('invalid_status')
	end
	local ok
	ok, errorCode = DeepwebPersistence.InsertReview({ orderId = id, sellerHandle = order.sellerHandle, buyerHandle = session.id, rating = rating, body = body }, os.time())
	if not ok then
		return fail(errorCode == 'already_reviewed' and errorCode or 'database_error')
	end
	return { ok = true }
end

for _, action in ipairs({ 'marketHome', 'marketListing', 'marketMine', 'marketOrder' }) do
	S.ReadOnly(action)
end

-- Staff (coe_admin): resolve disputas e cancela pedidos travados. decision: buyer (devolve) ou seller (paga).
function DeepwebMarket.Resolve(orderId, decision)
	local order = DeepwebPersistence.OrderById(orderId)
	if not order then
		return { error = order == nil and 'database_error' or 'not_found' }
	end
	local now = os.time()
	local action
	if order.status == 'disputed' then
		action = decision == 'seller' and 'resolve_seller' or 'resolve_buyer'
	elseif order.status == 'paid' and decision == 'buyer' then
		action = 'cancel'
	else
		return { error = 'invalid_status' }
	end
	local nextStatus, errorCode = DeepwebRules.OrderNext(config, order, action, 'system', now)
	if not nextStatus then
		return { error = errorCode }
	end
	local ok
	ok, errorCode = move(order, nextStatus, { closed = true }, now)
	if not ok then
		return { error = errorCode }
	end
	notifyHandle(order.buyerHandle, _t('market_order_decided', { id = order.id }))
	notifyHandle(order.sellerHandle, _t('market_order_decided', { id = order.id }))
	return { ok = true, status = nextStatus }
end

-- Rodada: libera pedidos entregues e não contestados depois do prazo e repete pagamentos que falharam.
function DeepwebMarket.Tick()
	if not cryptoReady() then
		return
	end
	local now = os.time()
	local dropped = DeepwebPersistence.OrdersByStatus('dropped', 200) or {}
	for _, order in ipairs(dropped) do
		if DeepwebRules.OrderNext(config, order, 'release', 'system', now) then
			move(order, 'completed', { closed = true }, now)
		end
	end
	-- Coleta interrompida no meio (o item já entrou): conclui.
	for _, order in ipairs(DeepwebPersistence.OrdersByStatus('collecting', 50) or {}) do
		if now - order.closedAt > 300 then
			move(order, 'completed', { closed = true }, now)
		end
	end
	for _, order in ipairs(DeepwebPersistence.UnsettledOrders(50) or {}) do
		settle(order)
	end
end

CreateThread(function()
	while true do
		Wait(60000)
		if S.IsReady() then
			local ok, failure = pcall(DeepwebMarket.Tick)
			if not ok then
				S.Log('error', 'gameplay', 'deepweb_market_tick_failed', { error_code = tostring(failure):sub(1, 120) })
			end
		end
	end
end)

-- Fornecedores NPC iniciais: só enquanto não existir nenhum anúncio de fornecedor (nem removido); depois, o admin manda.
S.OnReady(function()
	local count = DeepwebPersistence.CountVendorListings()
	if count ~= 0 then
		return
	end
	local now = os.time()
	for _, vendor in ipairs(market.Vendors) do
		local clean = DeepwebRules.Listing(config, vendor)
		if clean then
			clean.vendor = vendor.vendor
			if not DeepwebPersistence.InsertListing(clean, now) then
				S.Log('warn', 'persistence', 'deepweb_vendor_seed_failed', { target = vendor.item })
			end
		end
	end
end)
