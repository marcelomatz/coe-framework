local repository = Core.Repositories.Player
local activePlayers = {}
local configuredCharacterLimit = 5
local configuredHardCharacterLimit = 10

local function isCurrent(session)
	return Core.SessionRegistry.IsCurrent(session.source, session.generation)
end

local function makeCharacterSnapshot(character)
	return {
		characterId = character.characterId,
		playerId = character.playerId,
		stateId = character.stateId,
		firstName = character.firstName,
		lastName = character.lastName,
		birthDate = character.birthDate,
		gender = character.gender,
		appearance = character.appearance,
		appearanceVersion = character.appearanceVersion,
		createdAt = character.createdAt
	}
end

local function makeSessionSnapshot(session)
	local snapshot = {
		source = session.source,
		state = session.state,
		playerId = session.playerId
	}
	if session.character then
		snapshot.character = makeCharacterSnapshot(session.character)
	end
	return snapshot
end

local function releasePlayer(session)
	local active = session.playerId and activePlayers[session.playerId]
	if active and active.source == session.source
		and active.generation == session.generation then
		activePlayers[session.playerId] = nil
	end
end

local function finishFailedLoad(session, callback, errorMessage)
	if isCurrent(session) then
		releasePlayer(session)
		Core.SessionRegistry.Remove(session.source, session.generation)
	end
	callback(false, nil, errorMessage)
end

local function requireSelectionSession(source)
	local session = Core.SessionRegistry.Get(source)
	if not session then
		return nil, 'session_not_found'
	end
	if session.state ~= 'character_selection' then
		return nil, 'character_selection_required'
	end
	return session
end

local function beginOperation(session, name)
	if not isCurrent(session) then
		return false, 'stale_session'
	end
	if session.operation then
		return false, 'operation_in_progress'
	end

	session.operation = name
	return true
end

local function finishOperation(session)
	if isCurrent(session) then
		session.operation = nil
	end
end

function Core.Players.SetCharacterLimit(limit)
	if not Core.Functions.IsInteger(limit) or limit < 1 or limit > 50 then
		return false, 'invalid_character_limit'
	end

	configuredCharacterLimit = limit
	return true
end

-- Teto absoluto de slots por jogador; vale mesmo para valores definidos individualmente.
function Core.Players.SetCharacterHardLimit(limit)
	if not Core.Functions.IsInteger(limit) or limit < 1 or limit > 50 then
		return false, 'invalid_character_limit'
	end

	configuredHardCharacterLimit = limit
	return true
end

-- Define ou limpa (nil) os slots de personagem de um jogador. API interna do core: a
-- autorização do operador é responsabilidade de quem chama (ex.: coe_admin com ACE).
function Core.Players.SetCharacterSlots(playerId, slots, callback)
	if type(callback) ~= 'function' then
		return false, 'invalid_callback'
	end
	if type(playerId) ~= 'string' or not playerId:match('^[1-9]%d*$') or #playerId > 20 then
		return false, 'invalid_player'
	end
	if slots ~= nil and (not Core.Functions.IsInteger(slots) or slots < 1 or slots > configuredHardCharacterLimit) then
		return false, 'invalid_character_slots'
	end

	repository.SetCharacterSlots(playerId, slots, callback)
	return true
end

function Core.Players.LoadSession(source, license, callback)
	if type(callback) ~= 'function' then
		return false, 'invalid_callback'
	end

	local session, createError = Core.SessionRegistry.Create(source)
	if not session then
		return false, createError
	end

	repository.FindOrCreateByLicense(license, function(success, playerId, errorMessage)
		if not isCurrent(session) then
			callback(false, nil, 'stale_session')
			return
		end
		if not success then
			finishFailedLoad(session, callback, errorMessage)
			return
		end

		local existing = activePlayers[playerId]
		if existing and Core.SessionRegistry.IsCurrent(existing.source, existing.generation) then
			finishFailedLoad(session, callback, 'player_already_online')
			return
		end

		local loaded, loadError = Core.SessionRegistry.MarkPlayerLoaded(session, playerId)
		if not loaded then
			finishFailedLoad(session, callback, loadError)
			return
		end
		activePlayers[playerId] = {
			source = source,
			generation = session.generation
		}

		local selecting, selectionError = Core.SessionRegistry.BeginCharacterSelection(session)
		if not selecting then
			finishFailedLoad(session, callback, selectionError)
			return
		end

		Core.Events.Emit('player.loaded', {
			source = source,
			playerId = playerId
		})
		Core.Events.Emit('player.characterSelectionRequired', {
			source = source,
			playerId = playerId
		})

		repository.ListCharacters(playerId, function(listed, characters, listError)
			if not isCurrent(session) then
				callback(false, nil, 'stale_session')
				return
			end
			if not listed then
				finishFailedLoad(session, callback, listError)
				return
			end

			callback(true, makeSessionSnapshot(session), characters)
		end)
	end)

	return true
