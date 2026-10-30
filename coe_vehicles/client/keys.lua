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
-- A chave é um item: pode chegar (ou sair) com o jogador já sentado. Sem chave pergunta de novo a cada 3 s;
-- com chave, a cada 10 s.
local RECHECK_DENIED_MS = 3000
local RECHECK_ALLOWED_MS = 10000

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
			and (Core.Platform.Entities.GetState(candidate, 'coe:vehicleId') ~= nil
				or Core.Platform.Entities.GetState(candidate, 'coe:keyPlate') ~= nil)

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
				if GetGameTimer() - requestedAt >= RECHECK_ALLOWED_MS then
					requestedAt = GetGameTimer()
					TriggerServerEvent('coe_vehicles:checkKey', currentNetId)
				end
			else
				SetVehicleUndriveable(vehicle, true)
				SetVehicleEngineOn(vehicle, false, true, true)
				if not warned then
					warned = true
					pcall(function()
						exports.coe_notify:Show('error', _t('no_key_warning'))
					end)
				end
				if GetGameTimer() - requestedAt >= RECHECK_DENIED_MS then
					requestedAt = GetGameTimer()
					TriggerServerEvent('coe_vehicles:checkKey', currentNetId)
				end
			end
			Wait(CHECK_INTERVAL_MS)
		end
	end
end)

-- Trancar/destrancar (tecla configurável). O servidor escolhe o veículo, confere a chave (item) e tranca.
if type(RegisterCommand) == 'function' and type(RegisterKeyMapping) == 'function' then
	RegisterCommand('+coe_vehicle_lock', function()
		local ped = PlayerPedId()
		local vehicle = GetVehiclePedIsIn(ped, false)
		local netId = nil
		if vehicle ~= 0 then
			netId = Core.Platform.Entities.GetNetworkId(vehicle)
		end
		TriggerServerEvent('coe_vehicles:toggleLock', netId)
	end, false)
	RegisterCommand('-coe_vehicle_lock', function() end, false)
	RegisterKeyMapping('+coe_vehicle_lock', _t('lock_keybind'), 'keyboard', (config and config.LockKey) or 'L')
end

-- Retorno visual e sonoro ao trancar/destrancar.
RegisterNetEvent('coe_vehicles:lockChanged', function(netId, locked)
	if math.type(netId) ~= 'integer' or not NetworkDoesEntityExistWithNetworkId(netId) then
		return
	end
	local vehicle = Core.Platform.Entities.FromNetworkId(netId)
	if not vehicle or vehicle == 0 then
		return
	end
	PlaySoundFromEntity(-1, locked and 'Remote_Control_Close' or 'Remote_Control_Open', vehicle, 'PI_Menu_Sounds', true, 0)
	CreateThread(function()
		for _ = 1, 2 do
			SetVehicleLights(vehicle, 2)
			Wait(150)
			SetVehicleLights(vehicle, 0)
			Wait(150)
		end
	end)
end)
