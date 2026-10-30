dofile([=[coe_database/test/integration/bridge.lua]=])
local assertEqual = Bridge.AssertEqual
Bridge.InstallFiveMStubs()

-- Carrega o executor padronizado de migrações
dofile([=[coe_core/lib/migrations.lua]=])
dofile([=[coe_core/lib/logger.lua]=])

-- Carrega bootstrap e migrações do coe_core
dofile([=[coe_core/core/shared/bootstrap.lua]=])
dofile([=[coe_core/core/shared/functions.lua]=])
dofile([=[coe_core/core/shared/identity.lua]=])

local function adaptCore(operation)
	return function(sql, parameters, callback)
		local response = Bridge[operation](sql, parameters)
		callback(response.ok == true, response.result, response.error)
		return true
	end
end
Core.Database.Query = adaptCore('Query')
Core.Database.Execute = adaptCore('Execute')
Core.Database.Transaction = function(statements, callback)
	local response = Bridge.Transaction(statements)
	callback(response.ok == true, response.result, response.error)
	return true
end

dofile([=[coe_core/core/server/migrations.lua]=])

-- Helper genérico para rodar migrações de qualquer resource
local function runResourceMigrations(name, migrations, tableName)
	local success, err = CoeMigrations.Run({
		tableName = tableName or (name .. '_schema_migrations'),
		migrations = migrations,
		execute = function(sql, parameters)
			local response = Bridge.Execute(sql, parameters)
			if not response.ok then
				return false, response.error
			end
			return true
		end,
		query = function(sql, parameters)
			local response = Bridge.Query(sql, parameters)
			if not response.ok then
				return nil, response.error
			end
			return response.result
		end
	})
	return success, err
end

-- Migrações de todos os resources do framework que têm banco (além do coe_core). Um resource novo com
-- migrations precisa entrar aqui; o teste compara com os arquivos existentes no repositório.
local migrationDefs = {
	{ resource = 'coe_audit', file = 'coe_audit/server/migrations.lua', get = function() return AuditMigrations end },
	{ resource = 'coe_economy', file = 'coe_economy/server/migrations.lua', get = function() return EconomyMigrations end },
	{ resource = 'coe_inventory', file = 'coe_inventory/adapters/migrations.lua', get = function() return InventoryMigrations end },
	{ resource = 'coe_businesses', file = 'coe_businesses/server/migrations.lua', get = function() return BusinessesMigrations end },
	{ resource = 'coe_jobs', file = 'coe_jobs/server/migrations.lua', get = function() return JobsMigrations end },
	{ resource = 'coe_vehicles', file = 'coe_vehicles/server/migrations.lua', get = function() return VehiclesMigrations end },
	{ resource = 'coe_vehicle_catalog', file = 'coe_vehicle_catalog/server/migrations.lua', get = function() return VehicleCatalogMigrations end },
	{ resource = 'coe_garage', file = 'coe_garage/adapters/migrations.lua', get = function() return GarageMigrations end },
	{ resource = 'coe_shops', file = 'coe_shops/server/migrations.lua', get = function() return ShopsMigrations end },
	{ resource = 'coe_mobile', file = 'coe_mobile/server/migrations.lua', get = function() return MobileMigrations end },
	{ resource = 'coe_rentals', file = 'coe_rentals/server/migrations.lua', get = function() return RentalsMigrations end },
	-- coe_needs usa o formato { resource, versions } do CoeMigrations; roda pelo próprio Initialize.
	{ resource = 'coe_needs', file = 'coe_needs/adapters/migrations.lua', extra = 'coe_needs/adapters/persistence.lua',
		initialize = function() return NeedsPersistence.Initialize() end },
	{ resource = 'coe_spawn', file = 'coe_spawn/server/migrations.lua', get = function() return SpawnMigrations end }
}

-- Nenhum arquivo de migrations do repositório pode ficar fora da lista acima.
local listed = {}
for _, item in ipairs(migrationDefs) do
	listed[item.file] = true
end
local isWin = package.config:sub(1, 1) == '\\'
local pipe = io.popen(isWin and 'dir /b /s migrations.lua' or 'find . -name migrations.lua -path "*/server/*" -o -name migrations.lua -path "*/adapters/*"')
for line in pipe:lines() do
	local rel = line:gsub('\\', '/'):gsub('^%./', ''):match('(coe_[%w_]+/[%w_]+/migrations%.lua)$')
	if rel and not rel:match('^coe_core/') and not rel:match('/test/') then
		assertEqual(listed[rel], true, 'migrations sem cenário de integração: ' .. rel)
	end
end
pipe:close()

-- Carrega todos os arquivos de migrações
for _, item in ipairs(migrationDefs) do
	dofile(item.file)
	if item.extra then
		dofile(item.extra)
	end
end

-- Executa duas vezes para validar idempotência total em banco do zero
for attempt = 1, 2 do
	-- 1. coe_core
	local coreSuccess, coreErr = Bridge.Call(Core.Database.RunMigrations)
	assertEqual(coreSuccess, true, 'coe_core migration attempt ' .. attempt .. ': ' .. tostring(coreErr))

	-- 2. Demais recursos
	for _, item in ipairs(migrationDefs) do
		local success, err
		if item.initialize then
			success, err = item.initialize()
		else
			success, err = runResourceMigrations(item.resource, item.get())
		end
		assertEqual(success, true, item.resource .. ' migration attempt ' .. attempt .. ': ' .. tostring(err))
	end
end

-- Valida que as tabelas de schema de todos os recursos foram criadas e registradas
local coreVersions = Bridge.Query('SELECT version, name FROM coe_schema_migrations')
assertEqual(coreVersions.ok, true, 'coe_schema_migrations query ok')
assertEqual(#coreVersions.result >= 7, true, 'coe_core has recorded all migrations')

local allTables = Bridge.Query('SELECT table_name FROM information_schema.tables WHERE table_schema = DATABASE()')
assertEqual(allTables.ok, true, 'information_schema query ok')
for _, item in ipairs(migrationDefs) do
	local versions = Bridge.Query('SELECT COUNT(*) AS n FROM ' .. item.resource .. '_schema_migrations')
	assertEqual(versions.ok and versions.result[1].n >= 1, true, item.resource .. ' registrou suas migrations')
end
assertEqual(#allTables.result >= #migrationDefs * 2, true, 'tabelas criadas no banco novo: ' .. tostring(#allTables.result))

Bridge.Done()

