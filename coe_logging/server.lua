local levels = {
	debug = 10,
	info = 20,
	warn = 30,
	error = 40
}

local function validToken(value, maximumLength)
	return type(value) == 'string'
		and #value > 0
		and #value <= maximumLength
		and value:match('^[%w_.%-]+$') ~= nil
end

local function configuredLevel(resourceName)
	local resourceOverride = GetConvar('coe_logging_level_' .. resourceName, '')
	if levels[resourceOverride] then
		return resourceOverride
	end

	local configured = GetConvar('coe_logging_level', '')
	if levels[configured] then
		return configured
	end

	configured = CoeLoggingConfig.ResourceLevels[resourceName]
	if not levels[configured] then
		configured = CoeLoggingConfig.DefaultLevel
	end
	return configured
end

local function sanitizeContext(context)
	if context == nil then
		return {}
	end
	if type(context) ~= 'table' then
		return nil, 'invalid_context'
	end

	local safe = {}
	local count = 0
	for key, value in pairs(context) do
		if type(key) == 'string' and CoeLoggingConfig.AllowedContextFields[key] then
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

-- Códigos ^N do console do FXServer/txAdmin. ^7 volta à cor padrão.
local levelColors = { debug = '^4', info = '^2', warn = '^3', error = '^1' }
local DIM, RESET = '^9', '^7'
local RESOURCE_WIDTH, CATEGORY_WIDTH = 14, 12

local function configuredFormat()
	local format = GetConvar('coe_logging_format', CoeLoggingConfig.DefaultFormat or 'pretty')
	if format ~= 'json' and format ~= 'pretty' then
		return 'pretty'
	end
	return format
end

local function colorEnabled()
	local value = GetConvar('coe_logging_color', CoeLoggingConfig.DefaultColor == false and '0' or '1')
	return value ~= '0' and value ~= 'false'
end

-- Remove controles e '^' para um valor de contexto não injetar cor nem quebrar a linha.
local function cleanText(value)
	return (value:gsub('[%c^]', '?'))
end

local function formatValue(value)
	if type(value) == 'string' then
		value = cleanText(value)
		if value ~= '' and value:match('^[%w_.:/%-]+$') then
			return value
		end
		return '"' .. value:gsub('"', "'") .. '"'
	end
	return tostring(value)
end

-- Linha legível: hora  NÍVEL  resource  categoria  evento  chave=valor ...
local function formatPretty(entry, color)
	local keys = {}
	for key in pairs(entry.context) do
		keys[#keys + 1] = key
	end
	table.sort(keys)

	local pairsText = {}
	for index, key in ipairs(keys) do
		local text = key .. '=' .. formatValue(entry.context[key])
		pairsText[index] = color and (DIM .. key .. '=' .. RESET .. formatValue(entry.context[key])) or text
	end

	local time = os.date('%H:%M:%S')
	local level = entry.level:upper()
	local resource = entry.resource .. string.rep(' ', RESOURCE_WIDTH - #entry.resource)
	local category = entry.category .. string.rep(' ', CATEGORY_WIDTH - #entry.category)
	level = level .. string.rep(' ', 5 - #level)

	local line
	if color then
		line = ('%s%s%s %s%s%s %s %s%s%s %s'):format(
			DIM, time, RESET, levelColors[entry.level], level, RESET, resource, DIM, category, RESET, entry.event)
	else
		line = ('%s %s %s %s %s'):format(time, level, resource, category, entry.event)
	end
	if #pairsText > 0 then
		line = line .. '  ' .. table.concat(pairsText, ' ')
	end
	return line
end

local function log(level, category, event, context)
	local resourceName = GetInvokingResource()
	if not CoeAccess.Allowed(resourceName, CoeLoggingConfig.Ace, CoeLoggingConfig.AllowedResources) then
		return false, 'caller_not_allowed'
	end
	if not levels[level] then
		return false, 'invalid_level'
	end
	if not validToken(category, 48) or not validToken(event, 80) then
		return false, 'invalid_event'
	end
	if levels[level] < levels[configuredLevel(resourceName)] then
		return true
	end

	local safeContext, contextError = sanitizeContext(context)
	if not safeContext then
		return false, contextError
	end

	local entry = {
		timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
		level = level,
		category = category,
		event = event,
		resource = resourceName,
		context = safeContext
	}
	if configuredFormat() == 'pretty' then
		print(formatPretty(entry, colorEnabled()))
		return true
	end

	local encodedOk, encoded = pcall(json.encode, entry)
	if not encodedOk or type(encoded) ~= 'string' then
		print(('{"timestamp":"%s","level":"error","category":"logging","event":"encoding_failed","resource":"coe_logging","context":{}}')
			:format(os.date('!%Y-%m-%dT%H:%M:%SZ')))
		return false, 'encoding_failed'
	end

	print(encoded)
	return true
end

exports('Log', log)
