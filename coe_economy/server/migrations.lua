EconomyMigrations = {
	{
		version = 1,
		name = 'accounts',
		statements = {
			[[
				CREATE TABLE IF NOT EXISTS coe_economy_accounts (
					character_id BIGINT UNSIGNED NOT NULL,
					balance BIGINT UNSIGNED NOT NULL DEFAULT 0,
					created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
					updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
					PRIMARY KEY (character_id)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]],
			[[
				CREATE TABLE IF NOT EXISTS coe_economy_ledger (
					id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
					character_id BIGINT UNSIGNED NOT NULL,
					delta BIGINT NOT NULL,
					reason VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					reference VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT '',
					source_resource VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
					PRIMARY KEY (id),
					KEY idx_ledger_character (character_id, id)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]]
		}
	},
	{
		version = 2,
		name = 'societies',
		statements = {
			[[
				CREATE TABLE IF NOT EXISTS coe_economy_societies (
					business_id VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					balance BIGINT UNSIGNED NOT NULL DEFAULT 0,
					created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
					updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
					PRIMARY KEY (business_id)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]],
			[[
				CREATE TABLE IF NOT EXISTS coe_economy_society_ledger (
					id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
					business_id VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					character_id BIGINT UNSIGNED NULL,
					delta BIGINT NOT NULL,
					reason VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					reference VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT '',
					source_resource VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
					PRIMARY KEY (id),
					KEY idx_society_ledger_business (business_id, id)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]]
		}
	}
}
