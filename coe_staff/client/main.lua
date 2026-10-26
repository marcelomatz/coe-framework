-- coe_staff (client): abre o painel (tecla ou comando, só com permissão), aplica no próprio personagem o que o
-- servidor autorizou (noclip, teleporte, curar...), recebe efeitos da staff (trazer, congelar, curar, reviver)
-- e mantém a hora e o clima definidos pela staff.
local config = StaffConfig

local isOpen = false
local modules = {}
local speeds = config.Noclip.Speeds
local pending = {}
local nextRequest = 0
local toggles = { invisible = false, godmode = false, coords = false }

local function send(message)
	SendNUIMessage(message)
end

local function yielded()
	return GlobalState.coeStaffYielded and GlobalState.coeStaffYielded ~= false
end

local function request(action, data)
	nextRequest = nextRequest + 1
	local requestId = nextRequest
	local p = promise.new()
	pending[requestId] = p
	local timeoutMs = (action == 'applyUpdate') and 300000 or 15000
	SetTimeout(timeoutMs, function()
		if pending[requestId] then
			pending[requestId] = nil
			p:resolve({ ok = false, error = 'timeout' })
		end
	end)
	TriggerServerEvent('coe_staff:request', requestId, action, data)
	return Citizen.Await(p)
end

RegisterNetEvent('coe_staff:response', function(requestId, result)
	local p = pending[requestId]
	if p then
		pending[requestId] = nil
		p:resolve(type(result) == 'table' and result or { ok = false })
	end
end)

-- Utilidades no mundo ----------------------------------------------------------------------------------------------

local function loadModel(hash)
	if not IsModelInCdimage(hash) or not IsModelValid(hash) then
		return false
	end
	RequestModel(hash)
	local deadline = GetGameTimer() + 5000
	while not HasModelLoaded(hash) and GetGameTimer() < deadline do
		Wait(0)
	end
	return HasModelLoaded(hash)
end

local function control(entity)
	local deadline = GetGameTimer() + 1500
	NetworkRequestControlOfEntity(entity)
	while not NetworkHasControlOfEntity(entity) and GetGameTimer() < deadline do
		Wait(0)
		NetworkRequestControlOfEntity(entity)
	end
	return NetworkHasControlOfEntity(entity)
end

-- Teleporte com tela escura; sem z (marcador), procura o chão de cima para baixo.
local function teleport(x, y, z, findGround)
	local ped = PlayerPedId()
	local vehicle = GetVehiclePedIsIn(ped, false)
	local entity = (vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == ped) and vehicle or ped
	DoScreenFadeOut(250)
	while not IsScreenFadedOut() do Wait(0) end
	FreezeEntityPosition(entity, true)
	local targetZ = z or 0.0
	if findGround then
		for height = 1000.0, 0.0, -25.0 do
			SetEntityCoordsNoOffset(entity, x, y, height, false, false, false)
			RequestCollisionAtCoord(x, y, height)
			Wait(20)
			local found, ground = GetGroundZFor_3dCoord(x, y, height, false)
			if found then
				targetZ = ground + 1.0
				break
			end
		end
	else
		RequestCollisionAtCoord(x, y, targetZ)
	end
	SetEntityCoordsNoOffset(entity, x, y, targetZ, false, false, false)
	Wait(150)
	FreezeEntityPosition(entity, false)
	DoScreenFadeIn(250)
end

local function waypoint()
	local blip = GetFirstBlipInfoId(8)
	if not DoesBlipExist(blip) then
		return nil
	end
	local at = GetBlipInfoIdCoord(blip)
	return { x = at.x, y = at.y }
end

local function nearestVehicle()
	local ped = PlayerPedId()
	local current = GetVehiclePedIsIn(ped, false)
	if current ~= 0 then
		return current
	end
	local at = GetEntityCoords(ped)
	local vehicle = GetClosestVehicle(at.x, at.y, at.z, 8.0, 0, 71)
	return vehicle ~= 0 and vehicle or nil
end

local function heal()
	local ped = PlayerPedId()
	SetEntityHealth(ped, GetEntityMaxHealth(ped))
	SetPedArmour(ped, 100)
	ClearPedBloodDamage(ped)
end

local function revive()
	local ped = PlayerPedId()
	local at = GetEntityCoords(ped)
	if IsEntityDead(ped) or IsPedDeadOrDying(ped, true) then
		NetworkResurrectLocalPlayer(at.x, at.y, at.z, GetEntityHeading(ped), true, false)
	end
	ped = PlayerPedId()
	ClearPedTasksImmediately(ped)
	heal()
	TriggerEvent('coe_staff:revived')
end

local function applyToggles()
	local ped = PlayerPedId()
	SetEntityVisible(ped, not toggles.invisible, false)
	SetEntityInvincible(ped, toggles.godmode)
end

-- Painel -----------------------------------------------------------------------------------------------------------

