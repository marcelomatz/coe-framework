-- Regras puras do coe_mail (sem natives), usadas pelo servidor e pelos testes.
MailRules = {}

MailRules.Folders = { inbox = true, sent = true, drafts = true, archive = true, trash = true, starred = true }

local function trim(value)
	return (tostring(value):gsub('^%s+', ''):gsub('%s+$', ''))
end

-- Texto livre: sem caracteres de controle, espaços repetidos reduzidos e limite em caracteres UTF-8.
-- Vazio devolve nil.
function MailRules.Text(value, max, multiline)
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
		text = text:sub(1, utf8.offset(text, max + 1) - 1)
	end
	return text
end

-- Nome antes do @ no domínio público: minúsculas, números e . _ - (sem começar/terminar com símbolo nem repetir).
function MailRules.LocalPart(config, value)
	if type(value) ~= 'string' then
		return nil, 'invalid_address'
	end
	local name = trim(value):lower()
	local limits = config.Accounts
	if #name < limits.LocalMin or #name > limits.LocalMax then
		return nil, 'invalid_address'
	end
	if not name:match('^[a-z0-9][a-z0-9._%-]*[a-z0-9]$') or name:find('[._%-][._%-]') then
		return nil, 'invalid_address'
	end
	if config.Reserved[name] then
		return nil, 'address_reserved'
	end
	return name
end

-- Endereço completo normalizado (minúsculas): devolve endereço, nome e domínio, ou nil.
function MailRules.Address(value)
	if type(value) ~= 'string' then
		return nil
	end
	local address = trim(value):lower()
	if #address > 80 then
		return nil
	end
	local name, domain = address:match('^([a-z0-9._%-]+)@([a-z0-9%-]+%.[a-z0-9.%-]+)$')
	if not name or name:find('^[._%-]') or name:find('[._%-]$') or domain:find('%.%.') or domain:find('[.%-]$') then
		return nil
	end
	return address, name, domain
end

-- Senha: 6 a 32 caracteres, sem espaços nas pontas.
function MailRules.Password(config, value)
	if type(value) ~= 'string' then
		return nil, 'invalid_password'
	end
	local length = utf8.len(value)
	if not length or length < config.Accounts.PasswordMin or length > config.Accounts.PasswordMax or value ~= trim(value) then
		return nil, 'invalid_password'
	end
	return value
end

local function splitList(value)
	local list = {}
	if type(value) == 'table' then
		for _, entry in ipairs(value) do
			if type(entry) == 'string' then
				list[#list + 1] = entry
			end
		end
	elseif type(value) == 'string' then
		for entry in value:gmatch('[^,;%s]+') do
			list[#list + 1] = entry
		end
	end
	return list
end

-- Para, Cc e Cco: endereços válidos, sem repetir entre as listas, no máximo `MaxRecipients` no total.
-- Devolve { to, cc, bcc, all } ou nil + código (+ endereço com problema).
function MailRules.Recipients(config, to, cc, bcc)
	local seen = {}
	local result = { to = {}, cc = {}, bcc = {}, all = {} }
	for _, key in ipairs({ 'to', 'cc', 'bcc' }) do
		local source = key == 'to' and to or key == 'cc' and cc or bcc
		for _, raw in ipairs(splitList(source)) do
			local address = MailRules.Address(raw)
			if not address then
				return nil, 'invalid_recipient', raw
			end
			if not seen[address] then
				seen[address] = true
				result[key][#result[key] + 1] = address
				result.all[#result.all + 1] = address
				if #result.all > config.Messages.MaxRecipients then
					return nil, 'too_many_recipients'
				end
			end
		end
	end
	if #result.to == 0 then
		return nil, 'no_recipients'
	end
	return result
end

-- Assunto e texto de uma mensagem a enviar. Precisa de pelo menos um dos dois.
function MailRules.Compose(config, payload)
	local subject = MailRules.Text(payload.subject, config.Messages.SubjectMax) or ''
	local body = MailRules.Text(payload.body, config.Messages.BodyMax, true) or ''
	if subject == '' and body == '' then
		return nil, 'empty_message'
	end
	return { subject = subject, body = body }
end

-- Rascunho: guarda o que foi digitado, sem validar os endereços (só o tamanho).
function MailRules.Draft(config, payload)
	local limit = config.Messages.DraftListMax
	return {
		to = MailRules.Text(payload.to, limit) or '',
		cc = MailRules.Text(payload.cc, limit) or '',
		bcc = MailRules.Text(payload.bcc, limit) or '',
		subject = MailRules.Text(payload.subject, config.Messages.SubjectMax) or '',
		body = MailRules.Text(payload.body, config.Messages.BodyMax, true) or ''
	}
end

-- Lista de ids (caixas) vinda do app: inteiros positivos, sem repetir, no máximo `max`.
function MailRules.Ids(value, max)
	local list, seen = {}, {}
	local source = type(value) == 'table' and value or { value }
	for _, entry in ipairs(source) do
		local id = math.tointeger(tonumber(entry))
		if not id or id <= 0 then
			return nil
		end
		if not seen[id] then
			seen[id] = true
			list[#list + 1] = id
			if #list > max then
				return nil
			end
		end
	end
	if #list == 0 then
		return nil
	end
	return list
end

-- Bloqueio por senha errada. state: { failures, lockedUntil }. Devolve o novo estado.
function MailRules.Fail(config, state, now)
	state = state or { failures = 0, lockedUntil = 0 }
	state.failures = state.failures + 1
	if state.failures >= config.Login.MaxFailures then
		state.failures = 0
		state.lockedUntil = now + config.Login.LockSeconds
	end
	return state
end

function MailRules.Locked(state, now)
	return state ~= nil and (state.lockedUntil or 0) > now
end

local function getAlgorithms()
	return (type(Core) == 'table' and Core.Algorithms) or CoeAlgorithms
end

-- Cria rate limiter GCRA O(1) para controle de cadência de envio de e-mails.
function MailRules.NewSendLimiter(cooldownSeconds)
	local alg = getAlgorithms()
	if alg and alg.RateLimit and alg.RateLimit.newGCRA then
		return alg.RateLimit.newGCRA((cooldownSeconds or 3) * 1000, 0)
	end
	return nil
end

-- Cria cache LRU Intrusivo Zero-GC para sessões e contas consultadas com frequência.
function MailRules.NewSessionCache(capacity)
	local alg = getAlgorithms()
	if alg and alg.Containers and alg.Containers.newLRUCache then
		return alg.Containers.newLRUCache(capacity or 128)
	end
	return nil
end

-- Cria gerenciador de locks assíncronos por chave.
function MailRules.NewLockManager()
	local alg = getAlgorithms()
	if alg and alg.Concurrency and alg.Concurrency.newLockManager then
		return alg.Concurrency.newLockManager()
	end
	return nil
end

