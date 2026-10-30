-- Testes do server/main.lua: eventos de rede e exports que movem jogadores entre canais de voz.
-- Rodar a partir da pasta do resource: lua test/server_main_test.lua

local function eq(actual, expected, message)
	if actual ~= expected then
		error(('%s: esperado %s, obtido %s'):format(message, tostring(expected), tostring(actual)), 2)
	end
end

local handlers, registered, sent = {}, {}, {}
local now, invoker, playerJob = 0, 'coe_mobile', 'unemployed'

RegisterNetEvent = function(name, fn) handlers[name] = fn end
AddEventHandler = function(name, fn) handlers[name] = fn end
TriggerClientEvent = function(name, target, ...) sent[#sent + 1] = { name = name, target = target, args = { ... } } end
CreateThread = function() end
GetGameTimer = function() return now end
GetInvokingResource = function() return invoker end
IsPrincipalAceAllowed = function() return false end
exports = setmetatable({}, {
	__call = function(_, name, fn) registered[name] = fn end,
	__index = function(_, res)
		if res == 'coe_core' then
			return { GetPlayerGroups = function() return { job = { name = playerJob } } end }
		end
		if res == 'coe_notify' then
			return { Notify = function() end }
		end
		return nil
	end
})

dofile('../coe_core/lib/access.lua')
dofile('config.lua')
dofile('shared/rules.lua')
dofile('server/routing.lua')
dofile('server/main.lua')

local function fire(name, src, ...)
	source = src
	handlers[name](...)
end

-- 1. O client não escolhe chamada: o evento antigo de entrar em chamada não existe mais.
eq(handlers['coe_talk:server:setCall'], nil, 'evento setCall removido')
eq(type(handlers['coe_talk:server:leaveCall']), 'function', 'sair da chamada continua pelo client')

-- 2. SetPlayerCall: só coe_mobile (ou ACE coe.talk), com id e jogador válidos.
local ok, err = registered.SetPlayerCall(1, 'coe_mobile:00ff00ff00ff00ff')
eq(ok, true, 'coe_mobile coloca jogador na chamada')
eq(Routing.GetCall(1), 'coe_mobile:00ff00ff00ff00ff', 'jogador 1 na chamada')

invoker = 'script_qualquer'
ok, err = registered.SetPlayerCall(2, 'coe_mobile:00ff00ff00ff00ff')
eq(ok, false, 'resource sem ACE recusado')
eq(err, 'forbidden', 'erro forbidden')
eq(Routing.GetCall(2), nil, 'jogador 2 não entrou')
ok, err = registered.SetPlayerRadio(2, 2.0)
eq(err, 'forbidden', 'SetPlayerRadio também exige autorização')

invoker = 'coe_mobile'
eq(select(2, registered.SetPlayerCall(2, { 'tabela' })), 'invalid_call', 'id de chamada não-string recusado')
eq(select(2, registered.SetPlayerCall(2, string.rep('a', 65))), 'invalid_call', 'id longo recusado')
eq(select(2, registered.SetPlayerCall('2', 'x')), 'invalid_player', 'jogador inválido recusado')
eq(registered.SetPlayerCall(1, nil), true, 'nil encerra a chamada')
eq(Routing.GetCall(1), nil, 'jogador 1 saiu')

-- 3. Rádio: frequência restrita exige job e eventos têm rate limit.
fire('coe_talk:server:setRadio', 5, 2.0)
eq(Routing.GetRadio(5), nil, 'frequência restrita sem job é recusada')
now = now + 1000
playerJob = 'police'
fire('coe_talk:server:setRadio', 5, 2.0)
eq(Routing.GetRadio(5), 2.0, 'policial entra na frequência restrita')
fire('coe_talk:server:setRadio', 5, 150.0)
eq(Routing.GetRadio(5), 2.0, 'segunda troca dentro do cooldown é ignorada')
now = now + 1000
fire('coe_talk:server:setRadio', 5, 150.0)
eq(Routing.GetRadio(5), 150.0, 'troca depois do cooldown aceita')

io.write('coe_talk server_main_test: ok\n')
