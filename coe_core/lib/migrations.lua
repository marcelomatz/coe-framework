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

local function normalizeMigrationsList(migrations)
	if type(migrations) ~= 'table' then
		return migrations
	end
	local normalized = {}
	for i, m in ipairs(migrations) do
		if type(m) == 'table' then
			local stmts = m.statements
			if type(stmts) ~= 'table' then
				if type(m.up) == 'table' then
					stmts = m.up
				elseif type(m.sql) == 'string' and #m.sql > 0 then
					stmts = { m.sql }
				end
			end
			normalized[i] = {
				version = m.version,
				name = m.name or ('migration_' .. tostring(m.version or i)),
				statements = stmts
			}
		else
			normalized[i] = m
		end
	end
	return normalized
end

local function defaultDbCall(method, sql, parameters)
	if type(GetResourceState) == 'function' and GetResourceState('coe_database') ~= 'started' then
		return nil, 'database_unavailable'
	end
	local db = exports and exports.coe_database
	if not db then
		return nil, 'database_unavailable'
	end
	local canAsync = type(promise) == 'table' and type(promise.new) == 'function'
		and type(Citizen) == 'table' and type(Citizen.Await) == 'function'
	local canWait = canAsync and type(Wait) == 'function' and type(GetGameTimer) == 'function' and GetGameTimer() > 0
	for attempt = 1, (canWait and 30 or 1) do
		if canAsync then
			local p = promise.new()
			local settled = false
			local ok, syncRes, syncErr = pcall(function()
				return db[method](db, sql, parameters or {}, function(success, result, errorCode)
					if not settled then
						settled = true
						p:resolve({ ok = success == true, result = result, err = errorCode })
					end
				end)
			end)
			if not ok then
				return nil, 'database_unavailable'
			end
			if settled or syncRes == nil then
				local awaited = Citizen.Await(p)
				if type(awaited) == 'table' and awaited.ok then
					return awaited.result ~= nil and awaited.result or (method == 'Execute' and true or {}), nil
				end
				local err = (type(awaited) == 'table' and awaited.err) or 'database_error'
				if err == 'database_not_ready' and canWait and attempt < 30 then
					Wait(500)
				else
					return nil, err
				end
			else
				if syncRes == false then
					return nil, syncErr or 'database_error'
				end
				return syncRes, nil
			end
		else
			local cbCalled = false
			local cbOk, cbRes, cbErr
			local ok, syncRes, syncErr = pcall(function()
				return db[method](db, sql, parameters or {}, function(success, result, errorCode)
					cbCalled = true
					cbOk = success == true
					cbRes = result
					cbErr = errorCode
				end)
			end)
			if not ok then
				return nil, 'database_unavailable'
			end
			if cbCalled then
				if not cbOk then
					return nil, cbErr or 'database_error'
				end
				return cbRes ~= nil and cbRes or (method == 'Execute' and true or {}), nil
			end
			if syncRes == false then
				return nil, syncErr or 'database_error'
			end
			return syncRes ~= nil and syncRes or (method == 'Execute' and true or {}), nil
		end
	end
	return nil, 'database_not_ready'
end

function CoeMigrations.Run(options, maybeMigrations)
	if type(options) == 'string' and type(maybeMigrations) == 'table' then
		local tableName = options:gsub('[^%w_]', '_'):lower() .. '_schema_migrations'
		options = {
			tableName = tableName,
			migrations = normalizeMigrationsList(maybeMigrations),
			execute = function(sql, parameters)
				local res, err = defaultDbCall('Execute', sql, parameters)
				if not res then return false, err end
				return true, nil
			end,
			query = function(sql, parameters)
				local res, err = defaultDbCall('Query', sql, parameters)
				if type(res) ~= 'table' then return nil, err or 'database_error' end
				return res, nil
			end
		}
	elseif type(options) == 'table' and type(options.migrations) == 'table' then
		options = {
			tableName = options.tableName,
			migrations = normalizeMigrationsList(options.migrations),
			execute = options.execute,
			query = options.query
		}
	end
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