local function close()
	if not isOpen then
		return
	end
	isOpen = false
	SetNuiFocus(false, false)
	send({ action = 'close' })
end

local function requestOpen()
	if isOpen or yielded() then
		return
	end
	TriggerServerEvent('coe_staff:open')
end

RegisterCommand(config.Command, requestOpen, false)
if config.OpenKey then
	RegisterCommand('+coe_staff_open', requestOpen, false)
	RegisterCommand('-coe_staff_open', function() end, false)
	RegisterKeyMapping('+coe_staff_open', 'Abrir painel da staff', 'keyboard', config.OpenKey)
end

RegisterNetEvent('coe_staff:opened', function(payload)
	if isOpen or type(payload) ~= 'table' or yielded() then
		return
	end
	modules = payload.modules or {}
	speeds = payload.speeds or speeds
	isOpen = true
	SetNuiFocus(true, true)
	send({
		action = 'open',
		data = {
			modules = modules,
			limits = payload.limits,
			toggles = toggles,
			noclip = StaffNoclip.active,
			update = payload.update
		}
	})
end)

RegisterNetEvent('coe_staff:close', function()
	close()
	if StaffNoclip.active then
		StaffNoclip.Set(false, speeds)
	end
end)

-- /noclip: atalho sem abrir o painel (o servidor confere a permissão).
RegisterCommand('noclip', function()
	if yielded() then
		return
	end
	CreateThread(function()
		local on = not StaffNoclip.active
		local result = request('noclip', { on = on })
		if result.ok then
			StaffNoclip.Set(on, speeds)
			if not on then applyToggles() end
		end
	end)
end, false)

-- Efeitos pedidos pela staff (o servidor só manda para o jogador certo).
RegisterNetEvent('coe_staff:effect', function(kind, data)
	if kind == 'teleport' and type(data) == 'table' then
		teleport(data.x + 1.0, data.y, data.z, false)
	elseif kind == 'freeze' and type(data) == 'table' then
		local ped = PlayerPedId()
		FreezeEntityPosition(ped, data.on == true)
		local vehicle = GetVehiclePedIsIn(ped, false)
		if vehicle ~= 0 then FreezeEntityPosition(vehicle, data.on == true) end
	elseif kind == 'heal' then
		heal()
	elseif kind == 'revive' then
		revive()
	end
end)

-- Antes de enviar: ações sobre o veículo vão com o netId; o teleporte ao marcador precisa do marcador.
local PREPARE = {
	deleteVehicle = function(data)
		local vehicle = nearestVehicle()
		if not vehicle then return nil, 'no_vehicle' end
		data.netId = NetworkGetNetworkIdFromEntity(vehicle)
		return data
	end,
	tpWaypoint = function(data)
		local at = waypoint()
		if not at then return nil, 'no_waypoint' end
		data.x, data.y = at.x, at.y
		return data
	end
}

-- Depois da autorização: o que acontece no próprio personagem.
local APPLY = {
	noclip = function(data)
		StaffNoclip.Set(data.on == true, speeds)
		if data.on then close() else applyToggles() end
	end,
	invisible = function(data) toggles.invisible = data.on == true; applyToggles() end,
	godmode = function(data) toggles.godmode = data.on == true; applyToggles() end,
	heal = heal,
	revive = revive,
	tpWaypoint = function(data) teleport(data.x, data.y, nil, true) end,
	tpCoords = function(_, result) teleport(result.data.x, result.data.y, result.data.z, result.data.z == 0) end,
	gotoPlayer = function(_, result) teleport(result.data.x + 1.0, result.data.y, result.data.z, false) end,
	businessGoto = function(_, result) teleport(result.data.x, result.data.y, result.data.z, false) end,
	spawnVehicle = function(data, result)
		local ped = PlayerPedId()
		if result.data.netId then
			local deadline = GetGameTimer() + 5000
			while not NetworkDoesEntityExistWithNetworkId(result.data.netId) and GetGameTimer() < deadline do Wait(50) end
			local vehicle = NetToVeh(result.data.netId)
			if vehicle ~= 0 then TaskWarpPedIntoVehicle(ped, vehicle, -1) end
			return
		end
		local hash = joaat(result.data.model)
		if not loadModel(hash) then
			return 'invalid_model'
		end
		local current = GetVehiclePedIsIn(ped, false)
		if current ~= 0 and control(current) then
			SetEntityAsMissionEntity(current, true, true)
			DeleteVehicle(current)
		end
		local at = GetEntityCoords(ped)
		local vehicle = CreateVehicle(hash, at.x, at.y, at.z + 0.5, GetEntityHeading(ped), true, false)
		SetModelAsNoLongerNeeded(hash)
		SetVehicleOnGroundProperly(vehicle)
		SetVehicleNumberPlateText(vehicle, 'STAFF')
		SetVehicleFuelLevel(vehicle, 100.0)
		TaskWarpPedIntoVehicle(ped, vehicle, -1)
	end,
	vehicleFix = function(data)
		local vehicle = nearestVehicle()
		if not vehicle or not control(vehicle) then
			return 'no_vehicle'
		end
		if data.op == 'repair' then
			SetVehicleFixed(vehicle)
			SetVehicleDeformationFixed(vehicle)
			SetVehicleEngineHealth(vehicle, 1000.0)
			SetVehicleBodyHealth(vehicle, 1000.0)
			SetVehicleUndriveable(vehicle, false)
		elseif data.op == 'refuel' then
			SetVehicleFuelLevel(vehicle, 100.0)
		elseif data.op == 'clean' then
			SetVehicleDirtLevel(vehicle, 0.0)
			WashDecalsFromVehicle(vehicle, 1.0)
		elseif data.op == 'flip' then
			SetVehicleOnGroundProperly(vehicle)
		end
	end
}

