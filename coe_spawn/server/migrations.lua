SpawnMigrations = {
	{
		version = 1,
		name = 'last_positions',
		statements = {
			[[
				CREATE TABLE IF NOT EXISTS coe_spawn_positions (
					character_id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					x DOUBLE NOT NULL,
					y DOUBLE NOT NULL,
					z DOUBLE NOT NULL,
					heading DOUBLE NOT NULL DEFAULT 0,
					updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
					PRIMARY KEY (character_id)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]]
		}
	},
	{
		version = 2,
		name = 'starter_hotel',
		statements = {
			[[
				CREATE TABLE IF NOT EXISTS coe_starter_hotel (
					id INT UNSIGNED NOT NULL PRIMARY KEY DEFAULT 1,
					name VARCHAR(64) NOT NULL DEFAULT 'Motel Pink Cage',
					enabled TINYINT(1) NOT NULL DEFAULT 1,
					entrance_x DOUBLE NOT NULL DEFAULT 325.5,
					entrance_y DOUBLE NOT NULL DEFAULT -212.8,
					entrance_z DOUBLE NOT NULL DEFAULT 54.0,
					entrance_h DOUBLE NOT NULL DEFAULT 160.0,
					room_x DOUBLE NOT NULL DEFAULT 151.4,
					room_y DOUBLE NOT NULL DEFAULT -1007.8,
					room_z DOUBLE NOT NULL DEFAULT -99.0,
					room_h DOUBLE NOT NULL DEFAULT 0.0,
					exit_x DOUBLE NOT NULL DEFAULT 151.3,
					exit_y DOUBLE NOT NULL DEFAULT -1004.8,
					exit_z DOUBLE NOT NULL DEFAULT -99.0,
					exit_h DOUBLE NOT NULL DEFAULT 180.0,
					stash_x DOUBLE NOT NULL DEFAULT 151.8,
					stash_y DOUBLE NOT NULL DEFAULT -1001.2,
					stash_z DOUBLE NOT NULL DEFAULT -99.0,
					stash_slots INT UNSIGNED NOT NULL DEFAULT 30,
					stash_weight INT UNSIGNED NOT NULL DEFAULT 50000,
					updated_at BIGINT UNSIGNED NOT NULL DEFAULT 0
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]],
			[[
				INSERT IGNORE INTO coe_starter_hotel (id, name, enabled, entrance_x, entrance_y, entrance_z, entrance_h, room_x, room_y, room_z, room_h, exit_x, exit_y, exit_z, exit_h, stash_x, stash_y, stash_z, stash_slots, stash_weight, updated_at)
				VALUES (1, 'Motel Pink Cage', 1, 325.5, -212.8, 54.0, 160.0, 151.4, -1007.8, -99.0, 0.0, 151.3, -1004.8, -99.0, 180.0, 151.8, -1001.2, -99.0, 30, 50000, 0)
			]]
		}
	}
}
