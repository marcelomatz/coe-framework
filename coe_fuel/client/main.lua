-- coe_fuel (client): blips dos postos, bombas (alvo "Abastecer"), consumo do veículo do motorista (reportado ao
-- servidor), nível de combustível nativo (o HUD lê GetVehicleFuelLevel) e galão. O tanque é do servidor.
local config = FuelConfig
local catalog = assert(FuelRules.Catalog(config, function(name) return joaat(name) end))

local blips = {}
local pending = {}
local nextRequest = 0
local ui = nil          -- { station, vehicle }
local busy = false

local function request(action, payload)
	nextRequest = nextRequest + 1
	local requestId = nextRequest
	local p = promise.new()
	pending[requestId] = p
	SetTimeout(20000, function()
		if pending[requestId] then
			pending[requestId] = nil
			p:resolve({ ok = false, error = 'timeout' })
		end
	end)
	TriggerServerEvent('coe_fuel:request', requestId, action, payload)
	return Citizen.Await(p)
end

RegisterNetEvent('coe_fuel:response', function(requestId, result)
	local p = pending[requestId]
	if p then
		pending[requestId] = nil
		p:resolve(type(result) == 'table' and result or { ok = false })
	end
end)

local _t = function(key, params)
	if Core and Core.Locale and Core.Locale.New then
		return Core.Locale.New({ default = Core.Locale.GetDefaultLang(), locales = Locales or {} })(key, params)
	end
	if Locales and Locales['pt-BR'] and Locales['pt-BR'][key] then
		return Locales['pt-BR'][key]
	end
	return key
end

local function show(kind, message)
	pcall(function() exports.coe_notify:Show(kind, message, 4500) end)
end

local ERRORS = {
	too_far = _t('err_too_far'),
	not_ready = _t('err_not_ready'),
	station_closed = _t('err_station_closed'),
	busy = _t('err_busy'),
	no_vehicle = _t('err_no_vehicle'),
	wrong_fuel = _t('err_wrong_fuel'),
	tank_full = _t('err_tank_full'),
	no_tank = _t('err_no_tank'),
	can_empty = _t('err_can_empty'),
	no_can = _t('err_no_can'),
	timeout = _t('err_timeout'),
	no_character = _t('err_no_character'),
	not_fleet = _t('err_not_fleet'),
	not_at_refinery = _t('err_not_at_refinery'),
	not_at_station = _t('err_not_at_station'),
	empty_cargo = _t('err_empty_cargo'),
	tanks_full = _t('err_tanks_full'),
	forbidden = _t('err_forbidden')
}

-- Blips ------------------------------------------------------------------------------------------------------

