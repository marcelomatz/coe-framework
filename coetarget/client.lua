-- Registros: chave (entidade/modelo/tipo) -> { [resource dono] = opções }.
local entityTargets = {}
local modelTargets = {}
local globalTargets = { player = {}, ped = {}, vehicle = {}, object = {} }
-- Opções de superfície: valem para qualquer ponto mirado (mapa ou entidade), recebendo as coordenadas do acerto.
local surfaceTargets = {}

local targetHeld = false
local targetToggled = false
local currentEntity = 0
local uiVisible = false
local uiHasTarget = false
local uiInteractive = false
local uiOptionSignature = ''
-- Modo de escolha: após o clique, as opções ficam congeladas e o mouse seleciona uma delas.
local menu = nil

local function invokingResource()
	if type(GetInvokingResource) == 'function' then
		return GetInvokingResource() or 'unknown'
	end
	return 'unknown'
end

local function updateTargetUi(visible, hasTarget, labels, interactive)
	labels = labels or {}
	interactive = interactive == true
	local signature = table.concat(labels, '\31')
	if uiVisible == visible and uiHasTarget == hasTarget
		and uiInteractive == interactive and uiOptionSignature == signature then
		return
	end

	uiVisible = visible
	uiHasTarget = hasTarget
	uiInteractive = interactive
	uiOptionSignature = signature
	SendNUIMessage({
		action = 'targetState',
		visible = visible,
		hasTarget = hasTarget,
		interactive = interactive,
		optionCount = #labels,
		options = labels
	})
end

local function menuLabels()
	local labels = {}
	for index, option in ipairs(menu.options) do
		labels[index] = option.label
	end
	return labels
end

local function closeMenu()
	if not menu then
		return
	end
	menu = nil
	-- Soltar a tecla com o foco na NUI não dispara -coetarget; zera para não travar a mira ligada.
	targetHeld = false
	SetNuiFocus(false, false)
	updateTargetUi(false, false)
end

local function openMenu(entity, options, hit)
	menu = { entity = entity, options = options, hit = hit }
	SetNuiFocus(true, true)
	SetCursorLocation(0.5, 0.5)
	updateTargetUi(true, true, menuLabels(), true)
end

local function normalizeModel(model)
	if type(model) == 'string' then
		return GetHashKey(model)
	end
	return model
end

-- Callbacks vindos de outro resource por export chegam como funcref (tabela chamável), não como function.
local function isCallable(value)
	if type(value) == 'function' then
		return true
	end
	local meta = type(value) == 'table' and getmetatable(value)
	return type(meta) == 'table' and meta.__call ~= nil
end

local function validOptions(options)
	if type(options) ~= 'table' then
		return false
	end
	for _, option in ipairs(options) do
		if type(option) ~= 'table' or type(option.label) ~= 'string' or not isCallable(option.onSelect) then
			return false
		end
	end
	return true
end

local function register(registry, key, options)
	registry[key] = registry[key] or {}
	registry[key][invokingResource()] = options
end

local function unregister(registry, key)
	local owners = registry[key]
	if not owners then
		return
	end
	owners[invokingResource()] = nil
	if next(owners) == nil then
		registry[key] = nil
	end
end

local function AddTargetEntity(entity, options)
	if not DoesEntityExist(entity) or not validOptions(options) then
		return false
	end
	register(entityTargets, entity, options)
	return true
end

local function RemoveTargetEntity(entity)
	unregister(entityTargets, entity)
end

local function AddTargetModel(model, options)
	if not validOptions(options) then
		return false
	end
	register(modelTargets, normalizeModel(model), options)
	return true
end

local function RemoveTargetModel(model)
	unregister(modelTargets, normalizeModel(model))
end

-- Opções para todas as entidades de um tipo: 'player', 'ped' (NPCs), 'vehicle' ou 'object'.
local function AddTargetGlobal(entityType, options)
	if not globalTargets[entityType] or not validOptions(options) then
		return false
	end
	register(globalTargets[entityType], 'all', options)
	return true
end

local function RemoveTargetGlobal(entityType)
	if globalTargets[entityType] then
		unregister(globalTargets[entityType], 'all')
	end
end

-- Opções para qualquer superfície mirada. `canInteract(entity, distance, hit)` e `onSelect(entity, option, hit)`
-- recebem `hit` (vector3 do ponto atingido); `entity` é 0 quando a mira acerta o mapa.
local function AddTargetSurface(options)
	if not validOptions(options) then
		return false
	end
	register(surfaceTargets, 'all', options)
	return true
end

local function RemoveTargetSurface()
	unregister(surfaceTargets, 'all')
end

