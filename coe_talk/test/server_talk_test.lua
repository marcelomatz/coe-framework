-- Mocks dos natives de canais de voz do servidor FiveM Enhanced
local createdChannels = {}
local channelMembers = {}
local channelMuted = {}
local channelDeaf = {}
local nextChannelId = 1

CreateVoiceChannel = function(mode, maxDistance)
	local id = nextChannelId
	nextChannelId = nextChannelId + 1
	createdChannels[id] = { mode = mode, maxDistance = maxDistance }
	channelMembers[id] = {}
	channelMuted[id] = {}
	channelDeaf[id] = {}
	return id
end

AddPlayerToVoiceChannel = function(channelId, clientID)
	if not createdChannels[channelId] then error('canal nao existe') end
	channelMembers[channelId][clientID] = true
end

RemovePlayerFromVoiceChannel = function(channelId, clientID)
	if createdChannels[channelId] and channelMembers[channelId] then
		channelMembers[channelId][clientID] = nil
	end
end

DeleteVoiceChannel = function(channelId)
	createdChannels[channelId] = nil
	channelMembers[channelId] = nil
	channelMuted[channelId] = nil
	channelDeaf[channelId] = nil
end

SetPlayerMutedInVoiceChannel = function(channelId, clientID, muted)
	if channelMuted[channelId] then
		channelMuted[channelId][clientID] = muted
	end
end

SetPlayerDeafInVoiceChannel = function(channelId, clientID, deaf)
	if channelDeaf[channelId] then
		channelDeaf[channelId][clientID] = deaf
	end
end

dofile('config.lua')
dofile('shared/rules.lua')
dofile('server/routing.lua')

local function eq(a, b, msg)
	if a ~= b then
		error(('%s: esperado %s, obtido %s'):format(msg, tostring(b), tostring(a)))
	end
end

-- Inicializacao de canais espaciais de proximidade
Routing.InitProximityChannels({ 1.5, 5.0, 15.0 })
local vChannels = Routing.GetVoiceChannels()
eq(type(vChannels.proximity[1.5]), 'number', 'canal de proximidade 1.5m criado')
eq(type(vChannels.proximity[5.0]), 'number', 'canal de proximidade 5.0m criado')
eq(type(vChannels.proximity[15.0]), 'number', 'canal de proximidade 15.0m criado')

-- Jogador define proximidade (Normal 5.0m, falando/ativo)
Routing.SetPlayerProximity(1, 5.0, true)
local pNormChan = vChannels.proximity[5.0]
local pWhisChan = vChannels.proximity[1.5]
eq(channelMembers[pNormChan][1], true, 'jogador 1 adicionado ao canal normal')
eq(channelMuted[pNormChan][1], false, 'jogador 1 desmutado no canal normal')
eq(channelMuted[pWhisChan][1], true, 'jogador 1 mutado no canal sussurro')

-- Radio
eq(Routing.GetRadio(1), nil, 'jogador 1 sem radio')
Routing.JoinRadio(1, 101.5)
eq(Routing.GetRadio(1), 101.5, 'jogador 1 no canal 101.5')

local members = Routing.GetRadioMembers(101.5)
eq(#members, 1, '1 membro no canal 101.5')
eq(members[1], 1, 'membro e o jogador 1')

local radioChan = vChannels.radio[101.5]
eq(type(radioChan), 'number', 'canal de voz criado no servidor para 101.5 MHz')
eq(createdChannels[radioChan].mode, 0, 'modo do canal de radio e 0 (nao-espacial 2D)')
eq(channelMembers[radioChan][1], true, 'jogador 1 adicionado ao canal de voz de radio')
eq(channelMuted[radioChan][1], true, 'jogador 1 mutado no radio ate apertar PTT')

-- Pressiona PTT no radio
Routing.SetRadioTransmitting(1, true)
eq(channelMuted[radioChan][1], false, 'jogador 1 desmutado ao transmitir no radio')

-- Solta PTT no radio
Routing.SetRadioTransmitting(1, false)
eq(channelMuted[radioChan][1], true, 'jogador 1 mutado novamente ao soltar PTT')

-- Adiciona outro membro
Routing.JoinRadio(2, 101.5)
members = Routing.GetRadioMembers(101.5)
eq(#members, 2, '2 membros no canal 101.5')
eq(channelMembers[radioChan][2], true, 'jogador 2 adicionado ao canal de voz')

-- Troca de canal
Routing.JoinRadio(1, 200.0)
eq(Routing.GetRadio(1), 200.0, 'jogador 1 trocou para canal 200.0')
eq(#Routing.GetRadioMembers(101.5), 1, 'canal 101.5 ficou com 1 membro')
eq(#Routing.GetRadioMembers(200.0), 1, 'canal 200.0 tem 1 membro')

-- Jogador 2 sai do radio -> canal 101.5 esvazia e canal de voz e deletado
Routing.LeaveRadio(2)
eq(Routing.GetRadio(2), nil, 'jogador 2 saiu do radio')
eq(#Routing.GetRadioMembers(101.5), 0, 'canal 101.5 agora vazio')
eq(createdChannels[radioChan], nil, 'canal de voz 101.5 deletado ao esvaziar')

-- Chamadas de telefone
Routing.JoinCall(10, 'call_abc')
Routing.JoinCall(11, 'call_abc')
eq(Routing.GetCall(10), 'call_abc', 'jogador 10 na chamada')
eq(Routing.GetCall(11), 'call_abc', 'jogador 11 na chamada')
eq(#Routing.GetCallMembers('call_abc'), 2, '2 participantes na chamada')

local callChan = vChannels.call['call_abc']
eq(type(callChan), 'number', 'canal de voz criado para chamada')
eq(createdChannels[callChan].mode, 0, 'modo do canal de chamada e 0 (2D)')
eq(channelMembers[callChan][10], true, 'jogador 10 no canal de chamada')
eq(channelMembers[callChan][11], true, 'jogador 11 no canal de chamada')
eq(channelMuted[callChan][10], false, 'jogador 10 desmutado na chamada')

Routing.RemovePlayer(10)
eq(Routing.GetCall(10), nil, 'jogador 10 desconectou e saiu da chamada')
eq(#Routing.GetCallMembers('call_abc'), 1, 'restou 1 participante na chamada')
eq(channelMembers[callChan][10], nil, 'jogador 10 removido do canal de voz')

print('coe_talk server routing tests passed')
