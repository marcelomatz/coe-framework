dofile('config.lua')
dofile('shared/rules.lua')

local function eq(a, b, msg)
	if a ~= b then
		error(('%s: esperado %s, obtido %s'):format(msg, tostring(b), tostring(a)))
	end
end

-- Teste de formatação de uptime
eq(Rules.FormatUptime(0), '0m 00s', 'uptime 0 segundos')
eq(Rules.FormatUptime(59), '0m 59s', 'uptime 59 segundos')
eq(Rules.FormatUptime(65), '1m 05s', 'uptime 65 segundos')
eq(Rules.FormatUptime(3600), '1h 00m', 'uptime 1 hora')
eq(Rules.FormatUptime(7325), '2h 02m', 'uptime 2 horas e 2 minutos')

-- Teste de formatação de moeda
eq(Rules.FormatCurrency(0), 'R$ 0', 'moeda zero')
eq(Rules.FormatCurrency(150), 'R$ 150', 'moeda centenas')
eq(Rules.FormatCurrency(1250), 'R$ 1.250', 'moeda milhares')
eq(Rules.FormatCurrency(1500000), 'R$ 1.500.000', 'moeda milhões')

-- Teste de montagem do payload
local payload = Rules.BuildPayload({
	name = 'Marcus Holloway',
	stateId = 'COE7788',
	job = 'Desenvolvedor',
	jobGrade = 'Senior',
	bank = 250000
}, {
	onlinePlayers = 42,
	maxPlayers = 128,
	ping = 15,
	uptime = 3660
})

eq(payload.character.name, 'Marcus Holloway', 'nome do personagem')
eq(payload.character.stateId, 'COE7788', 'stateId')
eq(payload.character.job, 'Desenvolvedor', 'emprego')
eq(payload.character.bank, 'R$ 250.000', 'saldo bancário formatado')
eq(payload.server.onlinePlayers, 42, 'jogadores online')
eq(payload.server.ping, 15, 'ping')
eq(payload.server.uptime, '1h 01m', 'uptime formatado')
eq(#payload.quickBinds > 0, true, 'atalhos carregados')
eq(#payload.rules > 0, true, 'regras carregadas')

print('coe_pausemenu rules tests passed')
