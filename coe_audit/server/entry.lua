-- Validação, normalização, encadeamento forense SHA-256 (Crypto.newForensicChain) e detecção de anomalias
-- estatísticas (Anomaly.newWelfordCUSUM) de eventos de auditoria. Sem dependência de natives.
AuditEntry = {}

local SEVERITIES = { info = true, warn = true, error = true }

local function resolveAlgorithms()
	if type(Core) == 'table' and type(Core.Algorithms) == 'table' then
		return Core.Algorithms
	end
	if type(CoeAlgorithms) == 'table' then
		return CoeAlgorithms
	end
	if type(LoadResourceFile) == 'function' then
		local src = LoadResourceFile('coe_core', 'lib/algorithms/init.lua')
		if type(src) == 'string' and src ~= '' then
			local fn = load(src, '@@coe_core/lib/algorithms/init.lua', 't', _G)
			if fn then pcall(fn) end
		end
	elseif type(io) == 'table' and type(io.open) == 'function' then
		for _, candidate in ipairs({
			'../coe_core/lib/algorithms/init.lua',
			'../../coe-framework/coe_core/lib/algorithms/init.lua'
		}) do
			local f = io.open(candidate, 'r')
			if f then
				f:close()
				pcall(dofile, candidate)
				break
			end
		end
	end
	return CoeAlgorithms
end

function AuditEntry.NewForensicChain(genesisSeed)
	local alg = resolveAlgorithms()
	if alg and alg.Crypto and type(alg.Crypto.newForensicChain) == 'function' then
		return alg.Crypto.newForensicChain(genesisSeed or 'COE_AUDIT_GENESIS_2026')
	end
	return nil
end

function AuditEntry.NewAnomalyDetector(targetMean, slackK, thresholdH, alpha)
	local alg = resolveAlgorithms()
	if alg and alg.Anomaly and type(alg.Anomaly.newWelfordCUSUM) == 'function' then
		return alg.Anomaly.newWelfordCUSUM(targetMean or 100.0, slackK or 50.0, thresholdH or 250.0, alpha or 0.2)
	end
	return nil
end

local defaultChain = nil
local function getDefaultChain()
	if not defaultChain then
		defaultChain = AuditEntry.NewForensicChain('COE_AUDIT_GENESIS_2026')
	end
	return defaultChain
end

local function canonicalPayload(entry)
	return ('%s|%s|%s|%s|%s'):format(
		tostring(entry.occurred_at or ''),
		tostring(entry.severity or ''),
		tostring(entry.category or ''),
		tostring(entry.target_license or ''),
		tostring(entry.context_json or '')
	)
end

function AuditEntry.VerifyChain(records, genesisSeed)
	local alg = resolveAlgorithms()
	local chain = AuditEntry.NewForensicChain(genesisSeed or 'COE_AUDIT_GENESIS_2026')
	if not chain or not (alg and alg.Crypto) then
		return false, 0
	end
	for i = 1, #records do
		local r = records[i]
		local expectedPrev = chain.lastHash
		local computedHash, prevHash = chain:append(
			tonumber(r.timestamp) or 0,
			r.resource,
			r.actor_license,
			r.event,
			canonicalPayload(r)
		)
		if not alg.Crypto.constantTimeEquals(tostring(r.prev_hash or ''), expectedPrev)
			or not alg.Crypto.constantTimeEquals(tostring(r.hash or ''), computedHash)
			or prevHash ~= expectedPrev then
			return false, i
		end
	end
	return true, nil
end

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
-- allowedResources ou isAllowed(resource), allowedFields, resolveLicense(playerId), encode(table), chain?
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

	local ts = tonumber(options.timestamp) or 0
	local entry = {
		timestamp = ts,
		occurred_at = os.date('!%Y-%m-%d %H:%M:%S', ts),
		severity = options.severity,
		category = options.category,
		event = options.event,
		resource = options.resource,
		actor_license = licenseFor(options.resolveLicense, context.source or context.player_id),
		target_license = licenseFor(options.resolveLicense, context.target),
		context_json = encoded
	}

	local chain = options.chain or getDefaultChain()
	if chain then
		local currentHash, prevHash, seq = chain:append(
			ts,
			entry.resource,
			entry.actor_license,
			entry.event,
			canonicalPayload(entry)
		)
		entry.seq = seq
		entry.prev_hash = prevHash
		entry.hash = currentHash
	end

	return entry
end
