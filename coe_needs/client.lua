local settings = Config.Needs
local state = nil
local activity = 'idle'
local lastReport = nil
local appliedShake = -1
local sprintBlocked = false
local regenTicks = 0

local function detectActivity(ped)
	if IsPedInAnyVehicle(ped, false) then
		local vehicle = GetVehiclePedIsIn(ped, false)
		if GetPedInVehicleSeat(vehicle, -1) ~= ped then
			return 'idle'
		end
		return GetEntitySpeed(vehicle) * 3.6 >= 120.0 and 'driveFast' or 'drive'
	end
	if IsPedShooting(ped) or IsPedInMeleeCombat(ped) then
		return 'combat'
	end
	if IsPedSwimming(ped) then
		return 'swim'
	end
	if IsPedSprinting(ped) then
		return 'sprint'
	end
	if IsPedRunning(ped) then
		return 'run'
	end
	if IsPedWalking(ped) then
		return 'walk'
	end
	return 'idle'
end

local function applyShake()
	local stress = state and state.stress or 0
	local level = 0
	if stress >= settings.StressMax then
		level = 2
	elseif stress >= settings.StressHigh then
		level = 1
	end
	if level == appliedShake then
		return
	end
	appliedShake = level
	if level == 0 then
		StopGameplayCamShaking(true)
	else
		ShakeGameplayCam('HAND_SHAKE', level == 2 and 0.35 or 0.15)
	end
end

local function applyState(snapshot)
	state = snapshot
	local weak = snapshot.hunger <= settings.Low or snapshot.thirst <= settings.Low
	SetRunSprintMultiplierForPlayer(PlayerId(), weak and 0.9 or 1.0)
	local blocked = snapshot.hunger <= settings.Empty or snapshot.thirst <= settings.Empty
	if blocked and not sprintBlocked then
		pcall(function()
			exports.coe_notify:Show('error', snapshot.thirst <= settings.Empty
				and 'Você está desidratado demais para correr. Beba algo.'
				or 'Você está faminto demais para correr. Coma algo.')
		end)
	end
	sprintBlocked = blocked
	applyShake()
	TriggerEvent('coe_needs:changed', snapshot)
end

RegisterNetEvent('coe_needs:state')
AddEventHandler('coe_needs:state', function(snapshot)
	if type(snapshot) == 'table' and GetInvokingResource() == nil then
		applyState(snapshot)
	end
end)

exports('GetState', function()
	return state
end)

-- A cada segundo: reporta a atividade ao servidor (so quando muda) e aplica os efeitos no ped.
CreateThread(function()
	TriggerServerEvent('coe_needs:request')
	while true do
		Wait(1000)
		local ped = PlayerPedId()
		if ped ~= 0 and not IsEntityDead(ped) then
			activity = detectActivity(ped)
			if activity ~= lastReport then
				lastReport = activity
				TriggerServerEvent('coe_needs:activity', activity)
			end

			-- A recuperacao nativa de vida e desligada: quem regenera e o estado do personagem.
			SetPlayerHealthRechargeMultiplier(PlayerId(), 0.0)
			if state then
				local health = GetEntityHealth(ped)
				local maxHealth = GetEntityMaxHealth(ped)
				local starving = state.hunger <= settings.Empty or state.thirst <= settings.Empty
				regenTicks = regenTicks + 1
				if starving and regenTicks % 5 == 0 and health > 105 then
					SetEntityHealth(ped, health - 2)
				elseif not starving and state.hunger >= 60 and state.thirst >= 60
					and state.stress <= 70 and regenTicks % 2 == 0
					and health > 100 and health < maxHealth then
					SetEntityHealth(ped, health + 1)
				end
			end
		end
	end
end)

CreateThread(function()
	while true do
		if sprintBlocked then
			DisableControlAction(0, 21, true)
			Wait(0)
		else
			Wait(500)
		end
	end
end)

AddEventHandler('onResourceStop', function(resourceName)
	if resourceName == GetCurrentResourceName() then
		SetRunSprintMultiplierForPlayer(PlayerId(), 1.0)
		SetPlayerHealthRechargeMultiplier(PlayerId(), 1.0)
		StopGameplayCamShaking(true)
	end
end)
