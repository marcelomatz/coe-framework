-- Animações de uso de item (comer, beber, curativo, sacar arma...) e equipar armas.
-- As definições das animações ficam em `data/coe_animations.lua` (`Inventory.Items.Animations`).
local C = Inventory.Client

--- Resolve o modelo do prop de uma animação. Props com `weaponModel` usam o modelo da arma do item.
local function resolvePropModel(propProfile, item)
	if propProfile.weaponModel then
		if not item or type(item.name) ~= 'string' then
			return nil
		end
		local weaponModel = GetWeapontypeModel(GetHashKey(item.name))
		if not weaponModel or weaponModel == 0 or not IsModelInCdimage(weaponModel) or not IsModelValid(weaponModel) then
			return nil
		end
		return weaponModel
	end
	return C.resolveModelHash(propProfile.model)
end

--- Cria o prop da animação e o anexa ao osso indicado no perfil. O modelo precisa estar carregado.
local function attachAnimationProp(playerPed, propProfile, modelHash)
	if not modelHash or not HasModelLoaded(modelHash) then
		return nil
	end

	local object = C.createLocalObject(modelHash, GetEntityCoords(playerPed))
	if not object then
		return nil
	end

	local position = propProfile.position
	local rotation = propProfile.rotation
	AttachEntityToEntity(
		object,
		playerPed,
		GetPedBoneIndex(playerPed, propProfile.bone),
		position.x, position.y, position.z,
		rotation.x, rotation.y, rotation.z,
		false, true, false, true, 2, true
	)
	return object
end

--- Dispara a animação (avançada, com posição fixa, ou comum).
local function startAnimation(playerPed, animation, durationMs)
	local duration = durationMs or animation.duration
	if animation.advanced then
		local coords = GetEntityCoords(playerPed, true)
		TaskPlayAnimAdvanced(
			playerPed,
			animation.dict,
			animation.clip,
			coords.x, coords.y, coords.z,
			0.0, 0.0, GetEntityHeading(playerPed),
			8.0, 3.0,
			duration,
			animation.flag,
			animation.startTime or 0.0,
			0, 0
		)
		return
	end

	TaskPlayAnim(
		playerPed,
		animation.dict,
		animation.clip,
		8.0,
		-8.0,
		duration,
		animation.flag,
		1.0,
		false,
		false,
		false
	)
end

--- Espera por `ms` milissegundos em fatias curtas, interrompendo imediatamente se `shouldCancel()` retornar true.
local function waitInterruptible(ms, shouldCancel)
	if ms <= 0 then
		return not (shouldCancel and shouldCancel())
	end
	if not shouldCancel then
		Wait(ms)
		return true
	end
	local remaining = ms
	while remaining > 0 do
		if shouldCancel() then
			return false
		end
		local step = math.min(50, remaining)
		Wait(step)
		remaining = remaining - step
	end
	return not shouldCancel()
end

--- Lista, em ordem cronológica, os momentos da animação em que algo deve acontecer:
--- criar o prop (`attachAt`) e equipar o item (`equipAt`). Os tempos são frações da duração.
local function buildCheckpoints(duration, animation, propProfile, hasEquipCallback)
	local checkpoints = {}
	if propProfile then
		checkpoints[#checkpoints + 1] = {
			time = math.floor(duration * (propProfile.attachAt or 0)),
			action = 'prop'
		}
	end
	if animation.equipAt ~= nil and hasEquipCallback then
		checkpoints[#checkpoints + 1] = {
			time = math.floor(duration * animation.equipAt),
			action = 'equip'
		}
	end
	table.sort(checkpoints, function(first, second)
		return first.time < second.time
	end)
	return checkpoints
end

--- Executa a linha do tempo da animação e retorna `propObject, completed`.
local function runTimeline(playerPed, duration, animation, propProfile, propModelHash, onEquip, shouldCancel)
	local propObject
	local elapsed = 0
	for _, checkpoint in ipairs(buildCheckpoints(duration, animation, propProfile, onEquip ~= nil)) do
		local delay = math.max(0, checkpoint.time - elapsed)
		if delay > 0 and not waitInterruptible(delay, shouldCancel) then
			return propObject, false
		end
		elapsed = checkpoint.time
		if checkpoint.action == 'prop' then
			propObject = attachAnimationProp(playerPed, propProfile, propModelHash)
		else
			onEquip()
		end
	end
	if elapsed < duration then
		if not waitInterruptible(duration - elapsed, shouldCancel) then
			return propObject, false
		end
	end
	return propObject, true
