CryptoMigrations = {
	{
		version = 1,
		name = 'wallets_ledger_prices',
		statements = {
			-- Carteira: endereço público, hash da chave e saldo em unidades. Saldo UNSIGNED: em modo estrito, um débito
			-- além do saldo falha e desfaz a transação inteira. created_by fica para investigação (nunca vai ao cliente).
			[[
				CREATE TABLE IF NOT EXISTS coe_crypto_wallets (
					address VARCHAR(40) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					key_hash VARCHAR(255) NOT NULL DEFAULT '',
					balance BIGINT UNSIGNED NOT NULL DEFAULT 0,
					created_by BIGINT UNSIGNED NULL,
					created_at BIGINT UNSIGNED NOT NULL,
					PRIMARY KEY (address),
					KEY idx_crypto_wallets_creator (created_by, created_at)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]],
			-- Chaves guardadas em aparelhos (phone:<serial>, tablet:<personagem>, laptop:<serial>, desktop:<serial>...).
			[[
				CREATE TABLE IF NOT EXISTS coe_crypto_keystore (
					device_key VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					address VARCHAR(40) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					secret VARCHAR(40) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					label VARCHAR(48) NOT NULL DEFAULT '',
					added_at BIGINT UNSIGNED NOT NULL,
					PRIMARY KEY (device_key, address),
					KEY idx_crypto_keystore_address (address)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]],
			-- Livro público da rede. kind: transfer, buy, sell, mint, genesis. fiat: $ da ordem (compra/venda).
			-- character_id e device_key registram quem executou (rastro para investigação, nunca exibido no explorador).
			[[
				CREATE TABLE IF NOT EXISTS coe_crypto_tx (
					id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
					kind VARCHAR(12) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					from_address VARCHAR(40) CHARACTER SET ascii COLLATE ascii_bin NULL,
					to_address VARCHAR(40) CHARACTER SET ascii COLLATE ascii_bin NULL,
					amount BIGINT UNSIGNED NOT NULL,
					fee BIGINT UNSIGNED NOT NULL DEFAULT 0,
					fiat BIGINT UNSIGNED NOT NULL DEFAULT 0,
					memo VARCHAR(120) NOT NULL DEFAULT '',
					character_id BIGINT UNSIGNED NULL,
					device_key VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NULL,
					created_at BIGINT UNSIGNED NOT NULL,
					PRIMARY KEY (id),
					KEY idx_crypto_tx_from (from_address, id),
					KEY idx_crypto_tx_to (to_address, id),
					KEY idx_crypto_tx_character (character_id, kind, created_at)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]],
			[[
				CREATE TABLE IF NOT EXISTS coe_crypto_prices (
					id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
					price BIGINT UNSIGNED NOT NULL,
					created_at BIGINT UNSIGNED NOT NULL,
					PRIMARY KEY (id),
					KEY idx_crypto_prices_at (created_at)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]],
			-- Contadores da rede (ex.: minted = total emitido por mineração).
			[[
				CREATE TABLE IF NOT EXISTS coe_crypto_state (
					name VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					value BIGINT UNSIGNED NOT NULL DEFAULT 0,
					PRIMARY KEY (name)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]]
		}
	},
	{
		version = 2,
		name = 'crypto_settings',
		statements = {
			-- Configurações editáveis pelo admin (vazia = valores de config.lua).
			[[
				CREATE TABLE IF NOT EXISTS coe_crypto_settings (
					id TINYINT UNSIGNED NOT NULL,
					config_json TEXT NOT NULL,
					updated_at BIGINT UNSIGNED NOT NULL,
					PRIMARY KEY (id)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]]
		}
	}
}

