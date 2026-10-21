local netEvents = {}
local clientEvents = {}
local droppedPlayers = {}

RegisterNetEvent = function(name, fn)
	netEvents[name] = fn
end

TriggerClientEvent = function(name, target, ...)
	clientEvents[#clientEvents + 1] = { name = name, target = target, args = { ... } }
end

DropPlayer = function(src, reason)
	droppedPlayers[#droppedPlayers + 1] = { source = src, reason = reason }
end

GetPlayerName = function(src)
	return 'Player_' .. tostring(src)
end

GetPlayerPing = function(src)
	return 22
end

GetPlayers = function()
	return { '1', '2', '3' }
end

GetConvarInt = function(name, default)
	return 128
end

exports = {
	coe_core = {
		GetActiveCharacter = function(src)
			return {
				characterId = 10,
				firstName = 'Lucas',
				lastName = 'Silva',
				stateId = 'COE1020',
				birthDate = '1995-05-12',
				gender = 'male',
				createdAt = '2026-01-01'
			}
		end
	},
	coe_economy = {
		GetBalance = function(charId)
			return 85000
		end
	},
	coe_jobs = {
		GetCareer = function(charId)
			return {
				currentJob = {
					name = 'police',
					label = 'Polícia Militar',
					grade = 3,
					gradeLabel = 'Sargento'
				}
			}
		end
	},
	coe_factions = {
		Memberships = function(charId)
			return {
				{
					factionId = 'tactical_squad',
					factionName = 'COE Tático',
					grade = 2,
					gradeName = 'Operador'
				}
			}
		end
	}
}

dofile('config.lua')
dofile('shared/rules.lua')
dofile('server/main.lua')

local function eq(a, b, msg)
	if a ~= b then
		error(('%s: esperado %s, obtido %s'):format(msg, tostring(b), tostring(a)))
	end
end

-- Teste de requisição de dados pelo cliente
source = 1
netEvents['coe_pausemenu:server:requestData']()

eq(#clientEvents, 1, 'evento enviado ao cliente')
local res = clientEvents[1]
eq(res.name, 'coe_pausemenu:client:receiveData', 'nome do evento de retorno')
eq(res.target, 1, 'enviado para o source solicitante')

local data = res.args[1]
eq(data.character.name, 'Lucas Silva', 'nome completo do personagem')
eq(data.character.stateId, 'COE1020', 'stateId')
eq(data.character.job, 'Polícia Militar', 'emprego')
eq(data.character.jobGrade, 'Sargento', 'cargo')
eq(data.character.faction, 'COE Tático', 'facção')
eq(data.character.bank, 'R$ 85.000', 'saldo formatado')
eq(data.server.onlinePlayers, 3, 'total de jogadores online')
eq(data.server.ping, 22, 'ping do jogador')

-- Teste de desconexão voluntária
netEvents['coe_pausemenu:server:disconnect']()
eq(#droppedPlayers, 1, 'jogador desconectado')
eq(droppedPlayers[1].source, 1, 'source desconectado')

print('coe_pausemenu server tests passed')
