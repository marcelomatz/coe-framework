dofile([=[coe_database/test/integration/bridge.lua]=])
local assertEqual = Bridge.AssertEqual

dofile([=[coe_core/core/shared/bootstrap.lua]=])
dofile([=[coe_core/core/shared/functions.lua]=])
dofile([=[coe_core/core/shared/identity.lua]=])

local function adapt(operation)
	return function(sql, parameters, callback)
		local response = Bridge[operation](sql, parameters)
		callback(response.ok == true, response.result, response.error)
		return true
	end
end
Core.Database.Query = adapt('Query')
Core.Database.Execute = adapt('Execute')
Core.Database.Transaction = function(statements, callback)
	local response = Bridge.Transaction(statements)
	callback(response.ok == true, response.result, response.error)
	return true
end

dofile([=[coe_core/core/server/migrations.lua]=])
dofile([=[coe_core/core/server/group_definitions.lua]=])
dofile([=[coe_core/core/server/group_repository.lua]=])
dofile([=[coe_core/core/server/player_repository.lua]=])
local repository = Core.Repositories.Player

-- Migrations: aplicar duas vezes não replica nem falha.
for attempt = 1, 2 do
	local success, errorMessage = Bridge.Call(Core.Database.RunMigrations)
	assertEqual(success, true, 'migration run ' .. attempt .. ' ' .. tostring(errorMessage))
