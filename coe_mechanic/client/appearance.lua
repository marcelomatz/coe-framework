local TOGGLE_MODS = { turbo = 18, tyreSmoke = 20, xenon = 22 }
local NEON_SIDES = { 0, 1, 2, 3 }

local function applyColors(vehicle, colors)
	if colors.primary or colors.secondary then
		local primary, secondary = GetVehicleColours(vehicle)
		SetVehicleColours(vehicle, colors.primary or primary, colors.secondary or secondary)
	end
	if colors.pearl or colors.wheel then
		local pearl, wheel = GetVehicleExtraColours(vehicle)
		SetVehicleExtraColours(vehicle, colors.pearl or pearl, colors.wheel or wheel)
	end
	if colors.interior then
		SetVehicleInteriorColor(vehicle, colors.interior)
	end
	if colors.dashboard then
		SetVehicleDashboardColor(vehicle, colors.dashboard)
	end
	if colors.primaryRgb then
		SetVehicleCustomPrimaryColour(vehicle, colors.primaryRgb[1], colors.primaryRgb[2], colors.primaryRgb[3])
	end
	if colors.secondaryRgb then
		SetVehicleCustomSecondaryColour(vehicle, colors.secondaryRgb[1], colors.secondaryRgb[2], colors.secondaryRgb[3])
	end
end

-- Livery pode vir como livery nativa do modelo ou como mod 48; usa a que o modelo oferece.
local function applyLivery(vehicle, livery)
	if GetVehicleLiveryCount(vehicle) > 0 then
		SetVehicleLivery(vehicle, math.max(0, livery))
	end
	if GetNumVehicleMods(vehicle, 48) > 0 then
		SetVehicleMod(vehicle, 48, livery, false)
	end
end

local function apply(vehicle, data)
	if not Core.Platform.Entities.Exists(vehicle) or type(data) ~= 'table' then
		return
	end
	SetVehicleModKit(vehicle, 0)

	if data.wheelType then
		SetVehicleWheelType(vehicle, data.wheelType)
	end
	if data.colors then
		applyColors(vehicle, data.colors)
	end
	for key, index in pairs(data.mods or {}) do
		local modType = tonumber(key)
		if modType and (index < 0 or index < GetNumVehicleMods(vehicle, modType)) then
			SetVehicleMod(vehicle, modType, index, false)
		end
	end
	for key, enabled in pairs(data.toggles or {}) do
		if TOGGLE_MODS[key] then
			ToggleVehicleMod(vehicle, TOGGLE_MODS[key], enabled)
		end
	end
	if data.livery then
		applyLivery(vehicle, data.livery)
	end
	if data.tint then
		SetVehicleWindowTint(vehicle, data.tint)
	end
	if data.plateIndex then
		SetVehicleNumberPlateTextIndex(vehicle, data.plateIndex)
	end
	if data.xenonColor then
		SetVehicleXenonLightsColor(vehicle, data.xenonColor)
	end
	if data.neon then
		for index, side in ipairs(NEON_SIDES) do
			if data.neon.sides then
				SetVehicleNeonLightEnabled(vehicle, side, data.neon.sides[index] == true)
			end
		end
		if data.neon.rgb then
			SetVehicleNeonLightsColour(vehicle, data.neon.rgb[1], data.neon.rgb[2], data.neon.rgb[3])
		end
	end
	for key, enabled in pairs(data.extras or {}) do
		local id = tonumber(key)
		if id and DoesExtraExist(vehicle, id) then
			SetVehicleExtra(vehicle, id, not enabled)
		end
	end
end

AddStateBagChangeHandler('coe:appearance', nil, function(bagName, _, value)
	if type(value) ~= 'table' then
		return
	end
	local entity = GetEntityFromStateBagName(bagName)
	if entity ~= 0 then
		apply(entity, value)
	end
end)

-- Veículos que já estavam em streaming quando o resource iniciou.
CreateThread(function()
	for _, vehicle in ipairs(GetGamePool('CVehicle')) do
		local data = Entity(vehicle).state['coe:appearance']
		if data then
			apply(vehicle, data)
		end
	end
end)

-- Opções que o modelo suporta: quantidade por tipo de mod, liveries e extras.
local function optionsOf(vehicle)
	SetVehicleModKit(vehicle, 0)
	local mods = {}
	for modType = 0, 49 do
		local count = GetNumVehicleMods(vehicle, modType)
		if count > 0 and not CoeMechanicConfig.Appearance.BlockedModTypes[modType] then
			mods[tostring(modType)] = count
		end
	end
	local extras = {}
	for id = 0, 14 do
		if DoesExtraExist(vehicle, id) then
			extras[#extras + 1] = id
		end
	end
	return {
		mods = mods,
		liveryCount = GetVehicleLiveryCount(vehicle),
		liveryModCount = GetNumVehicleMods(vehicle, 48),
		extras = extras
	}
end

exports('GetVehicleOptions', function(vehicle)
	if not vehicle or not Core.Platform.Entities.Exists(vehicle) then
		return nil
	end
	return optionsOf(vehicle)
end)

MechanicAppearanceApply = apply

RegisterCommand('coe_appearance_options', function()
	local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
	if vehicle == 0 then
		return
	end
	print(json.encode(optionsOf(vehicle)))
end, false)
