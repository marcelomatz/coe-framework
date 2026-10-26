local settings = Config.Needs
local current = nil
local lastActivity = nil
local activeTimecycle = nil
local energyExpiresAt = 0
local lastPhysicalApplied = nil

local function t(key)
	local lang = (Config and Config.Locale) or 'pt-BR'
	local dict = (type(Locales) == 'table' and (Locales[lang] or Locales['pt-BR'])) or nil
	return (dict and dict[key]) or key
end

local function notify(kind, key)
	pcall(function()
		exports.coe_notify:Show(kind, t(key))
	end)
end

local function clearVisualEffects()
	if activeTimecycle then
		ClearTimecycleModifier()
		activeTimecycle = nil
	end
end

local function applyTimecycle(modifier, strength)
	if not modifier then
		clearVisualEffects()
		return
	end
	if activeTimecycle ~= modifier then
		SetTimecycleModifier(modifier)
		activeTimecycle = modifier
	end
	SetTimecycleModifierStrength(strength or 0.5)
end

local function detectActivity()
	local ped = PlayerPedId()
	if IsEntityDead(ped) then
		return 'idle'
	end
	if IsPedShooting(ped) or IsPedInMeleeCombat(ped) then
		return 'combat'
	end
	if IsPedSwimming(ped) or IsPedSwimmingUnderWater(ped) then
		return 'swim'
	end
	local veh = GetVehiclePedIsIn(ped, false)
	if veh ~= 0 then
		if GetPedInVehicleSeat(veh, -1) == ped and GetEntitySpeed(veh) * 3.6 >= settings.FastDriveSpeedKmh then
			return 'driveFast'
		end
		return 'drive'
	end
	if IsPedSprinting(ped) then
		return 'sprint'
	end
	if IsPedRunning(ped) or IsPedJumping(ped) then
		return 'run'
	end
	if IsPedWalking(ped) then
		return 'walk'
	end
	return 'idle'
end

RegisterNetEvent('coe_needs:state')
AddEventHandler('coe_needs:state', function(snapshot)
	if type(snapshot) ~= 'table' then
		return
	end
	local prevAlcohol = current and (current.alcohol or 0) or 0
	local prevDrugs = current and (current.drugs or 0) or 0
	current = snapshot
	TriggerEvent('coe_needs:changed', snapshot)

	local fx = settings.Effects
	local alcCfg = fx and fx.Alcohol
	local drgCfg = fx and fx.Drugs
	if alcCfg and (snapshot.alcohol or 0) >= alcCfg.Threshold and prevAlcohol < alcCfg.Threshold then
		notify('warning', 'intoxicated_alcohol')
	end
	if drgCfg and (snapshot.drugs or 0) >= drgCfg.Threshold and prevDrugs < drgCfg.Threshold then
		notify('warning', 'intoxicated_drugs')
	end
end)

RegisterNetEvent('coe_needs:effect')
AddEventHandler('coe_needs:effect', function(payload)
	if type(payload) ~= 'table' then
		return
	end
	local ped = PlayerPedId()
	if ped == 0 or IsEntityDead(ped) then
		return
	end

	local applied = { healthDelta = 0, armorDelta = 0, hadEnergy = false }
	local healthGain = math.floor(tonumber(payload.health) or 0)
	if healthGain > 0 then
		local curHealth = GetEntityHealth(ped)
		local maxHealth = GetEntityMaxHealth(ped)
		if maxHealth <= 0 then
			maxHealth = 200
		end
		local nextHealth = math.min(maxHealth, curHealth + healthGain)
		applied.healthDelta = math.max(0, nextHealth - curHealth)
		if applied.healthDelta > 0 then
			SetEntityHealth(ped, nextHealth)
		end
	end

	local armorGain = math.floor(tonumber(payload.armor) or 0)
	if armorGain > 0 then
		local curArmor = GetPedArmour(ped)
		local nextArmor = math.min(100, curArmor + armorGain)
		applied.armorDelta = math.max(0, nextArmor - curArmor)
		if applied.armorDelta > 0 then
			SetPedArmour(ped, nextArmor)
		end
	end

	local energyGain = tonumber(payload.energy) or 0
	if energyGain > 0 then
		local energyCfg = settings.Effects and settings.Effects.Energy or {}
		local durationMs = math.floor(energyGain * (energyCfg.DurationPerPointMs or 1000))
		energyExpiresAt = GetGameTimer() + durationMs
		applied.hadEnergy = true
		RestorePlayerStamina(PlayerId(), 1.0)
		SetRunSprintMultiplierForPlayer(PlayerId(), energyCfg.SprintMultiplier or 1.15)
		notify('info', 'energy_boost')
	end
	lastPhysicalApplied = applied
end)

