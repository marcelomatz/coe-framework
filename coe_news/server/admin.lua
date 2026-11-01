-- Painel da staff (aba Imprensa do coe_admin). Só os resources de `AdminResources` chamam estes exports; quem
-- chama confere a permissão do operador (coe_admin.news.manage). Toda ação que muda dados é auditada.
local S = NewsServer
local config = S.config
local remote = S.remote
local DAY = 86400

local _t = function(key, params)
	if Core and Core.Locale and Core.Locale.New then
		return Core.Locale.New({ default = Core.Locale.GetDefaultLang(), locales = Locales or {} })(key, params)
	end
	if Locales and Locales['pt-BR'] and Locales['pt-BR'][key] then
		return Locales['pt-BR'][key]
	end
	return key
end

local function allowed()
	return config.AdminResources[GetInvokingResource()] == true
end

local function failure(errorCode)
	return { error = errorCode }
end

local function adminTag(payload)
	local id = math.tointeger(tonumber(payload and payload.admin))
	return id and ('admin:' .. id) or 'admin'
end

-- Baú do estoque de equipamento: o `Equipment.Stash` do negócio ou, se não existir, o primeiro baú.
local function equipmentStash(outlet)
	local business = remote('coe_businesses', 'Get', outlet.business)
	local stashes = type(business) == 'table' and type(business.stations) == 'table' and business.stations.stashes or nil
	if type(stashes) ~= 'table' or #stashes == 0 then
		return nil, 'no_stash'
	end
	local station = stashes[1]
	for _, entry in ipairs(stashes) do
		if entry.id == config.Equipment.Stash then
			station = entry
		end
	end
	return {
		id = ('stash:business:%s:%s'):format(outlet.business, station.id),
		label = station.label or station.id,
		slots = math.tointeger(station.slots) or config.Equipment.StashSlots,
		maxWeight = math.tointeger(station.maxWeight)
	}, nil, business
end

-- O inventário do baú nasce na primeira abertura; o admin pode abastecer antes disso.
local function ensureStash(stash)
	if type(remote('coe_inventory', 'GetInventory', stash.id)) == 'table' then
		return true
	end
	remote('coe_inventory', 'CreateInventory', stash.id, stash.slots, stash.maxWeight)
	return type(remote('coe_inventory', 'GetInventory', stash.id)) == 'table'
end

local function count(inventoryId, name)
	return math.tointeger(remote('coe_inventory', 'GetItemCount', inventoryId, name, nil, false)) or 0
end

local function outletOf(payload)
	local id = type(payload) == 'table' and payload.outlet or nil
	local outlet = type(id) == 'string' and config.Outlets[id] or nil
	return outlet, id
end

-- Visão geral ---------------------------------------------------------------------------------------------

exports('AdminOverview', function()
	if not allowed() then
		return failure('forbidden')
	end
	if not S.isReady() then
		return failure('not_ready')
	end
	local since = os.time() - 30 * DAY
	local list = {}
	for id, outlet in pairs(config.Outlets) do
		local data = S.outlets[id] or {}
		local balance = remote('coe_economy', 'SocietyBalance', outlet.business)
		list[#list + 1] = {
			id = id, label = outlet.label, color = outlet.color, region = outlet.region, business = outlet.business,
			tagline = data.tagline, editorial = data.editorial, sections = data.sections, adPrice = data.adPrice,
			stats = NewsPersistence.Stats(id, since),
			balance = type(balance) == 'number' and balance or nil
		}
	end
	table.sort(list, function(first, second)
		return first.label < second.label
	end)
	local equipment = {}
	for index, item in ipairs(config.Equipment.Items) do
		equipment[index] = { name = item.name, label = item.label }
	end
	return {
		available = true,
		outlets = list,
		sections = config.Sections,
		equipment = equipment,
		suggestedVehicles = config.SuggestedVehicles,
		limits = {
			maxPerOperation = config.Equipment.MaxPerOperation,
			minPrice = config.Ads.MinPricePerDay, maxPrice = config.Ads.MaxPricePerDay,
			taglineMax = config.Editorial.TaglineMax, editorialMax = config.Editorial.EditorialMax,
			noteMax = config.Ads.NoteMax
		}
	}
end)

-- Consultas sob demanda -----------------------------------------------------------------------------------

local function adminAd(ad)
	local view = S.adView(ad)
	view.buyerName = ad.buyerName ~= '' and ad.buyerName or nil
	view.buyerId = ad.buyerId
	view.decidedAt = ad.decidedAt
	return view
end

local function adminArticle(article, withBody)
	return {
		id = article.id, section = article.section, status = article.status, title = article.title, summary = article.summary,
		body = withBody and article.body or nil, authorName = article.authorName, anonymous = article.anonymous,
		breaking = article.breaking, views = article.views, note = article.note, editorName = article.editorName,
		createdAt = article.createdAt, updatedAt = article.updatedAt, publishedAt = article.publishedAt,
		hasImage = article.image ~= ''
	}
