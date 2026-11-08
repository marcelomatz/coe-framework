local config = CoeTabletConfig
local isOpen = false
local pending = {}
local nextRequest = 0
local capturing = false
local PREFS_KEY = 'coe_tablet:prefs'

-- Preferências do aparelho (papel de parede, brilho, tamanho, dock), por jogador em KVP local.
local function loadPrefs()
	local raw = GetResourceKvpString(PREFS_KEY)
	local ok, decoded = pcall(function() return raw and json.decode(raw) or nil end)
	return TabletPrefs.Sanitize(ok and decoded or nil)
end

local function close()
	if not isOpen then
		return
	end
	isOpen = false
	SetNuiFocus(false, false)
	SendNUIMessage({ action = 'close' })
	TabletAnim.Stop()
	for id, p in pairs(pending) do
		pending[id] = nil
		p:resolve({ ok = false, error = 'closed' })
	end
end

local function requestOpen(shortcut)
	if isOpen or IsPedInAnyVehicle(PlayerPedId(), true) or IsPedDeadOrDying(PlayerPedId(), true) then
		print('[coe_tablet] abertura ignorada (ja aberto, em veiculo ou morto)')
		return
	end
	TriggerServerEvent('coe_tablet:open', shortcut)
end

-- Comandos de quem vem do tablet de trabalho básico (/trabalho) continuam abrindo o tablet.
for _, alias in ipairs(config.CommandAliases or {}) do
	RegisterCommand(alias, function()
		requestOpen()
	end, false)
end

RegisterCommand(config.Command, function()
	requestOpen()
end, false)

if config.OpenKey then
	RegisterCommand('+coe_tablet_open', function()
		requestOpen()
	end, false)
	RegisterCommand('-coe_tablet_open', function() end, false)
	RegisterKeyMapping('+coe_tablet_open', 'Abrir tablet (COE OS)', 'keyboard', config.OpenKey)
end

for command, shortcut in pairs(config.Shortcuts or {}) do
	if shortcut.command ~= false then
		RegisterCommand(command, function()
			requestOpen(command)
		end, false)
	end
end

-- Usar o item do tablet de negócios abre o tablet (o servidor confere o item e o ponto).
Core.Events.On('inventory.itemUsed', function(item)
	if type(item) == 'table' and item.name == config.BusinessTabletItem then
		requestOpen()
	end
end)

RegisterNetEvent('coe_tablet:opened', function(profile)
	if isOpen or type(profile) ~= 'table' then
		return
	end
	isOpen = true
	SetNuiFocus(true, true)
	TabletAnim.Start()
	profile.prefs = loadPrefs()
	SendNUIMessage({ action = 'open', data = profile })
end)

-- Lista de apps recalculada (ex.: app instalado pela loja) enquanto o tablet está aberto.
RegisterNetEvent('coe_tablet:profile', function(profile)
	if isOpen and type(profile) == 'table' then
		SendNUIMessage({ action = 'profile', data = profile })
	end
end)

-- Ponto batido ou encerrado em outro lugar com o app Ponto aberto: a tela recarrega.
RegisterNetEvent('coe_tablet:duty', function(businessId)
	if isOpen then
		SendNUIMessage({ action = 'duty', data = businessId })
	end
end)

RegisterNetEvent('coe_tablet:result', function(requestId, result)
	local p = pending[requestId]
	if p then
		pending[requestId] = nil
		p:resolve(result)
	end
end)

RegisterNUICallback('close', function(_, cb)
	close()
	cb({ ok = true })
end)

RegisterNUICallback('call', function(data, cb)
	if not isOpen or type(data) ~= 'table' then
		cb({ ok = false, error = 'closed' })
		return
	end
	nextRequest = nextRequest + 1
	local requestId = nextRequest
	local p = promise.new()
	pending[requestId] = p
	SetTimeout(15000, function()
		if pending[requestId] then
			pending[requestId] = nil
			p:resolve({ ok = false, error = 'timeout' })
		end
	end)
	TriggerServerEvent('coe_tablet:call', requestId, data.app, data.action, data.payload)
	cb(Citizen.Await(p))
end)

RegisterNUICallback('prefs', function(data, cb)
	local prefs = TabletPrefs.Sanitize(data)
	SetResourceKvp(PREFS_KEY, json.encode(prefs))
	cb({ ok = true, prefs = prefs })
end)

RegisterNUICallback('refresh', function(_, cb)
	if isOpen then
		TriggerServerEvent('coe_tablet:refresh')
	end
	cb({ ok = true })
end)

-- Câmera do aparelho (coe_apps): o tablet sai da tela enquanto o jogador fotografa e volta com a foto.
RegisterNUICallback('camera', function(_, cb)
	if not isOpen or capturing or GetResourceState('coe_apps') ~= 'started' then
		cb({ ok = false, error = 'camera_unavailable' })
		return
	end
	capturing = true
	SetNuiFocus(false, false)
	SendNUIMessage({ action = 'suspend', data = true })
	TabletAnim.Stop()
	local ok, result = pcall(function()
		return exports.coe_apps:TakePhoto()
	end)
	capturing = false
	if isOpen then
		TabletAnim.Start()
		SetNuiFocus(true, true)
	end
	SendNUIMessage({ action = 'suspend', data = false })
	cb(ok and type(result) == 'table' and result or { ok = false, error = 'camera_unavailable' })
end)

RegisterNUICallback('upload', function(data, cb)
	if not isOpen or type(data) ~= 'table' or type(data.image) ~= 'string' or GetResourceState('coe_apps') ~= 'started' then
		cb({ ok = false, error = 'app_unavailable' })
		return
	end
	local ok, result = pcall(function()
		return exports.coe_apps:StorePhoto(data.image)
	end)
	cb(ok and type(result) == 'table' and result or { ok = false, error = 'app_error' })
end)

-- Placa do veículo mais próximo, para os apps que trabalham sobre um veículo.
RegisterNUICallback('nearestVehicle', function(_, cb)
	local ped = PlayerPedId()
	local coords = Core.Platform.Entities.GetCoords(ped)
	local vehicle = GetClosestVehicle(coords.x, coords.y, coords.z, config.NearestVehicleRadius, 0, 71)
	if vehicle == 0 or not Core.Platform.Entities.Exists(vehicle) then
		cb({ ok = false, error = 'no_vehicle' })
		return
	end
	cb({ ok = true, plate = (Core.Platform.Vehicles.GetPlate(vehicle) or ''):gsub('^%s+', ''):gsub('%s+$', '') })
end)

-- Marca um ponto no GPS (apps que listam locais: estrutura, garagens).
RegisterNUICallback('waypoint', function(data, cb)
	local x, y = type(data) == 'table' and tonumber(data.x), type(data) == 'table' and tonumber(data.y)
	if not isOpen or not x or not y or math.abs(x) > 10000 or math.abs(y) > 10000 then
		cb({ ok = false })
		return
	end
	SetNewWaypoint(x, y)
	cb({ ok = true })
end)

CreateThread(function()
	while true do
		if isOpen then
			local ped = PlayerPedId()
			if IsPedInAnyVehicle(ped, true) or IsPedDeadOrDying(ped, true) then
				close()
			end
			Wait(500)
		else
			Wait(1000)
		end
	end
end)

AddEventHandler('onResourceStop', function(resource)
	if resource == GetCurrentResourceName() then
		if isOpen then
			SetNuiFocus(false, false)
		end
		TabletAnim.Stop()
	end
end)
