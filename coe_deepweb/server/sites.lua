-- Navegador onion: favoritos por aparelho, sites da rede (sistema e por blocos) e o buscador DuckDark.
local config = DeepwebConfig
local App = DeepwebApp
local S = DeepwebServer
DeepwebSites = {}

local function fail(code)
	return { ok = false, error = code }
end

-- Favoritos ---------------------------------------------------------------------------------------------

function App.bookmarks(context)
	local list = DeepwebPersistence.Bookmarks(context.key)
	if not list then
		return fail('database_error')
	end
	return { ok = true, bookmarks = list }
end

function App.bookmarkAdd(context, payload)
	local target = DeepwebRules.ParseAddress(payload.address)
	if not target or target.kind == 'search' then
		return fail('invalid_address')
	end
	local title = DeepwebRules.Text(payload.title, config.Browser.TitleMax) or target.href
	local list = DeepwebPersistence.Bookmarks(context.key)
	if not list then
		return fail('database_error')
	end
	local exists = false
	for _, entry in ipairs(list) do
		if entry.address == target.href then
			exists = true
		end
	end
	if not exists and #list >= config.Browser.MaxBookmarks then
		return fail('bookmark_limit')
	end
	if not DeepwebPersistence.AddBookmark(context.key, target.href, title, os.time()) then
		return fail('database_error')
	end
	return { ok = true, address = target.href }
end

function App.bookmarkRemove(context, payload)
	if type(payload.address) ~= 'string' or #payload.address > 200 then
		return fail('invalid_address')
	end
	if not DeepwebPersistence.RemoveBookmark(context.key, payload.address) then
		return fail('database_error')
	end
	return { ok = true }
end

-- Sites -------------------------------------------------------------------------------------------------

-- Sites de sistema por domínio (perfil e contato vêm do config, não do banco).
local function systemEntry(domain)
	for _, entry in ipairs(config.Sites.System) do
		if entry.domain == domain then
			return entry
		end
	end
	return nil
end

local function siteView(site)
	local entry = site.app ~= '' and systemEntry(site.domain) or nil
	return {
		domain = site.domain, app = site.app, title = site.title, description = site.description, blocks = site.blocks, updatedAt = site.updatedAt,
		profile = entry and entry.profile or nil
	}
end

-- Resolve um domínio: sistema (app) ou páginas por blocos. Desconhecido ou fora do ar: not_found (o navegador mostra
-- o erro de serviço oculto inalcançável).
function App.site(context, payload)
	local target = DeepwebRules.ParseAddress(payload.address)
	if not target or target.kind ~= 'site' then
		return fail('invalid_address')
	end
	local site = DeepwebPersistence.SiteByDomain(target.domain)
	if site == nil then
		return fail('database_error')
	end
	if not site or not site.active then
		return fail('not_found')
	end
	return { ok = true, site = siteView(site) }
end

-- DuckDark ----------------------------------------------------------------------------------------------

function App.search(context, payload)
	local denied = S.RequireFeature(context, 'search')
	if denied then
		return fail(denied)
	end
	local text, pattern = DeepwebRules.SearchTerm(payload.q)
	if not text then
		return fail('invalid_query')
	end
	local sites = DeepwebPersistence.SearchSites(pattern, 10)
	local posts = DeepwebPersistence.SearchPosts(pattern, 10)
	local listings = DeepwebPersistence.Listings({ pattern = pattern, limit = 10 })
	if not sites or not posts or not listings then
		return fail('database_error')
	end
	local items = {}
	for _, listing in ipairs(listings) do
		items[#items + 1] = {
			id = listing.id, title = listing.title, description = listing.description:sub(1, 200), price = listing.price,
			priceText = S.Call('coe_crypto', 'Format', listing.price), seller = listing.seller or listing.vendor, npc = listing.sellerHandle == nil
		}
	end
	return { ok = true, query = text, sites = sites, posts = posts, listings = items }
end

