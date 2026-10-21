dofile([=[core/shared/bootstrap.lua]=])
dofile([=[core/shared/functions.lua]=])
dofile([=[core/shared/identity.lua]=])
dofile([=[core/shared/character_profile.lua]=])
json = { encode = function() return '{}' end }
local createdProfiles = {}
local appearanceWrites = {}
dofile([=[core/server/session_registry.lua]=])

local pendingLookups = {}
local emittedEvents = {}
local repository = {
	FindOrCreateByLicense = function(license, callback)
		if license == 'license:deferred' then
			pendingLookups.deferred = callback
			return
		end
		if license == 'license:reused-source' then
			pendingLookups.reused = callback
			return
		end
		callback(true, '7')
	end,
	ListCharacters = function(playerId, callback)
		callback(true, {
			{
				characterId = '9',
				playerId = playerId,
				firstName = 'Ana',
				lastName = 'Silva'
			}
		})
	end,
	CreateCharacter = function(playerId, firstName, lastName, profile, characterLimit, hardLimit, callback)
		createdProfiles[#createdProfiles + 1] = profile
		assert(characterLimit == 5)
		assert(hardLimit == 10)
		callback(true, {
			characterId = '10',
			playerId = playerId,
			stateId = 'WXYZ6789',
			firstName = firstName,
			lastName = lastName
		})
	end,
	SetCharacterSlots = function(playerId, slots, callback)
		callback(true)
	end,
	GetOwnedCharacter = function(playerId, characterId, callback)
		if characterId == '404' then
			callback(false, nil, 'character_not_found')
			return
		end
		callback(true, {
			characterId = characterId,
			playerId = playerId,
			stateId = 'ABCD2345',
			firstName = 'Ana',
			lastName = 'Silva'
		})
	end,
	ArchiveCharacter = function(_, characterId, callback)
		callback(characterId ~= '404', nil, characterId == '404' and 'character_not_found' or nil)
	end,
	SetInitialAppearance = function(_, characterId, appearanceJson, version, callback)
		appearanceWrites[#appearanceWrites + 1] = { characterId = characterId, json = appearanceJson, version = version }
		callback(characterId ~= '11', nil, characterId == '11' and 'appearance_locked' or nil)
	end
}

Core.Repositories.Player = repository
Core.Events.Emit = function(name, payload)
	emittedEvents[#emittedEvents + 1] = { name = name, payload = payload }
	return true
end
dofile([=[core/application/player_service.lua]=])

local function assertEqual(actual, expected, message)
	if actual ~= expected then
		error(('%s: expected %s, got %s'):format(message or 'assertEqual', tostring(expected), tostring(actual)))
	end
end

local function testLoadCreateSelectAndArchive()
	assertEqual(Core.Players.SetCharacterLimit(5), true, 'set character limit')
	assertEqual(Core.Players.SetCharacterLimit(0), false, 'reject invalid character limit')
	Core.Players.SetCharacterLimit(5)

	local loaded, session, characters
	assertEqual(Core.Players.LoadSession(42, 'license:abcdef123', function(success, result, list)
		loaded, session, characters = success, result, list
	end), true, 'load session dispatched')
	assertEqual(loaded, true, 'session loaded')
	assertEqual(session.state, 'character_selection', 'character selection required')
	assertEqual(session.playerId, '7', 'persistent player ID')
	assertEqual(#characters, 1, 'character list')

	local created, newCharacter
	assertEqual(Core.Players.CreateCharacter(42, '  Maria ', 'Costa', nil, function(success, result)
		created, newCharacter = success, result
	end), true, 'create character dispatched')
	assertEqual(created, true, 'character created')
	assertEqual(newCharacter.firstName, 'Maria', 'first name normalized')
	assertEqual(newCharacter.lastName, 'Costa', 'last name normalized')
	local createdEvent
	for _, event in ipairs(emittedEvents) do
		if event.name == 'player.characterCreated' and event.payload.source == 42 then
			createdEvent = event.payload
		end
	end
	assertEqual(createdEvent.character.stateId, 'WXYZ6789', 'characterCreated event carries the new character')
	assertEqual(createdEvent.playerId, '7', 'characterCreated event carries the player')

	local selected, character
	assertEqual(Core.Players.SelectCharacter(42, '10', function(success, result)
		selected, character = success, result
	end), true, 'select character dispatched')
	assertEqual(selected, true, 'character selected')
	assertEqual(character.characterId, '10', 'selected character ID')
	assertEqual(Core.Players.GetActiveCharacterId(42), '10', 'active character ID')
	assertEqual(Core.Players.GetActiveCharacter(42).stateId, 'ABCD2345', 'active snapshot has stateId')
	assertEqual(Core.Players.GetCharacterByStateId('ABCD2345').characterId, '10', 'lookup character by stateId')
	local byState = Core.Players.GetPlayerByStateId('ABCD2345')
	assertEqual(byState.source, 42, 'lookup player source by stateId')
	assertEqual(byState.playerId, '7', 'lookup player id by stateId')
	local _, unknownState = Core.Players.GetCharacterByStateId('WXYZ6789')
	assertEqual(unknownState, 'character_not_online', 'unloaded stateId is not online')
	local _, badState = Core.Players.GetPlayerByStateId('abc')
	assertEqual(badState, 'invalid_state_id', 'malformed stateId is rejected')
	local loadedEvent
	for _, event in ipairs(emittedEvents) do
		if event.name == 'player.characterLoaded' and event.payload.source == 42 then
			loadedEvent = event.payload
		end
	end
	local generation = Core.SessionRegistry.Get(42).generation
	assertEqual(loadedEvent.generation, generation, 'loaded event is scoped to session generation')

	local archived, archiveError = Core.Players.ArchiveCharacter(42, '10', function(success)
		archived = success
	end)
	assertEqual(archived, false, 'cannot archive active character')
	assertEqual(archiveError, 'character_selection_required', 'active character archive error')

	local changed, availableCharacters
	assertEqual(Core.Players.ReturnToSelection(42, function(success, result)
		changed, availableCharacters = success, result
	end), true, 'return to selection dispatched')
	assertEqual(changed, true, 'returned to selection')
	assertEqual(Core.Players.GetActiveCharacterId(42), nil, 'active character cleared')
	local _, afterUnload = Core.Players.GetCharacterByStateId('ABCD2345')
	assertEqual(afterUnload, 'character_not_online', 'stateId lookup cleared after unload')
	assertEqual(#availableCharacters, 1, 'selection list refreshed')
	local unloadedEvent
	for _, event in ipairs(emittedEvents) do
		if event.name == 'player.characterUnloaded' and event.payload.source == 42 then
			unloadedEvent = event.payload
		end
	end
	assertEqual(unloadedEvent.generation, generation, 'unloaded event is scoped to session generation')

	assertEqual(Core.Players.ArchiveCharacter(42, '9', function(success)
		archived = success
	end), true, 'archive dispatched')
	assertEqual(archived, true, 'character archived')
end

local function testDuplicatePlayerAndStaleAsyncCompletion()
	local duplicateSuccess, duplicateError
	Core.Players.LoadSession(43, 'license:other', function(success, _, errorMessage)
		duplicateSuccess, duplicateError = success, errorMessage
	end)
	assertEqual(duplicateSuccess, false, 'duplicate account rejected')
	assertEqual(duplicateError, 'player_already_online', 'duplicate account error')
	assertEqual(Core.SessionRegistry.Get(43), nil, 'duplicate session removed')

	local staleResult, currentResult
	Core.Players.LoadSession(55, 'license:deferred', function(success, _, errorMessage)
		staleResult = success and 'loaded' or errorMessage
	end)
	local oldSession = Core.SessionRegistry.Get(55)
	assertEqual(Core.Players.Disconnect(55), true, 'old session disconnected')

	Core.Players.LoadSession(55, 'license:reused-source', function(success, _, errorMessage)
		currentResult = success and 'loaded' or errorMessage
	end)
	local newSession = Core.SessionRegistry.Get(55)
	assertEqual(oldSession.generation == newSession.generation, false, 'source generation changed')

	pendingLookups.deferred(true, '88')
	assertEqual(staleResult, 'stale_session', 'late old-session result rejected')
	assertEqual(Core.SessionRegistry.Get(55), newSession, 'late result preserves current session')

	pendingLookups.reused(true, '89')
	assertEqual(currentResult, 'loaded', 'current session loads')
	assertEqual(Core.Players.GetPlayerId(55), '89', 'current player identity')
end

local function testCharacterSlots()
	local done = false
	assertEqual(Core.Players.SetCharacterSlots('7', 3, function(ok) done = ok end), true, 'slots accepted')
	assertEqual(done, true, 'slots callback')
	assertEqual(Core.Players.SetCharacterSlots('7', nil, function() end), true, 'slots can be cleared')
	local _, e1 = Core.Players.SetCharacterSlots('7', 0, function() end)
	assertEqual(e1, 'invalid_character_slots', 'zero slots rejected')
	local _, e2 = Core.Players.SetCharacterSlots('7', 11, function() end)
	assertEqual(e2, 'invalid_character_slots', 'above hard limit rejected')
	local _, e3 = Core.Players.SetCharacterSlots('abc', 2, function() end)
	assertEqual(e3, 'invalid_player', 'invalid player rejected')
	assertEqual(Core.Players.SetCharacterHardLimit(4), true, 'hard limit set')
	local _, e4 = Core.Players.SetCharacterSlots('7', 5, function() end)
	assertEqual(e4, 'invalid_character_slots', 'hard limit applies')
	Core.Players.SetCharacterHardLimit(10)
end

local function testCharacterProfile()
	local loaded
	Core.Players.LoadSession(42, 'license:abcdef123', function(success) loaded = success end)
	assertEqual(loaded, true, 'session loaded for profile test')

	local before = #createdProfiles
	local created
	assertEqual(Core.Players.CreateCharacter(42, 'Maria', 'Costa', {
		birthDate = '1990-05-17', gender = 'Female', appearance = { hair = 3 }, appearanceVersion = 1
	}, function(success) created = success end), true, 'valid profile accepted')
	assertEqual(created, true, 'character with profile created')
	local profile = createdProfiles[before + 1]
	assertEqual(profile.gender, 'female', 'gender normalized before the repository')
	assertEqual(profile.appearanceJson, '{}', 'appearance serialized before the repository')

	local ok, err = Core.Players.CreateCharacter(42, 'Maria', 'Costa', { birthDate = '2999-01-01' }, function() end)
	assertEqual(ok, false, 'invalid profile rejected')
	assertEqual(err, 'birth_date_out_of_range', 'invalid profile error code')
	assertEqual(#createdProfiles, before + 1, 'repository not reached for invalid profile')

	local _, unknownError = Core.Players.CreateCharacter(42, 'Maria', 'Costa', { admin = true }, function() end)
	assertEqual(unknownError, 'invalid_profile', 'unknown profile key rejected')
	-- Rejeição não pode deixar a operação pendente (rate limit/ocupado).
	created = nil
	Core.Players.CreateCharacter(42, 'Maria', 'Costa', nil, function(success) created = success end)
	assertEqual(created, true, 'session still usable after rejected profile')
end

local function testInitialAppearance()
	-- Usa a sessão 42, que continua na seleção depois do teste de perfil.
	local done
	assertEqual(Core.Players.SetInitialAppearance(42, '10', { model = 'mp_f_freemode_01' }, 1, function(success) done = success end), true, 'appearance accepted')
	assertEqual(done, true, 'appearance saved')
	assertEqual(appearanceWrites[#appearanceWrites].json, '{}', 'appearance serialized before the repository')
	assertEqual(appearanceWrites[#appearanceWrites].version, 1, 'version forwarded')

	local result, errorCode
	Core.Players.SetInitialAppearance(42, '11', { model = 'mp_m_freemode_01' }, 1, function(success, _, err) result, errorCode = success, err end)
	assertEqual(result, false, 'existing appearance cannot be replaced')
	assertEqual(errorCode, 'appearance_locked', 'locked error code')

	local ok, err = Core.Players.SetInitialAppearance(42, '10', 'not a table', 1, function() end)
	assertEqual(ok, false, 'invalid appearance rejected')
	assertEqual(err, 'invalid_appearance', 'invalid appearance code')
	local _, missingVersion = Core.Players.SetInitialAppearance(42, '10', {}, nil, function() end)
	assertEqual(missingVersion, 'invalid_appearance', 'version required')
	local _, badId = Core.Players.SetInitialAppearance(42, 'abc', {}, 1, function() end)
	assertEqual(badId, 'invalid_character_id', 'character id validated')
	local _, noSession = Core.Players.SetInitialAppearance(999, '10', {}, 1, function() end)
	assertEqual(noSession ~= nil, true, 'requires a selection session')
end

testLoadCreateSelectAndArchive()
testCharacterSlots()
testCharacterProfile()
testInitialAppearance()
testDuplicatePlayerAndStaleAsyncCompletion()
print('player service tests passed')
