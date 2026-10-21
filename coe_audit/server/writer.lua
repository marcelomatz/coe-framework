-- Fila limitada em memória com envio em lote e backoff exponencial.
-- Nunca bloqueia o chamador: o envio acontece em Flush(), chamado por uma thread.
AuditWriter = {}

function AuditWriter.New(options)
	local queue = {}
	local writer = {}
	local flushing = false
	local failures = 0
	local nextAttemptAt = 0
	local dropped = 0

	function writer.Enqueue(entry)
		if #queue >= options.maxSize then
			dropped = dropped + 1
			return false, 'queue_full'
		end
		queue[#queue + 1] = entry
		return true
	end

	function writer.Pending()
		return #queue
	end

	-- Retorna e zera o contador de eventos descartados por fila cheia.
	function writer.TakeDropped()
		local count = dropped
		dropped = 0
		return count
	end

	function writer.Failures()
		return failures
	end

	function writer.Flush()
		if flushing then
			return false, 'busy'
		end
		if #queue == 0 then
			return true, nil, 0
		end
		if options.now() < nextAttemptAt then
			return false, 'backoff'
		end

		local size = math.min(#queue, options.batchSize)
		local batch = {}
		for index = 1, size do
			batch[index] = queue[index]
		end

		flushing = true
		local called, ok, errorCode = pcall(options.insertBatch, batch)
		flushing = false

		if called and ok then
			table.move(queue, size + 1, #queue + size, 1)
			failures = 0
			nextAttemptAt = 0
				return true, nil, size
		end

		failures = failures + 1
		local delay = math.min(options.maxBackoffMs, 1000 * 2 ^ (failures - 1))
		nextAttemptAt = options.now() + delay
		return false, called and errorCode or 'insert_failed'
	end

	return writer
end
