local invokingResource = 'coe_core'
local registeredExports = {}
local events = {}
local playerName = 'Player'

GetInvokingResource = function()
	return invokingResource
end
GetPlayerName = function(playerId)
	return playerId == 12 and playerName or nil
end
TriggerClientEvent = function(name, target, ...)
	events[#events + 1] = { name = name, target = target, args = { ... } }
end
exports = function(name, callback)
	registeredExports[name] = callback
end

dofile('../coe_core/lib/access.lua')
dofile('server.lua')

local function assertEqual(actual, expected, message)
	if actual ~= expected then
		error(('%s: expected %s, got %s'):format(message, tostring(expected), tostring(actual)))
	end
end

local notify = registeredExports.Notify
local success, errorCode = notify(12, 'success', 'Personagem carregado.')
assertEqual(success, true, 'authorized resource can notify an online player')
assertEqual(errorCode, nil, 'successful notification has no error')
assertEqual(events[1].name, 'coe_notify:display', 'server uses notification route')
assertEqual(events[1].target, 12, 'notification targets the requested player')
assertEqual(events[1].args[1], 'success', 'notification type is forwarded')
assertEqual(events[1].args[3], 4000, 'default duration is set server-side')

invokingResource = 'untrusted_resource'
local unauthorized, unauthorizedError = notify(12, 'info', 'No.')
assertEqual(unauthorized, false, 'unlisted resources cannot notify players')
assertEqual(unauthorizedError, 'caller_not_allowed', 'unauthorized resource has explicit error')

IsPrincipalAceAllowed = function(principal, ace) return principal == 'resource.pack_script' and ace == 'coe.notify' end
invokingResource = 'pack_script'
local granted = notify(12, 'info', 'Ok.')
assertEqual(granted, true, 'resource with the coe.notify ACE can notify')
events[#events] = nil
IsPrincipalAceAllowed = nil

invokingResource = 'coe_core'
local invalid, invalidError = notify(12, 'success', string.rep('x', 241))
assertEqual(invalid, false, 'oversized message is rejected')
assertEqual(invalidError, 'invalid_notification', 'invalid message has explicit error')
assertEqual(#events, 1, 'invalid notification is not sent')

print('server notification tests passed')
