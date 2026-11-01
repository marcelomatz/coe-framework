AmzgMigrations = {
	{
		version = 1,
		name = 'products_orders',
		statements = {
			[[
				CREATE TABLE IF NOT EXISTS coe_amzg_products (
					id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
					item VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					label VARCHAR(64) NOT NULL,
					category VARCHAR(16) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					price BIGINT UNSIGNED NOT NULL,
					active TINYINT(1) NOT NULL DEFAULT 1,
					sort SMALLINT UNSIGNED NOT NULL DEFAULT 0,
					updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
					PRIMARY KEY (id)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]],
			[[
				CREATE TABLE IF NOT EXISTS coe_amzg_orders (
					id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
					character_id BIGINT UNSIGNED NOT NULL,
					property_id VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					owner VARCHAR(40) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					address_label VARCHAR(96) NOT NULL,
					items TEXT NOT NULL,
					total BIGINT UNSIGNED NOT NULL,
					shipping_fee BIGINT UNSIGNED NOT NULL DEFAULT 0,
					shipping VARCHAR(16) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					card_id BIGINT UNSIGNED NOT NULL,
					status VARCHAR(16) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT 'pending',
					created_at BIGINT UNSIGNED NOT NULL,
					deliver_at BIGINT UNSIGNED NOT NULL,
					delivered_at BIGINT UNSIGNED NULL,
					PRIMARY KEY (id),
					KEY idx_amzg_orders_due (status, deliver_at),
					KEY idx_amzg_orders_character (character_id, id),
					KEY idx_amzg_orders_space (property_id, owner, status)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]]
		}
	},
	-- Eletrônicos da DeepWeb (coe_deepweb/coe_crypto). Só entram se o item ainda não estiver no catálogo; depois o
	-- preço, o nome e a pausa são do painel admin (aba Amzg).
	{
		version = 2,
		name = 'seed_electronics',
		statements = {
			[[
				INSERT INTO coe_amzg_products (item, label, category, price, active, sort)
				SELECT 'laptop', 'Notebook', 'electronics', 4500, 1, 10 FROM DUAL
				WHERE NOT EXISTS (SELECT 1 FROM coe_amzg_products WHERE item = 'laptop')
			]],
			[[
				INSERT INTO coe_amzg_products (item, label, category, price, active, sort)
				SELECT 'desktop_pc', 'Computador desktop', 'electronics', 9000, 1, 11 FROM DUAL
				WHERE NOT EXISTS (SELECT 1 FROM coe_amzg_products WHERE item = 'desktop_pc')
			]],
			[[
				INSERT INTO coe_amzg_products (item, label, category, price, active, sort)
				SELECT 'home_server', 'Servidor doméstico', 'electronics', 22000, 1, 12 FROM DUAL
				WHERE NOT EXISTS (SELECT 1 FROM coe_amzg_products WHERE item = 'home_server')
			]],
			[[
				INSERT INTO coe_amzg_products (item, label, category, price, active, sort)
				SELECT 'usb_black', 'Pen drive', 'electronics', 120, 1, 13 FROM DUAL
				WHERE NOT EXISTS (SELECT 1 FROM coe_amzg_products WHERE item = 'usb_black')
			]]
		}
	},
	-- Promoções e banners: preço promocional (0 = sem), fim da promoção (epoch, 0 = sem prazo), destaque nos banners e
	-- selo curto do banner.
	{
		version = 3,
		name = 'promotions',
		statements = {
			'ALTER TABLE coe_amzg_products ADD COLUMN IF NOT EXISTS promo_price BIGINT UNSIGNED NOT NULL DEFAULT 0',
			'ALTER TABLE coe_amzg_products ADD COLUMN IF NOT EXISTS promo_until BIGINT UNSIGNED NOT NULL DEFAULT 0',
			'ALTER TABLE coe_amzg_products ADD COLUMN IF NOT EXISTS featured TINYINT(1) NOT NULL DEFAULT 0',
			"ALTER TABLE coe_amzg_products ADD COLUMN IF NOT EXISTS banner_text VARCHAR(48) NOT NULL DEFAULT ''"
		}
	}
}