end
local versions = Bridge.Query('SELECT version, name FROM coe_schema_migrations')
assertEqual(#versions.result, 7, 'each migration recorded exactly once')
assertEqual(versions.result[4].name, 'player_settings', 'player settings migration name')
assertEqual(versions.result[5].name, 'character_profile', 'character profile migration name')
assertEqual(versions.result[6].name, 'groups', 'groups migration name')
assertEqual(versions.result[7].name, 'character_name_search', 'name search migration name')
assertEqual(versions.result[1].name, 'player_character_identity', 'migration name')
assertEqual(versions.result[2].name, 'character_state_id', 'state id migration name')
assertEqual(versions.result[3].name, 'character_state_id_required', 'state id required migration name')

-- Jogador: criação idempotente por license.
local ok, playerId = Bridge.Call(repository.FindOrCreateByLicense, 'license:abc123')
assertEqual(ok, true, 'create player')
local okAgain, samePlayerId = Bridge.Call(repository.FindOrCreateByLicense, 'license:abc123')
assertEqual(okAgain, true, 'find existing player')
assertEqual(samePlayerId, playerId, 'same license maps to the same player')
local _, otherPlayerId = Bridge.Call(repository.FindOrCreateByLicense, 'license:def456')
assert(otherPlayerId ~= playerId, 'different license maps to a different player')

-- Personagens: limite, unicode, propriedade e arquivamento.
local created, first = Bridge.Call(repository.CreateCharacter, playerId, 'José', 'Silva', {}, 2, 10)
assertEqual(created, true, 'create first character')
assertEqual(first.firstName, 'José', 'unicode name is kept')
assert(Core.Identity.IsValidStateId(first.stateId), 'created character has a valid state id')
local createdSecond = Bridge.Call(repository.CreateCharacter, playerId, 'Maria', 'Souza', {}, 2, 10)
assertEqual(createdSecond, true, 'create second character')
local limited, _, limitError = Bridge.Call(repository.CreateCharacter, playerId, 'Extra', 'Nome', {}, 2, 10)
assertEqual(limited, false, 'limit blocks creation')
assertEqual(limitError, 'character_limit_reached', 'limit error code')
local missingOk, _, missingError = Bridge.Call(repository.CreateCharacter, '999999', 'Fantasma', 'Nome', {}, 2, 10)
assertEqual(missingOk, false, 'unknown player rejected')
assertEqual(missingError, 'player_not_found', 'unknown player code')

local listed, characters = Bridge.Call(repository.ListCharacters, playerId)
assertEqual(listed, true, 'list characters')
assertEqual(#characters, 2, 'both characters listed')
assertEqual(characters[1].firstName, 'José', 'unicode survives the database round trip')

local foreignOk, _, foreignError = Bridge.Call(repository.GetOwnedCharacter, otherPlayerId, first.characterId)
assertEqual(foreignOk, false, 'foreign character is not accessible')
assertEqual(foreignError, 'character_not_found', 'foreign character code')
local ownedOk, owned = Bridge.Call(repository.GetOwnedCharacter, playerId, first.characterId)
assertEqual(ownedOk, true, 'owner reads the character')
assertEqual(owned.lastName, 'Silva', 'owner data')

local archived = Bridge.Call(repository.ArchiveCharacter, playerId, first.characterId)
assertEqual(archived, true, 'archive character')
local archivedAgain, _, archiveError = Bridge.Call(repository.ArchiveCharacter, playerId, first.characterId)
assertEqual(archivedAgain, false, 'second archive fails')
assertEqual(archiveError, 'character_not_found', 'second archive code')
local _, afterArchive = Bridge.Call(repository.ListCharacters, playerId)
assertEqual(#afterArchive, 1, 'archived character is hidden')
local recreated = Bridge.Call(repository.CreateCharacter, playerId, 'Novo', 'Nome', {}, 2, 10)
assertEqual(recreated, true, 'archiving frees a slot')

-- stateId: listagem e leitura devolvem o valor; o banco recusa duplicidade com o código usado nas retentativas.
assertEqual(Core.Identity.IsValidStateId(afterArchive[1].stateId), true, 'listed character has a state id')
local duplicate = Bridge.Execute(
	'INSERT INTO coe_characters (player_id, first_name, last_name, state_id) VALUES (?, ?, ?, ?)',
	{ playerId, 'Dup', 'Nome', afterArchive[1].stateId }
)
assertEqual(duplicate.ok, false, 'duplicate state id is rejected')
assertEqual(duplicate.error, 'ER_DUP_ENTRY', 'duplicate state id error code')

-- Migração sobre dados legados: personagem sem stateId é preenchido e a migração é idempotente.
Bridge.Execute('ALTER TABLE coe_characters MODIFY state_id CHAR(8) CHARACTER SET ascii COLLATE ascii_bin NULL', {})
Bridge.Execute(
	'INSERT INTO coe_characters (player_id, first_name, last_name, state_id) VALUES (?, ?, ?, NULL)',
	{ playerId, 'Legado', 'Antigo' }
)
Bridge.Execute('DELETE FROM coe_schema_migrations WHERE version IN (2, 3)', {})
local rerun, rerunError = Bridge.Call(Core.Database.RunMigrations)
assertEqual(rerun, true, 'migration rerun on legacy data ' .. tostring(rerunError))
local legacy = Bridge.Query('SELECT state_id FROM coe_characters WHERE first_name = ?', { 'Legado' })
assertEqual(Core.Identity.IsValidStateId(legacy.result[1].state_id), true, 'legacy character received a state id')
local missing = Bridge.Query('SELECT COUNT(*) AS total FROM coe_characters WHERE state_id IS NULL', {})
assertEqual(tonumber(missing.result[1].total), 0, 'no character is left without a state id')
local nullable = Bridge.Execute('INSERT INTO coe_characters (player_id, first_name, last_name) VALUES (?, ?, ?)', { playerId, 'Sem', 'Id' })
assertEqual(nullable.ok, false, 'state id is required after migration')

-- Slots por jogador: valor individual, teto absoluto e retorno ao padrão.
local _, slotPlayerId = Bridge.Call(repository.FindOrCreateByLicense, 'license:slots001')
local function createFor(name, defaultLimit, hardLimit)
	return Bridge.Call(repository.CreateCharacter, slotPlayerId, name, 'Slot', {}, defaultLimit, hardLimit)
end
assertEqual((createFor('Um', 1, 10)), true, 'default limit allows the first character')
local blockedByDefault, _, blockedError = createFor('Dois', 1, 10)
assertEqual(blockedByDefault, false, 'default limit blocks the second character')
assertEqual(blockedError, 'character_limit_reached', 'default limit error code')

assertEqual((Bridge.Call(repository.SetCharacterSlots, slotPlayerId, 3)), true, 'set player slots')
assertEqual((createFor('Dois', 1, 10)), true, 'player slots raise the limit')
assertEqual((createFor('Tres', 1, 10)), true, 'player slots allow up to the configured value')
assertEqual((createFor('Quatro', 1, 10)), false, 'player slots are still a limit')

assertEqual((Bridge.Call(repository.SetCharacterSlots, slotPlayerId, 9)), true, 'set a large value')
assertEqual((createFor('Quatro', 1, 3)), false, 'hard limit caps a larger player value')
assertEqual((createFor('Quatro', 1, 4)), true, 'raising the hard limit allows one more')

assertEqual((Bridge.Call(repository.SetCharacterSlots, slotPlayerId, 0)), true, 'clear player slots (0 clears)')
assertEqual((createFor('Cinco', 1, 10)), false, 'cleared value falls back to the default')
local missingSlots, missingSlotsError = Bridge.Call(repository.SetCharacterSlots, '999999', 2)
assertEqual(missingSlots, false, 'slots for an unknown player are rejected')
assertEqual(missingSlotsError, 'player_not_found', 'unknown player slots code')

-- Perfil: nascimento, gênero e aparência persistem; ausentes ficam NULL; nada disso vaza no limite de slots.
local _, profilePlayerId = Bridge.Call(repository.FindOrCreateByLicense, 'license:profile001')
local withProfileOk, withProfile = Bridge.Call(repository.CreateCharacter, profilePlayerId, 'Perfil', 'Completo', {
	birthDate = '1990-05-17', gender = 'female', appearanceJson = '{"hair":3}', appearanceVersion = 2
}, 5, 10)
assertEqual(withProfileOk, true, 'create character with profile')
assertEqual(withProfile.birthDate, '1990-05-17', 'created snapshot birth date')
local emptyOk, emptyProfile = Bridge.Call(repository.CreateCharacter, profilePlayerId, 'Perfil', 'Vazio', {}, 5, 10)
assertEqual(emptyOk, true, 'create character without profile')
assertEqual(emptyProfile.birthDate, nil, 'no birth date in the snapshot')
local profileRead, profileOwned = Bridge.Call(repository.GetOwnedCharacter, profilePlayerId, withProfile.characterId)
assertEqual(profileRead, true, 'read character with profile')
assertEqual(profileOwned.birthDate, '1990-05-17', 'birth date round trip as YYYY-MM-DD')
assertEqual(profileOwned.gender, 'female', 'gender round trip')
local profileList = select(2, Bridge.Call(repository.ListCharacters, profilePlayerId))
assertEqual(profileList[1].birthDate, '1990-05-17', 'listed birth date')
assertEqual(profileList[2].birthDate, nil, 'missing birth date stays nil')
assertEqual(profileList[2].gender, nil, 'missing gender stays nil')
local stored = Bridge.Query('SELECT appearance, appearance_version FROM coe_characters WHERE character_id = ?', { withProfile.characterId })
-- O driver pode devolver o JSON já decodificado (tabela) ou como texto.
local storedAppearance = stored.result[1].appearance
local hair = type(storedAppearance) == 'table' and storedAppearance.hair
	or (tostring(storedAppearance):match('"hair":%s*(%d+)'))
assertEqual(tonumber(hair), 3, 'appearance stored as sent')
assertEqual(tonumber(stored.result[1].appearance_version), 2, 'appearance version stored')
local blank = Bridge.Query('SELECT appearance, appearance_version, gender FROM coe_characters WHERE character_id = ?', { emptyProfile.characterId })
assertEqual(blank.result[1].appearance, nil, 'missing appearance is NULL')
assertEqual(blank.result[1].appearance_version, nil, 'missing appearance version is NULL')
assertEqual(blank.result[1].gender, nil, 'missing gender is NULL')

-- Grupos: sync idempotente, sem apagar, e um grupo ativo por tipo garantido pelo banco.
local groupsConfig = {
	Types = { 'job', 'gang' },
	Groups = {
		police = { type = 'job', label = 'Polícia', grades = { [0] = { label = 'Cadete' } } },
		ambulance = { type = 'job', label = 'Hospital', grades = { [0] = { label = 'Estagiário' } } },
		ballas = { type = 'gang', label = 'Ballas', grades = { [0] = { label = 'Membro' } } }
	}
}
assertEqual(Core.Groups.SetDefinitions(groupsConfig), true, 'group definitions')
for attempt = 1, 2 do
	local synced, syncError = Bridge.Call(Core.Groups.Sync)
	assertEqual(synced, true, 'group sync ' .. attempt .. ' ' .. tostring(syncError))
end
local groupRows = Bridge.Query('SELECT name, type, label FROM coe_groups ORDER BY name')
assertEqual(#groupRows.result, 3, 'groups synced once')
groupsConfig.Groups.police.label = 'Polícia Militar'
Core.Groups.SetDefinitions(groupsConfig)
Bridge.Call(Core.Groups.Sync)
assertEqual(Bridge.Query('SELECT label FROM coe_groups WHERE name = ?', { 'police' }).result[1].label, 'Polícia Militar', 'label updated')
groupsConfig.Groups.police.type = 'gang'
Core.Groups.SetDefinitions(groupsConfig)
local typeSynced, typeError = Bridge.Call(Core.Groups.Sync)
assertEqual(typeSynced, false, 'type change refused')
assertEqual(typeError, 'group_type_changed', 'type change code')

local function link(characterId, name, groupType, grade, active)
	return Bridge.Execute('INSERT INTO coe_character_groups (character_id, group_name, group_type, grade, active) VALUES (?, ?, ?, ?, ?)',
		{ characterId, name, groupType, grade, active })
end
local groupCharacterId = withProfile.characterId
assertEqual(link(groupCharacterId, 'police', 'job', 0, 1).ok, true, 'active job linked')
assertEqual(link(groupCharacterId, 'ambulance', 'job', 0, 1).ok, false, 'second active job is refused')
assertEqual(link(groupCharacterId, 'ambulance', 'job', 0, 0).ok, true, 'inactive job allowed')
assertEqual(link(groupCharacterId, 'ballas', 'gang', 0, 1).ok, true, 'active gang alongside active job')
assertEqual(link(groupCharacterId, 'ballas', 'job', 0, 0).ok, false, 'wrong type breaks the composite foreign key')
assertEqual(Bridge.Execute('DELETE FROM coe_groups WHERE name = ?', { 'police' }).ok, false, 'linked group cannot be deleted')

-- Repositório de vínculos: WriteLink troca o ativo do tipo de forma atômica.
local switchOk = Bridge.Call(Core.Groups.WriteLink, groupCharacterId, { name = 'ambulance', type = 'job' }, 0)
assertEqual(switchOk, true, 'switch active job')
local _, linkRows = Bridge.Call(Core.Groups.LoadLinks, groupCharacterId)
local byName = {}
for _, row in ipairs(linkRows) do byName[row.name] = row end
assertEqual(byName.ambulance.active, true, 'new job active')
assertEqual(byName.police.active, false, 'old job deactivated')
assertEqual(byName.ballas.active, true, 'gang untouched')
local gradeOk = Bridge.Call(Core.Groups.WriteLink, groupCharacterId, { name = 'ambulance', type = 'job' }, 3)
assertEqual(gradeOk, true, 'regrade existing link')
local _, regraded = Bridge.Call(Core.Groups.LoadLinks, groupCharacterId)
for _, row in ipairs(regraded) do
	if row.name == 'ambulance' then assertEqual(row.grade, 3, 'grade updated') end
end
local missingOk, missingError = Bridge.Call(Core.Groups.WriteLink, '999999', { name = 'ambulance', type = 'job' }, 0)
assertEqual(missingOk, false, 'unknown character rejected')
assertEqual(missingError, 'transaction_failed', 'unknown character fails the transaction')
assertEqual(Bridge.Call(Core.Groups.DeleteLink, groupCharacterId, 'ballas'), true, 'delete link')
local _, afterDelete = Bridge.Call(Core.Groups.LoadLinks, groupCharacterId)
assertEqual(#afterDelete, 2, 'link removed')

Bridge.Done()
