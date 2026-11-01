-- Servidor do Elos com natives e banco simulados: perfil, currículo, horas de ponto, busca, conexões e visibilidade.
local handlers, exported, notices = {}, {}, {}
local invoking = 'coe_phone'
local clock = 1792000000
local now = 1000
os.time = function() return clock end
source = nil

function GetGameTimer() now = now + 1000; return now end
function GetInvokingResource() return invoking end
function GetCurrentResourceName() return 'coe_elos' end
function GetResourceState() return 'started' end
function GetPlayers() return { '3' } end
function CreateThread(fn) fn() end
local waits = 0
function Wait() waits = waits + 1 end
function AddEventHandler(name, fn) handlers[name] = fn end

local characters = {
	[1] = { characterId = 11, stateId = 'AAAA2222', firstName = 'Ana', lastName = 'Lima' },
	[2] = { characterId = 22, stateId = 'BBBB3333', firstName = 'Bruno', lastName = 'Reis' },
	[3] = { characterId = 33, stateId = 'CCCC4444', firstName = 'Carla', lastName = 'Dias' }
}
Core = { Players = {
	GetActiveCharacter = function(id) return characters[id] end,
	GetPlayerByStateId = function(stateId)
		for id, c in pairs(characters) do if c.stateId == stateId then return { source = id } end end
	end
} }

local careers = {
	['11'] = { level = 2, maxLevel = 8, tier = 'Regular', completed = 3, skills = { { label = 'Força', level = 2, maxLevel = 5 }, { label = 'Campo', level = 1, maxLevel = 5 } },
		jobs = { { id = 'farmer', label = 'Fazendeiro', kindLabel = 'Coleta e venda', level = 1, maxLevel = 5, xp = 48, tasks = 16, earned = 320, workedSeconds = 1800, firstAt = 10, lastAt = 20 } } }
}
local businesses = {
	{ id = 'bennys', label = "Benny's", category = 'mechanic', enabled = true, owner = { characterId = '99' },
		staff = { { characterId = '22', grade = 'mec' } } },
	{ id = 'lojinha', label = 'Lojinha', category = 'shop', enabled = true, owner = { characterId = '11' }, staff = {} }
}
local currentDuty = { [3] = 'bennys' }

