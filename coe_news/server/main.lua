local config = NewsConfig

local ready = false
local outlets = {}
local locks = {}
local lockManager = NewsRules and NewsRules.NewLockManager and NewsRules.NewLockManager() or nil
local lastSave = {}
local saveLimiter = NewsRules and NewsRules.NewSaveLimiter and NewsRules.NewSaveLimiter(config and config.Articles and config.Articles.SaveCooldownSeconds or 3) or nil
local viewed = {}

local HOSTS = { coe_tablet = 'tablet', coe_phone = 'phone' }
local DAY = 86400
local SECTION_LABELS = NewsRules.SectionLabels(config)
local App = {}

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

local _t = function(key, params)
	if Core and Core.Locale and Core.Locale.New then
		return Core.Locale.New({ default = Core.Locale.GetDefaultLang(), locales = Locales or {} })(key, params)
	end
	if Locales and Locales['pt-BR'] and Locales['pt-BR'][key] then
		return Locales['pt-BR'][key]
	end
	return key
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
	local arguments = { ... }
	local ok, result, extra = pcall(function()
		return exports[resource][name](exports[resource], table.unpack(arguments))
	end)
	if not ok then
		return nil
	end
	return result, extra
end

local function characterOf(playerId)
	local snapshot = Core.Players.GetActiveCharacter(playerId)
	if type(snapshot) ~= 'table' or not snapshot.characterId then
		return nil
	end
	local name = (((snapshot.firstName or '') .. ' ' .. (snapshot.lastName or '')):gsub('^%s+', ''):gsub('%s+$', ''))
	return { id = tostring(snapshot.characterId), name = name }
end

local function playerOf(characterId)
	for _, playerId in ipairs(GetPlayers()) do
		local character = characterOf(tonumber(playerId))
		if character and character.id == tostring(characterId) then
			return tonumber(playerId)
		end
	end
	return nil
end

local function notifyCharacter(characterId, kind, message)
	local playerId = playerOf(characterId)
	if playerId then
		notify(playerId, kind, message)
	end
end

local function withLock(key, run)
	if lockManager then
		local guard <close>, err = lockManager:acquireMulti({ tostring(key) }, 0)
		if not guard then
			return { ok = false, error = err == 'lock_timeout' and 'busy' or err }
		end
		local ok, result = pcall(run)
		if not ok then
			log('error', 'gameplay', 'news_action_failed', { error_code = tostring(result) })
			return { ok = false, error = 'database_error' }
		end
		return result
	end
	if locks[key] then
		return { ok = false, error = 'busy' }
	end
	locks[key] = true
	local ok, result = pcall(run)
	locks[key] = nil
	if not ok then
		log('error', 'gameplay', 'news_action_failed', { error_code = tostring(result) })
		return { ok = false, error = 'database_error' }
	end
	return result
end

-- Papel do personagem no veículo: vem do negócio (equipe, cargo e ponto). O dono tem todas as permissões.
local function roleOf(outlet, character)
	local business = outlet.business
	local access = remote('coe_businesses', 'Access', business, character.id)
	local member = type(access) == 'table' and (access.owner == true or access.staff == true)
	local function can(permission)
		return member and remote('coe_businesses', 'Can', business, character.id, permission) == true or false
	end
	return {
		member = member or false,
		owner = type(access) == 'table' and access.owner == true or false,
		write = can('news.write'),
		publish = can('news.publish'),
		ads = can('news.ads'),
		editorial = can('news.editorial')
	}
end

