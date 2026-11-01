TelecomMigrations = {
	{
		version = 1,
		name = 'lines_invoices_usage',
		statements = {
			[[
				CREATE TABLE IF NOT EXISTS coe_telecom_lines (
					character_id BIGINT UNSIGNED NOT NULL,
					carrier VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					plan VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					balance INT UNSIGNED NOT NULL DEFAULT 0,
					status VARCHAR(16) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT 'active',
					cycle_start BIGINT UNSIGNED NOT NULL,
					voice_used INT UNSIGNED NOT NULL DEFAULT 0,
					video_used INT UNSIGNED NOT NULL DEFAULT 0,
					plan_changed_at BIGINT UNSIGNED NOT NULL DEFAULT 0,
					created_at BIGINT UNSIGNED NOT NULL,
					PRIMARY KEY (character_id),
					KEY idx_lines_plan (plan, cycle_start)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]],
			[[
				CREATE TABLE IF NOT EXISTS coe_telecom_invoices (
					id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
					character_id BIGINT UNSIGNED NOT NULL,
					carrier VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					plan VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					period_start BIGINT UNSIGNED NOT NULL,
					period_end BIGINT UNSIGNED NOT NULL,
					amount INT UNSIGNED NOT NULL,
					details VARCHAR(255) NOT NULL,
					status VARCHAR(16) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT 'open',
					due_at BIGINT UNSIGNED NOT NULL,
					paid_at BIGINT UNSIGNED NULL,
					PRIMARY KEY (id),
					KEY idx_invoices_character (character_id, status),
					KEY idx_invoices_due (status, due_at)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]],
			[[
				CREATE TABLE IF NOT EXISTS coe_telecom_usage (
					id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
					character_id BIGINT UNSIGNED NOT NULL,
					kind VARCHAR(16) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					peer VARCHAR(16) CHARACTER SET ascii COLLATE ascii_bin NULL,
					units INT UNSIGNED NOT NULL DEFAULT 0,
					cost INT UNSIGNED NOT NULL DEFAULT 0,
					created_at BIGINT UNSIGNED NOT NULL,
					PRIMARY KEY (id),
					KEY idx_usage_character (character_id, id),
					KEY idx_usage_created (created_at)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]]
		}
	},
	{
		-- A linha passa a ser do número (chip do coe_phone); character_id vira o titular e pode faltar.
		-- Linhas antigas ficam com number NULL até o titular usar o chip (o servidor associa na hora).
		version = 2,
		name = 'lines_by_number',
		statements = {
			[[
				ALTER TABLE coe_telecom_lines
				ADD COLUMN IF NOT EXISTS number VARCHAR(16) CHARACTER SET ascii COLLATE ascii_bin NULL AFTER character_id
			]],
			[[
				ALTER TABLE coe_telecom_lines
				DROP PRIMARY KEY,
				ADD COLUMN id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY FIRST,
				MODIFY character_id BIGINT UNSIGNED NULL,
				ADD UNIQUE KEY uq_lines_number (number),
				ADD KEY idx_lines_character (character_id)
			]],
			[[
				ALTER TABLE coe_telecom_invoices
				ADD COLUMN IF NOT EXISTS number VARCHAR(16) CHARACTER SET ascii COLLATE ascii_bin NULL AFTER character_id,
				MODIFY character_id BIGINT UNSIGNED NULL,
				ADD KEY IF NOT EXISTS idx_invoices_number (number, status)
			]],
			[[
				ALTER TABLE coe_telecom_usage
				ADD COLUMN IF NOT EXISTS number VARCHAR(16) CHARACTER SET ascii COLLATE ascii_bin NULL AFTER character_id,
				MODIFY character_id BIGINT UNSIGNED NULL,
				ADD KEY IF NOT EXISTS idx_usage_number (number, id)
			]]
		}
	}
}