exports = setmetatable({}, {
	__call = function(_, name, fn) exported[name] = fn end,
	__index = function(_, resource)
		if resource == 'coe_jobs' then return { GetCareer = function(_, id) return careers[id] end } end
		if resource == 'coe_apps' then return { HasApp = function(_, _, app) return app == 'elos' end } end
		if resource == 'coe_notify' then return { Notify = function(_, id, kind, message) notices[#notices + 1] = { id = id, kind = kind, message = message } end } end
		if resource == 'coe_businesses' then
			return {
				List = function() return businesses end,
				Get = function(_, id) for _, b in ipairs(businesses) do if b.id == id then return b end end end,
				GradeOf = function(_, id, characterId)
					if id == 'bennys' and characterId == '22' then return { id = 'mec', label = 'Mecânico' } end
				end,
				CurrentDuty = function(_, playerId) return currentDuty[playerId] end
			}
		end
		return setmetatable({}, { __index = function() return function() return true end end })
	end
})

-- Banco em memória com o mesmo contrato do server/persistence.lua.
local profiles, items, works, links, shiftLog = {}, {}, {}, {}, {}
local function copy(t) local o = {} for k, v in pairs(t) do o[k] = v end return o end
ElosPersistence = {
	-- Primeira tentativa com o banco ainda conectando: o Elos espera e tenta de novo.
	Initialize = function()
		initAttempts = (initAttempts or 0) + 1
		if initAttempts == 1 then return nil, 'database_not_ready' end
		return true
	end,
	Profile = function(id) return profiles[id] and copy(profiles[id]) or false end,
	ProfileByState = function(stateId) for _, p in pairs(profiles) do if p.stateId == stateId then return copy(p) end end return false end,
	SaveProfile = function(p) profiles[p.characterId] = copy(p); return true end,
	Search = function(term, exclude) local out = {} for id, p in pairs(profiles) do if id ~= exclude and p.name:lower():find(term:lower(), 1, true) then out[#out + 1] = copy(p) end end return out end,
	Items = function(id) local out = {} for key, v in pairs(items[id] or {}) do out[key] = v end return out end,
	SaveItem = function(id, kind, ref, note) items[id] = items[id] or {}; items[id][kind .. ':' .. ref] = { note = note }; return true end,
	DeleteItem = function(id, kind, ref) if items[id] then items[id][kind .. ':' .. ref] = nil end return true end,
	Works = function(id) local out = {} for _, w in pairs(works[id] or {}) do out[#out + 1] = copy(w) end return out end,
	AddShift = function(id, shift)
		shiftLog[#shiftLog + 1] = { id = id, shift = shift }
		works[id] = works[id] or {}
		local w = works[id][shift.businessId] or { businessId = shift.businessId, seconds = 0, shifts = 0, firstAt = shift.startedAt }
		w.label, w.category, w.role = shift.label, shift.category, shift.role ~= '' and shift.role or w.role
		w.seconds, w.shifts, w.lastAt = w.seconds + shift.seconds, w.shifts + 1, shift.endedAt
		works[id][shift.businessId] = w
		return true
	end,
	Connections = function(id)
		local out = {}
		for _, l in ipairs(links) do
			if l.requester == id or l.target == id then
				local other = profiles[l.requester == id and l.target or l.requester]
				out[#out + 1] = { requester = l.requester, target = l.target, status = l.status, stateId = other.stateId, name = other.name, headline = other.headline }
			end
		end
		return out
	end,
	Connection = function(a, b)
		for _, l in ipairs(links) do
			if (l.requester == a and l.target == b) or (l.requester == b and l.target == a) then return copy(l) end
		end
		return false
	end,
	Count = function(id) local n = 0 for _, l in ipairs(links) do if l.status == 'accepted' and (l.requester == id or l.target == id) then n = n + 1 end end return n end,
	Request = function(a, b) links[#links + 1] = { requester = a, target = b, status = 'pending' }; return true end,
	Accept = function(a, b) for _, l in ipairs(links) do if l.requester == a and l.target == b and l.status == 'pending' then l.status = 'accepted'; return true end end return false end,
	Remove = function(a, b)
		for i = #links, 1, -1 do local l = links[i]; if (l.requester == a and l.target == b) or (l.requester == b and l.target == a) then table.remove(links, i); return true end end
		return false
	end
}

dofile('config.lua')
dofile('shared/rules.lua')
dofile('server/main.lua')

local function eq(a, b, m)
	if a ~= b then error(('%s: esperado %s, veio %s'):format(m, tostring(b), tostring(a)), 2) end
end
local function call(playerId, action, payload) return exported.TabletCall(playerId, 'elos', action, payload) end

eq(exported.IsReady(), true, 'pronto')
eq(initAttempts, 2, 'tenta de novo enquanto o banco conecta')
eq(waits, 1, 'espera entre as tentativas')

-- contrato do aparelho
invoking = 'outro'
eq(call(1, 'state').error, 'forbidden', 'so tablet e smartphone')
invoking = 'coe_phone'
eq(exported.TabletVisible(1, 'elos'), true, 'app visivel no smartphone')
eq(call(1, 'voar').error, 'unknown_action', 'acao desconhecida')

-- primeiro acesso cria o perfil com os padroes
local state = call(1, 'state')
eq(state.ok, true, 'estado')
eq(state.me.name, 'Ana Lima', 'nome do personagem')
eq(state.me.stateId, 'AAAA2222', 'stateId')
eq(state.me.visibility, 'open', 'aberto por padrao')
eq(state.me.showEarnings, false, 'ganhos escondidos por padrao')
eq(state.career.level, 2, 'carreira dos empregos livres')
eq(#state.career.skills, 1, 'so habilidades acima do nivel 1')
eq(#state.resume, 2, 'fazendeiro e a lojinha (dona)')
local keys = {}
for _, e in ipairs(state.resume) do keys[e.key] = e end
eq(keys['business:lojinha'].title, 'Dono', 'dona da lojinha')
eq(keys['job:farmer'].seconds, 1800, 'tempo no emprego livre')
eq(keys['job:farmer'].added, false, 'nada no curriculo ainda')

-- perfil
eq(call(1, 'saveProfile', { headline = 'Fazendeira e empresária', visibility = 'closed' }).ok, true, 'salva perfil')
eq(call(1, 'saveProfile', { visibility = 'x' }).error, 'invalid_visibility', 'valida perfil')
eq(profiles['11'].headline, 'Fazendeira e empresária', 'gravado')

-- curriculo: so experiencias reais
eq(call(1, 'setItem', { kind = 'job', ref = 'taxi' }).error, 'unknown_item', 'nao inventa experiencia')
eq(call(1, 'setItem', { kind = 'job', ref = 'farmer', note = 'Colheita recorde' }).ok, true, 'adiciona emprego livre')
eq(call(1, 'setItem', { kind = 'business', ref = 'lojinha' }).ok, true, 'adiciona negocio')
eq(call(1, 'setItem', { kind = 'job', ref = 'farmer', note = ('x'):rep(200) }).error, 'invalid_note', 'comentario longo')
state = call(1, 'state')
eq(state.summary.count, 2, 'duas no curriculo')
eq(call(1, 'setItem', { kind = 'business', ref = 'lojinha', added = false }).ok, true, 'tira do curriculo')
eq(call(1, 'state').summary.count, 1, 'uma no curriculo')

-- horas de ponto: quem ja estava de ponto ao iniciar (jogador 3) e turnos pelo evento
call(3, 'state')
clock = clock + 3600
handlers['coe_businesses:dutyChanged'](3, 'bennys', false, 'clock_out')
eq(shiftLog[1].id, '33', 'turno de quem ja estava de ponto')
eq(shiftLog[1].shift.seconds, 3600, 'uma hora')
handlers['coe_businesses:dutyChanged'](2, 'bennys', true, 'clock_in')
clock = clock + 30
handlers['coe_businesses:dutyChanged'](2, 'bennys', false, 'clock_out')
eq(#shiftLog, 1, 'turno curto nao conta')
handlers['coe_businesses:dutyChanged'](2, 'bennys', true, 'clock_in')
clock = clock + 7200
source = 2
handlers.playerDropped()
eq(shiftLog[2].shift.seconds, 7200, 'sair do jogo fecha o turno')
eq(shiftLog[2].shift.role, 'Mecânico', 'cargo no turno')
state = call(2, 'state')
local bennys
for _, e in ipairs(state.resume) do if e.key == 'business:bennys' then bennys = e end end
eq(bennys.current, true, 'equipe atual')
eq(bennys.title, 'Mecânico', 'cargo')
eq(bennys.seconds, 7200, 'horas trabalhadas')
eq(bennys.shifts, 1, 'turnos')
eq(state.career, nil, 'sem empregos livres')

-- busca e conexoes
eq(call(2, 'search', { query = 'an' }).error, 'search_short', 'busca curta')
local found = call(2, 'search', { query = 'ana' }).results
eq(#found, 1, 'acha pelo nome')
eq(found[1].relation, 'none', 'sem ligacao')
eq(call(2, 'search', { query = 'aaaa2222' }).results[1].name, 'Ana Lima', 'acha pelo ID')

-- perfil fechado: estranho ve so nome e apresentacao
local person = call(2, 'person', { stateId = 'AAAA2222' }).person
eq(person.full, false, 'fechado para estranhos')
eq(person.headline, 'Fazendeira e empresária', 'apresentacao visivel')
eq(person.resume, nil, 'curriculo escondido')

eq(call(2, 'request', { stateId = 'AAAA2222' }).relation, 'outgoing', 'pedido enviado')
eq(notices[#notices].id, 1, 'Ana avisada')
eq(call(2, 'request', { stateId = 'AAAA2222' }).error, 'already_requested', 'nao repete')
eq(call(1, 'state').network.incoming[1].name, 'Bruno Reis', 'pedido recebido')
eq(call(2, 'state').network.outgoing[1].name, 'Ana Lima', 'pedido enviado na lista')
eq(call(1, 'respond', { stateId = 'BBBB3333', accept = true }).relation, 'connected', 'aceito')
eq(notices[#notices].id, 2, 'Bruno avisado do aceite')
person = call(2, 'person', { stateId = 'AAAA2222' }).person
eq(person.full, true, 'conexao ve o perfil fechado')
eq(person.relation, 'connected', 'conectados')
eq(#person.resume, 1, 'so o que esta no curriculo')
eq(person.resume[1].earned, nil, 'ganhos escondidos')
eq(person.resume[1].note, 'Colheita recorde', 'comentario')
eq(person.career.level, 2, 'carreira visivel')
eq(person.connections, 1, 'uma conexao')

-- pedido cruzado vira aceite; remover desfaz
eq(call(3, 'request', { stateId = 'BBBB3333' }).relation, 'outgoing', 'Carla pede')
eq(call(2, 'request', { stateId = 'CCCC4444' }).relation, 'connected', 'pedido de volta aceita')
eq(call(2, 'remove', { stateId = 'CCCC4444' }).relation, 'none', 'desfaz')
eq(call(3, 'person', { stateId = 'BBBB3333' }).person.relation, 'none', 'sem ligacao depois')
eq(call(3, 'respond', { stateId = 'BBBB3333', accept = true }).error, 'no_request', 'sem pedido para responder')
eq(call(2, 'request', { stateId = 'BBBB3333' }).error, 'self', 'nao conecta consigo')
eq(call(2, 'person', { stateId = 'ZZZZ9999' }).error, 'unknown_person', 'pessoa desconhecida')

-- perfil para outros resources (candidaturas)
local public = exported.GetProfile(11)
eq(public.name, 'Ana Lima', 'perfil publico')
eq(#public.resume, 1, 'curriculo publico')

print('coe_elos server tests passed')
