-- Regras puras do coe_news (sem natives), usadas pelo servidor e pelos testes.
NewsRules = {}

local function trim(value)
	return (tostring(value):gsub('^%s+', ''):gsub('%s+$', ''))
end

-- Texto livre: sem caracteres de controle, espaços repetidos reduzidos e limite em caracteres UTF-8. Vazio devolve nil.
function NewsRules.Text(value, max, multiline)
	if type(value) ~= 'string' then
		return nil
	end
	local text = value:gsub('\r\n?', '\n')
	if multiline then
		text = text:gsub('[\0-\8\11-\31\127]', ''):gsub('\n\n\n+', '\n\n')
	else
		text = text:gsub('[\0-\31\127]', ' ')
	end
	text = trim(text:gsub('[ \t]+', ' '))
	if text == '' or not utf8.len(text) then
		return nil
	end
	if utf8.len(text) > max then
		text = trim(text:sub(1, utf8.offset(text, max + 1) - 1))
	end
	return text
end

function NewsRules.Id(value)
	local id = math.tointeger(tonumber(value))
	return id and id > 0 and id or nil
end

function NewsRules.SectionLabels(config)
	local map = {}
	for _, section in ipairs(config.Sections) do
		map[section.id] = section.label
	end
	return map
end

-- Lista de editorias válidas, sem repetição, na ordem do config. Precisa de pelo menos uma.
function NewsRules.Sections(config, list)
	if type(list) ~= 'table' then
		return nil, 'invalid_sections'
	end
	local wanted = {}
	for _, id in ipairs(list) do
		if type(id) == 'string' then
			wanted[id] = true
		end
	end
	local result = {}
	for _, section in ipairs(config.Sections) do
		if wanted[section.id] then
			result[#result + 1] = section.id
		end
	end
	if #result == 0 then
		return nil, 'invalid_sections'
	end
	return result
end

function NewsRules.ParseSections(config, csv)
	local list = {}
	for id in tostring(csv or ''):gmatch('[^,]+') do
		list[#list + 1] = id
	end
	return NewsRules.Sections(config, list) or NewsRules.Sections(config, config.DefaultSections)
end

-- Linha editorial do veículo: slogan, texto, editorias e preço do anúncio por dia.
function NewsRules.Editorial(config, raw)
	if type(raw) ~= 'table' then
		return nil, 'invalid_editorial'
	end
	local sections, sectionsError = NewsRules.Sections(config, raw.sections)
	if not sections then
		return nil, sectionsError
	end
	local price = math.tointeger(tonumber(raw.adPrice))
	if not price or price < config.Ads.MinPricePerDay or price > config.Ads.MaxPricePerDay then
		return nil, 'invalid_price'
	end
	return {
		tagline = NewsRules.Text(raw.tagline, config.Editorial.TaglineMax) or '',
		editorial = NewsRules.Text(raw.editorial, config.Editorial.EditorialMax, true) or '',
		sections = sections,
		adPrice = price
	}
end

-- Matéria vinda do editor. `sections`: editorias ativas do veículo (lista).
function NewsRules.Article(config, raw, sections)
	if type(raw) ~= 'table' then
		return nil, 'invalid_article'
	end
	local allowed = false
	for _, id in ipairs(sections or {}) do
		if id == raw.section then
			allowed = true
		end
	end
	if not allowed then
		return nil, 'invalid_section'
	end
	local limits = config.Articles
	local title = NewsRules.Text(raw.title, limits.TitleMax)
	if not title then
		return nil, 'missing_title'
	end
	local body = NewsRules.Text(raw.body, limits.BodyMax, true)
	if not body then
		return nil, 'missing_body'
	end
	return {
		section = raw.section,
		title = title,
		summary = NewsRules.Text(raw.summary, limits.LeadMax) or '',
		body = body,
		anonymous = raw.anonymous == true
	}
end

-- Fluxo da matéria. role: { author = bool, publisher = bool }. Devolve o novo status (ou o atual em `edit`)
-- ou nil, erro. Estados: draft (rascunho), review (em revisão), published, unpublished (retirada do ar).
local FLOW = {
	edit = function(status, role)
		if status == 'draft' then
			return role.author and status
		end
		if status == 'review' then
			return (role.author or role.publisher) and status
		end
		return role.publisher and status
	end,
	submit = function(status, role)
		return status == 'draft' and role.author and 'review'
	end,
	reject = function(status, role)
		return status == 'review' and role.publisher and 'draft'
	end,
	publish = function(status, role)
		return status ~= 'published' and role.publisher and 'published'
	end,
	unpublish = function(status, role)
		return status == 'published' and role.publisher and 'unpublished'
	end,
	remove = function(status, role)
		if role.publisher then
			return 'removed'
		end
		return (status == 'draft' or status == 'review') and role.author and 'removed'
	end
}

NewsRules.Statuses = { draft = true, review = true, published = true, unpublished = true }

function NewsRules.Transition(status, action, role)
	local rule = FLOW[action]
	if not rule or not NewsRules.Statuses[status] or type(role) ~= 'table' then
		return nil, 'invalid_action'
	end
	local result = rule(status, role)
	if not result then
		return nil, 'forbidden'
	end
	return result
end

-- Quem assina: "Redação" quando a matéria é anônima (ex.: fofoca), senão o nome do autor.
function NewsRules.Byline(article)
	if article.anonymous then
		return 'Redação'
	end
	return article.authorName ~= '' and article.authorName or 'Redação'
end

-- Anúncio comprado no app. Devolve { advertiser, title, body, days, price } ou nil, erro.
function NewsRules.Ad(config, raw, pricePerDay)
	if type(raw) ~= 'table' then
		return nil, 'invalid_ad'
	end
	local limits = config.Ads
	local days = math.tointeger(tonumber(raw.days))
	local validDays = false
	for _, option in ipairs(limits.Days) do
		if option == days then
			validDays = true
		end
	end
	if not validDays then
		return nil, 'invalid_days'
	end
	local advertiser = NewsRules.Text(raw.advertiser, limits.AdvertiserMax)
	if not advertiser then
		return nil, 'missing_advertiser'
	end
	local title = NewsRules.Text(raw.title, limits.TitleMax)
	if not title then
		return nil, 'missing_title'
	end
	local body = NewsRules.Text(raw.body, limits.BodyMax, true)
	if not body then
		return nil, 'missing_body'
	end
	return { advertiser = advertiser, title = title, body = body, days = days, price = days * pricePerDay }
end

-- Quem paga o anúncio: 'personal' (conta do personagem) ou 'business:<id>' (caixa do negócio).
function NewsRules.Payer(value)
	if value == 'personal' then
		return { kind = 'personal' }
	end
	local id = type(value) == 'string' and value:match('^business:([a-z][a-z0-9_]+)$')
	if id and #id <= 32 then
		return { kind = 'business', ref = id }
	end
	return nil
end

-- Busca: texto limpo, sem os curingas do LIKE (% _ \).
function NewsRules.Search(value, max)
	local text = NewsRules.Text(value, max)
	if not text then
		return nil
	end
	text = text:gsub('[%%_\\]', ' ')
	text = trim(text:gsub('%s+', ' '))
	return text ~= '' and text or nil
end

-- Painel admin --------------------------------------------------------------------------------------------

-- Item de equipamento do config (ou nil).
function NewsRules.EquipmentItem(config, name)
	for _, item in ipairs(config.Equipment.Items) do
		if item.name == name then
			return item
		end
	end
	return nil
end

-- Abastecer/retirar equipamento do baú: { item, count, op = 'add'|'remove' } ou nil, erro.
function NewsRules.StockChange(config, raw)
	if type(raw) ~= 'table' then
		return nil, 'invalid_stock'
	end
	if not NewsRules.EquipmentItem(config, raw.item) then
		return nil, 'unknown_equipment'
	end
	local count = math.tointeger(tonumber(raw.count))
	if not count or count < 1 or count > config.Equipment.MaxPerOperation then
		return nil, 'invalid_count'
	end
	if raw.op ~= 'add' and raw.op ~= 'remove' then
		return nil, 'invalid_stock'
	end
	return { item = raw.item, count = count, op = raw.op }
end

-- Estorno ao tirar um anúncio do ar: 'none' (nada), 'remaining' (dias que faltavam, proporcional) ou 'full'.
function NewsRules.TakedownRefund(ad, now, mode)
	if mode == 'full' then
		return ad.price
	end
	if mode ~= 'remaining' then
		return 0
	end
	local total = (ad.days or 0) * 86400
	local left = (ad.endsAt or 0) - now
	if total <= 0 or left <= 0 then
		return 0
	end
	return math.min(ad.price, math.floor(ad.price * left / total))
end

-- Filtro da lista de matérias do admin: status (ou todos) e busca.
function NewsRules.ArticleFilter(raw, searchMax)
	raw = type(raw) == 'table' and raw or {}
	local status = type(raw.status) == 'string' and NewsRules.Statuses[raw.status] and raw.status or nil
	return { status = status, search = NewsRules.Search(raw.search, searchMax) }
end

-- Grupos de anúncios do admin.
NewsRules.AdGroups = {
	pending = { 'pending' },
	active = { 'active' },
	history = { 'expired', 'rejected', 'cancelled', 'removed' }
}

function NewsRules.ExecuteSaga(steps, context)
	local Concurrency = (Core and Core.Algorithms and Core.Algorithms.Concurrency) or (CoeAlgorithms and CoeAlgorithms.Concurrency)
	if Concurrency and Concurrency.executeSaga then
		local ok, failedStep, reason = Concurrency.executeSaga(steps, context)
		if not ok then
			return false, reason or failedStep
		end
		return true
	end
	local completed = {}
	for _, step in ipairs(steps) do
		local fn = step.action or step.forward
		local ok, err = fn(context)
		if not ok then
			for j = #completed, 1, -1 do
				if completed[j].compensate then
					pcall(completed[j].compensate, context)
				end
			end
			return false, err
		end
		completed[#completed + 1] = step
	end
	return true
end

function NewsRules.NewLockManager()
	local alg = (type(Core) == 'table' and Core.Algorithms) or CoeAlgorithms
	local Concurrency = alg and alg.Concurrency
	if Concurrency and Concurrency.newLockManager then
		return Concurrency.newLockManager()
	end
	return nil
end

function NewsRules.NewSaveLimiter(cooldownSec)
	local alg = (type(Core) == 'table' and Core.Algorithms) or CoeAlgorithms
	local RateLimit = alg and alg.RateLimit
	if RateLimit and RateLimit.newGCRA then
		return RateLimit.newGCRA(math.max(1, (tonumber(cooldownSec) or 3) * 1000), 0)
	end
	return nil
end

function NewsRules.NewArticleCache(capacity)
	local alg = (type(Core) == 'table' and Core.Algorithms) or CoeAlgorithms
	local Containers = alg and alg.Containers
	if Containers and Containers.newLRUCache then
		return Containers.newLRUCache(capacity or 128)
	end
	return nil
end
