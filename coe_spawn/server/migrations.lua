SpawnMigrations = {
	{
		version = 1,
		name = 'last_positions',
		statements = {
			[[
				CREATE TABLE IF NOT EXISTS coe_spawn_positions (
					character_id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					x DOUBLE NOT NULL,
					y DOUBLE NOT NULL,
					z DOUBLE NOT NULL,
					heading DOUBLE NOT NULL DEFAULT 0,
					updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
					PRIMARY KEY (character_id)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]]
		}
	}
}
