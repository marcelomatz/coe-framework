-- Servidor do coe_jobs com natives simulados: registro dos pacotes, sessões, pagamento e checagens anti-trapaça.
local handlers, netHandlers, clientEvents, notices, credits, debits = {}, {}, {}, {}, {}, {}
local exported = {}
local now = 1000
local positions = { [1] = { x = 0, y = 0, z = 0 }, [2] = { x = 0, y = 0, z = 0 }, [3] = { x = 0, y = 0, z = 0 } }
local characters = { [1] = 11, [2] = 22, [3] = 55 }
local balances = { ['11'] = 1000, ['22'] = 0, ['55'] = 1000 }
local entities, nextEntity = {}, 500
local invoking = 'coe_extra_jobs'
source = nil

function GetGameTimer() return now end
function GetCurrentResourceName() return 'coe_jobs' end
function GetInvokingResource() return invoking end
function GetPlayerPed(id) return positions[id] and id or 0 end
function GetEntityCoords(e)
	if entities[e] then return entities[e] end
	local p = positions[e]
	return p and { x = p.x, y = p.y, z = p.z } or { x = 0, y = 0, z = 0 }
end
function joaat(s) return #s end
function CreateVehicleServerSetter(_, _, x, y, z)
	nextEntity = nextEntity + 1
	entities[nextEntity] = { x = x, y = y, z = z }
	return nextEntity
