MailPersistence = {}

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

local function transaction(statements)
	return callDatabase('Transaction', statements)
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

local function placeholders(count)
	return ('?'):rep(count, ', ')
end

local function concat(first, list)
	local parameters = { first }
	for _, value in ipairs(list) do
		parameters[#parameters + 1] = value
	end
	return parameters
end

local function isDuplicate(errorCode)
	return tostring(errorCode):upper():find('DUP', 1, true) ~= nil
end

function MailPersistence.Initialize()
	return CoeMigrations.Run({
		tableName = 'coe_mail_schema_migrations',
		migrations = MailMigrations,
		execute = execute,
		query = query
	})
end

-- Contas ----------------------------------------------------------------------------------------------

local ACCOUNT_COLUMNS = 'id, address, domain, display_name, signature, password_hash, owner_character'

local function account(row)
	if not row then
		return nil
	end
	return {
		id = int(row.id), address = str(row.address), domain = str(row.domain), name = str(row.display_name),
		signature = str(row.signature), hash = str(row.password_hash), owner = str(row.owner_character)
	}
end

function MailPersistence.AccountByAddress(address)
	local rows, errorCode = query('SELECT ' .. ACCOUNT_COLUMNS .. ' FROM coe_mail_accounts WHERE address = ?', { address })
	if not rows then
		return nil, errorCode
	end
	return account(rows[1]) or false
end

function MailPersistence.AccountById(id)
	local rows, errorCode = query('SELECT ' .. ACCOUNT_COLUMNS .. ' FROM coe_mail_accounts WHERE id = ?', { id })
	if not rows then
		return nil, errorCode
	end
	return account(rows[1]) or false
end

-- Contas criadas pelo personagem (sem o hash).
function MailPersistence.AccountsOf(characterId)
	local rows, errorCode = query('SELECT id, address FROM coe_mail_accounts WHERE owner_character = ? ORDER BY id', { characterId })
	if not rows then
		return nil, errorCode
	end
	local list = {}
	for _, row in ipairs(rows) do
		list[#list + 1] = { id = int(row.id), address = str(row.address) }
	end
	return list
end

-- Endereços existentes entre os informados: [address] = { id, address, name }.
function MailPersistence.AccountsByAddress(addresses)
	if #addresses == 0 then
		return {}
	end
	local rows, errorCode = query(
		'SELECT id, address, display_name FROM coe_mail_accounts WHERE address IN (' .. placeholders(#addresses) .. ')', addresses)
	if not rows then
		return nil, errorCode
	end
	local map = {}
	for _, row in ipairs(rows) do
		map[str(row.address)] = { id = int(row.id), address = str(row.address), name = str(row.display_name) }
	end
	return map
end

-- Cria a conta. Endereço em uso devolve nil, 'address_taken'.
function MailPersistence.InsertAccount(data, now)
	local result, errorCode = execute(
		'INSERT INTO coe_mail_accounts (address, domain, display_name, signature, password_hash, owner_character, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)',
		{ data.address, data.domain, data.name, '', data.hash, data.owner, now })
	if not result then
		if isDuplicate(errorCode) then
			return nil, 'address_taken'
		end
		return nil, errorCode
	end
	return int(result.insertId)
end

function MailPersistence.UpdateProfile(id, name, signature)
	return execute('UPDATE coe_mail_accounts SET display_name = ?, signature = ? WHERE id = ?', { name, signature, id })
end

function MailPersistence.UpdatePassword(id, hash)
	return execute('UPDATE coe_mail_accounts SET password_hash = ? WHERE id = ?', { hash, id })
end

-- Apaga a conta, as caixas e as sessões. As mensagens sem dono saem na limpeza.
function MailPersistence.DeleteAccount(id)
	return transaction({
		{ sql = 'DELETE FROM coe_mail_boxes WHERE account_id = ?', parameters = { id } },
		{ sql = 'DELETE FROM coe_mail_sessions WHERE account_id = ?', parameters = { id } },
		{ sql = 'DELETE FROM coe_mail_accounts WHERE id = ?', parameters = { id } }
	})
end

-- Sessões ---------------------------------------------------------------------------------------------

-- Contas abertas no aparelho, com as não lidas da Entrada.
function MailPersistence.Sessions(deviceKey)
	local rows, errorCode = query([[
		SELECT a.id, a.address, a.display_name, a.signature, a.owner_character,
			(SELECT COUNT(*) FROM coe_mail_boxes b WHERE b.account_id = a.id AND b.folder = 'inbox' AND b.is_read = 0) AS unread
		FROM coe_mail_sessions s JOIN coe_mail_accounts a ON a.id = s.account_id
		WHERE s.device_key = ? ORDER BY s.created_at, a.id
	]], { deviceKey })
	if not rows then
		return nil, errorCode
	end
	local list = {}
	for _, row in ipairs(rows) do
		list[#list + 1] = {
			id = int(row.id), address = str(row.address), name = str(row.display_name), signature = str(row.signature),
			owner = str(row.owner_character), unread = int(row.unread) or 0
		}
	end
	return list
end

function MailPersistence.AddSession(deviceKey, accountId, now)
	return execute('INSERT IGNORE INTO coe_mail_sessions (device_key, account_id, created_at) VALUES (?, ?, ?)', { deviceKey, accountId, now })
end

function MailPersistence.RemoveSession(deviceKey, accountId)
	return execute('DELETE FROM coe_mail_sessions WHERE device_key = ? AND account_id = ?', { deviceKey, accountId })
end

-- Sai de todos os outros aparelhos (troca ou redefinição de senha).
function MailPersistence.RemoveOtherSessions(accountId, deviceKey)
	return execute('DELETE FROM coe_mail_sessions WHERE account_id = ? AND device_key <> ?', { accountId, deviceKey })
end

-- Aparelhos com sessão nas contas: lista de { device, account }.
function MailPersistence.SessionsOf(accountIds)
	if #accountIds == 0 then
		return {}
	end
	local rows, errorCode = query(
		'SELECT device_key, account_id FROM coe_mail_sessions WHERE account_id IN (' .. placeholders(#accountIds) .. ')', accountIds)
	if not rows then
		return nil, errorCode
	end
	local list = {}
	for _, row in ipairs(rows) do
		list[#list + 1] = { device = str(row.device_key), account = int(row.account_id) }
	end
	return list
end

-- Caixas ----------------------------------------------------------------------------------------------

-- Totais por pasta: { inbox = { total, unread }, ..., starred = { total } }.
function MailPersistence.Counts(accountId)
	local rows, errorCode = query([[
		SELECT folder, COUNT(*) AS total, SUM(is_read = 0) AS unread, SUM(starred = 1 AND folder <> 'trash') AS starred
		FROM coe_mail_boxes WHERE account_id = ? GROUP BY folder
	]], { accountId })
	if not rows then
		return nil, errorCode
	end
	local counts = { starred = { total = 0, unread = 0 } }
	for _, row in ipairs(rows) do
		counts[str(row.folder)] = { total = int(row.total) or 0, unread = int(tonumber(row.unread) or 0) or 0 }
		counts.starred.total = counts.starred.total + (int(tonumber(row.starred) or 0) or 0)
	end
	return counts
end

-- Mensagens guardadas por conta: [accountId] = total.
function MailPersistence.Totals(accountIds)
	if #accountIds == 0 then
		return {}
	end
	local rows, errorCode = query(
		'SELECT account_id, COUNT(*) AS total FROM coe_mail_boxes WHERE account_id IN (' .. placeholders(#accountIds) .. ') GROUP BY account_id',
		accountIds)
	if not rows then
		return nil, errorCode
	end
	local map = {}
	for _, row in ipairs(rows) do
		map[int(row.account_id)] = int(row.total) or 0
	end
	return map
end

local function likeTerm(term)
	return '%' .. term:gsub('[\\%%_]', '\\%0') .. '%'
end

-- Página de uma pasta (mais nova primeiro). before: id da última caixa já mostrada.
function MailPersistence.List(accountId, folder, search, before, limit)
	local sql = {
		[[SELECT b.id, b.folder, b.role, b.is_read, b.starred, m.sender_address, m.sender_name, m.subject,
			LEFT(m.body, 140) AS snippet, m.to_list, m.created_at
		FROM coe_mail_boxes b JOIN coe_mail_messages m ON m.id = b.message_id WHERE b.account_id = ?]]
	}
	local parameters = { accountId }
	if folder == 'starred' then
		sql[#sql + 1] = "AND b.starred = 1 AND b.folder <> 'trash'"
	else
		sql[#sql + 1] = 'AND b.folder = ?'
		parameters[#parameters + 1] = folder
	end
	if search then
		local like = likeTerm(search)
		sql[#sql + 1] = 'AND (m.subject LIKE ? OR m.body LIKE ? OR m.sender_address LIKE ? OR m.sender_name LIKE ? OR m.to_list LIKE ?)'
		for _ = 1, 5 do
			parameters[#parameters + 1] = like
		end
	end
	if before then
		sql[#sql + 1] = 'AND b.id < ?'
		parameters[#parameters + 1] = before
	end
	sql[#sql + 1] = ('ORDER BY b.id DESC LIMIT %d'):format(limit + 1)
	local rows, errorCode = query(table.concat(sql, ' '), parameters)
	if not rows then
		return nil, errorCode
	end
	local list = {}
	for index, row in ipairs(rows) do
		if index > limit then
			break
		end
		list[#list + 1] = {
			id = int(row.id), folder = str(row.folder), sent = str(row.role) == 'from', read = truthy(row.is_read),
			starred = truthy(row.starred), from = str(row.sender_address), fromName = str(row.sender_name),
			subject = str(row.subject), snippet = str(row.snippet), to = str(row.to_list), at = int(row.created_at) or 0
		}
	end
	return list, #rows > limit
end

-- Mensagem completa de uma caixa da conta (Cco só para quem enviou).
function MailPersistence.Box(accountId, boxId)
	local rows, errorCode = query([[
		SELECT b.id, b.message_id, b.folder, b.role, b.is_read, b.starred, m.sender_address, m.sender_name, m.subject, m.body,
			m.to_list, m.cc_list, m.bcc_list, m.created_at
		FROM coe_mail_boxes b JOIN coe_mail_messages m ON m.id = b.message_id WHERE b.id = ? AND b.account_id = ?
	]], { boxId, accountId })
	if not rows then
		return nil, errorCode
	end
	local row = rows[1]
	if not row then
		return false
	end
	local sent = str(row.role) == 'from'
	return {
		id = int(row.id), messageId = int(row.message_id), folder = str(row.folder), sent = sent, read = truthy(row.is_read),
		starred = truthy(row.starred), from = str(row.sender_address), fromName = str(row.sender_name), subject = str(row.subject),
		body = str(row.body), to = str(row.to_list), cc = str(row.cc_list), bcc = sent and str(row.bcc_list) or '',
		at = int(row.created_at) or 0
	}
end

local function inIds(sql, accountId, ids, before)
	local parameters = {}
	for _, value in ipairs(before or {}) do
		parameters[#parameters + 1] = value
	end
	parameters[#parameters + 1] = accountId
	for _, id in ipairs(ids) do
		parameters[#parameters + 1] = id
	end
	return execute(sql .. ' WHERE account_id = ? AND id IN (' .. placeholders(#ids) .. ')', parameters)
end

function MailPersistence.SetRead(accountId, ids, value)
	return inIds('UPDATE coe_mail_boxes SET is_read = ?', accountId, ids, { value and 1 or 0 })
end

function MailPersistence.SetStarred(accountId, ids, value)
	return inIds('UPDATE coe_mail_boxes SET starred = ?', accountId, ids, { value and 1 or 0 })
end

-- Move caixas. archive: Entrada/Enviados para o Arquivo. trash: tudo menos rascunhos para a Lixeira.
-- restore: da Lixeira ou do Arquivo de volta para a Entrada (recebidas) ou Enviados (enviadas).
local MOVES = {
	archive = "SET folder = 'archive', moved_at = ? WHERE folder IN ('inbox', 'sent') AND",
	trash = "SET folder = 'trash', moved_at = ? WHERE folder IN ('inbox', 'sent', 'archive') AND",
	restore = "SET folder = IF(role = 'from', 'sent', 'inbox'), moved_at = ? WHERE folder IN ('trash', 'archive') AND"
}

function MailPersistence.Move(accountId, ids, operation, now)
	local parameters = concat(now, { accountId })
	for _, id in ipairs(ids) do
		parameters[#parameters + 1] = id
	end
	return execute('UPDATE coe_mail_boxes ' .. MOVES[operation] .. ' account_id = ? AND id IN (' .. placeholders(#ids) .. ')', parameters)
end

-- Apaga para sempre (só da Lixeira e dos Rascunhos).
function MailPersistence.Delete(accountId, ids)
	local parameters = concat(accountId, ids)
	return execute("DELETE FROM coe_mail_boxes WHERE folder IN ('trash', 'drafts') AND account_id = ? AND id IN (" .. placeholders(#ids) .. ')',
		parameters)
end

function MailPersistence.EmptyTrash(accountId)
	return execute("DELETE FROM coe_mail_boxes WHERE account_id = ? AND folder = 'trash'", { accountId })
end

-- Grava a mensagem e entrega nas caixas. boxes: lista de { account, folder, role, read }.
-- draftId: rascunho que vira esta mensagem (sai dos Rascunhos na mesma transação).
function MailPersistence.Deliver(message, boxes, now, draftId, draftAccount)
	local statements = {
		{
			sql = 'INSERT INTO coe_mail_messages (sender_address, sender_name, subject, body, to_list, cc_list, bcc_list, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
			parameters = { message.from, message.fromName, message.subject, message.body, message.to, message.cc, message.bcc, now }
		},
		{ sql = 'SET @coe_mail_message = LAST_INSERT_ID()', parameters = {} }
	}
	local values, parameters = {}, {}
	for _, box in ipairs(boxes) do
		values[#values + 1] = '(?, @coe_mail_message, ?, ?, ?, 0, ?)'
		parameters[#parameters + 1] = box.account
		parameters[#parameters + 1] = box.folder
		parameters[#parameters + 1] = box.role
		parameters[#parameters + 1] = box.read and 1 or 0
		parameters[#parameters + 1] = now
	end
	statements[#statements + 1] = {
		sql = 'INSERT INTO coe_mail_boxes (account_id, message_id, folder, role, is_read, starred, moved_at) VALUES ' .. table.concat(values, ', '),
		parameters = parameters
	}
	if draftId then
		statements[#statements + 1] = {
			sql = "DELETE FROM coe_mail_boxes WHERE id = ? AND account_id = ? AND folder = 'drafts'", parameters = { draftId, draftAccount }
		}
	end
	local result, errorCode = transaction(statements)
	if not result then
		return nil, errorCode or 'database_error'
	end
	return int(result[1] and result[1].insertId) or true
end

-- Cria ou atualiza um rascunho. Devolve o id da caixa (ou false se o rascunho não existe mais).
function MailPersistence.SaveDraft(accountId, boxId, sender, draft, now)
	if boxId then
		local result, errorCode = execute([[
			UPDATE coe_mail_messages m JOIN coe_mail_boxes b ON b.message_id = m.id
			SET m.sender_address = ?, m.sender_name = ?, m.subject = ?, m.body = ?, m.to_list = ?, m.cc_list = ?, m.bcc_list = ?,
				m.created_at = ?, b.moved_at = ?
			WHERE b.id = ? AND b.account_id = ? AND b.folder = 'drafts'
		]], { sender.address, sender.name, draft.subject, draft.body, draft.to, draft.cc, draft.bcc, now, now, boxId, accountId })
		if not result then
			return nil, errorCode
		end
		return (tonumber(result.affectedRows) or 0) > 0 and boxId or false
	end
	local result, errorCode = transaction({
		{
			sql = 'INSERT INTO coe_mail_messages (sender_address, sender_name, subject, body, to_list, cc_list, bcc_list, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
			parameters = { sender.address, sender.name, draft.subject, draft.body, draft.to, draft.cc, draft.bcc, now }
		},
		{
			sql = "INSERT INTO coe_mail_boxes (account_id, message_id, folder, role, is_read, starred, moved_at) VALUES (?, LAST_INSERT_ID(), 'drafts', 'from', 1, 0, ?)",
			parameters = { accountId, now }
		}
	})
	if not result then
		return nil, errorCode
	end
	return int(result[2] and result[2].insertId)
end

-- Limpeza: Lixeira vencida e mensagens que nenhuma caixa usa mais.
function MailPersistence.Purge(trashBefore)
	local trash = execute("DELETE FROM coe_mail_boxes WHERE folder = 'trash' AND moved_at < ?", { trashBefore })
	local orphans = execute(
		'DELETE FROM coe_mail_messages WHERE NOT EXISTS (SELECT 1 FROM coe_mail_boxes b WHERE b.message_id = coe_mail_messages.id)')
	return (trash and tonumber(trash.affectedRows) or 0), (orphans and tonumber(orphans.affectedRows) or 0)
end
