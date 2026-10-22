dofile('../coe_core/lib/access.lua')
dofile('../coe_audit/config.lua')
dofile('../coe_audit/server/migrations.lua')
dofile('../coe_audit/server/entry.lua')
dofile('../coe_audit/server/writer.lua')

local function assertEqual(actual, expected, message)
	if actual ~= expected then
		error(('%s: expected %s, got %s'):format(message, tostring(expected), tostring(actual)))
	end
end

local config = CoeAuditConfig
local encode = function() return '{}' end
local function build(overrides)
	local options = {
		resource = 'coe_core',
		severity = 'info',
		category = 'audit',
		event = 'admin_item_granted',
		context = { source = 3, target = 5, item = 'water', count = 2, ignored = 'x' },
		timestamp = 0,
		allowedResources = config.AllowedResources,
		allowedFields = config.AllowedContextFields,
		resolveLicense = function(id) return id == 3 and 'license:aaa' or nil end,
		encode = function(context)
			assertEqual(context.ignored, nil, 'campo fora da allowlist removido')
			return '{"ok":true}'
		end
	}
	for key, value in pairs(overrides or {}) do
		options[key] = value
	end
	return AuditEntry.Build(options)
end

-- entrada válida
local entry = build()
assertEqual(entry.occurred_at, '1970-01-01 00:00:00', 'timestamp UTC')
assertEqual(entry.actor_license, 'license:aaa', 'licença do ator resolvida')
assertEqual(entry.target_license, '', 'alvo offline fica vazio')
assertEqual(entry.context_json, '{"ok":true}', 'contexto codificado')
assertEqual(entry.resource, 'coe_core', 'resource vem do chamador')

-- Pacotes e scripts de terceiros entram por ACE (resource.<nome> coe.audit), não pela lista do framework.
assertEqual(config.AllowedResources.coe_admin, nil, 'padrão só lista resources do framework')
local aceGranted = { ['resource.coe_admin|coe.audit'] = true }
IsPrincipalAceAllowed = function(principal, ace) return aceGranted[principal .. '|' .. ace] == true end
local function viaAce(resource)
	return AuditEntry.Build({
		resource = resource, severity = 'info', category = 'audit', event = 'x', timestamp = 0,
		isAllowed = function(name) return CoeAccess.Allowed(name, config.Ace, config.AllowedResources) end,
		allowedFields = config.AllowedContextFields, resolveLicense = function() return nil end, encode = encode
	})
end
assertEqual(viaAce('coe_admin') ~= nil, true, 'resource com ACE registra')
local refused, refusedError = viaAce('random_script')
assertEqual(refused, nil, 'resource sem ACE recusado')
assertEqual(refusedError, 'caller_not_allowed', 'erro de chamador')

-- rejeições
local _, err = build({ resource = 'outro' })
assertEqual(err, 'caller_not_allowed', 'resource fora da allowlist')
_, err = build({ severity = 'debug' })
assertEqual(err, 'invalid_severity', 'debug não é auditável')
_, err = build({ event = 'com espaco' })
assertEqual(err, 'invalid_event', 'evento inválido')
_, err = build({ context = { item = string.rep('x', 97) } })
assertEqual(err, 'context_value_too_long', 'valor longo')
_, err = build({ context = { item = {} } })
assertEqual(err, 'invalid_context_value', 'valor aninhado')
_, err = build({ encode = function() return nil end })
assertEqual(err, 'encoding_failed', 'falha de encode')
local ok = build({ resolveLicense = function() error('boom') end })
assertEqual(ok.actor_license, '', 'falha ao resolver licença não derruba o evento')

-- writer: lote, falha, backoff e recuperação
local clock = 0
local inserted = {}
local failNext = false
local writer = AuditWriter.New({
	maxSize = 3,
	batchSize = 2,
	maxBackoffMs = 4000,
	now = function() return clock end,
	insertBatch = function(batch)
		if failNext then
			return false, 'database_error'
		end
		for _, item in ipairs(batch) do
			inserted[#inserted + 1] = item
		end
		return true
	end
})

assertEqual(writer.Enqueue({ id = 1 }), true, 'enfileira 1')
assertEqual(writer.Enqueue({ id = 2 }), true, 'enfileira 2')
assertEqual(writer.Enqueue({ id = 3 }), true, 'enfileira 3')
local accepted, queueError = writer.Enqueue({ id = 4 })
assertEqual(accepted, false, 'fila cheia rejeita')
assertEqual(queueError, 'queue_full', 'motivo fila cheia')
assertEqual(writer.TakeDropped(), 1, 'descartes contados')
assertEqual(writer.TakeDropped(), 0, 'contador zera')

local flushed, _, size = writer.Flush()
assertEqual(flushed, true, 'flush ok')
assertEqual(size, 2, 'respeita tamanho do lote')
assertEqual(writer.Pending(), 1, 'sobra 1 na fila')
assertEqual(inserted[1].id, 1, 'ordem preservada')

failNext = true
local failed, failError = writer.Flush()
assertEqual(failed, false, 'falha propagada')
assertEqual(failError, 'database_error', 'código de erro')
assertEqual(writer.Pending(), 1, 'itens mantidos após falha')

local _, backoffError = writer.Flush()
assertEqual(backoffError, 'backoff', 'respeita backoff')
clock = 1000
failed = writer.Flush()
failNext = false
clock = 1001
_, backoffError = writer.Flush()
assertEqual(backoffError, 'backoff', 'backoff dobra após segunda falha')

clock = 10000
flushed = writer.Flush()
assertEqual(flushed, true, 'recupera após o backoff')
assertEqual(writer.Pending(), 0, 'fila drenada')
assertEqual(inserted[3].id, 3, 'nenhum evento perdido')
assertEqual(writer.Failures(), 0, 'falhas zeradas')

-- insertBatch que lança erro não quebra o writer
local throwing = AuditWriter.New({
	maxSize = 5, batchSize = 5, maxBackoffMs = 1000,
	now = function() return 0 end,
	insertBatch = function() error('explodiu') end
})
throwing.Enqueue({ id = 1 })
local threwOk, threwError = throwing.Flush()
assertEqual(threwOk, false, 'erro no insert tratado')
assertEqual(throwing.Pending(), 1, 'evento mantido')

print('coe_audit tests passed')
