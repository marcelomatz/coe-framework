MdtMigrations = {
	{
		version = 1,
		name = 'warrants_bulletins_reports_access_log',
		statements = {
			[[
				CREATE TABLE IF NOT EXISTS coe_mdt_warrants (
					id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
					subject_id BIGINT UNSIGNED NOT NULL,
					issued_by BIGINT UNSIGNED NOT NULL,
					business_id VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					charge VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					note VARCHAR(200) NOT NULL DEFAULT '',
					status VARCHAR(8) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT 'active',
					resolved_by BIGINT UNSIGNED NULL,
					created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
					resolved_at DATETIME(3) NULL,
					PRIMARY KEY (id),
					KEY idx_mdt_warrants_subject (subject_id, status, id),
					KEY idx_mdt_warrants_status (status, id)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]],
			[[
				CREATE TABLE IF NOT EXISTS coe_mdt_bulletins (
					id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
					issued_by BIGINT UNSIGNED NOT NULL,
					business_id VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					title VARCHAR(60) NOT NULL,
					body VARCHAR(300) NOT NULL,
					plate VARCHAR(8) CHARACTER SET ascii COLLATE ascii_bin NULL,
					status VARCHAR(8) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT 'active',
					expires_at BIGINT UNSIGNED NOT NULL,
					created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
					PRIMARY KEY (id),
					KEY idx_mdt_bulletins_status (status, expires_at),
					KEY idx_mdt_bulletins_plate (plate, status)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]],
			[[
				CREATE TABLE IF NOT EXISTS coe_mdt_reports (
					id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
					author_id BIGINT UNSIGNED NOT NULL,
					business_id VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					subject_id BIGINT UNSIGNED NULL,
					title VARCHAR(80) NOT NULL,
					body VARCHAR(1000) NOT NULL,
					created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
					PRIMARY KEY (id),
					KEY idx_mdt_reports_subject (subject_id, id)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]],
			[[
				CREATE TABLE IF NOT EXISTS coe_mdt_access_log (
					id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
					officer_id BIGINT UNSIGNED NOT NULL,
					business_id VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					action VARCHAR(16) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					subject VARCHAR(24) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT '',
					created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
					PRIMARY KEY (id),
					KEY idx_mdt_access_officer (officer_id, id),
					KEY idx_mdt_access_subject (subject, id)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]]
		}
	}
}