end
function DoesEntityExist(e) return entities[e] ~= nil end
function DeleteEntity(e) entities[e] = nil end
function NetworkGetNetworkIdFromEntity(e) return e + 10000 end
function NetworkGetEntityFromNetworkId(n) return n - 10000 end
function SetVehicleNumberPlateText() end
function Entity() return { state = { set = function() end } } end
function Wait() if coroutine.isyieldable() then coroutine.yield() end end
local threads = {}
function CreateThread(fn) local co = coroutine.create(fn); threads[#threads + 1] = co; assert(coroutine.resume(co)) end
function RegisterNetEvent(name, fn) if fn then netHandlers[name] = fn end end
function AddEventHandler(name, fn) handlers[name] = fn end
function TriggerEvent(name, ...) if handlers[name] then handlers[name](...) end end
function TriggerClientEvent(name, target, payload) clientEvents[#clientEvents + 1] = { name = name, target = target, payload = payload } end
math.randomseed(7)
-- Relógio do servidor controlado pelo teste (tempo trabalhado e cooldowns).
local clock = 1792000000
os.time = function() return clock end

Core = { Players = { GetActiveCharacterId = function(id) return characters[id] end }, Events = { On = function() end } }
exports = setmetatable({}, {
	__call = function(_, name, fn) exported[name] = fn end,
	__index = function(_, resource)
		if resource == 'coe_economy' then
			return {
				Credit = function(_, id, amount, reason) credits[#credits + 1] = { id = id, amount = amount, reason = reason }; balances[id] = (balances[id] or 0) + amount; return true end,
				Debit = function(_, id, amount, reason)
					if (balances[id] or 0) < amount then return nil end
					balances[id] = balances[id] - amount; debits[#debits + 1] = { id = id, amount = amount, reason = reason }; return true
				end
			}
		end
		if resource == 'coe_notify' then
			return { Notify = function(_, id, kind, message) notices[#notices + 1] = { id = id, kind = kind, message = message } end }
		end
		return setmetatable({}, { __index = function() return function() return true end end })
	end
})

local db, profiles, savedSessions = {}, {}, {}
-- O tablet chama a Carreira com a ACE coe.jobs.tablet no principal do resource.
IsPrincipalAceAllowed = function(principal, ace) return principal == 'resource.coe_tablet' and ace == 'coe.jobs.tablet' end
dofile('../coe_core/lib/access.lua')
dofile('locales/pt-br.lua')
dofile('config.lua')
dofile('shared/rules.lua')
dofile('shared/career.lua')
dofile('shared/guide.lua')
JobsConfig.Enabled.miner = true
-- Emprego embutido (jobs/*.lua) com requisito de carreira: carregado na inicialização.
JobsCatalog[1] = { id = 'miner', label = 'Mineiro', kind = 'gather', center = { 0, 0, 0 }, skills = { 'strength' },
	requires = { skills = { strength = 2 } },
	gather = { nodes = { { 5, 0, 0 } }, seconds = 5, sell = { points = { { 6, 0, 0 } }, price = 10 } } }
JobsPersistence = {
	Initialize = function() return true end,
	AllProgress = function(c)
		local out = {}
		for key, r in pairs(db) do
			local char, job = key:match('^(.-):(.+)$')
			if char == c then out[job] = { xp = r.xp, tasks = r.tasks, earned = r.earned } end
		end
		return out
	end,
	Profile = function(c) local p = profiles[c]; return p and { reputation = p.reputation, completed = p.completed, abandoned = p.abandoned } or { reputation = 0, completed = 0, abandoned = 0 } end,
	SaveProfile = function(c, r) profiles[c] = { reputation = r.reputation, completed = r.completed, abandoned = r.abandoned }; return true end,
	Save = function(c, j, p) db[c .. ':' .. j] = { xp = p.xp, tasks = p.tasks, earned = p.earned, seconds = p.seconds, firstAt = p.firstAt, lastAt = p.lastAt }; return true end,
	SaveSession = function(c, entry) savedSessions[#savedSessions + 1] = { character = c, entry = entry }; return true end,
	Sessions = function() return {} end
}
dofile('server/main.lua')

local function eq(a, b, m)
	if a ~= b then error(('%s: esperado %s, veio %s'):format(m, tostring(b), tostring(a)), 2) end
end
local function net(name, playerId, ...)
	source = playerId
	now = now + 1000
	netHandlers[name](...)
end
local function lastEvent(name)
	for i = #clientEvents, 1, -1 do if clientEvents[i].name == name then return clientEvents[i] end end
end
local function lastNotice() return notices[#notices] end

eq(exported.IsReady(), true, 'pronto depois das migracoes')
eq(#exported.ListJobs(), 1, 'emprego embutido carregado')

-- registro pelo pacote
local lumber = {
	id = 'lumberjack', label = 'Lenhador', kind = 'gather', center = { 0, 0, 0 }, levels = { 0, 8, 100 },
	vehicle = { model = 'bison', spawn = { 3, 0, 0 }, deposit = 200 },
	gather = { nodes = { { 50, 0, 0 }, { 60, 0, 0 } }, seconds = 5, yield = { 3, 3 }, capacity = 5, xp = 4, nodeCooldown = 60,
		sell = { points = { { 100, 0, 0 } }, price = 10 } }
}
eq(exported.RegisterJob(lumber), true, 'pacote registra o emprego')
eq(lastEvent('coe_jobs:catalog').target, -1, 'catalogo vai para todos')
eq(#exported.ListJobs(), 2, 'catalogo com o embutido e o registrado')
invoking = 'outro_pacote'
eq(exported.RegisterJob(lumber), 'id_taken', 'outro pacote nao toma o id')
eq(exported.RegisterJob({ id = 'xx' }), 'invalid_label', 'definicao invalida devolve o codigo')
invoking = 'coe_extra_jobs'

-- comecar: perto do centro, deposito do veiculo
positions[1] = { x = 20, y = 0, z = 0 }
net('coe_jobs:start', 1, 'lumberjack')
eq(lastEvent('coe_jobs:result').payload.error, 'too_far', 'longe do centro nao comeca')
positions[1] = { x = 1, y = 0, z = 0 }
balances['22'] = 0
positions[2] = { x = 1, y = 0, z = 0 }
net('coe_jobs:start', 2, 'lumberjack')
eq(lastEvent('coe_jobs:result').payload.error, 'no_deposit', 'sem saldo para o deposito')
net('coe_jobs:start', 1, 'lumberjack')
local view = lastEvent('coe_jobs:session').payload
eq(view.jobId, 'lumberjack', 'sessao aberta')
eq(view.vehicle ~= nil, true, 'veiculo do emprego liberado')
eq(balances['11'], 800, 'deposito debitado')
net('coe_jobs:start', 1, 'lumberjack')
eq(lastEvent('coe_jobs:result').payload.error, 'already_working', 'nao abre duas sessoes')

-- coleta: distancia, tempo da acao, cooldown do ponto, capacidade
net('coe_jobs:gather', 1, 'lumberjack', 1)
eq(lastEvent('coe_jobs:result').payload.error, 'too_far', 'longe do ponto')
positions[1] = { x = 50, y = 1, z = 2 }
now = now + 6000
net('coe_jobs:gather', 1, 'lumberjack', 1)
view = lastEvent('coe_jobs:session').payload
eq(view.cargo, 3, 'coletou 3')
eq(view.cooldowns[1].node, 1, 'ponto entra em cooldown')
positions[1] = { x = 60, y = 0, z = 0 }
net('coe_jobs:gather', 1, 'lumberjack', 2)
eq(lastEvent('coe_jobs:result').payload.error, 'too_fast', 'acao mais rapida que a animacao')
positions[1] = { x = 50, y = 0, z = 0 }
now = now + 6000
net('coe_jobs:gather', 1, 'lumberjack', 1)
eq(lastEvent('coe_jobs:result').payload.error, 'cooldown', 'mesmo ponto em cooldown')
positions[1] = { x = 60, y = 0, z = 0 }
now = now + 6000
net('coe_jobs:gather', 1, 'lumberjack', 2)
view = lastEvent('coe_jobs:session').payload
eq(view.cargo, 5, 'limitado pela capacidade')
eq(view.progress.level, 2, 'subiu de nivel com XP')
local leveled = false
for _, n in ipairs(notices) do if n.message:find('nível 2') then leveled = true end end
eq(leveled, true, 'aviso de nivel')
eq(db['11:lumberjack'].xp, 8, 'XP gravado')

-- encerrar com carga avisa e nao encerra (a carga da coleta se perde)
positions[1] = { x = 1, y = 0, z = 0 }
net('coe_jobs:stop', 1)
eq(lastEvent('coe_jobs:result').payload.error, 'cargo_left', 'encerrar com carga pede confirmacao')
eq(lastNotice().message:find('Venda no comprador') ~= nil, true, 'aviso para vender')
eq(lastNotice().kind, 'warning', 'aviso e alerta')

-- venda com bonus de nivel
net('coe_jobs:sell', 1, 'lumberjack', 1)
eq(lastEvent('coe_jobs:result').payload.error, 'too_far', 'venda longe do comprador')
positions[1] = { x = 100, y = 0, z = 0 }
net('coe_jobs:sell', 1, 'lumberjack', 1)
eq(credits[#credits].amount, 52, '5 x $10 com +5% do nivel 2')
eq(credits[#credits].reason, 'job_lumberjack', 'motivo do extrato')
eq(lastEvent('coe_jobs:session').payload.cargo, 0, 'carga zerada')
eq(db['11:lumberjack'].earned, 52, 'ganhos gravados')
eq(profiles['11'].reputation, 1, 'venda conta para a reputacao')
eq(profiles['11'].completed, 1, 'trabalho concluido')
net('coe_jobs:sell', 1, 'lumberjack', 1)
eq(lastEvent('coe_jobs:result').payload.error, 'empty', 'nada para vender')

-- personagem errado nao age na sessao
characters[1] = 99
net('coe_jobs:sell', 1, 'lumberjack', 1)
eq(lastEvent('coe_jobs:result').payload.error, 'not_working', 'outro personagem nao usa a sessao')
characters[1] = 11

-- encerrar: deposito volta com o veiculo perto do centro
positions[1] = { x = 1, y = 0, z = 0 }
clock = clock + 600
net('coe_jobs:stop', 1)
eq(balances['11'], 800 + 52 + 200, 'deposito devolvido')
eq(db['11:lumberjack'].seconds, 600, 'tempo trabalhado somado')
eq(db['11:lumberjack'].lastAt, clock, 'ultima vez no emprego')
local lumberCareer
for _, entry in ipairs(exported.GetCareer('11').jobs) do if entry.id == 'lumberjack' then lumberCareer = entry end end
eq(lumberCareer.workedSeconds, 600, 'tempo no GetCareer')
eq(lumberCareer.kindLabel, 'Coleta e venda', 'tipo do emprego no GetCareer')
eq(exported.GetCareer('11').workedSeconds, 600, 'tempo total')
eq(lastNotice().message:find('Lenhador encerrado: 2 tarefas, %+8 XP, %$52 ganhos') ~= nil, true, 'resumo ao encerrar')
eq(savedSessions[#savedSessions].entry.jobId, 'lumberjack', 'trabalho registrado')
eq(savedSessions[#savedSessions].entry.earned, 52, 'ganhos da sessao')
eq(savedSessions[#savedSessions].entry.discarded, 0, 'nada descartado')
eq(lastEvent('coe_jobs:ended').payload.summary.tasks, 2, 'resumo vai ao client')
eq(lastEvent('coe_jobs:ended').payload.refund, 200, 'client avisado do fim')
eq(next(entities), nil, 'veiculo removido')

-- rota: parada certa, veiculo perto, anti-teleporte, bonus e nova rota
local delivery = {
	id = 'delivery', label = 'Entregador', kind = 'route', center = { 0, 0, 0 },
	vehicle = { model = 'boxville2', spawn = { 2, 0, 0 } },
	route = { stops = { { 1000, 0, 0 }, { 2000, 0, 0 } }, perRoute = 2, pay = 100, bonus = 50, xp = 5, vehicleRange = 40 }
}
eq(exported.RegisterJob(delivery), true, 'segundo emprego')
net('coe_jobs:start', 1, 'delivery')
view = lastEvent('coe_jobs:session').payload
eq(view.route.index, 1, 'primeira parada')
local stop = view.route.stop
positions[1] = { x = stop.x, y = stop.y, z = stop.z }
net('coe_jobs:deliver', 1, 'delivery')
eq(lastEvent('coe_jobs:result').payload.error, 'vehicle_far', 'veiculo longe da parada')
local vehicleEntity = view.vehicle - 10000
entities[vehicleEntity] = { x = stop.x + 5, y = 0, z = 0 }
now = now + 1000
net('coe_jobs:deliver', 1, 'delivery')
eq(lastEvent('coe_jobs:result').payload.error, 'too_fast', 'rapido demais desde o centro (teleporte)')
now = now + 60000
net('coe_jobs:deliver', 1, 'delivery')
view = lastEvent('coe_jobs:session').payload
eq(view.route.index, 2, 'segunda parada')
eq(credits[#credits].amount, 100, 'pagamento da parada')
stop = view.route.stop
positions[1] = { x = stop.x, y = stop.y, z = stop.z }
entities[vehicleEntity] = { x = stop.x, y = 0, z = 0 }
now = now + 60000
net('coe_jobs:deliver', 1, 'delivery')
eq(credits[#credits].amount, 50, 'bonus da rota')
view = lastEvent('coe_jobs:session').payload
eq(view.route.index, 1, 'nova rota')
eq(lastNotice().message:find('Nova rota') ~= nil, true, 'aviso de nova rota')

-- historico em um emprego libera outro: o mineiro exige Forca 2 (o lenhador nao treina Forca aqui)
positions[1] = { x = 0, y = 0, z = 0 }
handlers.onResourceStop('coe_extra_jobs')
eq(#exported.ListJobs(), 1, 'empregos do resource parado saem; o embutido fica')
eq(lastEvent('coe_jobs:ended').payload.reason, 'unavailable', 'sessao encerrada')
eq(next(entities), nil, 'veiculo removido ao parar o resource')
net('coe_jobs:start', 1, 'miner')
eq(lastEvent('coe_jobs:result').payload.error, 'locked', 'mineiro bloqueado sem Forca')
eq(lastNotice().message:find('Força nível 2') ~= nil, true, 'motivo do bloqueio')
db['33:lumberjack'] = { xp = 300, tasks = 1, earned = 0 }
lumber.skills = { 'strength', 'outdoor' }
invoking = 'coe_extra_jobs'
eq(exported.RegisterJob(lumber), true, 'lenhador volta com Forca')
characters[2] = 33
positions[2] = { x = 0, y = 0, z = 0 }
net('coe_jobs:start', 2, 'miner')
eq(lastEvent('coe_jobs:session').payload.jobId, 'miner', 'historico do lenhador libera o mineiro')
eq(lastEvent('coe_jobs:session').payload.career.level, 2, 'carreira nivel 2 pelo xp do lenhador')
eq(lastEvent('coe_jobs:session').payload.capacity, 22, 'Forca 2 aumenta a carga no mineiro')

-- abandonar com o veiculo da empresa custa reputacao; reputacao exemplar dispensa o deposito
eq(exported.RegisterJob(delivery), true, 'entregador de volta')
profiles['44'] = { reputation = 60, completed = 60, abandoned = 0 }
characters[1] = 44
balances['44'] = 0
positions[1] = { x = 0, y = 0, z = 0 }
net('coe_jobs:start', 1, 'delivery')
eq(lastEvent('coe_jobs:session').payload.jobId, 'delivery', 'exemplar comeca sem saldo: deposito dispensado')
eq(balances['44'], 0, 'exemplar nao paga deposito')
source = 1
handlers.playerDropped()
eq(profiles['44'].reputation, 50, 'abandono com o veiculo tira 10')
eq(profiles['44'].abandoned, 1, 'abandono contado')

-- rota de coleta (lixeiro): recolhe na parada, guarda no veiculo perto
invoking = 'coe_extra_jobs'
local garbage = {
	id = 'garbage', label = 'Lixeiro', kind = 'route', center = { 0, 0, 0 }, skills = { 'strength' },
	vehicle = { model = 'trash', spawn = { 2, 0, 0 } },
	route = { mode = 'collect', stops = { { 500, 0, 0 }, { 600, 0, 0 } }, perRoute = 1, pay = 40, xp = 5, vehicleRange = 25,
		carry = { model = 'prop_rub_binbag_01' } }
}
eq(exported.RegisterJob(garbage), true, 'lixeiro registrado')
positions[3] = { x = 0, y = 0, z = 0 }
net('coe_jobs:start', 3, 'garbage')
view = lastEvent('coe_jobs:session').payload
eq(view.route.mode, 'collect', 'modo na sessao')
eq(view.route.picked, false, 'nada recolhido')
local truck = view.vehicle - 10000
net('coe_jobs:deliver', 3, 'garbage')
eq(lastEvent('coe_jobs:result').payload.error, 'wrong_step', 'guardar antes de recolher')
stop = view.route.stop
positions[3] = { x = stop.x, y = 0, z = 0 }
net('coe_jobs:pickup', 3, 'garbage')
eq(lastEvent('coe_jobs:result').payload.error, 'vehicle_far', 'caminhao longe da cacamba')
entities[truck] = { x = stop.x + 10, y = 0, z = 0 }
now = now + 60000
net('coe_jobs:pickup', 3, 'garbage')
eq(lastEvent('coe_jobs:session').payload.route.picked, true, 'saco recolhido')
net('coe_jobs:pickup', 3, 'garbage')
eq(lastEvent('coe_jobs:result').payload.error, 'wrong_step', 'nao recolhe duas vezes')
net('coe_jobs:deliver', 3, 'garbage')
eq(lastEvent('coe_jobs:result').payload.error, 'vehicle_far', 'precisa ir ate o caminhao')
positions[3] = { x = stop.x + 5, y = 0, z = 0 }
net('coe_jobs:deliver', 3, 'garbage')
eq(credits[#credits].amount, 40, 'coleta paga')
eq(lastNotice().message:find('Coleta feita') ~= nil, true, 'aviso de coleta')
view = lastEvent('coe_jobs:session').payload
eq(view.route.picked, false, 'nova rota sem carga')
entities[truck] = { x = 0, y = 0, z = 0 }
positions[3] = { x = 0, y = 0, z = 0 }
net('coe_jobs:stop', 3)

-- rota de passageiro (taxi): embarque e destino, corrida paga por km
local taxi = {
	id = 'taxi', label = 'Taxista', kind = 'route', center = { 0, 0, 0 }, skills = { 'driving' },
	vehicle = { model = 'taxi', spawn = { 2, 0, 0 } },
	route = { mode = 'passenger', stops = { { 1000, 0, 0 }, { 3000, 0, 0 } }, perRoute = 1, pay = 30, payPerKm = 50,
		xp = 10, stopRadius = 12, vehicleRange = 15 }
}
eq(exported.RegisterJob(taxi), true, 'taxi registrado')
net('coe_jobs:start', 3, 'taxi')
view = lastEvent('coe_jobs:session').payload
eq(view.route.phase, 'pickup', 'primeiro o embarque')
eq(view.route.total, 1, 'uma corrida por rota')
local cab = view.vehicle - 10000
net('coe_jobs:deliver', 3, 'taxi')
eq(lastEvent('coe_jobs:result').payload.error, 'wrong_step', 'nao desembarca antes de embarcar')
local boarding = view.route.stop
positions[3] = { x = boarding.x + 8, y = 0, z = 0 }
entities[cab] = { x = boarding.x + 8, y = 0, z = 0 }
now = now + 120000
net('coe_jobs:pickup', 3, 'taxi')
view = lastEvent('coe_jobs:session').payload
eq(view.route.phase, 'dropoff', 'passageiro a bordo')
eq(view.route.index, 1, 'ainda a primeira corrida')
local destination = view.route.stop
positions[3] = { x = destination.x, y = 0, z = 0 }
entities[cab] = { x = destination.x, y = 0, z = 0 }
net('coe_jobs:deliver', 3, 'taxi')
eq(lastEvent('coe_jobs:result').payload.error, 'too_fast', 'corrida rapida demais')
now = now + 120000
net('coe_jobs:deliver', 3, 'taxi')
eq(credits[#credits].amount, 30 + 100, 'fixo + 2 km x $50')
eq(lastEvent('coe_jobs:session').payload.route.phase, 'pickup', 'nova corrida')
eq(profiles['55'].completed, 2, 'coleta e corrida concluidas')
entities[cab] = { x = 0, y = 0, z = 0 }
positions[3] = { x = 0, y = 0, z = 0 }
net('coe_jobs:stop', 3)

-- rota por zonas (lixeiro): lixeiras do mapa dentro da área, saco no caminhão, área completa com perZone sacos
local zoneJob = {
	id = 'trash', label = 'Lixeiro', kind = 'route', center = { 0, 0, 0 }, skills = { 'strength' },
	vehicle = { model = 'trash', spawn = { 2, 0, 0 } },
	route = { mode = 'zone', pay = 20, bonus = 50, xp = 3, perRoute = 2, perZone = 2, binCooldown = 600,
		carry = { model = 'prop_cs_rub_binbag_01' }, binModels = { 'prop_bin_01a' },
		zones = { { 1000, 0, 0, radius = 50, label = 'Norte' }, { 3000, 0, 0, radius = 50, label = 'Sul' } } }
}
eq(exported.RegisterJob(zoneJob), true, 'lixeiro por zonas registrado')
positions[3] = { x = 0, y = 0, z = 0 }
net('coe_jobs:start', 3, 'trash')
view = lastEvent('coe_jobs:session').payload
eq(view.route.mode, 'zone', 'modo zona na sessao')
eq(view.route.zone.radius, 50, 'zona com raio')
eq(view.route.perZone, 2, 'sacos por zona')
local trashTruck = view.vehicle - 10000
net('coe_jobs:deliver', 3, 'trash')
eq(lastEvent('coe_jobs:result').payload.error, 'wrong_step', 'guardar antes de recolher')
local zone = view.route.zone
positions[3] = { x = zone.x + 80, y = 0, z = 0 }
net('coe_jobs:pickup', 3, 'trash', { x = zone.x + 81, y = 0, z = 0 })
eq(lastEvent('coe_jobs:result').payload.error, 'outside_zone', 'fora da area')
positions[3] = { x = zone.x + 10, y = 0, z = 0 }
net('coe_jobs:pickup', 3, 'trash', { x = zone.x + 20, y = 0, z = 0 })
eq(lastEvent('coe_jobs:result').payload.error, 'too_far', 'lixeira longe do jogador')
net('coe_jobs:pickup', 3, 'trash', { x = zone.x + 11, y = 1, z = 0 })
eq(lastEvent('coe_jobs:result').payload.error, 'too_fast', 'chegou rapido demais na area')
now = now + 120000
net('coe_jobs:pickup', 3, 'trash', { x = zone.x + 11, y = 1, z = 0 })
eq(lastEvent('coe_jobs:session').payload.route.picked, true, 'saco recolhido')
net('coe_jobs:pickup', 3, 'trash', { x = zone.x + 11, y = 1, z = 0 })
eq(lastEvent('coe_jobs:result').payload.error, 'wrong_step', 'um saco por vez')
entities[trashTruck] = { x = zone.x + 200, y = 0, z = 0 }
net('coe_jobs:deliver', 3, 'trash')
eq(lastEvent('coe_jobs:result').payload.error, 'vehicle_far', 'caminhao longe')
entities[trashTruck] = { x = zone.x + 14, y = 0, z = 0 }
net('coe_jobs:deliver', 3, 'trash')
eq(credits[#credits].amount, 20, 'saco pago')
view = lastEvent('coe_jobs:session').payload
eq(view.route.collected, 1, 'um saco na area')
eq(view.route.picked, false, 'mao livre')
net('coe_jobs:pickup', 3, 'trash', { x = zone.x + 11.3, y = 1.2, z = 0 })
eq(lastEvent('coe_jobs:result').payload.error, 'bin_empty', 'mesma lixeira vazia')
positions[3] = { x = zone.x + 12, y = 2, z = 0 }
net('coe_jobs:pickup', 3, 'trash', { x = zone.x + 13, y = 3, z = 0 })
net('coe_jobs:deliver', 3, 'trash')
view = lastEvent('coe_jobs:session').payload
eq(view.route.index, 2, 'area concluida, proxima area')
eq(view.route.collected, 0, 'contagem zerada')
eq(lastNotice().message:find('concluída') ~= nil, true, 'aviso de area concluida')
zone = view.route.zone
positions[3] = { x = zone.x, y = 0, z = 0 }
entities[trashTruck] = { x = zone.x + 3, y = 0, z = 0 }
now = now + 120000
for i = 1, 2 do
	net('coe_jobs:pickup', 3, 'trash', { x = zone.x + 1, y = i * 2, z = 0 })
	positions[3] = { x = zone.x, y = i * 2, z = 0 }
	net('coe_jobs:deliver', 3, 'trash')
end
eq(credits[#credits].amount, 50, 'bonus da rota por zonas')
eq(lastEvent('coe_jobs:session').payload.route.index, 1, 'nova rota')
eq(lastNotice().message:find('Nova área') ~= nil, true, 'aviso de nova area')
positions[3] = { x = 0, y = 0, z = 0 }
entities[trashTruck] = { x = 0, y = 0, z = 0 }
net('coe_jobs:stop', 3)

-- app Carreira no tablet
invoking = 'coe_tablet'
local tablet = exported.TabletCall(2, 'career', 'profile', {})
eq(tablet.ok, true, 'carreira no tablet')
eq(tablet.data.level, 2, 'nivel de carreira')
eq(tablet.data.working, 'miner', 'emprego atual')
local strength
for _, skill in ipairs(tablet.data.skills) do if skill.id == 'strength' then strength = skill end end
eq(strength.level, 2, 'Forca nivel 2 no app')
invoking = 'outro'
eq(exported.TabletCall(2, 'career', 'profile', {}).error, 'forbidden', 'so o coe_tablet chama')

-- descartar a carga e encerrar: fica nos ultimos trabalhos, com o descarte
positions[2] = { x = 5, y = 0, z = 0 }
now = now + 6000
net('coe_jobs:gather', 2, 'miner', 1)
local cargo = lastEvent('coe_jobs:session').payload.cargo
eq(cargo > 0, true, 'minerio na mao')
positions[2] = { x = 0, y = 0, z = 0 }
net('coe_jobs:stop', 2)
eq(lastEvent('coe_jobs:result').payload.error, 'cargo_left', 'pede para vender antes')
net('coe_jobs:stop', 2, true)
eq(lastEvent('coe_jobs:ended').payload.summary.discarded, cargo, 'descarte no resumo')
eq(lastNotice().message:find('descartados') ~= nil, true, 'aviso do descarte')
invoking = 'coe_tablet'
local career33 = exported.TabletCall(2, 'career', 'profile', {}).data
eq(career33.sessions[1].jobId, 'miner', 'ultimo trabalho no app')
eq(career33.sessions[1].label, 'Mineiro', 'nome do emprego no historico')
eq(career33.sessions[1].discarded, cargo, 'descarte no historico')

-- guia "Como funciona": no NPC (evento) e no app
net('coe_jobs:guide', 2, 'miner')
local guide = lastEvent('coe_jobs:guide').payload
eq(guide.label, 'Mineiro', 'guia do emprego')
eq(#guide.steps >= 4, true, 'passo a passo')
eq(guide.requires, 'Força nível 2', 'requisito em texto')
eq(guide.player.allowed, true, 'liberado pelo historico')
eq(guide.player.sessions[1].jobId, 'miner', 'ultimas vezes neste emprego')
eq(guide.player.working, false, 'nao esta trabalhando')
local tabletGuide = exported.TabletCall(2, 'career', 'guide', { jobId = 'miner' })
eq(tabletGuide.ok, true, 'guia no tablet')
eq(tabletGuide.data.player.tasks >= 1, true, 'tarefas no guia')
eq(exported.TabletCall(2, 'career', 'guide', { jobId = 'nada' }).error, 'invalid_payload', 'emprego desconhecido')


print('coe_jobs server tests passed')