exports('AddTargetSurface', AddTargetSurface)
exports('RemoveTargetSurface', RemoveTargetSurface)
exports('AddTargetEntity', AddTargetEntity)
exports('RemoveTargetEntity', RemoveTargetEntity)
exports('AddTargetModel', AddTargetModel)
exports('RemoveTargetModel', RemoveTargetModel)
exports('AddTargetGlobal', AddTargetGlobal)
exports('RemoveTargetGlobal', RemoveTargetGlobal)

local function removeOwner(registry, owner)
	for key, owners in pairs(registry) do
		owners[owner] = nil
		if next(owners) == nil then
			registry[key] = nil
		end
	end
end

-- Resources que param não podem deixar opções (e callbacks mortos) registradas.
AddEventHandler('onClientResourceStop', function(resourceName)
	removeOwner(entityTargets, resourceName)
	removeOwner(modelTargets, resourceName)
	removeOwner(surfaceTargets, resourceName)
	for _, registry in pairs(globalTargets) do
		removeOwner(registry, resourceName)
	end
end)

local function getCameraDirection()
	local rotation = GetGameplayCamRot(2)
	local pitch = math.rad(rotation.x)
	local yaw = math.rad(rotation.z)
	local pitchScale = math.abs(math.cos(pitch))

	return vector3(
		-math.sin(yaw) * pitchScale,
		math.cos(yaw) * pitchScale,
		math.sin(pitch)
	)
end

local function castRay(origin, destination, ped)
	local ray = StartShapeTestRay(
		origin.x, origin.y, origin.z,
		destination.x, destination.y, destination.z,
		511, ped, 7
	)
	local status, hit, endCoords, _, entity = GetShapeTestResult(ray)

	if status == 1 then
		local deadline = GetGameTimer() + 250
		while status == 1 and GetGameTimer() < deadline do
			Wait(0)
			status, hit, endCoords, _, entity = GetShapeTestResult(ray)
		end
	end
	return hit, endCoords, entity
end

-- Props presos ao próprio jogador (maleta na mão, arma) não são alvo: o raio os atravessa.
local function attachedToPlayer(entity, ped)
	return entity ~= 0 and DoesEntityExist(entity) and IsEntityAttachedToEntity(entity, ped)
end

local function raycastTarget()
	local ped = PlayerPedId()
	local origin = GetGameplayCamCoord()
	local direction = getCameraDirection()
	local destination = origin + direction * Config.MaxDistance
	local hit, endCoords, entity = castRay(origin, destination, ped)

	if hit == 1 and attachedToPlayer(entity, ped) then
		hit, endCoords, entity = castRay(endCoords + direction * 0.15, destination, ped)
	end

	if hit ~= 1 then
		return 0, nil
	end
	if entity ~= 0 and DoesEntityExist(entity) and not attachedToPlayer(entity, ped) then
		return entity, endCoords
	end

	return 0, endCoords
end

local function globalCategory(entity)
	local entityType = GetEntityType(entity)
	if entityType == 1 then
		return IsPedAPlayer(entity) and 'player' or 'ped'
	end
	if entityType == 2 then
		return 'vehicle'
	end
	if entityType == 3 then
		return 'object'
	end
end