end

local Queries = {}

function Queries.ads(id, filter)
	local statuses = NewsRules.AdGroups[filter.group] or NewsRules.AdGroups.pending
	local list = NewsPersistence.AdminAds(id, statuses, 60)
	if not list then
		return failure('database_error')
	end
	local result = {}
	for index, ad in ipairs(list) do
		result[index] = adminAd(ad)
	end
	return { ads = result }
end

function Queries.articles(id, filter)
	local parsed = NewsRules.ArticleFilter(filter, config.Articles.SearchMax)
	local list = NewsPersistence.AdminArticles(id, parsed.status, parsed.search, 60)
	if not list then
		return failure('database_error')
	end
	local result = {}
	for index, article in ipairs(list) do
		result[index] = adminArticle(article, false)
	end
	return { articles = result }
end

function Queries.article(id, filter)
	local article, errorCode = S.loadArticle(id, filter.id)
	if not article then
		return failure(errorCode)
	end
	return { article = adminArticle(article, true) }
end

-- Estoque no baú do veículo e quem da equipe (ou o dono) está com cada equipamento.
function Queries.equipment(id)
	local outlet = config.Outlets[id]
	local stash, stashError, business = equipmentStash(outlet)
	if not stash then
		return failure(stashError)
	end
	local people = {}
	if type(business.owner) == 'table' and business.owner.characterId then
		people[#people + 1] = { characterId = tostring(business.owner.characterId), name = business.owner.name, owner = true }
	end
	for _, member in ipairs(type(business.staff) == 'table' and business.staff or {}) do
		people[#people + 1] = { characterId = tostring(member.characterId), name = member.name }
	end
	local stashExists = type(remote('coe_inventory', 'GetInventory', stash.id)) == 'table'
	local items = {}
	for index, item in ipairs(config.Equipment.Items) do
		local holders = {}
		for _, person in ipairs(people) do
			local amount = count('character:' .. person.characterId, item.name)
			if amount > 0 then
				holders[#holders + 1] = { name = person.name or person.characterId, count = amount, owner = person.owner == true }
			end
		end
		items[index] = { name = item.name, label = item.label, stock = stashExists and count(stash.id, item.name) or 0, holders = holders }
	end
	return { stash = { id = stash.id, label = stash.label }, items = items }
end

exports('AdminQuery', function(kind, payload)
	if not allowed() then
		return failure('forbidden')
	end
	if not S.isReady() then
		return failure('not_ready')
	end
	local query = type(kind) == 'string' and rawget(Queries, kind)
	local outlet, id = outletOf(payload)
	if not query or not outlet then
		return failure('invalid_query')
	end
	return query(id, payload)
end)

-- Ações ---------------------------------------------------------------------------------------------------

local Actions = {}

function Actions.editorial(id, payload)
	local data, errorCode = NewsRules.Editorial(config, payload)
	if not data then
		return failure(errorCode)
	end
	if not NewsPersistence.SaveOutlet(id, data, os.time(), nil) then
		return failure('database_error')
	end
	local current = S.outlets[id]
	current.tagline, current.editorial, current.sections, current.adPrice = data.tagline, data.editorial, data.sections, data.adPrice
	S.audit('news_editorial_updated', { source = adminTag(payload), operation = id, count = data.adPrice })
	return { ok = true }
end

local function pendingAd(id, payload)
	local ad, errorCode = S.loadAd(id, payload.id)
	if not ad then
		return nil, errorCode
	end
	if ad.status ~= 'pending' then
		return nil, 'ad_decided'
	end
	return ad
end

local function decide(approve)
	return function(id, payload)
		local ad, errorCode = pendingAd(id, payload)
		if not ad then
			return failure(errorCode)
		end
		local note = NewsRules.Text(payload.note, config.Ads.NoteMax) or ''
		local result = S.decideAd(ad, approve, note, { admin = adminTag(payload) })
		if not result.ok then
			return failure(result.error)
		end
		S.audit(approve and 'news_ad_approved_admin' or 'news_ad_rejected_admin',
			{ source = adminTag(payload), operation = id, target = tostring(ad.id), count = ad.price })
		return { ok = true }
	end
end

Actions.adApprove = decide(true)
Actions.adReject = decide(false)

-- Devolve `amount` a quem pagou o anúncio.
local function refundPayer(ad, amount)
	if ad.payerKind == 'business' then
		return remote('coe_economy', 'SocietyCollect', ad.payerRef, amount, 'news_ad_refund') == true
	end
	return remote('coe_economy', 'Credit', ad.buyerId, amount, 'news_ad_refund', 'news_ad:' .. ad.id) == true
end

-- Tira do ar. Com estorno, o valor sai do caixa do veículo (que recebeu na aprovação) e volta para quem pagou.
function Actions.adTakedown(id, payload)
	local ad, errorCode = S.loadAd(id, payload.id)
	if not ad then
		return failure(errorCode)
	end
	if ad.status ~= 'active' then
		return failure('ad_not_active')
	end
	local outlet = config.Outlets[id]
	local note = NewsRules.Text(payload.note, config.Ads.NoteMax) or ''
	return S.withLock('ad:' .. ad.id, function()
		local now = os.time()
		local amount = NewsRules.TakedownRefund(ad, now, payload.refund)
		if not NewsPersistence.TakedownAd(ad.id, note, now) then
			return failure('conflict')
		end
		if amount > 0 then
			local charged = remote('coe_economy', 'SocietyCharge', outlet.business, amount, 'news_ad_refund', 'news_ad:' .. ad.id)
			if charged ~= true then
				NewsPersistence.RestoreAd(ad.id, ad.endsAt)
				return failure(type(charged) == 'table' and charged.error == 'insufficient_funds' and 'outlet_insufficient_funds' or 'payment_failed')
			end
			if not refundPayer(ad, amount) then
				remote('coe_economy', 'SocietyCollect', outlet.business, amount, 'news_ad')
				NewsPersistence.RestoreAd(ad.id, ad.endsAt)
				S.log('error', 'gameplay', 'news_ad_refund_failed', { operation = tostring(ad.id), count = amount })
				return failure('refund_failed')
			end
		end
		S.audit('news_ad_removed_admin', { source = adminTag(payload), operation = id, target = tostring(ad.id), count = amount })
		local formattedAmount = (Core and Core.Locale and Core.Locale.FormatMoney) and Core.Locale.FormatMoney(amount) or string.format('$%d', amount)
		S.notifyCharacter(ad.buyerId, 'info', amount > 0
			and _t('ad_removed_refund', { outlet = outlet.label, title = ad.title, amount = formattedAmount })
			or _t('ad_removed', { outlet = outlet.label, title = ad.title }))
		return { ok = true, refunded = amount }
	end)
end

local function articleStatus(from, to, event)
	return function(id, payload)
		local article, errorCode = S.loadArticle(id, payload.id)
		if not article then
			return failure(errorCode)
		end
		if article.status ~= from then
			return failure('invalid_status')
		end
		local note = NewsRules.Text(payload.note, config.Articles.NoteMax) or ''
		local done = S.withLock('article:' .. article.id, function()
			return NewsPersistence.SetStatus(article.id, from, to, { note = note, editorName = 'Staff', breaking = false }, os.time())
		end)
		if done ~= true then
			return failure(type(done) == 'table' and done.error or 'conflict')
		end
		S.audit(event, { source = adminTag(payload), operation = id, target = tostring(article.id) })
		return { ok = true }
	end
end

Actions.articleUnpublish = articleStatus('published', 'unpublished', 'news_article_unpublished_admin')
Actions.articleRepublish = articleStatus('unpublished', 'published', 'news_article_republished_admin')

function Actions.articleDelete(id, payload)
	local article, errorCode = S.loadArticle(id, payload.id)
	if not article then
		return failure(errorCode)
	end
	local done = S.withLock('article:' .. article.id, function()
		return NewsPersistence.DeleteArticle(article.id, article.status)
	end)
	if done ~= true then
		return failure(type(done) == 'table' and done.error or 'conflict')
	end
	S.deletePhoto(article.image)
	S.audit('news_article_removed_admin', { source = adminTag(payload), operation = id, target = tostring(article.id) })
	return { ok = true }
end

-- Abastece ou retira equipamento do baú do veículo.
function Actions.stock(id, payload)
	local change, errorCode = NewsRules.StockChange(config, payload)
	if not change then
		return failure(errorCode)
	end
	local stash, stashError = equipmentStash(config.Outlets[id])
	if not stash then
		return failure(stashError)
	end
	if not ensureStash(stash) then
		return failure('stash_unavailable')
	end
	local done
	if change.op == 'add' then
		done = remote('coe_inventory', 'AddItem', stash.id, change.item, change.count)
	else
		done = remote('coe_inventory', 'RemoveItemByName', stash.id, change.item, change.count)
	end
	if not done then
		return failure(change.op == 'add' and 'stash_full' or 'insufficient_items')
	end
	S.audit(change.op == 'add' and 'news_equipment_added' or 'news_equipment_removed',
		{ source = adminTag(payload), operation = id, item = change.item, count = change.count })
	return { ok = true }
end

exports('AdminAction', function(op, payload)
	if not allowed() then
		return failure('forbidden')
	end
	if not S.isReady() then
		return failure('not_ready')
	end
	local action = type(op) == 'string' and rawget(Actions, op)
	local outlet, id = outletOf(payload)
	if not action or not outlet then
		return failure('invalid_action')
	end
	return action(id, payload)
end)
