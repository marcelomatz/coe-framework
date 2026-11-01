FuelMigrations = {
	{
		version = 1,
		name = 'vehicles_tanks_sales',
		statements = {
			-- Tanque de cada veículo registrado (coe_vehicles): motor, capacidade e litros de cada combustível.
			[[
				CREATE TABLE IF NOT EXISTS coe_fuel_vehicles (
					vehicle_id BIGINT UNSIGNED NOT NULL,
					engine VARCHAR(8) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					capacity SMALLINT UNSIGNED NOT NULL,
					regular DECIMAL(9,3) NOT NULL DEFAULT 0,
					premium DECIMAL(9,3) NOT NULL DEFAULT 0,
					ethanol DECIMAL(9,3) NOT NULL DEFAULT 0,
					diesel DECIMAL(9,3) NOT NULL DEFAULT 0,
					updated_at BIGINT UNSIGNED NOT NULL,
					PRIMARY KEY (vehicle_id)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]],
			-- Tanques dos postos de jogador (litros por combustível).
			[[
				CREATE TABLE IF NOT EXISTS coe_fuel_tanks (
					business_id VARCHAR(24) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					fuel VARCHAR(12) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					liters DECIMAL(10,2) NOT NULL DEFAULT 0,
					updated_at BIGINT UNSIGNED NOT NULL,
					PRIMARY KEY (business_id, fuel)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]],
			-- Vendas das bombas (relatório e histórico de funcionamento do posto, base dos upgrades da etapa B).
			[[
				CREATE TABLE IF NOT EXISTS coe_fuel_sales (
					id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
					business_id VARCHAR(24) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					station_id VARCHAR(24) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					character_id BIGINT UNSIGNED NOT NULL,
					fuel VARCHAR(12) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					liters DECIMAL(9,2) NOT NULL,
					total INT UNSIGNED NOT NULL,
					method VARCHAR(8) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					target VARCHAR(8) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					mode VARCHAR(8) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					created_at BIGINT UNSIGNED NOT NULL,
					PRIMARY KEY (id),
					KEY idx_fuel_sales_business (business_id, created_at)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]]
		}
	},
	{
		version = 2,
		name = 'levels_prices_fleet',
		statements = {
			-- Nível de cada tanque do posto (1 = o que vem com o posto).
			[[
				ALTER TABLE coe_fuel_tanks ADD COLUMN IF NOT EXISTS level TINYINT UNSIGNED NOT NULL DEFAULT 1
			]],
			-- Preço por litro definido pelo dono (sem linha = preço de tabela).
			[[
				CREATE TABLE IF NOT EXISTS coe_fuel_prices (
					business_id VARCHAR(24) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					fuel VARCHAR(12) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					price INT UNSIGNED NOT NULL,
					updated_at BIGINT UNSIGNED NOT NULL,
					PRIMARY KEY (business_id, fuel)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]],
			-- Veículos da frota de abastecimento (registrados no coe_vehicles, guardados na garagem de frota do posto)
			-- com o nível e a carga de cada combustível.
			[[
				CREATE TABLE IF NOT EXISTS coe_fuel_fleet (
					vehicle_id BIGINT UNSIGNED NOT NULL,
					business_id VARCHAR(24) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					tier TINYINT UNSIGNED NOT NULL,
					regular DECIMAL(9,2) NOT NULL DEFAULT 0,
					premium DECIMAL(9,2) NOT NULL DEFAULT 0,
					ethanol DECIMAL(9,2) NOT NULL DEFAULT 0,
					diesel DECIMAL(9,2) NOT NULL DEFAULT 0,
					created_at BIGINT UNSIGNED NOT NULL,
					PRIMARY KEY (vehicle_id),
					KEY idx_fuel_fleet_business (business_id)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]]
		}
	}
}
