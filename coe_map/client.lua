local mode = 'mini'
local lastWaypoint = nil

local function scaleFor(current)
	return current == 'extended' and Config.ExtendedScale or 1.0
end

local function anchorFor(current)
	return MapAnchor.Compute(scaleFor(current), GetSafeZoneSize(), GetAspectRatio(false))
end

local function radarVisible()
	return not IsRadarHidden()
end

local function setMode(next)
	if next == mode then
		return
	end
	mode = next
	-- SetBigmapActive usa a animacao de expansao do proprio GTA; SetRadarBigmapEnabled troca de forma seca.
	SetBigmapActive(mode == 'extended', false)
	TriggerEvent('coe_map:changed', mode, scaleFor(mode))
	SendNUIMessage({ action = 'mode', mode = mode, anchor = anchorFor(mode), keys = Config.Keys })
	if mode ~= 'extended' then
		lastWaypoint = nil
		SendNUIMessage({ action = 'waypoint', active = false })
	end
end

local function readWaypoint()
	local blip = GetFirstBlipInfoId(Config.WaypointSprite)
	if not DoesBlipExist(blip) then
		return nil
	end
	local target = GetBlipInfoIdCoord(blip)
	local distance = MapAnchor.Distance(GetEntityCoords(PlayerPedId()), target)
	return math.floor(distance + 0.5)
end

local function pollWaypoint()
	CreateThread(function()
		while mode == 'extended' do
			local distance = readWaypoint()
			if distance ~= lastWaypoint then
				lastWaypoint = distance
				SendNUIMessage({ action = 'waypoint', active = distance ~= nil, distance = distance })
			end
			Wait(Config.WaypointIntervalMs)
		end
	end)
end

local function toggleExtended()
	if mode == 'extended' then
		setMode('mini')
		return
	end
	if not radarVisible() then
		return
	end
	setMode('extended')
	pollWaypoint()
end

-- Abre o mapa completo do GTA (aba Mapa); la o jogador marca o destino com Enter.
local function openFull()
	setMode('mini')
	CreateThread(function()
		ActivateFrontendMenu(GetHashKey('FE_MENU_VERSION_MP_PAUSE'), false, -1)
		Wait(100)
		PauseMenuceptionGoDeeper(0)
	end)
end

local function clearWaypoint()
	SetWaypointOff()
	lastWaypoint = nil
	SendNUIMessage({ action = 'waypoint', active = false })
end

local function bind(key, handler)
	RegisterCommand(key.command, handler, false)
	RegisterKeyMapping(key.command, key.label, 'keyboard', key.default)
end

bind(Config.Keys.extended, toggleExtended)
bind(Config.Keys.full, openFull)
bind(Config.Keys.clear, clearWaypoint)

-- /destino abre o mapa para marcar; /destino limpar remove o destino atual.
RegisterCommand('destino', function(_, args)
	if args[1] == 'limpar' then
		clearWaypoint()
	else
		openFull()
	end
end, false)

-- O Z nativo expande o radar por conta propria; o coe_map assume essa tecla.
CreateThread(function()
	while true do
		DisableControlAction(0, 20, true)
		Wait(0)
	end
end)

-- Zoom do radar a pe; em veiculo o proprio GTA ajusta pela velocidade.
CreateThread(function()
	while true do
		if Config.FootZoom and not IsPedInAnyVehicle(PlayerPedId(), false) then
			SetRadarZoom(Config.FootZoom)
		end
		Wait(250)
	end
end)

AddEventHandler('onResourceStop', function(resourceName)
	if resourceName == GetCurrentResourceName() then
		SetBigmapActive(false, false)
		TriggerEvent('coe_map:changed', 'mini', 1.0)
	end
end)

exports('GetMode', function()
	return mode
end)

exports('OpenFull', openFull)
