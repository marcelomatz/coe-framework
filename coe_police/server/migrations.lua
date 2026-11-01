PoliceMigrations = {
	{
		version = 1,
		name = 'records_and_sentences',
		statements = {
			[[
				CREATE TABLE IF NOT EXISTS coe_police_records (
					id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
					subject_id BIGINT UNSIGNED NOT NULL,
					officer_id BIGINT UNSIGNED NOT NULL,
					business_id VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					kind VARCHAR(16) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					detail VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT '',
					amount BIGINT UNSIGNED NULL,
					minutes INT UNSIGNED NULL,
					created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
					PRIMARY KEY (id),
					KEY idx_police_records_subject (subject_id, id)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]],
			[[
				CREATE TABLE IF NOT EXISTS coe_police_sentences (
					character_id BIGINT UNSIGNED NOT NULL,
					release_at BIGINT UNSIGNED NOT NULL,
					PRIMARY KEY (character_id)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]]
		}
	}
}
