NewsMigrations = {
	{
		version = 1,
		name = 'outlets_articles_ads',
		statements = {
			[[
				CREATE TABLE IF NOT EXISTS coe_news_outlets (
					outlet VARCHAR(16) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					tagline VARCHAR(160) NOT NULL DEFAULT '',
					editorial TEXT NOT NULL,
					sections VARCHAR(200) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT '',
					ad_price INT UNSIGNED NOT NULL,
					last_breaking BIGINT UNSIGNED NOT NULL DEFAULT 0,
					updated_at BIGINT UNSIGNED NOT NULL,
					updated_by BIGINT UNSIGNED NULL,
					PRIMARY KEY (outlet)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]],
			-- status: draft, review, published, unpublished. image: `media:<id>` (coe_apps) ou URL https.
			[[
				CREATE TABLE IF NOT EXISTS coe_news_articles (
					id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
					outlet VARCHAR(16) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					section VARCHAR(16) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					status VARCHAR(12) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					title VARCHAR(200) NOT NULL,
					summary VARCHAR(480) NOT NULL DEFAULT '',
					body TEXT NOT NULL,
					image VARCHAR(255) NOT NULL DEFAULT '',
					author_character BIGINT UNSIGNED NOT NULL,
					author_name VARCHAR(48) NOT NULL DEFAULT '',
					anonymous TINYINT(1) NOT NULL DEFAULT 0,
					breaking TINYINT(1) NOT NULL DEFAULT 0,
					views INT UNSIGNED NOT NULL DEFAULT 0,
					note VARCHAR(400) NOT NULL DEFAULT '',
					editor_name VARCHAR(48) NOT NULL DEFAULT '',
					created_at BIGINT UNSIGNED NOT NULL,
					updated_at BIGINT UNSIGNED NOT NULL,
					published_at BIGINT UNSIGNED NULL,
					PRIMARY KEY (id),
					KEY idx_news_articles_feed (outlet, status, published_at),
					KEY idx_news_articles_author (outlet, author_character, status)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]],
			-- status: pending (pago, valor retido), active, rejected, cancelled, expired.
			-- payer_kind: personal (conta do personagem) ou business (caixa do negócio em payer_ref).
			[[
				CREATE TABLE IF NOT EXISTS coe_news_ads (
					id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
					outlet VARCHAR(16) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					buyer_character BIGINT UNSIGNED NOT NULL,
					payer_kind VARCHAR(10) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					payer_ref VARCHAR(40) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT '',
					advertiser VARCHAR(96) NOT NULL,
					title VARCHAR(120) NOT NULL,
					body VARCHAR(600) NOT NULL,
					days INT UNSIGNED NOT NULL,
					price INT UNSIGNED NOT NULL,
					status VARCHAR(10) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					note VARCHAR(320) NOT NULL DEFAULT '',
					created_at BIGINT UNSIGNED NOT NULL,
					decided_at BIGINT UNSIGNED NULL,
					ends_at BIGINT UNSIGNED NULL,
					PRIMARY KEY (id),
					KEY idx_news_ads_outlet (outlet, status, ends_at),
					KEY idx_news_ads_buyer (buyer_character, outlet, status),
					KEY idx_news_ads_pending (status, created_at)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]]
		}
	}
}
