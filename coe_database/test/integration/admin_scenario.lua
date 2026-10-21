dofile([=[coe_database/test/integration/bridge.lua]=])
local assertEqual = Bridge.AssertEqual
Bridge.InstallFiveMStubs()

dofile([=[coe_core/lib/migrations.lua]=])
dofile([=[coe_admin/server/migrations.lua]=])
dofile([=[coe_admin/server/persistence.lua]=])

for attempt = 1, 2 do
	local ok, errorCode = AdminPersistence.Initialize()
	assertEqual(ok, true, 'admin initialize ' .. attempt .. ' ' .. tostring(errorCode))
end
local versions = Bridge.Query('SELECT version, name FROM coe_admin_schema_migrations')
assertEqual(#versions.result, 1, 'admin migration recorded once')
assertEqual(versions.result[1].name, 'admin_staff', 'admin migration name')

assertEqual(AdminPersistence.SetRole('license:abc123', 'admin'), true, 'insert role')
assertEqual(AdminPersistence.SetRole('license:def456', 'moderator'), true, 'insert second role')
assertEqual(AdminPersistence.SetRole('license:abc123', 'moderator'), true, 'upsert role')

local staff = AdminPersistence.Load()
assertEqual(staff['license:abc123'].role, 'moderator', 'upsert persisted')
assertEqual(staff['license:def456'].role, 'moderator', 'second role loaded')

assertEqual(AdminPersistence.RemoveRole('license:abc123'), true, 'remove role')
local afterRemove = AdminPersistence.Load()
assertEqual(afterRemove['license:abc123'], nil, 'role removed')
assertEqual(afterRemove['license:def456'].role, 'moderator', 'other roles untouched')

Bridge.Done()
