HandlingMigrations = {
	{
		version = 1,
		name = 'vehicle_tyres',
		statements = {
			[[
				CREATE TABLE IF NOT EXISTS coe_vehicle_tyres (
					vehicle_id BIGINT UNSIGNED NOT NULL,
					compound VARCHAR(24) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					fitted_at_m BIGINT UNSIGNED NOT NULL DEFAULT 0,
					updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
					PRIMARY KEY (vehicle_id)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]]
		}
	}
}
