VehicleCatalogMigrations = {
	{
		version = 1,
		name = 'vehicle_overrides',
		statements = {
			[[
				CREATE TABLE IF NOT EXISTS coe_vehicle_overrides (
					model VARCHAR(48) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					price BIGINT UNSIGNED NULL,
					stock INT UNSIGNED NULL,
					category VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NULL,
					hidden TINYINT(1) NULL,
					updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
					PRIMARY KEY (model)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]]
		}
	}
}
