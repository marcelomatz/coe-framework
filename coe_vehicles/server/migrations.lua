VehiclesMigrations = {
	{
		version = 1,
		name = 'vehicles',
		statements = {
			[[
				CREATE TABLE IF NOT EXISTS coe_vehicles (
					vehicle_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
					owner_character_id BIGINT UNSIGNED NULL,
					model VARCHAR(48) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					plate VARCHAR(8) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					mileage_m BIGINT UNSIGNED NOT NULL DEFAULT 0,
					state VARCHAR(12) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT 'stored',
					props JSON NULL,
					created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
					updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
					PRIMARY KEY (vehicle_id),
					UNIQUE KEY uq_vehicles_plate (plate),
					KEY idx_vehicles_owner (owner_character_id)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]]
		}
	},
	{
		version = 2,
		name = 'vehicle_keys',
		statements = {
			[[
				CREATE TABLE IF NOT EXISTS coe_vehicle_keys (
					vehicle_id BIGINT UNSIGNED NOT NULL,
					character_id BIGINT UNSIGNED NOT NULL,
					granted_by BIGINT UNSIGNED NULL,
					created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
					PRIMARY KEY (vehicle_id, character_id),
					KEY idx_vehicle_keys_character (character_id),
					CONSTRAINT fk_vehicle_keys_vehicle FOREIGN KEY (vehicle_id) REFERENCES coe_vehicles (vehicle_id) ON DELETE CASCADE
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]]
		}
	}
}
