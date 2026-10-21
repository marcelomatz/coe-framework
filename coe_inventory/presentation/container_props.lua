-- Containers portáteis (maleta, saco de lixo, saco de papel) carregados pelo jogador.
--
-- Cada container carregado tem um "registro" em `state.containerProps[containerId]`:
--   { containerId, itemName, profile, entity, metadata?, equipped?, weaponHash?, placed? }
-- Maletas e saco de lixo são armas nativas: o jogo cuida da animação e do prop na mão, então a
-- entidade fica escondida e só aparece ao posicionar no chão. O `paperbag` não é arma e
-- tem o prop anexado à mão.
local C = Inventory.Client
local state = C.state

--- Remove a arma nativa (ou para a animação) associada a um registro carregado.
local function releaseCarry(record)
	local playerPed = PlayerPedId()
	if record.weaponHash then
		if DoesEntityExist(playerPed) and HasPedGotWeapon(playerPed, record.weaponHash, false) then
			RemoveWeaponFromPed(playerPed, record.weaponHash)
		end
		record.weaponHash = nil
	elseif record.animationDict then
		if DoesEntityExist(playerPed) then
			StopAnimTask(playerPed, record.animationDict, record.animationClip, 1.0)
		end
		RemoveAnimDict(record.animationDict)
	end
end
C.releaseCarry = releaseCarry

--- Desequipa a arma-container atual. Com `deleteEntity`, apaga também o prop escondido.
local function clearEquippedWeapon(deleteEntity)
	local equipped = state.equippedWeapon
	if not equipped then return end

	releaseCarry(equipped)
	state.equippedWeapon = nil
	state.containerProps[equipped.containerId] = nil
	if deleteEntity and equipped.entity and DoesEntityExist(equipped.entity) then
		SetEntityAsMissionEntity(equipped.entity, true, true)
		DeleteEntity(equipped.entity)
	end
	if state.carriedContainerId == equipped.containerId then
		state.carriedContainerId = nil
		C.syncCarriedState()
	end
end
C.clearEquippedWeapon = clearEquippedWeapon

--- Apaga o prop do container e limpa todo o estado de carregamento/posicionamento dele.
local function deleteContainerProp(containerId)
	local record = state.containerProps[containerId]
	if state.equippedWeapon and state.equippedWeapon.containerId == containerId then
		releaseCarry(state.equippedWeapon)
		state.equippedWeapon = nil
	end
	if record and record.entity and DoesEntityExist(record.entity) then
		if NetworkGetEntityIsNetworked(record.entity) then
			NetworkRequestControlOfEntity(record.entity)
		end
		SetEntityAsMissionEntity(record.entity, true, true)
		DeleteEntity(record.entity)
	end
	state.containerProps[containerId] = nil
	if state.carriedContainerId == containerId then
		state.carriedContainerId = nil
		C.syncCarriedState()
	end
	if state.placement and state.placement.containerId == containerId then
		state.placement = nil
	end
end
C.deleteContainerProp = deleteContainerProp

--- Coloca o container na mão do jogador. Para armas nativas dá a arma e esconde o prop;
--- para o saco de papel anexa o prop ao osso do perfil. Retorna false se não for possível.
local function attachContainerProp(record)
	local playerPed = PlayerPedId()
	if not DoesEntityExist(record.entity) or not DoesEntityExist(playerPed) then
		return false
	end

	FreezeEntityPosition(record.entity, false)
	SetEntityCollision(record.entity, false, false)
	SetEntityAlpha(record.entity, 255, false)
	record.placed = false

	if C.isWeaponItem(record.itemName) then
		local weaponHash = GetHashKey(record.itemName)
		if weaponHash == 0 then return false end
		DetachEntity(record.entity, true, true)
		SetEntityVisible(record.entity, false, false)
		if not HasPedGotWeapon(playerPed, weaponHash, false) then
			GiveWeaponToPed(playerPed, weaponHash, 0, false, true)
		end
		SetCurrentPedWeapon(playerPed, weaponHash, true)
		record.weaponHash = weaponHash
		record.equipped = true
		state.equippedWeapon = record
	else
		local profile = record.profile
		AttachEntityToEntity(
			record.entity,
			playerPed,
			GetPedBoneIndex(playerPed, profile.bone),
			profile.position.x, profile.position.y, profile.position.z,
			profile.rotation.x, profile.rotation.y, profile.rotation.z,
			false, true, false, true, 2, true
		)
	end

	state.carriedContainerId = record.containerId
	C.syncCarriedState()
	return true
end
C.attachContainerProp = attachContainerProp

--- Cria a entidade local do container (escondida/segurada) para o item informado.
--- Retorna a entidade ou nil.
local function createContainerEntity(profile)
	local playerPed = PlayerPedId()
	if not DoesEntityExist(playerPed) then return nil end

	local modelHash = C.resolveModelHash(profile.model)
	if not modelHash or not C.loadModel(modelHash) then return nil end
	return C.createLocalObject(modelHash, GetEntityCoords(playerPed))
end

--- Registra um novo container carregado e o põe na mão. Em falha apaga o que criou.
local function registerAndAttach(record)
	state.containerProps[record.containerId] = record
	if attachContainerProp(record) then
		return true
	end
	deleteContainerProp(record.containerId)
	return false
end

local CARRY_GUARD_MS = 6000

