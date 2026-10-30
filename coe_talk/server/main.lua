-- coe_talk - Servidor de Voz e Comunicacao
local accessConfig = Config.Access or {}
local lastEvent = {}

-- Eventos de voz chegam do client: um por jogador a cada Config.EventCooldownMs.
local function throttled(src, kind)
	local now = GetGameTimer()
	local byKind = lastEvent[src]
	if not byKind then
		byKind = {}
		lastEvent[src] = byKind
	end
	local previous = byKind[kind]
	if previous and now - previous < (Config.EventCooldownMs or 250) then
		return true
	end
	byKind[kind] = now
	return false
end

-- Exports de servidor que movem jogadores entre canais: so o coe_mobile (padrao) ou quem tem a ACE coe.talk.
local function callerAllowed()
	return CoeAccess.Allowed(GetInvokingResource(), accessConfig.Ace or 'coe.talk', accessConfig.Resources)
end

local function validPlayer(source)
	return math.type(source) == 'integer' and source > 0
end

local function validCallId(callId)
	return type(callId) == 'string' and #callId <= 64 and callId:match('^[%w_:%-]+$') ~= nil
end
local function getPlayerJob(src)
	local job = 'unemployed'
	pcall(function()
		if exports.coe_core and exports.coe_core.GetPlayerGroups then
			local groups = exports.coe_core:GetPlayerGroups(src)
			if groups and groups.job and groups.job.name then
				job = groups.job.name
			end
		elseif exports.coe_jobs and exports.coe_jobs.GetSession then
			local session = exports.coe_jobs:GetSession(src)
			if session and session.jobId then
				job = session.jobId
			end
		end
	end)
	return job
end

local function notify(src, kind, message)
	pcall(function()
		exports.coe_notify:Notify(src, kind, message, 3000)
	end)
end

local _t = function(key, params)
	if Core and Core.Locale and Core.Locale.New then
		return Core.Locale.New({ default = Core.Locale.GetDefaultLang(), locales = Locales or {} })(key, params)
	end
	if Locales and Locales['pt-BR'] and Locales['pt-BR'][key] then
		return Locales['pt-BR'][key]
	end
	return key
end

-- Sincroniza a lista de membros do radio com todos os participantes do canal
local function syncRadioChannel(frequency)
	if not frequency then return end
	local members = Routing.GetRadioMembers(frequency)
	for _, member in ipairs(members) do
		TriggerClientEvent('coe_talk:client:syncRadioMembers', member, frequency, members)
	end
end

-- Sincroniza participantes de uma chamada telefonica
local function syncCallChannel(callId)
	if not callId then return end
	local members = Routing.GetCallMembers(callId)
	for _, member in ipairs(members) do
		TriggerClientEvent('coe_talk:client:syncCallMembers', member, callId, members)
	end
end

