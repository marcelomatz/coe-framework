-- coe_talk - Cliente Principal de Voz e Proximidade
local currentModeIndex = Config.DefaultModeIndex or 2
local isTalking = false
local pttPressed = false

local _t = function(key, params)
	if Core and Core.Locale and Core.Locale.New then
		return Core.Locale.New({ default = Core.Locale.GetDefaultLang(), locales = Locales or {} })(key, params)
	end
	if Locales and Locales['pt-BR'] and Locales['pt-BR'][key] then
		return Locales['pt-BR'][key]
	end
	return key
end

local function notify(kind, message)
	pcall(function()
		exports.coe_notify:Show(kind, message, 2000)
	end)
end

local function updateVoiceTransmission()
	local mode = Rules.GetModeByIndex(currentModeIndex, Config.Modes)
	local active = pttPressed or Config.VoiceActivation or (Radio and Radio.transmitting)
	local dist = active and mode.distance or 0.0

	-- Servidor gerencia os canais espaciais de voz (FiveM Enhanced server-controlled channels)
	TriggerServerEvent('coe_talk:server:setVoiceRange', mode.distance, active)

	pcall(function()
		if NetworkSetTalkerProximity then
			NetworkSetTalkerProximity(dist)
		end
	end)
end

local function applyMode(index)
	local mode = Rules.GetModeByIndex(index, Config.Modes)
	currentModeIndex = index

	updateVoiceTransmission()

	SendNUIMessage({
		action = 'mode',
		mode = mode.id,
		label = mode.label,
		distance = mode.distance,
		level = mode.level
	})

	TriggerEvent('coe_talk:client:mode', mode)

	return mode
end

local function voiceUp()
	local nextIndex, changed = Rules.IncreaseModeIndex(currentModeIndex, Config.Modes)
	if not changed then
		notify('info', _t('voice_max_range'))
		return
	end
	local mode = applyMode(nextIndex)
	pcall(function()
		PlaySoundFrontend(-1, 'NAV_UP_DOWN', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
	end)
	notify('info', _t('voice_increased', { mode = mode.label, dist = string.format('%.1f', mode.distance) }))
end

local function voiceDown()
	local nextIndex, changed = Rules.DecreaseModeIndex(currentModeIndex, Config.Modes)
	if not changed then
		notify('info', _t('voice_min_range'))
		return
	end
	local mode = applyMode(nextIndex)
	pcall(function()
		PlaySoundFrontend(-1, 'NAV_LEFT_RIGHT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
	end)
	notify('info', _t('voice_decreased', { mode = mode.label, dist = string.format('%.1f', mode.distance) }))
end

-- Keybind Push-To-Talk para falar no microfone (tecla padrao: N)
RegisterCommand('+talk', function()
	if Config.VoiceActivation then return end
	pttPressed = true
	updateVoiceTransmission()
	isTalking = true
	SendNUIMessage({ action = 'talking', talking = true })
	TriggerEvent('coe_talk:client:talking', true)
end, false)

RegisterCommand('-talk', function()
	if Config.VoiceActivation then return end
	pttPressed = false
	updateVoiceTransmission()
	isTalking = false
	SendNUIMessage({ action = 'talking', talking = false })
	TriggerEvent('coe_talk:client:talking', false)
end, false)

RegisterKeyMapping('+talk', 'Falar (Microfone)', 'keyboard', Config.Keybinds.talk or 'N')

-- Keybinds para subir e baixar o alcance da voz (padroes: PageUp e PageDown)
RegisterCommand('coe_talk:voiceUp', function()
	voiceUp()
end, false)

RegisterKeyMapping('coe_talk:voiceUp', 'Aumentar alcance da voz (Subir)', 'keyboard', Config.Keybinds.voiceUp or 'PAGEUP')

RegisterCommand('coe_talk:voiceDown', function()
	voiceDown()
end, false)

RegisterKeyMapping('coe_talk:voiceDown', 'Diminuir alcance da voz (Baixar)', 'keyboard', Config.Keybinds.voiceDown or 'PAGEDOWN')

-- Comandos no chat para conveniencia
RegisterCommand('subirvoz', function()
	voiceUp()
end, false)

RegisterCommand('baixarvoz', function()
	voiceDown()
end, false)

RegisterCommand('proximidade', function()
	voiceUp()
end, false)

RegisterCommand('voz', function()
	voiceUp()
end, false)

RegisterCommand('ptt', function()
	Config.VoiceActivation = not Config.VoiceActivation
	local msg = Config.VoiceActivation and _t('voice_activation_on') or _t('voice_activation_off')
	notify('info', msg)
	updateVoiceTransmission()
end, false)

-- Inicializacao da pilha nativa FiveM Enhanced
CreateThread(function()
	pcall(function()
		if NetworkSetVoiceActive then
			NetworkSetVoiceActive(true)
		end
	end)

	Submix.Init()
	applyMode(currentModeIndex)

	-- Loop de deteccao de transmissao de voz (para modo ativacao continua por voz)
	while true do
		if Config.VoiceActivation then
			local talking = false
			pcall(function()
				if NetworkIsPlayerTalking then
					talking = NetworkIsPlayerTalking(PlayerId()) and true or false
				end
			end)

			if talking ~= isTalking then
				isTalking = talking
				SendNUIMessage({ action = 'talking', talking = isTalking })
				TriggerEvent('coe_talk:client:talking', isTalking)
			end
		end

		Wait(Config.VoiceTickMs or 150)
	end
end)

-- Exports de Cliente
exports('GetVoiceRange', function()
	local mode = Rules.GetModeByIndex(currentModeIndex, Config.Modes)
	return mode.distance, mode.label, mode.id
end)

exports('SetVoiceRange', function(modeOrDistance, extra)
	if type(modeOrDistance) == 'table' then
		modeOrDistance = extra
	end
	if type(modeOrDistance) == 'number' then
		for i, m in ipairs(Config.Modes) do
			if m.distance == modeOrDistance then
				applyMode(i)
				return true
			end
		end
		-- Distancia customizada
		TriggerServerEvent('coe_talk:server:setVoiceRange', modeOrDistance, true)
		pcall(function()
			NetworkSetTalkerProximity(modeOrDistance)
		end)
		return true
	elseif type(modeOrDistance) == 'string' then
		for i, m in ipairs(Config.Modes) do
			if m.id == modeOrDistance then
				applyMode(i)
				return true
			end
		end
	end
	return false
end)

exports('GetRadioChannel', function()
	return Radio and Radio.frequency or nil
end)

exports('SetRadioChannel', function(frequency, extra)
	if type(frequency) == 'table' then
		frequency = extra
	end
	TriggerServerEvent('coe_talk:server:setRadio', frequency)
	return true
end)

exports('GetCallChannel', function()
	return Phone and Phone.callId or nil
end)

exports('SetCallChannel', function(callId, extra)
	if type(callId) == 'table' then
		callId = extra
	end
	TriggerServerEvent('coe_talk:server:setCall', callId)
	return true
end)

exports('IsTalking', function()
	return isTalking
end)

exports('IsRadioTransmitting', function()
	return Radio and Radio.transmitting or false
end)

exports('SetVoiceVolume', function(volume)
	if not volume then return false end
	local vol = math.max(0.0, math.min(1.0, (tonumber(volume) or 100) / 100.0))
	pcall(function()
		if MumbleSetVoiceVolume then
			MumbleSetVoiceVolume(vol)
		elseif MumbleSetVolumeWalkablePlayer then
			MumbleSetVolumeWalkablePlayer(PlayerId(), vol)
		end
	end)
	return true
end)

