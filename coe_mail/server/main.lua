local config = MailConfig

local ready = false
local locks = {}
local lockManager = MailRules.NewLockManager and MailRules.NewLockManager() or nil
local logins = {}
local lastSend = {}
local sendLimiter = MailRules.NewSendLimiter and MailRules.NewSendLimiter(config.Messages.SendCooldownSeconds) or nil
local sessionCache = MailRules.NewSessionCache and MailRules.NewSessionCache(128) or nil
local seen = {}

local HOSTS = { coe_tablet = 'tablet', coe_phone = 'phone' }
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

local function notify(playerId, kind, message)
	pcall(function()
		exports.coe_notify:Notify(playerId, kind, message)
	end)
end

local function characterOf(playerId)
	local snapshot = Core.Players.GetActiveCharacter(playerId)
	if type(snapshot) ~= 'table' or not snapshot.characterId then
		return nil
	end
	local name = (((snapshot.firstName or '') .. ' ' .. (snapshot.lastName or '')):gsub('^%s+', ''):gsub('%s+$', ''))
	return { id = tostring(snapshot.characterId), name = name }
end

local function hash(password)
	local ok, value = pcall(GetPasswordHash, password)
	return ok and type(value) == 'string' and value or nil
end

local function verify(password, stored)
	if type(stored) ~= 'string' or stored == '' then
		return false
	end
	local ok, valid = pcall(VerifyPasswordHash, password, stored)
	return ok and valid == true
end

local function withLock(key, run)
	if lockManager then
		local guard <close>, err = lockManager:acquire(key, 3000)
		if not guard then
			return { ok = false, error = err == 'lock_timeout' and 'busy' or 'busy' }
		end
		local ok, result = pcall(run)
		if not ok then
			log('error', 'gameplay', 'mail_action_failed', { error_code = tostring(result) })
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
		log('error', 'gameplay', 'mail_action_failed', { error_code = tostring(result) })
		return { ok = false, error = 'database_error' }
	end
	return result
end

-- Chave do aparelho: smartphone pelo número de série (passou o aparelho, passou a sessão); tablet pelo personagem.
local function deviceKey(playerId, device, character)
	if device == 'tablet' then
		return 'tablet:' .. character.id
	end
	local ok, info = pcall(function()
		return exports.coe_phone:ActiveDevice(playerId)
	end)
	if not ok or type(info) ~= 'table' or type(info.serial) ~= 'string' then
		return nil
	end
	return 'phone:' .. info.serial
end

-- Lembra o aparelho que cada jogador usa (para o aviso de e-mail novo). Um aparelho só fica com quem o usou por último.
local function remember(playerId, device, key)
	for other, keys in pairs(seen) do
		if other ~= playerId and keys[device] == key then
			keys[device] = nil
		end
	end
	seen[playerId] = seen[playerId] or {}
	seen[playerId][device] = key
end

local function publicAccount(account)
	return { id = account.id, address = account.address, name = account.name, signature = account.signature, unread = account.unread }
end

-- Contas abertas no aparelho, como mapa por id.
local function sessions(key)
	local list = MailPersistence.Sessions(key)
	if not list then
		return nil
	end
	local map = {}
	for _, account in ipairs(list) do
		map[account.id] = account
	end
	return list, map
end

local function sessionAccount(context, payload)
	local id = math.tointeger(tonumber(payload.account))
	local _, map = sessions(context.key)
	if not map then
		return nil, 'database_error'
	end
	local account = id and map[id]
	if not account then
		return nil, 'not_signed_in'
	end
	return account
end

local function senderName(account, character)
	if account.name ~= '' then
		return account.name
	end
	return account.address:match('^[^@]+')
end

local function joinList(list)
	return table.concat(list, ', ')
end

-- Aviso de e-mail novo para quem está com um aparelho conectado na conta.
local function announce(accountIds, sender, subject)
	local list = MailPersistence.SessionsOf(accountIds)
	if not list or #list == 0 then
		return
	end
	local devices = {}
	for _, entry in ipairs(list) do
		devices[entry.device] = true
	end
	local text = ('Novo e-mail de %s%s'):format(sender, subject ~= '' and (': ' .. subject) or '')
	for playerId, keys in pairs(seen) do
		if (keys.phone and devices[keys.phone]) or (keys.tablet and devices[keys.tablet]) then
			notify(playerId, 'info', text)
		end
	end
end

-- Estado ----------------------------------------------------------------------------------------------

