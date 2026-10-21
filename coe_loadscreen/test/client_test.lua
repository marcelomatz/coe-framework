-- Rede de seguranca do loadscreen_manual_shutdown: fecha logo sem o coe_characters e em 60 s se ele travar.
local calls = {}
local states = { coe_characters = 'missing' }
local t = 0
NetworkIsPlayerActive = function() return true end
PlayerId = function() return 1 end
GetResourceState = function(n) return states[n] end
Wait = function(ms) t = t + ms end
ShutdownLoadingScreen = function() calls[#calls+1] = 'native' end
ShutdownLoadingScreenNui = function() calls[#calls+1] = ('nui@%d'):format(t) end
CreateThread = function(f) f() end
dofile('client.lua')
assert(calls[2] == 'nui@5000', calls[2])
calls, t, states.coe_characters = {}, 0, 'started'
dofile('client.lua')
assert(calls[2] == 'nui@60000', calls[2])
print('coe_loadscreen tests passed')
