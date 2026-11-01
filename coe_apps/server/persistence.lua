AppsPersistence = {}

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

function AppsPersistence.Initialize()
	return CoeMigrations.Run({
		tableName = 'coe_apps_schema_migrations',
		migrations = AppsMigrations,
		execute = execute,
		query = query
	})
end

-- Loja ----------------------------------------------------------------------------------------------

function AppsPersistence.Installed(characterId)
	local rows, errorCode = query('SELECT app_id, installed, paid_until, auto_renew, card_id FROM coe_apps_installed WHERE character_id = ?', { characterId })
	if not rows then
		return nil, errorCode
	end
	local map = {}
	for _, row in ipairs(rows) do
		map[tostring(row.app_id)] = {
			installed = tonumber(row.installed) == 1 or row.installed == true,
			paidUntil = tonumber(row.paid_until) or 0,
			autoRenew = tonumber(row.auto_renew) == 1 or row.auto_renew == true,
			cardId = tonumber(row.card_id)
		}
	end
	return map
end

-- Instala/remove. `paidUntil` nil mantém o período pago; `cardId` nil mantém o cartão; `pricePaid` soma ao total já pago.
function AppsPersistence.SetInstalled(characterId, appId, installed, pricePaid, paidUntil, autoRenew, cardId)
	return execute([[
		INSERT INTO coe_apps_installed (character_id, app_id, installed, price_paid, paid_until, auto_renew, card_id) VALUES (?, ?, ?, ?, ?, ?, NULLIF(?, 0))
		ON DUPLICATE KEY UPDATE installed = VALUES(installed), auto_renew = VALUES(auto_renew),
			price_paid = price_paid + VALUES(price_paid), paid_until = IF(? = 0, paid_until, VALUES(paid_until)),
			card_id = IF(? = 0, card_id, VALUES(card_id))
	]], { characterId, appId, installed and 1 or 0, pricePaid or 0, paidUntil or 0, autoRenew and 1 or 0, cardId or 0, paidUntil or 0, cardId or 0 })
end

