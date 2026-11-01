PhoneMigrations = {
	{
		version = 1,
		name = 'numbers_contacts_messages_calls',
		statements = {
			[[
				CREATE TABLE IF NOT EXISTS coe_phone_numbers (
					character_id BIGINT UNSIGNED NOT NULL,
					number VARCHAR(16) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
					PRIMARY KEY (character_id),
					UNIQUE KEY uq_phone_number (number)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]],
			[[
				CREATE TABLE IF NOT EXISTS coe_phone_contacts (
					id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
					character_id BIGINT UNSIGNED NOT NULL,
					name VARCHAR(64) NOT NULL,
					number VARCHAR(16) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					PRIMARY KEY (id),
					UNIQUE KEY uq_contact_number (character_id, number)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]],
			[[
				CREATE TABLE IF NOT EXISTS coe_phone_messages (
					id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
					sender VARCHAR(16) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					receiver VARCHAR(16) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					body TEXT NOT NULL,
					created_at BIGINT UNSIGNED NOT NULL,
					read_at BIGINT UNSIGNED NULL,
					PRIMARY KEY (id),
					KEY idx_messages_sender (sender, receiver),
					KEY idx_messages_receiver (receiver, read_at)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]],
			[[
				CREATE TABLE IF NOT EXISTS coe_phone_calls (
					id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
					caller VARCHAR(16) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					callee VARCHAR(16) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					status VARCHAR(16) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					duration INT UNSIGNED NOT NULL DEFAULT 0,
					created_at BIGINT UNSIGNED NOT NULL,
					PRIMARY KEY (id),
					KEY idx_calls_caller (caller),
					KEY idx_calls_callee (callee)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]]
		}
	},
	{
		version = 2,
		name = 'settings',
		statements = {
			[[
				CREATE TABLE IF NOT EXISTS coe_phone_settings (
					character_id BIGINT UNSIGNED NOT NULL,
					data TEXT NOT NULL,
					passcode VARCHAR(128) NULL,
					updated_at BIGINT UNSIGNED NOT NULL,
					PRIMARY KEY (character_id)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]]
		}
	},
	{
		version = 3,
		name = 'call_kind',
		statements = {
			[[
				ALTER TABLE coe_phone_calls
				ADD COLUMN IF NOT EXISTS kind VARCHAR(8) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT 'voice'
			]]
		}
	},
	{
		-- Aparelhos e chips viram objetos. Cada personagem com número ganha um aparelho legado (serial MG…)
		-- com seus ajustes e contatos e um chip com o mesmo número; o vínculo ao item acontece ao abrir.
		version = 4,
		name = 'devices_sims',
		statements = {
			[[
				CREATE TABLE IF NOT EXISTS coe_phone_devices (
					serial VARCHAR(16) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					model VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					owner_character BIGINT UNSIGNED NULL,
					face_character BIGINT UNSIGNED NULL,
					passcode VARCHAR(128) NULL,
					data TEXT NULL,
					bound TINYINT(1) NOT NULL DEFAULT 0,
					created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
					updated_at BIGINT UNSIGNED NOT NULL DEFAULT 0,
					PRIMARY KEY (serial),
					KEY idx_devices_owner (owner_character, bound)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]],
			[[
				CREATE TABLE IF NOT EXISTS coe_phone_sims (
					iccid VARCHAR(20) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					number VARCHAR(16) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					carrier VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT 'coe',
					holder_character BIGINT UNSIGNED NULL,
					device_serial VARCHAR(16) CHARACTER SET ascii COLLATE ascii_bin NULL,
					slot TINYINT UNSIGNED NULL,
					created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
					PRIMARY KEY (iccid),
					UNIQUE KEY uq_sims_number (number),
					UNIQUE KEY uq_sims_device_slot (device_serial, slot),
					KEY idx_sims_holder (holder_character)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]],
			[[
				CREATE TABLE IF NOT EXISTS coe_phone_device_contacts (
					id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
					serial VARCHAR(16) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					name VARCHAR(64) NOT NULL,
					number VARCHAR(16) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					PRIMARY KEY (id),
					UNIQUE KEY uq_device_contact (serial, number)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]],
			[[
				INSERT IGNORE INTO coe_phone_devices (serial, model, owner_character, face_character, passcode, data, bound, updated_at)
				SELECT CONCAT('MG', LPAD(n.character_id, 14, '0')), 'coe_one', n.character_id, n.character_id,
					s.passcode, s.data, 0, COALESCE(s.updated_at, 0)
				FROM coe_phone_numbers n
				LEFT JOIN coe_phone_settings s ON s.character_id = n.character_id
			]],
			[[
				INSERT IGNORE INTO coe_phone_sims (iccid, number, carrier, holder_character, device_serial, slot)
				SELECT CONCAT('8955', LPAD(character_id, 16, '0')), number, 'coe', character_id,
					CONCAT('MG', LPAD(character_id, 14, '0')), 1
				FROM coe_phone_numbers
			]],
			[[
				INSERT IGNORE INTO coe_phone_device_contacts (serial, name, number)
				SELECT CONCAT('MG', LPAD(character_id, 14, '0')), name, number
				FROM coe_phone_contacts
			]]
		}
	},
	{
		version = 5,
		name = 'photos',
		statements = {
			[[
				CREATE TABLE IF NOT EXISTS coe_phone_photos (
					id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
					serial VARCHAR(16) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					character_id BIGINT UNSIGNED NULL,
					image MEDIUMTEXT CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					thumb TEXT CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					bytes INT UNSIGNED NOT NULL,
					created_at BIGINT UNSIGNED NOT NULL,
					PRIMARY KEY (id),
					KEY idx_photos_serial (serial, id)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]]
		}
	},
	{
		version = 6,
		name = 'wallet',
		statements = {
			[[
				CREATE TABLE IF NOT EXISTS coe_phone_wallet (
					serial VARCHAR(16) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					card_id BIGINT UNSIGNED NOT NULL,
					is_default TINYINT(1) NOT NULL DEFAULT 0,
					added_at BIGINT UNSIGNED NOT NULL,
					PRIMARY KEY (serial, card_id)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]]
		}
	},
	{
		-- Upgrade do telefone básico (server/upgrade.lua): até onde cada tabela de origem já foi importada.
		version = 7,
		name = 'upgrades',
		statements = {
			[[
				CREATE TABLE IF NOT EXISTS coe_phone_upgrades (
					source VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					kind VARCHAR(16) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					last_id BIGINT UNSIGNED NOT NULL DEFAULT 0,
					updated_at BIGINT UNSIGNED NOT NULL,
					PRIMARY KEY (source, kind)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]]
		}
	}
}