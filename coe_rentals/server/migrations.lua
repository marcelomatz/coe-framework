-- Cadastro das estações de aluguel (o painel edita; o config.lua só semeia a primeira vez).
RentalsMigrations = {
	{
		version = 1,
		name = 'rental_stations',
		statements = {
			[[
				CREATE TABLE IF NOT EXISTS coe_rental_stations (
					station_id VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					config JSON NOT NULL,
					updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
					PRIMARY KEY (station_id)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]]
		}
	}
}
