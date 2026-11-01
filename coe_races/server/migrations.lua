RacesMigrations = {
	{
		version = 1,
		name = 'tracks_profiles_races_results',
		statements = {
			-- Pistas: largada e checkpoints em JSON; status active, featured (destaque da staff) ou hidden.
			[[
				CREATE TABLE IF NOT EXISTS coe_races_tracks (
					id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
					name VARCHAR(64) NOT NULL,
					description VARCHAR(400) NOT NULL DEFAULT '',
					kind VARCHAR(8) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					start_json VARCHAR(128) NOT NULL,
					checkpoints_json TEXT NOT NULL,
					length_m INT UNSIGNED NOT NULL,
					creator_id BIGINT UNSIGNED NULL,
					creator_name VARCHAR(32) NOT NULL DEFAULT '',
					status VARCHAR(10) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT 'active',
					races INT UNSIGNED NOT NULL DEFAULT 0,
					created_at BIGINT UNSIGNED NOT NULL,
					PRIMARY KEY (id),
					KEY idx_races_tracks_status (status),
					KEY idx_races_tracks_creator (creator_id)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]],
			-- Pilotos: apelido único, rating e números da carreira (prize em unidades da cripto).
			[[
				CREATE TABLE IF NOT EXISTS coe_races_profiles (
					character_id BIGINT UNSIGNED NOT NULL,
					nickname VARCHAR(16) CHARACTER SET ascii COLLATE ascii_general_ci NOT NULL,
					rating INT NOT NULL,
					races INT UNSIGNED NOT NULL DEFAULT 0,
					wins INT UNSIGNED NOT NULL DEFAULT 0,
					podiums INT UNSIGNED NOT NULL DEFAULT 0,
					dnfs INT UNSIGNED NOT NULL DEFAULT 0,
					prize BIGINT UNSIGNED NOT NULL DEFAULT 0,
					created_at BIGINT UNSIGNED NOT NULL,
					PRIMARY KEY (character_id),
					UNIQUE KEY uq_races_nickname (nickname),
					KEY idx_races_rating (rating)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]],
			-- Corridas: status lobby, running, finished ou cancelled. settled = pote já pago ou devolvido.
			[[
				CREATE TABLE IF NOT EXISTS coe_races_races (
					id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
					track_id BIGINT UNSIGNED NOT NULL,
					organizer_id BIGINT UNSIGNED NOT NULL,
					laps TINYINT UNSIGNED NOT NULL,
					buy_in BIGINT UNSIGNED NOT NULL,
					class VARCHAR(24) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					status VARCHAR(10) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					payout_address VARCHAR(40) CHARACTER SET ascii COLLATE ascii_bin NULL,
					created_at BIGINT UNSIGNED NOT NULL,
					finished_at BIGINT UNSIGNED NULL,
					PRIMARY KEY (id),
					KEY idx_races_status (status)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]],
			-- Inscrições: de onde saiu a entrada (custódia do coe_crypto) e para onde vai o prêmio. settled = já pago/devolvido.
			[[
				CREATE TABLE IF NOT EXISTS coe_races_entries (
					race_id BIGINT UNSIGNED NOT NULL,
					character_id BIGINT UNSIGNED NOT NULL,
					pay_address VARCHAR(40) CHARACTER SET ascii COLLATE ascii_bin NULL,
					payout_address VARCHAR(40) CHARACTER SET ascii COLLATE ascii_bin NULL,
					amount BIGINT UNSIGNED NOT NULL DEFAULT 0,
					settled TINYINT(1) NOT NULL DEFAULT 0,
					created_at BIGINT UNSIGNED NOT NULL,
					PRIMARY KEY (race_id, character_id),
					KEY idx_races_entries_open (settled)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]],
			-- Resultados: um por corredor por corrida (dnf = abandono). Base do histórico e dos recordes por pista.
			[[
				CREATE TABLE IF NOT EXISTS coe_races_results (
					id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
					race_id BIGINT UNSIGNED NOT NULL,
					track_id BIGINT UNSIGNED NOT NULL,
					character_id BIGINT UNSIGNED NOT NULL,
					nickname VARCHAR(16) NOT NULL,
					position TINYINT UNSIGNED NOT NULL,
					racers TINYINT UNSIGNED NOT NULL,
					time_ms INT UNSIGNED NULL,
					best_lap_ms INT UNSIGNED NULL,
					laps TINYINT UNSIGNED NOT NULL,
					class VARCHAR(24) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					vehicle VARCHAR(32) NOT NULL DEFAULT '',
					dnf TINYINT(1) NOT NULL DEFAULT 0,
					rating_delta INT NOT NULL DEFAULT 0,
					prize BIGINT UNSIGNED NOT NULL DEFAULT 0,
					created_at BIGINT UNSIGNED NOT NULL,
					PRIMARY KEY (id),
					KEY idx_races_results_track (track_id, dnf, best_lap_ms),
					KEY idx_races_results_track_time (track_id, laps, dnf, time_ms),
					KEY idx_races_results_character (character_id, id)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]]
		}
	}
}
