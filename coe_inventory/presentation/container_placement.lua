-- Posicionamento de containers no mundo: o jogador mira, confirma com E e o cliente cria uma
-- entidade networked que o servidor valida e adota (`inventory.containerDrop`).
local C = Inventory.Client
local state = C.state

local CONTROL_CONFIRM = 38 -- E
local CONTROL_CANCEL_PRIMARY = 194 -- BACKSPACE
local CONTROL_CANCEL_SECONDARY = 177 -- ESC / botão B
local PLACEMENT_RANGE = Config.Client.placementRange
local PLACEMENT_RAY_FLAGS = 511 -- mundo, veículos, peds, objetos...
local PLACEMENT_RAY_WAIT_MS = 100
local PREVIEW_ALPHA = Config.Client.placementPreviewAlpha

--- Ponto no mundo onde o prop deve ficar: onde a mira da câmera acerta, ou à frente do ped
--- (ajustado ao chão) quando nada é atingido. A altura é corrigida pela base do modelo.
local function adjustToModelBase(position, record)
	local modelHash = C.resolveModelHash(record.profile.model)
	if modelHash then
		local minimum = GetModelDimensions(modelHash)
		return vector3(position.x, position.y, position.z - minimum.z)
	end
	return position
end

local function getPlacementPoint(playerPed, record)
	local cameraPosition = GetGameplayCamCoord()
	local cameraRotation = GetGameplayCamRot(2)
	local pitch = math.rad(cameraRotation.x)
	local yaw = math.rad(cameraRotation.z)
	local horizontal = math.abs(math.cos(pitch))
	local direction = {
		x = -math.sin(yaw) * horizontal,
		y = math.cos(yaw) * horizontal,
		z = math.sin(pitch)
	}

	local ray = StartShapeTestRay(
		cameraPosition.x, cameraPosition.y, cameraPosition.z,
		cameraPosition.x + direction.x * PLACEMENT_RANGE,
		cameraPosition.y + direction.y * PLACEMENT_RANGE,
		cameraPosition.z + direction.z * PLACEMENT_RANGE,
		PLACEMENT_RAY_FLAGS,
		playerPed,
		7
	)
	local resultState, hit, hitPosition
	local startedAt = GetGameTimer()
	repeat
		resultState, hit, hitPosition = GetShapeTestResult(ray)
		if resultState == 1 then Wait(0) end
	until resultState ~= 1 or GetGameTimer() - startedAt >= PLACEMENT_RAY_WAIT_MS

	local position
	if hit == 1 then
		position = hitPosition
	else
		position = GetOffsetFromEntityInWorldCoords(playerPed, 0.0, 1.2, 0.0)
		local foundGround, groundZ = GetGroundZFor_3dCoord(position.x, position.y, position.z + 1.5, false)
		if foundGround then position = vector3(position.x, position.y, groundZ) end
	end

	return adjustToModelBase(position, record)
end

--- Cria a versão networked e congelada do prop no ponto escolhido.
--- Retorna `entity, netId` ou nil em caso de falha.
local function createNetworkedProp(record, position, heading)
	local modelHash = C.resolveModelHash(record.profile.model)
	if not modelHash or not C.loadModel(modelHash) then return nil end

	local entity = CreateObject(modelHash, position.x, position.y, position.z, true, true, false)
	SetModelAsNoLongerNeeded(modelHash)
	if entity == 0 or not DoesEntityExist(entity) then return nil end

	SetEntityAsMissionEntity(entity, true, true)
	SetEntityCoordsNoOffset(entity, position.x, position.y, position.z, false, false, false)
	SetEntityHeading(entity, heading)
	SetEntityCollision(entity, true, true)
	SetEntityVisible(entity, true, false)
	FreezeEntityPosition(entity, true)

	local netId = NetworkGetNetworkIdFromEntity(entity)
	if not netId or netId < 1 then
		DeleteEntity(entity)
		return nil
	end
	SetNetworkIdExistsOnAllMachines(netId, true)
	SetNetworkIdCanMigrate(netId, true)
	return entity, netId
end

--- Confirma a posição: cria a entidade networked e pede ao servidor para registrar o drop.
--- O prop de preview some; a resposta chega em `C.handleDropResult`.
local function confirmPlacement(record, position)
	local heading = GetEntityHeading(record.entity)
	local worldEntity, netId = createNetworkedProp(record, position, heading)
	if not worldEntity then
		C.attachContainerProp(record)
		C.feedback('Não foi possível criar a entidade da maleta.', true)
		return
	end

	SetEntityVisible(record.entity, false, false)
	SetEntityCollision(record.entity, false, false)
	local requestId = C.nextWorldActionId()
	state.pendingDrops[requestId] = { record = record, entity = worldEntity }
	Core.Events.ToServer(
		'inventory.containerDrop',
		requestId,
		record.containerId,
		netId,
		{ x = position.x, y = position.y, z = position.z },
		heading
	)
