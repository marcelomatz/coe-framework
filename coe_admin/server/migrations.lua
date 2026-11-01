AdminMigrations = {
	{
		version = 1,
		name = 'admin_staff',
		statements = {
			[[
				CREATE TABLE IF NOT EXISTS coe_admin_staff (
					identifier_value VARCHAR(128) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					role_name VARCHAR(48) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3)
						ON UPDATE CURRENT_TIMESTAMP(3),
					PRIMARY KEY (identifier_value)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]]
		}
	}
}
