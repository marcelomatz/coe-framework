DoorsMigrations = {
	{
		version = 1,
		name = 'doors',
		statements = {
			[[
				CREATE TABLE IF NOT EXISTS coe_doors_registry (
					door_id VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					config JSON NOT NULL,
					updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
					PRIMARY KEY (door_id)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]]
		}
	}
}
