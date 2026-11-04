local config = CoeMechanicConfig
local open = false
local shopId, vehicle, snapshot = nil, nil, nil
local TOGGLES = { turbo = 18, tyreSmoke = 20, xenon = 22 }
local MAX_EXTRA = 14

local function plateOf(entity)
	return (Core.Platform.Vehicles.GetPlate(entity) or ''):gsub('^%s+', ''):gsub('%s+$', '')
end

-- Estado visual antes das prévias, para restaurar ao sair sem alterar o veículo.
local function capture(entity)
	SetVehicleModKit(entity, 0)
	local state = { mods = {}, toggles = {}, colors = {}, neon = { sides = {} }, extras = {} }
	for modType = 0, 49 do
		if GetNumVehicleMods(entity, modType) > 0 and not config.Appearance.BlockedModTypes[modType] then
			state.mods[tostring(modType)] = GetVehicleMod(entity, modType)
		end
	end
	for key, modType in pairs(TOGGLES) do
		state.toggles[key] = IsToggleModOn(entity, modType)
	end
	local primary, secondary = GetVehicleColours(entity)
	state.colors.primary, state.colors.secondary = primary, secondary
	if GetIsVehiclePrimaryColourCustom(entity) then
		local r, g, b = GetVehicleCustomPrimaryColour(entity)
		state.colors.primaryRgb = { r, g, b }
	end
	if GetIsVehicleSecondaryColourCustom(entity) then
		local r, g, b = GetVehicleCustomSecondaryColour(entity)
		state.colors.secondaryRgb = { r, g, b }
	end
	state.tint = GetVehicleWindowTint(entity)
	state.wheelType = GetVehicleWheelType(entity)
	if GetVehicleLiveryCount(entity) > 0 then
		state.livery = GetVehicleLivery(entity)
	end
	for side = 0, 3 do
		state.neon.sides[side + 1] = IsVehicleNeonLightEnabled(entity, side)
	end
	local nr, ng, nb = GetVehicleNeonLightsColour(entity)
	state.neon.rgb = { nr, ng, nb }
	for id = 0, MAX_EXTRA do
		if DoesExtraExist(entity, id) then
			state.extras[tostring(id)] = IsVehicleExtraTurnedOn(entity, id)
		end
	end
	return state
end

local function restore()
	if vehicle and snapshot and Core.Platform.Entities.Exists(vehicle) then
		-- Cor personalizada só some com a chamada de limpeza; depois o snapshot reaplica a original.
		ClearVehicleCustomPrimaryColour(vehicle)
		ClearVehicleCustomSecondaryColour(vehicle)
		MechanicAppearanceApply(vehicle, snapshot)
	end
end

local function close()
	if not open then
		return
	end
	open = false
	restore()
	ShowroomCamera.Stop(false)
	SetNuiFocus(false, false)
	SendNUIMessage({ action = 'close' })
	if vehicle and Core.Platform.Entities.Exists(vehicle) then
		FreezeEntityPosition(vehicle, false)
	end
	vehicle, snapshot, shopId = nil, nil, nil
end


local function openShowroom(id, shop)
	local ped = PlayerPedId()
	local entity = GetVehiclePedIsIn(ped, false)
	if open or entity == 0 or GetPedInVehicleSeat(entity, -1) ~= ped then
		return
	end
	shopId, vehicle = id, entity
	snapshot = capture(entity)
	open = true
	FreezeEntityPosition(entity, true)
	ShowroomCamera.Start(entity, shop.showroom)
	SetNuiFocus(true, true)
	local model = GetDisplayNameFromVehicleModel(Core.Platform.Entities.GetModel(entity))
	SendNUIMessage({
		action = 'open',
		data = {
			shop = id,
			label = shop.label,
			plate = plateOf(entity),
			model = GetLabelText(model) ~= 'NULL' and GetLabelText(model) or model,
			options = exports.coe_mechanic:GetVehicleOptions(entity),
			current = snapshot
		}
	})
	TriggerServerEvent('coe_mechanic:syncOrder')
end

ShowroomCamera.OnFreeChanged(function(free)
	if not open then
		return
	end
	SetNuiFocus(not free, not free)
	SendNUIMessage({ action = 'freecam', data = free })
end)

MechanicShowroom = {
	IsOpen = function() return open end,
	Open = openShowroom
}

local shopBlips = {}

