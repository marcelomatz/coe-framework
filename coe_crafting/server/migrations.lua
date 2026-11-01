CraftingMigrations = {
	{
		version = 1,
		name = 'catalog',
		statements = {
			[[
				CREATE TABLE IF NOT EXISTS coe_crafting_catalog (
					record_kind VARCHAR(16) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					record_id VARCHAR(48) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					config JSON NOT NULL,
					updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
					PRIMARY KEY (record_kind, record_id)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]]
		}
	}
}
