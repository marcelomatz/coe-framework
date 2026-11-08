-- Navegador (favoritos, sites, busca), Rabbit, Deep Market (custódia, ponto de coleta, serviços, disputa, avaliação) e
-- exports do admin, com natives, exports e persistência falsos em memória.
dofile('config.lua')
dofile('shared/rules.lua')
local function loadFramework(path)
	local candidates = {
		'../' .. path,
		'../tools/compat/' .. path,
		'../[coe-framework]/' .. path,
		'../../coe-framework/' .. path
	}
	for _, c in ipairs(candidates) do
		local f = io.open(c, 'r')
		if f then f:close() return dofile(c) end
	end
	error('Cannot find framework file: ' .. path)
end

loadFramework('coe_core/lib/hash.lua')

local config = DeepwebConfig
local failures = 0

local function eq(actual, expected, message)
	if actual ~= expected then
		failures = failures + 1
		print(('FAIL %s: esperado %s, obtido %s'):format(message, tostring(expected), tostring(actual)))
	end
end

-- Ambiente FiveM falso ---------------------------------------------------------------------------------

local invoking = 'coe_phone'
local now = 2000000
local timer = 0
local registered, threads, notices, alerts = {}, {}, {}, {}

function GetInvokingResource() return invoking end
function GetGameTimer() timer = timer + 1000; return timer end
function GetResourceState() return 'started' end
function AddEventHandler() end
function RegisterCommand() end
function RegisterNetEvent() end
clientEvents = {}
function TriggerClientEvent(name, playerId, ...) clientEvents[#clientEvents + 1] = { name = name, playerId = playerId, args = { ... } } end
function Wait() coroutine.yield() end
function CreateThread(fn) local co = coroutine.create(fn); threads[#threads + 1] = co; assert(coroutine.resume(co)) end
function GetPlayers() return { '1', '2', '3' } end
local positions = { [1] = { x = 0.0, y = 0.0, z = 0.0 }, [2] = { x = 0.0, y = 0.0, z = 0.0 }, [3] = { x = 0.0, y = 0.0, z = 0.0 } }
function GetPlayerPed(playerId) return playerId end
function GetEntityCoords(ped) return positions[ped] end
function GetEntityHeading() return 0.0 end
json = { encode = function(value) return value end }
os.time = function() return now end
math.random = function(n) return n and 1 or 0.05 end

local characters = { [1] = 11, [2] = 22, [3] = 33 }
Core = {
	Algorithms = dofile('../coe_core/lib/algorithms/init.lua'),
	Platform = dofile('../coe_core/lib/platform.lua'),
	Players = { GetActiveCharacterId = function(playerId) return characters[playerId] end },
	Events = { On = function() end }
}

-- Inventário: [inventário][item] = quantidade.
local bag = { ['character:11'] = {}, ['character:22'] = { lockpick = 5 }, ['character:33'] = {} }
local ITEMS = { onion_usb = { label = 'Pen drive onion' }, usb_black = { label = 'Pen drive' }, lockpick = { label = 'Gazua' } }
local inventoryFull = false

-- Cripto: saldos por endereço; chaves por aparelho.
local A1, A2, A3 = 'nx' .. string.rep('a', 28), 'nx' .. string.rep('b', 28), 'nx' .. string.rep('c', 28)
local RESERVE, ESCROW = 'nx' .. string.rep('R', 28), 'nx' .. string.rep('E', 28)
local balances = { [A1] = 1000000, [A2] = 0, [A3] = 500000, [RESERVE] = 0, [ESCROW] = 0 }
local keys = { ['phone:P1'] = { A1 }, ['phone:P2'] = { A2 }, ['phone:P3'] = { A3 } }
local releaseFails = false

local function resource(methods)
	return setmetatable({}, { __index = function(_, name)
		return function(_, ...)
			local fn = methods[name]
			if fn then return fn(...) end
			return true
		end
	end })
end

local stub = {
	coe_phone = resource({ ActiveDevice = function(playerId) return { serial = 'P' .. playerId } end }),
	coe_inventory = resource({
		Items = function() return ITEMS end,
		GetItemCount = function(id, name) return bag[id][name] or 0 end,
		RemoveItemByName = function(id, name, count)
			if (bag[id][name] or 0) < count then return false end
			bag[id][name] = bag[id][name] - count
			return true
		end,
		AddItem = function(id, name, count)
			if inventoryFull then return false end
			bag[id][name] = (bag[id][name] or 0) + count
			return true
		end
	}),
	coe_crypto = resource({
		IsReady = function() return true end,
		IsAddress = function(address) return type(address) == 'string' and #address == 30 and address:sub(1, 2) == 'nx' end,
		Balance = function(address) return balances[address] end,
		Format = function(units) return tostring(units) .. ' NOX' end,
		ReserveAddress = function() return RESERVE end,
		HeldWallets = function(playerId, key)
			local list = {}
			for _, address in ipairs(keys[key] or {}) do list[#list + 1] = { address = address, label = '', source = 'device', balance = balances[address] } end
			return list
		end,
		EscrowLock = function(playerId, key, from, amount)
			local held = false
			for _, address in ipairs(keys[key] or {}) do if address == from then held = true end end
			if not held then return { ok = false, error = 'no_key' } end
			if balances[from] < amount + 10 then return { ok = false, error = 'insufficient_funds' } end
			balances[from] = balances[from] - amount - 10
			balances[ESCROW] = balances[ESCROW] + amount
			return { ok = true, txId = 1 }
		end,
		EscrowRelease = function(to, amount)
			if releaseFails or balances[ESCROW] < amount then return { ok = false, error = 'database_error' } end
			balances[ESCROW] = balances[ESCROW] - amount
			balances[to] = (balances[to] or 0) + amount
			return { ok = true, txId = 2 }
		end
	}),
	coe_dispatch = resource({ Alert = function(code) alerts[#alerts + 1] = code; return 1 end }),
	coe_notify = resource({ Notify = function(playerId, kind, message) notices[#notices + 1] = { playerId = playerId, message = message } end })
}
exports = setmetatable({}, {
	__call = function(_, name, fn) registered[name] = fn end,
	__index = function(_, name) return stub[name] or resource({}) end
})

-- Persistência em memória (mesmo contrato de server/persistence.lua) ------------------------------------

local db = {
	handles = {}, sessions = {}, browsers = { ['phone:P1'] = true, ['phone:P2'] = true, ['phone:P3'] = true, ['tablet:22'] = true },
	devices = {}, bookmarks = {}, sites = {}, communities = {}, posts = {}, comments = {}, votes = {}, listings = {}, orders = {},
	reviews = {}, state = {}
}

local function copy(value)
	if type(value) ~= 'table' then return value end
	local result = {}
	for k, v in pairs(value) do result[k] = copy(v) end
	return result
end

DeepwebPersistence = {}
local P = DeepwebPersistence
function P.Initialize() return true end
function P.HandleByName(name) for _, h in ipairs(db.handles) do if h.handle == name then return copy(h) end end return false end
function P.HandleById(id) return db.handles[id] and copy(db.handles[id]) or false end
function P.HandlesOf(characterId)
	local list = {}
	for _, h in ipairs(db.handles) do if h.owner == characterId then list[#list + 1] = { id = h.id, handle = h.handle } end end
	return list
end
function P.InsertHandle(name, hash, characterId, at)
	for _, h in ipairs(db.handles) do if h.handle == name then return nil, 'handle_taken' end end
	db.handles[#db.handles + 1] = { id = #db.handles + 1, handle = name, hash = hash, owner = characterId, reputation = 0, createdAt = at }
	return #db.handles
end
function P.UpdateHandlePassword() return true end
function P.TouchHandle() return true end
function P.Session(key) return db.sessions[key] and copy(db.handles[db.sessions[key]]) or false end
function P.SetSession(key, id) db.sessions[key] = id; return true end
function P.ClearSession(key) db.sessions[key] = nil; return true end
function P.ClearOtherSessions() return true end
function P.BrowserInstalled(key) return db.browsers[key] == true end
function P.InstallBrowser(key) db.browsers[key] = true; return true end
function P.Device() return false end
function P.EnsureDevice() return true end
function P.RigById() return false end
function P.MiningRigs() return {} end

function P.StateFlag(name) return db.state[name] == true end
function P.SetStateFlag(name) db.state[name] = true; return true end

function P.Bookmarks(key)
	local list = {}
	for _, b in ipairs(db.bookmarks) do if b.key == key then list[#list + 1] = { address = b.address, title = b.title } end end
	return list
end
function P.AddBookmark(key, address, title)
	for _, b in ipairs(db.bookmarks) do if b.key == key and b.address == address then b.title = title; return true end end
	db.bookmarks[#db.bookmarks + 1] = { key = key, address = address, title = title }
	return true
end
function P.RemoveBookmark(key, address)
	for i, b in ipairs(db.bookmarks) do if b.key == key and b.address == address then table.remove(db.bookmarks, i); break end end
	return true
end

function P.SiteByDomain(domain) return db.sites[domain] and copy(db.sites[domain]) or false end
function P.Sites()
	local list = {}
	for _, s in pairs(db.sites) do list[#list + 1] = copy(s) end
	table.sort(list, function(a, b) return a.domain < b.domain end)
	return list
end
function P.SaveSite(data, at)
	local site = copy(data)
	site.app = site.app or ''
	site.active = data.active ~= false
	site.listed = data.listed ~= false
	site.blocks = data.blocks or ''
	site.updatedAt = at
	db.sites[data.domain] = site
	return true
end
function P.DeleteSite(domain)
	local site = db.sites[domain]
	if not site or site.app ~= '' then return false end
	db.sites[domain] = nil
	return true
end

local function like(pattern, ...)
	local needle = pattern:gsub('^%%', ''):gsub('%%$', ''):gsub('\\(.)', '%1')
	for _, text in ipairs({ ... }) do
		if tostring(text):lower():find(needle, 1, true) then return true end
	end
	return false
end

function P.SearchSites(pattern, limit)
	local list = {}
	for _, s in pairs(db.sites) do
		if s.active and s.listed and like(pattern, s.title, s.description, s.keywords, s.domain) then list[#list + 1] = { domain = s.domain, app = s.app, title = s.title, description = s.description } end
	end
	return list
end

db.contacts = {}
local function contactRow(k)
	local row = copy(k)
	row.handle = db.handles[k.handleId] and db.handles[k.handleId].handle
	return row
end
function P.InsertContact(data, at)
	local id = #db.contacts + 1
	db.contacts[id] = { id = id, site = data.site, handleId = data.handleId, body = data.body, status = 'open', createdAt = at, repliedAt = 0 }
	return id
end
function P.ContactsOf(handleId, site, limit)
	local list = {}
	for i = #db.contacts, 1, -1 do
		local k = db.contacts[i]
		if k.handleId == handleId and k.site == site and #list < limit then list[#list + 1] = contactRow(k) end
	end
	return list
end
function P.ContactStats(handleId, site)
	local last, open = 0, 0
	for _, k in ipairs(db.contacts) do
		if k.handleId == handleId then
			last = math.max(last, k.createdAt)
			if k.site == site and k.status == 'open' then open = open + 1 end
		end
	end
	return { last = last, open = open }
end
function P.ContactById(id) return db.contacts[id] and contactRow(db.contacts[id]) or false end
function P.ContactInbox()
	local list = {}
	for _, k in ipairs(db.contacts) do list[#list + 1] = contactRow(k) end
	return list
end
function P.ReplyContact(id, reply, at)
	local k = db.contacts[id]
	if not k or k.status == 'closed' then return false end
	k.reply, k.status, k.repliedAt = reply, 'answered', at
	return true
end
function P.CloseContact(id)
	local k = db.contacts[id]
	if not k or k.status == 'closed' then return false end
	k.status = 'closed'
	return true
end

local function communityById(id) for _, c in ipairs(db.communities) do if c.id == id then return c end end end
local function handleName(id) return db.handles[id] and db.handles[id].handle end

local function postRow(p)
	local row = copy(p)
	row.community = communityById(p.communityId).slug
	row.author = handleName(p.handleId)
	return row
end

function P.SearchPosts(pattern)
	local list = {}
	for _, p in ipairs(db.posts) do if not p.removed and like(pattern, p.title, p.body) then list[#list + 1] = postRow(p) end end
	return list
end

local function communityRow(c)
	local row = copy(c)
	row.posts = 0
	for _, p in ipairs(db.posts) do if p.communityId == c.id and not p.removed then row.posts = row.posts + 1 end end
	row.moderator = c.createdBy and handleName(c.createdBy) or nil
	return row
end
function P.Communities()
	local list = {}
	for _, c in ipairs(db.communities) do list[#list + 1] = communityRow(c) end
	return list
end
function P.CommunityBySlug(slug) for _, c in ipairs(db.communities) do if c.slug == slug then return communityRow(c) end end return false end
function P.CommunitiesCreatedBy(handleId)
	local count = 0
	for _, c in ipairs(db.communities) do if c.createdBy == handleId then count = count + 1 end end
	return count
end
function P.InsertCommunity(data, at)
	for _, c in ipairs(db.communities) do if c.slug == data.slug then return nil, 'slug_taken' end end
	db.communities[#db.communities + 1] = { id = #db.communities + 1, slug = data.slug, title = data.title, description = data.description, createdBy = data.handleId, createdAt = at }
	return #db.communities
end

function P.Posts(filter)
	local list = {}
	for i = #db.posts, 1, -1 do
		local p = db.posts[i]
		if not p.removed and (not filter.communityId or p.communityId == filter.communityId) and (not filter.handleId or p.handleId == filter.handleId)
			and (not filter.since or p.createdAt >= filter.since) then
			list[#list + 1] = postRow(p)
		end
	end
	if filter.sort == 'top' then table.sort(list, function(a, b) return a.score > b.score end) end
	local result = {}
	for i = (filter.offset or 0) + 1, math.min(#list, (filter.offset or 0) + filter.limit) do result[#result + 1] = list[i] end
	return result
end
function P.PostById(id) return db.posts[id] and postRow(db.posts[id]) or false end
function P.LastPostAt(handleId)
	local last = 0
	for _, p in ipairs(db.posts) do if p.handleId == handleId then last = math.max(last, p.createdAt) end end
	return last
end
function P.InsertPost(data, at)
	db.posts[#db.posts + 1] = { id = #db.posts + 1, communityId = data.communityId, handleId = data.handleId, title = data.title, body = data.body, score = 0, comments = 0, removed = false, createdAt = at }
	return #db.posts
end
function P.RemovePost(id) if db.posts[id] then db.posts[id].removed = true end; return true end
function P.Comments(postId)
	local list = {}
	for _, c in ipairs(db.comments) do if c.postId == postId then local row = copy(c); row.author = handleName(c.handleId); list[#list + 1] = row end end
	return list
end
function P.CommentById(id) return db.comments[id] and copy(db.comments[id]) or false end
function P.LastCommentAt(handleId)
	local last = 0
	for _, c in ipairs(db.comments) do if c.handleId == handleId then last = math.max(last, c.createdAt) end end
	return last
end
function P.InsertComment(data, at)
	db.comments[#db.comments + 1] = { id = #db.comments + 1, postId = data.postId, parentId = data.parentId, handleId = data.handleId, body = data.body, score = 0, removed = false, createdAt = at }
	db.posts[data.postId].comments = db.posts[data.postId].comments + 1
	return #db.comments
end
function P.RemoveComment(id) if db.comments[id] then db.comments[id].removed = true end; return true end
function P.VoteOf(target, id, handleId) return db.votes[target .. id .. ':' .. handleId] or 0 end
function P.SetVote(target, id, handleId, value, delta)
	db.votes[target .. id .. ':' .. handleId] = value ~= 0 and value or nil
	local entry = target == 'p' and db.posts[id] or db.comments[id]
	entry.score = entry.score + delta
	return true
end
function P.VotesOf(handleId, target, ids)
	local map = {}
	for _, id in ipairs(ids) do map[id] = db.votes[target .. id .. ':' .. handleId] end
	return map
end
function P.HandleStats(handleId)
	local stats = { karma = 0, posts = 0, comments = 0 }
	for _, p in ipairs(db.posts) do if p.handleId == handleId and not p.removed then stats.karma = stats.karma + p.score; stats.posts = stats.posts + 1 end end
	for _, c in ipairs(db.comments) do if c.handleId == handleId and not c.removed then stats.karma = stats.karma + c.score; stats.comments = stats.comments + 1 end end
	return stats
end

local function listingRow(l)
	local row = copy(l)
	row.seller = l.sellerHandle and handleName(l.sellerHandle) or nil
	row.reputation = l.sellerHandle and db.handles[l.sellerHandle].reputation or 0
	return row
end
function P.Listings(filter)
	local list = {}
	for _, l in ipairs(db.listings) do
		local statusOk = (filter.status == 'any' and l.status ~= 'removed') or l.status == (filter.status or 'active')
		if statusOk and (not filter.category or l.category == filter.category) and (not filter.pattern or like(filter.pattern, l.title, l.description))
			and (not filter.sellerHandle or l.sellerHandle == filter.sellerHandle) and (not filter.npc or l.sellerHandle == nil) then
			list[#list + 1] = listingRow(l)
		end
	end
	local result = {}
	for i = (filter.offset or 0) + 1, math.min(#list, (filter.offset or 0) + filter.limit) do result[#result + 1] = list[i] end
	return result
end
function P.ListingById(id) return db.listings[id] and listingRow(db.listings[id]) or false end
function P.CountListings(handleId)
	local count = 0
	for _, l in ipairs(db.listings) do if l.sellerHandle == handleId and l.status ~= 'removed' then count = count + 1 end end
	return count
end
function P.InsertListing(data, at)
	local l = copy(data)
	l.id = #db.listings + 1
	l.status = data.status or 'active'
	l.vendor = data.vendor or ''
	l.payout = data.payout or ''
	l.sold = 0
	l.createdAt = at
	l.updatedAt = at
	db.listings[l.id] = l
	return l.id
end
function P.UpdateListing(id, data, at)
	local l = db.listings[id]
	for _, key in ipairs({ 'vendor', 'kind', 'category', 'title', 'description', 'item', 'count', 'price', 'stock', 'payout', 'status' }) do l[key] = data[key] end
	l.updatedAt = at
	return true
end
function P.SetListingStatus(id, status) db.listings[id].status = status; return true end
function P.TakeStock(id, quantity)
	local l = db.listings[id]
	if l.status ~= 'active' or l.stock < quantity then return false end
	l.stock = l.stock - quantity
	l.sold = l.sold + quantity
	return true
end
function P.ReturnStock(id, quantity) local l = db.listings[id]; l.stock = l.stock + quantity; l.sold = math.max(0, l.sold - quantity); return true end

local function orderRow(o)
	local row = copy(o)
	row.seller = o.sellerHandle and handleName(o.sellerHandle) or nil
	row.buyer = handleName(o.buyerHandle)
	row.rating = db.reviews[o.id] and db.reviews[o.id].rating or nil
	return row
end
function P.InsertOrder(data, at)
	local o = copy(data)
	o.id = #db.orders + 1
	o.createdAt = at
	o.deliveredAt = data.deliveredAt or 0
	o.closedAt = 0
	o.note = ''
	o.settled = false
	o.buyerCharacter = tostring(data.buyerCharacter)
	db.orders[o.id] = o
	return o.id
end
function P.OrderById(id) return db.orders[id] and orderRow(db.orders[id]) or false end
function P.OrdersOf(handleId, role)
	local list = {}
	for i = #db.orders, 1, -1 do
		local o = db.orders[i]
		if (role == 'seller' and o.sellerHandle == handleId) or (role ~= 'seller' and o.buyerHandle == handleId) then list[#list + 1] = orderRow(o) end
	end
	return list
end
function P.OrdersByStatus(status)
	local list = {}
	for _, o in ipairs(db.orders) do if o.status == status then list[#list + 1] = orderRow(o) end end
	return list
end
function P.MoveOrder(id, from, to, fields, at)
	local o = db.orders[id]
	if not o or o.status ~= from then return false end
	o.status = to
	fields = fields or {}
	if fields.delivered then o.deliveredAt = at end
	if fields.closed then o.closedAt = at end
	if fields.note then o.note = fields.note end
	return true
end
function P.MarkSettled(id) db.orders[id].settled = true; return true end
function P.UnsettledOrders()
	local list = {}
	local final = { completed = true, released = true, cancelled = true, refunded = true }
	for _, o in ipairs(db.orders) do if final[o.status] and not o.settled then list[#list + 1] = orderRow(o) end end
	return list
end
function P.InsertReview(data, at)
	if db.reviews[data.orderId] then return nil, 'already_reviewed' end
	db.reviews[data.orderId] = { rating = data.rating, body = data.body, seller = data.sellerHandle, buyer = data.buyerHandle, createdAt = at }
	db.handles[data.sellerHandle].reputation = db.handles[data.sellerHandle].reputation + data.rating - 3
	return true
end
function P.SellerReviews(handleId)
	local count, sum = 0, 0
	for _, r in pairs(db.reviews) do if r.seller == handleId then count = count + 1; sum = sum + r.rating end end
	return { count = count, average = count > 0 and sum / count or 0, recent = {} }
end

-- Carrega o resource -----------------------------------------------------------------------------------

dofile('server/main.lua')
dofile('server/sites.lua')
dofile('server/forum.lua')
dofile('server/market.lua')
dofile('server/admin.lua')
-- A inicialização (migrações, sementes) roda num thread; os sementes foram registrados depois, então roda de novo.
for _, co in ipairs(threads) do if coroutine.status(co) == 'suspended' then coroutine.resume(co) end end

local function call(playerId, action, payload)
	invoking = 'coe_phone'
	timer = timer + 1000
	return registered.TabletCall(playerId, 'onion', action, payload or {})
end

local function tablet(playerId, action, payload)
	invoking = 'coe_tablet'
	timer = timer + 1000
	return registered.TabletCall(playerId, 'onion', action, payload or {})
end

-- Sementes ---------------------------------------------------------------------------------------------
-- Os ganchos rodam no thread de inicialização, que já passou quando os módulos registraram os seus: roda à mão.
DeepwebSites.Seed(now)
for _, entry in ipairs(config.Forum.Communities) do P.InsertCommunity({ slug = entry.slug, title = entry.title, description = entry.description }, now) end
for _, vendor in ipairs(config.Market.Vendors) do
	local clean = DeepwebRules.Listing(config, vendor)
	clean.vendor = vendor.vendor
	P.InsertListing(clean, now)
end

eq(db.sites['rabbit.onion'].app, 'forum', 'site de sistema do Rabbit')
eq(#db.listings, #config.Market.Vendors, 'fornecedores NPC iniciais')

-- Apelidos de teste: 1 = comprador (celular), 2 = vendedor (celular), 3 = outro.
local FIXTURE = 'senha123'
eq(call(1, 'handleCreate', { name = 'comprador', password = FIXTURE }).ok, true, 'apelido do comprador')
eq(call(2, 'handleCreate', { name = 'vendedor', password = FIXTURE }).ok, true, 'apelido do vendedor')
eq(call(3, 'handleCreate', { name = 'curioso', password = FIXTURE }).ok, true, 'terceiro apelido')

-- Navegador --------------------------------------------------------------------------------------------
eq(call(1, 'state').browser.home, 'duckdark.onion', 'página inicial')
eq(call(1, 'site', { address = 'Rabbit.onion/r/geral' }).site.app, 'forum', 'resolve o domínio')
eq(call(1, 'site', { address = 'naoexiste.onion' }).error, 'not_found', 'serviço oculto inexistente')
eq(call(1, 'site', { address = 'about:rede' }).error, 'invalid_address', 'about: não é site')
eq(call(1, 'bookmarkAdd', { address = 'rabbit.onion/r/geral', title = 'Geral' }).ok, true, 'favorita')
eq(call(1, 'bookmarkAdd', { address = 'pen drive barato' }).error, 'invalid_address', 'busca não vira favorito')
eq(#call(1, 'bookmarks').bookmarks, 1, 'favoritos do aparelho')
eq(#call(2, 'bookmarks').bookmarks, 0, 'favoritos são por aparelho')
eq(call(1, 'bookmarkRemove', { address = 'rabbit.onion/r/geral' }).ok, true, 'remove favorito')
eq(#call(1, 'directory').sites, #config.Sites.System - 1, 'diretório com os sites de sistema listados')
eq(db.sites['fantasma.onion'].listed, false, 'fantasma fora do diretório')
eq(call(1, 'site', { address = 'fantasma.onion' }).site.profile.handle, 'fantasma', 'perfil vem do config')
eq(db.sites['deepmarket.onion'].app, 'market', 'Deep Market no novo domínio')

-- Leitura não sofre o intervalo mínimo entre chamadas.
local reads = 0
for _ = 1, 3 do
	invoking = 'coe_phone'
	if registered.TabletCall(1, 'onion', 'bookmarks', {}).ok then reads = reads + 1 end
end
eq(reads, 3, 'leituras seguidas liberadas')

-- Rabbit -----------------------------------------------------------------------------------------------
eq(call(1, 'forumSubmit', { slug = 'geral', title = 'Oi' }).error, 'invalid_title', 'título curto')
eq(call(1, 'forumSubmit', { slug = 'inexistente', title = 'Primeiro post' }).error, 'invalid_community', 'comunidade inexistente')
local posted = call(1, 'forumSubmit', { slug = 'geral', title = 'Primeiro post da toca', body = 'Alguém sabe onde fica o ponto?' })
eq(posted.ok, true, 'posta')
eq(call(1, 'forumSubmit', { slug = 'geral', title = 'Segundo post rápido' }).error, 'post_cooldown', 'intervalo entre posts')
local home = call(3, 'forumHome', {})
eq(#home.posts, 1, 'post aparece em alta')
eq(home.posts[1].handleId, nil, 'id interno do apelido não vai ao cliente')
eq(home.canCreate, false, 'celular não cria comunidade')
eq(call(1, 'forumVote', { target = 'p', id = posted.id, value = 1 }).error, 'own_content', 'não vota no próprio')
eq(call(3, 'forumVote', { target = 'p', id = posted.id, value = 1 }).delta, 1, 'voto positivo')
eq(call(3, 'forumVote', { target = 'p', id = posted.id, value = -1 }).delta, -2, 'troca o voto')
eq(call(3, 'forumVote', { target = 'p', id = posted.id, value = 0 }).delta, 1, 'tira o voto')
eq(db.posts[posted.id].score, 0, 'pontuação volta a zero')
local reply = call(3, 'forumComment', { postId = posted.id, body = 'No viaduto.' })
eq(reply.ok, true, 'comenta')
now = now + config.Forum.CommentCooldownSeconds
eq(call(1, 'forumComment', { postId = posted.id, parentId = reply.id, body = 'Valeu.' }).ok, true, 'responde comentário')
local thread = call(2, 'forumPost', { id = posted.id })
eq(#thread.comments, 2, 'dois comentários')
eq(thread.comments[2].depth, 1, 'resposta um nível abaixo')
eq(thread.post.canRemove, false, 'terceiro não remove o post')
eq(call(2, 'forumRemove', { target = 'c', id = reply.id }).error, 'forbidden', 'só autor ou moderador remove')
eq(call(3, 'forumRemove', { target = 'c', id = reply.id }).ok, true, 'autor remove o comentário')
eq(call(2, 'forumPost', { id = posted.id }).comments[1].author, nil, 'comentário removido sem autor')
eq(call(1, 'forumUser', { handle = 'curioso' }).commentCount, 0, 'perfil conta só o que não foi removido')
-- Criar comunidade: tablet é nível 2 (bloqueado); o limite vale no nível do aparelho.
eq(tablet(2, 'forumCreate', { slug = 'oficina', title = 'Oficina' }).error, 'tier_too_low', 'tablet não cria comunidade')
eq(call(1, 'forumHome', {}).posts[1].vote, 0, 'sem voto marcado')

-- Deep Market: fornecedor NPC--------------------------------------------------------------------------
local npc = db.listings[1]
local browse = call(1, 'marketHome', {})
eq(#browse.listings, #config.Market.Vendors, 'vitrine com fornecedores')
eq(browse.canBuy, false, 'celular só vê a vitrine')
eq(call(1, 'marketBuy', { id = npc.id, from = A1 }).error, 'tier_too_low', 'celular não compra')

-- Compras pelo tablet (nível 2): chave do tablet do personagem 2 não tem carteira; usa o celular para o resto.
db.sessions['tablet:11'] = 1
db.browsers['tablet:11'] = true
keys['tablet:11'] = { A1 }
local listingView = tablet(1, 'marketListing', { id = npc.id })
eq(listingView.canBuy, true, 'tablet compra')
eq(#listingView.wallets, 1, 'carteiras à mão para pagar')
eq(tablet(1, 'marketBuy', { id = npc.id, from = A3 }).error, 'no_key', 'sem a chave da carteira não paga')
local before = balances[A1]
local npcOrder = tablet(1, 'marketBuy', { id = npc.id, quantity = 2, from = A1 })
eq(npcOrder.ok, true, 'compra do fornecedor')
eq(npcOrder.status, 'dropped', 'mercadoria do fornecedor já no ponto')
eq(balances[A1], before - npc.price * 2 - 10, 'valor + taxa da rede saem da carteira')
eq(balances[ESCROW], npc.price * 2, 'valor em custódia')
eq(db.listings[npc.id].stock, config.Market.Vendors[1].stock - 2, 'estoque reservado')
local npcView = tablet(1, 'marketOrder', { id = npcOrder.orderId }).order
eq(npcView.drop ~= nil, true, 'comprador vê o ponto de coleta')
eq(npcView.actions[1], 'collect', 'pode coletar')
-- A coleta é pelo alvo no ponto: o site só arma o ponto (GPS + caixa com alvo).
eq(DeepwebMarket.DropUse(1, npcOrder.orderId).error, 'not_armed', 'sem armar pelo site o alvo não coleta')
positions[1] = { x = 0.0, y = 0.0, z = 0.0 }
local armed = tablet(1, 'marketAct', { id = npcOrder.orderId, action = 'collect' })
eq(armed.ok and armed.armed, true, 'site arma o ponto de coleta, mesmo longe')
eq(db.orders[npcOrder.orderId].status, 'dropped', 'armar não coleta')
eq(clientEvents[#clientEvents].name, 'coe_deepweb:drop:arm', 'client recebe o ponto armado')
eq(clientEvents[#clientEvents].args[1].orderId, npcOrder.orderId, 'ponto armado do pedido')
eq(clientEvents[#clientEvents].args[1].action, 'collect', 'ação do alvo')
eq(DeepwebMarket.DropUse(1, npcOrder.orderId).error, 'not_at_drop', 'longe do ponto não coleta')
eq(DeepwebMarket.DropUse(2, npcOrder.orderId).error, 'not_armed', 'outro jogador não usa o ponto armado')
local drop = config.Market.Drops[db.orders[npcOrder.orderId].dropIndex]
positions[1] = { x = drop.x + 1.0, y = drop.y + 1.0, z = drop.z + 2.5 }
inventoryFull = true
eq(DeepwebMarket.DropUse(1, npcOrder.orderId).error, 'inventory_full', 'inventário cheio (z do ponto não precisa ser exato)')
eq(db.orders[npcOrder.orderId].status, 'dropped', 'pedido volta ao ponto')
inventoryFull = false
eq(DeepwebMarket.DropUse(1, npcOrder.orderId).ok, true, 'coleta pelo alvo')
eq(clientEvents[#clientEvents].name, 'coe_deepweb:drop:clear', 'caixa some depois da coleta')
eq(DeepwebMarket.DropUse(1, npcOrder.orderId).error, 'not_armed', 'não coleta duas vezes')
eq(bag['character:11'].onion_usb, 2, 'itens no inventário')
eq(balances[RESERVE], npc.price * 2, 'pagamento do fornecedor vai para a reserva')
eq(balances[ESCROW], 0, 'custódia zerada')
eq(db.orders[npcOrder.orderId].settled, true, 'pedido liquidado')
eq(#alerts, 1, 'coleta pode chamar a atenção da polícia')

-- Deep Market: vendedor jogador (item)-----------------------------------------------------------------
-- O vendedor precisa de nível 3: usa o tablet + celular? Nível 3 é o notebook; simula pelo tipo do contexto.
local function laptop(playerId, action, payload)
	return DeepwebApp[action]({ playerId = playerId, character = tostring(characters[playerId]), kind = 'laptop', key = 'laptop:L' .. playerId, computer = true }, payload or {})
end
db.sessions['laptop:L2'] = 2
keys['laptop:L2'] = { A2 }
eq(laptop(2, 'marketSave', { title = 'Gazua profissional', category = 'tools', item = 'lockpick', count = 1, price = '0,5', stock = 3, payout = 'lixo' }).error, 'invalid_payout', 'carteira de recebimento inválida')
eq(laptop(2, 'marketSave', { title = 'Gazua profissional', category = 'tools', item = 'naoexiste', count = 1, price = '0,5', stock = 3, payout = A2 }).error, 'unknown_item', 'item inexistente')
local saved = laptop(2, 'marketSave', { title = 'Gazua profissional', category = 'tools', item = 'lockpick', count = 1, price = '0,5', stock = 3, payout = A2 })
eq(saved.ok, true, 'anuncia')
eq(db.listings[saved.id].price, 5000, 'preço em unidades')
eq(call(2, 'marketSave', { title = 'Outra coisa', category = 'tools', item = 'lockpick', count = 1, price = '1', stock = 1, payout = A2 }).error, 'tier_too_low', 'celular não anuncia')
eq(laptop(1, 'marketBuy', { id = saved.id, from = A1 }).error, 'not_signed_in', 'sem apelido no notebook não compra')
db.sessions['laptop:L1'] = 1
keys['laptop:L1'] = { A1 }
eq(laptop(2, 'marketBuy', { id = saved.id, from = A2 }).error, 'own_listing', 'não compra do próprio anúncio')
local order = laptop(1, 'marketBuy', { id = saved.id, quantity = 2, from = A1 })
eq(order.ok, true, 'compra do jogador')
eq(order.status, 'paid', 'espera o vendedor deixar')
eq(#notices > 0 and notices[#notices].playerId, 2, 'vendedor avisado')
local sellerView = laptop(2, 'marketOrder', { id = order.orderId }).order
eq(sellerView.drop ~= nil, true, 'vendedor vê onde deixar')
eq(sellerView.buyer, 'comprador', 'vendedor vê o apelido do comprador')
eq(laptop(1, 'marketOrder', { id = order.orderId }).order.drop, nil, 'comprador só vê o ponto depois da entrega')
eq(laptop(3, 'marketOrder', { id = order.orderId }).error, 'not_signed_in', 'terceiro sem sessão')
eq(laptop(1, 'marketAct', { id = order.orderId, action = 'cancel' }).error, 'too_early', 'comprador espera o prazo')
drop = config.Market.Drops[db.orders[order.orderId].dropIndex]
positions[2] = { x = drop.x, y = drop.y, z = drop.z }
bag['character:22'].lockpick = 1
eq(laptop(2, 'marketAct', { id = order.orderId, action = 'deliver' }).armed, true, 'vendedor arma o ponto de entrega')
eq(DeepwebMarket.DropUse(2, order.orderId).error, 'missing_items', 'sem os itens não entrega')
bag['character:22'].lockpick = 5
eq(DeepwebMarket.DropUse(2, order.orderId).ok, true, 'deixa no ponto pelo alvo')
eq(bag['character:22'].lockpick, 3, 'itens saem do vendedor')
eq(db.orders[order.orderId].status, 'dropped', 'pedido no ponto')
positions[1] = { x = drop.x, y = drop.y, z = drop.z }
eq(laptop(1, 'marketAct', { id = order.orderId, action = 'collect' }).armed, true, 'comprador arma a coleta')
eq(DeepwebMarket.DropUse(1, order.orderId).ok, true, 'comprador coleta pelo alvo')
local fee = DeepwebRules.Fee(10000, config.Market.FeeBps)
eq(balances[A2], 10000 - fee, 'vendedor recebe menos a taxa')
eq(balances[RESERVE], npc.price * 2 + fee, 'taxa vai para a reserva')
eq(laptop(1, 'marketReview', { id = order.orderId, rating = 5, body = 'Rápido.' }).ok, true, 'avalia')
eq(laptop(1, 'marketReview', { id = order.orderId, rating = 5 }).error, 'already_reviewed', 'uma avaliação por pedido')
eq(db.handles[2].reputation, 2, 'reputação do vendedor')

-- Cancelamento após o prazo e estorno
local late = laptop(1, 'marketBuy', { id = saved.id, quantity = 1, from = A1 })
eq(late.ok, true, 'segunda compra')
local balanceBefore = balances[A1]
now = now + config.Market.DeliverHours * 3600
eq(laptop(1, 'marketAct', { id = late.orderId, action = 'cancel' }).ok, true, 'cancela depois do prazo')
eq(balances[A1], balanceBefore + 5000, 'valor devolvido')
eq(db.listings[saved.id].stock, 3 - 2 - 1 + 1, 'estoque devolvido')

-- Serviço: entrega marcada, contestação e decisão da staff
local service = laptop(2, 'marketSave', { title = 'Rastreio de placa', kind = 'service', category = 'services', price = '1', stock = 5, payout = A2 })
eq(service.ok, true, 'anuncia serviço')
local job = laptop(1, 'marketBuy', { id = service.id, from = A1 })
eq(job.ok, true, 'contrata serviço')
eq(laptop(2, 'marketAct', { id = job.orderId, action = 'deliver' }).ok, true, 'vendedor marca como feito')
eq(laptop(1, 'marketAct', { id = job.orderId, action = 'dispute' }).error, 'invalid_note', 'contestação precisa de motivo')
eq(laptop(1, 'marketAct', { id = job.orderId, action = 'dispute', note = 'Não recebi nada.' }).ok, true, 'contesta')
invoking = 'coe_police'
eq(registered.AdminResolveOrder({ id = job.orderId, decision = 'buyer' }).error, 'forbidden', 'só o admin decide')
invoking = 'coe_admin'
local overview = registered.AdminOverview()
eq(overview.ready, true, 'panorama do admin')
local listed = false
for _, entry in ipairs(overview.orders) do if entry.id == job.orderId then listed = entry.status == 'disputed' end end
eq(listed, true, 'disputa no panorama')
local refundBefore = balances[A1]
eq(registered.AdminResolveOrder({ id = job.orderId, decision = 'buyer' }).ok, true, 'staff devolve')
eq(balances[A1], refundBefore + 10000, 'comprador recebe de volta')
eq(db.orders[job.orderId].status, 'refunded', 'pedido estornado')

-- Liberação automática e pagamento repetido quando a rede falha
invoking = 'coe_phone'
local auto = laptop(1, 'marketBuy', { id = service.id, from = A1 })
eq(laptop(2, 'marketAct', { id = auto.orderId, action = 'deliver' }).ok, true, 'serviço entregue')
local sellerBefore = balances[A2]
now = now + config.Market.AutoReleaseHours * 3600
releaseFails = true
DeepwebMarket.Tick()
eq(db.orders[auto.orderId].status, 'completed', 'liberado depois do prazo')
eq(db.orders[auto.orderId].settled, false, 'pagamento pendente com a rede fora')
releaseFails = false
DeepwebMarket.Tick()
eq(db.orders[auto.orderId].settled, true, 'pagamento repetido na rodada seguinte')
eq(balances[A2], sellerBefore + 10000 - DeepwebRules.Fee(10000, config.Market.FeeBps), 'vendedor pago uma vez só')

-- Busca ------------------------------------------------------------------------------------------------
local found = call(3, 'search', { q = 'gazua' })
eq(found.ok, true, 'busca')
eq(#found.listings, 1, 'acha o anúncio')
eq(#call(3, 'search', { q = 'toca' }).posts, 1, 'acha o post')
eq(#call(3, 'search', { q = 'mercado' }).sites >= 1, true, 'acha o site pelas palavras-chave')
eq(call(3, 'search', { q = 'a' }).error, 'invalid_query', 'busca curta')
eq(#call(3, 'search', { q = 'fantasma.onion' }).sites, 0, 'fantasma não aparece na busca')

-- Contato com a staff (fantasma.onion) -----------------------------------------------------------------
invoking = 'coe_phone'
eq(call(3, 'contactSend', { domain = 'rabbit.onion', body = 'Mensagem qualquer aqui.' }).error, 'not_found', 'site sem contato')
eq(call(3, 'contactSend', { domain = 'fantasma.onion', body = 'curta' }).error, 'invalid_message', 'mensagem curta')
local contact = call(3, 'contactSend', { domain = 'fantasma.onion', body = 'Preciso de ajuda com um contrato.' })
eq(contact.ok, true, 'envia contato')
eq(call(3, 'contactSend', { domain = 'fantasma.onion', body = 'Segunda mensagem seguida.' }).error, 'contact_cooldown', 'intervalo entre mensagens')
for _ = 2, config.Contact.MaxOpen do
	now = now + config.Contact.CooldownSeconds
	eq(call(3, 'contactSend', { domain = 'fantasma.onion', body = 'Mais uma mensagem aberta.' }).ok, true, 'outra mensagem')
end
now = now + config.Contact.CooldownSeconds
eq(call(3, 'contactSend', { domain = 'fantasma.onion', body = 'Uma além do limite.' }).error, 'contact_limit', 'limite de abertas')
eq(#call(3, 'contactThread', { domain = 'fantasma.onion' }).messages, config.Contact.MaxOpen, 'histórico do apelido')
eq(#call(1, 'contactThread', { domain = 'fantasma.onion' }).messages, 0, 'outro apelido não vê')
invoking = 'coe_police'
eq(registered.AdminReplyContact({ id = contact.id, reply = 'Ok.' }).error, 'forbidden', 'só o admin responde')
invoking = 'coe_admin'
eq(registered.AdminReplyContact({ id = contact.id, reply = '' }).error, 'invalid_reply', 'resposta vazia')
local noticesBefore = #notices
eq(registered.AdminReplyContact({ id = contact.id, reply = 'Fala no privado.' }).ok, true, 'staff responde')
eq(#notices, noticesBefore + 1, 'avisa o apelido online')
eq(db.contacts[contact.id].status, 'answered', 'mensagem respondida')
eq(#registered.AdminOverview().contacts, config.Contact.MaxOpen, 'contatos no panorama')
eq(registered.AdminCloseContact({ id = contact.id }).ok, true, 'arquiva')
eq(registered.AdminReplyContact({ id = contact.id, reply = 'Tarde demais.' }).error, 'contact_closed', 'arquivada não recebe resposta')
eq(registered.AdminCloseContact({ id = 999 }).error, 'not_found', 'contato inexistente')
invoking = 'coe_phone'
eq(call(3, 'contactThread', { domain = 'fantasma.onion' }).messages[config.Contact.MaxOpen].reply, 'Fala no privado.', 'resposta na página')

-- Admin: sites por blocos e fornecedores ---------------------------------------------------------------
invoking = 'coe_admin'
eq(registered.AdminSaveSite({ domain = 'rabbit.onion', title = 'Falso' }).error, 'domain_reserved', 'não sobrescreve sistema')
local site = registered.AdminSaveSite({
	domain = 'Faca-Afiada', title = 'Faca Afiada', description = 'Serviços de quem não aparece.', keywords = 'servico',
	blocks = { { type = 'heading', text = 'Bem-vindo' }, { type = 'text', text = 'Fale com a gente no Rabbit.' }, { type = 'link', label = 'Rabbit', href = 'rabbit.onion' } }
})
eq(site.ok, true, 'cria site por blocos')
eq(site.domain, 'faca-afiada.onion', 'domínio normalizado')
eq(registered.AdminSaveSite({ domain = 'ruim', title = 'Ruim', blocks = { { type = 'script', text = 'x' } } }).error, 'invalid_block', 'bloco desconhecido recusado')
invoking = 'coe_phone'
eq(call(3, 'site', { address = 'faca-afiada.onion' }).site.title, 'Faca Afiada', 'site novo no ar')
invoking = 'coe_admin'
local vendor = registered.AdminSaveVendor({ vendor = 'Fantasma', title = 'Gazua de fábrica', category = 'tools', item = 'lockpick', count = 2, price = '0,25', stock = 10 })
eq(vendor.ok, true, 'fornecedor novo')
eq(db.listings[vendor.id].sellerHandle, nil, 'fornecedor sem apelido')
eq(registered.AdminSaveVendor({ id = saved.id, vendor = 'X', title = 'Tomar anúncio', category = 'tools', item = 'lockpick', count = 1, price = '1', stock = 1 }).error, 'not_found', 'admin não edita anúncio de jogador como fornecedor')
eq(registered.AdminDeleteVendor({ id = vendor.id }).ok, true, 'remove fornecedor')
eq(registered.AdminRemovePost({ id = posted.id }).ok, true, 'staff remove post')
eq(registered.AdminDeleteSite({ domain = 'faca-afiada' }).ok, true, 'apaga site')

if failures > 0 then
	print(('%d falha(s)'):format(failures))
	os.exit(1)
end
print('deepweb web_test: ok')