local function sectionList(ids)
	local list = {}
	for _, id in ipairs(ids) do
		list[#list + 1] = { id = id, label = SECTION_LABELS[id] or id }
	end
	return list
end

-- Matéria para o público: anônima não expõe o autor.
local function publicArticle(article)
	return {
		id = article.id, section = article.section, sectionLabel = SECTION_LABELS[article.section] or article.section,
		title = article.title, summary = article.summary, body = article.body, image = article.image,
		byline = NewsRules.Byline(article), breaking = article.breaking, views = article.views, publishedAt = article.publishedAt
	}
end

-- Matéria na mesa da redação (equipe): autor, status, observação do editor.
local function deskArticle(article, character)
	local item = publicArticle(article)
	item.status, item.authorName, item.anonymous = article.status, article.authorName, article.anonymous
	item.note, item.editorName, item.updatedAt = article.note, article.editorName, article.updatedAt
	item.mine = article.authorId == character.id
	return item
end

local function publicAd(ad)
	return { id = ad.id, advertiser = ad.advertiser, title = ad.title, body = ad.body }
end

local function adView(ad)
	return {
		id = ad.id, advertiser = ad.advertiser, title = ad.title, body = ad.body, days = ad.days, price = ad.price,
		status = ad.status, note = ad.note, createdAt = ad.createdAt, endsAt = ad.endsAt,
		payer = ad.payerKind == 'business' and ('business:' .. ad.payerRef) or 'personal'
	}
end

-- Dinheiro dos anúncios ---------------------------------------------------------------------------------
-- A compra debita na hora (conta pessoal ou caixa do negócio) e o valor fica retido. Aprovado, vai para o caixa do
-- veículo; recusado, cancelado ou sem resposta, volta para quem pagou.

local function charge(payer, characterId, amount, reference)
	if payer.kind == 'personal' then
		local done, errorCode = remote('coe_economy', 'Debit', characterId, amount, 'news_ad', reference)
		if done == true then
			return true
		end
		return nil, errorCode == 'insufficient_funds' and 'insufficient_funds' or 'payment_failed'
	end
	local result = remote('coe_economy', 'SocietyCharge', payer.ref, amount, 'news_ad', reference)
	if result == true then
		return true
	end
	return nil, type(result) == 'table' and result.error == 'insufficient_funds' and 'insufficient_funds' or 'payment_failed'
end

local function refund(ad)
	if ad.payerKind == 'business' then
		return remote('coe_economy', 'SocietyCollect', ad.payerRef, ad.price, 'news_ad_refund') == true
	end
	return remote('coe_economy', 'Credit', ad.buyerId, ad.price, 'news_ad_refund', 'news_ad:' .. ad.id) == true
end

local function collect(ad)
	local outlet = config.Outlets[ad.outlet]
	return outlet ~= nil and remote('coe_economy', 'SocietyCollect', outlet.business, ad.price, 'news_ad') == true
end

-- Recusa (ou cancela) um anúncio pendente e devolve o valor. Sem devolução, ele volta para a fila.
local function closeAd(ad, status, note)
	if not NewsPersistence.SetAdStatus(ad.id, 'pending', status, note, os.time(), nil) then
		return nil, 'conflict'
	end
	if not refund(ad) then
		NewsPersistence.RevertAd(ad.id, status)
		log('error', 'gameplay', 'news_ad_refund_failed', { operation = tostring(ad.id), count = ad.price })
		return nil, 'refund_failed'
	end
	return true
end

-- Ações dos apps ----------------------------------------------------------------------------------------

function App.state(_, character, outletId)
	local outlet, data = config.Outlets[outletId], outlets[outletId]
	local role = roleOf(outlet, character)
	local payers = { { id = 'personal', label = 'Conta pessoal' } }
	for _, business in ipairs(remote('coe_businesses', 'List') or {}) do
		if business.enabled ~= false and remote('coe_businesses', 'Can', business.id, character.id, 'business.funds') == true then
			payers[#payers + 1] = { id = 'business:' .. business.id, label = 'Caixa: ' .. business.label }
		end
	end
	return {
		ok = true,
		outlet = {
			id = outletId, label = outlet.label, color = outlet.color, region = outlet.region,
			tagline = data.tagline, editorial = data.editorial, sections = sectionList(data.sections),
			adPrice = data.adPrice, adDays = config.Ads.Days
		},
		role = role,
		payers = payers,
		allSections = config.Sections,
		limits = {
			article = config.Articles, ads = { AdvertiserMax = config.Ads.AdvertiserMax, TitleMax = config.Ads.TitleMax,
				BodyMax = config.Ads.BodyMax, NoteMax = config.Ads.NoteMax, MinPricePerDay = config.Ads.MinPricePerDay,
				MaxPricePerDay = config.Ads.MaxPricePerDay, FeedEvery = config.Ads.FeedEvery },
			editorial = config.Editorial
		}
	}
end

function App.feed(_, _, outletId, payload)
	local data = outlets[outletId]
	local section = type(payload.section) == 'string' and SECTION_LABELS[payload.section] and payload.section or nil
	local search = NewsRules.Search(payload.search, config.Articles.SearchMax)
	local cursor
	if type(payload.cursor) == 'table' then
		local at, id = NewsRules.Id(payload.cursor.at), NewsRules.Id(payload.cursor.id)
		cursor = at and id and { at = at, id = id } or nil
	end
	local list = NewsPersistence.Feed(outletId, section, search, cursor, config.Articles.PageSize)
	if not list then
		return { ok = false, error = 'database_error' }
	end
	local result = {}
	for index, article in ipairs(list) do
		result[index] = publicArticle(article)
	end
	local last = list[#list]
	local response = {
		ok = true, articles = result,
		cursor = #list >= config.Articles.PageSize and last and { at = last.publishedAt, id = last.id } or nil
	}
	if not cursor then
		local ads = NewsPersistence.ActiveAds(outletId, os.time(), config.Ads.MaxActivePerOutlet) or {}
		response.ads = {}
		for index, ad in ipairs(ads) do
			response.ads[index] = publicAd(ad)
		end
		response.tagline = data.tagline
	end
	return response
end

local function loadArticle(outletId, id)
	id = NewsRules.Id(id)
	local article = id and NewsPersistence.Article(id)
	if article == nil and id then
		return nil, 'database_error'
	end
	if not article or article.outlet ~= outletId then
		return nil, 'not_found'
	end
	return article
end

function App.article(playerId, character, outletId, payload)
	local article, errorCode = loadArticle(outletId, payload.id)
	if not article then
		return { ok = false, error = errorCode }
	end
	if article.status ~= 'published' or payload.desk == true then
		local role = roleOf(config.Outlets[outletId], character)
		if not (role.publish or (role.write and article.authorId == character.id)) then
			return { ok = false, error = 'not_found' }
		end
		return { ok = true, article = deskArticle(article, character) }
	end
	viewed[playerId] = viewed[playerId] or {}
	if not viewed[playerId][article.id] then
		viewed[playerId][article.id] = true
		NewsPersistence.AddView(article.id)
		article.views = article.views + 1
	end
	return { ok = true, article = publicArticle(article) }
end

function App.media(_, _, _, payload)
	local data = remote('coe_apps', 'PhotoData', payload.id)
	if type(data) ~= 'string' then
		return { ok = false, error = 'not_found' }
	end
	return { ok = true, data = data }
end

function App.desk(_, character, outletId)
	local role = roleOf(config.Outlets[outletId], character)
	if not (role.write or role.publish) then
		return { ok = false, error = 'forbidden' }
	end
	local list = NewsPersistence.Desk(outletId, character.id, role.publish, config.Articles.DeskMax)
	if not list then
		return { ok = false, error = 'database_error' }
	end
	local result = {}
	for index, article in ipairs(list) do
		result[index] = deskArticle(article, character)
	end
	return { ok = true, articles = result }
end

-- Foto da capa: `token` do upload do aparelho (coe_apps), guardada só quando a matéria é salva.
local function claimPhoto(playerId, token)
	if type(token) ~= 'string' then
		return nil
	end
	local result = remote('coe_apps', 'ClaimPhoto', playerId, token)
	if type(result) ~= 'table' then
		return nil, 'upload_failed'
	end
	if not result.ok then
		return nil, result.error or 'upload_failed'
	end
	return result.image
end

local function deletePhoto(image)
	if type(image) == 'string' and image ~= '' then
		remote('coe_apps', 'DeletePhoto', image)
	end
end

function App.save(playerId, character, outletId, payload)
	local now = os.time()
	if lastSave[character.id] and now - lastSave[character.id] < config.Articles.SaveCooldownSeconds then
		return { ok = false, error = 'save_cooldown' }
	end
	local role = roleOf(config.Outlets[outletId], character)
	local data, errorCode = NewsRules.Article(config, payload, outlets[outletId].sections)
	if not data then
		return { ok = false, error = errorCode }
	end
	local existing
	if payload.id ~= nil then
		existing, errorCode = loadArticle(outletId, payload.id)
		if not existing then
			return { ok = false, error = errorCode }
		end
		local allowed = NewsRules.Transition(existing.status, 'edit', { author = role.write and existing.authorId == character.id, publisher = role.publish })
		if not allowed then
			return { ok = false, error = 'forbidden' }
		end
	else
		if not role.write then
			return { ok = false, error = 'forbidden' }
		end
		local open = NewsPersistence.CountOpen(outletId, character.id)
		if not open then
			return { ok = false, error = 'database_error' }
		end
		if open >= config.Articles.MaxDraftsPerAuthor then
			return { ok = false, error = 'draft_limit' }
		end
	end
	return withLock('article:' .. (existing and existing.id or ('new:' .. character.id)), function()
		local photo, photoError = claimPhoto(playerId, payload.token)
		if photoError then
			return { ok = false, error = photoError }
		end
		local previous = existing and existing.image or ''
		data.image = photo or ((payload.removeImage == true) and '' or previous)
		data.now = now
		local id
		if existing then
			if not NewsPersistence.UpdateArticle(existing.id, existing.status, data) then
				deletePhoto(photo)
				return { ok = false, error = 'conflict' }
			end
			id = existing.id
			if previous ~= '' and previous ~= data.image then
				deletePhoto(previous)
			end
		else
			data.outlet, data.authorId, data.authorName = outletId, character.id, character.name
			id = NewsPersistence.InsertArticle(data)
			if not id then
				deletePhoto(photo)
				return { ok = false, error = 'database_error' }
			end
		end
		lastSave[character.id] = now
		return { ok = true, id = id }
	end)
end

-- Quem tem o app do veículo em algum aparelho recebe o aviso de urgente.
local function broadcast(outletId, title)
	local outlet = config.Outlets[outletId]
	for _, value in ipairs(GetPlayers()) do
		local playerId = tonumber(value)
		if remote('coe_apps', 'HasApp', playerId, outletId, 'phone') == true or remote('coe_apps', 'HasApp', playerId, outletId, 'tablet') == true then
			notify(playerId, 'info', _t('breaking_news', { outlet = outlet.label, title = title }))
		end
	end
end

local NOTES = { reject = true, unpublish = true }

local function transition(action)
	return function(_, character, outletId, payload)
		local outlet = config.Outlets[outletId]
		local role = roleOf(outlet, character)
		local article, errorCode = loadArticle(outletId, payload.id)
		if not article then
			return { ok = false, error = errorCode }
		end
		local target
		target, errorCode = NewsRules.Transition(article.status, action,
			{ author = role.write and article.authorId == character.id, publisher = role.publish })
		if not target then
			return { ok = false, error = errorCode }
		end
		return withLock('article:' .. article.id, function()
			local now = os.time()
			if target == 'removed' then
				if not NewsPersistence.DeleteArticle(article.id, article.status) then
					return { ok = false, error = 'conflict' }
				end
				deletePhoto(article.image)
				if article.authorId ~= character.id then
					audit('news_article_removed', { character_id = character.id, operation = outletId, target = tostring(article.id) })
				end
				return { ok = true }
			end
			local breaking, breakingDenied = false, false
			if action == 'publish' and payload.breaking == true then
				breaking = NewsPersistence.ClaimBreaking(outletId, now, config.Articles.BreakingCooldownMinutes * 60)
				breakingDenied = not breaking
			end
			local note = NOTES[action] and NewsRules.Text(payload.note, config.Articles.NoteMax) or ''
			local editorName = (action == 'publish' or NOTES[action]) and character.name or article.editorName
			if not NewsPersistence.SetStatus(article.id, article.status, target, { note = note, editorName = editorName, breaking = breaking }, now) then
				return { ok = false, error = 'conflict' }
			end
			if action == 'publish' then
				log('info', 'gameplay', 'news_published', { character_id = character.id, operation = outletId, target = tostring(article.id) })
				if breaking then
					broadcast(outletId, article.title)
				end
				if article.authorId ~= character.id then
					notifyCharacter(article.authorId, 'success', _t('article_published', { outlet = outlet.label, title = article.title }))
				end
			elseif action == 'reject' and article.authorId ~= character.id then
				notifyCharacter(article.authorId, 'error', _t('article_returned', { outlet = outlet.label, title = article.title }))
			elseif action == 'unpublish' then
				audit('news_article_unpublished', { character_id = character.id, operation = outletId, target = tostring(article.id) })
			end
			return { ok = true, status = target, breakingDenied = breakingDenied or nil }
		end)
	end
end

App.submit = transition('submit')
App.reject = transition('reject')
App.publish = transition('publish')
App.unpublish = transition('unpublish')
App.remove = transition('remove')

function App.editorial(_, character, outletId, payload)
	local role = roleOf(config.Outlets[outletId], character)
	if not role.editorial then
		return { ok = false, error = 'forbidden' }
	end
	local data, errorCode = NewsRules.Editorial(config, payload)
	if not data then
		return { ok = false, error = errorCode }
	end
	if not NewsPersistence.SaveOutlet(outletId, data, os.time(), character.id) then
		return { ok = false, error = 'database_error' }
	end
	local current = outlets[outletId]
	current.tagline, current.editorial, current.sections, current.adPrice = data.tagline, data.editorial, data.sections, data.adPrice
	audit('news_editorial_updated', { character_id = character.id, operation = outletId, count = data.adPrice })
	return { ok = true }
end

function App.adBuy(_, character, outletId, payload)
	local payer = NewsRules.Payer(payload.payer)
	if not payer then
		return { ok = false, error = 'invalid_payer' }
	end
	if payer.kind == 'business' and remote('coe_businesses', 'Can', payer.ref, character.id, 'business.funds') ~= true then
		return { ok = false, error = 'payer_forbidden' }
	end
	local ad, errorCode = NewsRules.Ad(config, payload, outlets[outletId].adPrice)
	if not ad then
		return { ok = false, error = errorCode }
	end
	return withLock('buyer:' .. character.id, function()
		local pending = NewsPersistence.PendingCount(outletId, character.id)
		if not pending then
			return { ok = false, error = 'database_error' }
		end
		if pending >= config.Ads.MaxPendingPerBuyer then
			return { ok = false, error = 'ad_pending_limit' }
		end
		ad.outlet, ad.buyerId, ad.payerKind, ad.payerRef, ad.now = outletId, character.id, payer.kind, payer.ref, os.time()
		local id = nil
		local sagaOk, sagaErr = NewsRules.ExecuteSaga({
			{
				name = 'charge_ad',
				forward = function()
					return charge(payer, character.id, ad.price, 'news:' .. outletId)
				end,
				compensate = function()
					ad.id = 0
					if not refund(ad) then
						log('error', 'gameplay', 'news_ad_refund_failed', { character_id = character.id, count = ad.price })
					end
				end
			},
			{
				name = 'insert_ad',
				forward = function()
					id = NewsPersistence.InsertAd(ad)
					if not id then
						return false, 'database_error'
					end
					return true
				end
			}
		}, {})
		if not sagaOk then
			return { ok = false, error = sagaErr or 'database_error' }
		end
		log('info', 'gameplay', 'news_ad_bought', { character_id = character.id, operation = outletId, count = ad.price })
		return { ok = true, id = id, price = ad.price }
	end)
end

function App.myAds(_, character, outletId)
	local list = NewsPersistence.BuyerAds(outletId, character.id, config.Ads.History)
	if not list then
		return { ok = false, error = 'database_error' }
	end
	local result = {}
	for index, ad in ipairs(list) do
		result[index] = adView(ad)
	end
	return { ok = true, ads = result }
end

local function loadAd(outletId, id)
	id = NewsRules.Id(id)
	local ad = id and NewsPersistence.Ad(id)
	if ad == nil and id then
		return nil, 'database_error'
	end
	if not ad or ad.outlet ~= outletId then
		return nil, 'not_found'
	end
	return ad
end

function App.adCancel(_, character, outletId, payload)
	local ad, errorCode = loadAd(outletId, payload.id)
	if not ad then
		return { ok = false, error = errorCode }
	end
	if ad.buyerId ~= character.id then
		return { ok = false, error = 'forbidden' }
	end
	if ad.status ~= 'pending' then
		return { ok = false, error = 'ad_decided' }
	end
	return withLock('ad:' .. ad.id, function()
		local done
		done, errorCode = closeAd(ad, 'cancelled', '')
		return done and { ok = true } or { ok = false, error = errorCode }
	end)
end

function App.adQueue(_, character, outletId)
	if not roleOf(config.Outlets[outletId], character).ads then
		return { ok = false, error = 'forbidden' }
	end
	local now = os.time()
	local queue = NewsPersistence.Queue(outletId, 50)
	local active = NewsPersistence.ActiveAds(outletId, now, config.Ads.MaxActivePerOutlet)
	if not queue or not active then
		return { ok = false, error = 'database_error' }
	end
	local pending, running = {}, {}
	for index, ad in ipairs(queue) do
		pending[index] = adView(ad)
	end
	for index, ad in ipairs(active) do
		running[index] = adView(ad)
	end
	return { ok = true, pending = pending, active = running }
end

-- Aprova ou recusa um anúncio pendente. Usado pela equipe (news.ads) e pelo painel admin.
-- actor: { characterId?, admin? } só para o log.
local function decideAd(ad, approve, note, actor)
	local outlet = config.Outlets[ad.outlet]
	return withLock('ad:' .. ad.id, function()
		local now = os.time()
		if not approve then
			local done, errorCode = closeAd(ad, 'rejected', note)
			if not done then
				return { ok = false, error = errorCode }
			end
			notifyCharacter(ad.buyerId, 'error', _t('ad_rejected', { outlet = outlet.label, title = ad.title }))
			return { ok = true }
		end
		local active = NewsPersistence.ActiveAds(ad.outlet, now, config.Ads.MaxActivePerOutlet)
		if not active then
			return { ok = false, error = 'database_error' }
		end
		if #active >= config.Ads.MaxActivePerOutlet then
			return { ok = false, error = 'ad_slots_full' }
		end
		if not NewsPersistence.SetAdStatus(ad.id, 'pending', 'active', note, now, now + ad.days * DAY) then
			return { ok = false, error = 'conflict' }
		end
		if not collect(ad) then
			NewsPersistence.RevertAd(ad.id, 'active')
			return { ok = false, error = 'payment_failed' }
		end
		log('info', 'gameplay', 'news_ad_approved', { character_id = actor.characterId, source = actor.admin, operation = ad.outlet, count = ad.price })
		notifyCharacter(ad.buyerId, 'success', _t('ad_approved', { outlet = outlet.label, title = ad.title }))
		return { ok = true }
	end)
end

function App.adDecide(_, character, outletId, payload)
	local outlet = config.Outlets[outletId]
	if not roleOf(outlet, character).ads then
		return { ok = false, error = 'forbidden' }
	end
	local ad, errorCode = loadAd(outletId, payload.id)
	if not ad then
		return { ok = false, error = errorCode }
	end
	if ad.status ~= 'pending' then
		return { ok = false, error = 'ad_decided' }
	end
	local note = NewsRules.Text(payload.note, config.Ads.NoteMax) or ''
	return decideAd(ad, payload.approve == true, note, { characterId = character.id })
end

-- Helpers internos para server/admin.lua (painel da staff). Não é API pública.
NewsServer = {
	config = config,
	outlets = outlets,
	isReady = function()
		return ready
	end,
	remote = remote,
	log = log,
	audit = audit,
	notifyCharacter = notifyCharacter,
	withLock = withLock,
	loadAd = loadAd,
	loadArticle = loadArticle,
	decideAd = decideAd,
	refund = refund,
	deletePhoto = deletePhoto,
	adView = adView,
	sectionList = sectionList
}

-- Exports para o tablet e o smartphone ------------------------------------------------------------------

local function installed(playerId, appId, device)
	return remote('coe_apps', 'HasApp', playerId, appId, device) == true
end

exports('TabletVisible', function(playerId, appId)
	local device = HOSTS[GetInvokingResource()]
	return device ~= nil and ready and config.Outlets[appId] ~= nil and installed(playerId, appId, device)
end)

exports('TabletCall', function(playerId, appId, action, payload)
	local device = HOSTS[GetInvokingResource()]
	if not device then
		return { ok = false, error = 'forbidden' }
	end
	if not ready then
		return { ok = false, error = 'not_ready' }
	end
	if not config.Outlets[appId] then
		return { ok = false, error = 'unknown_action' }
	end
	local character = characterOf(playerId)
	if not character then
		return { ok = false, error = 'no_character' }
	end
	local handler = type(action) == 'string' and rawget(App, action)
	if type(handler) ~= 'function' then
		return { ok = false, error = 'unknown_action' }
	end
	if not installed(playerId, appId, device) then
		return { ok = false, error = 'not_installed' }
	end
	return handler(playerId, character, appId, type(payload) == 'table' and payload or {})
end)

AddEventHandler('playerDropped', function()
	viewed[source] = nil
end)

-- Negócios dos veículos e permissões de cargo ------------------------------------------------------------

local function seedBusinesses()
	if remote('coe_businesses', 'IsReady') ~= true then
		return false
	end
	local registered = remote('coe_businesses', 'RegisterPermissions', config.Permissions)
	if registered ~= true then
		log('warn', 'system', 'news_permissions_failed', { error_code = type(registered) == 'table' and tostring(registered.error) or 'unknown' })
	end
	for _, outlet in pairs(config.Outlets) do
		local point = outlet.seed.clock
		local saved = remote('coe_businesses', 'Seed', {
			id = outlet.business, category = 'media', label = outlet.label, area = outlet.seed.area,
			stations = {
				clocks = { { id = 'redacao', label = 'Redação', x = point.x, y = point.y, z = point.z, radius = 1.5 } },
				stashes = { { id = 'arquivo', label = 'Arquivo', x = point.x + 2.0, y = point.y, z = point.z, radius = 1.5 } }
			},
			grades = config.Grades
		})
		if type(saved) ~= 'table' or saved.error then
			log('warn', 'system', 'news_seed_failed', { operation = outlet.business, error_code = type(saved) == 'table' and tostring(saved.error) or 'unknown' })
		end
	end
	return true
end

AddEventHandler('onResourceStart', function(name)
	if name == 'coe_businesses' then
		SetTimeout(3000, seedBusinesses)
	end
end)

CreateThread(function()
	local waitingLogged = false
	while true do
		local initialized, errorCode = NewsPersistence.Initialize()
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
	local now = os.time()
	for id, outlet in pairs(config.Outlets) do
		NewsPersistence.InsertOutlet(id, {
			tagline = outlet.tagline, editorial = outlet.editorial, sections = config.DefaultSections, adPrice = config.Ads.DefaultPricePerDay
		}, now)
		local row = NewsPersistence.Outlet(id)
		if not row then
			log('error', 'persistence', 'news_outlet_load_failed', { operation = id })
			return
		end
		outlets[id] = {
			tagline = row.tagline, editorial = row.editorial, sections = NewsRules.ParseSections(config, row.sections),
			adPrice = row.adPrice
		}
	end
	ready = true
	log('info', 'system', 'news_ready', {})

	CreateThread(function()
		for _ = 1, 60 do
			if seedBusinesses() then
				return
			end
			Wait(5000)
		end
	end)

	while true do
		local tick = os.time()
		local expired = NewsPersistence.ExpireActive(tick)
		if expired > 0 then
			log('info', 'gameplay', 'news_ads_expired', { count = expired })
		end
		for _, ad in ipairs(NewsPersistence.StalePending(tick - config.Ads.PendingHours * 3600, 50) or {}) do
			if closeAd(ad, 'rejected', 'Sem resposta do veículo.') then
				local outlet = config.Outlets[ad.outlet]
				notifyCharacter(ad.buyerId, 'info', _t('ad_expired', { outlet = outlet and outlet.label or _t('outlet_default'), title = ad.title }))
			end
		end
		Wait(config.TickSeconds * 1000)
	end
end)
