-- Ciclo de vida: playerDropped, inicialização e parada do resource.
local S = Inventory.Service

AddEventHandler('playerDropped', function()
	S.openedContainers[source] = nil
	S.inventoryRequestTimes[source] = nil
	S.inventorySwapTimes[source] = nil
	S.inventoryActionTimes[source] = nil
	S.containerDropTimes[source] = nil
	S.containerSyncTimes[source] = nil
	S.weaponAmmoTimes[source] = nil
	CreateThread(S.flushInventories)
end)

CreateThread(function()
	local waitingLogged = false
	while not Inventory.Persistence.IsReady() do
		local initialized, errorMessage = Inventory.Persistence.Initialize()
		if initialized then
			local orphans = S.cleanupOrphanContainerProps()
			if orphans > 0 then
				S.log('warn', 'persistence', 'orphan_container_props_removed', { count = orphans })
			end
			local purged, purgeError = S.purgeWorldContainers()
			local report = S.gcOrphanContainers(false)
			if report and report.orphans > 0 then
				S.log('warn', 'persistence', 'orphan_container_records_found', report)
			end
			if purged == false then
				S.log('error', 'persistence', 'world_container_purge_failed', {
					error_code = purgeError or 'unknown_error'
				})
			elseif purged > 0 then
				S.log('info', 'persistence', 'world_containers_purged', { count = purged })
			end
			return
		end

		-- Banco ainda subindo é esperado na inicialização: não é erro.
		if errorMessage == 'database_not_ready' then
			if not waitingLogged then
				S.log('info', 'persistence', 'database_waiting', {})
				waitingLogged = true
			end
			Wait(1000)
		else
			S.log('error', 'persistence', 'database_initialization_failed', {
				error_code = errorMessage or 'unknown_error',
				retry_ms = 5000
			})
			Wait(5000)
		end
	end
end)

AddEventHandler('onResourceStop', function(resourceName)
	if resourceName ~= GetCurrentResourceName() then return end
	S.flushInventories()
	for _, container in pairs(S.worldContainers) do
		if container.entity and DoesEntityExist(container.entity) then
			DeleteEntity(container.entity)
		end
	end
	-- Varredura final: remove também props de container que não estavam rastreados.
	S.worldContainers = {}
	S.cleanupOrphanContainerProps()
end)

-- Uso: coe_clean_containers (somente console do servidor). Remove props de container não registrados.
RegisterCommand('coe_clean_containers', function(source)
	if source ~= 0 then return end
	local tracked = 0
	for _, c in pairs(S.worldContainers) do if c.entity then tracked = tracked + 1 end end
	print(('[coe_inventory] props rastreados mantidos: %d'):format(tracked))
	print(('[coe_inventory] props órfãos removidos: %d'):format(S.cleanupOrphanContainerProps()))
end, true)

-- Uso: coe_gc_containers [apply] (somente console). Sem `apply` só relata os registros órfãos.
RegisterCommand('coe_gc_containers', function(source, args)
	if source ~= 0 then return end
	local report, reason = S.gcOrphanContainers(args[1] == 'apply')
	if not report then
		print(('[coe_inventory] varredura falhou: %s'):format(tostring(reason)))
		return
	end
	print(('[coe_inventory] containers=%d órfãos=%d removidos=%d'):format(report.scanned, report.orphans, report.removed))
	if report.orphans > 0 and args[1] ~= 'apply' then
		print('[coe_inventory] use `coe_gc_containers apply` para remover')
	end
end, true)

-- Despejo periódico de inventários ociosos do cache.
local function scheduleEviction()
	SetTimeout(60000, function()
		S.evictIdleInventories()
		scheduleEviction()
	end)
end
scheduleEviction()

-- Flush periódico das reorganizações pendentes (ver S.markInventoryDirty).
local function scheduleFlush()
	local interval = Config.Server.flushIntervalMs
	if interval <= 0 then return end
	SetTimeout(interval, function()
		S.flushInventories()
		scheduleFlush()
	end)
end
scheduleFlush()
