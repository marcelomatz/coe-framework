ElosMigrations = {
	{
		version = 1,
		name = 'network',
		statements = {
			-- Perfil de cada personagem que abriu o Elos (nome e stateId copiados para buscas e visitas offline).
			[[
				CREATE TABLE IF NOT EXISTS coe_elos_profiles (
					character_id BIGINT UNSIGNED NOT NULL,
					state_id CHAR(8) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					name VARCHAR(64) NOT NULL,
					headline VARCHAR(80) NOT NULL DEFAULT '',
					about VARCHAR(600) NOT NULL DEFAULT '',
					visibility VARCHAR(8) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT 'open',
					show_earnings TINYINT(1) NOT NULL DEFAULT 0,
					show_career TINYINT(1) NOT NULL DEFAULT 1,
					created_at BIGINT UNSIGNED NOT NULL,
					updated_at BIGINT UNSIGNED NOT NULL,
					PRIMARY KEY (character_id),
					UNIQUE KEY uq_elos_profiles_state (state_id),
					KEY idx_elos_profiles_name (name)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]],
			-- Experiências que o personagem pôs no currículo (o que aparece para os outros), com um comentário.
			[[
				CREATE TABLE IF NOT EXISTS coe_elos_items (
					character_id BIGINT UNSIGNED NOT NULL,
					kind VARCHAR(8) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					ref VARCHAR(48) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					note VARCHAR(160) NOT NULL DEFAULT '',
					added_at BIGINT UNSIGNED NOT NULL,
					PRIMARY KEY (character_id, kind, ref)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]],
			-- Horas de ponto em cada negócio (coe_businesses:dutyChanged), com o último cargo e a primeira/última vez.
			[[
				CREATE TABLE IF NOT EXISTS coe_elos_work (
					character_id BIGINT UNSIGNED NOT NULL,
					business_id VARCHAR(24) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					label VARCHAR(64) NOT NULL,
					category VARCHAR(24) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT '',
					role VARCHAR(48) NOT NULL DEFAULT '',
					seconds INT UNSIGNED NOT NULL DEFAULT 0,
					shifts INT UNSIGNED NOT NULL DEFAULT 0,
					first_at BIGINT UNSIGNED NOT NULL,
					last_at BIGINT UNSIGNED NOT NULL,
					PRIMARY KEY (character_id, business_id)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]],
			-- Conexões: uma linha por par (quem pediu e quem recebeu); `pending` até o aceite.
			[[
				CREATE TABLE IF NOT EXISTS coe_elos_connections (
					requester_id BIGINT UNSIGNED NOT NULL,
					target_id BIGINT UNSIGNED NOT NULL,
					status VARCHAR(8) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT 'pending',
					created_at BIGINT UNSIGNED NOT NULL,
					accepted_at BIGINT UNSIGNED NULL,
					PRIMARY KEY (requester_id, target_id),
					KEY idx_elos_connections_target (target_id, status)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]]
		}
	}
}
