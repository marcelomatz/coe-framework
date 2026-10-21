local sessions = {}
local nextGeneration = 0

local transitions = {
	identifying = {
		player_loaded = true,
		disconnecting = true
	},
	player_loaded = {
		character_selection = true,
		disconnecting = true
	},
	character_selection = {
		character_loaded = true,
		disconnecting = true
	},
	character_loaded = {
		character_selection = true,
		disconnecting = true
	},
	disconnecting = {
		disconnected = true
	}
}

local function isCurrent(source, generation)
	local session = sessions[source]
	return session ~= nil and session.generation == generation
end

local function transition(session, nextState)
	if type(session) ~= 'table' or not isCurrent(session.source, session.generation) then
		return false, 'stale_session'
	end
	if not transitions[session.state] or not transitions[session.state][nextState] then
		return false, 'invalid_session_transition'
	end

	session.state = nextState
	return true
end

function Core.SessionRegistry.Create(source)
	if not Core.Functions.IsInteger(source) or source < 1 then
		return nil, 'invalid_source'
	end

	nextGeneration = nextGeneration + 1
	local session = {
		source = source,
		generation = nextGeneration,
		state = 'identifying',
		playerId = nil,
		character = nil
	}
	sessions[source] = session
	return session
end

function Core.SessionRegistry.Get(source)
	return sessions[source]
end

function Core.SessionRegistry.IsCurrent(source, generation)
	return isCurrent(source, generation)
end

function Core.SessionRegistry.MarkPlayerLoaded(session, playerId)
	if type(playerId) ~= 'string' or not playerId:match('^[1-9]%d*$') or #playerId > 20 then
		return false, 'invalid_player_id'
	end

	local transitioned, errorMessage = transition(session, 'player_loaded')
	if not transitioned then
		return false, errorMessage
	end

	session.playerId = playerId
	return true
end

function Core.SessionRegistry.BeginCharacterSelection(session)
	return transition(session, 'character_selection')
end

function Core.SessionRegistry.MarkCharacterLoaded(session, character)
	if type(session) ~= 'table' or not isCurrent(session.source, session.generation) then
		return false, 'stale_session'
	end
	if type(character) ~= 'table'
		or type(character.characterId) ~= 'string'
		or not Core.Identity.IsValidCharacterId(character.characterId)
		or character.playerId ~= session.playerId then
		return false, 'character_owner_mismatch'
	end

	local transitioned, errorMessage = transition(session, 'character_loaded')
	if not transitioned then
		return false, errorMessage
	end

	session.character = {
		characterId = character.characterId,
		playerId = character.playerId,
		stateId = character.stateId,
		firstName = character.firstName,
		lastName = character.lastName,
		birthDate = character.birthDate,
		gender = character.gender,
		createdAt = character.createdAt
	}
	return true
end

function Core.SessionRegistry.ClearActiveCharacter(session)
	local transitioned, errorMessage = transition(session, 'character_selection')
	if not transitioned then
		return false, errorMessage
	end

	session.character = nil
	return true
end

function Core.SessionRegistry.BeginDisconnect(session)
	if type(session) ~= 'table' or not isCurrent(session.source, session.generation) then
		return false, 'stale_session'
	end
	if session.state == 'disconnecting' then
		return true
	end

	return transition(session, 'disconnecting')
end

function Core.SessionRegistry.Remove(source, generation)
	local session = sessions[source]
	if not session or session.generation ~= generation then
		return nil, 'stale_session'
	end

	if session.state ~= 'disconnecting' then
		local transitioned, errorMessage = Core.SessionRegistry.BeginDisconnect(session)
		if not transitioned then
			return nil, errorMessage
		end
	end

	session.state = 'disconnected'
	sessions[source] = nil
	return session
end

function Core.SessionRegistry.List()
	local activeSessions = {}
	for _, session in pairs(sessions) do
		activeSessions[#activeSessions + 1] = session
	end
	return activeSessions
end
