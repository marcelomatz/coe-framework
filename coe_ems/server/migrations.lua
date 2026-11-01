EmsMigrations = {
	{
		version = 1,
		name = 'records',
		statements = {
			[[
				CREATE TABLE IF NOT EXISTS coe_ems_records (
					id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
					patient_id BIGINT UNSIGNED NOT NULL,
					medic_id BIGINT UNSIGNED NULL,
					business_id VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NULL,
					kind VARCHAR(16) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					detail VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT '',
					created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
					PRIMARY KEY (id),
					KEY idx_ems_records_patient (patient_id, id)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]]
		}
	}
}
