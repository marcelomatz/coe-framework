dofile([=[coe_database/test/integration/bridge.lua]=])
local assertEqual = Bridge.AssertEqual
Bridge.InstallFiveMStubs()

Inventory = {}
dofile([=[coe_core/lib/migrations.lua]=])
dofile([=[coe_inventory/adapters/migrations.lua]=])
dofile([=[coe_core/lib/logger.lua]=])
dofile([=[coe_inventory/adapters/persistence.lua]=])
local persistence = Inventory.Persistence

for attempt = 1, 2 do
	local ok, errorCode = persistence.Initialize()
	assertEqual(ok, true, 'inventory initialize ' .. attempt .. ' ' .. tostring(errorCode))
end
local versions = Bridge.Query('SELECT version, name FROM coe_inventory_schema_migrations')
assertEqual(#versions.result, 1, 'inventory migration recorded once')
assertEqual(versions.result[1].name, 'inventory_records', 'inventory migration name')

local missing, missingError = persistence.Get('character:77')
assertEqual(missing, nil, 'missing record is nil')
assertEqual(missingError, nil, 'missing record is not an error')

assertEqual(persistence.Set('character:77', '{"items":["café"]}'), true, 'insert record')
assertEqual(persistence.Get('character:77'), '{"items":["café"]}', 'read back with unicode')
assertEqual(persistence.Set('character:77', '{"items":[]}'), true, 'upsert record')
assertEqual(persistence.Get('character:77'), '{"items":[]}', 'upsert replaced the value')
assertEqual(persistence.Set('character:77', '{invalid'), false, 'invalid JSON rejected')

assertEqual(persistence.SetMany({
	{ key = 'character:1', value = '{"a":1}' },
	{ key = 'stash:1', value = '{"b":2}' }
}), true, 'transactional batch')
assertEqual(persistence.Get('stash:1'), '{"b":2}', 'batch record persisted')

assertEqual(persistence.Delete('stash:1'), true, 'delete record')
assertEqual(persistence.Get('stash:1'), nil, 'record removed')

Bridge.Done()
