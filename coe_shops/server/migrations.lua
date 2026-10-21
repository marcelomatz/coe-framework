ShopsMigrations = {
	{
		version = 1,
		name = 'shelves_and_sales',
		statements = {
			-- Prateleira de cada loja de jogador: quantidade e preço definido pelo dono (nulo = preço de tabela).
			[[
				CREATE TABLE IF NOT EXISTS coe_shops_shelves (
					business_id VARCHAR(24) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					product_id VARCHAR(24) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					quantity INT UNSIGNED NOT NULL DEFAULT 0,
					price INT UNSIGNED NULL,
					updated_at BIGINT UNSIGNED NOT NULL,
					PRIMARY KEY (business_id, product_id)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]],
			-- Vendas (relatório da gestão e auditoria): quem comprou, quanto, como pagou e os itens.
			[[
				CREATE TABLE IF NOT EXISTS coe_shops_sales (
					id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
					business_id VARCHAR(24) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					character_id BIGINT UNSIGNED NOT NULL,
					mode VARCHAR(8) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					method VARCHAR(8) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					total INT UNSIGNED NOT NULL,
					units INT UNSIGNED NOT NULL,
					lines_json VARCHAR(2048) NOT NULL,
					created_at BIGINT UNSIGNED NOT NULL,
					PRIMARY KEY (id),
					KEY idx_shops_sales_business (business_id, created_at)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]]
		}
	}
}
