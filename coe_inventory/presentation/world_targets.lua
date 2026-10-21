-- Containers soltos no mundo: opções "Abrir" e "Pegar" no coetarget.
-- O cliente só pede a ação; o servidor revalida posse, distância e existência do container.
local C = Inventory.Client
local state = C.state

local TARGET_DISTANCE = Config.Client.targetDistance
local TOO_FAR_DISTANCE = 8.0

--- NetId da entidade, ou nil se ela não for networked (props do mapa não são containers do servidor).
local function containerNetId(entity)
	if not NetworkGetEntityIsNetworked(entity) then return nil end
	local netId = NetworkGetNetworkIdFromEntity(entity)
	if netId and netId > 0 then
		return netId
	end
end

--- Envia ao servidor a ação sobre o container do mundo e guarda o pedido para casar com a resposta.
local function requestAction(eventName, netId)
	local requestId = C.nextWorldActionId()
	state.pendingWorldActions[requestId] = eventName
	if eventName == 'inventory.containerWorldOpen' then
		state.lastOpenNetId = netId
	end
	Core.Events.ToServer(eventName, requestId, netId)
end

local function buildTargetOptions()
	local function canInteract(entity)
		return containerNetId(entity) ~= nil
	end

	local function option(label, eventName)
		return {
			label = label,
			distance = TARGET_DISTANCE,
			canInteract = canInteract,
			onSelect = function(entity)
				local netId = containerNetId(entity)
				if netId then requestAction(eventName, netId) end
			end
		}
	end

	return {
		option(C.t('target_open'), 'inventory.containerWorldOpen'),
		option(C.t('target_pickup'), 'inventory.containerWorldPickup'),
		-- Fora do alcance a maleta não pode ficar muda: diz ao jogador o que fazer.
		{
			label = C.t('target_approach'),
			distance = TOO_FAR_DISTANCE,
			canInteract = function(entity, distance)
				return containerNetId(entity) ~= nil and distance > TARGET_DISTANCE
			end,
			onSelect = function()
				C.feedback(C.t('error_closer_needed'), true)
			end
		}
	}
end

--- Com uma maleta na mão, qualquer superfície mirada oferece "Colocar aqui".
function C.registerPlacementSurface()
	-- Nunca coloca além do alcance de Abrir/Pegar, para a maleta sempre poder ser usada de onde foi posta.
	local range = math.min(Config.Client.placementRange, TARGET_DISTANCE)
	Inventory.Target.AddSurface({
		{
			label = C.t('target_place_here'),
			distance = range,
			canInteract = function(entity)
				if not state.carriedContainerId or state.placement then return false end
				return entity == 0 or GetEntityType(entity) ~= 1
			end,
			onSelect = function(_, _, hit)
				if not hit then return end
				local ok, errorCode = C.placeContainerAt(state.carriedContainerId, hit)
				if not ok then
					C.feedback(C.errorMessage(errorCode, C.t('error_place_failed')), true)
				end
			end
		}
	})
end

--- Registra as opções em todos os modelos de container.
function C.registerWorldContainerModels()
	for _, modelName in pairs(C.WORLD_CONTAINER_MODELS) do
		Inventory.Target.AddModel(modelName, buildTargetOptions())
	end
end

--- Mantém o conjunto de containers do mundo conhecidos (informado pelo servidor).
function C.addWorldContainer(netId)
	state.worldTargets[netId] = true
end

function C.removeWorldContainer(netId)
	state.worldTargets[netId] = nil
end

--- Resposta do servidor a uma ação Abrir/Pegar feita pelo target.
function C.handleWorldActionResult(worldAction, success, errorMessage)
	if not success then
		C.feedback(C.errorMessage(errorMessage, C.t('error_interact_failed')), true)
	elseif worldAction == 'inventory.containerWorldPickup' then
		C.feedback(C.t('container_picked_up'))
	end
end