function MechanicRefreshBlips()
	for _, blip in ipairs(shopBlips) do
		RemoveBlip(blip)
	end
	shopBlips = {}
	for _, shop in pairs(config.Shops) do
		if shop.blip then
			local room = shop.showroom
			local blip = AddBlipForCoord(room.x, room.y, room.z)
			SetBlipSprite(blip, shop.blip.sprite)
			SetBlipColour(blip, shop.blip.colour)
			SetBlipAsShortRange(blip, true)
			BeginTextCommandSetBlipName('STRING')
			AddTextComponentSubstringPlayerName(shop.label)
			EndTextCommandSetBlipName(blip)
			shopBlips[#shopBlips + 1] = blip
		end
	end
end

CreateThread(MechanicRefreshBlips)

RegisterNUICallback('preview', function(data, cb)
	local wheels = 0
	if open and vehicle and type(data) == 'table' and type(data.patch) == 'table' then
		MechanicAppearanceApply(vehicle, data.patch)
		wheels = GetNumVehicleMods(vehicle, 23)
	end
	cb({ ok = true, wheels = wheels })
end)

RegisterNUICallback('camPreset', function(data, cb)
	cb({ ok = open and type(data) == 'table' and ShowroomCamera.Preset(tostring(data.name)) })
end)

RegisterNUICallback('camOrbit', function(data, cb)
	if open and type(data) == 'table' then
		ShowroomCamera.Orbit(tonumber(data.dx) or 0.0, tonumber(data.dy) or 0.0)
	end
	cb({ ok = true })
end)

RegisterNUICallback('camZoom', function(data, cb)
	if open and type(data) == 'table' then
		ShowroomCamera.Zoom(tonumber(data.direction) or 0)
	end
	cb({ ok = true })
end)

RegisterNUICallback('camAuto', function(data, cb)
	if open and type(data) == 'table' then
		ShowroomCamera.SetAuto(data.enabled == true)
	end
	cb({ ok = true })
end)

RegisterNUICallback('camFree', function(_, cb)
	if open then
		ShowroomCamera.SetFree(true)
	end
	cb({ ok = true })
end)

RegisterNUICallback('resetPreview', function(_, cb)
	restore()
	cb({ ok = true })
end)

RegisterNUICallback('estimate', function(data, cb)
	if open and type(data) == 'table' then
		TriggerServerEvent('coe_mechanic:requestEstimate', shopId, plateOf(vehicle), data.patch or {})
	end
	cb({ ok = true })
end)

RegisterNUICallback('request', function(data, cb)
	if open and type(data) == 'table' then
		TriggerServerEvent('coe_mechanic:requestOrder', shopId, plateOf(vehicle), data.patch or {})
	end
	cb({ ok = true })
end)

RegisterNUICallback('respond', function(data, cb)
	if type(data) == 'table' then
		TriggerServerEvent('coe_mechanic:respondOrder', tonumber(data.id), data.approve == true)
	end
	cb({ ok = true })
end)

RegisterNUICallback('cancel', function(data, cb)
	if type(data) == 'table' then
		TriggerServerEvent('coe_mechanic:cancelOrder', tonumber(data.id))
	end
	cb({ ok = true })
end)

RegisterNUICallback('closeShowroom', function(_, cb)
	close()
	cb({ ok = true })
end)

RegisterNetEvent('coe_mechanic:estimate', function(quote)
	SendNUIMessage({ action = 'estimate', data = quote })
end)

RegisterNetEvent('coe_mechanic:orderFailed', function(code)
	SendNUIMessage({ action = 'error', data = code })
end)

RegisterNetEvent('coe_mechanic:orderUpdated', function(order)
	SendNUIMessage({ action = 'order', data = order })
	if order and order.status == 'done' and open and vehicle then
		-- O serviço foi aplicado: a nova aparência passa a ser a base das próximas prévias.
		local entity = vehicle
		SetTimeout(800, function()
			if open and entity == vehicle and Core.Platform.Entities.Exists(entity) then
				snapshot = capture(entity)
			end
		end)
	end
end)

CreateThread(function()
	while true do
		if open then
			if not Core.Platform.Entities.Exists(vehicle) or GetVehiclePedIsIn(PlayerPedId(), false) ~= vehicle then
				close()
			end
			Wait(500)
		else
			Wait(1000)
		end
	end
end)

AddEventHandler('onResourceStop', function(resource)
	if resource == GetCurrentResourceName() and open then
		restore()
		ShowroomCamera.Stop(true)
		if vehicle and Core.Platform.Entities.Exists(vehicle) then
			FreezeEntityPosition(vehicle, false)
		end
		SetNuiFocus(false, false)
	end
end)
