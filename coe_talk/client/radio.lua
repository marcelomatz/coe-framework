-- coe_talk - Comunicacao via Radio Tatica
Radio = {
	frequency = nil,
	transmitting = false,
	members = {},
	volume = 80
}

local VOICE_TARGET_RADIO = 1

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
		exports.coe_notify:Show(kind, message, 2500)
	end)
end

function Radio.PlayClick(isOn)
	if not Config.Radio.clicks or not PlaySoundFrontend then return end
	pcall(function()
		if isOn then
			PlaySoundFrontend(-1, 'Click', 'DLC_HEIST_HACKING_SNAKE_SOUNDS', true)
		else
			PlaySoundFrontend(-1, 'Click_Fail', 'DLC_HEIST_HACKING_SNAKE_SOUNDS', true)
		end
	end)
end

function Radio.StartAnimation()
	if not Config.Radio.animation then return end
	local ped = PlayerPedId()
	if not DoesEntityExist(ped) or IsEntityDead(ped) then return end

	local dict = Config.Radio.animDict
	local name = Config.Radio.animName
	RequestAnimDict(dict)
	local timeout = GetGameTimer() + 500
	while not HasAnimDictLoaded(dict) and GetGameTimer() < timeout do
		Wait(10)
	end

	if HasAnimDictLoaded(dict) then
		TaskPlayAnim(ped, dict, name, 8.0, 2.0, -1, 50, 2.0, false, false, false)
	end
end

function Radio.StopAnimation()
	if not Config.Radio.animation then return end
	local ped = PlayerPedId()
	if DoesEntityExist(ped) then
		StopAnimTask(ped, Config.Radio.animDict, Config.Radio.animName, 2.5)
	end
end

function Radio.StartTransmitting()
	if not Radio.frequency or Radio.transmitting then return end
	Radio.transmitting = true
	Radio.PlayClick(true)
	Radio.StartAnimation()

	-- Aplica filtro de audio submix nos membros do radio
	pcall(function()
		for _, serverId in ipairs(Radio.members) do
			if serverId ~= GetPlayerServerId(PlayerId()) then
				Submix.ApplyRadio(serverId)
			end
		end
	end)

	TriggerServerEvent('coe_talk:server:startRadioTransmitting')
	SendNUIMessage({ action = 'radioTransmitting', transmitting = true })
end

function Radio.StopTransmitting()
	if not Radio.transmitting then return end
	Radio.transmitting = false
	Radio.PlayClick(false)
	Radio.StopAnimation()

	TriggerServerEvent('coe_talk:server:stopRadioTransmitting')
	SendNUIMessage({ action = 'radioTransmitting', transmitting = false })
end

-- Keybind do Push-to-Talk (+radioptt e -radioptt)
RegisterCommand('+radioptt', function()
	Radio.StartTransmitting()
end, false)

RegisterCommand('-radioptt', function()
	Radio.StopTransmitting()
end, false)

RegisterKeyMapping('+radioptt', 'Falar no Rádio', 'keyboard', Config.Keybinds.radioPtt or 'CAPITAL')

-- Comandos no chat
RegisterCommand('radio', function(_, args)
	if not args or not args[1] or args[1] == '0' or args[1] == 'off' then
		TriggerServerEvent('coe_talk:server:setRadio', nil)
		return
	end
	TriggerServerEvent('coe_talk:server:setRadio', args[1])
end, false)

RegisterCommand('radiodesligar', function()
	TriggerServerEvent('coe_talk:server:setRadio', nil)
end, false)

RegisterCommand('radiovolume', function(_, args)
	local vol = Rules.SanitizeVolume(args[1], Radio.volume)
	Radio.volume = vol
	pcall(function()
		if SetAudioSubmixOutputVolumes and Submix.radioId then
			SetAudioSubmixOutputVolumes(Submix.radioId, 0, vol / 100, vol / 100, 0.0, 0.0, 0.0, 0.0)
		end
	end)
	notify('info', _t('radio_volume', { vol = vol }))
end, false)

-- Eventos de sincronizacao vindos do servidor
RegisterNetEvent('coe_talk:client:radioSet', function(freq)
	Radio.frequency = freq
	if not freq and Radio.transmitting then
		Radio.StopTransmitting()
	end
	SendNUIMessage({ action = 'radioSet', frequency = freq })
end)

RegisterNetEvent('coe_talk:client:syncRadioMembers', function(freq, members)
	if Radio.frequency == freq then
		Radio.members = members or {}
	end
end)

RegisterNetEvent('coe_talk:client:radioTransmitting', function(senderServerId, transmitting)
	if transmitting then
		Radio.PlayClick(true)
		Submix.ApplyRadio(senderServerId)
	else
		Radio.PlayClick(false)
	end
end)