end

function Core.Players.Disconnect(source)
	local session = Core.SessionRegistry.Get(source)
	if not session then
		return false, 'session_not_found'
	end

	local snapshot = makeSessionSnapshot(session)
	local disconnected, errorMessage = Core.SessionRegistry.BeginDisconnect(session)
	if not disconnected then
		return false, errorMessage
	end

	releasePlayer(session)
	Core.SessionRegistry.Remove(source, session.generation)
	Core.Events.Emit('player.sessionEnded', snapshot)
	return true
end

function Core.Players.GetSession(source)
	local session = Core.SessionRegistry.Get(source)
	if not session then
		return nil, 'session_not_found'
	end
	return makeSessionSnapshot(session)
end

function Core.Players.GetPlayerId(source)
	local session = Core.SessionRegistry.Get(source)
	if not session or not session.playerId then
		return nil, 'player_not_loaded'
	end
	return session.playerId
end

function Core.Players.GetActiveCharacter(source)
	local session = Core.SessionRegistry.Get(source)
	if not session or session.state ~= 'character_loaded' or not session.character then
		return nil, 'character_not_loaded'
	end
	return makeCharacterSnapshot(session.character)
end

function Core.Players.GetActiveCharacterId(source)
	local character, errorMessage = Core.Players.GetActiveCharacter(source)
	if not character then
		return nil, errorMessage
	end
	return character.characterId
end

local function findLoadedSessionByStateId(stateId)
	if not Core.Identity.IsValidStateId(stateId) then
		return nil, 'invalid_state_id'
	end
	for _, session in ipairs(Core.SessionRegistry.List()) do
		if session.state == 'character_loaded' and session.character and session.character.stateId == stateId then
			return session
		end
	end
	return nil, 'character_not_online'
end

-- Busca por stateId apenas entre personagens carregados (online); retorna o snapshot do personagem.
function Core.Players.GetCharacterByStateId(stateId)
	local session, errorMessage = findLoadedSessionByStateId(stateId)
	if not session then
		return nil, errorMessage
	end
	return makeCharacterSnapshot(session.character)
end

-- Retorna o snapshot da sessão (source, playerId, personagem ativo) dona do stateId.
function Core.Players.GetPlayerByStateId(stateId)
	local session, errorMessage = findLoadedSessionByStateId(stateId)
	if not session then
		return nil, errorMessage
	end
	return makeSessionSnapshot(session)
end

function Core.Players.ListCharacters(source, callback)
	if type(callback) ~= 'function' then
		return false, 'invalid_callback'
	end

	local session = Core.SessionRegistry.Get(source)
	if not session or (session.state ~= 'character_selection' and session.state ~= 'character_loaded') then
		return false, 'player_not_loaded'
	end
	local generation = session.generation

	repository.ListCharacters(session.playerId, function(success, characters, errorMessage)
		if not Core.SessionRegistry.IsCurrent(source, generation) then
			callback(false, nil, 'stale_session')
			return
		end
		callback(success, characters, errorMessage)
	end)
	return true
end

-- profile é opcional: { birthDate, gender, appearance, appearanceVersion }.
function Core.Players.CreateCharacter(source, firstName, lastName, profile, callback)
	if type(callback) ~= 'function' then
		return false, 'invalid_callback'
	end

	local session, sessionError = requireSelectionSession(source)
	if not session then
		return false, sessionError
	end
	local first, firstError = Core.Identity.NormalizeCharacterName(firstName)
	if not first then
		return false, firstError
	end
	local last, lastError = Core.Identity.NormalizeCharacterName(lastName)
	if not last then
		return false, lastError
	end

	local normalizedProfile, profileError = Core.CharacterProfile.Normalize(profile, json and json.encode)
	if not normalizedProfile then
		return false, profileError
	end

	local started, operationError = beginOperation(session, 'create_character')
	if not started then
		return false, operationError
	end
	local generation = session.generation

	repository.CreateCharacter(session.playerId, first, last, normalizedProfile, configuredCharacterLimit, configuredHardCharacterLimit,
		function(success, character, errorMessage)
			if not Core.SessionRegistry.IsCurrent(source, generation) then
				callback(false, nil, 'stale_session')
				return
			end
			finishOperation(session)
			if not success then
				callback(false, nil, errorMessage)
				return
			end
			local snapshot = makeCharacterSnapshot(character)
			Core.Events.Emit('player.characterCreated', {
				source = source,
				playerId = session.playerId,
				generation = generation,
				character = snapshot
			})
			callback(true, snapshot)
		end
	)
	return true
