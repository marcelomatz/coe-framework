AppsMigrations = {
	{
		version = 1,
		name = 'store_classifieds_insta',
		statements = {
			[[
				CREATE TABLE IF NOT EXISTS coe_apps_installed (
					character_id BIGINT UNSIGNED NOT NULL,
					app_id VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					installed TINYINT(1) NOT NULL DEFAULT 1,
					price_paid BIGINT UNSIGNED NOT NULL DEFAULT 0,
					created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
					updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
					PRIMARY KEY (character_id, app_id)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]],
			[[
				CREATE TABLE IF NOT EXISTS coe_apps_classifieds (
					id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
					character_id BIGINT UNSIGNED NOT NULL,
					author VARCHAR(64) NOT NULL,
					contact VARCHAR(16) NOT NULL,
					category VARCHAR(16) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					title VARCHAR(255) NOT NULL,
					body TEXT NOT NULL,
					price BIGINT UNSIGNED NULL,
					created_at BIGINT UNSIGNED NOT NULL,
					expires_at BIGINT UNSIGNED NOT NULL,
					PRIMARY KEY (id),
					KEY idx_classifieds_expires (expires_at),
					KEY idx_classifieds_character (character_id)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]],
			[[
				CREATE TABLE IF NOT EXISTS coe_apps_insta_media (
					id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
					character_id BIGINT UNSIGNED NOT NULL,
					data MEDIUMTEXT CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
					PRIMARY KEY (id)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]],
			[[
				CREATE TABLE IF NOT EXISTS coe_apps_insta_posts (
					id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
					character_id BIGINT UNSIGNED NOT NULL,
					author VARCHAR(64) NOT NULL,
					handle VARCHAR(40) NOT NULL,
					caption TEXT NOT NULL,
					image VARCHAR(512) NOT NULL,
					created_at BIGINT UNSIGNED NOT NULL,
					PRIMARY KEY (id),
					KEY idx_insta_character (character_id)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]],
			[[
				CREATE TABLE IF NOT EXISTS coe_apps_insta_likes (
					post_id BIGINT UNSIGNED NOT NULL,
					character_id BIGINT UNSIGNED NOT NULL,
					PRIMARY KEY (post_id, character_id),
					CONSTRAINT fk_insta_like_post FOREIGN KEY (post_id) REFERENCES coe_apps_insta_posts (id) ON DELETE CASCADE
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]]
		}
	},
	{
		version = 2,
		name = 'weekly_subscriptions',
		statements = {
			'ALTER TABLE coe_apps_installed ADD COLUMN IF NOT EXISTS paid_until BIGINT UNSIGNED NOT NULL DEFAULT 0',
			'ALTER TABLE coe_apps_installed ADD COLUMN IF NOT EXISTS auto_renew TINYINT(1) NOT NULL DEFAULT 0',
			'CREATE INDEX IF NOT EXISTS idx_apps_renewal ON coe_apps_installed (auto_renew, installed, paid_until)',
			-- Quem comprou antes das assinaturas ganha a primeira semana.
			'UPDATE coe_apps_installed SET paid_until = UNIX_TIMESTAMP() + 604800, auto_renew = installed WHERE price_paid > 0'
		}
	},
	{
		version = 3,
		name = 'subscription_card',
		statements = {
			-- Cartão (coe_banking) que paga a assinatura; escolhido na Carteira do smartphone.
			'ALTER TABLE coe_apps_installed ADD COLUMN IF NOT EXISTS card_id BIGINT UNSIGNED NULL'
		}
	}
}
