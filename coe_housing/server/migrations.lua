HousingMigrations = {
	{
		version = 1,
		name = 'housing',
		statements = {
			[[
				CREATE TABLE IF NOT EXISTS coe_housing_registry (
					property_id VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					config JSON NOT NULL,
					updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
					PRIMARY KEY (property_id)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]],
			[[
				CREATE TABLE IF NOT EXISTS coe_housing_tenancies (
					id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
					property_id VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					unit INT UNSIGNED NOT NULL,
					character_id BIGINT UNSIGNED NOT NULL,
					cycle_days SMALLINT UNSIGNED NOT NULL DEFAULT 0,
					daily_rate BIGINT UNSIGNED NOT NULL DEFAULT 0,
					paid_until BIGINT UNSIGNED NOT NULL DEFAULT 0,
					created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
					PRIMARY KEY (id),
					UNIQUE KEY uq_tenancy_unit (property_id, unit),
					UNIQUE KEY uq_tenancy_character (property_id, character_id),
					KEY idx_tenancy_character (character_id)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]],
			[[
				CREATE TABLE IF NOT EXISTS coe_housing_grants (
					character_id BIGINT UNSIGNED NOT NULL,
					created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
					PRIMARY KEY (character_id)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]]
		}
	},
	{
		version = 2,
		name = 'presence',
		statements = {
			[[
				CREATE TABLE IF NOT EXISTS coe_housing_presence (
					character_id BIGINT UNSIGNED NOT NULL,
					tenancy_id BIGINT UNSIGNED NOT NULL,
					property_id VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
					PRIMARY KEY (character_id)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]]
		}
	},
	{
		version = 3,
		name = 'commercial',
		statements = {
			[[
				CREATE TABLE IF NOT EXISTS coe_housing_leases (
					id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
					property_id VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					unit INT UNSIGNED NOT NULL,
					business_id VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					cycle_days SMALLINT UNSIGNED NOT NULL DEFAULT 0,
					daily_rate BIGINT UNSIGNED NOT NULL DEFAULT 0,
					paid_until BIGINT UNSIGNED NOT NULL DEFAULT 0,
					created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
					PRIMARY KEY (id),
					UNIQUE KEY uq_lease_unit (property_id, unit),
					UNIQUE KEY uq_lease_business (property_id, business_id),
					KEY idx_lease_business (business_id)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]],
			-- Na presença, lease = 1 indica que tenancy_id é o id de um contrato comercial.
			[[
				ALTER TABLE coe_housing_presence ADD COLUMN lease TINYINT(1) NOT NULL DEFAULT 0
			]]
		}
	},
	{
		version = 4,
		name = 'interior_thumbs',
		statements = {
			-- Miniaturas do catálogo de interiores, capturadas no jogo pelo admin.
			[[
				CREATE TABLE IF NOT EXISTS coe_housing_interior_thumbs (
					interior_id VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					image MEDIUMTEXT CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
					PRIMARY KEY (interior_id)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]]
		}
	}
}