end

function Core.Players.SelectCharacter(source, characterId, callback)
	if type(callback) ~= 'function' then
		return false, 'invalid_callback'
	end
	local session, sessionError = requireSelectionSession(source)
	if not session then
		return false, sessionError
	end
	if not Core.Identity.IsValidCharacterId(characterId) then
		return false, 'invalid_character_id'
	end

	local started, operationError = beginOperation(session, 'select_character')
	if not started then
		return false, operationError
	end
	local generation = session.generation

	repository.GetOwnedCharacter(session.playerId, characterId, function(success, character, errorMessage)
		if not Core.SessionRegistry.IsCurrent(source, generation) then
			callback(false, nil, 'stale_session')
			return
		end
		finishOperation(session)
		if not success then
			callback(false, nil, errorMessage)
			return
		end

		local loaded, loadError = Core.SessionRegistry.MarkCharacterLoaded(session, character)
		if not loaded then
			callback(false, nil, loadError)
			return
		end

		local snapshot = makeCharacterSnapshot(character)
		Core.Events.Emit('player.characterLoaded', {
			source = source,
			playerId = session.playerId,
			generation = session.generation,
			character = snapshot
		})
		callback(true, snapshot)
	end)
	return true
end

function Core.Players.ReturnToSelection(source, callback)
	if type(callback) ~= 'function' then
		return false, 'invalid_callback'
	end

	local session = Core.SessionRegistry.Get(source)
	if not session or session.state ~= 'character_loaded' then
		return false, 'character_not_loaded'
	end
	local started, operationError = beginOperation(session, 'change_character')
	if not started then
		return false, operationError
	end

	local generation = session.generation
	local previousCharacter = makeCharacterSnapshot(session.character)
	local changed, changeError = Core.SessionRegistry.ClearActiveCharacter(session)
	if not changed then
		finishOperation(session)
		return false, changeError
	end
	finishOperation(session)
	Core.Events.Emit('player.characterUnloaded', {
		source = source,
		playerId = session.playerId,
		generation = session.generation,
		character = previousCharacter
	})

	repository.ListCharacters(session.playerId, function(success, characters, errorMessage)
		if not Core.SessionRegistry.IsCurrent(source, generation) then
			callback(false, nil, 'stale_session')
			return
		end
		if not success then
			callback(false, nil, errorMessage)
			return
		end

		Core.Events.Emit('player.characterSelectionRequired', {
			source = source,
			playerId = session.playerId
		})
		callback(true, characters)
	end)
	return true
end

function Core.Players.ArchiveCharacter(source, characterId, callback)
	if type(callback) ~= 'function' then
		return false, 'invalid_callback'
	end
	local session, sessionError = requireSelectionSession(source)
	if not session then
		return false, sessionError
	end
	if not Core.Identity.IsValidCharacterId(characterId) then
		return false, 'invalid_character_id'
	end

	local started, operationError = beginOperation(session, 'archive_character')
	if not started then
		return false, operationError
	end
	local generation = session.generation

	repository.ArchiveCharacter(session.playerId, characterId, function(success, _, errorMessage)
		if not Core.SessionRegistry.IsCurrent(source, generation) then
			callback(false, nil, 'stale_session')
			return
		end
		finishOperation(session)
		callback(success, nil, errorMessage)
	end)
	return true
end

-- Primeira aparência de um personagem que ainda não tem (criado antes do criador de personagem).
-- Só na seleção, só de personagem da conta e só uma vez (o repositório recusa se já houver aparência).
function Core.Players.SetInitialAppearance(source, characterId, appearance, appearanceVersion, callback)
	if type(callback) ~= 'function' then
		return false, 'invalid_callback'
	end
	local session, sessionError = requireSelectionSession(source)
	if not session then
		return false, sessionError
	end
	if not Core.Identity.IsValidCharacterId(characterId) then
		return false, 'invalid_character_id'
	end
	local encoded, version, appearanceError = Core.CharacterProfile.NormalizeAppearance(appearance, appearanceVersion, json and json.encode)
	if not encoded then
		return false, appearanceError
	end

	local started, operationError = beginOperation(session, 'set_appearance')
	if not started then
		return false, operationError
	end
	local generation = session.generation

	repository.SetInitialAppearance(session.playerId, characterId, encoded, version, function(success, _, errorMessage)
		if not Core.SessionRegistry.IsCurrent(source, generation) then
			callback(false, nil, 'stale_session')
			return
		end
		finishOperation(session)
		callback(success, nil, errorMessage)
	end)
	return true
end
