InventoryMigrations = {
	{
		version = 1,
		name = 'inventory_records',
		statements = {
			[[
				CREATE TABLE IF NOT EXISTS coe_inventory_records (
					record_key VARCHAR(160) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					record_value LONGTEXT NOT NULL,
					updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3)
						ON UPDATE CURRENT_TIMESTAMP(3),
					PRIMARY KEY (record_key)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]]
		}
	}
}
