dofile([=[coe_database/test/integration/bridge.lua]=])
local assertEqual = Bridge.AssertEqual
Bridge.InstallFiveMStubs()

dofile([=[coe_core/lib/migrations.lua]=])
dofile([=[coe_audit/server/migrations.lua]=])
dofile([=[coe_audit/server/persistence.lua]=])

for attempt = 1, 2 do
	local ok, errorCode = AuditPersistence.Initialize()
	assertEqual(ok, true, 'audit initialize ' .. attempt .. ' ' .. tostring(errorCode))
end
local versions = Bridge.Query('SELECT version, name FROM coe_audit_schema_migrations')
assertEqual(#versions.result, 1, 'audit migration recorded once')
assertEqual(versions.result[1].name, 'audit_log', 'audit migration name')

local function entry(overrides)
	local base = {
		occurred_at = '2026-01-01 10:00:00',
		severity = 'info',
		category = 'audit',
		event = 'admin_item_granted',
		resource = 'coe_admin',
		actor_license = 'license:abc',
		target_license = '',
		context_json = '{"item":"water","count":2}'
	}
	for key, value in pairs(overrides or {}) do
		base[key] = value
	end
	return base
end

local inserted, insertError = AuditPersistence.InsertBatch({
	entry(),
	entry({ event = 'staff_role_assigned', actor_license = '', target_license = 'license:def', occurred_at = '2020-01-01 00:00:00' })
})
assertEqual(inserted, true, 'batch insert ' .. tostring(insertError))

local rows = Bridge.Query('SELECT event, actor_license, target_license, context FROM coe_audit_log ORDER BY id').result
assertEqual(#rows, 2, 'duas linhas gravadas')
assertEqual(rows[1].actor_license, 'license:abc', 'ator gravado')
assertEqual(rows[1].target_license, nil, 'alvo vazio vira NULL')
assertEqual(rows[2].actor_license, nil, 'ator vazio vira NULL')
assertEqual(rows[2].target_license, 'license:def', 'alvo gravado')
assertEqual(rows[1].context.item, 'water', 'contexto JSON preservado')
assertEqual(rows[1].context.count, 2, 'contexto JSON numérico preservado')

local badInsert = AuditPersistence.InsertBatch({ entry({ severity = string.rep('x', 20) }) })
assertEqual(badInsert, false, 'lote inválido falha')
assertEqual(#Bridge.Query('SELECT id FROM coe_audit_log').result, 2, 'lote com erro não grava nada')

local removed, purgeError = AuditPersistence.Purge(365, 100)
assertEqual(purgeError, nil, 'purge sem erro')
assertEqual(removed, 1, 'purge remove só o antigo')
local remaining = Bridge.Query('SELECT event FROM coe_audit_log').result
assertEqual(#remaining, 1, 'registro recente mantido')
assertEqual(remaining[1].event, 'admin_item_granted', 'registro correto mantido')

Bridge.Done()
