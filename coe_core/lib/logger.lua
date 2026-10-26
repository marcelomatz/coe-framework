-- Logger server-side por resource. Encaminha para o coe_logging e, para as categorias
-- `audit` e `security`, também para a trilha durável do coe_audit. Se o coe_logging
-- estiver indisponível, escreve uma linha JSON de fallback no console.
CoeLogger = {}

local AUDITED_CATEGORIES = { audit = true, security = true }
local FALLBACK_ENCODING_FAILED = '{"level":"error","category":"logging","event":"fallback_encoding_failed"}'

function CoeLogger.Create(resourceName)
	local logger = {}

	function logger.fallback(event, level, category, context)
		local encodedOk, encoded = pcall(json.encode, {
			timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
			level = (type(level) == 'string' and level) or 'error',
			category = (type(category) == 'string' and category) or 'logging',
			event = (type(event) == 'string' and event) or 'event',
			resource = resourceName,
			context = (type(context) == 'table' and context) or {}
		})
		print(encodedOk and encoded or FALLBACK_ENCODING_FAILED)
	end

	function logger.log(a, b, c, d, e)
		local level, category, event, context
		if type(a) == 'table' and a == logger then
			level, category, event, context = b, c, d, e
		else
			level, category, event, context = a, b, c, d
		end

		if type(level) ~= 'string' then level = 'info' end
		if type(category) ~= 'string' then category = 'general' end
		if type(event) ~= 'string' then event = 'event' end
		if type(context) ~= 'table' then context = {} end

		local ok, logged = pcall(function()
			return exports.coe_logging:Log(level, category, event, context)
		end)
		if not ok or logged ~= true then
			logger.fallback(event, level, category, context)
		end
		if AUDITED_CATEGORIES[category] then
			pcall(function()
				return exports.coe_audit:Record(level, category, event, context)
			end)
		end
	end

	return logger
end
