-- Fishing Activity Client Minigame & Loop
local JobsClient = JobsClient
local catalog = JobsClient.catalog
local work = JobsClient.work
local show = function(...) return JobsClient.show(...) end
local loadDict = function(...) return JobsClient.loadDict(...) end
local attachProp = function(...) return JobsClient.attachProp(...) end
local playAnimation = function(...) return JobsClient.playAnimation(...) end
local stopAnimation = function(...) return JobsClient.stopAnimation(...) end
local deleteEntity = function(...) return JobsClient.deleteEntity(...) end
local _t = (Core and Core.Locale and Core.Locale.Bind) and Core.Locale.Bind(Locales) or function(k, p) return (Locales and Locales["pt-BR"] and Locales["pt-BR"][k]) or k end


local rod = nil          -- { jobId, item, prop, phase, ... } com a vara na mão

local FISH_ANIM_DICT = 'amb@world_human_stand_fishing@base'
local FISH_ANIM_CAST = { dict = 'amb@world_human_stand_fishing@idle_a', name = 'idle_c' }
local BLOCKED_CONTROLS = { 24, 25, 37, 44, 140, 141, 142, 257, 263, 264 }

local function fishingOf(jobId)
	local job = catalog[jobId]
	return job, job and job.gather and job.gather.fishing or nil
end

-- Água num ponto: sonda vertical de cima (altura do jogador) até 45 m abaixo.
local function waterAt(x, y, z)
	local hit = TestProbeAgainstWater(x, y, z + 1.0, x, y, z - 45.0)
	if hit == true or hit == 1 then
		return true
	end
	local found, height = GetWaterHeight(x, y, z + 1.0)
	if found and height < z + 1.0 then
		local groundFound, ground = GetGroundZFor_3dCoord(x, y, z + 1.0, false)
		return not groundFound or ground <= height + 0.1
	end
	return false
end

-- Onde a linha cai com a força do arremesso (4 a 18 m à frente).
local function landingOf(power)
	local ped = PlayerPedId()
	local here = Core.Platform.Entities.GetCoords(ped)
	local forward = GetEntityForwardVector(ped)
	local distance = 4.0 + power * 14.0
	return here.x + forward.x * distance, here.y + forward.y * distance, here.z
end

local function holdAnimation(full)
	local ped = PlayerPedId()
	if not loadDict(FISH_ANIM_DICT) then
		return
	end
	-- Parado pescando: corpo inteiro; só com a vara na mão: tronco (dá para andar).
	TaskPlayAnim(ped, FISH_ANIM_DICT, 'base', 4.0, -4.0, -1, full and 1 or 49, 0.0, false, false, false)
end

local function hint(text)
	SendNUIMessage({ action = 'fish:hint', text = text })
end

local function setPhase(phase)
	if rod then
		rod.phase = phase
		rod.phaseAt = GetGameTimer()
	end
end

-- Volta para "vara na mão" (sem lance), sem guardar a vara.
local function cancelFishing(notifyServer)
	local state = fishingState
	fishingState = nil
	work.busy = false
	if notifyServer and state then
		TriggerServerEvent('coe_jobs:castCancel', state.jobId)
	end
	if rod then
		setPhase('idle')
		holdAnimation(false)
		hint(_t('fish_hint_idle'))
	end
end

local function putAwayRod()
	if not rod then
		return
	end
	if fishingState then
		cancelFishing(true)
	end
	local state = rod
	rod = nil
	deleteEntity(state.prop)
	StopAnimTask(PlayerPedId(), FISH_ANIM_DICT, 'base', 2.0)
	SendNUIMessage({ action = 'fish:hide' })
end

-- Varas soltas no chão por perto (as que o cenário antigo largava): some com elas ao pegar a vara.
local function clearLooseRods(spec)
	local hash = joaat(spec.model)
	local here = Core.Platform.Entities.GetCoords(PlayerPedId())
	for _, object in ipairs(GetGamePool('CObject')) do
		if Core.Platform.Entities.GetModel(object) == hash and not IsEntityAttached(object) and #(Core.Platform.Entities.GetCoords(object) - here) < 8.0 then
			Core.Platform.Entities.Delete(object)
		end
	end
end

