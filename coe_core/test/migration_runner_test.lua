dofile([=[lib/migrations.lua]=])

local function assertEqual(actual, expected, message)
	if actual ~= expected then
		error(('%s: expected %s, got %s'):format(message, tostring(expected), tostring(actual)))
	end
end

local function harness(appliedRows, failOn)
	local log = {}
	return log, {
		tableName = 'coe_demo_schema_migrations',
		migrations = {
			{ version = 1, name = 'one', statements = { 'CREATE A', 'CREATE B' } },
			{ version = 2, name = 'two', statements = { 'ALTER A' } }
		},
		execute = function(sql, parameters)
			log[#log + 1] = { sql = sql, parameters = parameters }
			if failOn and sql:find(failOn, 1, true) then
				return nil, 'query_failed'
			end
			return { affectedRows = 1 }
		end,
		query = function()
			return appliedRows
		end
	}
end

local log, options = harness({})
local ok, err, count = CoeMigrations.Run(options)
assertEqual(ok, true, 'fresh run succeeds')
assertEqual(err, nil, 'fresh run has no error')
assertEqual(count, 2, 'both migrations applied')
assertEqual(#log, 6, 'version table, A, B, record 1, ALTER, record 2')
assertEqual(log[1].sql:find('coe_demo_schema_migrations', 1, true) ~= nil, true, 'version table first')
assertEqual(log[4].parameters[1], 1, 'version 1 recorded after its statements')
assertEqual(log[6].parameters[2], 'two', 'version 2 recorded last')

log, options = harness({ { version = 1 } })
ok, _, count = CoeMigrations.Run(options)
assertEqual(ok, true, 'partially applied run succeeds')
assertEqual(count, 1, 'only pending migration applied')
assertEqual(log[2].sql, 'ALTER A', 'applied migration is not replayed')

log, options = harness({ { version = 1 }, { version = '2' } })
ok, _, count = CoeMigrations.Run(options)
assertEqual(ok, true, 'fully applied run succeeds')
assertEqual(count, 0, 'nothing to apply')
assertEqual(#log, 1, 'only the version table is touched')

log, options = harness({}, 'CREATE B')
ok, err = CoeMigrations.Run(options)
assertEqual(ok, false, 'failure is propagated')
assertEqual(err, 'query_failed', 'failure code')
for _, entry in ipairs(log) do
	assertEqual(entry.sql:find('ALTER A', 1, true), nil, 'later statements do not run after failure')
	assertEqual(entry.sql:find('INSERT INTO', 1, true), nil, 'failed migration is not recorded')
end

log, options = harness(nil)
options.query = function() return nil, 'database_error' end
ok, err = CoeMigrations.Run(options)
assertEqual(ok, false, 'query failure is propagated')
assertEqual(err, 'database_error', 'query failure code')

log, options = harness({})
options.tableName = 'bad name; DROP'
ok, err = CoeMigrations.Run(options)
assertEqual(ok, false, 'unsafe table name rejected')
assertEqual(err, 'invalid_options', 'unsafe table name code')
assertEqual(#log, 0, 'nothing executed for invalid options')

log, options = harness({})
options.migrations = { { version = 2, name = 'b', statements = { 'X' } }, { version = 1, name = 'a', statements = { 'Y' } } }
ok, err = CoeMigrations.Run(options)
assertEqual(ok, false, 'non-ascending versions rejected')
assertEqual(err, 'invalid_migrations', 'non-ascending versions code')

for _, resourceMigrations in ipairs({ '..\\coe_inventory\\adapters\\migrations.lua', '..\\coe_admin\\server\\migrations.lua' }) do
	dofile(resourceMigrations)
end
for _, definitions in ipairs({ InventoryMigrations, AdminMigrations }) do
	log, options = harness({})
	options.migrations = definitions
	ok, err = CoeMigrations.Run(options)
	assertEqual(ok, true, 'shipped migrations are valid')
end

print('migration runner tests passed')
