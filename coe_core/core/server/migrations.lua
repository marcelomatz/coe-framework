local STATE_ID_ATTEMPTS = 5

-- Passo em Lua da migração 2: atribui stateId aos personagens que ainda não têm.
-- Repete com outro valor quando o banco recusa por duplicidade; idempotente porque só
-- atualiza linhas com state_id nulo.
local function backfillCharacterStateIds(done)
	local dispatched, dispatchError = Core.Database.Query(
		'SELECT character_id FROM coe_characters WHERE state_id IS NULL ORDER BY character_id',
		{},
		function(success, rows, errorMessage)
			if not success then
				done(false, errorMessage)
				return
			end
			if type(rows) ~= 'table' then
				done(false, 'invalid_database_result')
				return
			end

			local function assign(index, attempt)
				local row = rows[index]
				if not row then
					done(true)
					return
				end
				local sent, sendError = Core.Database.Execute(
					'UPDATE coe_characters SET state_id = ? WHERE character_id = ? AND state_id IS NULL',
					{ Core.Identity.GenerateStateId(), row.character_id },
					function(updated, _, updateError)
						if updated then
							assign(index + 1, 1)
						elseif updateError == 'ER_DUP_ENTRY' and attempt < STATE_ID_ATTEMPTS then
							assign(index, attempt + 1)
						else
							done(false, updateError)
						end
					end
				)
				if not sent then
					done(false, sendError)
				end
			end
			assign(1, 1)
		end
	)
	if not dispatched then
		done(false, dispatchError)
	end
end

