MobileMigrations = {
	{
		version = 1,
		name = 'numbers_contacts_messages_calls',
		statements = {
			-- Número de cada personagem, gerado no primeiro uso do telefone.
			[[
				CREATE TABLE IF NOT EXISTS coe_mobile_numbers (
					character_id BIGINT UNSIGNED NOT NULL,
					number VARCHAR(16) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					created_at BIGINT UNSIGNED NOT NULL,
					PRIMARY KEY (character_id),
					UNIQUE KEY uq_mobile_number (number)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]],
			[[
				CREATE TABLE IF NOT EXISTS coe_mobile_contacts (
					id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
					character_id BIGINT UNSIGNED NOT NULL,
					number VARCHAR(16) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					name VARCHAR(64) NOT NULL,
					created_at BIGINT UNSIGNED NOT NULL,
					PRIMARY KEY (id),
					UNIQUE KEY uq_mobile_contact (character_id, number)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]],
			-- Mensagens entre números. Cada lado apaga a conversa só para si (sender_deleted / receiver_deleted).
			[[
				CREATE TABLE IF NOT EXISTS coe_mobile_messages (
					id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
					sender VARCHAR(16) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					receiver VARCHAR(16) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					body VARCHAR(1200) NOT NULL,
					created_at BIGINT UNSIGNED NOT NULL,
					read_at BIGINT UNSIGNED NULL,
					sender_deleted TINYINT(1) NOT NULL DEFAULT 0,
					receiver_deleted TINYINT(1) NOT NULL DEFAULT 0,
					PRIMARY KEY (id),
					KEY idx_mobile_messages_sender (sender, receiver, id),
					KEY idx_mobile_messages_receiver (receiver, sender, id)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]],
			-- Histórico de ligações: answered, missed, declined, busy ou unreachable; duration em segundos.
			[[
				CREATE TABLE IF NOT EXISTS coe_mobile_calls (
					id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
					caller VARCHAR(16) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					callee VARCHAR(16) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					status VARCHAR(12) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					duration INT UNSIGNED NOT NULL DEFAULT 0,
					created_at BIGINT UNSIGNED NOT NULL,
					PRIMARY KEY (id),
					KEY idx_mobile_calls_caller (caller, id),
					KEY idx_mobile_calls_callee (callee, id)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]],
			[[
				CREATE TABLE IF NOT EXISTS coe_mobile_settings (
					character_id BIGINT UNSIGNED NOT NULL,
					data VARCHAR(512) NOT NULL,
					updated_at BIGINT UNSIGNED NOT NULL,
					PRIMARY KEY (character_id)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]]
		}
	}
}