local function collectFrom(options, owners, entity, distance, hit)
	if not owners then
		return
	end
	for _, list in pairs(owners) do
		for _, option in ipairs(list) do
			local maxDistance = option.distance or Config.DefaultOptionDistance
			if distance <= maxDistance then
				local allowed = true
				if option.canInteract then
					local ok, result = pcall(option.canInteract, entity, distance, hit)
					allowed = ok and result == true
				end
				if allowed then
					options[#options + 1] = option
				end
			end
		end
	end
end

-- Só devolve opções que algum resource registrou; entidades sem interação não listam nada.
local function getOptions(entity, hit)
	local options = {}
	local playerCoords = GetEntityCoords(PlayerPedId())

	if entity ~= 0 then
		local distance = #(playerCoords - GetEntityCoords(entity))
		collectFrom(options, entityTargets[entity], entity, distance, hit)
		collectFrom(options, modelTargets[GetEntityModel(entity)], entity, distance, hit)
		local category = globalCategory(entity)
		if category then
			collectFrom(options, globalTargets[category].all, entity, distance, hit)
		end
	end
	if hit then
		collectFrom(options, surfaceTargets.all, entity, #(playerCoords - hit), hit)
	end
	return options
end

RegisterCommand('+coetarget', function()
	targetHeld = true
end, false)

RegisterCommand('-coetarget', function()
	targetHeld = false
end, false)

RegisterKeyMapping('+coetarget', 'Ativar/desativar mira do target', 'keyboard', Config.DefaultKey)

RegisterCommand(Config.Command, function()
	targetToggled = not targetToggled
end, false)

-- Remove registros de entidades que deixaram de existir (handles podem ser reaproveitados).
CreateThread(function()
	while true do
		for entity in pairs(entityTargets) do
			if not DoesEntityExist(entity) then
				entityTargets[entity] = nil
			end
		end
		Wait(5000)
	end
end)

local function runOption(entity, option, hit)
	local ok, err = pcall(option.onSelect, entity, option, hit)
	if not ok then
		print(('[coetarget] erro em "%s": %s'):format(option.label, tostring(err)))
	end
end

-- A opção só executa se ainda existir para a entidade (alcance, canInteract e dono do registro).
RegisterNUICallback('menuSelect', function(data, callback)
	callback({ success = true })
	if not menu then
		return
	end

	local entity, options, hit = menu.entity, menu.options, menu.hit
	if entity ~= 0 and hit and not DoesEntityExist(entity) then entity = 0 end
	local index = type(data) == 'table' and tonumber(data.index) or nil
	closeMenu()
	if not index or index % 1 ~= 0 or (entity ~= 0 and not DoesEntityExist(entity) and not hit) then
		return
	end
	local option = options[index]
	for _, current in ipairs(option and getOptions(entity, hit) or {}) do
		if current == option then
			runOption(entity, option, hit)
			break
		end
	end
end)

RegisterNUICallback('menuClose', function(_, callback)
	callback({ success = true })
	closeMenu()
end)

AddEventHandler('onResourceStop', function(resourceName)
	if resourceName == GetCurrentResourceName() and menu then
		SetNuiFocus(false, false)
	end
end)

CreateThread(function()
	-- O raycast e as opções rodam em quadros alternados; o clique é lido em todo quadro.
	local frame, entity, hit, options = 0, 0, nil, {}
	while true do
		if menu then
			frame = 0
			-- O ponto clicado vale mais que a origem da entidade (props grandes têm a origem longe de onde se mira).
			local anchor = menu.hit
			if not anchor and menu.entity ~= 0 and DoesEntityExist(menu.entity) then
				anchor = GetEntityCoords(menu.entity)
			end
			if not anchor
				or #(GetEntityCoords(PlayerPedId()) - anchor) > Config.MaxDistance then
				closeMenu()
			end
			Wait(100)
		elseif not targetHeld and not targetToggled then
			frame = 0
			updateTargetUi(false, false)
			currentEntity = 0
			Wait(150)
		else
			DisableControlAction(0, 24, true)
			DisableControlAction(0, 25, true)
			DisableControlAction(0, 14, true)
			DisableControlAction(0, 15, true)
			DisableControlAction(0, 16, true)
			DisableControlAction(0, 17, true)
			DisableControlAction(0, 140, true)
			DisableControlAction(0, 141, true)
			DisableControlAction(0, 142, true)

			if frame % 2 == 0 then
				entity, hit = raycastTarget()
				currentEntity = entity
				options = hit and getOptions(entity, hit) or (entity ~= 0 and getOptions(entity) or {})
				if #options > 0 then
					local labels = {}
					for index, option in ipairs(options) do
						labels[index] = option.label
					end
					updateTargetUi(true, true, labels)
				elseif entity ~= 0 then
					updateTargetUi(true, true)
				else
					updateTargetUi(true, false)
				end
			end
			frame = frame + 1

			-- Os controles de ataque estão desabilitados, então o clique é lido como desabilitado.
			if #options > 0 and IsDisabledControlJustPressed(0, 24) then
				openMenu(entity, options, hit)
			end

			Wait(0)
		end
	end
end)

-- Avisa os resources para registrarem seus alvos novamente após um restart do coetarget.
CreateThread(function()
	Wait(0)
	TriggerEvent('coetarget:ready')
end)

RegisterCommand('targetdebug', function()
	local entity = raycastTarget()
	if entity == 0 then
		print('[coetarget] nenhuma entidade sob a mira (olhe para o objeto e rode /targetdebug)')
		return
	end
	local netId = NetworkGetEntityIsNetworked(entity) and NetworkGetNetworkIdFromEntity(entity) or 0
	local distance = #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(entity))
	print(('[coetarget] entidade=%s modelo=%s tipo=%s netId=%s distância=%.2f opções=%s'):format(
		entity, GetEntityModel(entity), GetEntityType(entity), netId, distance, #getOptions(entity)))
	for key, owners in pairs({ [GetEntityModel(entity)] = modelTargets[GetEntityModel(entity)] or {} }) do
		for owner, list in pairs(owners) do
			for _, option in ipairs(list) do
				local ok, result = true, nil
				if option.canInteract then ok, result = pcall(option.canInteract, entity, distance, hit) end
				print(('[coetarget] modelo=%s dono=%s opção=%s dist=%s canInteract=%s/%s'):format(
					key, owner, option.label, tostring(option.distance), tostring(ok), tostring(result)))
			end
		end
	end
end, false)
