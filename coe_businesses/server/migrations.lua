BusinessesMigrations = {
	{
		version = 1,
		name = 'businesses',
		statements = {
			[[
				CREATE TABLE IF NOT EXISTS coe_businesses (
					id VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					category VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					label VARCHAR(64) NOT NULL,
					enabled TINYINT(1) NOT NULL DEFAULT 1,
					data MEDIUMTEXT NOT NULL,
					updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3)
						ON UPDATE CURRENT_TIMESTAMP(3),
					PRIMARY KEY (id),
					KEY idx_coe_businesses_category (category)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]]
		}
	}
}
