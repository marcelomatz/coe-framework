NeedsMigrations = {
	{
		version = 1,
		name = 'needs_state',
		statements = {
			[[
				CREATE TABLE IF NOT EXISTS coe_needs_state (
					character_id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					hunger DOUBLE NOT NULL,
					thirst DOUBLE NOT NULL,
					stress DOUBLE NOT NULL,
					updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3)
						ON UPDATE CURRENT_TIMESTAMP(3),
					PRIMARY KEY (character_id)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]]
		}
	}
}
