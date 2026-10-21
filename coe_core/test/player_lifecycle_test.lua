local eventCallbacks = {}
local removedHandlers = {}
local sentClientEvents = {}
local handlerSequence = 0
local activeSession = {
	source = 42,
	generation = 3
}

Core = {
	Functions = {
		IsInteger = function(value)
			return type(value) == 'number' and value % 1 == 0
		end,
		IsValidName = function(value)
			return type(value) == 'string' and value:match('^[%w%.]+$') ~= nil
		end
	},
	Events = {
		On = function(name, callback)
			handlerSequence = handlerSequence + 1
			eventCallbacks[name] = callback
			return handlerSequence
		end,
		OnNet = function(name, callback)
			handlerSequence = handlerSequence + 1
			eventCallbacks[name] = callback
			return handlerSequence
		end,
		Remove = function(handler)
			removedHandlers[#removedHandlers + 1] = handler
			return true
		end,
		ToClient = function(target, name, ...)
			sentClientEvents[#sentClientEvents + 1] = {
				target = target,
				name = name,
				args = { ... }
			}
			return true
		end
	},
	SessionRegistry = {
		Get = function(source)
			if activeSession and activeSession.source == source then
				return activeSession
			end
			return nil
		end,
		List = function()
			return {}
		end
	},
	Players = {
		SetCharacterLimit = function()
			return true
		end,
		SetCharacterHardLimit = function()
			return true
		end
	},
	CharacterProfile = {
		SetRules = function()
			return true
		end
	}
}

function AddEventHandler()
	handlerSequence = handlerSequence + 1
	return handlerSequence
end

exports = setmetatable({}, {
	__index = function()
		return { Log = function() return true end }
	end
})
json = { encode = function() return '{}' end }

function GetConvar(_, default)
	return default
end

function GetPlayers()
	return {}
end

function GetGameTimer()
	return 10000
end

function GetPlayerName()
	return 'Test player'
end

function GetPlayerIdentifiers()
	return { 'license:abcdef123' }
end

function DropPlayer()
	error('DropPlayer should not be called in this test')
end

dofile([=[lib/logger.lua]=])
dofile([=[core/server/player_lifecycle.lua]=])

assert(Core.Players.Start())
assert(type(eventCallbacks['player.characterUnloaded']) == 'function')

Core.Events.Emit = function(name, payload)
	eventCallbacks[name](payload)
	return true
end
Core.Events.Emit('player.characterUnloaded', {
	source = 42,
	generation = 3
})
assert(#sentClientEvents == 1)
assert(sentClientEvents[1].target == 42)
assert(sentClientEvents[1].name == 'player.characterUnloaded')

sentClientEvents = {}
Core.Events.Emit('player.characterUnloaded', {
	source = 42,
	generation = 2
})
assert(#sentClientEvents == 0)

-- Handshake de client pronto: reenvia a seleção somente a sessões em seleção e com limite de frequência.
Core.SessionRegistry.IsCurrent = function(source, generation)
	return activeSession ~= nil and activeSession.source == source and activeSession.generation == generation
end
Core.Players.ListCharacters = function(_, callback)
	callback(true, { { characterId = '7', firstName = 'Ana', lastName = 'Silva', createdAt = 'x', secret = 'hidden' } })
	return true
end

source = 42
activeSession.state = 'character_loaded'
sentClientEvents = {}
eventCallbacks['player.clientReady']()
assert(#sentClientEvents == 0)

activeSession.state = 'character_selection'
eventCallbacks['player.clientReady']()
assert(#sentClientEvents == 2)
assert(sentClientEvents[1].name == 'player.loaded')
assert(sentClientEvents[2].name == 'character.selectionRequired')
assert(sentClientEvents[2].args[1][1].characterId == '7')
assert(sentClientEvents[2].args[1][1].secret == nil)

sentClientEvents = {}
eventCallbacks['player.clientReady']()
assert(#sentClientEvents == 0)

source = 99
eventCallbacks['player.clientReady']()
assert(#sentClientEvents == 0)

-- Statebag coe:stateId: definido ao carregar o personagem, limpo ao descarregar; sessões antigas são ignoradas.
local bags = {}
function Player(target)
	return {
		state = {
			set = function(_, key, value, replicated)
				bags[#bags + 1] = { target = target, key = key, value = value, replicated = replicated }
			end
		}
	}
end

eventCallbacks['player.characterLoaded']({ source = 42, generation = 3, character = { stateId = 'ABCD2345' } })
assert(#bags == 1 and bags[1].target == 42 and bags[1].key == 'coe:stateId')
assert(bags[1].value == 'ABCD2345' and bags[1].replicated == true)

eventCallbacks['player.characterLoaded']({ source = 42, generation = 2, character = { stateId = 'ZZZZ2345' } })
assert(#bags == 1, 'stale generation does not touch the statebag')

eventCallbacks['player.characterUnloaded']({ source = 42, generation = 3 })
assert(#bags == 2 and bags[2].value == nil and bags[2].replicated == true, 'unload clears the statebag')

-- Falha no statebag não derruba o fluxo.
function Player()
	error('statebag unavailable')
end
eventCallbacks['player.characterLoaded']({ source = 42, generation = 3, character = { stateId = 'ABCD2345' } })

Core.Players.Stop()
assert(#removedHandlers == 9)
print('player lifecycle tests passed')