function App.state(playerId, character, payload, context)
	local list = sessions(context.key)
	local owned = MailPersistence.AccountsOf(character.id)
	if not list or not owned then
		return { ok = false, error = 'database_error' }
	end
	local accounts = {}
	for _, account in ipairs(list) do
		accounts[#accounts + 1] = publicAccount(account)
	end
	local limits = config.Accounts
	return {
		ok = true,
		domain = config.PublicDomain,
		accounts = accounts,
		owned = owned,
		canCreate = #owned < limits.MaxPerCharacter,
		limits = {
			LocalMin = limits.LocalMin, LocalMax = limits.LocalMax, PasswordMin = limits.PasswordMin, PasswordMax = limits.PasswordMax,
			NameMax = limits.NameMax, SignatureMax = limits.SignatureMax, MaxPerCharacter = limits.MaxPerCharacter,
			MaxRecipients = config.Messages.MaxRecipients, SubjectMax = config.Messages.SubjectMax, BodyMax = config.Messages.BodyMax,
			TrashDays = config.Messages.TrashDays
		}
	}
end

-- Contas ----------------------------------------------------------------------------------------------

local function signIn(context, accountId)
	local list = sessions(context.key)
	if not list then
		return 'database_error'
	end
	for _, account in ipairs(list) do
		if account.id == accountId then
			return nil
		end
	end
	if #list >= config.Login.MaxSessionsPerDevice then
		return 'too_many_sessions'
	end
	if not MailPersistence.AddSession(context.key, accountId, os.time()) then
		return 'database_error'
	end
	return nil
end

function App.create(playerId, character, payload, context)
	return withLock('character:' .. character.id, function()
		local localPart, errorCode = MailRules.LocalPart(config, payload['local'])
		if not localPart then
			return { ok = false, error = errorCode }
		end
		local password
		password, errorCode = MailRules.Password(config, payload.password)
		if not password then
			return { ok = false, error = errorCode }
		end
		local owned = MailPersistence.AccountsOf(character.id)
		if not owned then
			return { ok = false, error = 'database_error' }
		end
		if #owned >= config.Accounts.MaxPerCharacter then
			return { ok = false, error = 'account_limit' }
		end
		local digest = hash(password)
		if not digest then
			return { ok = false, error = 'database_error' }
		end
		local address = localPart .. '@' .. config.PublicDomain
		local name = MailRules.Text(payload.name, config.Accounts.NameMax) or character.name
		local id
		id, errorCode = MailPersistence.InsertAccount({
			address = address, domain = config.PublicDomain, name = MailRules.Text(name, config.Accounts.NameMax) or '',
			hash = digest, owner = character.id
		}, os.time())
		if not id then
			return { ok = false, error = errorCode == 'address_taken' and errorCode or 'database_error' }
		end
		signIn(context, id)
		audit('mail_account_created', { character_id = character.id, target = address })
		return { ok = true, account = id }
	end)
end

function App.login(playerId, character, payload, context)
	local address = MailRules.Address(payload.address)
	if not address or type(payload.password) ~= 'string' or #payload.password > 64 then
		return { ok = false, error = 'wrong_credentials' }
	end
	return withLock('device:' .. context.key, function()
		local account = MailPersistence.AccountByAddress(address)
		if account == nil then
			return { ok = false, error = 'database_error' }
		end
		local now = os.time()
		local key = account and account.id or address
		if MailRules.Locked(logins[key], now) then
			return { ok = false, error = 'login_locked', seconds = logins[key].lockedUntil - now }
		end
		if not account or not verify(payload.password, account.hash) then
			logins[key] = MailRules.Fail(config, logins[key], now)
			if account and MailRules.Locked(logins[key], now) then
				log('warn', 'security', 'mail_login_locked', { character_id = character.id, target = address })
			end
			return { ok = false, error = 'wrong_credentials' }
		end
		logins[key] = nil
		local errorCode = signIn(context, account.id)
		if errorCode then
			return { ok = false, error = errorCode }
		end
		return { ok = true, account = account.id }
	end)
end

function App.logout(playerId, character, payload, context)
	local id = math.tointeger(tonumber(payload.account))
	if not id or not MailPersistence.RemoveSession(context.key, id) then
		return { ok = false, error = 'database_error' }
	end
	return { ok = true }
end

function App.profile(playerId, character, payload, context)
	local account, errorCode = sessionAccount(context, payload)
	if not account then
		return { ok = false, error = errorCode }
	end
	local name = MailRules.Text(payload.name, config.Accounts.NameMax) or ''
	local signature = MailRules.Text(payload.signature, config.Accounts.SignatureMax, true) or ''
	if not MailPersistence.UpdateProfile(account.id, name, signature) then
		return { ok = false, error = 'database_error' }
	end
	return { ok = true }
end

-- Troca a senha (exige a atual) e encerra a conta nos outros aparelhos.
function App.password(playerId, character, payload, context)
	local account, errorCode = sessionAccount(context, payload)
	if not account then
		return { ok = false, error = errorCode }
	end
	local password
	password, errorCode = MailRules.Password(config, payload.new)
	if not password then
		return { ok = false, error = errorCode }
	end
	return withLock('account:' .. account.id, function()
		local stored = MailPersistence.AccountById(account.id)
		if not stored then
			return { ok = false, error = 'database_error' }
		end
		if type(payload.current) ~= 'string' or not verify(payload.current, stored.hash) then
			return { ok = false, error = 'wrong_password' }
		end
		local digest = hash(password)
		if not digest or not MailPersistence.UpdatePassword(account.id, digest) then
			return { ok = false, error = 'database_error' }
		end
		MailPersistence.RemoveOtherSessions(account.id, context.key)
		audit('mail_password_changed', { character_id = character.id, target = account.address })
		return { ok = true }
	end)
end

local function ownedAccount(character, payload)
	local id = math.tointeger(tonumber(payload.account))
	local account = id and MailPersistence.AccountById(id)
	if account == nil then
		return nil, 'database_error'
	end
	if not account or account.owner ~= character.id then
		return nil, 'not_owner'
	end
	return account
end

-- Esqueci a senha: quem criou a conta define outra senha. Os outros aparelhos saem e este entra.
function App.reset(playerId, character, payload, context)
	local account, errorCode = ownedAccount(character, payload)
	if not account then
		return { ok = false, error = errorCode }
	end
	local password
	password, errorCode = MailRules.Password(config, payload.password)
	if not password then
		return { ok = false, error = errorCode }
	end
	return withLock('account:' .. account.id, function()
		local digest = hash(password)
		if not digest or not MailPersistence.UpdatePassword(account.id, digest) then
			return { ok = false, error = 'database_error' }
		end
		MailPersistence.RemoveOtherSessions(account.id, context.key)
		logins[account.id] = nil
		signIn(context, account.id)
		audit('mail_password_reset', { character_id = character.id, target = account.address })
		return { ok = true, account = account.id }
	end)
end

-- Exclui a conta (só quem criou, com a senha). Some com as mensagens dela; o endereço fica livre.
function App.remove(playerId, character, payload, context)
	local account, errorCode = ownedAccount(character, payload)
	if not account then
		return { ok = false, error = errorCode }
	end
	return withLock('account:' .. account.id, function()
		if type(payload.password) ~= 'string' or not verify(payload.password, account.hash) then
			return { ok = false, error = 'wrong_password' }
		end
		if not MailPersistence.DeleteAccount(account.id) then
			return { ok = false, error = 'database_error' }
		end
		audit('mail_account_deleted', { character_id = character.id, target = account.address })
		return { ok = true }
	end)
end

-- Caixas ----------------------------------------------------------------------------------------------

function App.folder(playerId, character, payload, context)
	local account, errorCode = sessionAccount(context, payload)
	if not account then
		return { ok = false, error = errorCode }
	end
	local folder = type(payload.folder) == 'string' and MailRules.Folders[payload.folder] and payload.folder or 'inbox'
	local search = MailRules.Text(payload.search, config.Messages.SearchMax)
	local before = math.tointeger(tonumber(payload.before))
	local list, more = MailPersistence.List(account.id, folder, search, before, config.Messages.PageSize)
	local counts = MailPersistence.Counts(account.id)
	if not list or not counts then
		return { ok = false, error = 'database_error' }
	end
	return { ok = true, folder = folder, messages = list, more = more == true, counts = counts }
end

function App.open(playerId, character, payload, context)
	local account, errorCode = sessionAccount(context, payload)
	if not account then
		return { ok = false, error = errorCode }
	end
	local id = math.tointeger(tonumber(payload.box))
	local message = id and MailPersistence.Box(account.id, id)
	if message == nil then
		return { ok = false, error = 'database_error' }
	end
	if not message then
		return { ok = false, error = 'message_not_found' }
	end
	if not message.read then
		MailPersistence.SetRead(account.id, { id }, true)
		message.read = true
	end
	return { ok = true, message = message }
end

local function boxIds(payload)
	return MailRules.Ids(payload.boxes, config.Messages.PageSize)
end

function App.mark(playerId, character, payload, context)
	local account, errorCode = sessionAccount(context, payload)
	if not account then
		return { ok = false, error = errorCode }
	end
	local ids = boxIds(payload)
	if not ids then
		return { ok = false, error = 'invalid_selection' }
	end
	local done = true
	if payload.read ~= nil then
		done = MailPersistence.SetRead(account.id, ids, payload.read == true) and done
	end
	if payload.starred ~= nil then
		done = MailPersistence.SetStarred(account.id, ids, payload.starred == true) and done
	end
	return done and { ok = true } or { ok = false, error = 'database_error' }
end

function App.move(playerId, character, payload, context)
	local account, errorCode = sessionAccount(context, payload)
	if not account then
		return { ok = false, error = errorCode }
	end
	local ids = boxIds(payload)
	local operation = payload.to
	if not ids or (operation ~= 'archive' and operation ~= 'trash' and operation ~= 'restore') then
		return { ok = false, error = 'invalid_selection' }
	end
	if not MailPersistence.Move(account.id, ids, operation, os.time()) then
		return { ok = false, error = 'database_error' }
	end
	return { ok = true }
end

function App.delete(playerId, character, payload, context)
	local account, errorCode = sessionAccount(context, payload)
	if not account then
		return { ok = false, error = errorCode }
	end
	local ids = boxIds(payload)
	if not ids then
		return { ok = false, error = 'invalid_selection' }
	end
	if not MailPersistence.Delete(account.id, ids) then
		return { ok = false, error = 'database_error' }
	end
	return { ok = true }
end

function App.emptyTrash(playerId, character, payload, context)
	local account, errorCode = sessionAccount(context, payload)
	if not account then
		return { ok = false, error = errorCode }
	end
	if not MailPersistence.EmptyTrash(account.id) then
		return { ok = false, error = 'database_error' }
	end
	return { ok = true }
end

-- Envio -----------------------------------------------------------------------------------------------

-- Entrega nas contas destino. Contas cheias não recebem (voltam em `bounced`).
-- Devolve o resultado do app; sender: { account (id ou nil), address, name }.
local function deliver(sender, recipients, message, draftId)
	local found = MailPersistence.AccountsByAddress(recipients.all)
	if not found then
		return { ok = false, error = 'database_error' }
	end
	for _, address in ipairs(recipients.all) do
		if not found[address] then
			return { ok = false, error = 'unknown_recipient', address = address }
		end
	end
	local ids, unique = {}, {}
	for _, address in ipairs(recipients.all) do
		local id = found[address].id
		if not unique[id] then
			unique[id] = true
			ids[#ids + 1] = id
		end
	end
	local totals = MailPersistence.Totals(ids)
	if not totals then
		return { ok = false, error = 'database_error' }
	end
	local boxes, bounced, delivered = {}, {}, {}
	if sender.account then
		boxes[#boxes + 1] = { account = sender.account, folder = 'sent', role = 'from', read = true }
	end
	for _, address in ipairs(recipients.all) do
		local id = found[address].id
		if unique[id] then
			unique[id] = nil
			if (totals[id] or 0) >= config.Messages.MaxPerAccount then
				bounced[#bounced + 1] = address
			else
				boxes[#boxes + 1] = { account = id, folder = 'inbox', role = 'to', read = false }
				delivered[#delivered + 1] = id
			end
		end
	end
	if #delivered == 0 then
		return { ok = false, error = 'mailbox_full', bounced = bounced }
	end
	local stored = MailPersistence.Deliver({
		from = sender.address, fromName = sender.name, subject = message.subject, body = message.body,
		to = joinList(recipients.to), cc = joinList(recipients.cc), bcc = joinList(recipients.bcc)
	}, boxes, os.time(), draftId, sender.account)
	if not stored then
		return { ok = false, error = 'database_error' }
	end
	announce(delivered, sender.name ~= '' and sender.name or sender.address, message.subject)
	return { ok = true, bounced = bounced }
end

function App.send(playerId, character, payload, context)
	local account, errorCode = sessionAccount(context, payload)
	if not account then
		return { ok = false, error = errorCode }
	end
	local recipients, badAddress
	recipients, errorCode, badAddress = MailRules.Recipients(config, payload.to, payload.cc, payload.bcc)
	if not recipients then
		return { ok = false, error = errorCode, address = badAddress }
	end
	local message
	message, errorCode = MailRules.Compose(config, payload)
	if not message then
		return { ok = false, error = errorCode }
	end
	return withLock('account:' .. account.id, function()
		local now = os.time()
		local nowMs = now * 1000
		if sendLimiter then
			local allowed, retryMs = sendLimiter:allow(account.id, nowMs)
			if not allowed then
				return { ok = false, error = 'send_cooldown', seconds = math.max(1, math.ceil((retryMs or 1000) / 1000)) }
			end
		elseif lastSend[account.id] and now - lastSend[account.id] < config.Messages.SendCooldownSeconds then
			return { ok = false, error = 'send_cooldown', seconds = config.Messages.SendCooldownSeconds - (now - lastSend[account.id]) }
		end
		local draftId = math.tointeger(tonumber(payload.draft))
		local result = deliver({ account = account.id, address = account.address, name = senderName(account, character) },
			recipients, message, draftId)
		if result.ok then
			lastSend[account.id] = now
			log('info', 'gameplay', 'mail_sent', { character_id = character.id, count = #recipients.all })
		elseif sendLimiter then
			sendLimiter:reset(account.id)
		end
		return result
	end)
end

function App.saveDraft(playerId, character, payload, context)
	local account, errorCode = sessionAccount(context, payload)
	if not account then
		return { ok = false, error = errorCode }
	end
	local draft = MailRules.Draft(config, payload)
	local boxId = math.tointeger(tonumber(payload.draft))
	return withLock('account:' .. account.id, function()
		local id = MailPersistence.SaveDraft(account.id, boxId, { address = account.address, name = senderName(account, character) },
			draft, os.time())
		if id == false then
			id = MailPersistence.SaveDraft(account.id, nil, { address = account.address, name = senderName(account, character) },
				draft, os.time())
		end
		if not id then
			return { ok = false, error = 'database_error' }
		end
		return { ok = true, draft = id }
	end)
end

-- Exports para o tablet e o smartphone ----------------------------------------------------------------

local function installed(playerId, device)
	if GetResourceState('coe_apps') ~= 'started' then
		return false
	end
	local ok, result = pcall(function()
		return exports.coe_apps:HasApp(playerId, 'mail', device)
	end)
	return ok and result == true
end

exports('TabletVisible', function(playerId, appId)
	local device = HOSTS[GetInvokingResource()]
	return device ~= nil and ready and appId == 'mail' and installed(playerId, device)
end)

exports('TabletCall', function(playerId, appId, action, payload)
	local device = HOSTS[GetInvokingResource()]
	if not device then
		return { ok = false, error = 'forbidden' }
	end
	if not ready then
		return { ok = false, error = 'not_ready' }
	end
	local character = characterOf(playerId)
	if not character then
		return { ok = false, error = 'no_character' }
	end
	local handler = appId == 'mail' and type(action) == 'string' and rawget(App, action)
	if type(handler) ~= 'function' then
		return { ok = false, error = 'unknown_action' }
	end
	if not installed(playerId, device) then
		return { ok = false, error = 'not_installed' }
	end
	local key = deviceKey(playerId, device, character)
	if not key then
		return { ok = false, error = 'no_device' }
	end
	remember(playerId, device, key)
	return handler(playerId, character, type(payload) == 'table' and payload or {}, { device = device, key = key })
end)

-- E-mail do sistema (ex.: avisos de outros resources). from: { address, name }; to: endereço ou lista.
-- Devolve { ok, bounced } ou { ok = false, error }.
exports('Send', function(from, to, subject, body)
	if not config.SystemCallers[GetInvokingResource() or ''] then
		return { ok = false, error = 'forbidden' }
	end
	if not ready then
		return { ok = false, error = 'not_ready' }
	end
	local address = type(from) == 'table' and MailRules.Address(from.address)
	if not address then
		return { ok = false, error = 'invalid_sender' }
	end
	local recipients, errorCode = MailRules.Recipients(config, to)
	if not recipients then
		return { ok = false, error = errorCode }
	end
	local message
	message, errorCode = MailRules.Compose(config, { subject = subject, body = body })
	if not message then
		return { ok = false, error = errorCode }
	end
	return deliver({ address = address, name = MailRules.Text(from.name, config.Accounts.NameMax) or '' }, recipients, message)
end)

AddEventHandler('playerDropped', function()
	seen[source] = nil
end)

CreateThread(function()
	local waitingLogged = false
	while true do
		local initialized, errorCode = MailPersistence.Initialize()
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
	ready = true
	log('info', 'system', 'mail_ready', {})
	while true do
		local trash, orphans = MailPersistence.Purge(os.time() - config.Messages.TrashDays * 86400)
		if trash > 0 or orphans > 0 then
			log('info', 'persistence', 'mail_purged', { count = trash + orphans })
		end
		Wait(config.PurgeMinutes * 60000)
	end
end)
