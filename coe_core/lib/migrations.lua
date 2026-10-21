-- Executor de migrações versionadas, genérico e sem dependência de banco.
-- Cada resource fornece `execute` e `query` (síncronos, retornam resultado, erro)
-- e a lista de migrações; o registro fica em uma tabela própria do resource.
CoeMigrations = {}

local MAX_STATEMENTS = 64

local function validIdentifier(value)
	return type(value) == 'string'
		and #value > 0
		and #value <= 64
		and value:match('^[%l_][%l%d_]*$') ~= nil
end

local function validateMigrations(migrations)
	if type(migrations) ~= 'table' or #migrations == 0 then
		return false, 'invalid_migrations'
	end

	local previous = 0
	for _, migration in ipairs(migrations) do
		if type(migration) ~= 'table'
			or math.type(migration.version) ~= 'integer'
			or migration.version <= previous
			or type(migration.name) ~= 'string'
			or #migration.name == 0
			or #migration.name > 128
			or type(migration.statements) ~= 'table'
			or #migration.statements == 0
			or #migration.statements > MAX_STATEMENTS then
			return false, 'invalid_migrations'
		end
		for _, statement in ipairs(migration.statements) do
			if type(statement) ~= 'string' or #statement == 0 then
				return false, 'invalid_migrations'
			end
		end
		previous = migration.version
	end

	return true
end

function CoeMigrations.Run(options)
	if type(options) ~= 'table'
		or not validIdentifier(options.tableName)
		or type(options.execute) ~= 'function'
		or type(options.query) ~= 'function' then
		return false, 'invalid_options'
	end

	local valid, validationError = validateMigrations(options.migrations)
	if not valid then
		return false, validationError
	end

	local tableName = options.tableName
	local created, createError = options.execute(([[
		CREATE TABLE IF NOT EXISTS %s (
			version INT UNSIGNED NOT NULL,
			name VARCHAR(128) NOT NULL,
			applied_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
			PRIMARY KEY (version)
		) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
	]]):format(tableName), {})
	if not created then
		return false, createError or 'database_error'
	end

	local rows, queryError = options.query(('SELECT version FROM %s'):format(tableName), {})
	if not rows then
		return false, queryError or 'database_error'
	end

	local applied = {}
	for _, row in ipairs(rows) do
		local version = tonumber(row.version)
		if version then
			applied[version] = true
		end
	end

	local appliedNow = 0
	for _, migration in ipairs(options.migrations) do
		if not applied[migration.version] then
			for _, statement in ipairs(migration.statements) do
				local executed, executeError = options.execute(statement, {})
				if not executed then
					return false, executeError or 'database_error', appliedNow
				end
			end

			local recorded, recordError = options.execute(
				('INSERT INTO %s (version, name) VALUES (?, ?)'):format(tableName),
				{ migration.version, migration.name }
			)
			if not recorded then
				return false, recordError or 'database_error', appliedNow
			end
			appliedNow = appliedNow + 1
		end
	end

	return true, nil, appliedNow
end
