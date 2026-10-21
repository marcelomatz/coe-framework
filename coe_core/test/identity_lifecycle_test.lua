dofile([=[core/shared/bootstrap.lua]=])
dofile([=[core/shared/functions.lua]=])
dofile([=[core/shared/identity.lua]=])
dofile([=[core/server/session_registry.lua]=])

local function assertEqual(actual, expected, message)
	if actual ~= expected then
		error(('%s: expected %s, got %s'):format(message or 'assertEqual', tostring(expected), tostring(actual)))
	end
end

local function testIdentityRules()
	assertEqual(Core.Identity.NormalizeLicense('license:abcdef123'), 'license:abcdef123', 'license')
	local invalidLicense, licenseError = Core.Identity.NormalizeLicense('license2:abcdef123')
	assertEqual(invalidLicense, nil, 'license2 rejected')
	assertEqual(licenseError, 'license_unavailable', 'license error')

	assertEqual(Core.Identity.NormalizeCharacterName('  José  '), 'José', 'unicode name trimmed')
	assertEqual(Core.Identity.NormalizeCharacterName("D'Ávila"), "D'Ávila", 'apostrophe accepted')

	local blankName, blankError = Core.Identity.NormalizeCharacterName('  ')
	assertEqual(blankName, nil, 'blank name rejected')
	assertEqual(blankError, 'invalid_character_name', 'blank-name error')

	local longName, longError = Core.Identity.NormalizeCharacterName(string.rep('a', 49))
	assertEqual(longName, nil, 'long name rejected')
	assertEqual(longError, 'invalid_character_name', 'long-name error')

	local invalidUtf8, utf8Error = Core.Identity.NormalizeCharacterName(string.char(255))
	assertEqual(invalidUtf8, nil, 'invalid UTF-8 rejected')
	assertEqual(utf8Error, 'invalid_character_name', 'UTF-8 error')

	assertEqual(Core.Identity.IsValidCharacterId('18446744073709551615'), true, '64-bit string ID')
	assertEqual(Core.Identity.IsValidCharacterId('0'), false, 'zero ID rejected')
	assertEqual(Core.Identity.IsValidCharacterId('01'), false, 'noncanonical ID rejected')
	assertEqual(Core.Identity.IsValidCharacterId(1), false, 'numeric ID rejected')
end

local function testSessionLifecycleAndSourceReuse()
	local session, createError = Core.SessionRegistry.Create(42)
	assertEqual(createError, nil, 'session create')
	assertEqual(session.state, 'identifying', 'initial state')

	assertEqual(Core.SessionRegistry.MarkPlayerLoaded(session, '7'), true, 'player loaded')
	assertEqual(session.state, 'player_loaded', 'player state')
	assertEqual(Core.SessionRegistry.BeginCharacterSelection(session), true, 'selection state')
	assertEqual(Core.SessionRegistry.MarkCharacterLoaded(session, {
		characterId = '9',
		playerId = '7',
		firstName = 'Ana',
		lastName = 'Silva'
	}), true, 'character loaded')
	assertEqual(session.character.characterId, '9', 'active character')

	local reusedSession = Core.SessionRegistry.Create(42)
	assertEqual(Core.SessionRegistry.IsCurrent(42, session.generation), false, 'old generation invalidated')
	local staleResult, staleError = Core.SessionRegistry.BeginCharacterSelection(session)
	assertEqual(staleResult, false, 'stale session rejected')
	assertEqual(staleError, 'stale_session', 'stale error')
	assertEqual(Core.SessionRegistry.IsCurrent(42, reusedSession.generation), true, 'new generation remains current')

	assertEqual(Core.SessionRegistry.MarkPlayerLoaded(reusedSession, '8'), true, 'new player loaded')
	assertEqual(Core.SessionRegistry.BeginCharacterSelection(reusedSession), true, 'new selection state')
	local wrongOwner, ownerError = Core.SessionRegistry.MarkCharacterLoaded(reusedSession, {
		characterId = '10',
		playerId = '7'
	})
	assertEqual(wrongOwner, false, 'foreign character rejected')
	assertEqual(ownerError, 'character_owner_mismatch', 'ownership error')

	local removed, removeError = Core.SessionRegistry.Remove(42, reusedSession.generation)
	assertEqual(removeError, nil, 'session removed')
	assertEqual(removed.state, 'disconnected', 'disconnected state')
	assertEqual(Core.SessionRegistry.Get(42), nil, 'session registry cleaned')
end

testIdentityRules()
testSessionLifecycleAndSourceReuse()
print('identity lifecycle tests passed')
