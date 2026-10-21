local config = CoeVehiclesConfig
local _t_inst = (Core and Core.Locale and Core.Locale.New) and Core.Locale.New({
	default = (config and config.Locale) or (Core and Core.Locale and Core.Locale.GetDefaultLang()) or 'pt-BR',
	locales = Locales or {}
})
local _t = function(k, params)
	if type(_t_inst) == 'table' then
		if _t_inst.T then
			return _t_inst:T(k, params)
		end
		local lang = _t_inst.lang or 'pt-BR'
		local dict = (_t_inst.locales and _t_inst.locales[lang]) or (Locales and Locales[lang]) or (Locales and Locales['pt-BR'])
		if dict and dict[k] then
			return dict[k]
		end
	elseif type(_t_inst) == 'function' then
		return _t_inst(k, params)
	end
	return (Locales and Locales['pt-BR'] and Locales['pt-BR'][k]) or k
end
local CHECK_INTERVAL_MS = 250
local IDLE_INTERVAL_MS = 1000
local RETRY_MS = 1500

local currentNetId = nil
local hasKey = nil
local requestedAt = 0
local warned = false

-- A decisão vem do servidor; sem a resposta (ou sem chave) o veículo fica inoperante para este jogador.
RegisterNetEvent('coe_vehicles:keyResult', function(netId, allowed)
	if netId == currentNetId then
		hasKey = allowed == true
	end
end)

RegisterNetEvent('coe_vehicles:keysChanged', function()
	hasKey = nil
	requestedAt = 0
	warned = false
end)

local function restore(vehicle)
	if vehicle and vehicle ~= 0 and Core.Platform.Entities.Exists(vehicle) then
		SetVehicleUndriveable(vehicle, false)
	end
end

CreateThread(function()
	local vehicle = 0
	while true do
		local ped = PlayerPedId()
		local candidate = GetVehiclePedIsIn(ped, false)
		local registered = candidate ~= 0
			and GetPedInVehicleSeat(candidate, -1) == ped
			and Core.Platform.Entities.GetState(candidate, 'coe:vehicleId') ~= nil

		if not registered then
			if vehicle ~= 0 then
				restore(vehicle)
				vehicle, currentNetId, hasKey, warned = 0, nil, nil, false
			end
			Wait(IDLE_INTERVAL_MS)
		else
			if candidate ~= vehicle then
				restore(vehicle)
				vehicle = candidate
				currentNetId = Core.Platform.Entities.GetNetworkId(vehicle)
				hasKey, requestedAt, warned = nil, 0, false
			end

			if hasKey == nil then
				SetVehicleUndriveable(vehicle, true)
				SetVehicleEngineOn(vehicle, false, true, true)
				local now = GetGameTimer()
				if now - requestedAt >= RETRY_MS then
					requestedAt = now
					TriggerServerEvent('coe_vehicles:checkKey', currentNetId)
				end
			elseif hasKey then
				SetVehicleUndriveable(vehicle, false)
			else
				SetVehicleUndriveable(vehicle, true)
				SetVehicleEngineOn(vehicle, false, true, true)
				if not warned then
					warned = true
					pcall(function()
						exports.coe_notify:Show('error', _t('no_key_warning'))
					end)
				end
			end
			Wait(CHECK_INTERVAL_MS)
		end
	end
end)
