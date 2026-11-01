MechanicMigrations = {
	{
		version = 1,
		name = 'vehicle_parts',
		statements = {
			[[
				CREATE TABLE IF NOT EXISTS coe_vehicle_parts (
					vehicle_id BIGINT UNSIGNED NOT NULL,
					part VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					installed_at_m BIGINT UNSIGNED NOT NULL DEFAULT 0,
					updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
					PRIMARY KEY (vehicle_id, part)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]]
		}
	},
	{
		version = 2,
		name = 'vehicle_appearance',
		statements = {
			[[
				CREATE TABLE IF NOT EXISTS coe_vehicle_appearance (
					vehicle_id BIGINT UNSIGNED NOT NULL,
					data LONGTEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL,
					updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
					PRIMARY KEY (vehicle_id)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]]
		}
	},
	{
		version = 3,
		name = 'shop_owners',
		statements = {
			[[
				CREATE TABLE IF NOT EXISTS coe_mechanic_businesses (
					shop_id VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					owner_character_id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
					PRIMARY KEY (shop_id)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]]
		}
	},
	{
		version = 4,
		name = 'parts_extra_wear',
		statements = {
			-- Desgaste extra (metros) somado por outros resources (ex.: gasolina comum no coe_fuel). Zera na troca.
			[[
				ALTER TABLE coe_vehicle_parts ADD COLUMN IF NOT EXISTS extra_wear_m BIGINT UNSIGNED NOT NULL DEFAULT 0
			]]
		}
	}
}