-- Assinaturas que vencem até `limitAt`, mais antigas primeiro.
function AppsPersistence.DueSubscriptions(limitAt, limit)
	local rows, errorCode = query(([[
		SELECT character_id, app_id, paid_until, card_id FROM coe_apps_installed
		WHERE auto_renew = 1 AND installed = 1 AND paid_until <= ? ORDER BY paid_until LIMIT %d
	]]):format(math.floor(limit)), { limitAt })
	if not rows then
		return nil, errorCode
	end
	local list = {}
	for _, row in ipairs(rows) do
		list[#list + 1] = { characterId = tostring(row.character_id), appId = tostring(row.app_id), paidUntil = tonumber(row.paid_until) or 0, cardId = tonumber(row.card_id) }
	end
	return list
end

-- Renova só se a assinatura não mudou desde a leitura. Devolve true se aplicou.
function AppsPersistence.Renew(characterId, appId, previousPaidUntil, paidUntil, price)
	local result, errorCode = execute([[
		UPDATE coe_apps_installed SET paid_until = ?, price_paid = price_paid + ?
		WHERE character_id = ? AND app_id = ? AND paid_until = ? AND auto_renew = 1 AND installed = 1
	]], { paidUntil, price, characterId, appId, previousPaidUntil })
	if not result then
		return nil, errorCode
	end
	return (tonumber(result.affectedRows) or 0) > 0
end

function AppsPersistence.StopRenewal(characterId, appId)
	return execute('UPDATE coe_apps_installed SET auto_renew = 0 WHERE character_id = ? AND app_id = ?', { characterId, appId })
end

function AppsPersistence.Expire(characterId, appId)
	return execute('UPDATE coe_apps_installed SET installed = 0, auto_renew = 0 WHERE character_id = ? AND app_id = ?', { characterId, appId })
end

-- Classificados -------------------------------------------------------------------------------------

local function adFromRow(row)
	return {
		id = tonumber(row.id), characterId = tostring(row.character_id), author = row.author, contact = row.contact,
		category = row.category, title = row.title, body = row.body, price = row.price ~= nil and tonumber(row.price) or nil,
		createdAt = tonumber(row.created_at), expiresAt = tonumber(row.expires_at)
	}
end

function AppsPersistence.ActiveAds(now)
	local rows, errorCode = query([[
		SELECT id, character_id, author, contact, category, title, body, price, created_at, expires_at
		FROM coe_apps_classifieds WHERE expires_at > ? ORDER BY id DESC
	]], { now })
	if not rows then
		return nil, errorCode
	end
	local list = {}
	for _, row in ipairs(rows) do
		list[#list + 1] = adFromRow(row)
	end
	return list
end

function AppsPersistence.InsertAd(ad)
	local result, errorCode = execute([[
		INSERT INTO coe_apps_classifieds (character_id, author, contact, category, title, body, price, created_at, expires_at)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
	]], { ad.characterId, ad.author, ad.contact, ad.category, ad.title, ad.body, ad.price, ad.createdAt, ad.expiresAt })
	if not result then
		return nil, errorCode
	end
	return tonumber(result.insertId)
end

function AppsPersistence.DeleteAd(id)
	return execute('DELETE FROM coe_apps_classifieds WHERE id = ?', { id })
end

function AppsPersistence.PurgeAds(now)
	return execute('DELETE FROM coe_apps_classifieds WHERE expires_at <= ?', { now })
end

-- Insta ---------------------------------------------------------------------------------------------

function AppsPersistence.InsertMedia(characterId, data)
	local result, errorCode = execute('INSERT INTO coe_apps_insta_media (character_id, data) VALUES (?, ?)', { characterId, data })
	if not result then
		return nil, errorCode
	end
	return tonumber(result.insertId)
end

function AppsPersistence.Media(id)
	local rows, errorCode = query('SELECT data FROM coe_apps_insta_media WHERE id = ?', { id })
	if not rows then
		return nil, errorCode
	end
	return rows[1] and rows[1].data or nil
end

function AppsPersistence.DeleteMedia(id)
	return execute('DELETE FROM coe_apps_insta_media WHERE id = ?', { id })
end

function AppsPersistence.InsertPost(post)
	local result, errorCode = execute([[
		INSERT INTO coe_apps_insta_posts (character_id, author, handle, caption, image, created_at) VALUES (?, ?, ?, ?, ?, ?)
	]], { post.characterId, post.author, post.handle, post.caption, post.image, post.createdAt })
	if not result then
		return nil, errorCode
	end
	return tonumber(result.insertId)
end

function AppsPersistence.Post(id)
	local rows, errorCode = query('SELECT id, character_id, image FROM coe_apps_insta_posts WHERE id = ?', { id })
	if not rows then
		return nil, errorCode
	end
	local row = rows[1]
	return row and { id = tonumber(row.id), characterId = tostring(row.character_id), image = row.image } or false
end

function AppsPersistence.DeletePost(id)
	return execute('DELETE FROM coe_apps_insta_posts WHERE id = ?', { id })
end

-- Mais recentes primeiro; `before` pagina pelo id. O limite é inteiro validado (LIMIT não aceita placeholder em todo driver).
function AppsPersistence.Feed(characterId, before, limit, author)
	local filter, parameters = 'p.id < ?', { characterId, before }
	if author then
		filter = filter .. ' AND p.character_id = ?'
		parameters[#parameters + 1] = author
	end
	local rows, errorCode = query(([[
		SELECT p.id, p.character_id, p.author, p.handle, p.caption, p.image, p.created_at,
			(SELECT COUNT(*) FROM coe_apps_insta_likes l WHERE l.post_id = p.id) AS likes,
			(SELECT COUNT(*) FROM coe_apps_insta_likes m WHERE m.post_id = p.id AND m.character_id = ?) AS liked
		FROM coe_apps_insta_posts p WHERE %s ORDER BY p.id DESC LIMIT %d
	]]):format(filter, math.floor(limit)), parameters)
	if not rows then
		return nil, errorCode
	end
	local list = {}
	for _, row in ipairs(rows) do
		list[#list + 1] = {
			id = tonumber(row.id), characterId = tostring(row.character_id), author = row.author, handle = row.handle,
			caption = row.caption, image = row.image, createdAt = tonumber(row.created_at),
			likes = tonumber(row.likes) or 0, liked = (tonumber(row.liked) or 0) > 0
		}
	end
	return list
end

-- Alterna a curtida. Devolve curtido (bool) e o total.
function AppsPersistence.ToggleLike(postId, characterId)
	local inserted, errorCode = execute('INSERT IGNORE INTO coe_apps_insta_likes (post_id, character_id) VALUES (?, ?)', { postId, characterId })
	if not inserted then
		return nil, errorCode
	end
	local liked = (tonumber(inserted.affectedRows) or 0) > 0
	if not liked then
		local removed, removeError = execute('DELETE FROM coe_apps_insta_likes WHERE post_id = ? AND character_id = ?', { postId, characterId })
		if not removed then
			return nil, removeError
		end
	end
	local rows = query('SELECT COUNT(*) AS total FROM coe_apps_insta_likes WHERE post_id = ?', { postId })
	return liked, rows and rows[1] and tonumber(rows[1].total) or 0
end
