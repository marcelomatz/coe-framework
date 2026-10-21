AuditMigrations = {
	{
		version = 1,
		name = 'audit_log',
		statements = {
			[[
				CREATE TABLE IF NOT EXISTS coe_audit_log (
					id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
					occurred_at DATETIME(3) NOT NULL,
					severity VARCHAR(8) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					category VARCHAR(48) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					event VARCHAR(80) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					resource VARCHAR(48) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					actor_license VARCHAR(128) CHARACTER SET ascii COLLATE ascii_bin NULL,
					target_license VARCHAR(128) CHARACTER SET ascii COLLATE ascii_bin NULL,
					context JSON NOT NULL,
					PRIMARY KEY (id),
					KEY idx_audit_occurred_at (occurred_at),
					KEY idx_audit_event (event, occurred_at),
					KEY idx_audit_actor (actor_license, occurred_at),
					KEY idx_audit_target (target_license, occurred_at)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]]
		}
	}
}
