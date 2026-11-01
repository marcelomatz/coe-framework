PhonePersistence = {}

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

-- Troca cada `?` cujo valor é nil por NULL: tabela com nil no meio não chega inteira ao coe_database.
-- Só para valores de INSERT/SET (em WHERE, `= NULL` nunca casa).
local function bind(sql, ...)
	local values, count = { ... }, select('#', ...)
	local parameters, index = {}, 0
	local text = sql:gsub('%?', function()
		index = index + 1
		local value = values[index]
		if value == nil then
			return 'NULL'
		end
		parameters[#parameters + 1] = value
		return '?'
	end)
	assert(index == count, 'bind: quantidade de parâmetros')
	return text, parameters
end

local function limit(value)
	return math.max(1, math.min(200, math.floor(tonumber(value) or 1)))
end

-- Acesso direto para o upgrade do telefone básico (server/upgrade.lua).
function PhonePersistence.Database()
	return {
		query = query,
		execute = execute,
		transaction = function(statements) return callDatabase('Transaction', statements) end
	}
end

function PhonePersistence.Initialize()
	return CoeMigrations.Run({
		tableName = 'coe_phone_schema_migrations',
		migrations = PhoneMigrations,
		execute = execute,
		query = query
	})
end

-- Aparelhos -------------------------------------------------------------------------------------------

local DEVICE_COLUMNS = 'serial, model, owner_character, face_character, passcode, data, bound'

-- { serial, model, owner_character, face_character, passcode, data, bound } ou false.
function PhonePersistence.Device(serial)
	local rows, errorCode = query('SELECT ' .. DEVICE_COLUMNS .. ' FROM coe_phone_devices WHERE serial = ?', { serial })
	if not rows then
		return nil, errorCode
	end
	return rows[1] or false
end

-- Aparelho migrado (de antes dos itens com serial) que o personagem ainda não vinculou a um item.
function PhonePersistence.LegacyDevice(characterId)
	local rows, errorCode = query('SELECT ' .. DEVICE_COLUMNS .. ' FROM coe_phone_devices WHERE owner_character = ? AND bound = 0 LIMIT 1', { characterId })
	if not rows then
		return nil, errorCode
	end
	return rows[1] or false
end

-- true se criou; false se o serial já existia.
function PhonePersistence.CreateDevice(serial, model, ownerCharacter)
	local result, errorCode = execute('INSERT IGNORE INTO coe_phone_devices (serial, model, owner_character, bound) VALUES (?, ?, ?, 0)', { serial, model, ownerCharacter })
	if not result then
		return nil, errorCode
	end
	return (tonumber(result.affectedRows) or 0) > 0
end

-- true se este processo vinculou (o aparelho ainda estava livre).
function PhonePersistence.BindDevice(serial)
	local result = execute('UPDATE coe_phone_devices SET bound = 1 WHERE serial = ? AND bound = 0', { serial })
	return result ~= nil and (tonumber(result.affectedRows) or 0) > 0
end

function PhonePersistence.SaveSettings(serial, data, now)
	return execute('UPDATE coe_phone_devices SET data = ?, updated_at = ? WHERE serial = ?', { data, now, serial })
end

-- hash false remove a senha.
function PhonePersistence.SavePasscode(serial, hash, data, now)
	return execute(bind('UPDATE coe_phone_devices SET passcode = ?, data = ?, updated_at = ? WHERE serial = ?', hash or nil, data, now, serial))
end

-- Rosto cadastrado no reconhecimento facial (characterId nil limpa).
function PhonePersistence.SetFace(serial, characterId)
	return execute(bind('UPDATE coe_phone_devices SET face_character = ? WHERE serial = ?', characterId, serial))
end

-- Chips ------------------------------------------------------------------------------------------------

local SIM_COLUMNS = 'iccid, number, carrier, holder_character, device_serial, slot'

local function toSim(row)
	return {
		iccid = tostring(row.iccid),
		number = tostring(row.number),
		carrier = tostring(row.carrier),
		holder = row.holder_character ~= nil and tostring(row.holder_character) or nil,
		serial = row.device_serial ~= nil and tostring(row.device_serial) or nil,
		slot = tonumber(row.slot)
	}
end

local function oneSim(sql, parameters)
	local rows, errorCode = query(sql, parameters)
	if not rows then
		return nil, errorCode
	end
	return rows[1] and toSim(rows[1]) or false
end

function PhonePersistence.Sim(iccid)
	return oneSim('SELECT ' .. SIM_COLUMNS .. ' FROM coe_phone_sims WHERE iccid = ?', { iccid })
end

function PhonePersistence.SimByNumber(number)
	return oneSim('SELECT ' .. SIM_COLUMNS .. ' FROM coe_phone_sims WHERE number = ?', { number })
end

-- Chips dentro do aparelho, por slot.
function PhonePersistence.SimsIn(serial)
	local rows, errorCode = query('SELECT ' .. SIM_COLUMNS .. ' FROM coe_phone_sims WHERE device_serial = ? ORDER BY slot', { serial })
	if not rows then
		return nil, errorCode
	end
	local list = {}
	for _, row in ipairs(rows) do
		list[#list + 1] = toSim(row)
	end
	return list
end

-- Primeiro número de que o personagem é titular; false se nenhum.
function PhonePersistence.HeldNumber(characterId)
	local rows, errorCode = query('SELECT number FROM coe_phone_sims WHERE holder_character = ? ORDER BY created_at, iccid LIMIT 1', { characterId })
	if not rows then
		return nil, errorCode
	end
	return rows[1] and tostring(rows[1].number) or false
end

-- true se gravou; false se o ICCID, o número ou o slot do aparelho já estavam em uso.
function PhonePersistence.CreateSim(iccid, number, holder, serial, slot)
	local result, errorCode = execute(bind([[
		INSERT IGNORE INTO coe_phone_sims (iccid, number, holder_character, device_serial, slot) VALUES (?, ?, ?, ?, ?)
	]], iccid, number, holder, serial, slot))
	if not result then
		return nil, errorCode
	end
	return (tonumber(result.affectedRows) or 0) > 0
end

-- Coloca o chip (fora de aparelho) no slot. true se colocou; slot ocupado dá erro de chave única (false).
function PhonePersistence.InsertSim(iccid, serial, slot)
	local result = execute('UPDATE coe_phone_sims SET device_serial = ?, slot = ? WHERE iccid = ? AND device_serial IS NULL', { serial, slot, iccid })
	return result ~= nil and (tonumber(result.affectedRows) or 0) > 0
end

-- Tira o chip do aparelho. true se tirou.
function PhonePersistence.EjectSim(iccid, serial)
	local result = execute('UPDATE coe_phone_sims SET device_serial = NULL, slot = NULL WHERE iccid = ? AND device_serial = ?', { iccid, serial })
	return result ~= nil and (tonumber(result.affectedRows) or 0) > 0
end

-- Contatos (do aparelho) ---------------------------------------------------------------------------

function PhonePersistence.Contacts(serial)
	return query('SELECT id, name, number FROM coe_phone_device_contacts WHERE serial = ? ORDER BY name', { serial })
end

function PhonePersistence.CountContacts(serial)
	local rows, errorCode = query('SELECT COUNT(*) AS total FROM coe_phone_device_contacts WHERE serial = ?', { serial })
	if not rows then
		return nil, errorCode
	end
	return tonumber(rows[1] and rows[1].total) or 0
end

function PhonePersistence.ContactByNumber(serial, number)
	local rows, errorCode = query('SELECT id FROM coe_phone_device_contacts WHERE serial = ? AND number = ?', { serial, number })
	if not rows then
		return nil, errorCode
	end
	return rows[1] and tonumber(rows[1].id) or false
end

function PhonePersistence.AddContact(serial, name, number)
	return execute('INSERT INTO coe_phone_device_contacts (serial, name, number) VALUES (?, ?, ?)', { serial, name, number })
end

function PhonePersistence.UpdateContact(serial, id, name, number)
	return execute('UPDATE coe_phone_device_contacts SET name = ?, number = ? WHERE id = ? AND serial = ?', { name, number, id, serial })
end

function PhonePersistence.DeleteContact(serial, id)
	return execute('DELETE FROM coe_phone_device_contacts WHERE id = ? AND serial = ?', { id, serial })
end

-- Fotos (do aparelho) -----------------------------------------------------------------------------

-- { count, bytes } das fotos do aparelho.
function PhonePersistence.PhotoUsage(serial)
	local rows, errorCode = query('SELECT COUNT(*) AS total, COALESCE(SUM(bytes), 0) AS bytes FROM coe_phone_photos WHERE serial = ?', { serial })
	if not rows then
		return nil, errorCode
	end
	local row = rows[1] or {}
	return { count = tonumber(row.total) or 0, bytes = tonumber(row.bytes) or 0 }
end

function PhonePersistence.AddPhoto(serial, characterId, image, thumb, now)
	local text, parameters = bind('INSERT INTO coe_phone_photos (serial, character_id, image, thumb, bytes, created_at) VALUES (?, ?, ?, ?, ?, ?)',
		serial, characterId, image, thumb, #image + #thumb, now)
	return execute(text, parameters)
end

-- Miniaturas, mais recentes primeiro; `before` (id) pagina.
function PhonePersistence.Photos(serial, before, max)
	if before then
		return query(('SELECT id, thumb, created_at FROM coe_phone_photos WHERE serial = ? AND id < ? ORDER BY id DESC LIMIT %d'):format(limit(max)), { serial, before })
	end
	return query(('SELECT id, thumb, created_at FROM coe_phone_photos WHERE serial = ? ORDER BY id DESC LIMIT %d'):format(limit(max)), { serial })
end

-- Foto inteira com os vizinhos (anterior = mais nova, próxima = mais antiga) ou false.
function PhonePersistence.Photo(serial, id)
	local rows, errorCode = query([[
		SELECT p.id, p.image, p.created_at,
			(SELECT MIN(n.id) FROM coe_phone_photos n WHERE n.serial = p.serial AND n.id > p.id) AS newer,
			(SELECT MAX(o.id) FROM coe_phone_photos o WHERE o.serial = p.serial AND o.id < p.id) AS older
		FROM coe_phone_photos p WHERE p.serial = ? AND p.id = ?
	]], { serial, id })
	if not rows then
		return nil, errorCode
	end
	return rows[1] or false
end

function PhonePersistence.DeletePhoto(serial, id)
	return execute('DELETE FROM coe_phone_photos WHERE id = ? AND serial = ?', { id, serial })
end

-- Carteira (do aparelho; não vai para a nuvem) ----------------------------------------------------

function PhonePersistence.WalletCards(serial)
	return query('SELECT card_id, is_default FROM coe_phone_wallet WHERE serial = ? ORDER BY added_at, card_id', { serial })
end

function PhonePersistence.WalletAdd(serial, cardId, isDefault, now)
	return execute('INSERT INTO coe_phone_wallet (serial, card_id, is_default, added_at) VALUES (?, ?, ?, ?)', { serial, cardId, isDefault and 1 or 0, now })
end

function PhonePersistence.WalletRemove(serial, cardId)
	local result, errorCode = execute('DELETE FROM coe_phone_wallet WHERE serial = ? AND card_id = ?', { serial, cardId })
	if not result then
		return nil, errorCode
	end
	return (tonumber(result.affectedRows) or 0) > 0
end

-- Deixa só `cardId` como padrão (nil: nenhum).
function PhonePersistence.WalletDefault(serial, cardId)
	return execute('UPDATE coe_phone_wallet SET is_default = IF(card_id = ?, 1, 0) WHERE serial = ?', { cardId or 0, serial })
end
-- Mensagens -------------------------------------------------------------------------------------------

-- Última mensagem de cada conversa do número, mais recentes primeiro.
function PhonePersistence.Threads(number, max)
	return query(([[
		SELECT m.id, m.sender, m.receiver, m.body, m.created_at
		FROM coe_phone_messages m
		JOIN (
			SELECT MAX(id) AS id FROM coe_phone_messages
			WHERE sender = ? OR receiver = ?
			GROUP BY IF(sender = ?, receiver, sender)
		) last ON last.id = m.id
		ORDER BY m.id DESC LIMIT %d
	]]):format(limit(max)), { number, number, number })
end

function PhonePersistence.Unread(number)
	return query('SELECT sender, COUNT(*) AS total FROM coe_phone_messages WHERE receiver = ? AND read_at IS NULL GROUP BY sender', { number })
end

function PhonePersistence.Conversation(number, other, max)
	return query(([[
		SELECT id, sender, body, created_at FROM coe_phone_messages
		WHERE (sender = ? AND receiver = ?) OR (sender = ? AND receiver = ?)
		ORDER BY id DESC LIMIT %d
	]]):format(limit(max)), { number, other, other, number })
end

function PhonePersistence.MarkRead(number, other, now)
	return execute('UPDATE coe_phone_messages SET read_at = ? WHERE receiver = ? AND sender = ? AND read_at IS NULL', { now, number, other })
end

function PhonePersistence.AddMessage(sender, receiver, body, now)
	return execute('INSERT INTO coe_phone_messages (sender, receiver, body, created_at) VALUES (?, ?, ?, ?)', { sender, receiver, body, now })
end

-- Chamadas --------------------------------------------------------------------------------------------

function PhonePersistence.AddCall(caller, callee, status, duration, now, kind)
	return execute('INSERT INTO coe_phone_calls (caller, callee, status, duration, created_at, kind) VALUES (?, ?, ?, ?, ?, ?)', { caller, callee, status, duration, now, kind == 'video' and 'video' or 'voice' })
end

function PhonePersistence.Recents(number, max)
	return query(([[
		SELECT id, caller, callee, status, duration, created_at, kind FROM coe_phone_calls
		WHERE caller = ? OR callee = ? ORDER BY id DESC LIMIT %d
	]]):format(limit(max)), { number, number })
end
