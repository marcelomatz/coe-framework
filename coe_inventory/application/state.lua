-- Estado compartilhado, logging, controle de concorrência lexicográfico e validações básicas do serviço de inventário.
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

local Algorithms = (Core and Core.Algorithms) or CoeAlgorithms
S.locks = (Algorithms and Algorithms.Concurrency) and Algorithms.Concurrency.newLockManager() or nil

local noopGuard = setmetatable({}, { __close = function() end })

---Adquire travas atômicas em ordem lexicográfica estrita sobre múltiplos inventários (compatível com `<close>`).
---@param keys string[]
---@param ownerSource? integer
---@return table|nil guard, string|nil err
function S.acquireInventoryLocks(keys, ownerSource, timeoutMs)
	if not S.locks then
		return noopGuard, nil
	end
	return S.locks:acquireMulti(keys, timeoutMs or 3000, ownerSource)
end

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
S.activeConsumptions = {}
