local invokingResource = 'coe_core'
local minimumLevel = 'info'
local resourceMinimumLevel = ''
local format = 'json'
local color = '1'
local loggedEntries = {}

CoeLoggingConfig = {
	DefaultLevel = 'info',
	ResourceLevels = { coe_core = 'info' },
	AllowedResources = { coe_core = true, coe_admin = true },
	AllowedContextFields = {
		action = true,
		error_code = true,
		player_id = true
	}
}

GetInvokingResource = function()
	return invokingResource
end

GetConvar = function(name, default)
	if name == 'coe_logging_level_coe_core' then return resourceMinimumLevel end
	if name == 'coe_logging_level' then return minimumLevel end
	if name == 'coe_logging_format' then return format end
	if name == 'coe_logging_color' then return color end
	return default
end

json = {
	encode = function(entry)
		loggedEntries[#loggedEntries + 1] = entry
		return 'structured-entry'
	end
}

local output = {}
local nativePrint = print
print = function(message)
	output[#output + 1] = message
end

local registeredExports = {}
exports = function(name, callback)
	registeredExports[name] = callback
end

dofile('server.lua')

local function assertEqual(actual, expected, message)
	if actual ~= expected then
		error(('%s: expected %s, got %s'):format(message, tostring(expected), tostring(actual)))
	end
end

local log = registeredExports.Log
local succeeded = log('error', 'runtime', 'database_failed', {
	error_code = 'database_unavailable',
	player_id = 42,
	password = 'must_not_be_logged',
	metadata = { secret = true }
})
assertEqual(succeeded, true, 'valid entry is logged')
assertEqual(output[1], 'structured-entry', 'entry goes to console as JSON')
assertEqual(loggedEntries[1].resource, 'coe_core', 'resource is assigned by the logger')
assertEqual(loggedEntries[1].context.error_code, 'database_unavailable', 'safe context is retained')
assertEqual(loggedEntries[1].context.player_id, 42, 'numeric context is retained')
assertEqual(loggedEntries[1].context.password, nil, 'sensitive context is excluded')
assertEqual(loggedEntries[1].context.metadata, nil, 'nested context is excluded')

local oversized, oversizedError = log('error', 'runtime', 'oversized_context', {
	error_code = string.rep('x', 97)
})
assertEqual(oversized, false, 'oversized context value is rejected')
assertEqual(oversizedError, 'context_value_too_long', 'oversized context has explicit error')

minimumLevel = 'error'
local filtered = log('warn', 'runtime', 'retrying')
assertEqual(filtered, true, 'filtered entry is accepted')
assertEqual(#loggedEntries, 1, 'filtered entry is not written')

resourceMinimumLevel = 'debug'
local resourceOverride = log('debug', 'runtime', 'diagnostic_enabled')
assertEqual(resourceOverride, true, 'resource-specific level override is accepted')
assertEqual(#loggedEntries, 2, 'resource-specific override takes precedence')

invokingResource = 'unknown_resource'
local unauthorized, unauthorizedError = log('error', 'runtime', 'forbidden')
assertEqual(unauthorized, false, 'unlisted caller is rejected')
assertEqual(unauthorizedError, 'caller_not_allowed', 'unauthorized caller has an explicit error')

-- Formato legível: colunas fixas, contexto ordenado, cores opcionais e valores saneados.
format, resourceMinimumLevel, minimumLevel = 'pretty', '', 'debug'
invokingResource = 'coe_core'
output = {}
color = '0'
log('error', 'persistence', 'database_failed', { player_id = 42, error_code = 'database_not_ready', action = 'say hi' })
local plain = output[1]
assertEqual(plain:match('^%d%d:%d%d:%d%d ERROR coe_core       persistence  database_failed  ') ~= nil, true,
	'pretty line has aligned columns: ' .. tostring(plain))
assertEqual(plain:match('action="say hi" error_code=database_not_ready player_id=42$') ~= nil, true,
	'context is sorted, quoted when needed: ' .. tostring(plain))
assertEqual(plain:find('^', 1, true), nil, 'no color codes when color is disabled')

log('info', 'lifecycle', 'database_waiting')
assertEqual(output[2]:match('INFO  coe_core       lifecycle    database_waiting$') ~= nil, true,
	'pretty line without context has no trailing separator: ' .. tostring(output[2]))

color = '1'
log('warn', 'runtime', 'colored')
assertEqual(output[3]:find('^3WARN ^7', 1, true) ~= nil, true, 'level is colored')

log('info', 'runtime', 'injection', { action = '^1red\nnewline' })
assertEqual(output[4]:find('^1', 1, true), nil, 'color codes in values are neutralized')
assertEqual(output[4]:find('\n', 1, true), nil, 'control characters in values are neutralized')

format = 'invalid'
local before = #output
log('info', 'runtime', 'fallback_format')
assertEqual(output[before + 1]:find('fallback_format', 1, true) ~= nil, true, 'unknown format falls back to pretty')
assertEqual(output[before + 1] ~= 'structured-entry', true, 'fallback is not JSON output')

invokingResource = 'coe_admin'
local invalid, invalidError = log('trace', 'audit', 'invalid_level')
assertEqual(invalid, false, 'unknown level is rejected')
assertEqual(invalidError, 'invalid_level', 'invalid level has an explicit error')

print = nativePrint
nativePrint('logging tests passed')