end

--- Resolve o registro do container carregado para posicioná-lo.
--- Retorna `record` ou `nil, codigoDeErro`.
local function resolvePlacementRecord(containerId)
	if state.placement then
		return nil, 'container_placement_active'
	end
	if state.carriedContainerId ~= containerId then
		return nil, 'container_not_carried'
	end

	local record = state.containerProps[containerId]
	if not record and state.equippedWeapon and state.equippedWeapon.containerId == containerId then
		-- A arma nativa vira apenas o prop de preview enquanto o jogador escolhe o local.
		record = state.equippedWeapon
		state.containerProps[containerId] = record
		C.releaseCarry(record)
		state.equippedWeapon = nil
	end
	if not record or not DoesEntityExist(record.entity) then
		C.deleteContainerProp(containerId)
		return nil, 'container_prop_unavailable'
	end
	return record
end

--- Coloca o container carregado direto num ponto da superfície escolhida pelo target.
--- Retorna `true` ou `false, codigoDeErro`.
function C.placeContainerAt(containerId, surfacePoint)
	local record, errorCode = resolvePlacementRecord(containerId)
	if not record then return false, errorCode end

	local playerPed = PlayerPedId()
	DetachEntity(record.entity, true, true)
	SetEntityCollision(record.entity, false, false)
	SetEntityHeading(record.entity, GetEntityHeading(playerPed))
	confirmPlacement(record, adjustToModelBase(surfacePoint, record))
	return true
end

--- Inicia o modo de posicionamento por mira do container carregado.
--- Retorna `true` ou `false, codigoDeErro`.
function C.placeContainerProp(containerId)
	local record, errorCode = resolvePlacementRecord(containerId)
	if not record then return false, errorCode end

	DetachEntity(record.entity, true, true)
	SetEntityVisible(record.entity, true, false)
	SetEntityCollision(record.entity, false, false)
	SetEntityAlpha(record.entity, PREVIEW_ALPHA, false)
	state.placement = { containerId = containerId, record = record }

	CreateThread(function()
		while state.placement and state.placement.containerId == containerId do
			Wait(0)
			local playerPed = PlayerPedId()
			local position = getPlacementPoint(playerPed, record)
			SetEntityCoordsNoOffset(record.entity, position.x, position.y, position.z, false, false, false)
			SetEntityHeading(record.entity, GetEntityHeading(playerPed))
			BeginTextCommandDisplayHelp('STRING')
			AddTextComponentSubstringPlayerName('Mire para o local desejado. Pressione E para colocar ou BACKSPACE para cancelar.')
			EndTextCommandDisplayHelp(0, false, true, -1)

			if IsControlJustPressed(0, CONTROL_CONFIRM) then
				state.placement = nil
				confirmPlacement(record, position)
			elseif IsControlJustPressed(0, CONTROL_CANCEL_PRIMARY) or IsControlJustPressed(0, CONTROL_CANCEL_SECONDARY) then
				state.placement = nil
				C.attachContainerProp(record)
			end
		end
	end)
	return true
end

--- Resposta do servidor ao drop. Em sucesso o container passa a existir só no mundo;
--- em falha o prop volta para a mão e a entidade networked é descartada.
function C.handleDropResult(requestId, success, result)
	local pending = state.pendingDrops[requestId]
	if not pending then return end
	state.pendingDrops[requestId] = nil

	local record = pending.record
	if success then
		state.containerProps[record.containerId] = nil
		if record.equipped then
			C.releaseCarry(record)
			state.equippedWeapon = nil
		end
		if state.carriedContainerId == record.containerId then state.carriedContainerId = nil end
		if DoesEntityExist(record.entity) then DeleteEntity(record.entity) end
		C.syncCarriedState()
		C.feedback('Maleta colocada no mundo.')
		return
	end

	if DoesEntityExist(pending.entity) then DeleteEntity(pending.entity) end
	if DoesEntityExist(record.entity) then
		SetEntityVisible(record.entity, true, false)
		C.attachContainerProp(record)
	end
	C.feedback(C.errorMessage(result, C.t('error_place_failed')), true)
end