-- Arremesso: confere área e água onde a linha cai e pede o lance ao servidor.
local function throwLine(power)
	local job, fishing = fishingOf(rod.jobId)
	if not fishing then
		return putAwayRod()
	end
	local here = Core.Platform.Entities.GetCoords(PlayerPedId())
	if not JobRules.FishingArea(fishing, { x = here.x, y = here.y, z = here.z }) then
		setPhase('idle')
		hint(_t('fish_hint_idle'))
		return show('warning', _t('err_no_fishing_area'))
	end
	local x, y, z = landingOf(power)
	if not waterAt(x, y, z) then
		setPhase('idle')
		hint(_t('fish_hint_idle'))
		return show('warning', _t('fish_no_water'))
	end
	setPhase('casting')
	rod.power = power
	CreateThread(function()
		local ped = PlayerPedId()
		if loadDict(FISH_ANIM_CAST.dict) then
			TaskPlayAnim(ped, FISH_ANIM_CAST.dict, FISH_ANIM_CAST.name, 8.0, -4.0, 1500, 48, 0.0, false, false, false)
		end
		Wait(900)
		if rod and rod.phase == 'casting' then
			TriggerServerEvent('coe_jobs:cast', job.id, rod.item, power)
		end
	end)
end

local function reel(caught)
	local state = fishingState
	if not state or not rod then
		return
	end
	setPhase('reeling')
	TriggerServerEvent('coe_jobs:reel', state.jobId, caught)
end

-- Briga: física simples da faixa (segurar E sobe, soltar cai) e do peixe (vai a alvos sorteados).
local function startFight(fight)
	rod.fight = {
		fish = 0.5, target = math.random(), retarget = GetGameTimer() + 800,
		bar = 0.5 - fight.bar / 2, velocity = 0.0, progress = fight.start, started = GetGameTimer(), last = GetGameTimer()
	}
	setPhase('fight')
end

local function stepFight(fight)
	local state = rod.fight
	local now = GetGameTimer()
	local dt = math.min(0.1, (now - state.last) / 1000)
	state.last = now
	-- Peixe: troca de alvo a cada 0,5-1,4 s (mais agitado = mais rápido) e nada até ele com tremidas.
	if now >= state.retarget then
		state.target = math.random()
		state.retarget = now + math.floor((500 + math.random() * 900) / math.max(0.5, fight.speed / 0.3))
	end
	local step = fight.speed * dt
	local delta = state.target - state.fish
	state.fish = math.max(0, math.min(1, state.fish + math.max(-step, math.min(step, delta)) + (math.random() - 0.5) * 0.01))
	-- Faixa: E segurado acelera para cima, solto cai; para nas bordas.
	if IsDisabledControlPressed(0, 38) then
		state.velocity = math.min(1.2, state.velocity + 2.4 * dt)
	else
		state.velocity = math.max(-1.2, state.velocity - 2.0 * dt)
	end
	state.bar = state.bar + state.velocity * dt
	if state.bar < 0 then
		state.bar, state.velocity = 0, 0
	elseif state.bar > 1 - fight.bar then
		state.bar, state.velocity = 1 - fight.bar, 0
	end
	local inside = state.fish >= state.bar and state.fish <= state.bar + fight.bar
	state.progress = math.max(0, math.min(1, state.progress + (inside and fight.fill or -fight.drain) * dt))
	SendNUIMessage({ action = 'fish:fight', fish = state.fish, bar = state.bar, size = fight.bar, progress = state.progress, inside = inside })
	if state.progress >= 1 then
		SendNUIMessage({ action = 'fish:end', hit = true })
		reel(true)
	elseif state.progress <= 0 or now - state.started > fight.maxMs then
		SendNUIMessage({ action = 'fish:end', hit = false })
		reel(false)
	end
end