-- Inicializacao dos canais espaciais de voz (FiveM Enhanced server-controlled channels)
CreateThread(function()
	local distances = {}
	if Config.Modes then
		for _, m in ipairs(Config.Modes) do
			distances[#distances + 1] = m.distance
		end
	end
	Routing.InitProximityChannels(distances)
end)

-- Evento: atualizar alcance ou estado de transmissao da voz do jogador
RegisterNetEvent('coe_talk:server:setVoiceRange', function(distance, active)
	local src = source
	if throttled(src, 'voice') then return end
	Routing.SetPlayerProximity(src, distance, active)
end)

-- Evento: entrar ou trocar frequencia de radio
RegisterNetEvent('coe_talk:server:setRadio', function(rawFrequency)
	local src = source
	if throttled(src, 'radio') then return end
	if rawFrequency == nil or rawFrequency == 0 or rawFrequency == '' then
		local _, prev = Routing.LeaveRadio(src)
		TriggerClientEvent('coe_talk:client:radioSet', src, nil)
		if prev then syncRadioChannel(prev) end
		notify(src, 'info', _t('radio_off'))
		return
	end

	local freq = Rules.SanitizeFrequency(rawFrequency)
	if not freq then
		notify(src, 'error', _t('radio_invalid_freq'))
		return
	end

	local job = getPlayerJob(src)
	if not Rules.CanAccessFrequency(freq, job) then
		notify(src, 'error', _t('radio_restricted'))
		return
	end

	local _, prev = Routing.LeaveRadio(src)
	if prev then syncRadioChannel(prev) end

	Routing.JoinRadio(src, freq)
	TriggerClientEvent('coe_talk:client:radioSet', src, freq)
	syncRadioChannel(freq)
	notify(src, 'success', _t('radio_connected', { freq = string.format('%.1f', freq) }))
end)

-- Evento: sair do radio
RegisterNetEvent('coe_talk:server:leaveRadio', function()
	local src = source
	local _, prev = Routing.LeaveRadio(src)
	TriggerClientEvent('coe_talk:client:radioSet', src, nil)
	if prev then syncRadioChannel(prev) end
end)

-- Evento: iniciou transmissao no radio (Push-to-Talk)
RegisterNetEvent('coe_talk:server:startRadioTransmitting', function()
	local src = source
	if throttled(src, 'transmit') then return end
	Routing.SetRadioTransmitting(src, true)
	local freq = Routing.GetRadio(src)
	if not freq then return end

	local members = Routing.GetRadioMembers(freq)
	for _, member in ipairs(members) do
		if member ~= src then
			TriggerClientEvent('coe_talk:client:radioTransmitting', member, src, true)
		end
	end
end)

-- Evento: parou transmissao no radio
RegisterNetEvent('coe_talk:server:stopRadioTransmitting', function()
	local src = source
	Routing.SetRadioTransmitting(src, false)
	local freq = Routing.GetRadio(src)
	if not freq then return end

	local members = Routing.GetRadioMembers(freq)
	for _, member in ipairs(members) do
		if member ~= src then
			TriggerClientEvent('coe_talk:client:radioTransmitting', member, src, false)
		end
	end
end)

-- Chamadas telefonicas: o client nao escolhe em qual chamada entra (isso permitiria ouvir chamadas alheias).
-- Quem coloca os dois lados na chamada e o coe_mobile, pelo export SetPlayerCall, depois de atender.

-- Evento: sair de chamada telefonica
RegisterNetEvent('coe_talk:server:leaveCall', function()
	local src = source
	local _, prev = Routing.LeaveCall(src)
	TriggerClientEvent('coe_talk:client:callSet', src, nil)
	if prev then syncCallChannel(prev) end
end)

-- Desconexao do jogador
AddEventHandler('playerDropped', function()
	local src = source
	local radio = Routing.GetRadio(src)
	local call = Routing.GetCall(src)
	Routing.RemovePlayer(src)
	lastEvent[src] = nil
	if radio then syncRadioChannel(radio) end
	if call then syncCallChannel(call) end
end)

-- Exports de Servidor
exports('SetPlayerRadio', function(source, frequency, extra)
	if type(source) == 'table' then
		source, frequency = frequency, extra
	end
	if not callerAllowed() then
		return false, 'forbidden'
	end
	if not validPlayer(source) then
		return false, 'invalid_player'
	end
	if frequency == nil or frequency == 0 then
		local _, prev = Routing.LeaveRadio(source)
		TriggerClientEvent('coe_talk:client:radioSet', source, nil)
		if prev then syncRadioChannel(prev) end
		return true
	end
	local freq = Rules.SanitizeFrequency(frequency)
	if not freq then return false end
	local _, prev = Routing.LeaveRadio(source)
	if prev then syncRadioChannel(prev) end
	Routing.JoinRadio(source, freq)
	TriggerClientEvent('coe_talk:client:radioSet', source, freq)
	syncRadioChannel(freq)
	return true
end)

exports('GetPlayerRadio', function(source, extra)
	if type(source) == 'table' then
		source = extra
	end
	return Routing.GetRadio(source)
end)

exports('SetPlayerCall', function(source, callId, extra)
	if type(source) == 'table' then
		source, callId = callId, extra
	end
	if not callerAllowed() then
		return false, 'forbidden'
	end
	if not validPlayer(source) then
		return false, 'invalid_player'
	end
	if callId ~= nil and not validCallId(callId) then
		return false, 'invalid_call'
	end
	if not callId then
		local _, prev = Routing.LeaveCall(source)
		TriggerClientEvent('coe_talk:client:callSet', source, nil)
		if prev then syncCallChannel(prev) end
		return true
	end
	local _, prev = Routing.LeaveCall(source)
	if prev then syncCallChannel(prev) end
	Routing.JoinCall(source, callId)
	TriggerClientEvent('coe_talk:client:callSet', source, callId)
	syncCallChannel(callId)
	return true
end)

exports('GetPlayerCall', function(source, extra)
	if type(source) == 'table' then
		source = extra
	end
	return Routing.GetCall(source)
end)

exports('GetRadioMembers', function(frequency)
	return Routing.GetRadioMembers(frequency)
end)

exports('GetCallMembers', function(callId)
	return Routing.GetCallMembers(callId)
end)
