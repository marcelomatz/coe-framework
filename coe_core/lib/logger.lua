-- Logger server-side por resource. Encaminha para o coe_logging e, para as categorias
-- `audit` e `security`, também para a trilha durável do coe_audit. Se o coe_logging
-- estiver indisponível, escreve uma linha JSON de fallback no console.
CoeLogger = {}

local AUDITED_CATEGORIES = { audit = true, security = true }
local FALLBACK_ENCODING_FAILED = '{"level":"error","category":"logging","event":"fallback_encoding_failed"}'

function CoeLogger.Create(resourceName)
	local logger = {}

	function logger.fallback(event)
		local encodedOk, encoded = pcall(json.encode, {
			timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
			level = 'error',
			category = 'logging',
			event = event,
			resource = resourceName,
			context = {}
		})
		print(encodedOk and encoded or FALLBACK_ENCODING_FAILED)
	end

	function logger.log(level, category, event, context)
		local ok, logged = pcall(function()
			return exports.coe_logging:Log(level, category, event, context)
		end)
		if not ok or logged ~= true then
			logger.fallback(event)
		end
		if AUDITED_CATEGORIES[category] then
			pcall(function()
				return exports.coe_audit:Record(level, category, event, context)
			end)
		end
	end

	return logger
end
