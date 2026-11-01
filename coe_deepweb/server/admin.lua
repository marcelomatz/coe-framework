-- Administração da DeepWeb pelo coe_admin: sites por blocos, fornecedores NPC do Deep Market, disputas, moderação e contatos.
local config = DeepwebConfig
local S = DeepwebServer

local function adminOnly()
	return GetInvokingResource() == 'coe_admin'
end

local function denied()
	return { error = 'forbidden' }
end

local function format(units)
	return S.Call('coe_crypto', 'Format', units) or tostring(units)
end

-- Panorama: sites, fornecedores NPC, pedidos em disputa ou travados, posts recentes do Rabbit e contatos dos perfis.
exports('AdminOverview', function()
	if not adminOnly() then
		return denied()
	end
	if not S.IsReady() then
		return { available = true, ready = false }
	end
	local sites = DeepwebPersistence.Sites() or {}
	local vendors = DeepwebPersistence.Listings({ npc = true, status = 'any', limit = 200 }) or {}
	local disputed = DeepwebPersistence.OrdersByStatus('disputed', 50) or {}
	local paid = DeepwebPersistence.OrdersByStatus('paid', 50) or {}
	local posts = DeepwebPersistence.Posts({ sort = 'new', limit = 30 }) or {}
	local inbox = DeepwebPersistence.ContactInbox(60) or {}
	local siteList, vendorList, orderList, postList, contactList = {}, {}, {}, {}, {}
	for _, site in ipairs(sites) do
		siteList[#siteList + 1] = {
			domain = site.domain, app = site.app, title = site.title, description = site.description, keywords = site.keywords,
			blocks = site.blocks, active = site.active, listed = site.listed ~= false, system = site.app ~= '', updatedAt = site.updatedAt
		}
	end
	for _, listing in ipairs(vendors) do
		vendorList[#vendorList + 1] = {
			id = listing.id, vendor = listing.vendor, kind = listing.kind, category = listing.category, title = listing.title,
			description = listing.description, item = listing.item, count = listing.count, price = listing.price, priceText = format(listing.price),
			stock = listing.stock, sold = listing.sold, status = listing.status
		}
	end
	local now = os.time()
	local function addOrder(order)
		orderList[#orderList + 1] = {
			id = order.id, title = order.title, status = order.status, kind = order.kind, total = order.total, totalText = format(order.total),
			seller = order.seller or order.vendor, buyer = order.buyer, buyerCharacter = order.buyerCharacter, note = order.note,
			createdAt = order.createdAt, deliveredAt = order.deliveredAt, late = order.status == 'paid' and now > order.createdAt + config.Market.DeliverHours * 3600
		}
	end
	for _, order in ipairs(disputed) do addOrder(order) end
	for _, order in ipairs(paid) do addOrder(order) end
	for _, post in ipairs(posts) do
		postList[#postList + 1] = { id = post.id, title = post.title, body = post.body, community = post.community, author = post.author, score = post.score, createdAt = post.createdAt }
	end
	for _, entry in ipairs(inbox) do
		contactList[#contactList + 1] = {
			id = entry.id, site = entry.site, handle = entry.handle, body = entry.body, reply = entry.reply, status = entry.status,
			createdAt = entry.createdAt, repliedAt = entry.repliedAt
		}
	end
	return {
		available = true, ready = true, sites = siteList, vendors = vendorList, orders = orderList, posts = postList, contacts = contactList,
		categories = config.Market.Categories, decimals = config.Market.CoinDecimals, blockTypes = { 'heading', 'text', 'quote', 'notice', 'list', 'divider', 'link', 'listing' }
	}
end)

-- Site por blocos. raw: { domain, title, description, keywords, blocks, active, listed }.
exports('AdminSaveSite', function(raw)
	if not adminOnly() then
		return denied()
	end
	local result = DeepwebSites.Save(raw, nil, json.encode)
	if result.ok then
		S.Audit('deepweb_admin_site_saved', { target = result.domain })
	end
	return result
end)

exports('AdminDeleteSite', function(raw)
	if not adminOnly() then
		return denied()
	end
	local domain = type(raw) == 'table' and DeepwebRules.Domain(config, raw.domain)
	if not domain then
		return { error = 'invalid_domain' }
	end
	local deleted = DeepwebPersistence.DeleteSite(domain)
	if not deleted then
		return { error = deleted == nil and 'database_error' or 'not_found' }
	end
	S.Audit('deepweb_admin_site_deleted', { target = domain })
	return { ok = true }
end)

-- Fornecedor NPC. raw: { id?, vendor, kind, category, title, description, item, count, price (texto em moeda), stock, status }.
exports('AdminSaveVendor', function(raw)
	if not adminOnly() then
		return denied()
	end
	if type(raw) ~= 'table' then
		return { error = 'invalid_listing' }
	end
	local copy = {}
	for key, value in pairs(raw) do
		copy[key] = value
	end
	copy.price = DeepwebRules.ParseCoin(raw.price, config.Market.CoinDecimals)
	local clean, errorCode = DeepwebRules.Listing(config, copy)
	if not clean then
		return { error = errorCode }
	end
	local vendor = DeepwebRules.Text(raw.vendor, 32)
	if not vendor then
		return { error = 'invalid_vendor' }
	end
	if clean.kind == 'item' then
		local items = S.Call('coe_inventory', 'Items')
		if type(items) == 'table' and not items[clean.item] then
			return { error = 'unknown_item' }
		end
	end
	clean.vendor = vendor
	clean.status = raw.status == 'paused' and 'paused' or 'active'
	local now = os.time()
	local id = math.tointeger(tonumber(raw.id))
	if id then
		local existing = DeepwebPersistence.ListingById(id)
		if not existing or existing.sellerHandle ~= nil or existing.status == 'removed' then
			return { error = existing == nil and 'database_error' or 'not_found' }
		end
		if not DeepwebPersistence.UpdateListing(id, clean, now) then
			return { error = 'database_error' }
		end
	else
		id = DeepwebPersistence.InsertListing(clean, now)
		if not id then
			return { error = 'database_error' }
		end
	end
	S.Audit('deepweb_admin_vendor_saved', { target = 'listing:' .. id })
	return { ok = true, id = id }
end)

exports('AdminDeleteVendor', function(raw)
	if not adminOnly() then
		return denied()
	end
	local id = type(raw) == 'table' and math.tointeger(tonumber(raw.id))
	local existing = id and DeepwebPersistence.ListingById(id)
	if not existing or existing.sellerHandle ~= nil then
		return { error = existing == nil and 'database_error' or 'not_found' }
	end
	if not DeepwebPersistence.SetListingStatus(id, 'removed', os.time()) then
		return { error = 'database_error' }
	end
	return { ok = true }
end)

-- Disputa ou pedido travado: decision = 'buyer' (devolve) ou 'seller' (paga o vendedor).
exports('AdminResolveOrder', function(raw)
	if not adminOnly() then
		return denied()
	end
	local id = type(raw) == 'table' and math.tointeger(tonumber(raw.id))
	if not id or (raw.decision ~= 'buyer' and raw.decision ~= 'seller') then
		return { error = 'invalid_order' }
	end
	local result = DeepwebMarket.Resolve(id, raw.decision)
	if result.ok then
		S.Audit('deepweb_admin_order_resolved', { target = 'order:' .. id, result = raw.decision })
	end
	return result
end)

-- Moderação do Rabbit: remove um post (o conteúdo some para todos).
exports('AdminRemovePost', function(raw)
	if not adminOnly() then
		return denied()
	end
	local id = type(raw) == 'table' and math.tointeger(tonumber(raw.id))
	if not id or not DeepwebPersistence.RemovePost(id) then
		return { error = id and 'database_error' or 'not_found' }
	end
	S.Audit('deepweb_admin_post_removed', { target = 'post:' .. id })
	return { ok = true }
end)

-- Contatos dos sites de perfil: a resposta fica na página para o apelido e avisa quem estiver online.
exports('AdminReplyContact', function(raw)
	if not adminOnly() then
		return denied()
	end
	local id = type(raw) == 'table' and math.tointeger(tonumber(raw.id))
	local reply = id and DeepwebRules.Text(raw.reply, config.Contact.ReplyMax, true)
	if not id then
		return { error = 'not_found' }
	end
	if not reply then
		return { error = 'invalid_reply' }
	end
	local entry = DeepwebPersistence.ContactById(id)
	if not entry then
		return { error = entry == nil and 'database_error' or 'not_found' }
	end
	local changed = DeepwebPersistence.ReplyContact(id, reply, os.time())
	if not changed then
		return { error = changed == nil and 'database_error' or 'contact_closed' }
	end
	local _t = (S and S.T) or function(k, p) return ('Resposta de %s: abra o site para ler.'):format(p and p.site or '') end
	S.NotifyHandle(entry.handleId, _t('admin_reply_received', { site = entry.site }))
	S.Audit('deepweb_admin_contact_replied', { target = 'contact:' .. id })
	return { ok = true }
end)

exports('AdminCloseContact', function(raw)
	if not adminOnly() then
		return denied()
	end
	local id = type(raw) == 'table' and math.tointeger(tonumber(raw.id))
	local closed = id and DeepwebPersistence.CloseContact(id)
	if not closed then
		return { error = closed == nil and id and 'database_error' or 'not_found' }
	end
	S.Audit('deepweb_admin_contact_closed', { target = 'contact:' .. id })
	return { ok = true }
end)