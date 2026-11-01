FactionsMigrations = {
	{
		version = 1,
		name = 'factions',
		statements = {
			[[
				CREATE TABLE IF NOT EXISTS coe_faction_registry (
					faction_id VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					config JSON NOT NULL,
					updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
					PRIMARY KEY (faction_id)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]],
			[[
				CREATE TABLE IF NOT EXISTS coe_faction_members (
					faction_id VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					character_id BIGINT UNSIGNED NOT NULL,
					grade TINYINT UNSIGNED NOT NULL DEFAULT 0,
					created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
					PRIMARY KEY (faction_id, character_id),
					KEY idx_faction_members_character (character_id)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]]
		}
	}
}
