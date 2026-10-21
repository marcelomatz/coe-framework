Routing = {}

local radioChannels = {}      -- [frequency] = { [source] = true }
local radioVoiceChannels = {} -- [frequency] = channelId (Modo 0: Nao-espacial / 2D)
local playerRadio = {}        -- [source] = frequency

local callChannels = {}       -- [callId] = { [source] = true }
local callVoiceChannels = {}  -- [callId] = channelId (Modo 0: Nao-espacial / 2D)
local playerCall = {}         -- [source] = callId

-- Canais espaciais (Modo 1) para proximidade:
-- Sussurro: 1.5m, Normal: 5.0m, Grito: 15.0m
local proximityVoiceChannels = {} -- [distance] = channelId
local playerProximity = {}        -- [source] = { distance = 5.0, active = false }

-- Inicializa os canais de proximidade espaciais no servidor
function Routing.InitProximityChannels(modes)
	if not CreateVoiceChannel then return end
	modes = modes or { 1.5, 5.0, 15.0 }
	for _, dist in ipairs(modes) do
		pcall(function()
			if not proximityVoiceChannels[dist] then
				proximityVoiceChannels[dist] = CreateVoiceChannel(1, dist)
			end
		end)
	end
end

-- Define o alcance e estado de transmissao de voz do jogador
function Routing.SetPlayerProximity(source, distance, active)
	local src = tonumber(source)
	if not src then return end
	distance = tonumber(distance) or 5.0
	active = active == true
	playerProximity[src] = { distance = distance, active = active }

	if not AddPlayerToVoiceChannel or not SetPlayerMutedInVoiceChannel then return end

	pcall(function()
		for dist, ch in pairs(proximityVoiceChannels) do
			if ch then
				AddPlayerToVoiceChannel(ch, src)
				-- O jogador transmite no canal se estiver ativo (falando/PTT) e a distancia corresponder
				local canSpeak = active and (dist == distance)
				SetPlayerMutedInVoiceChannel(ch, src, not canSpeak)
				if SetPlayerDeafInVoiceChannel then
					SetPlayerDeafInVoiceChannel(ch, src, false)
				end
			end
		end
	end)
end

-- Entra em um canal de radio (Server-Controlled Voice Channel)
function Routing.JoinRadio(source, frequency)
	local src = tonumber(source)
	if not src then return false end
	Routing.LeaveRadio(src)
	if not frequency then return true end

	if not radioChannels[frequency] then
		radioChannels[frequency] = {}
		if CreateVoiceChannel then
			pcall(function()
				radioVoiceChannels[frequency] = CreateVoiceChannel(0, 0.0)
			end)
		end
	end

	radioChannels[frequency][src] = true
	playerRadio[src] = frequency

	local ch = radioVoiceChannels[frequency]
	if ch and AddPlayerToVoiceChannel then
		pcall(function()
			AddPlayerToVoiceChannel(ch, src)
			-- Mutado por padrao no canal ate pressionar PTT
			SetPlayerMutedInVoiceChannel(ch, src, true)
			if SetPlayerDeafInVoiceChannel then
				SetPlayerDeafInVoiceChannel(ch, src, false)
			end
		end)
	end

	return true
end

-- Controle de transmissao de radio (PTT)
function Routing.SetRadioTransmitting(source, transmitting)
	local src = tonumber(source)
	if not src then return end
	local freq = playerRadio[src]
	if not freq then return end

	local ch = radioVoiceChannels[freq]
	if ch and SetPlayerMutedInVoiceChannel then
		pcall(function()
			SetPlayerMutedInVoiceChannel(ch, src, not transmitting)
		end)
	end
end

-- Sai do canal de radio
function Routing.LeaveRadio(source)
	local src = tonumber(source)
	if not src then return false end
	local current = playerRadio[src]
	if not current then return false end

	local ch = radioVoiceChannels[current]
	if ch and RemovePlayerFromVoiceChannel then
		pcall(function()
			RemovePlayerFromVoiceChannel(ch, src)
		end)
	end

	playerRadio[src] = nil
	if radioChannels[current] then
		radioChannels[current][src] = nil
		if next(radioChannels[current]) == nil then
			radioChannels[current] = nil
			if ch and DeleteVoiceChannel then
				pcall(function()
					DeleteVoiceChannel(ch)
				end)
			end
			radioVoiceChannels[current] = nil
		end
	end
	return true, current
end

function Routing.GetRadio(source)
	local src = tonumber(source)
	return src and playerRadio[src] or nil
end

function Routing.GetRadioMembers(frequency)
	if not frequency or not radioChannels[frequency] then
		return {}
	end
	local list = {}
	for src in pairs(radioChannels[frequency]) do
		list[#list + 1] = src
	end
	return list
end

-- Entra em uma chamada telefonica (Server-Controlled Voice Channel)
function Routing.JoinCall(source, callId)
	local src = tonumber(source)
	if not src then return false end
	Routing.LeaveCall(src)
	if not callId then return true end

	if not callChannels[callId] then
		callChannels[callId] = {}
		if CreateVoiceChannel then
			pcall(function()
				callVoiceChannels[callId] = CreateVoiceChannel(0, 0.0)
			end)
		end
	end

	callChannels[callId][src] = true
	playerCall[src] = callId

	local ch = callVoiceChannels[callId]
	if ch and AddPlayerToVoiceChannel then
		pcall(function()
			AddPlayerToVoiceChannel(ch, src)
			SetPlayerMutedInVoiceChannel(ch, src, false)
			if SetPlayerDeafInVoiceChannel then
				SetPlayerDeafInVoiceChannel(ch, src, false)
			end
		end)
	end

	return true
end

function Routing.LeaveCall(source)
	local src = tonumber(source)
	if not src then return false end
	local current = playerCall[src]
	if not current then return false end

	local ch = callVoiceChannels[current]
	if ch and RemovePlayerFromVoiceChannel then
		pcall(function()
			RemovePlayerFromVoiceChannel(ch, src)
		end)
	end

	playerCall[src] = nil
	if callChannels[current] then
		callChannels[current][src] = nil
		if next(callChannels[current]) == nil then
			callChannels[current] = nil
			if ch and DeleteVoiceChannel then
				pcall(function()
					DeleteVoiceChannel(ch)
				end)
			end
			callVoiceChannels[current] = nil
		end
	end
	return true, current
end

function Routing.GetCall(source)
	local src = tonumber(source)
	return src and playerCall[src] or nil
end

function Routing.GetCallMembers(callId)
	if not callId or not callChannels[callId] then
		return {}
	end
	local list = {}
	for src in pairs(callChannels[callId]) do
		list[#list + 1] = src
	end
	return list
end

-- Remove jogador de todos os canais ao desconectar
function Routing.RemovePlayer(source)
	local src = tonumber(source)
	if not src then return end
	Routing.LeaveRadio(src)
	Routing.LeaveCall(src)
	playerProximity[src] = nil

	if RemovePlayerFromVoiceChannel then
		pcall(function()
			for _, ch in pairs(proximityVoiceChannels) do
				if ch then
					RemovePlayerFromVoiceChannel(ch, src)
				end
			end
		end)
	end
end

-- Acesso aos canais para testes unitarios
function Routing.GetVoiceChannels()
	return {
		radio = radioVoiceChannels,
		call = callVoiceChannels,
		proximity = proximityVoiceChannels
	}
end
