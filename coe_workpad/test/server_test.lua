-- Servidor do tablet de trabalho com natives e exports simulados: item obrigatório, lista de apps, roteamento para
-- os resources dos apps (com instância), acesso revalidado a cada ação, limite de taxa e payload, apps Ponto e
-- Empregos livres, uso do item e o Yield de um pacote.
local handlers, netHandlers, exported, results, notices, clientEvents, coreEvents, routed = {}, {}, {}, {}, {}, {}, {}, {}
local now = 1000
source = nil
GlobalState = {}

function GetGameTimer() return now end
local states = { coe_jobs = 'started', coe_businesses = 'started', coe_inventory = 'started' }
function GetResourceState(name) return states[name] or 'started' end
function GetCurrentResourceName() return 'coe_workpad' end
function CreateThread(fn) fn() end
function Wait() end
function RegisterNetEvent(name, fn) netHandlers[name] = fn end
function AddEventHandler(name, fn) handlers[name] = fn end
function TriggerClientEvent(name, target, a, b)
	if name == 'coe_workpad:result' then
		results[#results + 1] = { target = target, id = a, result = b }
	else
		clientEvents[#clientEvents + 1] = { name = name, target = target, data = a }
	end
end
local invoking = nil
function GetInvokingResource() return invoking end
function IsPrincipalAceAllowed(principal, ace) return ace == 'coe.workpad.yield' and principal == 'resource.pack_tablet' end
json = { encode = function(t) return string.rep('x', t.size or 2) end }

local online = { [1] = { characterId = 11 }, [2] = { characterId = 22 } }
function GetPlayers() return { '1', '2' } end
local tablets = { inv1 = 1, inv2 = 0 }
Core = {
	Players = { GetActiveCharacter = function(id) return online[id] end },
	Events = { On = function(name, fn) coreEvents[name] = fn end }
}

-- Negócios: 'auto' (personagem 11 é dono) e 'burger' (11 é equipe); 'other' não é dele.
local businesses = {
	{ id = 'auto', label = 'Auto', category = 'mechanic', owner = '11', stations = { clocks = { { x = 1, y = 2 } } } },
	{ id = 'burger', label = 'Burger', category = 'restaurant', staff = '11', area = { kind = 'circle', x = 5, y = 6 } },
	{ id = 'other', label = 'Outro', category = 'shop' }
}
local onDuty = { [1] = 'burger' }
local clockOuts = {}
local session = nil

exports = setmetatable({}, {
	__call = function(_, name, fn) exported[name] = fn end,
	__index = function(_, resource)
		if resource == 'coe_inventory' then
			return {
				GetPlayerInventory = function(_, id) return 'inv' .. id end,
				GetItemCount = function(_, inv, item) return item == 'business_tablet' and (tablets[inv] or 0) or 0 end
			}
		end
		if resource == 'coe_businesses' then
			return {
				TabletInstances = function(_, playerId)
					local list = {}
					for _, b in ipairs(businesses) do
						if b.owner == tostring(online[playerId].characterId) or b.staff == tostring(online[playerId].characterId) then
							list[#list + 1] = { id = b.id, label = b.label, category = b.category }
						end
					end
					return list
				end,
				TabletCall = function(_, playerId, appId, action, payload, instance)
					routed[#routed + 1] = { resource = 'coe_businesses', playerId = playerId, appId = appId, action = action, instance = instance }
					return { ok = true, data = { instance = instance } }
				end,
				List = function() return businesses end,
				Access = function(_, id, characterId)
					for _, b in ipairs(businesses) do
						if b.id == id then return { owner = b.owner == characterId, staff = b.staff == characterId } end
					end
					return {}
				end,
				GradeOf = function(_, id) return id == 'burger' and { label = 'Chapeiro', salary = 300 } or nil end,
				CurrentDuty = function(_, playerId) return onDuty[playerId] end,
				ClockOut = function(_, playerId, reason)
					if not onDuty[playerId] then return { error = 'not_on_duty' } end
					clockOuts[#clockOuts + 1] = { playerId = playerId, reason = reason }
					onDuty[playerId] = nil
					return true
				end
			}
		end
		if resource == 'coe_jobs' then
			return {
				TabletCall = function(_, playerId, appId, action)
					routed[#routed + 1] = { resource = 'coe_jobs', playerId = playerId, appId = appId, action = action }
					return { ok = true, data = {} }
				end,
				ListJobs = function()
					return { { id = 'taxi', label = 'Taxista', route = { pay = 30 }, center = { 1, 2, 3 } }, { id = 'miner', label = 'Mineiro', gather = { unit = 'minério', sell = { price = 20 } } } }
				end,
				GetCareer = function() return { jobs = { { id = 'miner', allowed = false, lockedReason = 'Força nível 2' } } } end,
				GetSession = function() return session end
			}
		end
		if resource == 'coe_notify' then
			return { Notify = function(_, id, kind, message) notices[#notices + 1] = { id = id, kind = kind, message = message } end }
		end
		return setmetatable({}, { __index = function() return function() return true end end })
	end
})

dofile('../coe_core/lib/access.lua')
dofile('config.lua')
dofile('locales/pt-br.lua')
dofile('shared/rules.lua')
dofile('server/main.lua')

local function eq(a, b, m)
	if a ~= b then error(('%s: esperado %s, veio %s'):format(m, tostring(b), tostring(a)), 2) end
end
local function lastEvent(name)
	for index = #clientEvents, 1, -1 do
		if clientEvents[index].name == name then return clientEvents[index] end
	end
	return nil
end
local function open(playerId)
	source = playerId
	now = now + 2000
	clientEvents = {}
	netHandlers['coe_workpad:open']()
	local event = lastEvent('coe_workpad:opened')
	return event and event.data or nil
end
local requestId = 0
local function call(playerId, appId, action, payload)
	requestId = requestId + 1
	source = playerId
	now = now + 1000
	netHandlers['coe_workpad:call'](requestId, appId, action, payload)
	local result = results[#results]
	eq(result.id, requestId, 'resposta do pedido')
	eq(result.target, playerId, 'para quem pediu')
	return result.result
end

-- Abrir
local profile = open(1)
local ids = {}
for _, app in ipairs(profile.apps) do ids[#ids + 1] = app.id end
eq(table.concat(ids, ','), 'duty,freejobs,career,business:auto,business:burger', 'apps do jogador')
source = 1
now = now + 100
clientEvents = {}
netHandlers['coe_workpad:open']()
eq(lastEvent('coe_workpad:opened'), nil, 'abrir de novo logo em seguida e ignorado')
eq(open(2), nil, 'sem o item nao abre')
eq(notices[#notices].id, 2, 'aviso de falta do tablet')

-- Encaminhamento: app de negócio com instância e app do coe_jobs
local r = call(1, 'business:auto', 'overview', {})
eq(r.ok, true, 'negocio responde')
eq(routed[#routed].instance, 'auto', 'instancia vem do servidor')
eq(routed[#routed].appId, 'business', 'app base')
r = call(1, 'career', 'profile', {})
eq(routed[#routed].resource, 'coe_jobs', 'carreira no coe_jobs')
eq(call(1, 'business:other', 'overview', {}).error, 'forbidden', 'negocio de outro')
eq(call(1, 'hack', 'x', {}).error, 'forbidden', 'app inexistente')
eq(call(1, 'duty', 'x', 'texto').error, 'invalid_payload', 'payload invalido')
eq(call(1, 'duty', 'x', { size = 5000 }).error, 'invalid_payload', 'payload grande')
call(1, 'duty', 'overview', {})
source = 1
netHandlers['coe_workpad:call'](999, 'duty', 'overview', {})
eq(results[#results].result.error, 'rate_limited', 'limite de taxa')
netHandlers['coe_workpad:call']('x', 'duty', 'overview', {})
eq(results[#results].id, 999, 'requestId invalido ignorado')
eq(call(2, 'duty', 'overview', {}).error, 'no_tablet', 'sem o item nao chama')

-- Acesso revalidado: perdeu o negócio com o tablet aberto
businesses[2].staff = nil
eq(call(1, 'business:burger', 'overview', {}).error, 'forbidden', 'perdeu o negocio')
businesses[2].staff = '11'

-- Resource do app parado: o app some
states.coe_jobs = 'stopped'
eq(call(1, 'career', 'profile', {}).error, 'forbidden', 'carreira sem coe_jobs')
eq(call(1, 'freejobs', 'list', {}).error, 'forbidden', 'empregos livres sem coe_jobs')
states.coe_jobs = 'started'

-- Ponto
handlers['coe_businesses:dutyChanged'](1, 'burger', true)
eq(lastEvent('coe_workpad:duty').data, 'burger', 'tela sabe do ponto')
now = now + 1000
r = call(1, 'duty', 'overview', {})
eq(r.ok, true, 'ponto responde')
eq(r.data.duty.label, 'Burger', 'de ponto no Burger')
eq(r.data.duty.seconds ~= nil, true, 'tempo de ponto conhecido')
eq(#r.data.workplaces, 2, 'locais de trabalho')
eq(r.data.workplaces[1].id, 'burger', 'de ponto primeiro')
eq(r.data.workplaces[1].role, 'Chapeiro', 'cargo')
eq(r.data.workplaces[2].role, 'Dono', 'dono')
eq(call(1, 'duty', 'nope', {}).error, 'invalid_action', 'acao desconhecida')
r = call(1, 'duty', 'clockOut', {})
eq(r.ok, true, 'encerra o ponto')
eq(clockOuts[1].reason, 'clock_out', 'motivo do encerramento')
eq(r.data.duty, nil, 'sem ponto depois')
eq(call(1, 'duty', 'clockOut', {}).error, 'not_on_duty', 'sem ponto para encerrar')
handlers['coe_businesses:dutyChanged'](1, 'burger', false)
eq(lastEvent('coe_workpad:duty').data, nil, 'tela sabe que saiu')

-- Empregos livres
session = { jobId = 'taxi' }
r = call(1, 'freejobs', 'list', {})
eq(r.ok, true, 'empregos livres')
eq(r.data.jobs[1].id, 'taxi', 'atual primeiro')
eq(r.data.jobs[1].working, true, 'trabalhando')
eq(r.data.jobs[2].allowed, false, 'bloqueado pela carreira')
eq(r.data.jobs[1].pay[1], '$ 30 por parada', 'pagamento')

-- Uso do item
clientEvents = {}
coreEvents['inventory.itemUsed']('character:22', 1, { name = 'business_tablet' })
eq(lastEvent('coe_workpad:use').target, 2, 'item abre para o dono')
local count = #clientEvents
coreEvents['inventory.itemUsed']('character:11', 1, { name = 'phone' })
coreEvents['inventory.itemUsed']('character:99', 1, { name = 'business_tablet' })
eq(#clientEvents, count, 'outros itens e personagens ignorados')

-- Pacote assume o tablet
invoking = 'random_script'
eq(exported.Yield().error, 'forbidden', 'sem ACE nao assume')
invoking = 'pack_tablet'
eq(exported.Yield(), true, 'pacote assume')
eq(GlobalState.coeWorkpadYielded, 'pack_tablet', 'estado global')
eq(lastEvent('coe_workpad:close').target, -1, 'fecha as telas')
eq(exported.Status().active, false, 'inativo')
eq(open(1), nil, 'basico nao abre')
eq(call(1, 'duty', 'overview', {}).error, 'closed', 'basico nao responde')
count = #clientEvents
coreEvents['inventory.itemUsed']('character:11', 1, { name = 'business_tablet' })
eq(#clientEvents, count, 'item nao abre o basico')
handlers.onResourceStop('other')
eq(exported.Status().active, false, 'outro resource parando nao muda nada')
handlers.onResourceStop('pack_tablet')
eq(GlobalState.coeWorkpadYielded, false, 'volta')
eq(open(1) ~= nil, true, 'volta a abrir')

print('coe_workpad server: ok')