--- Toca a animação de pegar/guardar e roda `apply` no ponto dela. Recusa se já houver uma em curso.
local function runCarryAnimation(animationName, item, apply)
	local now = GetGameTimer()
	if (state.carryAnimationUntil or 0) > now then
		return false
	end
	state.carryAnimationUntil = now + CARRY_GUARD_MS
	C.playItemAnimation(animationName, function()
		state.carryAnimationUntil = 0
	end, item, function()
		local ok, err = pcall(apply)
		if not ok then
			print(('[coe_inventory] erro ao aplicar a maleta: %s'):format(tostring(err)))
		end
	end)
	return true
end

--- Equipa/desequipa a maleta nativa de `item` (alterna ao usar o mesmo container).
--- `fromGround` usa a animação de pegar do chão. Retorna `true` ou `false, codigoDeErro`.
function C.equipContainerWeapon(item, fromGround)
	local containerId = item.metadata and item.metadata.containerId
	local profile = C.CONTAINER_PROFILES[item.name]
	if type(containerId) ~= 'string' or not profile then
		return false, 'container_id_missing'
	end

	local equipped = state.equippedWeapon
	if equipped and equipped.containerId == containerId then
		if not runCarryAnimation('container_stow', item, function()
			clearEquippedWeapon(true)
			C.feedback('Maleta guardada.')
		end) then
			return false, 'container_prop_busy'
		end
		return true
	end
	if state.carriedContainerId and state.carriedContainerId ~= containerId and not equipped then
		return false, 'container_prop_busy'
	end

	local started = runCarryAnimation(fromGround and 'container_pickup' or 'container_equip', item, function()
		if state.equippedWeapon then
			clearEquippedWeapon(true)
		end
		local entity = createContainerEntity(profile)
		local registered = entity and registerAndAttach({
			containerId = containerId,
			itemName = item.name,
			metadata = item.metadata,
			profile = profile,
			entity = entity,
			equipped = true
		})
		if registered then
			C.feedback('Maleta equipada.')
		else
			C.feedback(C.errorMessage('container_prop_unavailable'), true)
		end
	end)
	if not started then return false, 'container_prop_busy' end
	return true
end

--- Guarda o container que está na mão (some o prop ou remove a arma nativa).
function C.storeContainerProp(containerId)
	if state.carriedContainerId ~= containerId then
		return false, 'container_not_carried'
	end
	if state.equippedWeapon and state.equippedWeapon.containerId == containerId then
		if not runCarryAnimation('container_stow', state.equippedWeapon, function()
			clearEquippedWeapon(true)
			C.feedback('Maleta guardada.')
		end) then
			return false, 'container_prop_busy'
		end
		return true
	end
	deleteContainerProp(containerId)
	return true
end

--- Garante controle de rede sobre a entidade do registro (aguarda até o limite).
local function ensureNetworkControl(entity)
	if not NetworkGetEntityIsNetworked(entity) or NetworkHasControlOfEntity(entity) then
		return true
	end
	NetworkRequestControlOfEntity(entity)
	return C.waitUntil(function() return NetworkHasControlOfEntity(entity) end, C.NETWORK_CONTROL_TIMEOUT_MS)
end

--- Pega o container na mão: reaproveita a entidade existente ou cria uma nova a partir do perfil.
--- Retorna `true` ou `false, codigoDeErro`.
function C.pickupContainerProp(itemName, containerId)
	if state.placement then
		return false, 'container_placement_active'
	end
	if type(containerId) ~= 'string' or containerId == '' then
		return false, 'container_id_missing'
	end
	if state.carriedContainerId and state.carriedContainerId ~= containerId then
		return false, 'container_prop_busy'
	end

	local existing = state.containerProps[containerId]
	if existing and existing.entity and DoesEntityExist(existing.entity) then
		if not ensureNetworkControl(existing.entity) then
			return false, 'container_prop_unavailable'
		end
		if attachContainerProp(existing) then
			return true
		end
		deleteContainerProp(containerId)
	end

	local profile = C.CONTAINER_PROFILES[itemName]
	if not profile then return false, 'container_prop_unavailable' end

	local entity = createContainerEntity(profile)
	if not entity then return false, 'container_prop_unavailable' end

	local registered = registerAndAttach({
		containerId = containerId,
		itemName = itemName,
		profile = profile,
		entity = entity
	})
	if not registered then return false, 'container_prop_unavailable' end
	return true
end

--- Remove props de containers que saíram do inventário (ex.: foram dados, soltos ou apagados).
function C.reconcileContainerProps(inventory)
	local present = {}
	for _, item in ipairs(inventory.items or {}) do
		if type(item) == 'table'
			and item.container
			and type(item.metadata) == 'table'
			and type(item.metadata.containerId) == 'string' then
			present[item.metadata.containerId] = true
		end
	end

	for containerId in pairs(state.containerProps) do
		if not present[containerId] then
			deleteContainerProp(containerId)
		end
	end
	if state.equippedWeapon and not present[state.equippedWeapon.containerId] then
		clearEquippedWeapon(true)
	end
end

--- Apaga todos os props de container e cancela o posicionamento em andamento.
function C.destroyAllContainerProps()
	state.placement = nil
	for containerId in pairs(state.containerProps) do
		deleteContainerProp(containerId)
	end
end