-- Laço da vara na mão.
local function rodLoop()
	local lastAnim = 0
	while rod do
		Wait(0)
		local ped = PlayerPedId()
		for _, control in ipairs(BLOCKED_CONTROLS) do
			DisableControlAction(0, control, true)
		end
		DisableControlAction(0, 38, true)
		DisableControlAction(0, 73, true)
		if IsPedInAnyVehicle(ped, true) or IsPedSwimming(ped) or IsPedDeadOrDying(ped, true) or IsPedRagdoll(ped) then
			putAwayRod()
			break
		end
		local phase = rod.phase
		local now = GetGameTimer()
		if phase == 'idle' then
			if now - lastAnim > 1500 and not IsEntityPlayingAnim(ped, FISH_ANIM_DICT, 'base', 3) then
				holdAnimation(false)
				lastAnim = now
			end
			if IsDisabledControlJustPressed(0, 73) then
				putAwayRod()
				break
			elseif IsDisabledControlJustPressed(0, 38) then
				setPhase('charging')
			end
		elseif phase == 'charging' then
			-- Força vai e volta (1,2 s por ida): soltar na hora certa é parte do arremesso.
			local power = JobRules.MarkerAt(now - rod.phaseAt, 1 / 2.4)
			SendNUIMessage({ action = 'fish:power', power = power })
			if not IsDisabledControlPressed(0, 38) then
				throwLine(power)
			end
		elseif phase == 'waiting' then
			if IsDisabledControlJustPressed(0, 73) or #(Core.Platform.Entities.GetCoords(ped) - rod.origin) > 2.0 then
				show('info', _t('fish_cancelled'))
				cancelFishing(true)
			elseif fishingState and now >= rod.biteAt then
				PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
				local rare = fishingState.tier == 'rare'
				SendNUIMessage({ action = 'fish:hook', text = rare and _t('fish_bite_big') or _t('fish_bite'), ms = fishingState.fight.hookMs, rare = rare })
				setPhase('hook')
			end
		elseif phase == 'hook' then
			if IsDisabledControlJustPressed(0, 38) then
				startFight(fishingState.fight)
			elseif now - rod.phaseAt > fishingState.fight.hookMs then
				SendNUIMessage({ action = 'fish:end', hit = false })
				reel(false)
			end
		elseif phase == 'fight' then
			if #(Core.Platform.Entities.GetCoords(ped) - rod.origin) > 2.5 then
				SendNUIMessage({ action = 'fish:end', hit = false })
				reel(false)
			else
				stepFight(fishingState.fight)
			end
		end
	end
end

local function takeRod(jobId, item)
	local _, fishing = fishingOf(jobId)
	if not fishing or work.busy then
		return
	end
	local spec = fishing.rodProp
	clearLooseRods(spec)
	local prop = attachProp(spec)
	rod = { jobId = jobId, item = item, prop = prop, phase = 'idle', phaseAt = GetGameTimer() }
	holdAnimation(false)
	hint(_t('fish_hint_idle'))
	CreateThread(rodLoop)
end

RegisterNetEvent('coe_jobs:fishUse', function(data)
	if type(data) ~= 'table' then
		return
	end
	-- Usar a vara de novo guarda (ou troca de vara, se for outra).
	if rod then
		local same = rod.item == data.rod
		if rod.phase ~= 'idle' and rod.phase ~= 'charging' then
			return
		end
		putAwayRod()
		if same then
			return
		end
	end
	local ped = PlayerPedId()
	if IsPedInAnyVehicle(ped, false) or IsPedSwimming(ped) or IsPedDeadOrDying(ped, true) then
		return
	end
	takeRod(data.jobId, data.rod)
end)

RegisterNetEvent('coe_jobs:fishCast', function(data)
	if type(data) ~= 'table' or not rod or rod.phase ~= 'casting' then
		if type(data) == 'table' then
			TriggerServerEvent('coe_jobs:castCancel', data.jobId)
		end
		return
	end
	fishingState = data
	work.busy = true
	rod.origin = Core.Platform.Entities.GetCoords(PlayerPedId())
	rod.biteAt = GetGameTimer() + data.bite
	setPhase('waiting')
	holdAnimation(true)
	hint(_t('fish_hint_wait', { bait = data.bait:lower() }))
end)

RegisterNetEvent('coe_jobs:fishResult', function()
	if not fishingState then
		return
	end
	fishingState = nil
	-- Mostra o resultado e volta à vara na mão (a mesma vara: nada cai no chão).
	CreateThread(function()
		Wait(1400)
		work.busy = false
		if rod and rod.phase == 'reeling' then
			setPhase('idle')
			holdAnimation(false)
			hint(_t('fish_hint_idle'))
		end
	end)
end)


JobsClient.cancelFishing = cancelFishing
JobsClient.clearLooseRods = clearLooseRods