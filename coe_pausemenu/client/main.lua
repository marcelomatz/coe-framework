local isOpen = false

local function getLocalGameInfo()
	local hours = GetClockHours()
	local mins = GetClockMinutes()
	local timeStr = string.format('%02d:%02d', hours, mins)

	local ped = PlayerPedId()
	local coords = GetEntityCoords(ped)
	local heading = GetEntityHeading(ped)
	local streetHash, crossingHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
	local streetName = GetStreetNameFromHashKey(streetHash)
	local zoneName = GetLabelText(GetNameOfZone(coords.x, coords.y, coords.z))

	if not streetName or streetName == '' or streetName == 'NULL' then
		streetName = 'Los Santos'
	end

	local locationStr = streetName
	if zoneName and zoneName ~= 'NULL' and zoneName ~= '' then
		locationStr = ('%s, %s'):format(streetName, zoneName)
	end

	local blip = GetFirstBlipInfoId(8) -- 8 = Waypoint nativo
	local hasWaypoint = DoesBlipExist(blip)
	local wpCoords = nil
	if hasWaypoint then
		local bCoords = GetBlipInfoIdCoord(blip)
		wpCoords = { x = bCoords.x, y = bCoords.y }
	end

	return {
		clock = timeStr,
		location = locationStr,
		coords = { x = coords.x, y = coords.y, z = coords.z },
		heading = heading,
		waypoint = wpCoords
	}
end

local function setMenu(open)
	if isOpen == open then return end
	isOpen = open
	SetNuiFocus(open, open)

	if open then
		PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
		TriggerServerEvent('coe_pausemenu:server:requestData')
	else
		PlaySoundFrontend(-1, 'CANCEL', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
		SendNUIMessage({ action = 'close' })
	end
end

RegisterNetEvent('coe_pausemenu:client:receiveData', function(payload)
	if not isOpen then return end
	local localInfo = getLocalGameInfo()
	payload.server.gameTime = localInfo.clock
	payload.character.location = localInfo.location
	payload.character.coords = localInfo.coords
	payload.character.heading = localInfo.heading
	payload.waypoint = localInfo.waypoint

	SendNUIMessage({
		action = 'open',
		data = payload
	})
end)

-- Loop continuo de interceptacao absoluta do ESC / Menu de Pausa nativo
CreateThread(function()
	SetPauseMenuActive(false)
	while true do
		-- Nunca permite que o menu nativo do GTA V abra
		SetPauseMenuActive(false)
		DisableControlAction(0, 199, true) -- INPUT_FRONTEND_PAUSE (ESC)
		DisableControlAction(0, 200, true) -- INPUT_FRONTEND_PAUSE_ALTERNATE (P)

		if IsDisabledControlJustReleased(0, 199) or IsDisabledControlJustReleased(0, 200) then
			if not IsPedDeadOrDying(PlayerPedId(), true) then
				setMenu(not isOpen)
			end
		end
		Wait(0)
	end
end)

-- NUI Callbacks
RegisterNUICallback('close', function(_, cb)
	setMenu(false)
	cb({ ok = true })
end)

RegisterNUICallback('openHud', function(_, cb)
	setMenu(false)
	ExecuteCommand('hud')
	cb({ ok = true })
end)

RegisterNUICallback('setWaypoint', function(data, cb)
	if data and data.x and data.y then
		SetNewWaypoint(tonumber(data.x) + 0.0, tonumber(data.y) + 0.0)
		pcall(function()
			PlaySoundFrontend(-1, 'WAYPOINT_SET', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
		end)
	end
	cb({ ok = true })
end)

RegisterNUICallback('clearWaypoint', function(_, cb)
	SetWaypointOff()
	pcall(function()
		PlaySoundFrontend(-1, 'CANCEL', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
	end)
	cb({ ok = true })
end)

RegisterNUICallback('toggleMinimap', function(_, cb)
	pcall(function()
		ExecuteCommand('map')
	end)
	cb({ ok = true })
end)

RegisterNUICallback('saveSettings', function(data, cb)
	if data then
		SetResourceKvp('coe_pausemenu_settings', json.encode(data))
		if data.voiceVol then
			pcall(function()
				if exports.coe_talk and exports.coe_talk.SetVoiceVolume then
					exports.coe_talk:SetVoiceVolume(tonumber(data.voiceVol))
				end
			end)
		end
	end
	cb({ ok = true })
end)

RegisterNUICallback('getSettings', function(_, cb)
	local saved = GetResourceKvpString('coe_pausemenu_settings')
	local binds = GetResourceKvpString('coe_pausemenu_keybinds')
	cb({
		ok = true,
		settings = saved and json.decode(saved) or nil,
		keybinds = binds and json.decode(binds) or nil
	})
end)

RegisterNUICallback('updateKeybind', function(data, cb)
	if data and data.id and data.key then
		local currentBinds = GetResourceKvpString('coe_pausemenu_keybinds')
		local binds = currentBinds and json.decode(currentBinds) or {}
		binds[data.id] = data.key
		SetResourceKvp('coe_pausemenu_keybinds', json.encode(binds))
	end
	cb({ ok = true })
end)

RegisterNUICallback('resetSettings', function(_, cb)
	DeleteResourceKvp('coe_pausemenu_settings')
	DeleteResourceKvp('coe_pausemenu_keybinds')
	cb({ ok = true })
end)

RegisterNUICallback('disconnect', function(_, cb)
	setMenu(false)
	TriggerServerEvent('coe_pausemenu:server:disconnect')
	cb({ ok = true })
end)

exports('IsOpen', function() return isOpen end)
exports('Toggle', function(state)
	if state == nil then
		setMenu(not isOpen)
	else
		setMenu(state and true or false)
	end
end)
