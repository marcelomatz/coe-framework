-- Persistência do telefone básico (coe_database). Funções síncronas: retornam resultado ou nil + código de erro.
MobilePersistence = {}

local config = MobileConfig

local function callDatabase(exportName, ...)
	if GetResourceState('coe_database') ~= 'started' then
		return nil, 'database_unavailable'
	end
	local response = promise.new()
	local database = exports['coe_database']
	local args = { database, ... }
	args[#args + 1] = function(success, result, errorCode)
		response:resolve({ success = success == true, result = result, error = errorCode })
	end
	if not pcall(function() database[exportName](table.unpack(args)) end) then
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

-- LIMIT vai no texto (inteiro já validado): parâmetros em LIMIT falham em alguns MySQL com prepared statements.
local function limit(value)
	return math.max(1, math.min(500, math.tointeger(value) or 1))
end

function MobilePersistence.Initialize()
	return CoeMigrations.Run({
		tableName = 'coe_mobile_schema_migrations',
		migrations = MobileMigrations,
		execute = execute,
		query = query
	})
end

-- Números ------------------------------------------------------------------------------------------------------

function MobilePersistence.NumberOf(characterId)
	local rows, errorCode = query('SELECT number FROM coe_mobile_numbers WHERE character_id = ? LIMIT 1', { characterId })
	if not rows then
		return nil, errorCode
	end
	return rows[1] and rows[1].number or false
end

function MobilePersistence.CharacterOf(number)
	local rows, errorCode = query('SELECT character_id FROM coe_mobile_numbers WHERE number = ? LIMIT 1', { number })
	if not rows then
		return nil, errorCode
	end
	return rows[1] and tostring(rows[1].character_id) or false
end

---Número do personagem; gera um na primeira vez. `generate()` devolve um candidato (pode colidir: tenta de novo).
function MobilePersistence.EnsureNumber(characterId, generate)
	local current, errorCode = MobilePersistence.NumberOf(characterId)
	if current == nil then
		return nil, errorCode
	end
	if current then
		return current
	end
	for _ = 1, 25 do
		local inserted, insertError = execute(
			'INSERT IGNORE INTO coe_mobile_numbers (character_id, number, created_at) VALUES (?, ?, ?)',
			{ characterId, generate(), os.time() })
		if not inserted then
			return nil, insertError
		end
		-- Lê de novo: vale o número gravado, seja este ou o de um pedido simultâneo do mesmo personagem.
		current, errorCode = MobilePersistence.NumberOf(characterId)
		if current == nil then
			return nil, errorCode
		end
		if current then
			return current
		end
	end
	return nil, 'number_exhausted'
end

-- Contatos -----------------------------------------------------------------------------------------------------

function MobilePersistence.Contacts(characterId)
	local rows, errorCode = query(('SELECT id, number, name FROM coe_mobile_contacts WHERE character_id = ? ORDER BY name LIMIT %d')
		:format(limit(config.Contacts.Max)), { characterId })
	if not rows then
		return nil, errorCode
	end
	local out = {}
	for _, row in ipairs(rows) do
		out[#out + 1] = { id = math.tointeger(row.id), number = row.number, name = row.name }
	end
	return out
end

function MobilePersistence.ContactCount(characterId)
	local rows, errorCode = query('SELECT COUNT(*) AS total FROM coe_mobile_contacts WHERE character_id = ?', { characterId })
	if not rows then
		return nil, errorCode
	end
	return math.tointeger(tonumber(rows[1] and rows[1].total) or 0)
end

---Cria (id nil) ou altera um contato. O mesmo número não aparece duas vezes na agenda: retorna 'duplicate_contact'.
function MobilePersistence.SaveContact(characterId, id, number, name)
	local result, errorCode
	if id then
		result, errorCode = execute('UPDATE coe_mobile_contacts SET number = ?, name = ? WHERE id = ? AND character_id = ?',
			{ number, name, id, characterId })
	else
		result, errorCode = execute('INSERT INTO coe_mobile_contacts (character_id, number, name, created_at) VALUES (?, ?, ?, ?)',
			{ characterId, number, name, os.time() })
	end
	if not result then
		return nil, errorCode == 'ER_DUP_ENTRY' and 'duplicate_contact' or errorCode
	end
	if id and (tonumber(result.affectedRows) or 0) < 1 then
		return nil, 'contact_not_found'
	end
	return true
end

function MobilePersistence.DeleteContact(characterId, id)
	local result, errorCode = execute('DELETE FROM coe_mobile_contacts WHERE id = ? AND character_id = ?', { id, characterId })
	if not result then
		return nil, errorCode
	end
	return true
end

---Nome salvo para `number` na agenda de `characterId` (ou false).
function MobilePersistence.ContactName(characterId, number)
	local rows, errorCode = query('SELECT name FROM coe_mobile_contacts WHERE character_id = ? AND number = ? LIMIT 1',
		{ characterId, number })
	if not rows then
		return nil, errorCode
	end
	return rows[1] and rows[1].name or false
end

-- Mensagens ----------------------------------------------------------------------------------------------------

function MobilePersistence.SendMessage(sender, receiver, body)
	local result, errorCode = execute('INSERT INTO coe_mobile_messages (sender, receiver, body, created_at) VALUES (?, ?, ?, ?)',
		{ sender, receiver, body, os.time() })
	if not result then
		return nil, errorCode
	end
	return math.tointeger(tonumber(result.insertId)) or true
end

---Conversas do número: a última mensagem com cada contraparte e quantas não lidas.
function MobilePersistence.Threads(number)
	local rows, errorCode = query(([[
		SELECT m.id, m.sender, m.receiver, m.body, m.created_at FROM coe_mobile_messages m
		JOIN (
			SELECT MAX(id) AS id FROM coe_mobile_messages
			WHERE (sender = ? AND sender_deleted = 0) OR (receiver = ? AND receiver_deleted = 0)
			GROUP BY IF(sender = ?, receiver, sender)
		) latest ON latest.id = m.id
		ORDER BY m.id DESC LIMIT %d
	]]):format(limit(config.Messages.ThreadsLimit)), { number, number, number })
	if not rows then
		return nil, errorCode
	end
	local unread, unreadError = query([[
		SELECT sender, COUNT(*) AS total FROM coe_mobile_messages
		WHERE receiver = ? AND read_at IS NULL AND receiver_deleted = 0 GROUP BY sender
	]], { number })
	if not unread then
		return nil, unreadError
	end
	local counts = {}
	for _, row in ipairs(unread) do
		counts[row.sender] = math.tointeger(tonumber(row.total)) or 0
	end
	local out = {}
	for _, row in ipairs(rows) do
		local other = row.sender == number and row.receiver or row.sender
		out[#out + 1] = {
			number = other, body = row.body, at = math.tointeger(tonumber(row.created_at)),
			mine = row.sender == number, unread = counts[other] or 0
		}
	end
	return out
end

---Mensagens trocadas com `other`, da mais antiga para a mais nova; marca as recebidas como lidas.
function MobilePersistence.Thread(number, other)
	local rows, errorCode = query(([[
		SELECT id, sender, body, created_at FROM coe_mobile_messages
		WHERE (sender = ? AND receiver = ? AND sender_deleted = 0) OR (sender = ? AND receiver = ? AND receiver_deleted = 0)
		ORDER BY id DESC LIMIT %d
	]]):format(limit(config.Messages.HistoryLimit)), { number, other, other, number })
	if not rows then
		return nil, errorCode
	end
	local marked, markError = execute(
		'UPDATE coe_mobile_messages SET read_at = ? WHERE receiver = ? AND sender = ? AND read_at IS NULL',
		{ os.time(), number, other })
	if not marked then
		return nil, markError
	end
	local out = {}
	for index = #rows, 1, -1 do
		local row = rows[index]
		out[#out + 1] = {
			id = math.tointeger(tonumber(row.id)), body = row.body, at = math.tointeger(tonumber(row.created_at)),
			mine = row.sender == number
		}
	end
	return out
end

---Apaga a conversa só para `number`; a outra pessoa continua vendo.
function MobilePersistence.DeleteThread(number, other)
	local sent, sentError = execute('UPDATE coe_mobile_messages SET sender_deleted = 1 WHERE sender = ? AND receiver = ?',
		{ number, other })
	if not sent then
		return nil, sentError
	end
	local received, receivedError = execute(
		'UPDATE coe_mobile_messages SET receiver_deleted = 1, read_at = COALESCE(read_at, ?) WHERE receiver = ? AND sender = ?',
		{ os.time(), number, other })
	if not received then
		return nil, receivedError
	end
	return true
end

function MobilePersistence.UnreadCount(number)
	local rows, errorCode = query(
		'SELECT COUNT(*) AS total FROM coe_mobile_messages WHERE receiver = ? AND read_at IS NULL AND receiver_deleted = 0',
		{ number })
	if not rows then
		return nil, errorCode
	end
	return math.tointeger(tonumber(rows[1] and rows[1].total) or 0)
end

-- Ligações -----------------------------------------------------------------------------------------------------

function MobilePersistence.LogCall(caller, callee, status, duration)
	return execute('INSERT INTO coe_mobile_calls (caller, callee, status, duration, created_at) VALUES (?, ?, ?, ?, ?)',
		{ caller, callee, status, math.max(0, math.tointeger(duration) or 0), os.time() })
end

---Ligações feitas e recebidas pelo número, da mais nova para a mais antiga.
function MobilePersistence.Recents(number)
	local size = limit(config.Calls.RecentsLimit)
	local rows, errorCode = query(([[
		SELECT id, caller, callee, status, duration, created_at FROM (
			(SELECT id, caller, callee, status, duration, created_at FROM coe_mobile_calls WHERE caller = ? ORDER BY id DESC LIMIT %d)
			UNION ALL
			(SELECT id, caller, callee, status, duration, created_at FROM coe_mobile_calls WHERE callee = ? AND caller <> ? ORDER BY id DESC LIMIT %d)
		) calls ORDER BY id DESC LIMIT %d
	]]):format(size, size, size), { number, number, number })
	if not rows then
		return nil, errorCode
	end
	local out = {}
	for _, row in ipairs(rows) do
		local outgoing = row.caller == number
		out[#out + 1] = {
			number = outgoing and row.callee or row.caller, outgoing = outgoing, status = row.status,
			duration = math.tointeger(tonumber(row.duration)) or 0, at = math.tointeger(tonumber(row.created_at))
		}
	end
	return out
end

-- Ajustes ------------------------------------------------------------------------------------------------------

function MobilePersistence.Settings(characterId)
	local rows, errorCode = query('SELECT data FROM coe_mobile_settings WHERE character_id = ? LIMIT 1', { characterId })
	if not rows then
		return nil, errorCode
	end
	local raw = rows[1] and rows[1].data
	local ok, decoded = pcall(json.decode, raw or '{}')
	return (ok and type(decoded) == 'table') and decoded or {}
end

function MobilePersistence.SaveSettings(characterId, settings)
	return execute([[
		INSERT INTO coe_mobile_settings (character_id, data, updated_at) VALUES (?, ?, ?)
		ON DUPLICATE KEY UPDATE data = VALUES(data), updated_at = VALUES(updated_at)
	]], { characterId, json.encode(settings), os.time() })
end
