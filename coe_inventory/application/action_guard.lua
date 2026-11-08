-- Rate limit (GCRA O(1)), limpeza por jogador e resposta padrão das ações.
local S = Inventory.Service

local Algorithms = (Core and Core.Algorithms) or CoeAlgorithms
S.actionRateLimiter = (Algorithms and Algorithms.RateLimit)
	and Algorithms.RateLimit.newGCRA(Config.Server.rateLimits.actionMs, 0)
	or nil
S.dropRateLimiter = (Algorithms and Algorithms.RateLimit)
	and Algorithms.RateLimit.newGCRA(Config.Server.rateLimits.dropMs, 0)
	or nil

Core.Events.On('player.characterUnloaded', function(event)
	if type(event) ~= 'table' or not Core.Functions.IsInteger(event.source) then
		return
	end
	local session = Core.SessionRegistry.Get(event.source)
	if not session or session.generation ~= event.generation then
		return
	end

	S.openedContainers[event.source] = nil
	S.inventoryRequestTimes[event.source] = nil
	S.inventorySwapTimes[event.source] = nil
	S.inventoryActionTimes[event.source] = nil
	S.containerDropTimes[event.source] = nil
	S.containerSyncTimes[event.source] = nil
	S.weaponAmmoTimes[event.source] = nil
	S.activeConsumptions[event.source] = nil
	if S.actionRateLimiter then
		S.actionRateLimiter:reset(event.source)
	end
	if S.dropRateLimiter then
		S.dropRateLimiter:reset(event.source)
	end
	if S.locks then
		S.locks:purgeOwner(event.source)
	end
	CreateThread(S.flushInventories)
end)

function S.sendActionResult(playerId, requestId, success, errorMessage, reason)
	-- Falhas ficam visíveis no log padrão para diagnosticar interações recusadas.
	S.log(success and 'debug' or 'warn', 'gameplay', 'inventory_action_completed', {
		error_code = not success and errorMessage or nil,
		player_id = playerId,
		reason = not success and reason or nil,
		request_id = requestId,
		result = success == true
	})
	Core.Events.ToClient(playerId, 'inventory.actionResult', requestId, success, errorMessage)
end

function S.allowInventoryAction(playerId)
	local now = GetGameTimer()
	if S.actionRateLimiter then
		if S.inventoryActionTimes[playerId] == nil then
			S.actionRateLimiter:reset(playerId)
		end
		local allowed = S.actionRateLimiter:allow(playerId, now, 1)
		if not allowed then
			return false
		end
		S.inventoryActionTimes[playerId] = now
		return true
	end

	local lastAction = S.inventoryActionTimes[playerId]
	if lastAction and now - lastAction < Config.Server.rateLimits.actionMs then
		return false
	end

	S.inventoryActionTimes[playerId] = now
	return true
end

function S.allowContainerDrop(playerId)
	local now = GetGameTimer()
	if S.dropRateLimiter then
		if S.containerDropTimes[playerId] == nil then
			S.dropRateLimiter:reset(playerId)
		end
		local allowed = S.dropRateLimiter:allow(playerId, now, 1)
		if not allowed then
			return false
		end
		S.containerDropTimes[playerId] = now
		return true
	end

	local previous = S.containerDropTimes[playerId]
	if previous and now - previous < Config.Server.rateLimits.dropMs then
		return false
	end
	S.containerDropTimes[playerId] = now
	return true
end