RegisterNUICallback('close', function(_, cb)
	close()
	cb({ ok = true })
end)

RegisterNUICallback('action', function(body, cb)
	if not isOpen or type(body) ~= 'table' or type(body.action) ~= 'string' then
		return cb({ ok = false, error = 'closed' })
	end
	local action = body.action
	local data = type(body.data) == 'table' and body.data or {}
	if PREPARE[action] then
		local prepared, errorCode = PREPARE[action](data)
		if not prepared then
			return cb({ ok = false, error = errorCode })
		end
		data = prepared
	end
	local result = request(action, data)
	if result.ok and APPLY[action] then
		local applyError = APPLY[action](data, result)
		if type(applyError) == 'string' then
			result = { ok = false, error = applyError }
		end
	end
	cb(result)
end)

-- Coordenadas atuais (x, y, z, direção), para mostrar e copiar.
RegisterNUICallback('coords', function(_, cb)
	local ped = PlayerPedId()
	local at = GetEntityCoords(ped)
	cb({ ok = modules.self == true, x = at.x, y = at.y, z = at.z, h = GetEntityHeading(ped) })
end)

RegisterNUICallback('showCoords', function(body, cb)
	toggles.coords = modules.self == true and type(body) == 'table' and body.on == true
	cb({ ok = true })
end)

CreateThread(function()
	while true do
		if toggles.coords then
			local ped = PlayerPedId()
			local at = GetEntityCoords(ped)
			SetTextFont(4)
			SetTextScale(0.0, 0.38)
			SetTextOutline()
			SetTextColour(255, 255, 255, 230)
			BeginTextCommandDisplayText('STRING')
			AddTextComponentSubstringPlayerName(('x %.2f  y %.2f  z %.2f  h %.1f'):format(at.x, at.y, at.z, GetEntityHeading(ped)))
			EndTextCommandDisplayText(0.40, 0.012)
			Wait(0)
		else
			Wait(500)
		end
	end
end)

-- Hora e clima da staff (para todos) ----------------------------------------------------------------------------

local appliedVersion = nil
local overriding = false

local function applyWorld(world)
	if type(world) ~= 'table' then
		if overriding then
			ClearOverrideWeather()
			ClearWeatherTypePersist()
			NetworkClearClockTimeOverride()
			overriding = false
			appliedVersion = nil
		end
		return
	end
	overriding = true
	if world.weather then
		SetWeatherTypeOvertimePersist(world.weather, appliedVersion == world.version and 0.0 or 15.0)
		SetOverrideWeather(world.weather)
	else
		ClearOverrideWeather()
		ClearWeatherTypePersist()
	end
	if world.time then
		if world.time.freeze or appliedVersion ~= world.version then
			NetworkOverrideClockTime(world.time.hour, world.time.minute, 0)
		end
	else
		NetworkClearClockTimeOverride()
	end
	appliedVersion = world.version
end

AddStateBagChangeHandler('coeStaffWorld', 'global', function(_, _, value)
	applyWorld(value)
end)

CreateThread(function()
	while true do
		local world = GlobalState.coeStaffWorld
		if type(world) == 'table' and world.time and world.time.freeze then
			NetworkOverrideClockTime(world.time.hour, world.time.minute, 0)
		end
		Wait(2000)
	end
end)

CreateThread(function()
	Wait(2000)
	applyWorld(GlobalState.coeStaffWorld)
end)

AddStateBagChangeHandler('coeStaffYielded', 'global', function(_, _, value)
	if value then
		close()
		if StaffNoclip.active then StaffNoclip.Set(false, speeds) end
	end
end)

AddEventHandler('onResourceStop', function(resourceName)
	if resourceName ~= GetCurrentResourceName() then
		return
	end
	if StaffNoclip.active then
		StaffNoclip.Set(false, speeds)
	end
	if isOpen then
		SetNuiFocus(false, false)
	end
	if overriding then
		ClearOverrideWeather()
		NetworkClearClockTimeOverride()
	end
end)
