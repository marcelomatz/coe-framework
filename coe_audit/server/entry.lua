-- Validação e normalização de um evento de auditoria. Sem dependência de natives.
AuditEntry = {}

local SEVERITIES = { info = true, warn = true, error = true }

local function validToken(value, maximumLength)
	return type(value) == 'string'
		and #value > 0
		and #value <= maximumLength
		and value:match('^[%w_.%-]+$') ~= nil
end

local function sanitizeContext(context, allowedFields)
	if context == nil then
		return {}
	end
	if type(context) ~= 'table' then
		return nil, 'invalid_context'
	end

	local safe = {}
	local count = 0
	for key, value in pairs(context) do
		if type(key) == 'string' and allowedFields[key] then
			local valueType = type(value)
			if valueType == 'string' then
				if #value > 96 then
					return nil, 'context_value_too_long'
				end
			elseif valueType == 'number' then
				if value ~= value or value == math.huge or value == -math.huge then
					return nil, 'invalid_context_value'
				end
			elseif valueType ~= 'boolean' then
				return nil, 'invalid_context_value'
			end

			count = count + 1
			if count > 16 then
				return nil, 'context_too_large'
			end
			safe[key] = value
		end
	end
	return safe
end

local function licenseFor(resolveLicense, playerId)
	if type(playerId) ~= 'number' or playerId % 1 ~= 0 then
		return ''
	end
	local ok, license = pcall(resolveLicense, playerId)
	if ok and type(license) == 'string' and #license <= 128 then
		return license
	end
	return ''
end

-- options: resource, severity, category, event, context, timestamp (epoch s),
-- allowedResources ou isAllowed(resource), allowedFields, resolveLicense(playerId), encode(table)
-- Licenças ausentes ficam como '' (a persistência converte para NULL).
function AuditEntry.Build(options)
	local allowed
	if type(options.isAllowed) == 'function' then
		allowed = options.isAllowed(options.resource) == true
	else
		allowed = type(options.allowedResources) == 'table' and options.allowedResources[options.resource] == true
	end
	if not allowed then
		return nil, 'caller_not_allowed'
	end
	if not SEVERITIES[options.severity] then
		return nil, 'invalid_severity'
	end
	if not validToken(options.category, 48) or not validToken(options.event, 80) then
		return nil, 'invalid_event'
	end

	local context, contextError = sanitizeContext(options.context, options.allowedFields)
	if not context then
		return nil, contextError
	end
	local encoded = options.encode(context)
	if type(encoded) ~= 'string' then
		return nil, 'encoding_failed'
	end

	return {
		occurred_at = os.date('!%Y-%m-%d %H:%M:%S', options.timestamp),
		severity = options.severity,
		category = options.category,
		event = options.event,
		resource = options.resource,
		actor_license = licenseFor(options.resolveLicense, context.source or context.player_id),
		target_license = licenseFor(options.resolveLicense, context.target),
		context_json = encoded
	}
end