-- Cada item de statements é uma string SQL ou uma função(done) que chama done(success, errorMessage).
local migrations = {
	{
		version = 1,
		name = 'player_character_identity',
		statements = {
			[[
				CREATE TABLE IF NOT EXISTS coe_players (
					player_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
					created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
					updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3)
						ON UPDATE CURRENT_TIMESTAMP(3),
					PRIMARY KEY (player_id)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]],
			[[
				CREATE TABLE IF NOT EXISTS coe_player_identifiers (
					identifier_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
					player_id BIGINT UNSIGNED NOT NULL,
					identifier_type VARCHAR(24) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					identifier_value VARCHAR(128) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
					PRIMARY KEY (identifier_id),
					UNIQUE KEY uq_coe_player_identifier (identifier_type, identifier_value),
					KEY ix_coe_player_identifiers_player (player_id),
					CONSTRAINT fk_coe_player_identifiers_player
						FOREIGN KEY (player_id) REFERENCES coe_players (player_id)
						ON DELETE RESTRICT ON UPDATE RESTRICT
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]],
			[[
				CREATE TABLE IF NOT EXISTS coe_characters (
					character_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
					player_id BIGINT UNSIGNED NOT NULL,
					first_name VARCHAR(48) NOT NULL,
					last_name VARCHAR(48) NOT NULL,
					created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
					updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3)
						ON UPDATE CURRENT_TIMESTAMP(3),
					archived_at DATETIME(3) NULL,
					PRIMARY KEY (character_id),
					KEY ix_coe_characters_owner_active (player_id, archived_at, character_id),
					CONSTRAINT fk_coe_characters_player
						FOREIGN KEY (player_id) REFERENCES coe_players (player_id)
						ON DELETE RESTRICT ON UPDATE RESTRICT
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]]
		}
	},
	{
		version = 2,
		name = 'character_state_id',
		statements = {
			'ALTER TABLE coe_characters ADD COLUMN IF NOT EXISTS state_id CHAR(8) CHARACTER SET ascii COLLATE ascii_bin NULL',
			'CREATE UNIQUE INDEX IF NOT EXISTS uq_coe_characters_state_id ON coe_characters (state_id)',
			backfillCharacterStateIds
		}
	},
	{
		version = 3,
		name = 'character_state_id_required',
		statements = {
			'ALTER TABLE coe_characters MODIFY state_id CHAR(8) CHARACTER SET ascii COLLATE ascii_bin NOT NULL'
		}
	},
	{
		version = 4,
		name = 'player_settings',
		statements = {
			[[
				CREATE TABLE IF NOT EXISTS coe_player_settings (
					player_id BIGINT UNSIGNED NOT NULL,
					character_slots TINYINT UNSIGNED NULL,
					updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3)
						ON UPDATE CURRENT_TIMESTAMP(3),
					PRIMARY KEY (player_id),
					CONSTRAINT fk_coe_player_settings_player
						FOREIGN KEY (player_id) REFERENCES coe_players (player_id)
						ON DELETE RESTRICT ON UPDATE RESTRICT
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]]
		}
	},
	{
		version = 5,
		name = 'character_profile',
		statements = {
			[[
				ALTER TABLE coe_characters
					ADD COLUMN IF NOT EXISTS birth_date DATE NULL,
					ADD COLUMN IF NOT EXISTS gender VARCHAR(16) NULL,
					ADD COLUMN IF NOT EXISTS appearance JSON NULL,
					ADD COLUMN IF NOT EXISTS appearance_version SMALLINT UNSIGNED NULL
			]]
		}
	},
	{
		version = 6,
		name = 'groups',
		statements = {
			[[
				CREATE TABLE IF NOT EXISTS coe_groups (
					name VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					type VARCHAR(16) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					label VARCHAR(64) NOT NULL,
					updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3)
						ON UPDATE CURRENT_TIMESTAMP(3),
					PRIMARY KEY (name),
					UNIQUE KEY uq_coe_groups_name_type (name, type)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]],
			-- active_type só tem valor quando o vínculo está ativo; o UNIQUE com character_id
			-- garante um grupo ativo por tipo (NULLs não colidem).
			[[
				CREATE TABLE IF NOT EXISTS coe_character_groups (
					character_id BIGINT UNSIGNED NOT NULL,
					group_name VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					group_type VARCHAR(16) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					grade TINYINT UNSIGNED NOT NULL,
					active TINYINT(1) NOT NULL DEFAULT 0,
					active_type VARCHAR(16) CHARACTER SET ascii COLLATE ascii_bin
						GENERATED ALWAYS AS (IF(active = 1, group_type, NULL)) STORED,
					updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3)
						ON UPDATE CURRENT_TIMESTAMP(3),
					PRIMARY KEY (character_id, group_name),
					UNIQUE KEY uq_coe_character_groups_active (character_id, active_type),
					KEY ix_coe_character_groups_group (group_name),
					CONSTRAINT fk_coe_character_groups_character
						FOREIGN KEY (character_id) REFERENCES coe_characters (character_id)
						ON DELETE RESTRICT ON UPDATE RESTRICT,
					CONSTRAINT fk_coe_character_groups_group
						FOREIGN KEY (group_name, group_type) REFERENCES coe_groups (name, type)
						ON DELETE RESTRICT ON UPDATE RESTRICT
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]]
		}
	},
	-- Busca por nome (prefixo) nos painéis: sem estes índices cada consulta varre a tabela inteira.
	{
		version = 7,
		name = 'character_name_search',
		statements = {
			'CREATE INDEX IF NOT EXISTS ix_coe_characters_first_name ON coe_characters (first_name, archived_at)',
			'CREATE INDEX IF NOT EXISTS ix_coe_characters_last_name ON coe_characters (last_name, archived_at)'
		}
	}
}

local function complete(callback, success, errorMessage)
	callback(success, errorMessage)
end

local function applyStatements(migration, index, callback)
	local statement = migration.statements[index]
	if not statement then
		local dispatched, dispatchError = Core.Database.Execute(
			'INSERT INTO coe_schema_migrations (version, name) VALUES (?, ?)',
			{ migration.version, migration.name },
			function(success, _, errorMessage)
				complete(callback, success, errorMessage)
			end
		)
		if not dispatched then
			complete(callback, false, dispatchError)
		end
		return
	end

	if type(statement) == 'function' then
		statement(function(success, errorMessage)
			if not success then
				complete(callback, false, errorMessage or 'migration_step_failed')
				return
			end
			applyStatements(migration, index + 1, callback)
		end)
		return
	end

	local dispatched, dispatchError = Core.Database.Execute(statement, {}, function(success, _, errorMessage)
		if not success then
			complete(callback, false, errorMessage)
			return
		end
		applyStatements(migration, index + 1, callback)
	end)
	if not dispatched then
		complete(callback, false, dispatchError)
	end
end

local function applyPendingMigrations(appliedVersions, index, callback)
	local migration = migrations[index]
	if not migration then
		complete(callback, true)
		return
	end
	if appliedVersions[migration.version] then
		applyPendingMigrations(appliedVersions, index + 1, callback)
		return
	end

	applyStatements(migration, 1, function(success, errorMessage)
		if not success then
			complete(callback, false, errorMessage)
			return
		end
		applyPendingMigrations(appliedVersions, index + 1, callback)
	end)
end

function Core.Database.RunMigrations(callback)
	if type(callback) ~= 'function' then
		return false, 'invalid_callback'
	end

	local dispatched, dispatchError = Core.Database.Execute([[
		CREATE TABLE IF NOT EXISTS coe_schema_migrations (
			version INT UNSIGNED NOT NULL,
			name VARCHAR(128) NOT NULL,
			applied_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
			PRIMARY KEY (version)
		) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
	]], {}, function(success, _, errorMessage)
		if not success then
			complete(callback, false, errorMessage)
			return
		end

		local queryDispatched, queryError = Core.Database.Query(
			'SELECT version FROM coe_schema_migrations',
			{},
			function(querySuccess, rows, queryMessage)
				if not querySuccess then
					complete(callback, false, queryMessage)
					return
				end

				local appliedVersions = {}
				for _, row in ipairs(rows) do
					local version = tonumber(row.version)
					if version then
						appliedVersions[version] = true
					end
				end
				applyPendingMigrations(appliedVersions, 1, callback)
			end
		)
		if not queryDispatched then
			complete(callback, false, queryError)
		end
	end)
	if not dispatched then
		return false, dispatchError
	end

	return true
end
