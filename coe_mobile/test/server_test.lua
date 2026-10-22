-- Servidor do telefone básico com natives, exports e persistência simulados: número gerado no primeiro uso, item
-- obrigatório, contatos, mensagens (online e offline), ligações (atender, recusar, perder, ocupado, fora de área),
-- ajustes, uso do item, troca de personagem e o Yield de um pacote.
local handlers, netHandlers, exported, responses, notices, clientEvents, voice, timers, coreEvents = {}, {}, {}, {}, {}, {}, {}, {}, {}
local now = 1000
source = nil
GlobalState = {}

function GetGameTimer() return now end
function GetResourceState() return 'started' end
function GetCurrentResourceName() return 'coe_mobile' end
function CreateThread(fn) fn() end
function Wait() end
function SetTimeout(ms, fn) timers[#timers + 1] = { ms = ms, fn = fn } end
function RegisterNetEvent(name, fn) netHandlers[name] = fn end
function AddEventHandler(name, fn) handlers[name] = fn end
function TriggerClientEvent(name, target, a, b)
	if name == 'coe_mobile:response' then
		responses[#responses + 1] = { target = target, id = a, result = b }
	else
		clientEvents[#clientEvents + 1] = { name = name, target = target, data = a }
	end
end
local invoking = nil
function GetInvokingResource() return invoking end
function IsPrincipalAceAllowed(principal, ace) return ace == 'coe.mobile.yield' and principal == 'resource.pack_phone' end

promise = { new = function() local p = {}; function p:resolve(v) self.value = v end; return p end }
Citizen = { Await = function(p) return p.value end }
json = { encode = function() return '{}' end, decode = function() return {} end }

-- Jogadores 1, 2 e 3 online (3 sem telefone); personagem 44 existe mas está offline.
local online = {
	[1] = { characterId = 11, stateId = 'AAAA2222', firstName = 'Ana', lastName = 'Souza' },
	[2] = { characterId = 22, stateId = 'BBBB3333', firstName = 'Bruno', lastName = 'Lima' },
	[3] = { characterId = 33, stateId = 'CCCC4444', firstName = 'Caio', lastName = 'Melo' }
}
local phones = { inv1 = 1, inv2 = 1, inv3 = 0 }
function GetPlayers() local list = {}; for id in pairs(online) do list[#list + 1] = tostring(id) end; return list end
Core = {
	Players = { GetActiveCharacter = function(id) return online[id] end },
	Events = { On = function(name, fn) coreEvents[name] = fn end }
}

exports = setmetatable({}, {
	__call = function(_, name, fn) exported[name] = fn end,
	__index = function(_, resource)
		if resource == 'coe_inventory' then
			return {
				GetPlayerInventory = function(_, id) return 'inv' .. id end,
				GetItemCount = function(_, inv, item) return item == 'phone' and (phones[inv] or 0) or 0 end
			}
		end
		if resource == 'coe_talk' then
			return { SetPlayerCall = function(_, id, callId) voice[id] = callId; return true end }
		end
		if resource == 'coe_notify' then
			return { Notify = function(_, id, kind, message) notices[#notices + 1] = { id = id, kind = kind, message = message } end }
		end
		return setmetatable({}, { __index = function() return function() return true end end })
	end
})

-- Persistência em memória com a mesma interface de server/persistence.lua.
local db = { numbers = { ['44'] = '555-4444' }, contacts = {}, messages = {}, calls = {}, settings = {}, nextId = 0 }
local generated = { '555-4444', '555-1111', '555-2222', '555-3333', '555-5555' }
local function id() db.nextId = db.nextId + 1; return db.nextId end
MobilePersistence = {
	Initialize = function() return true end,
	NumberOf = function(c) return db.numbers[c] or false end,
	CharacterOf = function(n) for c, number in pairs(db.numbers) do if number == n then return c end end; return false end,
	EnsureNumber = function(c, generate)
		if db.numbers[c] then return db.numbers[c] end
		for _ = 1, 5 do
			local candidate = generate()
			if not MobilePersistence.CharacterOf(candidate) then db.numbers[c] = candidate; return candidate end
		end
		return nil, 'number_exhausted'
	end,
	Contacts = function(c)
		local list = {}
		for _, contact in ipairs(db.contacts) do if contact.owner == c then list[#list + 1] = { id = contact.id, number = contact.number, name = contact.name } end end
		return list
	end,
	ContactCount = function(c) return #MobilePersistence.Contacts(c) end,
	SaveContact = function(c, cid, number, name)
		for _, contact in ipairs(db.contacts) do
			if contact.owner == c and contact.number == number and contact.id ~= cid then return nil, 'duplicate_contact' end
		end
		if cid then
			for _, contact in ipairs(db.contacts) do
				if contact.owner == c and contact.id == cid then contact.number, contact.name = number, name; return true end
			end
			return nil, 'contact_not_found'
		end
		db.contacts[#db.contacts + 1] = { id = id(), owner = c, number = number, name = name }
		return true
	end,
	DeleteContact = function(c, cid)
		for index, contact in ipairs(db.contacts) do
			if contact.owner == c and contact.id == cid then table.remove(db.contacts, index); break end
		end
		return true
	end,
	ContactName = function(c, number)
		for _, contact in ipairs(db.contacts) do if contact.owner == c and contact.number == number then return contact.name end end
		return false
	end,
	SendMessage = function(from, to, body)
		local mid = id()
		db.messages[#db.messages + 1] = { id = mid, from = from, to = to, body = body, read = false }
		return mid
	end,
	Threads = function(n)
		local latest, unread = {}, {}
		for _, m in ipairs(db.messages) do
			local other = m.from == n and m.to or (m.to == n and m.from) or nil
			if other then
				latest[other] = m
				if m.to == n and not m.read then unread[other] = (unread[other] or 0) + 1 end
			end
		end
		local list = {}
		for other, m in pairs(latest) do list[#list + 1] = { number = other, body = m.body, mine = m.from == n, unread = unread[other] or 0 } end
		return list
	end,
	Thread = function(n, other)
		local list = {}
		for _, m in ipairs(db.messages) do
			if (m.from == n and m.to == other) or (m.from == other and m.to == n) then
				if m.to == n then m.read = true end
				list[#list + 1] = { id = m.id, body = m.body, mine = m.from == n }
			end
		end
		return list
	end,
	DeleteThread = function() return true end,
	UnreadCount = function(n)
		local total = 0
		for _, m in ipairs(db.messages) do if m.to == n and not m.read then total = total + 1 end end
		return total
	end,
	LogCall = function(caller, callee, status, duration)
		db.calls[#db.calls + 1] = { caller = caller, callee = callee, status = status, duration = duration }
		return true
	end,
	Recents = function(n)
		local list = {}
		for index = #db.calls, 1, -1 do
			local c = db.calls[index]
			if c.caller == n or c.callee == n then
				list[#list + 1] = { number = c.caller == n and c.callee or c.caller, outgoing = c.caller == n, status = c.status }
			end
		end
		return list
	end,
	Settings = function(c) return db.settings[c] or {} end,
	SaveSettings = function(c, s) db.settings[c] = s; return true end
}

local nextGenerated = 0
math.random = function()
	return 0
end

dofile('../coe_core/lib/access.lua')
dofile('config.lua')
dofile('locales/pt-br.lua')
dofile('shared/rules.lua')
-- Números gerados em sequência (o primeiro colide com o personagem offline).
MobileRules.Generate = function()
	nextGenerated = nextGenerated + 1
	return generated[nextGenerated]
end
dofile('server/main.lua')

local function eq(a, b, m)
	if a ~= b then error(('%s: esperado %s, veio %s'):format(m, tostring(b), tostring(a)), 2) end
end
local requestId = 0
local function request(playerId, kind, payload)
	requestId = requestId + 1
	source = playerId
	now = now + 1
	netHandlers['coe_mobile:request'](requestId, kind, payload)
	local response = responses[#responses]
	eq(response.id, requestId, 'resposta do pedido')
	eq(response.target, playerId, 'resposta para quem pediu')
	return response.result
end
-- Cada pedido chega depois do intervalo mínimo; actNow chega logo em seguida ao anterior.
local function actNow(playerId, action, data)
	return request(playerId, 'action', { action = action, data = data or {} })
end
local function act(playerId, action, data)
	now = now + 1000
	return actNow(playerId, action, data)
end
local function lastEvent(name, target)
	for index = #clientEvents, 1, -1 do
		local event = clientEvents[index]
		if event.name == name and (target == nil or event.target == target) then return event.data end
	end
	return nil
end

-- Abertura: gera o número no primeiro uso (pulando o que já existe)
local r = request(1, 'open', {})
eq(r.ok, true, 'abre')
eq(r.data.number, '555-1111', 'numero gerado sem colidir')
eq(r.data.name, 'Ana Souza', 'nome do dono')
eq(r.data.settings.volume, 5, 'ajustes padrao')
eq(r.data.unread, 0, 'sem mensagens')
eq(request(1, 'open', {}).data.number, '555-1111', 'numero fixo')
eq(request(2, 'open', {}).data.number, '555-2222', 'outro personagem, outro numero')
eq(request(3, 'open', {}).error, 'no_phone', 'sem o item nao abre')
eq(request(9, 'open', {}).error, 'no_phone', 'sem inventario')
phones.inv9 = 1
eq(request(9, 'open', {}).error, 'no_character', 'sem personagem')
eq(act(1, 'hack').error, 'unavailable', 'acao desconhecida')

-- Contatos
r = act(1, 'contact_save', { name = ' Bruno ', number = '5552222' })
eq(r.ok, true, 'contato salvo')
eq(r.data.contacts[1].name, 'Bruno', 'nome aparado')
eq(r.data.contacts[1].number, '555-2222', 'numero normalizado')
eq(actNow(1, 'contact_save', { name = 'B2', number = '555-2222' }).error, 'busy', 'intervalo entre gravacoes')
now = now + 1000
eq(act(1, 'contact_save', { name = 'B2', number = '555-2222' }).error, 'duplicate_contact', 'numero repetido')
eq(act(1, 'contact_save', { name = '', number = '555-2222' }).error, 'invalid_name', 'nome vazio')
eq(act(1, 'contact_save', { name = 'X', number = '12' }).error, 'invalid_number', 'numero invalido')
eq(act(1, 'contact_save', { id = 'abc', name = 'X', number = '555-9999' }).error, 'contact_not_found', 'id invalido')
local bruno = act(1, 'contacts').data.contacts[1]
eq(act(1, 'contact_save', { id = bruno.id, name = 'Bruno Lima', number = '555-2222' }).data.contacts[1].name, 'Bruno Lima', 'edita')
act(2, 'contact_save', { name = 'Ana', number = '555-1111' })
MobileConfig.Contacts.Max = 1
eq(act(1, 'contact_save', { name = 'Caio', number = '555-3333' }).error, 'contacts_full', 'agenda cheia')
MobileConfig.Contacts.Max = 100
eq(#act(1, 'contact_delete', { id = bruno.id }).data.contacts, 0, 'apaga')
act(1, 'contact_save', { name = 'Bruno', number = '555-2222' })

-- Mensagens
clientEvents = {}
r = act(1, 'message_send', { number = '555-2222', body = '  oi Bruno  ' })
eq(r.ok, true, 'mensagem enviada')
eq(r.data.message.body, 'oi Bruno', 'corpo aparado')
eq(r.data.message.mine, true, 'minha')
local pushed = lastEvent('coe_mobile:message', 2)
eq(pushed.number, '555-1111', 'destinatario online recebe')
eq(pushed.name, 'Ana', 'com o nome da agenda dele')
eq(actNow(1, 'message_send', { number = '555-2222', body = 'de novo' }).error, 'busy', 'intervalo entre mensagens')
now = now + 2000
eq(act(1, 'message_send', { number = '555-1111', body = 'eu' }).error, 'invalid_number', 'para si mesmo')
eq(act(1, 'message_send', { number = '555-9999', body = 'oi' }).error, 'number_not_found', 'numero inexistente')
eq(act(1, 'message_send', { number = '555-2222', body = string.rep('x', 301) }).error, 'invalid_message', 'longa demais')
now = now + 2000
eq(act(1, 'message_send', { number = '555-4444', body = 'offline' }).ok, true, 'destinatario offline guarda')
eq(request(2, 'open', {}).data.unread, 1, 'nao lida aparece ao abrir')
local threads = act(2, 'threads').data.threads
eq(threads[1].name, 'Ana', 'conversa com nome da agenda')
eq(threads[1].unread, 1, 'nao lida na conversa')
local thread = act(2, 'thread', { number = '555-1111' }).data
eq(thread.name, 'Ana', 'nome na conversa')
eq(thread.messages[1].body, 'oi Bruno', 'historico')
eq(request(2, 'open', {}).data.unread, 0, 'lida ao abrir a conversa')
-- Destinatário sem o aparelho não recebe aviso (vê ao pegar o telefone).
clientEvents = {}
phones.inv2 = 0
now = now + 2000
act(1, 'message_send', { number = '555-2222', body = 'sem aparelho' })
eq(lastEvent('coe_mobile:message', 2), nil, 'sem aparelho, sem aviso')
phones.inv2 = 1

-- Ligações: atender e encerrar
clientEvents = {}
r = act(1, 'call_start', { number = '555-2222' })
eq(r.ok, true, 'liga')
eq(r.data.call.state, 'ringing', 'chamando')
eq(r.data.call.direction, 'outgoing', 'quem liga')
eq(r.data.call.name, 'Bruno', 'nome para quem liga')
local incoming = lastEvent('coe_mobile:call', 2)
eq(incoming.direction, 'incoming', 'chegou para o outro')
eq(incoming.number, '555-1111', 'numero de quem liga')
eq(incoming.name, 'Ana', 'nome na agenda de quem recebe')
eq(notices[#notices].id, 2, 'aviso de ligacao')
now = now + 1000
eq(act(1, 'call_start', { number = '555-2222' }).error, 'already_in_call', 'ja em ligacao')
eq(act(1, 'call_answer').error, 'not_in_call', 'quem liga nao atende')
r = act(2, 'call_answer')
eq(r.data.call.state, 'active', 'atendida')
eq(voice[1], voice[2], 'mesmo canal de voz')
eq(voice[1]:match('^coe_mobile:%x+$') ~= nil, true, 'canal imprevisivel')
eq(lastEvent('coe_mobile:call', 1).state, 'active', 'quem ligou ve ativa')
eq(timers[#timers].ms, MobileConfig.Calls.RingSeconds * 1000, 'tempo de toque')
timers[#timers].fn()
eq(lastEvent('coe_mobile:call', 1).state, 'active', 'toque expirado nao derruba ligacao atendida')
eq(act(1, 'call_end').ok, true, 'encerra')
eq(voice[1], nil, 'saiu do canal')
eq(voice[2], nil, 'outro saiu do canal')
eq(lastEvent('coe_mobile:call', 2).reason, 'ended', 'motivo para o outro')
eq(db.calls[#db.calls].status, 'answered', 'historico atendida')
eq(act(2, 'call_end').error, 'not_in_call', 'ja encerrada')

-- Recusar
now = now + 1000
act(1, 'call_start', { number = '555-2222' })
eq(act(2, 'call_decline').ok, true, 'recusa')
eq(lastEvent('coe_mobile:call', 1).reason, 'declined', 'quem ligou ve recusa')
eq(db.calls[#db.calls].status, 'declined', 'historico recusada')

-- Não atendida: chamada perdida e aviso
now = now + 1000
act(1, 'call_start', { number = '555-2222' })
local ring = timers[#timers]
ring.fn()
eq(lastEvent('coe_mobile:call', 2).reason, 'missed', 'perdida')
eq(db.calls[#db.calls].status, 'missed', 'historico perdida')
eq(notices[#notices].id, 2, 'aviso de chamada perdida para quem recebia')
eq(notices[#notices].message:find('Chamada perdida', 1, true) ~= nil, true, 'texto do aviso')

-- Quem liga desiste antes de atender
now = now + 1000
act(1, 'call_start', { number = '555-2222' })
act(1, 'call_end')
eq(lastEvent('coe_mobile:call', 2).reason, 'cancelled', 'cancelada')

-- Ocupado, fora de área e inexistente
now = now + 1000
act(1, 'call_start', { number = '555-2222' })
act(2, 'call_answer')
online[4] = { characterId = 55, firstName = 'Dani' }
phones.inv4 = 1
request(4, 'open', {})
eq(act(4, 'call_start', { number = '555-2222' }).error, 'line_busy', 'linha ocupada')
eq(db.calls[#db.calls].status, 'busy', 'historico ocupado')
now = now + 1000
eq(act(4, 'call_start', { number = '555-4444' }).error, 'unreachable', 'offline: fora de area')
now = now + 1000
db.numbers['33'] = '555-6666'
eq(act(4, 'call_start', { number = '555-6666' }).error, 'unreachable', 'sem aparelho: fora de area')
now = now + 1000
eq(act(4, 'call_start', { number = '555-0000' }).error, 'number_not_found', 'inexistente')
eq(act(4, 'call_start', { number = request(4, 'open', {}).data.number }).error, 'invalid_number', 'para si mesmo')

-- Reabrir durante a ligação mostra a ligação
eq(request(2, 'open', {}).data.call.state, 'active', 'reabre na ligacao')
eq(#act(1, 'recents').data.recents > 0, true, 'recentes')
eq(act(1, 'recents').data.recents[1].name, 'Bruno', 'recentes com nome')

-- Quem sai do jogo derruba a ligação
source = 2
handlers.playerDropped()
eq(lastEvent('coe_mobile:call', 1).state, 'ended', 'ligacao cai com a saida')
eq(voice[1], nil, 'canal liberado')

-- Encerrar sem o aparelho funciona
now = now + 1000
act(1, 'call_start', { number = request(4, 'open', {}).data.number })
phones.inv1 = 0
eq(act(1, 'call_end').ok, true, 'encerra sem o aparelho')
eq(act(1, 'contacts').error, 'no_phone', 'resto exige o aparelho')
phones.inv1 = 1

-- Ajustes
r = act(1, 'settings_save', { silent = true, volume = 8, wallpaper = 'oceano', ringtone = 'nope' })
eq(r.data.settings.silent, true, 'silencioso')
eq(r.data.settings.volume, 8, 'volume')
eq(r.data.settings.wallpaper, 'oceano', 'papel de parede')
eq(r.data.settings.ringtone, 'classico', 'toque invalido ignorado')
eq(request(1, 'open', {}).data.settings.silent, true, 'ajustes persistem')
-- Silencioso: ligação chega sem aviso sonoro do servidor
local noticeCount = #notices
now = now + 1000
act(4, 'call_start', { number = '555-1111' })
eq(lastEvent('coe_mobile:call', 1).silent, true, 'tela sabe que e silencioso')
eq(#notices, noticeCount, 'sem aviso no silencioso')
act(4, 'call_end')

-- Uso do item abre o telefone; outro item não
clientEvents = {}
coreEvents['inventory.itemUsed']('character:11', 1, { name = 'phone' })
eq(clientEvents[#clientEvents].name, 'coe_mobile:use', 'item abre')
eq(clientEvents[#clientEvents].target, 1, 'para o dono do item')
local count = #clientEvents
coreEvents['inventory.itemUsed']('character:11', 1, { name = 'burger' })
coreEvents['inventory.itemUsed']('character:999', 1, { name = 'phone' })
eq(#clientEvents, count, 'outros itens e personagens ignorados')

-- Troca de personagem: limpa o cache do número
online[1] = { characterId = 66, firstName = 'Eva' }
coreEvents['player.characterUnloaded']({ source = 1 })
eq(clientEvents[#clientEvents].name, 'coe_mobile:close', 'fecha a tela')
eq(request(1, 'open', {}).data.number, '555-5555', 'numero do novo personagem')

-- Pedido malformado é ignorado
count = #responses
netHandlers['coe_mobile:request']('x', 'open', {})
netHandlers['coe_mobile:request'](1, 'hack', {})
eq(#responses, count, 'pedidos invalidos ignorados')

-- Export NumberOf
eq(exported.NumberOf(22), '555-2222', 'numero pelo personagem')
eq(exported.NumberOf(777), nil, 'sem numero')

-- Pacote assume o telefone
now = now + 1000
online[2] = { characterId = 22, firstName = 'Bruno' }
act(4, 'call_start', { number = '555-2222' })
act(2, 'call_answer')
invoking = 'random_script'
eq(exported.Yield().error, 'forbidden', 'sem ACE nao assume')
invoking = 'pack_phone'
eq(exported.Yield(), true, 'pacote assume')
eq(GlobalState.coeMobileYielded, 'pack_phone', 'estado global')
eq(voice[2], nil, 'ligacoes encerradas')
eq(clientEvents[#clientEvents].name, 'coe_mobile:close', 'fecha telas abertas')
eq(exported.Status().active, false, 'status inativo')
eq(request(1, 'open', {}).error, 'unavailable', 'basico nao abre')
count = #clientEvents
coreEvents['inventory.itemUsed']('character:22', 1, { name = 'phone' })
eq(#clientEvents, count, 'item nao abre o basico')
handlers.onResourceStop('other_resource')
eq(exported.Status().active, false, 'outro resource parando nao muda nada')
handlers.onResourceStop('pack_phone')
eq(GlobalState.coeMobileYielded, false, 'pacote parou: telefone volta')
eq(request(1, 'open', {}).ok, true, 'volta a abrir')

print('coe_mobile server: ok')