-- Sites que a rede conhece (página inicial do DuckDark: "diretório").
function App.directory()
	local list = DeepwebPersistence.Sites()
	if not list then
		return fail('database_error')
	end
	local sites = {}
	for _, site in ipairs(list) do
		if site.active and site.listed ~= false then
			sites[#sites + 1] = { domain = site.domain, app = site.app, title = site.title, description = site.description }
		end
	end
	return { ok = true, sites = sites }
end

-- Contato (sites de perfil) ------------------------------------------------------------------------------

local function contactSite(domain)
	local entry = type(domain) == 'string' and systemEntry(domain)
	return entry and entry.profile and entry.profile.contact == true and entry or nil
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

local function contactView(entry)
	return { id = entry.id, body = entry.body, reply = entry.reply, status = entry.status, createdAt = entry.createdAt, repliedAt = entry.repliedAt }
end

-- Mensagens do apelido conectado para o site (com as respostas da staff).
function App.contactThread(context, payload)
	local entry = contactSite(payload.domain)
	if not entry then
		return fail('not_found')
	end
	local session, errorCode = signedIn(context)
	if not session then
		return fail(errorCode)
	end
	local list = DeepwebPersistence.ContactsOf(session.id, entry.domain, config.Contact.Shown)
	if not list then
		return fail('database_error')
	end
	local messages = {}
	for _, message in ipairs(list) do
		messages[#messages + 1] = contactView(message)
	end
	return { ok = true, handle = session.handle, messages = messages }
end

function App.contactSend(context, payload)
	local entry = contactSite(payload.domain)
	if not entry then
		return fail('not_found')
	end
	local session, errorCode = signedIn(context)
	if not session then
		return fail(errorCode)
	end
	local limits = config.Contact
	local body = DeepwebRules.Text(payload.body, limits.BodyMax, true, limits.BodyMin)
	if not body then
		return fail('invalid_message')
	end
	local now = os.time()
	return S.WithLock('contact:' .. session.id, function()
		local stats = DeepwebPersistence.ContactStats(session.id, entry.domain)
		if not stats then
			return fail('database_error')
		end
		if now - stats.last < limits.CooldownSeconds then
			return fail('contact_cooldown')
		end
		if stats.open >= limits.MaxOpen then
			return fail('contact_limit')
		end
		local id = DeepwebPersistence.InsertContact({ site = entry.domain, handleId = session.id, body = body }, now)
		if not id then
			return fail('database_error')
		end
		S.Audit('deepweb_contact_sent', { target = 'contact:' .. id, result = entry.domain })
		return { ok = true, id = id }
	end)
end

for _, action in ipairs({ 'bookmarks', 'site', 'search', 'directory', 'contactThread' }) do
	S.ReadOnly(action)
end

-- Sites de sistema: recriados a cada início com os dados do config.
function DeepwebSites.Seed(now)
	for _, entry in ipairs(config.Sites.System) do
		DeepwebPersistence.SaveSite({
			domain = entry.domain, app = entry.app, title = entry.title, description = entry.description, keywords = entry.keywords or '',
			blocks = nil, active = true, listed = entry.listed ~= false
		}, now)
	end
end

-- Site por blocos (staff no admin; jogadores na fase de hospedagem). raw: { domain, title, description, keywords,
-- blocks = { ... }, active, listed }. listed = false: fora do diretório e da busca. Devolve { ok, domain } ou { error }.
function DeepwebSites.Save(raw, ownerHandle, encode)
	if type(raw) ~= 'table' then
		return { error = 'invalid_site' }
	end
	local domain, errorCode = DeepwebRules.Domain(config, raw.domain)
	if not domain then
		return { error = errorCode }
	end
	local limits = config.Sites
	local title = DeepwebRules.Text(raw.title, limits.TitleMax)
	if not title then
		return { error = 'invalid_title' }
	end
	local description = raw.description == nil and '' or DeepwebRules.Text(raw.description, limits.DescriptionMax, false, 0)
	local keywords = raw.keywords == nil and '' or DeepwebRules.Text(raw.keywords, limits.KeywordsMax, false, 0)
	if not description or not keywords then
		return { error = 'invalid_description' }
	end
	local blocks, blockError, index = DeepwebRules.Blocks(config, raw.blocks or {})
	if not blocks then
		return { error = blockError, index = index }
	end
	local existing = DeepwebPersistence.SiteByDomain(domain)
	if existing == nil then
		return { error = 'database_error' }
	end
	if existing and existing.app ~= '' then
		return { error = 'domain_reserved' }
	end
	if existing and ownerHandle and existing.ownerHandle ~= ownerHandle then
		return { error = 'domain_taken' }
	end
	if not DeepwebPersistence.SaveSite({
		domain = domain, app = '', title = title, description = description, keywords = keywords, blocks = encode(blocks),
		ownerHandle = ownerHandle, active = raw.active ~= false, listed = raw.listed ~= false
	}, os.time()) then
		return { error = 'database_error' }
	end
	return { ok = true, domain = domain }
end

S.OnReady(function()
	DeepwebSites.Seed(os.time())
end)
