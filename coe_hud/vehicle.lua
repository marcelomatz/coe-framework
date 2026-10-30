-- Controles do veiculo (cinto, farol, setas). As teclas sao registradas com RegisterKeyMapping:
-- o jogador troca em Configuracoes > Teclado > FiveM. Padroes: B cinto, H farol, setas esquerda/direita.
VehicleControls = { belt = false, lights = 0, left = false, right = false, vehicle = 0 }

local CONTROL_VEH_HEADLIGHT = 74
local CONTROL_VEH_EXIT = 75
local FLAG_CAN_FLY_THROUGH_WINDSCREEN = 32
-- Sem cinto: motos (8) e bicicletas (13). Moto: o piloto cai normalmente; bicicleta não tem motor nem farol.
local NO_BELT_CLASSES = { [8] = true, [13] = true }

---O tipo de veículo do HUD ('motorcycle', 'bicycle', ...) tem cinto de segurança?
function VehicleControls.HasBelt(kind)
	return kind ~= 'motorcycle' and kind ~= 'bicycle'
end

local function notify(kind, message)
	pcall(function()
		exports.coe_notify:Show(kind, message, 2000)
	end)
end

local function drivingVehicle()
	local ped = PlayerPedId()
	local vehicle = GetVehiclePedIsIn(ped, false)
	if vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == ped then
		return ped, vehicle
	end
	return ped, 0
end

local function reset(ped, previous)
	if previous ~= 0 and DoesEntityExist(previous) then
		SetVehicleIndicatorLights(previous, 0, false)
		SetVehicleIndicatorLights(previous, 1, false)
	end
	SetPedConfigFlag(ped, FLAG_CAN_FLY_THROUGH_WINDSCREEN, true)
	VehicleControls.belt = false
	VehicleControls.lights = 0
	VehicleControls.left = false
	VehicleControls.right = false
end

-- Chamado pelo loop do HUD: zera o estado ao trocar de veiculo ou descer.
function VehicleControls.Track(ped, vehicle)
	if vehicle ~= VehicleControls.vehicle then
		reset(ped, VehicleControls.vehicle)
		VehicleControls.vehicle = vehicle
	end
end

local function toggleBelt()
	local ped, vehicle = drivingVehicle()
	if vehicle == 0 then
		return
	end
	if NO_BELT_CLASSES[GetVehicleClass(vehicle)] then
		VehicleControls.belt = false
		SetPedConfigFlag(ped, FLAG_CAN_FLY_THROUGH_WINDSCREEN, true)
		notify('info', 'Este veículo não tem cinto de segurança.')
		return
	end
	VehicleControls.belt = not VehicleControls.belt
	SetPedConfigFlag(ped, FLAG_CAN_FLY_THROUGH_WINDSCREEN, not VehicleControls.belt)
	notify('info', VehicleControls.belt and 'Cinto colocado.' or 'Cinto solto.')
end

-- Ciclo: apagado -> baixo -> alto -> apagado.
local function cycleLights()
	local _, vehicle = drivingVehicle()
	if vehicle == 0 or GetVehicleClass(vehicle) == 13 then
		return
	end
	VehicleControls.lights = (VehicleControls.lights + 1) % 3
	local mode = VehicleControls.lights
	SetVehicleLights(vehicle, mode == 0 and 1 or 2)
	SetVehicleFullbeam(vehicle, mode == 2)
end

local function toggleIndicator(side)
	local _, vehicle = drivingVehicle()
	if vehicle == 0 then
		return
	end
	local active = not VehicleControls[side]
	VehicleControls.left = false
	VehicleControls.right = false
	VehicleControls[side] = active
	SetVehicleIndicatorLights(vehicle, 1, VehicleControls.left)
	SetVehicleIndicatorLights(vehicle, 0, VehicleControls.right)
end

RegisterCommand('coe_hud_belt', toggleBelt, false)
RegisterCommand('coe_hud_lights', cycleLights, false)
RegisterCommand('coe_hud_left', function() toggleIndicator('left') end, false)
RegisterCommand('coe_hud_right', function() toggleIndicator('right') end, false)

RegisterKeyMapping('coe_hud_belt', 'Veículo: cinto de segurança', 'keyboard', 'B')
RegisterKeyMapping('coe_hud_lights', 'Veículo: farol', 'keyboard', 'H')
RegisterKeyMapping('coe_hud_left', 'Veículo: seta esquerda', 'keyboard', 'LEFT')
RegisterKeyMapping('coe_hud_right', 'Veículo: seta direita', 'keyboard', 'RIGHT')

-- Bloqueia o farol nativo (H) e a saida com o cinto afivelado.
CreateThread(function()
	while true do
		if VehicleControls.vehicle ~= 0 then
			DisableControlAction(0, CONTROL_VEH_HEADLIGHT, true)
			if VehicleControls.belt then
				DisableControlAction(0, CONTROL_VEH_EXIT, true)
			end
			Wait(0)
		else
			Wait(300)
		end
	end
end)
