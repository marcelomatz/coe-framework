dofile([=[core/shared/bootstrap.lua]=])
dofile([=[core/shared/functions.lua]=])
dofile([=[core/shared/identity.lua]=])
dofile([=[core/server/migrations.lua]=])

local function assertEqual(actual, expected, message)
	if actual ~= expected then
		error(('%s: expected %s, got %s'):format(message or 'assertEqual', tostring(expected), tostring(actual)))
	end
end

local function runMigrationHarness(appliedRows, failedStatement, legacyRows, duplicateStateIds)
	local executed = {}
	local duplicatesLeft = duplicateStateIds or 0
	Core.Database.Execute = function(sql, parameters, callback)
		executed[#executed + 1] = { sql = sql, parameters = parameters }
		if failedStatement and sql:find(failedStatement, 1, true) then
			callback(false, nil, 'query_failed')
		elseif sql:find('UPDATE coe_characters SET state_id', 1, true) and duplicatesLeft > 0 then
			duplicatesLeft = duplicatesLeft - 1
			callback(false, nil, 'ER_DUP_ENTRY')
		else
			callback(true, { affectedRows = 1 })
		end
		return true
	end
	Core.Database.Query = function(sql, parameters, callback)
		executed[#executed + 1] = { sql = sql, parameters = parameters }
		if sql:find('FROM coe_characters', 1, true) then
			callback(true, legacyRows or {})
		else
			callback(true, appliedRows)
		end
		return true
	end

	local outcome
	local dispatched, dispatchError = Core.Database.RunMigrations(function(success, errorMessage)
		outcome = { success = success, errorMessage = errorMessage }
	end)
	assertEqual(dispatched, true, 'migration dispatched')
	assertEqual(dispatchError, nil, 'migration dispatch error')
	return executed, outcome
end

local executed, outcome = runMigrationHarness({})
assertEqual(outcome.success, true, 'new schema migration succeeds')
assertEqual(executed[1].sql:find('coe_schema_migrations', 1, true) ~= nil, true, 'version table first')
assertEqual(executed[3].sql:find('CREATE TABLE IF NOT EXISTS coe_players', 1, true) ~= nil, true, 'player table')
assertEqual(executed[4].sql:find('coe_player_identifiers', 1, true) ~= nil, true, 'identifier table')
assertEqual(executed[5].sql:find('coe_characters', 1, true) ~= nil, true, 'character table')
assertEqual(executed[6].sql:find('INSERT INTO coe_schema_migrations', 1, true) ~= nil, true, 'version 1 recorded')
assertEqual(executed[7].sql:find('ADD COLUMN IF NOT EXISTS state_id', 1, true) ~= nil, true, 'state_id column added')
assertEqual(executed[8].sql:find('UNIQUE INDEX IF NOT EXISTS', 1, true) ~= nil, true, 'state_id unique index')
assertEqual(executed[9].sql:find('WHERE state_id IS NULL', 1, true) ~= nil, true, 'backfill looks for missing state_id')
assertEqual(executed[10].sql:find('INSERT INTO coe_schema_migrations', 1, true) ~= nil, true, 'version 2 recorded after backfill')
assertEqual(executed[11].sql:find('NOT NULL', 1, true) ~= nil, true, 'state_id becomes required')
assertEqual(executed[13].sql:find('coe_player_settings', 1, true) ~= nil, true, 'player settings table')
assertEqual(executed[15].sql:find('ADD COLUMN IF NOT EXISTS birth_date', 1, true) ~= nil, true, 'profile columns added')
assertEqual(executed[16].parameters[1], 5, 'version 5 recorded')
assertEqual(executed[17].sql:find('CREATE TABLE IF NOT EXISTS coe_groups', 1, true) ~= nil, true, 'groups table')
assertEqual(executed[18].sql:find('GENERATED ALWAYS AS (IF(active = 1, group_type, NULL)) STORED', 1, true) ~= nil, true,
	'active_type generated column')
assertEqual(executed[18].sql:find('UNIQUE KEY uq_coe_character_groups_active (character_id, active_type)', 1, true) ~= nil, true,
	'one active group per type is enforced by the database')
assertEqual(executed[18].sql:find('FOREIGN KEY (group_name, group_type) REFERENCES coe_groups (name, type)', 1, true) ~= nil, true,
	'group type is part of the foreign key')
assertEqual(executed[#executed - 2].sql:find('ix_coe_characters_first_name', 1, true) ~= nil, true, 'first name index')
assertEqual(executed[#executed - 1].sql:find('ix_coe_characters_last_name', 1, true) ~= nil, true, 'last name index')
assertEqual(executed[#executed].parameters[1], 7, 'version 7 recorded last')

local existingExecutions, existingOutcome = runMigrationHarness({ { version = 1 }, { version = 2 }, { version = 3 }, { version = 4 }, { version = 5 }, { version = 6 }, { version = 7 } })
assertEqual(existingOutcome.success, true, 'existing schema is accepted')
assertEqual(#existingExecutions, 2, 'applied migrations are not replayed')

local failedExecutions, failedOutcome = runMigrationHarness({}, 'coe_player_identifiers')
assertEqual(failedOutcome.success, false, 'schema failure is propagated')
assertEqual(failedOutcome.errorMessage, 'query_failed', 'schema failure code')
assertEqual(#failedExecutions, 4, 'later migrations do not run after failure')

-- Backfill: cada personagem sem stateId recebe um valor válido.
local backfillExecutions, backfillOutcome = runMigrationHarness(
	{ { version = 1 } }, nil, { { character_id = 7 }, { character_id = 9 } }
)
assertEqual(backfillOutcome.success, true, 'backfill succeeds')
local assigned = {}
for _, entry in ipairs(backfillExecutions) do
	if entry.sql:find('UPDATE coe_characters SET state_id', 1, true) then
		assigned[#assigned + 1] = entry.parameters
	end
end
assertEqual(#assigned, 2, 'one update per legacy character')
assertEqual(Core.Identity.IsValidStateId(assigned[1][1]), true, 'generated state id is valid')
assertEqual(assigned[1][2], 7, 'first legacy character updated')
assertEqual(assigned[2][2], 9, 'second legacy character updated')

-- Colisão: repete com outro valor e conclui.
local _, retryOutcome = runMigrationHarness({ { version = 1 } }, nil, { { character_id = 7 } }, 2)
assertEqual(retryOutcome.success, true, 'duplicate state id is retried')

-- Colisões persistentes falham e impedem a migração 3.
local stuckExecutions, stuckOutcome = runMigrationHarness({ { version = 1 } }, nil, { { character_id = 7 } }, 99)
assertEqual(stuckOutcome.success, false, 'persistent duplicates fail the migration')
assertEqual(stuckOutcome.errorMessage, 'ER_DUP_ENTRY', 'duplicate error code is reported')
for _, entry in ipairs(stuckExecutions) do
	assertEqual(entry.sql:find('MODIFY state_id', 1, true), nil, 'NOT NULL is never applied after a failed backfill')
end

-- Gerador e validador de stateId.
for _ = 1, 200 do
	assertEqual(Core.Identity.IsValidStateId(Core.Identity.GenerateStateId()), true, 'generator output validates')
end
for _, invalid in ipairs({ '', 'K7M2QX9', 'K7M2QX9RR', 'K7M2QX9O', 'k7m2qx9r', 'K7M2QX90', 12345678, false }) do
	assertEqual(Core.Identity.IsValidStateId(invalid), false, 'rejects ' .. tostring(invalid))
end

print('database migration tests passed')