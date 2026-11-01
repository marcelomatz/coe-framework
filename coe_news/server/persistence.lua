NewsPersistence = {}

local function callDatabase(exportName, ...)
	if GetResourceState('coe_database') ~= 'started' then
		return nil, 'database_unavailable'
	end
	local response = promise.new()
	local databaseResource = exports['coe_database']
	local callArguments = { databaseResource, ... }
	callArguments[#callArguments + 1] = function(success, result, errorCode)
		response:resolve({ success = success == true, result = result, error = errorCode })
	end
	local dispatched = pcall(function()
		databaseResource[exportName](table.unpack(callArguments))
	end)
	if not dispatched then
		return nil, 'database_unavailable'
	end
	local result = Citizen.Await(response)
	if not result.success then
		return nil, result.error or 'database_error'
	end
	return result.result
end

local function query(sql, parameters)
	return callDatabase('Query', sql, parameters or {})
end

local function execute(sql, parameters)
	return callDatabase('Execute', sql, parameters or {})
end

local function int(value)
	return math.tointeger(tonumber(value))
end

local function str(value)
	return value ~= nil and tostring(value) or ''
end

local function truthy(value)
	return value == true or tonumber(value) == 1
end

local function affected(result)
	return result ~= nil and (tonumber(result.affectedRows) or 0) > 0
end

function NewsPersistence.Initialize()
	return CoeMigrations.Run({
		tableName = 'coe_news_schema_migrations',
		migrations = NewsMigrations,
		execute = execute,
		query = query
	})
end

-- Veículos (linha editorial) ----------------------------------------------------------------------------

function NewsPersistence.Outlet(id)
	local rows = query('SELECT outlet, tagline, editorial, sections, ad_price, last_breaking FROM coe_news_outlets WHERE outlet = ?', { id })
	if not rows then
		return nil
	end
	local row = rows[1]
	if not row then
		return false
	end
	return {
		tagline = str(row.tagline), editorial = str(row.editorial), sections = str(row.sections),
		adPrice = int(row.ad_price) or 0, lastBreaking = int(row.last_breaking) or 0
	}
end

function NewsPersistence.InsertOutlet(id, data, now)
	return execute('INSERT IGNORE INTO coe_news_outlets (outlet, tagline, editorial, sections, ad_price, updated_at) VALUES (?, ?, ?, ?, ?, ?)',
		{ id, data.tagline, data.editorial, table.concat(data.sections, ','), data.adPrice, now }) ~= nil
end

function NewsPersistence.SaveOutlet(id, data, now, by)
	return execute('UPDATE coe_news_outlets SET tagline = ?, editorial = ?, sections = ?, ad_price = ?, updated_at = ?, updated_by = ? WHERE outlet = ?',
		{ data.tagline, data.editorial, table.concat(data.sections, ','), data.adPrice, now, tonumber(by), id }) ~= nil
end

-- Reserva o aviso de urgente: só passa se o último foi há mais de `cooldown` segundos.
function NewsPersistence.ClaimBreaking(id, now, cooldown)
	return affected(execute('UPDATE coe_news_outlets SET last_breaking = ? WHERE outlet = ? AND last_breaking <= ?', { now, id, now - cooldown }))
end

-- Matérias ----------------------------------------------------------------------------------------------

local SUMMARY_COLUMNS = 'id, outlet, section, status, title, summary, image, author_character, author_name, anonymous, breaking, views, note, editor_name, created_at, updated_at, published_at'

local function article(row, withBody)
	return {
		id = int(row.id), outlet = str(row.outlet), section = str(row.section), status = str(row.status),
		title = str(row.title), summary = str(row.summary), body = withBody and str(row.body) or nil, image = str(row.image),
		authorId = str(row.author_character), authorName = str(row.author_name), anonymous = truthy(row.anonymous),
		breaking = truthy(row.breaking), views = int(row.views) or 0, note = str(row.note), editorName = str(row.editor_name),
		createdAt = int(row.created_at) or 0, updatedAt = int(row.updated_at) or 0, publishedAt = int(row.published_at)
	}
end

local function articles(rows)
	if not rows then
		return nil
	end
	local list = {}
	for index, row in ipairs(rows) do
		list[index] = article(row, false)
	end
	return list
end

-- Feed público. cursor: { at, id } da última matéria da página anterior.
function NewsPersistence.Feed(outlet, section, search, cursor, limit)
	local sql = 'SELECT ' .. SUMMARY_COLUMNS .. " FROM coe_news_articles WHERE outlet = ? AND status = 'published'"
	local parameters = { outlet }
	if section then
		sql = sql .. ' AND section = ?'
		parameters[#parameters + 1] = section
	end
	if search then
		sql = sql .. ' AND (title LIKE ? OR summary LIKE ? OR body LIKE ?)'
		local pattern = '%' .. search .. '%'
		parameters[#parameters + 1] = pattern
		parameters[#parameters + 1] = pattern
		parameters[#parameters + 1] = pattern
	end
	if cursor then
		sql = sql .. ' AND (published_at < ? OR (published_at = ? AND id < ?))'
		parameters[#parameters + 1] = cursor.at
		parameters[#parameters + 1] = cursor.at
		parameters[#parameters + 1] = cursor.id
	end
	sql = sql .. (' ORDER BY published_at DESC, id DESC LIMIT %d'):format(limit)
	return articles(query(sql, parameters))
end

function NewsPersistence.Article(id)
	local rows = query('SELECT ' .. SUMMARY_COLUMNS .. ', body FROM coe_news_articles WHERE id = ?', { id })
	if not rows then
		return nil
	end
	return rows[1] and article(rows[1], true) or false
end

-- Mesa da redação: quem publica vê revisões e publicadas de todos; quem escreve vê as próprias.
function NewsPersistence.Desk(outlet, characterId, publisher, limit)
	local sql, parameters
	if publisher then
		sql = 'SELECT ' .. SUMMARY_COLUMNS .. " FROM coe_news_articles WHERE outlet = ? AND (status <> 'draft' OR author_character = ?)"
		parameters = { outlet, tonumber(characterId) }
	else
		sql = 'SELECT ' .. SUMMARY_COLUMNS .. ' FROM coe_news_articles WHERE outlet = ? AND author_character = ?'
		parameters = { outlet, tonumber(characterId) }
	end
	sql = sql .. (" ORDER BY FIELD(status, 'review', 'draft', 'published', 'unpublished'), updated_at DESC LIMIT %d"):format(limit)
	return articles(query(sql, parameters))
end

function NewsPersistence.CountOpen(outlet, characterId)
	local rows = query("SELECT COUNT(*) AS total FROM coe_news_articles WHERE outlet = ? AND author_character = ? AND status IN ('draft', 'review')",
		{ outlet, tonumber(characterId) })
	return rows and int(rows[1] and rows[1].total) or nil
end

function NewsPersistence.InsertArticle(data)
	local result = execute([[INSERT INTO coe_news_articles
		(outlet, section, status, title, summary, body, image, author_character, author_name, anonymous, created_at, updated_at)
		VALUES (?, ?, 'draft', ?, ?, ?, ?, ?, ?, ?, ?, ?)]],
		{ data.outlet, data.section, data.title, data.summary, data.body, data.image or '', tonumber(data.authorId), data.authorName,
			data.anonymous and 1 or 0, data.now, data.now })
	return result and int(result.insertId) or nil
end

-- Atualiza o texto só se o status não mudou desde a leitura.
function NewsPersistence.UpdateArticle(id, status, data)
	return affected(execute([[UPDATE coe_news_articles SET section = ?, title = ?, summary = ?, body = ?, image = ?, anonymous = ?, updated_at = ?
		WHERE id = ? AND status = ?]],
		{ data.section, data.title, data.summary, data.body, data.image or '', data.anonymous and 1 or 0, data.now, id, status }))
end

-- Troca de status com trava otimista. extra: note, editorName, breaking, publishedAt (só na publicação).
function NewsPersistence.SetStatus(id, from, to, extra, now)
	local sql = 'UPDATE coe_news_articles SET status = ?, note = ?, editor_name = ?, updated_at = ?'
	local parameters = { to, extra.note or '', extra.editorName or '', now }
	if to == 'published' then
		sql = sql .. ', breaking = ?, published_at = COALESCE(published_at, ?)'
		parameters[#parameters + 1] = extra.breaking and 1 or 0
		parameters[#parameters + 1] = now
	end
	sql = sql .. ' WHERE id = ? AND status = ?'
	parameters[#parameters + 1] = id
	parameters[#parameters + 1] = from
	return affected(execute(sql, parameters))
end

function NewsPersistence.DeleteArticle(id, status)
	return affected(execute('DELETE FROM coe_news_articles WHERE id = ? AND status = ?', { id, status }))
end

function NewsPersistence.AddView(id)
	execute("UPDATE coe_news_articles SET views = views + 1 WHERE id = ? AND status = 'published'", { id })
end

-- Anúncios ----------------------------------------------------------------------------------------------

local AD_COLUMNS = 'id, outlet, buyer_character, payer_kind, payer_ref, advertiser, title, body, days, price, status, note, created_at, decided_at, ends_at'

local function ad(row)
	return {
		id = int(row.id), outlet = str(row.outlet), buyerId = str(row.buyer_character), payerKind = str(row.payer_kind),
		payerRef = str(row.payer_ref), advertiser = str(row.advertiser), title = str(row.title), body = str(row.body),
		days = int(row.days) or 0, price = int(row.price) or 0, status = str(row.status), note = str(row.note),
		createdAt = int(row.created_at) or 0, decidedAt = int(row.decided_at), endsAt = int(row.ends_at)
	}
end

local function ads(rows)
	if not rows then
		return nil
	end
	local list = {}
	for index, row in ipairs(rows) do
		list[index] = ad(row)
	end
	return list
end

function NewsPersistence.InsertAd(data)
	local result = execute([[INSERT INTO coe_news_ads
		(outlet, buyer_character, payer_kind, payer_ref, advertiser, title, body, days, price, status, created_at)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending', ?)]],
		{ data.outlet, tonumber(data.buyerId), data.payerKind, data.payerRef or '', data.advertiser, data.title, data.body,
			data.days, data.price, data.now })
	return result and int(result.insertId) or nil
end

function NewsPersistence.Ad(id)
	local rows = query('SELECT ' .. AD_COLUMNS .. ' FROM coe_news_ads WHERE id = ?', { id })
	if not rows then
		return nil
	end
	return rows[1] and ad(rows[1]) or false
end

function NewsPersistence.PendingCount(outlet, buyerId)
	local rows = query("SELECT COUNT(*) AS total FROM coe_news_ads WHERE outlet = ? AND buyer_character = ? AND status = 'pending'",
		{ outlet, tonumber(buyerId) })
	return rows and int(rows[1] and rows[1].total) or nil
end

function NewsPersistence.ActiveAds(outlet, now, limit)
	return ads(query('SELECT ' .. AD_COLUMNS .. (" FROM coe_news_ads WHERE outlet = ? AND status = 'active' AND ends_at > ? ORDER BY decided_at DESC LIMIT %d"):format(limit),
		{ outlet, now }))
end

function NewsPersistence.BuyerAds(outlet, buyerId, limit)
	return ads(query('SELECT ' .. AD_COLUMNS .. (' FROM coe_news_ads WHERE outlet = ? AND buyer_character = ? ORDER BY id DESC LIMIT %d'):format(limit),
		{ outlet, tonumber(buyerId) }))
end

function NewsPersistence.Queue(outlet, limit)
	return ads(query('SELECT ' .. AD_COLUMNS .. (" FROM coe_news_ads WHERE outlet = ? AND status = 'pending' ORDER BY id LIMIT %d"):format(limit),
		{ outlet }))
end

-- Troca de status com trava otimista (só um processo decide cada anúncio).
function NewsPersistence.SetAdStatus(id, from, to, note, now, endsAt)
	return affected(execute('UPDATE coe_news_ads SET status = ?, note = ?, decided_at = ?, ends_at = ? WHERE id = ? AND status = ?',
		{ to, note or '', now, endsAt, id, from }))
end

-- Volta o anúncio para a fila quando o dinheiro não pôde ser movido.
function NewsPersistence.RevertAd(id, from)
	return affected(execute("UPDATE coe_news_ads SET status = 'pending', note = '', decided_at = NULL, ends_at = NULL WHERE id = ? AND status = ?",
		{ id, from }))
end

function NewsPersistence.StalePending(cutoff, limit)
	return ads(query('SELECT ' .. AD_COLUMNS .. (" FROM coe_news_ads WHERE status = 'pending' AND created_at < ? ORDER BY id LIMIT %d"):format(limit),
		{ cutoff }))
end

function NewsPersistence.ExpireActive(now)
	local result = execute("UPDATE coe_news_ads SET status = 'expired' WHERE status = 'active' AND ends_at <= ?", { now })
	return result and (tonumber(result.affectedRows) or 0) or 0
end

-- Painel admin (coe_admin) ----------------------------------------------------------------------------

-- Números do veículo: matérias por status, leituras e anúncios. `since` limita a receita e as leituras recentes.
function NewsPersistence.Stats(outlet, since)
	local articleRows = query([[SELECT status, COUNT(*) AS total, COALESCE(SUM(views), 0) AS views,
		COALESCE(SUM(CASE WHEN published_at >= ? THEN 1 ELSE 0 END), 0) AS recent
		FROM coe_news_articles WHERE outlet = ? GROUP BY status]], { since, outlet })
	local adRows = query([[SELECT status, COUNT(*) AS total, COALESCE(SUM(price), 0) AS amount,
		COALESCE(SUM(CASE WHEN decided_at >= ? THEN price ELSE 0 END), 0) AS recent
		FROM coe_news_ads WHERE outlet = ? GROUP BY status]], { since, outlet })
	if not articleRows or not adRows then
		return nil
	end
	local stats = { articles = {}, ads = {}, views = 0, publishedRecent = 0, revenue = 0, revenueRecent = 0 }
	for _, row in ipairs(articleRows) do
		local status = str(row.status)
		stats.articles[status] = int(row.total) or 0
		stats.views = stats.views + (int(row.views) or 0)
		if status == 'published' or status == 'unpublished' then
			stats.publishedRecent = stats.publishedRecent + (int(row.recent) or 0)
		end
	end
	for _, row in ipairs(adRows) do
		local status = str(row.status)
		stats.ads[status] = int(row.total) or 0
		-- Receita: anúncios aprovados (no ar, expirados ou retirados sem estorno).
		if status == 'active' or status == 'expired' or status == 'removed' then
			stats.revenue = stats.revenue + (int(row.amount) or 0)
			stats.revenueRecent = stats.revenueRecent + (int(row.recent) or 0)
		end
	end
	return stats
end

local AD_ADMIN_COLUMNS = 'a.id, a.outlet, a.buyer_character, a.payer_kind, a.payer_ref, a.advertiser, a.title, a.body, a.days, a.price, a.status, a.note, a.created_at, a.decided_at, a.ends_at, c.first_name, c.last_name'

-- Anúncios por status (lista de status), com o nome do comprador.
function NewsPersistence.AdminAds(outlet, statuses, limit)
	local marks = {}
	local parameters = { outlet }
	for index, status in ipairs(statuses) do
		marks[index] = '?'
		parameters[#parameters + 1] = status
	end
	local rows = query(('SELECT ' .. AD_ADMIN_COLUMNS .. [[ FROM coe_news_ads a
		LEFT JOIN coe_characters c ON c.character_id = a.buyer_character
		WHERE a.outlet = ? AND a.status IN (%s) ORDER BY a.id DESC LIMIT %d]]):format(table.concat(marks, ', '), limit), parameters)
	if not rows then
		return nil
	end
	local list = {}
	for index, row in ipairs(rows) do
		local item = ad(row)
		item.buyerName = (str(row.first_name) .. ' ' .. str(row.last_name)):gsub('^%s+', ''):gsub('%s+$', '')
		list[index] = item
	end
	return list
end

-- Matérias de qualquer status (ou de um só), com busca no título. Sem o corpo.
function NewsPersistence.AdminArticles(outlet, status, search, limit)
	local sql = 'SELECT ' .. SUMMARY_COLUMNS .. ' FROM coe_news_articles WHERE outlet = ?'
	local parameters = { outlet }
	if status then
		sql = sql .. ' AND status = ?'
		parameters[#parameters + 1] = status
	end
	if search then
		sql = sql .. ' AND (title LIKE ? OR author_name LIKE ?)'
		parameters[#parameters + 1] = '%' .. search .. '%'
		parameters[#parameters + 1] = '%' .. search .. '%'
	end
	sql = sql .. (' ORDER BY updated_at DESC, id DESC LIMIT %d'):format(limit)
	return articles(query(sql, parameters))
end

-- Tira do ar um anúncio ativo (o espaço fica livre na hora).
function NewsPersistence.TakedownAd(id, note, now)
	return affected(execute("UPDATE coe_news_ads SET status = 'removed', note = ?, ends_at = ? WHERE id = ? AND status = 'active'",
		{ note or '', now, id }))
end

-- Desfaz a retirada quando o estorno falha.
function NewsPersistence.RestoreAd(id, endsAt)
	return affected(execute("UPDATE coe_news_ads SET status = 'active', note = '', ends_at = ? WHERE id = ? AND status = 'removed'",
		{ endsAt, id }))
end