RegisterNetEvent('coe_needs:cancelEffect')
AddEventHandler('coe_needs:cancelEffect', function()
	if not lastPhysicalApplied then
		return
	end
	local applied = lastPhysicalApplied
	lastPhysicalApplied = nil
	local ped = PlayerPedId()
	if ped ~= 0 and not IsEntityDead(ped) then
		if applied.healthDelta and applied.healthDelta > 0 then
			local curHealth = GetEntityHealth(ped)
			SetEntityHealth(ped, math.max(101, curHealth - applied.healthDelta))
		end
		if applied.armorDelta and applied.armorDelta > 0 then
			local curArmor = GetPedArmour(ped)
			SetPedArmour(ped, math.max(0, curArmor - applied.armorDelta))
		end
	end
	if applied.hadEnergy then
		energyExpiresAt = 0
		SetRunSprintMultiplierForPlayer(PlayerId(), 1.0)
	end
end)

exports('GetNeeds', function()
	if not current then
		return nil
	end
	return {
		hunger = current.hunger,
		thirst = current.thirst,
		stress = current.stress,
		alcohol = current.alcohol or 0,
		drugs = current.drugs or 0
	}
end)

-- Informa ao servidor apenas quando a atividade muda.
CreateThread(function()
	while true do
		local activity = detectActivity()
		if activity ~= lastActivity then
			lastActivity = activity
			TriggerServerEvent('coe_needs:activity', activity)
		end
		if energyExpiresAt > 0 then
			if GetGameTimer() >= energyExpiresAt then
				energyExpiresAt = 0
				SetRunSprintMultiplierForPlayer(PlayerId(), 1.0)
			else
				RestorePlayerStamina(PlayerId(), 1.0)
			end
		end
		Wait(1000)
	end
end)

-- Efeitos de fome/sede zeradas, estresse elevado, alcool e drogas.
CreateThread(function()
	local fx = settings.Effects
	while true do
		Wait(fx.IntervalMs)
		if current then
			local ped = PlayerPedId()
			if not IsEntityDead(ped) then
				local damage = 0
				if current.hunger <= 0 then
					damage = damage + fx.StarveDamage
				end
				if current.thirst <= 0 then
					damage = damage + fx.DehydrateDamage
				end
				if damage > 0 then
					local health = GetEntityHealth(ped)
					if health > 105 then
						SetEntityHealth(ped, math.max(105, health - damage))
					end
					notify('error', 'starving_or_dehydrated')
				end

				local alcohol = current.alcohol or 0
				local drugs = current.drugs or 0
				local alcCfg = fx.Alcohol or {}
				local drgCfg = fx.Drugs or {}

				if drugs >= (drgCfg.Threshold or 25) then
					local heavy = drugs >= (drgCfg.HeavyThreshold or 60)
					applyTimecycle(drgCfg.Timecycle or 'drug_flying_base', heavy and 0.85 or 0.45)
					ShakeGameplayCam('DRUNK_SHAKE', heavy and (drgCfg.HeavyShakeIntensity or 0.45) or (drgCfg.ShakeIntensity or 0.20))
				elseif alcohol >= (alcCfg.Threshold or 30) then
					local heavy = alcohol >= (alcCfg.HeavyThreshold or 65)
					applyTimecycle(alcCfg.Timecycle or 'spectator5', heavy and 0.80 or 0.40)
					ShakeGameplayCam('DRUNK_SHAKE', heavy and (alcCfg.HeavyShakeIntensity or 0.55) or (alcCfg.ShakeIntensity or 0.25))
				else
					clearVisualEffects()
					if current.stress >= fx.StressShakeThreshold then
						ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', fx.StressShakeIntensity)
					end
				end
			else
				clearVisualEffects()
			end
		end
	end
end)

AddEventHandler('onResourceStop', function(resourceName)
	if resourceName ~= GetCurrentResourceName() then
		return
	end
	clearVisualEffects()
	if energyExpiresAt > 0 then
		SetRunSprintMultiplierForPlayer(PlayerId(), 1.0)
	end
end)
