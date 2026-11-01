-- Gravador de pistas: o piloto dirige o percurso marcando a largada e cada checkpoint; ao salvar, o servidor valida
-- tudo (espaçamento, quantidade, circuito fechado na largada) e grava a pista.
local config = RacesConfig
local Client = RacesClient
local T = Client.T

local recording = nil   -- { info, start, points, blips }

local function dist2d(a, b)
	local dx, dy = a.x - b.x, a.y - b.y
	return math.sqrt(dx * dx + dy * dy)
end

local function driverVehicle()
	local ped = PlayerPedId()
	local vehicle = GetVehiclePedIsIn(ped, false)
	if vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == ped then
		return vehicle
	end
	return nil
end

local function addBlip(point, number, start)
	local blip = AddBlipForCoord(point.x, point.y, point.z)
	SetBlipSprite(blip, start and 315 or 1)
	SetBlipColour(blip, start and 5 or 27)
	SetBlipScale(blip, 0.8)
	if number then
		ShowNumberOnBlip(blip, number)
	end
	return blip
end

local function clearBlips()
	if not recording then
		return
	end
	for _, blip in ipairs(recording.blips) do
		RemoveBlip(blip)
	end
	recording.blips = {}
end

local function redraw()
	clearBlips()
	if recording.start then
		recording.blips[#recording.blips + 1] = addBlip(recording.start, nil, true)
	end
	for index, point in ipairs(recording.points) do
		recording.blips[#recording.blips + 1] = addBlip(point, index, false)
	end
end

local function status()
	Client.Hud('record', {
		name = recording.info.name, kind = recording.info.kind, started = recording.start ~= nil, count = #recording.points,
		min = recording.info.minCheckpoints, max = recording.info.maxCheckpoints,
		keys = { mark = config.Recorder.MarkKey, undo = config.Recorder.UndoKey, save = config.Recorder.SaveKey, cancel = config.Recorder.CancelKey }
	})
end

local function stop()
	clearBlips()
	recording = nil
	Client.Hud('record', false)
end

RegisterNetEvent('coe_races:record', function(info)
	if type(info) ~= 'table' then
		return
	end
	Client.ClosePad()
	if recording then
		stop()
	end
	recording = { info = info, points = {}, blips = {} }
	status()
	Client.Notify('info', T('record_started'))
end)

local function mark()
	if not recording then
		return
	end
	local vehicle = driverVehicle()
	if not vehicle then
		Client.Notify('error', T('record_need_vehicle'))
		return
	end
	local at = GetEntityCoords(vehicle)
	local point = { x = at.x, y = at.y, z = at.z }
	if not recording.start then
		point.h = GetEntityHeading(vehicle)
		recording.start = point
		PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
	else
		local previous = recording.points[#recording.points] or recording.start
		if dist2d(previous, point) < (recording.info.minSpacing or config.Tracks.MinSpacing) then
			Client.Notify('error', T('record_too_close', { meters = math.floor(recording.info.minSpacing or config.Tracks.MinSpacing) }))
			return
		end
		if #recording.points >= (recording.info.maxCheckpoints or config.Tracks.MaxCheckpoints) then
			Client.Notify('error', T('record_full'))
			return
		end
		recording.points[#recording.points + 1] = point
		PlaySoundFrontend(-1, 'CHECKPOINT_NORMAL', 'HUD_MINI_GAME_SOUNDSET', true)
	end
	redraw()
	status()
end

local function undo()
	if not recording then
		return
	end
	if #recording.points > 0 then
		table.remove(recording.points)
	else
		recording.start = nil
	end
	redraw()
	status()
end

local saving = false
local function save()
	if not recording or saving then
		return
	end
	if not recording.start then
		Client.Notify('error', T('record_no_start'))
		return
	end
	saving = true
	local info = recording.info
	local result = Client.Request('saveTrack', {
		name = info.name, description = info.description, kind = info.kind, featured = info.featured == true,
		start = recording.start, checkpoints = recording.points
	})
	saving = false
	if result.ok then
		Client.Notify('success', T('record_saved', { track = info.name }))
		stop()
	else
		Client.Notify('error', T('err_' .. tostring(result.error)))
	end
end

local function cancel()
	if recording then
		stop()
		Client.Notify('info', T('record_cancelled'))
	end
end

local keys = config.Recorder
RegisterCommand('+coe_races_mark', mark, false)
RegisterCommand('-coe_races_mark', function() end, false)
RegisterKeyMapping('+coe_races_mark', T('key_mark'), 'keyboard', keys.MarkKey)
RegisterCommand('+coe_races_undo', undo, false)
RegisterCommand('-coe_races_undo', function() end, false)
RegisterKeyMapping('+coe_races_undo', T('key_undo'), 'keyboard', keys.UndoKey)
RegisterCommand('+coe_races_save', function() CreateThread(save) end, false)
RegisterCommand('-coe_races_save', function() end, false)
RegisterKeyMapping('+coe_races_save', T('key_save'), 'keyboard', keys.SaveKey)
RegisterCommand('+coe_races_cancel', cancel, false)
RegisterCommand('-coe_races_cancel', function() end, false)
RegisterKeyMapping('+coe_races_cancel', T('key_cancel'), 'keyboard', keys.CancelKey)

-- Marcadores no chão dos pontos já gravados (perto do piloto).
CreateThread(function()
	while true do
		if recording and (recording.start or #recording.points > 0) then
			local at = GetEntityCoords(PlayerPedId())
			local here = { x = at.x, y = at.y }
			local radius = recording.info.radius or config.Tracks.CheckpointRadius
			if recording.start and dist2d(recording.start, here) < 250 then
				DrawMarker(4, recording.start.x, recording.start.y, recording.start.z + 1.0, 0, 0, 0, 0, 0, 0, 3.0, 3.0, 3.0,
					255, 196, 0, 200, false, true, 2, false, nil, nil, false)
			end
			for _, point in ipairs(recording.points) do
				if dist2d(point, here) < 250 then
					DrawMarker(1, point.x, point.y, point.z - 1.0, 0, 0, 0, 0, 0, 0, radius * 2, radius * 2, 2.0,
						57, 255, 136, 90, false, false, 2, false, nil, nil, false)
				end
			end
			Wait(0)
		else
			Wait(500)
		end
	end
end)