end

--- Sem animação possível: aguarda a duração configurada (se houver) ou conclui imediatamente.
local function finishWithoutAnimation(onComplete, onEquip, options)
	local durationMs = options and tonumber(options.durationMs) or 0
	local shouldCancel = options and options.shouldCancel
	local onCancel = options and options.onCancel
	if durationMs > 0 and shouldCancel then
		CreateThread(function()
			if not waitInterruptible(durationMs, shouldCancel) then
				if onCancel then onCancel() end
				return
			end
			if onEquip then onEquip() end
			onComplete()
		end)
		return
	end
	if onEquip then onEquip() end
	onComplete()
end

--- Toca a animação `animationName` do item e chama `onComplete` ao final.
--- `onEquip` (opcional) roda no instante `equipAt` da animação, ou imediatamente se ela não puder tocar.
--- `options` (opcional): `{ durationMs, shouldCancel, onCancel }`.
function C.playItemAnimation(animationName, onComplete, item, onEquip, options)
	local animation = animationName and Inventory.Items.Animations[animationName]
	if not animation then
		finishWithoutAnimation(onComplete, onEquip, options)
		return
	end

	local duration = (options and tonumber(options.durationMs)) or animation.duration
	local shouldCancel = options and options.shouldCancel
	local onCancel = options and options.onCancel

	CreateThread(function()
		local playerPed = PlayerPedId()
		if playerPed == 0 then
			finishWithoutAnimation(onComplete, onEquip, options)
			return
		end

		local propProfile = animation.prop
		local propModelHash = propProfile and resolvePropModel(propProfile, item)
		if propModelHash and not C.loadModel(propModelHash) then
			propModelHash = nil
		end

		if not C.loadAnimDict(animation.dict) or not DoesEntityExist(playerPed) then
			if propModelHash then SetModelAsNoLongerNeeded(propModelHash) end
			finishWithoutAnimation(onComplete, onEquip, options)
			return
		end

		startAnimation(playerPed, animation, duration)
		local propObject, completed = runTimeline(
			playerPed, duration, animation, propProfile, propModelHash, onEquip, shouldCancel
		)

		if DoesEntityExist(playerPed) then
			StopAnimTask(playerPed, animation.dict, animation.clip, 1.0)
		end
		if propObject and DoesEntityExist(propObject) then
			DetachEntity(propObject, true, true)
			DeleteEntity(propObject)
		end
		RemoveAnimDict(animation.dict)
		if propModelHash and HasModelLoaded(propModelHash) then
			SetModelAsNoLongerNeeded(propModelHash)
		end
		if not completed then
			if onCancel then onCancel() end
			return
		end
		onComplete()
	end)
end

--- Dá a arma ao ped e a seleciona. Armas de fogo ficam só com a munição carregada no item
--- (metadata.ammo), sem reserva: recarregar usa a munição do inventário (weapon_ammo.lua).
function C.equipWeaponItem(item)
	if type(item) ~= 'table' or type(item.name) ~= 'string' then
		return
	end

	local weaponHash = GetHashKey(item.name)
	local playerPed = PlayerPedId()
	if weaponHash == 0 or playerPed == 0 then
		return
	end

	if not HasPedGotWeapon(playerPed, weaponHash, false) then
		local ammo = tonumber(item.metadata and item.metadata.ammo) or 0
		GiveWeaponToPed(playerPed, weaponHash, ammo, false, true)
	end
	SetCurrentPedWeapon(playerPed, weaponHash, true)

	local loaded = math.max(0, math.floor(tonumber(item.metadata and item.metadata.ammo) or 0))
	if C.isReloadableWeapon(item) then
		-- O estoque de munição do ped é por tipo; outra arma do mesmo tipo pode ter deixado sobra.
		SetPedAmmo(playerPed, weaponHash, loaded)
		SetAmmoInClip(playerPed, weaponHash, math.min(loaded, GetMaxAmmoInClip(playerPed, weaponHash, true)))
	end
	C.trackWeapon(item, loaded)
end
