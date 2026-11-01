DeepwebMigrations = {
	{
		version = 1,
		name = 'handles_devices_rigs',
		statements = {
			-- Identidade anônima. owner_character e reputation ficam no servidor (investigação e próximas fases).
			[[
				CREATE TABLE IF NOT EXISTS coe_deepweb_handles (
					id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
					handle VARCHAR(24) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					password_hash VARCHAR(255) NOT NULL,
					owner_character BIGINT UNSIGNED NOT NULL,
					reputation INT NOT NULL DEFAULT 0,
					created_at BIGINT UNSIGNED NOT NULL,
					last_seen_at BIGINT UNSIGNED NOT NULL DEFAULT 0,
					PRIMARY KEY (id),
					UNIQUE KEY uq_deepweb_handles_handle (handle),
					KEY idx_deepweb_handles_owner (owner_character)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]],
			-- Apelido conectado por aparelho (um por vez).
			[[
				CREATE TABLE IF NOT EXISTS coe_deepweb_sessions (
					device_key VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					handle_id BIGINT UNSIGNED NOT NULL,
					created_at BIGINT UNSIGNED NOT NULL,
					PRIMARY KEY (device_key),
					KEY idx_deepweb_sessions_handle (handle_id)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]],
			-- Navegador onion instalado em celulares (phone:<serial>) e tablets (tablet:<personagem>).
			[[
				CREATE TABLE IF NOT EXISTS coe_deepweb_browsers (
					device_key VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					installed_by BIGINT UNSIGNED NOT NULL,
					installed_at BIGINT UNSIGNED NOT NULL,
					PRIMARY KEY (device_key)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]],
			-- Computadores (notebook, desktop, servidor): senha opcional, presa ao aparelho (série).
			[[
				CREATE TABLE IF NOT EXISTS coe_deepweb_devices (
					device_key VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					kind VARCHAR(12) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					password_hash VARCHAR(255) NOT NULL DEFAULT '',
					created_at BIGINT UNSIGNED NOT NULL,
					PRIMARY KEY (device_key)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]],
			-- Desktop e servidor instalados num espaço de imóvel (propriedade + dono do espaço, como o baú).
			[[
				CREATE TABLE IF NOT EXISTS coe_deepweb_rigs (
					id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
					kind VARCHAR(12) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					serial VARCHAR(16) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					property_id VARCHAR(48) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					space_owner VARCHAR(48) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					x DOUBLE NOT NULL,
					y DOUBLE NOT NULL,
					z DOUBLE NOT NULL,
					heading DOUBLE NOT NULL DEFAULT 0,
					installed_by BIGINT UNSIGNED NOT NULL,
					installed_at BIGINT UNSIGNED NOT NULL,
					payout_address VARCHAR(40) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT '',
					mining TINYINT(1) NOT NULL DEFAULT 0,
					mined_total BIGINT UNSIGNED NOT NULL DEFAULT 0,
					last_payout BIGINT UNSIGNED NOT NULL DEFAULT 0,
					last_status VARCHAR(16) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT '',
					last_tick_at BIGINT UNSIGNED NOT NULL DEFAULT 0,
					PRIMARY KEY (id),
					UNIQUE KEY uq_deepweb_rigs_serial (serial),
					KEY idx_deepweb_rigs_space (property_id, space_owner)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]]
		}
	},
	-- Reconhecimento facial dos computadores (personagem do rosto cadastrado).
	{
		version = 2,
		name = 'device_face',
		statements = {
			'ALTER TABLE coe_deepweb_devices ADD COLUMN IF NOT EXISTS face_character BIGINT UNSIGNED NULL'
		}
	},
	-- Navegador (favoritos), sites, Rabbit (fórum) e o mercado com custódia em cripto (hoje Deep Market).
	{
		version = 3,
		name = 'browser_forum_market',
		statements = {
			[[
				CREATE TABLE IF NOT EXISTS coe_deepweb_bookmarks (
					device_key VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					address VARCHAR(200) NOT NULL,
					title VARCHAR(64) NOT NULL DEFAULT '',
					created_at BIGINT UNSIGNED NOT NULL,
					PRIMARY KEY (device_key, address(120))
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]],
			-- Sites: app = search/forum/market (sistema) ou '' (páginas por blocos). owner_handle: hospedagem futura.
			[[
				CREATE TABLE IF NOT EXISTS coe_deepweb_sites (
					domain VARCHAR(40) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					app VARCHAR(12) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT '',
					title VARCHAR(64) NOT NULL,
					description VARCHAR(255) NOT NULL DEFAULT '',
					keywords VARCHAR(160) NOT NULL DEFAULT '',
					blocks MEDIUMTEXT NULL,
					owner_handle BIGINT UNSIGNED NULL,
					active TINYINT(1) NOT NULL DEFAULT 1,
					created_at BIGINT UNSIGNED NOT NULL,
					updated_at BIGINT UNSIGNED NOT NULL,
					PRIMARY KEY (domain),
					KEY idx_deepweb_sites_owner (owner_handle)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]],
			[[
				CREATE TABLE IF NOT EXISTS coe_deepweb_communities (
					id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
					slug VARCHAR(24) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					title VARCHAR(48) NOT NULL,
					description VARCHAR(255) NOT NULL DEFAULT '',
					created_by BIGINT UNSIGNED NULL,
					created_at BIGINT UNSIGNED NOT NULL,
					PRIMARY KEY (id),
					UNIQUE KEY uq_deepweb_communities_slug (slug),
					KEY idx_deepweb_communities_creator (created_by)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]],
			[[
				CREATE TABLE IF NOT EXISTS coe_deepweb_posts (
					id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
					community_id BIGINT UNSIGNED NOT NULL,
					handle_id BIGINT UNSIGNED NOT NULL,
					title VARCHAR(160) NOT NULL,
					body TEXT NOT NULL,
					score INT NOT NULL DEFAULT 0,
					comments INT UNSIGNED NOT NULL DEFAULT 0,
					removed TINYINT(1) NOT NULL DEFAULT 0,
					created_at BIGINT UNSIGNED NOT NULL,
					PRIMARY KEY (id),
					KEY idx_deepweb_posts_community (community_id, removed, created_at),
					KEY idx_deepweb_posts_handle (handle_id, created_at),
					KEY idx_deepweb_posts_recent (removed, created_at)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]],
			[[
				CREATE TABLE IF NOT EXISTS coe_deepweb_comments (
					id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
					post_id BIGINT UNSIGNED NOT NULL,
					parent_id BIGINT UNSIGNED NULL,
					handle_id BIGINT UNSIGNED NOT NULL,
					body TEXT NOT NULL,
					score INT NOT NULL DEFAULT 0,
					removed TINYINT(1) NOT NULL DEFAULT 0,
					created_at BIGINT UNSIGNED NOT NULL,
					PRIMARY KEY (id),
					KEY idx_deepweb_comments_post (post_id, id),
					KEY idx_deepweb_comments_handle (handle_id, created_at)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]],
			-- Votos por apelido (target: p = post, c = comentário).
			[[
				CREATE TABLE IF NOT EXISTS coe_deepweb_votes (
					target CHAR(1) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					target_id BIGINT UNSIGNED NOT NULL,
					handle_id BIGINT UNSIGNED NOT NULL,
					value TINYINT NOT NULL,
					PRIMARY KEY (target, target_id, handle_id),
					KEY idx_deepweb_votes_handle (handle_id)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]],
			-- Anúncios. seller_handle NULL = fornecedor NPC (vendor), gerenciado no admin. payout_address: quem recebe.
			[[
				CREATE TABLE IF NOT EXISTS coe_deepweb_listings (
					id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
					seller_handle BIGINT UNSIGNED NULL,
					vendor VARCHAR(32) NOT NULL DEFAULT '',
					kind VARCHAR(8) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT 'item',
					category VARCHAR(16) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					title VARCHAR(80) NOT NULL,
					description TEXT NOT NULL,
					item VARCHAR(48) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT '',
					item_count INT UNSIGNED NOT NULL DEFAULT 0,
					price BIGINT UNSIGNED NOT NULL,
					stock INT UNSIGNED NOT NULL DEFAULT 0,
					payout_address VARCHAR(40) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT '',
					status VARCHAR(8) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT 'active',
					sold INT UNSIGNED NOT NULL DEFAULT 0,
					created_at BIGINT UNSIGNED NOT NULL,
					updated_at BIGINT UNSIGNED NOT NULL,
					PRIMARY KEY (id),
					KEY idx_deepweb_listings_status (status, category, id),
					KEY idx_deepweb_listings_seller (seller_handle)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]],
			-- Pedidos com custódia. buyer_character fica no servidor (investigação). drop_index: ponto de coleta.
			-- settled: a custódia já foi paga a quem devia (estados finais); 0 num estado final = repetir o pagamento.
			[[
				CREATE TABLE IF NOT EXISTS coe_deepweb_orders (
					id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
					listing_id BIGINT UNSIGNED NOT NULL,
					kind VARCHAR(8) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					title VARCHAR(80) NOT NULL,
					seller_handle BIGINT UNSIGNED NULL,
					vendor VARCHAR(32) NOT NULL DEFAULT '',
					buyer_handle BIGINT UNSIGNED NOT NULL,
					buyer_character BIGINT UNSIGNED NOT NULL,
					item VARCHAR(48) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT '',
					item_count INT UNSIGNED NOT NULL DEFAULT 0,
					quantity INT UNSIGNED NOT NULL,
					total BIGINT UNSIGNED NOT NULL,
					fee BIGINT UNSIGNED NOT NULL DEFAULT 0,
					buyer_address VARCHAR(40) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					payout_address VARCHAR(40) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					drop_index INT UNSIGNED NOT NULL DEFAULT 0,
					status VARCHAR(10) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					note VARCHAR(255) NOT NULL DEFAULT '',
					created_at BIGINT UNSIGNED NOT NULL,
					delivered_at BIGINT UNSIGNED NOT NULL DEFAULT 0,
					closed_at BIGINT UNSIGNED NOT NULL DEFAULT 0,
					settled TINYINT(1) NOT NULL DEFAULT 0,
					PRIMARY KEY (id),
					KEY idx_deepweb_orders_buyer (buyer_handle, id),
					KEY idx_deepweb_orders_seller (seller_handle, id),
					KEY idx_deepweb_orders_status (status, delivered_at),
					KEY idx_deepweb_orders_settled (settled, status)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]],
			[[
				CREATE TABLE IF NOT EXISTS coe_deepweb_reviews (
					order_id BIGINT UNSIGNED NOT NULL,
					seller_handle BIGINT UNSIGNED NOT NULL,
					buyer_handle BIGINT UNSIGNED NOT NULL,
					rating TINYINT UNSIGNED NOT NULL,
					body VARCHAR(255) NOT NULL DEFAULT '',
					created_at BIGINT UNSIGNED NOT NULL,
					PRIMARY KEY (order_id),
					KEY idx_deepweb_reviews_seller (seller_handle, created_at)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]],
			-- Fornecedores NPC iniciais só entram uma vez (marca na tabela de estado).
			[[
				CREATE TABLE IF NOT EXISTS coe_deepweb_state (
					name VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					value BIGINT NOT NULL DEFAULT 0,
					PRIMARY KEY (name)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]]
		}
	},
	-- Sites fora do diretório/busca (listed), contato dos sites de perfil e o Bazar Negro virando Deep Market
	-- (deepmarket.onion): sai o site de sistema antigo; favoritos e links dos sites por blocos passam ao endereço novo.
	{
		version = 4,
		name = 'contacts_deep_market',
		statements = {
			'ALTER TABLE coe_deepweb_sites ADD COLUMN IF NOT EXISTS listed TINYINT(1) NOT NULL DEFAULT 1',
			-- status: open (sem resposta), answered (respondida), closed (arquivada pela staff).
			[[
				CREATE TABLE IF NOT EXISTS coe_deepweb_contacts (
					id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
					site VARCHAR(40) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					handle_id BIGINT UNSIGNED NOT NULL,
					body TEXT NOT NULL,
					reply TEXT NULL,
					status VARCHAR(8) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT 'open',
					created_at BIGINT UNSIGNED NOT NULL,
					replied_at BIGINT UNSIGNED NOT NULL DEFAULT 0,
					PRIMARY KEY (id),
					KEY idx_deepweb_contacts_handle (handle_id, site, id),
					KEY idx_deepweb_contacts_status (status, id)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]],
			"DELETE FROM coe_deepweb_sites WHERE domain = 'bazar.onion' AND app = 'market'",
			"UPDATE IGNORE coe_deepweb_bookmarks SET address = CONCAT('deepmarket.onion', SUBSTRING(address, 12)) WHERE address LIKE 'bazar.onion%'",
			"UPDATE coe_deepweb_sites SET blocks = REPLACE(blocks, 'bazar.onion', 'deepmarket.onion') WHERE blocks LIKE '%bazar.onion%'",
			"UPDATE coe_deepweb_communities SET title = 'Deep Market' WHERE slug = 'bazar' AND created_by IS NULL"
		}
	}
}
