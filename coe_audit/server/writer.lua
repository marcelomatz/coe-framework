-- Fila circular limitada em memória O(1) com envio em lote e backoff exponencial.
-- Nunca bloqueia o chamador: o envio acontece em Flush(), chamado por uma thread.
AuditWriter = {}

function AuditWriter.New(options)
	local maxSize = options.maxSize or 1000
	local queue = {}
	local head = 1
	local tail = 0
	local count = 0
	local writer = {}
	local flushing = false
	local failures = 0
	local nextAttemptAt = 0
	local dropped = 0

	function writer.Enqueue(entry)
		if count >= maxSize then
			dropped = dropped + 1
			return false, 'queue_full'
		end
		tail = (tail % maxSize) + 1
		queue[tail] = entry
		count = count + 1
		return true
	end

	function writer.Pending()
		return count
	end

	-- Retorna e zera o contador de eventos descartados por fila cheia.
	function writer.TakeDropped()
		local c = dropped
		dropped = 0
		return c
	end

	function writer.Failures()
		return failures
	end

	function writer.Flush()
		if flushing then
			return false, 'busy'
		end
		if count == 0 then
			return true, nil, 0
		end
		if options.now() < nextAttemptAt then
			return false, 'backoff'
		end

		local size = math.min(count, options.batchSize)
		local batch = {}
		for index = 1, size do
			local pos = ((head + index - 2) % maxSize) + 1
			batch[index] = queue[pos]
		end

		flushing = true
		local called, ok, errorCode = pcall(options.insertBatch, batch)
		flushing = false

		if called and ok then
			for _ = 1, size do
				queue[head] = nil
				head = (head % maxSize) + 1
				count = count - 1
			end
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
