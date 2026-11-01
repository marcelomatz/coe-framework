DeepwebPersistence = {}

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

-- Parâmetro nil (coluna NULL, ex.: comunidade do sistema, fornecedor NPC, comentário sem pai) não atravessa o export:
-- a tabela Lua fica com buraco e o coe_database recusa (invalid_parameters). Troca o `?` desse parâmetro por NULL.
local function bind(sql, parameters)
	parameters = parameters or {}
	local count = select(2, sql:gsub('%?', '?'))
	local hasNil = false
	for index = 1, count do
		if parameters[index] == nil then
			hasNil = true
			break
		end
	end
	if not hasNil then
		return sql, parameters
	end
	local list, index = {}, 0
	local text = sql:gsub('%?', function()
		index = index + 1
		local value = parameters[index]
		if value == nil then
			return 'NULL'
		end
		list[#list + 1] = value
		return '?'
	end)
	return text, list
end

local function query(sql, parameters)
	sql, parameters = bind(sql, parameters)
	return callDatabase('Query', sql, parameters)
end

local function execute(sql, parameters)
	sql, parameters = bind(sql, parameters)
	return callDatabase('Execute', sql, parameters)
end

DeepwebPersistence.Bind = bind

local function int(value)
	return math.tointeger(tonumber(value))
end

local function str(value)
	return value ~= nil and tostring(value) or ''
end

local function isDuplicate(errorCode)
	return tostring(errorCode):upper():find('DUP', 1, true) ~= nil
end

function DeepwebPersistence.Initialize()
	return CoeMigrations.Run({
		tableName = 'coe_deepweb_schema_migrations',
		migrations = DeepwebMigrations,
		execute = execute,
		query = query
	})
end

-- Apelidos --------------------------------------------------------------------------------------------

local function handle(row)
	if not row then
		return nil
	end
	return {
		id = int(row.id), handle = str(row.handle), hash = str(row.password_hash), owner = str(row.owner_character),
		reputation = int(row.reputation) or 0, createdAt = int(row.created_at)
	}
end

local HANDLE_COLUMNS = 'id, handle, password_hash, owner_character, reputation, created_at'

function DeepwebPersistence.HandleByName(name)
	local rows, errorCode = query('SELECT ' .. HANDLE_COLUMNS .. ' FROM coe_deepweb_handles WHERE handle = ?', { name })
	if not rows then
		return nil, errorCode
	end
	return handle(rows[1]) or false
end

function DeepwebPersistence.HandleById(id)
	local rows, errorCode = query('SELECT ' .. HANDLE_COLUMNS .. ' FROM coe_deepweb_handles WHERE id = ?', { id })
	if not rows then
		return nil, errorCode
	end
	return handle(rows[1]) or false
end

function DeepwebPersistence.HandlesOf(characterId)
	local rows, errorCode = query('SELECT id, handle FROM coe_deepweb_handles WHERE owner_character = ? ORDER BY id', { characterId })
	if not rows then
		return nil, errorCode
	end
	local list = {}
	for _, row in ipairs(rows) do
		list[#list + 1] = { id = int(row.id), handle = str(row.handle) }
	end
	return list
end

-- Nome em uso devolve nil, 'handle_taken'.
function DeepwebPersistence.InsertHandle(name, hash, characterId, now)
	local result, errorCode = execute('INSERT INTO coe_deepweb_handles (handle, password_hash, owner_character, created_at, last_seen_at) VALUES (?, ?, ?, ?, ?)',
		{ name, hash, characterId, now, now })
	if not result then
		return nil, isDuplicate(errorCode) and 'handle_taken' or errorCode
	end
	return int(result.insertId)
end

function DeepwebPersistence.UpdateHandlePassword(id, hash)
	return execute('UPDATE coe_deepweb_handles SET password_hash = ? WHERE id = ?', { hash, id })
end

function DeepwebPersistence.TouchHandle(id, now)
	return execute('UPDATE coe_deepweb_handles SET last_seen_at = ? WHERE id = ?', { now, id })
end

-- Sessões ---------------------------------------------------------------------------------------------

-- Apelido conectado no aparelho (sem o hash), false se nenhum, nil + erro.
function DeepwebPersistence.Session(deviceKey)
	local rows, errorCode = query([[
		SELECT h.id, h.handle, h.password_hash, h.owner_character, h.reputation, h.created_at
		FROM coe_deepweb_sessions s JOIN coe_deepweb_handles h ON h.id = s.handle_id WHERE s.device_key = ?
	]], { deviceKey })
	if not rows then
		return nil, errorCode
	end
	return handle(rows[1]) or false
end

function DeepwebPersistence.SetSession(deviceKey, handleId, now)
	return execute('INSERT INTO coe_deepweb_sessions (device_key, handle_id, created_at) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE handle_id = VALUES(handle_id), created_at = VALUES(created_at)',
		{ deviceKey, handleId, now })
end

function DeepwebPersistence.ClearSession(deviceKey)
	return execute('DELETE FROM coe_deepweb_sessions WHERE device_key = ?', { deviceKey })
end

-- Encerra o apelido em todos os outros aparelhos (troca de senha).
function DeepwebPersistence.ClearOtherSessions(handleId, deviceKey)
	return execute('DELETE FROM coe_deepweb_sessions WHERE handle_id = ? AND device_key <> ?', { handleId, deviceKey })
end

-- Navegador no celular/tablet -------------------------------------------------------------------------

function DeepwebPersistence.BrowserInstalled(deviceKey)
	local rows, errorCode = query('SELECT 1 AS ok FROM coe_deepweb_browsers WHERE device_key = ?', { deviceKey })
	if not rows then
		return nil, errorCode
	end
	return rows[1] ~= nil
end

function DeepwebPersistence.InstallBrowser(deviceKey, characterId, now)
	return execute('INSERT IGNORE INTO coe_deepweb_browsers (device_key, installed_by, installed_at) VALUES (?, ?, ?)', { deviceKey, characterId, now })
end

-- Computadores ----------------------------------------------------------------------------------------

-- { kind, hash, face } ou false. face: personagem do rosto cadastrado ('' sem reconhecimento facial).
function DeepwebPersistence.Device(deviceKey)
	local rows, errorCode = query('SELECT kind, password_hash, face_character FROM coe_deepweb_devices WHERE device_key = ?', { deviceKey })
	if not rows then
		return nil, errorCode
	end
	local row = rows[1]
	if not row then
		return false
	end
	return { kind = str(row.kind), hash = str(row.password_hash), face = row.face_character ~= nil and str(row.face_character) or '' }
end

-- Rosto do reconhecimento facial (personagem) ou nil para desligar.
function DeepwebPersistence.SetDeviceFace(deviceKey, characterId)
	if characterId == nil then
		return execute('UPDATE coe_deepweb_devices SET face_character = NULL WHERE device_key = ?', { deviceKey })
	end
	return execute('UPDATE coe_deepweb_devices SET face_character = ? WHERE device_key = ?', { characterId, deviceKey })
end

function DeepwebPersistence.EnsureDevice(deviceKey, kind, now)
	return execute('INSERT IGNORE INTO coe_deepweb_devices (device_key, kind, created_at) VALUES (?, ?, ?)', { deviceKey, kind, now })
end

function DeepwebPersistence.SetDevicePassword(deviceKey, hash)
	return execute('UPDATE coe_deepweb_devices SET password_hash = ? WHERE device_key = ?', { hash, deviceKey })
end

-- Máquinas instaladas ---------------------------------------------------------------------------------

local RIG_COLUMNS = 'id, kind, serial, property_id, space_owner, x, y, z, heading, installed_by, installed_at, payout_address, mining, mined_total, last_payout, last_status, last_tick_at'

local function rig(row)
	return {
		id = int(row.id), kind = str(row.kind), serial = str(row.serial), propertyId = str(row.property_id), owner = str(row.space_owner),
		x = tonumber(row.x) or 0.0, y = tonumber(row.y) or 0.0, z = tonumber(row.z) or 0.0, heading = tonumber(row.heading) or 0.0,
		installedBy = str(row.installed_by), installedAt = int(row.installed_at), payout = str(row.payout_address),
		mining = int(row.mining) == 1, minedTotal = int(row.mined_total) or 0, lastPayout = int(row.last_payout) or 0,
		lastStatus = str(row.last_status), lastTickAt = int(row.last_tick_at) or 0
	}
end

local function rigs(sql, parameters)
	local rows, errorCode = query('SELECT ' .. RIG_COLUMNS .. ' FROM coe_deepweb_rigs ' .. sql, parameters)
	if not rows then
		return nil, errorCode
	end
	local list = {}
	for _, row in ipairs(rows) do
		list[#list + 1] = rig(row)
	end
	return list
end

function DeepwebPersistence.RigsInSpace(propertyId, owner)
	return rigs('WHERE property_id = ? AND space_owner = ? ORDER BY id', { propertyId, owner })
end

function DeepwebPersistence.RigById(id)
	local list, errorCode = rigs('WHERE id = ?', { id })
	if not list then
		return nil, errorCode
	end
	return list[1] or false
end

function DeepwebPersistence.MiningRigs()
	return rigs('WHERE mining = 1 ORDER BY id', {})
end

-- Série repetida devolve nil, 'serial_taken'.
function DeepwebPersistence.InsertRig(data, now)
	local result, errorCode = execute([[
		INSERT INTO coe_deepweb_rigs (kind, serial, property_id, space_owner, x, y, z, heading, installed_by, installed_at)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
	]], { data.kind, data.serial, data.propertyId, data.owner, data.x, data.y, data.z, data.heading, data.installedBy, now })
	if not result then
		return nil, isDuplicate(errorCode) and 'serial_taken' or errorCode
	end
	return int(result.insertId)
end

-- Desmonta: apaga só se ainda existir (duas pessoas desmontando ao mesmo tempo: só uma leva o item).
function DeepwebPersistence.DeleteRig(id)
	local result, errorCode = execute('DELETE FROM coe_deepweb_rigs WHERE id = ?', { id })
	if not result then
		return nil, errorCode
	end
	return (int(result.affectedRows) or 0) == 1
end

function DeepwebPersistence.SetMining(id, payout, enabled)
	return execute('UPDATE coe_deepweb_rigs SET payout_address = ?, mining = ? WHERE id = ?', { payout, enabled and 1 or 0, id })
end

function DeepwebPersistence.RecordTick(id, status, payout, now)
	return execute('UPDATE coe_deepweb_rigs SET last_status = ?, last_payout = ?, mined_total = mined_total + ?, last_tick_at = ? WHERE id = ?',
		{ status, payout, payout, now, id })
end

-- Estado (marcas de uma vez só) -----------------------------------------------------------------------

function DeepwebPersistence.StateFlag(name)
	local rows, errorCode = query('SELECT value FROM coe_deepweb_state WHERE name = ?', { name })
	if not rows then
		return nil, errorCode
	end
	return rows[1] ~= nil
end

function DeepwebPersistence.SetStateFlag(name)
	return execute('INSERT IGNORE INTO coe_deepweb_state (name, value) VALUES (?, 1)', { name })
end

-- Favoritos -------------------------------------------------------------------------------------------

function DeepwebPersistence.Bookmarks(deviceKey)
	local rows, errorCode = query('SELECT address, title, created_at FROM coe_deepweb_bookmarks WHERE device_key = ? ORDER BY created_at, address', { deviceKey })
	if not rows then
		return nil, errorCode
	end
	local list = {}
	for _, row in ipairs(rows) do
		list[#list + 1] = { address = str(row.address), title = str(row.title), createdAt = int(row.created_at) }
	end
	return list
end

function DeepwebPersistence.AddBookmark(deviceKey, address, title, now)
	return execute('INSERT INTO coe_deepweb_bookmarks (device_key, address, title, created_at) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE title = VALUES(title)',
		{ deviceKey, address, title, now })
end

function DeepwebPersistence.RemoveBookmark(deviceKey, address)
	return execute('DELETE FROM coe_deepweb_bookmarks WHERE device_key = ? AND address = ?', { deviceKey, address })
end

-- Sites -----------------------------------------------------------------------------------------------

local SITE_COLUMNS = 'domain, app, title, description, keywords, blocks, owner_handle, active, listed, created_at, updated_at'

local function site(row)
	if not row then
		return nil
	end
	return {
		domain = str(row.domain), app = str(row.app), title = str(row.title), description = str(row.description),
		keywords = str(row.keywords), blocks = row.blocks ~= nil and str(row.blocks) or '', ownerHandle = int(row.owner_handle),
		active = int(row.active) == 1, listed = int(row.listed) ~= 0, createdAt = int(row.created_at), updatedAt = int(row.updated_at)
	}
end

function DeepwebPersistence.SiteByDomain(domain)
	local rows, errorCode = query('SELECT ' .. SITE_COLUMNS .. ' FROM coe_deepweb_sites WHERE domain = ?', { domain })
	if not rows then
		return nil, errorCode
	end
	return site(rows[1]) or false
end

function DeepwebPersistence.Sites()
	local rows, errorCode = query('SELECT ' .. SITE_COLUMNS .. ' FROM coe_deepweb_sites ORDER BY app = \'\', domain', {})
	if not rows then
		return nil, errorCode
	end
	local list = {}
	for _, row in ipairs(rows) do
		list[#list + 1] = site(row)
	end
	return list
end

-- Cria ou atualiza. data: { domain, app, title, description, keywords, blocks (json), ownerHandle, active, listed }.
function DeepwebPersistence.SaveSite(data, now)
	return execute([[
		INSERT INTO coe_deepweb_sites (domain, app, title, description, keywords, blocks, owner_handle, active, listed, created_at, updated_at)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
		ON DUPLICATE KEY UPDATE app = VALUES(app), title = VALUES(title), description = VALUES(description), keywords = VALUES(keywords),
			blocks = VALUES(blocks), owner_handle = VALUES(owner_handle), active = VALUES(active), listed = VALUES(listed), updated_at = VALUES(updated_at)
	]], { data.domain, data.app or '', data.title, data.description or '', data.keywords or '', data.blocks, data.ownerHandle, data.active == false and 0 or 1, data.listed == false and 0 or 1, now, now })
end

function DeepwebPersistence.DeleteSite(domain)
	local result, errorCode = execute('DELETE FROM coe_deepweb_sites WHERE domain = ? AND app = \'\'', { domain })
	if not result then
		return nil, errorCode
	end
	return (int(result.affectedRows) or 0) == 1
end

-- Busca (pattern já escapado para LIKE) ------------------------------------------------------------------

function DeepwebPersistence.SearchSites(pattern, limit)
	local rows, errorCode = query(('SELECT domain, app, title, description FROM coe_deepweb_sites WHERE active = 1 AND listed = 1 AND (LOWER(title) LIKE ? OR LOWER(description) LIKE ? OR LOWER(keywords) LIKE ? OR domain LIKE ?) ORDER BY app <> \'\' DESC, domain LIMIT %d'):format(limit),
		{ pattern, pattern, pattern, pattern })
	if not rows then
		return nil, errorCode
	end
	local list = {}
	for _, row in ipairs(rows) do
		list[#list + 1] = { domain = str(row.domain), app = str(row.app), title = str(row.title), description = str(row.description) }
	end
	return list
end

function DeepwebPersistence.SearchPosts(pattern, limit)
	local rows, errorCode = query(([[
		SELECT p.id, p.title, p.body, p.score, p.comments, p.created_at, c.slug, h.handle
		FROM coe_deepweb_posts p JOIN coe_deepweb_communities c ON c.id = p.community_id JOIN coe_deepweb_handles h ON h.id = p.handle_id
		WHERE p.removed = 0 AND (LOWER(p.title) LIKE ? OR LOWER(p.body) LIKE ?) ORDER BY p.score DESC, p.id DESC LIMIT %d
	]]):format(limit), { pattern, pattern })
	if not rows then
		return nil, errorCode
	end
	local list = {}
	for _, row in ipairs(rows) do
		list[#list + 1] = {
			id = int(row.id), title = str(row.title), body = str(row.body):sub(1, 240), score = int(row.score) or 0,
			comments = int(row.comments) or 0, createdAt = int(row.created_at), community = str(row.slug), author = str(row.handle)
		}
	end
	return list
end

-- Rabbit ----------------------------------------------------------------------------------------------

local function community(row)
	return {
		id = int(row.id), slug = str(row.slug), title = str(row.title), description = str(row.description),
		createdBy = int(row.created_by), createdAt = int(row.created_at), posts = int(row.posts) or 0,
		moderator = row.moderator ~= nil and str(row.moderator) or nil
	}
end

local COMMUNITY_SELECT = [[
	SELECT c.id, c.slug, c.title, c.description, c.created_by, c.created_at, h.handle AS moderator,
		(SELECT COUNT(*) FROM coe_deepweb_posts p WHERE p.community_id = c.id AND p.removed = 0) AS posts
	FROM coe_deepweb_communities c LEFT JOIN coe_deepweb_handles h ON h.id = c.created_by
]]

function DeepwebPersistence.Communities()
	local rows, errorCode = query(COMMUNITY_SELECT .. ' ORDER BY posts DESC, c.id', {})
	if not rows then
		return nil, errorCode
	end
	local list = {}
	for _, row in ipairs(rows) do
		list[#list + 1] = community(row)
	end
	return list
end

function DeepwebPersistence.CommunityBySlug(slug)
	local rows, errorCode = query(COMMUNITY_SELECT .. ' WHERE c.slug = ?', { slug })
	if not rows then
		return nil, errorCode
	end
	return rows[1] and community(rows[1]) or false
end

function DeepwebPersistence.CommunitiesCreatedBy(handleId)
	local rows, errorCode = query('SELECT COUNT(*) AS total FROM coe_deepweb_communities WHERE created_by = ?', { handleId })
	if not rows then
		return nil, errorCode
	end
	return int(rows[1] and rows[1].total) or 0
end

-- Nome em uso devolve nil, 'slug_taken'. handleId nil = comunidade do sistema.
function DeepwebPersistence.InsertCommunity(data, now)
	local result, errorCode = execute('INSERT INTO coe_deepweb_communities (slug, title, description, created_by, created_at) VALUES (?, ?, ?, ?, ?)',
		{ data.slug, data.title, data.description or '', data.handleId, now })
	if not result then
		return nil, isDuplicate(errorCode) and 'slug_taken' or errorCode
	end
	return int(result.insertId)
end

local POST_SELECT = [[
	SELECT p.id, p.community_id, p.handle_id, p.title, p.body, p.score, p.comments, p.removed, p.created_at, c.slug, h.handle
	FROM coe_deepweb_posts p JOIN coe_deepweb_communities c ON c.id = p.community_id JOIN coe_deepweb_handles h ON h.id = p.handle_id
]]

local function post(row, full)
	local body = str(row.body)
	return {
		id = int(row.id), communityId = int(row.community_id), handleId = int(row.handle_id), title = str(row.title),
		body = full and body or body:sub(1, 280), score = int(row.score) or 0, comments = int(row.comments) or 0,
		removed = int(row.removed) == 1, createdAt = int(row.created_at), community = str(row.slug), author = str(row.handle)
	}
end

-- filter: { communityId, handleId, sort = 'new'|'top'|'recent', since, offset, limit }. 'recent' traz os candidatos
-- do "em alta" (ordenados depois no servidor).
function DeepwebPersistence.Posts(filter)
	local where, parameters = { 'p.removed = 0' }, {}
	if filter.communityId then
		where[#where + 1] = 'p.community_id = ?'
		parameters[#parameters + 1] = filter.communityId
	end
	if filter.handleId then
		where[#where + 1] = 'p.handle_id = ?'
		parameters[#parameters + 1] = filter.handleId
	end
	if filter.since then
		where[#where + 1] = 'p.created_at >= ?'
		parameters[#parameters + 1] = filter.since
	end
	local order = filter.sort == 'top' and 'p.score DESC, p.id DESC' or 'p.id DESC'
	local rows, errorCode = query(POST_SELECT .. ' WHERE ' .. table.concat(where, ' AND ')
		.. (' ORDER BY %s LIMIT %d OFFSET %d'):format(order, math.floor(filter.limit), math.floor(filter.offset or 0)), parameters)
	if not rows then
		return nil, errorCode
	end
	local list = {}
	for _, row in ipairs(rows) do
		list[#list + 1] = post(row, false)
	end
	return list
end

function DeepwebPersistence.PostById(id)
	local rows, errorCode = query(POST_SELECT .. ' WHERE p.id = ?', { id })
	if not rows then
		return nil, errorCode
	end
	return rows[1] and post(rows[1], true) or false
end

function DeepwebPersistence.LastPostAt(handleId)
	local rows, errorCode = query('SELECT MAX(created_at) AS at FROM coe_deepweb_posts WHERE handle_id = ?', { handleId })
	if not rows then
		return nil, errorCode
	end
	return int(rows[1] and rows[1].at) or 0
end

function DeepwebPersistence.InsertPost(data, now)
	local result, errorCode = execute('INSERT INTO coe_deepweb_posts (community_id, handle_id, title, body, created_at) VALUES (?, ?, ?, ?, ?)',
		{ data.communityId, data.handleId, data.title, data.body, now })
	if not result then
		return nil, errorCode
	end
	return int(result.insertId)
end

function DeepwebPersistence.RemovePost(id)
	return execute('UPDATE coe_deepweb_posts SET removed = 1 WHERE id = ?', { id })
end

function DeepwebPersistence.Comments(postId, limit)
	local rows, errorCode = query(([[
		SELECT m.id, m.post_id, m.parent_id, m.handle_id, m.body, m.score, m.removed, m.created_at, h.handle
		FROM coe_deepweb_comments m JOIN coe_deepweb_handles h ON h.id = m.handle_id WHERE m.post_id = ? ORDER BY m.id LIMIT %d
	]]):format(math.floor(limit)), { postId })
	if not rows then
		return nil, errorCode
	end
	local list = {}
	for _, row in ipairs(rows) do
		list[#list + 1] = {
			id = int(row.id), postId = int(row.post_id), parentId = int(row.parent_id), handleId = int(row.handle_id),
			body = str(row.body), score = int(row.score) or 0, removed = int(row.removed) == 1, createdAt = int(row.created_at), author = str(row.handle)
		}
	end
	return list
end

function DeepwebPersistence.CommentById(id)
	local rows, errorCode = query('SELECT id, post_id, parent_id, handle_id, removed FROM coe_deepweb_comments WHERE id = ?', { id })
	if not rows then
		return nil, errorCode
	end
	local row = rows[1]
	return row and { id = int(row.id), postId = int(row.post_id), parentId = int(row.parent_id), handleId = int(row.handle_id), removed = int(row.removed) == 1 } or false
end

function DeepwebPersistence.LastCommentAt(handleId)
	local rows, errorCode = query('SELECT MAX(created_at) AS at FROM coe_deepweb_comments WHERE handle_id = ?', { handleId })
	if not rows then
		return nil, errorCode
	end
	return int(rows[1] and rows[1].at) or 0
end

function DeepwebPersistence.InsertComment(data, now)
	local result, errorCode = execute('INSERT INTO coe_deepweb_comments (post_id, parent_id, handle_id, body, created_at) VALUES (?, ?, ?, ?, ?)',
		{ data.postId, data.parentId, data.handleId, data.body, now })
	if not result then
		return nil, errorCode
	end
	execute('UPDATE coe_deepweb_posts SET comments = comments + 1 WHERE id = ?', { data.postId })
	return int(result.insertId)
end

function DeepwebPersistence.RemoveComment(id)
	return execute('UPDATE coe_deepweb_comments SET removed = 1 WHERE id = ?', { id })
end

-- Votos: target 'p' ou 'c'.
function DeepwebPersistence.VoteOf(target, targetId, handleId)
	local rows, errorCode = query('SELECT value FROM coe_deepweb_votes WHERE target = ? AND target_id = ? AND handle_id = ?', { target, targetId, handleId })
	if not rows then
		return nil, errorCode
	end
	return int(rows[1] and rows[1].value) or 0
end

-- Grava o voto (0 apaga) e soma `delta` na pontuação do alvo.
function DeepwebPersistence.SetVote(target, targetId, handleId, value, delta)
	local ok, errorCode
	if value == 0 then
		ok, errorCode = execute('DELETE FROM coe_deepweb_votes WHERE target = ? AND target_id = ? AND handle_id = ?', { target, targetId, handleId })
	else
		ok, errorCode = execute('INSERT INTO coe_deepweb_votes (target, target_id, handle_id, value) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE value = VALUES(value)',
			{ target, targetId, handleId, value })
	end
	if not ok then
		return nil, errorCode
	end
	if delta ~= 0 then
		local tableName = target == 'p' and 'coe_deepweb_posts' or 'coe_deepweb_comments'
		execute('UPDATE ' .. tableName .. ' SET score = score + ? WHERE id = ?', { delta, targetId })
	end
	return true
end

-- Votos do apelido nos alvos: [id] = valor.
function DeepwebPersistence.VotesOf(handleId, target, ids)
	local map = {}
	if #ids == 0 then
		return map
	end
	local marks, parameters = {}, { handleId, target }
	for index, id in ipairs(ids) do
		marks[index] = '?'
		parameters[#parameters + 1] = id
	end
	local rows, errorCode = query(('SELECT target_id, value FROM coe_deepweb_votes WHERE handle_id = ? AND target = ? AND target_id IN (%s)'):format(table.concat(marks, ',')), parameters)
	if not rows then
		return nil, errorCode
	end
	for _, row in ipairs(rows) do
		map[int(row.target_id)] = int(row.value)
	end
	return map
end

-- Perfil público de um apelido: pontos (soma das pontuações), posts e comentários.
function DeepwebPersistence.HandleStats(handleId)
	local rows, errorCode = query([[
		SELECT
			(SELECT COALESCE(SUM(score), 0) FROM coe_deepweb_posts WHERE handle_id = ? AND removed = 0) AS post_score,
			(SELECT COUNT(*) FROM coe_deepweb_posts WHERE handle_id = ? AND removed = 0) AS posts,
			(SELECT COALESCE(SUM(score), 0) FROM coe_deepweb_comments WHERE handle_id = ? AND removed = 0) AS comment_score,
			(SELECT COUNT(*) FROM coe_deepweb_comments WHERE handle_id = ? AND removed = 0) AS comments
	]], { handleId, handleId, handleId, handleId })
	if not rows then
		return nil, errorCode
	end
	local row = rows[1] or {}
	return {
		karma = (int(tonumber(row.post_score)) or 0) + (int(tonumber(row.comment_score)) or 0),
		posts = int(tonumber(row.posts)) or 0, comments = int(tonumber(row.comments)) or 0
	}
end

-- Deep Market -----------------------------------------------------------------------------------------

local LISTING_SELECT = [[
	SELECT l.id, l.seller_handle, l.vendor, l.kind, l.category, l.title, l.description, l.item, l.item_count, l.price, l.stock,
		l.payout_address, l.status, l.sold, l.created_at, l.updated_at, h.handle, h.reputation
	FROM coe_deepweb_listings l LEFT JOIN coe_deepweb_handles h ON h.id = l.seller_handle
]]

local function listing(row)
	return {
		id = int(row.id), sellerHandle = int(row.seller_handle), vendor = str(row.vendor), kind = str(row.kind), category = str(row.category),
		title = str(row.title), description = str(row.description), item = str(row.item), count = int(row.item_count) or 0,
		price = int(row.price) or 0, stock = int(row.stock) or 0, payout = str(row.payout_address), status = str(row.status),
		sold = int(row.sold) or 0, createdAt = int(row.created_at), updatedAt = int(row.updated_at),
		seller = row.handle ~= nil and str(row.handle) or nil, reputation = int(row.reputation) or 0
	}
end

-- filter: { category, pattern, sellerHandle, npc, status ('active' por padrão; 'any' = todos menos removidos), offset, limit }.
function DeepwebPersistence.Listings(filter)
	local where, parameters = {}, {}
	if filter.status == 'any' then
		where[#where + 1] = 'l.status <> \'removed\''
	else
		where[#where + 1] = 'l.status = ?'
		parameters[#parameters + 1] = filter.status or 'active'
	end
	if filter.category then
		where[#where + 1] = 'l.category = ?'
		parameters[#parameters + 1] = filter.category
	end
	if filter.pattern then
		where[#where + 1] = '(LOWER(l.title) LIKE ? OR LOWER(l.description) LIKE ?)'
		parameters[#parameters + 1] = filter.pattern
		parameters[#parameters + 1] = filter.pattern
	end
	if filter.sellerHandle then
		where[#where + 1] = 'l.seller_handle = ?'
		parameters[#parameters + 1] = filter.sellerHandle
	elseif filter.npc then
		where[#where + 1] = 'l.seller_handle IS NULL'
	end
	local rows, errorCode = query(LISTING_SELECT .. ' WHERE ' .. table.concat(where, ' AND ')
		.. (' ORDER BY l.stock > 0 DESC, l.sold DESC, l.id DESC LIMIT %d OFFSET %d'):format(math.floor(filter.limit), math.floor(filter.offset or 0)), parameters)
	if not rows then
		return nil, errorCode
	end
	local list = {}
	for _, row in ipairs(rows) do
		list[#list + 1] = listing(row)
	end
	return list
end

function DeepwebPersistence.ListingById(id)
	local rows, errorCode = query(LISTING_SELECT .. ' WHERE l.id = ?', { id })
	if not rows then
		return nil, errorCode
	end
	return rows[1] and listing(rows[1]) or false
end

function DeepwebPersistence.CountListings(handleId)
	local rows, errorCode = query('SELECT COUNT(*) AS total FROM coe_deepweb_listings WHERE seller_handle = ? AND status <> \'removed\'', { handleId })
	if not rows then
		return nil, errorCode
	end
	return int(rows[1] and rows[1].total) or 0
end

-- data: { sellerHandle, vendor, kind, category, title, description, item, count, price, stock, payout, status }.
function DeepwebPersistence.InsertListing(data, now)
	local result, errorCode = execute([[
		INSERT INTO coe_deepweb_listings (seller_handle, vendor, kind, category, title, description, item, item_count, price, stock, payout_address, status, created_at, updated_at)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
	]], { data.sellerHandle, data.vendor or '', data.kind, data.category, data.title, data.description, data.item, data.count, data.price, data.stock,
		data.payout or '', data.status or 'active', now, now })
	if not result then
		return nil, errorCode
	end
	return int(result.insertId)
end

function DeepwebPersistence.UpdateListing(id, data, now)
	return execute([[
		UPDATE coe_deepweb_listings SET vendor = ?, kind = ?, category = ?, title = ?, description = ?, item = ?, item_count = ?, price = ?, stock = ?,
			payout_address = ?, status = ?, updated_at = ? WHERE id = ?
	]], { data.vendor or '', data.kind, data.category, data.title, data.description, data.item, data.count, data.price, data.stock, data.payout or '',
		data.status or 'active', now, id })
end

function DeepwebPersistence.SetListingStatus(id, status, now)
	return execute('UPDATE coe_deepweb_listings SET status = ?, updated_at = ? WHERE id = ?', { status, now, id })
end

-- Reserva estoque (só se houver). Devolve true se reservou.
function DeepwebPersistence.TakeStock(id, quantity)
	local result, errorCode = execute('UPDATE coe_deepweb_listings SET stock = stock - ?, sold = sold + ? WHERE id = ? AND status = \'active\' AND stock >= ?',
		{ quantity, quantity, id, quantity })
	if not result then
		return nil, errorCode
	end
	return (int(result.affectedRows) or 0) == 1
end

function DeepwebPersistence.ReturnStock(id, quantity)
	return execute('UPDATE coe_deepweb_listings SET stock = stock + ?, sold = GREATEST(sold, ?) - ? WHERE id = ?', { quantity, quantity, quantity, id })
end

local ORDER_COLUMNS = [[o.id, o.listing_id, o.kind, o.title, o.seller_handle, o.vendor, o.buyer_handle, o.buyer_character, o.item, o.item_count, o.quantity,
	o.total, o.fee, o.buyer_address, o.payout_address, o.drop_index, o.status, o.note, o.created_at, o.delivered_at, o.closed_at, o.settled,
	s.handle AS seller_name, b.handle AS buyer_name, r.rating]]
local ORDER_FROM = [[ FROM coe_deepweb_orders o LEFT JOIN coe_deepweb_handles s ON s.id = o.seller_handle
	LEFT JOIN coe_deepweb_handles b ON b.id = o.buyer_handle LEFT JOIN coe_deepweb_reviews r ON r.order_id = o.id ]]

local function order(row)
	return {
		id = int(row.id), listingId = int(row.listing_id), kind = str(row.kind), title = str(row.title), sellerHandle = int(row.seller_handle),
		vendor = str(row.vendor), buyerHandle = int(row.buyer_handle), buyerCharacter = str(row.buyer_character), item = str(row.item),
		count = int(row.item_count) or 0, quantity = int(row.quantity) or 0, total = int(row.total) or 0, fee = int(row.fee) or 0,
		buyerAddress = str(row.buyer_address), payout = str(row.payout_address), dropIndex = int(row.drop_index) or 0, status = str(row.status),
		note = str(row.note), createdAt = int(row.created_at), deliveredAt = int(row.delivered_at) or 0, closedAt = int(row.closed_at) or 0,
		seller = row.seller_name ~= nil and str(row.seller_name) or nil, buyer = row.buyer_name ~= nil and str(row.buyer_name) or nil,
		rating = int(row.rating), settled = int(row.settled) == 1
	}
end

local function orders(sql, parameters)
	local rows, errorCode = query('SELECT ' .. ORDER_COLUMNS .. ORDER_FROM .. sql, parameters)
	if not rows then
		return nil, errorCode
	end
	local list = {}
	for _, row in ipairs(rows) do
		list[#list + 1] = order(row)
	end
	return list
end

function DeepwebPersistence.InsertOrder(data, now)
	local result, errorCode = execute([[
		INSERT INTO coe_deepweb_orders (listing_id, kind, title, seller_handle, vendor, buyer_handle, buyer_character, item, item_count, quantity, total, fee,
			buyer_address, payout_address, drop_index, status, created_at, delivered_at)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
	]], { data.listingId, data.kind, data.title, data.sellerHandle, data.vendor or '', data.buyerHandle, data.buyerCharacter, data.item, data.count,
		data.quantity, data.total, data.fee, data.buyerAddress, data.payout, data.dropIndex, data.status, now, data.deliveredAt or 0 })
	if not result then
		return nil, errorCode
	end
	return int(result.insertId)
end

function DeepwebPersistence.OrderById(id)
	local list, errorCode = orders('WHERE o.id = ?', { id })
	if not list then
		return nil, errorCode
	end
	return list[1] or false
end

-- role: 'buyer' ou 'seller'.
function DeepwebPersistence.OrdersOf(handleId, role, limit)
	local column = role == 'seller' and 'o.seller_handle' or 'o.buyer_handle'
	return orders(('WHERE %s = ? ORDER BY o.id DESC LIMIT %d'):format(column, math.floor(limit)), { handleId })
end

function DeepwebPersistence.OrdersByStatus(status, limit)
	return orders(('WHERE o.status = ? ORDER BY o.id LIMIT %d'):format(math.floor(limit)), { status })
end

-- Troca de estado só se ainda estiver em `from` (duas ações ao mesmo tempo: só uma vale). fields: delivered_at,
-- closed_at, note. Devolve true se trocou.
function DeepwebPersistence.MoveOrder(id, from, to, fields, now)
	fields = fields or {}
	local sets, parameters = { 'status = ?' }, { to }
	if fields.delivered then
		sets[#sets + 1] = 'delivered_at = ?'
		parameters[#parameters + 1] = now
	end
	if fields.closed then
		sets[#sets + 1] = 'closed_at = ?'
		parameters[#parameters + 1] = now
	end
	if fields.note then
		sets[#sets + 1] = 'note = ?'
		parameters[#parameters + 1] = fields.note
	end
	parameters[#parameters + 1] = id
	parameters[#parameters + 1] = from
	local result, errorCode = execute(('UPDATE coe_deepweb_orders SET %s WHERE id = ? AND status = ?'):format(table.concat(sets, ', ')), parameters)
	if not result then
		return nil, errorCode
	end
	return (int(result.affectedRows) or 0) == 1
end

function DeepwebPersistence.InsertReview(data, now)
	local result, errorCode = execute('INSERT INTO coe_deepweb_reviews (order_id, seller_handle, buyer_handle, rating, body, created_at) VALUES (?, ?, ?, ?, ?, ?)',
		{ data.orderId, data.sellerHandle, data.buyerHandle, data.rating, data.body or '', now })
	if not result then
		return nil, isDuplicate(errorCode) and 'already_reviewed' or errorCode
	end
	execute('UPDATE coe_deepweb_handles SET reputation = reputation + ? WHERE id = ?', { data.rating - 3, data.sellerHandle })
	return true
end

-- Avaliações de um vendedor: { average, count, recent = { { rating, body, buyer, createdAt } } }.
function DeepwebPersistence.SellerReviews(handleId, limit)
	local rows, errorCode = query(([[
		SELECT r.rating, r.body, r.created_at, h.handle FROM coe_deepweb_reviews r LEFT JOIN coe_deepweb_handles h ON h.id = r.buyer_handle
		WHERE r.seller_handle = ? ORDER BY r.created_at DESC LIMIT %d
	]]):format(math.floor(limit)), { handleId })
	if not rows then
		return nil, errorCode
	end
	local summary = query('SELECT COUNT(*) AS total, COALESCE(AVG(rating), 0) AS average FROM coe_deepweb_reviews WHERE seller_handle = ?', { handleId })
	local recent = {}
	for _, row in ipairs(rows) do
		recent[#recent + 1] = { rating = int(row.rating) or 0, body = str(row.body), createdAt = int(row.created_at), buyer = row.handle ~= nil and str(row.handle) or nil }
	end
	local head = summary and summary[1] or {}
	return { count = int(tonumber(head.total)) or 0, average = tonumber(head.average) or 0, recent = recent }
end

function DeepwebPersistence.MarkSettled(id)
	return execute('UPDATE coe_deepweb_orders SET settled = 1 WHERE id = ?', { id })
end

-- Pedidos num estado final ainda sem o pagamento da custódia (a rede cripto falhou na hora).
function DeepwebPersistence.UnsettledOrders(limit)
	return orders(('WHERE o.settled = 0 AND o.status IN (\'completed\', \'released\', \'cancelled\', \'refunded\') ORDER BY o.id LIMIT %d'):format(math.floor(limit)), {})
end

-- Anúncios de fornecedor NPC já criados (qualquer estado, inclusive removidos).
function DeepwebPersistence.CountVendorListings()
	local rows, errorCode = query('SELECT COUNT(*) AS total FROM coe_deepweb_listings WHERE seller_handle IS NULL', {})
	if not rows then
		return nil, errorCode
	end
	return int(rows[1] and rows[1].total) or 0
end

-- Contato dos sites de perfil ---------------------------------------------------------------------------

local CONTACT_SELECT = [[
	SELECT k.id, k.site, k.handle_id, k.body, k.reply, k.status, k.created_at, k.replied_at, h.handle
	FROM coe_deepweb_contacts k LEFT JOIN coe_deepweb_handles h ON h.id = k.handle_id
]]

local function contact(row)
	return {
		id = int(row.id), site = str(row.site), handleId = int(row.handle_id), handle = row.handle ~= nil and str(row.handle) or nil,
		body = str(row.body), reply = row.reply ~= nil and str(row.reply) or nil, status = str(row.status),
		createdAt = int(row.created_at), repliedAt = int(row.replied_at) or 0
	}
end

local function contacts(sql, parameters)
	local rows, errorCode = query(CONTACT_SELECT .. sql, parameters)
	if not rows then
		return nil, errorCode
	end
	local list = {}
	for _, row in ipairs(rows) do
		list[#list + 1] = contact(row)
	end
	return list
end

-- data: { site, handleId, body }. Devolve o id.
function DeepwebPersistence.InsertContact(data, now)
	local result, errorCode = execute('INSERT INTO coe_deepweb_contacts (site, handle_id, body, status, created_at) VALUES (?, ?, ?, \'open\', ?)',
		{ data.site, data.handleId, data.body, now })
	if not result then
		return nil, errorCode
	end
	return int(result.insertId)
end

-- Mensagens de um apelido para um site (mais novas primeiro).
function DeepwebPersistence.ContactsOf(handleId, site, limit)
	return contacts(('WHERE k.handle_id = ? AND k.site = ? ORDER BY k.id DESC LIMIT %d'):format(math.floor(limit)), { handleId, site })
end

-- { last = created_at da última mensagem do apelido (qualquer site), open = sem resposta neste site }.
function DeepwebPersistence.ContactStats(handleId, site)
	local rows, errorCode = query([[
		SELECT (SELECT COALESCE(MAX(created_at), 0) FROM coe_deepweb_contacts WHERE handle_id = ?) AS last,
			(SELECT COUNT(*) FROM coe_deepweb_contacts WHERE handle_id = ? AND site = ? AND status = 'open') AS open
	]], { handleId, handleId, site })
	if not rows then
		return nil, errorCode
	end
	local row = rows[1] or {}
	return { last = int(tonumber(row.last)) or 0, open = int(tonumber(row.open)) or 0 }
end

function DeepwebPersistence.ContactById(id)
	local list, errorCode = contacts('WHERE k.id = ?', { id })
	if not list then
		return nil, errorCode
	end
	return list[1] or false
end

-- Caixa de entrada do admin: abertas primeiro, depois as mais recentes.
function DeepwebPersistence.ContactInbox(limit)
	return contacts(('ORDER BY k.status = \'open\' DESC, k.id DESC LIMIT %d'):format(math.floor(limit)), {})
end

-- Resposta da staff (também corrige uma resposta já dada). Arquivada não recebe. Devolve true se mudou.
function DeepwebPersistence.ReplyContact(id, reply, now)
	local result, errorCode = execute('UPDATE coe_deepweb_contacts SET reply = ?, status = \'answered\', replied_at = ? WHERE id = ? AND status <> \'closed\'', { reply, now, id })
	if not result then
		return nil, errorCode
	end
	return (int(result.affectedRows) or 0) == 1
end

function DeepwebPersistence.CloseContact(id)
	local result, errorCode = execute('UPDATE coe_deepweb_contacts SET status = \'closed\' WHERE id = ? AND status <> \'closed\'', { id })
	if not result then
		return nil, errorCode
	end
	return (int(result.affectedRows) or 0) == 1
end