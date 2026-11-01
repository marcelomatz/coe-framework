-- Valores originais por modelo (hash), lidos uma vez antes da primeira alteração.
local baseByModel = {}
local appliedByEntity = {}

local function readBase(vehicle, model)
	local cached = baseByModel[model]
	if cached then
		return cached
	end
	cached = {}
	for field in pairs(HandlingEngine.FIELDS) do
		cached[field] = GetVehicleHandlingFloat(vehicle, 'CHandlingData', field)
	end
	baseByModel[model] = cached
	return cached
end

local function apply(vehicle, mods)
	if not DoesEntityExist(vehicle) or type(mods) ~= 'table' then
		return
	end
	local model = GetEntityModel(vehicle)
	local base = readBase(vehicle, model)
	for field, multiplier in pairs(mods) do
		if HandlingEngine.FIELDS[field] and type(multiplier) == 'number' and base[field] and base[field] ~= 0 then
			SetVehicleHandlingFloat(vehicle, 'CHandlingData', field, base[field] * multiplier)
		end
	end
	appliedByEntity[vehicle] = true
end

AddStateBagChangeHandler('coe:handling', nil, function(bagName, _, value)
	if type(value) ~= 'table' then
		return
	end
	local entity = GetEntityFromStateBagName(bagName)
	if entity == 0 then
		return
	end
	apply(entity, value)
end)

-- Veículos que já estavam em streaming quando o resource iniciou.
CreateThread(function()
	for _, vehicle in ipairs(GetGamePool('CVehicle')) do
		local mods = Entity(vehicle).state['coe:handling']
		if mods then
			apply(vehicle, mods)
		end
	end
end)

RegisterCommand('coe_handling_dump', function()
	local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
	if vehicle == 0 then
		return
	end
	local state = Entity(vehicle).state
	print(json.encode({ tyre = state['coe:tyre'], mods = state['coe:handling'] }))
	for field in pairs(HandlingEngine.FIELDS) do
		print(field, GetVehicleHandlingFloat(vehicle, 'CHandlingData', field))
	end
end, false)

AddEventHandler('onResourceStop', function(resourceName)
	if resourceName ~= GetCurrentResourceName() then
		return
	end
	for vehicle in pairs(appliedByEntity) do
		if DoesEntityExist(vehicle) then
			local base = baseByModel[GetEntityModel(vehicle)]
			for field, value in pairs(base or {}) do
				SetVehicleHandlingFloat(vehicle, 'CHandlingData', field, value)
			end
		end
	end
end)
