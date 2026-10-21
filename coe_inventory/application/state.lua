-- Estado compartilhado, logging e validações básicas do serviço de inventário.
Inventory.Service = {}
local S = Inventory.Service

S.inventories = {}
S.WORLD_CONTAINERS_KEY = 'world:containers'
S.containerSequence = 0
S.openedContainers = {}
S.worldContainers = {}
-- itemName -> modelo do prop no mundo (vem de Config.Containers.items).
S.containerWorldModels = {}
for itemName, container in pairs(Config.Containers.items) do
	S.containerWorldModels[itemName] = container.model
end

local logger = CoeLogger.Create('coe_inventory')
S.log = logger.log

function S.isValidId(id)
	return type(id) == 'string'
		and #id > 0
		and #id <= 128
		and id:match('^[%w_:%-%.]+$') ~= nil
end

function S.isPositiveInteger(value)
	return type(value) == 'number' and value > 0 and value % 1 == 0
end

function S.generateContainerId()
	S.containerSequence = S.containerSequence + 1
	return ('container:%d:%d:%d'):format(os.time(), GetGameTimer(), S.containerSequence)
end


S.inventoryRequestTimes = {}
S.inventorySwapTimes = {}
S.containerSyncTimes = {}

S.inventoryActionTimes = {}
S.containerDropTimes = {}
