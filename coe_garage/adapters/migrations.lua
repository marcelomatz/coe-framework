GarageMigrations = {
	{
		version = 1,
		name = 'initial_schema_and_seed',
		statements = {
			[[
				CREATE TABLE IF NOT EXISTS coe_garage_registry (
					garage_id VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					config JSON NOT NULL,
					updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
					PRIMARY KEY (garage_id)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]],
			[[
				CREATE TABLE IF NOT EXISTS coe_garage_slots (
					vehicle_id BIGINT UNSIGNED NOT NULL,
					garage_id VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					character_id BIGINT UNSIGNED NOT NULL,
					class VARCHAR(8) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT 'car',
					created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
					PRIMARY KEY (vehicle_id),
					KEY idx_garage_slots_character (character_id)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]],
			[[
				INSERT IGNORE INTO coe_garage_registry (garage_id, config) VALUES
				('garagem_pinkcage', '{"kind":"public","label":"Garagem Pink Cage","enabled":true,"spots":[{"id":"vaga_1","label":"Vaga 1","x":315.5,"y":-234.2,"z":54.0,"radius":3.5,"heading":75.0},{"id":"vaga_2","label":"Vaga 2","x":317.8,"y":-238.5,"z":54.0,"radius":3.5,"heading":75.0}],"blip":{"enabled":true,"sprite":357,"color":3,"scale":0.8}}'),
				('garagem_central', '{"kind":"public","label":"Garagem Legion Square","enabled":true,"spots":[{"id":"vaga_1","label":"Vaga 1","x":215.2,"y":-805.1,"z":30.8,"radius":3.5,"heading":250.0},{"id":"vaga_2","label":"Vaga 2","x":218.4,"y":-809.5,"z":30.8,"radius":3.5,"heading":250.0}],"blip":{"enabled":true,"sprite":357,"color":3,"scale":0.8}}'),
				('garagem_aeroporto', '{"kind":"public","label":"Garagem Aeroporto LSIA","enabled":true,"spots":[{"id":"vaga_1","label":"Vaga 1","x":-1036.5,"y":-2732.1,"z":13.8,"radius":3.5,"heading":330.0}],"blip":{"enabled":true,"sprite":357,"color":3,"scale":0.8}}'),
				('garagem_sandy', '{"kind":"public","label":"Garagem Sandy Shores","enabled":true,"spots":[{"id":"vaga_1","label":"Vaga 1","x":1982.5,"y":3775.2,"z":32.2,"radius":3.5,"heading":120.0}],"blip":{"enabled":true,"sprite":357,"color":3,"scale":0.8}}')
			]]
		}
	}
}
