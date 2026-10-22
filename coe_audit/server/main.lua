local config = CoeAuditConfig
local ready = false

local function log(level, category, event, context)
	pcall(function()
		return exports.coe_logging:Log(level, category, event, context)
	end)
end

local function getLicense(playerId)
	for _, identifier in ipairs(GetPlayerIdentifiers(playerId)) do
		if identifier:sub(1, 8) == 'license:' then
			return identifier
		end
	end
	return ''
end

local writer = AuditWriter.New({
	maxSize = config.Queue.MaxSize,
	batchSize = config.Queue.BatchSize,
	maxBackoffMs = config.Queue.MaxBackoffMs,
	now = GetGameTimer,
	insertBatch = AuditPersistence.InsertBatch
})

-- Aceita o evento na fila e retorna imediatamente; a gravação é assíncrona.
exports('Record', function(severity, category, event, context)
	local entry, errorCode = AuditEntry.Build({
		resource = GetInvokingResource(),
		severity = severity,
		category = category,
		event = event,
		context = context,
		timestamp = os.time(),
		isAllowed = function(resource)
			return CoeAccess.Allowed(resource, config.Ace, config.AllowedResources)
		end,
		allowedFields = config.AllowedContextFields,
		resolveLicense = getLicense,
		encode = json.encode
	})
	if not entry then
		return false, errorCode
	end
	return writer.Enqueue(entry)
end)

exports('IsReady', function()
	return ready
end)

local function purgeExpired()
	local days = GetConvarInt('coe_audit_retention_days', config.RetentionDays)
	if days <= 0 then
		return
	end
	repeat
		local removed, errorCode = AuditPersistence.Purge(days, config.PurgeBatchSize)
		if not removed then
			log('error', 'persistence', 'audit_purge_failed', { error_code = errorCode or 'database_error' })
			return
		end
		log('info', 'audit', 'audit_purge_completed', { count = removed })
	until removed < config.PurgeBatchSize
end

CreateThread(function()
	local waitingLogged = false
	while true do
		local initialized, errorCode = AuditPersistence.Initialize()
		if initialized then
			break
		end
		-- Banco ainda subindo é esperado na inicialização: não é erro.
		if errorCode == 'database_not_ready' then
			if not waitingLogged then
				log('info', 'persistence', 'database_waiting', {})
				waitingLogged = true
			end
			Wait(1000)
		else
			log('error', 'persistence', 'database_initialization_failed', {
				error_code = errorCode or 'database_error',
				retry_ms = 5000
			})
			Wait(5000)
		end
	end

	ready = true
	purgeExpired()

	local failureLogged = false
	while true do
		local ok, flushError = writer.Flush()
		if not ok and flushError ~= 'backoff' and flushError ~= 'busy' then
			if not failureLogged then
				log('error', 'persistence', 'audit_flush_failed', {
					error_code = flushError or 'database_error',
					count = writer.Pending()
				})
				failureLogged = true
			end
		elseif ok then
			failureLogged = false
		end

		local dropped = writer.TakeDropped()
		if dropped > 0 then
			log('error', 'audit', 'audit_queue_overflow', { count = dropped })
		end

		-- Com backlog, drena sem esperar o intervalo.
		if ok and writer.Pending() > 0 then
			Wait(0)
		else
			Wait(config.Queue.FlushIntervalMs)
		end
	end
end)

AddEventHandler('onResourceStop', function(resourceName)
	if resourceName ~= GetCurrentResourceName() or not ready then
		return
	end
	-- Melhor esforço: tenta esvaziar a fila antes de parar.
	for _ = 1, 10 do
		if writer.Pending() == 0 then
			return
		end
		local ok, errorCode = writer.Flush()
		if not ok and errorCode == 'backoff' then
			break
		end
	end
	if writer.Pending() > 0 then
		log('error', 'audit', 'audit_events_lost_on_stop', { count = writer.Pending() })
	end
end)