local function paintBlips()
	for _, station in ipairs(catalog.stations) do
		local brand = config.Brands[station.brand]
		local blip = AddBlipForCoord(station.x, station.y, station.z)
		SetBlipSprite(blip, config.BlipSprite)
		SetBlipColour(blip, brand.color)
		SetBlipDisplay(blip, 4)
		SetBlipScale(blip, 0.75)
		SetBlipAsShortRange(blip, true)
		BeginTextCommandSetBlipName('STRING')
		AddTextComponentSubstringPlayerName(station.brand == 'none' and 'Posto sem bandeira' or ('Posto ' .. brand.label))
		EndTextCommandSetBlipName(blip)
		blips[#blips + 1] = blip
	end
	local r = config.Refinery
	local blip = AddBlipForCoord(r.center[1], r.center[2], r.center[3])
	SetBlipSprite(blip, r.blip.sprite)
	SetBlipColour(blip, r.blip.color)
	SetBlipDisplay(blip, 4)
	SetBlipScale(blip, 0.85)
	SetBlipAsShortRange(blip, true)
	BeginTextCommandSetBlipName('STRING')
	AddTextComponentSubstringPlayerName(r.label)
	EndTextCommandSetBlipName(blip)
	blips[#blips + 1] = blip
end

-- Veículo e consumo ----------------------------------------------------------------------------------------------

local function fuelState(vehicle)
	return vehicle ~= 0 and Core.Platform.Entities.Exists(vehicle) and Core.Platform.Entities.GetState(vehicle, 'coe:fuel') or nil
end

local function applyLevel(vehicle, state)
	if type(state) ~= 'table' or state.engine == 'none' then
		return
	end
	SetVehicleFuelLevel(vehicle, (tonumber(state.level) or 0) * 100.0)
end

-- Veículo sendo abastecido: o nível sobe junto com o mostrador (o state bag já chegou cheio).
local filling = {}

AddStateBagChangeHandler('coe:fuel', nil, function(bagName, _, value)
	local entity = GetEntityFromStateBagName(bagName)
	if entity ~= 0 and not filling[entity] then
		applyLevel(entity, value)
	end
end)

local current = { vehicle = 0, meters = 0, seconds = 0, rpm = 0, samples = 0, last = nil, since = 0, asked = nil }

local function resetTrip(vehicle)
	current.vehicle = vehicle
	current.meters, current.seconds, current.rpm, current.samples = 0, 0, 0, 0
	current.last = vehicle ~= 0 and Core.Platform.Entities.GetCoords(vehicle) or nil
	current.since = GetGameTimer()
	current.asked = nil
end

local function report(vehicle)
	if current.seconds <= 0 and current.meters <= 0 then
		return
	end
	local load = current.samples > 0 and current.rpm / current.samples or 0
	local netId = Core.Platform.Entities.GetNetworkId(vehicle) or VehToNet(vehicle)
	TriggerServerEvent('coe_fuel:report', netId, current.meters, current.seconds, load)
	current.meters, current.seconds, current.rpm, current.samples = 0, 0, 0, 0
	current.since = GetGameTimer()
end

CreateThread(function()
	paintBlips()
	while true do
		local ped = PlayerPedId()
		local vehicle = GetVehiclePedIsIn(ped, false)
		local driving = vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == ped and NetworkGetEntityIsNetworked(vehicle)
		if not driving then
			if current.vehicle ~= 0 and Core.Platform.Entities.Exists(current.vehicle) then
				report(current.vehicle)
			end
			if current.vehicle ~= 0 then
				resetTrip(0)
			end
			Wait(1000)
		else
			if vehicle ~= current.vehicle then
				if current.vehicle ~= 0 and Core.Platform.Entities.Exists(current.vehicle) then
					report(current.vehicle)
				end
				resetTrip(vehicle)
			end
			local state = fuelState(vehicle)
			-- Pede o tanque ao servidor (de novo a cada 5 s até chegar).
			if not state and (current.asked == nil or GetGameTimer() - current.asked > 5000) then
				current.asked = GetGameTimer()
				local netId = Core.Platform.Entities.GetNetworkId(vehicle) or VehToNet(vehicle)
				TriggerServerEvent('coe_fuel:init', netId, GetVehicleClass(vehicle), Core.Platform.Entities.GetModel(vehicle))
			end
			if state and state.engine ~= 'none' then
				applyLevel(vehicle, state)
				if (tonumber(state.liters) or 0) <= 0 then
					SetVehicleEngineOn(vehicle, false, true, true)
				end
				local position = Core.Platform.Entities.GetCoords(vehicle)
				if current.last and position then
					local step = #(position - current.last)
					if step < 60.0 then
						current.meters = current.meters + step
					end
				end
				current.last = position
				if Core.Platform.Vehicles.IsEngineRunning(vehicle) then
					current.seconds = current.seconds + 0.5
					current.rpm = current.rpm + GetVehicleCurrentRpm(vehicle)
					current.samples = current.samples + 1
				end
				if GetGameTimer() - current.since >= config.ReportSeconds * 1000 then
					report(vehicle)
				end
			end
			Wait(500)
		end
	end
end)

-- Animações ------------------------------------------------------------------------------------------------------

local function loadDict(dict)
	RequestAnimDict(dict)
	local deadline = GetGameTimer() + 3000
	while not HasAnimDictLoaded(dict) and GetGameTimer() < deadline do
		Wait(25)
	end
	return HasAnimDictLoaded(dict)
end

local function loadModel(name)
	local hash = joaat(name)
	if not IsModelInCdimage(hash) then
		return nil
	end
	RequestModel(hash)
	local deadline = GetGameTimer() + 3000
	while not HasModelLoaded(hash) and GetGameTimer() < deadline do
		Wait(25)
	end
	return HasModelLoaded(hash) and hash or nil
end

-- Abastecimento: bico na mão (bomba) ou galão (despejar) e o mostrador na tela contando os litros. O tempo é
-- proporcional aos litros (vazão da bomba ou do galão). O combustível já entrou no servidor; o nível nativo do
-- veículo sobe junto com o mostrador.
-- fill: { seconds, liters, nozzle, face, vehicle, fromLevel, fuel, price, total, brand, title }
local function playFill(fill)
	local ped = PlayerPedId()
	local seconds = math.max(1.0, tonumber(fill.seconds) or 1.0)
	if fill.face and fill.face ~= 0 and Core.Platform.Entities.Exists(fill.face) then
		TaskTurnPedToFaceEntity(ped, fill.face, 800)
		Wait(800)
	end
	local prop
	if fill.nozzle then
		local hash = loadModel(config.NozzleModel)
		if hash then
			local coords = Core.Platform.Entities.GetCoords(ped)
			if coords then
				prop = CreateObject(hash, coords.x, coords.y, coords.z, false, false, false)
				AttachEntityToEntity(prop, ped, GetPedBoneIndex(ped, 60309), 0.055, 0.05, 0.0, -50.0, -90.0, -50.0, true, true, false, true, 1, true)
				SetModelAsNoLongerNeeded(hash)
			end
		end
	end
	local dict, anim = 'timetable@gardener@filling_can', 'gar_ig_5_filling_can'
	if not fill.nozzle then
		dict, anim = 'weapon@w_sp_jerrycan', 'fire'
	end
	if loadDict(dict) then
		TaskPlayAnim(ped, dict, anim, 2.0, 2.0, -1, 1, 0, false, false, false)
	end
	local fuel = config.Fuels[fill.fuel or ''] or {}
	local brand = config.Brands[fill.brand or 'none'] or config.Brands.none
	SendNUIMessage({
		action = 'meter',
		data = {
			title = fill.title, brand = fill.brand or 'none', brandLabel = brand.label, theme = brand.theme,
			fuel = fuel.label, color = fuel.color, liters = fill.liters or 0, price = fill.price, total = fill.total, seconds = seconds
		}
	})
	local vehicle = fill.vehicle
	local target = vehicle and fuelState(vehicle)
	local toLevel = target and tonumber(target.level) or nil
	local fromLevel = tonumber(fill.fromLevel)
	if vehicle and toLevel and fromLevel then
		filling[vehicle] = true
	end
	local started = GetGameTimer()
	while true do
		local progress = math.min(1.0, (GetGameTimer() - started) / (seconds * 1000))
		if filling[vehicle or 0] and Core.Platform.Entities.Exists(vehicle) then
			SetVehicleFuelLevel(vehicle, (fromLevel + (toLevel - fromLevel) * progress) * 100.0)
		end
		if progress >= 1.0 then
			break
		end
		Wait(100)
	end
	if vehicle then
		filling[vehicle] = nil
		if Core.Platform.Entities.Exists(vehicle) then
			applyLevel(vehicle, fuelState(vehicle))
		end
	end
	Wait(600)
	SendNUIMessage({ action = 'meterEnd' })
	ClearPedTasks(ped)
	if prop and Core.Platform.Entities.Exists(prop) then
		Core.Platform.Entities.Delete(prop)
	end
	RemoveAnimDict(dict)
end

-- Bomba ---------------------------------------------------------------------------------------------------------

local function nearestVehicle(radius)
	local ped = PlayerPedId()
	local coords = Core.Platform.Entities.GetCoords(ped)
	if not coords then return 0 end
	local best, bestDistance = 0, radius
	local last = GetVehiclePedIsIn(ped, true)
	if last ~= 0 and Core.Platform.Entities.Exists(last) then
		local lastCoords = Core.Platform.Entities.GetCoords(last)
		if lastCoords and #(lastCoords - coords) <= radius then
			return last
		end
	end
	for _, vehicle in ipairs(GetGamePool('CVehicle')) do
		local vehicleCoords = Core.Platform.Entities.GetCoords(vehicle)
		if vehicleCoords then
			local d = #(vehicleCoords - coords)
			if d < bestDistance then
				best, bestDistance = vehicle, d
			end
		end
	end
	return best
end

local function vehiclePayload(payload, vehicle)
	if vehicle ~= 0 and NetworkGetEntityIsNetworked(vehicle) then
		payload.netId = Core.Platform.Entities.GetNetworkId(vehicle) or VehToNet(vehicle)
		payload.classId = GetVehicleClass(vehicle)
		payload.modelHash = Core.Platform.Entities.GetModel(vehicle)
	end
	return payload
end

local function stationHere()
	local coords = Core.Platform.Entities.GetCoords(PlayerPedId())
	if not coords then return nil end
	return FuelRules.StationAt(catalog, coords.x, coords.y, coords.z)
end

local function closeUi()
	if not ui then
		return
	end
	ui = nil
	SetNuiFocus(false, false)
	SendNUIMessage({ action = 'close' })
end

local function openPump()
	if ui or busy then
		return
	end
	local station = stationHere()
	if not station then
		show('error', 'Esta bomba não pertence a um posto.')
		return
	end
	local vehicle = nearestVehicle(config.VehicleRadius)
	local result = request('open', vehiclePayload({ stationId = station.id }, vehicle))
	if not result.ok then
		show('error', ERRORS[result.error] or 'Não foi possível usar a bomba.')
		return
	end
	ui = { station = station, vehicle = vehicle }
	SendNUIMessage({ action = 'open', view = result.view })
	SetNuiFocus(true, true)
end

CreateThread(function()
	local option = {
		{
			label = 'Abastecer',
			distance = 2.5,
			canInteract = function() return ui == nil and not busy and not IsPedInAnyVehicle(PlayerPedId(), false) and stationHere() ~= nil end,
			onSelect = function() openPump() end
		}
	}
	for _, name in ipairs(config.PumpModels) do
		pcall(function() exports.coetarget:AddTargetModel(name, option) end)
	end
end)

-- Fecha a bomba se o jogador se afastar.
CreateThread(function()
	while true do
		if ui then
			local coords = Core.Platform.Entities.GetCoords(PlayerPedId())
			local s = ui.station
			if coords and #(coords - vector3(s.x, s.y, s.z)) > s.radius + 3.0 then
				closeUi()
			end
		end
		Wait(1000)
	end
end)

-- Refinaria e descarga (frota de abastecimento dos postos) ---------------------------------------------------

local refineryUi = nil   -- { entity }
local targeted = {}       -- veículos da frota com alvo

local function atRefinery()
	local coords = Core.Platform.Entities.GetCoords(PlayerPedId())
	local r = config.Refinery
	return coords ~= nil and #(vector3(coords.x, coords.y, 0.0) - vector3(r.center[1], r.center[2], 0.0)) <= r.radius
end

local function cargoOf(entity)
	return Core.Platform.Entities.Exists(entity) and Core.Platform.Entities.GetState(entity, 'coe:fuelCargo') or nil
end

local function netIdOf(entity)
	return Core.Platform.Entities.GetNetworkId(entity) or VehToNet(entity)
end

local function closeRefinery()
	if not refineryUi then
		return
	end
	refineryUi = nil
	SetNuiFocus(false, false)
	SendNUIMessage({ action = 'refineryClose' })
end

local function openRefinery(entity)
	if refineryUi or ui or busy then
		return
	end
	local result = request('refinery', { netId = netIdOf(entity) })
	if not result.ok then
		show('error', ERRORS[result.error] or _t('err_load_failed'))
		return
	end
	refineryUi = { entity = entity }
	SendNUIMessage({ action = 'refinery', view = result.view })
	SetNuiFocus(true, true)
end

local function brandOfCargo(entity)
	local cargo = cargoOf(entity)
	local station = nil
	for _, entry in ipairs(catalog.stations) do
		if cargo and entry.business == cargo.business then
			station = entry
		end
	end
	return station and station.brand or 'none'
end

local function unloadAt(entity)
	if busy or ui or refineryUi then
		return
	end
	local result = request('unload', { netId = netIdOf(entity) })
	if not result.ok then
		show('error', ERRORS[result.error] or _t('err_unload_failed'))
		return
	end
	busy = true
	playFill({ seconds = result.seconds, liters = result.liters, nozzle = true, face = entity, brand = brandOfCargo(entity), title = _t('meter_unloading') })
	busy = false
	if (result.left or 0) > 0 then
		show('info', _t('unload_leftover', { liters = string.format('%.0f', result.left) }))
	end
end

local cargoOptions = {
	{
		label = _t('target_load'),
		distance = 3.0,
		canInteract = function() return not busy and not IsPedInAnyVehicle(PlayerPedId(), false) and atRefinery() end,
		onSelect = function(entity) openRefinery(entity) end
	},
	{
		label = _t('target_unload'),
		distance = 3.0,
		canInteract = function(entity)
			local cargo = cargoOf(entity)
			return not busy and cargo ~= nil and (cargo.liters or 0) > 0 and not IsPedInAnyVehicle(PlayerPedId(), false) and stationHere() ~= nil
		end,
		onSelect = function(entity) CreateThread(function() unloadAt(entity) end) end
	}
}

-- Alvo nos veículos da frota que estão por perto (state bag `coe:fuelCargo`).
CreateThread(function()
	while true do
		local coords = Core.Platform.Entities.GetCoords(PlayerPedId())
		for _, vehicle in ipairs(coords and GetGamePool('CVehicle') or {}) do
			local position = not targeted[vehicle] and Core.Platform.Entities.GetCoords(vehicle)
			if position and #(position - coords) < 80.0 and cargoOf(vehicle) then
				targeted[vehicle] = true
				pcall(function() exports.coetarget:AddTargetEntity(vehicle, cargoOptions) end)
			end
		end
		for vehicle in pairs(targeted) do
			if not Core.Platform.Entities.Exists(vehicle) then
				targeted[vehicle] = nil
			end
		end
		if refineryUi and (not Core.Platform.Entities.Exists(refineryUi.entity) or not atRefinery()) then
			closeRefinery()
		end
		Wait(2000)
	end
end)

RegisterNUICallback('refineryClose', function(_, cb)
	closeRefinery()
	cb({ ok = true })
end)

RegisterNUICallback('load', function(data, cb)
	if not refineryUi or type(data) ~= 'table' then
		return cb({ ok = false, error = 'closed' })
	end
	local entity = refineryUi.entity
	local result = request('load', { netId = netIdOf(entity), load = data.load })
	cb(result)
	if result.ok then
		closeRefinery()
		busy = true
		CreateThread(function()
			playFill({ seconds = result.seconds, liters = result.liters, nozzle = true, face = entity, brand = brandOfCargo(entity), title = _t('meter_loading') })
			busy = false
		end)
	end
end)

RegisterNUICallback('close', function(_, cb)
	closeUi()
	cb({ ok = true })
end)

-- Compra. Carteira: pede o total ao servidor, esconde a bomba e abre o pagamento no celular.
RegisterNUICallback('buy', function(data, cb)
	if not ui or type(data) ~= 'table' then
		return cb({ ok = false, error = 'closed' })
	end
	local payload = { stationId = ui.station.id, fuel = data.fuel, liters = data.liters, target = data.target, slot = data.slot }
	if data.target ~= 'can' then
		vehiclePayload(payload, ui.vehicle)
	end
	payload.payment = { method = data.method, cardId = data.cardId, pin = data.pin }
	if data.method == 'wallet' then
		if GetResourceState('coe_phone') ~= 'started' then
			return cb({ ok = false, error = 'phone_unavailable' })
		end
		local quote = request('quote', payload)
		if not quote.ok then
			return cb(quote)
		end
		SetNuiFocus(false, false)
		SendNUIMessage({ action = 'suspend', value = true })
		local ok, paid = pcall(function()
			return exports.coe_phone:RequestPayment({ amount = quote.total, label = quote.label, note = ('%.1f L'):format(quote.liters) })
		end)
		if ui then
			SendNUIMessage({ action = 'suspend', value = false })
			SetNuiFocus(true, true)
		end
		if not ok or type(paid) ~= 'table' or not paid.token then
			return cb({ ok = false, error = (ok and type(paid) == 'table' and paid.error) or 'cancelled' })
		end
		payload.payment = { method = 'wallet', token = paid.token }
	end
	local vehicle = data.target ~= 'can' and ui.vehicle ~= 0 and ui.vehicle or nil
	local before = vehicle and fuelState(vehicle)
	local result = request('buy', payload)
	cb(result)
	if result.ok and ui then
		local station = ui.station
		closeUi()
		busy = true
		CreateThread(function()
			playFill({
				seconds = result.seconds, liters = result.liters, nozzle = true, face = vehicle, vehicle = vehicle,
				fromLevel = before and before.level, fuel = result.fuel, price = result.price, total = result.total,
				brand = station.brand, title = result.target == 'can' and 'Enchendo o galão' or 'Abastecendo'
			})
			busy = false
		end)
	end
end)

-- Galão: usar no inventário despeja no veículo mais perto (a até 3,5 m).
local function useCan(item)
	if busy then
		return
	end
	local vehicle = nearestVehicle(3.5)
	if vehicle == 0 then
		show('error', 'Chegue perto do veículo para usar o galão.')
		return
	end
	local slot = type(item) == 'table' and math.tointeger(tonumber(item.slot)) or nil
	local before = fuelState(vehicle)
	local result = request('pour', vehiclePayload({ slot = slot }, vehicle))
	if not result.ok then
		show('error', ERRORS[result.error] or 'Não foi possível usar o galão.')
		return
	end
	busy = true
	playFill({
		seconds = result.seconds, liters = result.liters, nozzle = false, face = vehicle, vehicle = vehicle,
		fromLevel = before and before.level, fuel = result.fuel, title = 'Galão no tanque'
	})
	busy = false
end

Core.Events.OnNet('inventory.useItem', function(item)
	if type(item) == 'table' and item.name == config.Can.item then
		CreateThread(function() useCan(item) end)
	end
end)

-- Diagnóstico: tanque do veículo atual.
RegisterCommand('combustivel', function()
	local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
	local state = fuelState(vehicle)
	if not state then
		print('[coe_fuel] sem tanque (entre como motorista)')
		return
	end
	local parts = {}
	for _, id in ipairs(config.FuelOrder) do
		if (state.tank[id] or 0) > 0 then
			parts[#parts + 1] = ('%s %.1f L'):format(config.Fuels[id].short, state.tank[id])
		end
	end
	print(('[coe_fuel] %s | %.1f / %d L | %s'):format(state.engine, state.liters, state.capacity, table.concat(parts, ', ')))
end, false)

AddEventHandler('onResourceStop', function(resource)
	if resource ~= GetCurrentResourceName() then
		return
	end
	if ui or refineryUi then
		SetNuiFocus(false, false)
	end
	for vehicle in pairs(targeted) do
		pcall(function() exports.coetarget:RemoveTargetEntity(vehicle) end)
	end
	for _, blip in ipairs(blips) do
		RemoveBlip(blip)
	end
	for _, name in ipairs(config.PumpModels) do
		pcall(function() exports.coetarget:RemoveTargetModel(name) end)
	end
end)
