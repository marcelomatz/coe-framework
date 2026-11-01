MailMigrations = {
	{
		version = 1,
		name = 'accounts_messages',
		statements = {
			[[
				CREATE TABLE IF NOT EXISTS coe_mail_accounts (
					id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
					address VARCHAR(80) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					domain VARCHAR(60) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					display_name VARCHAR(48) NOT NULL DEFAULT '',
					signature VARCHAR(255) NOT NULL DEFAULT '',
					password_hash VARCHAR(255) NOT NULL,
					owner_character BIGINT UNSIGNED NOT NULL,
					created_at BIGINT UNSIGNED NOT NULL,
					PRIMARY KEY (id),
					UNIQUE KEY uq_mail_accounts_address (address),
					KEY idx_mail_accounts_owner (owner_character),
					KEY idx_mail_accounts_domain (domain)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]],
			[[
				CREATE TABLE IF NOT EXISTS coe_mail_sessions (
					device_key VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					account_id BIGINT UNSIGNED NOT NULL,
					created_at BIGINT UNSIGNED NOT NULL,
					PRIMARY KEY (device_key, account_id),
					KEY idx_mail_sessions_account (account_id)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]],
			[[
				CREATE TABLE IF NOT EXISTS coe_mail_messages (
					id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
					sender_address VARCHAR(80) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					sender_name VARCHAR(48) NOT NULL DEFAULT '',
					subject VARCHAR(160) NOT NULL DEFAULT '',
					body TEXT NOT NULL,
					to_list VARCHAR(1000) NOT NULL DEFAULT '',
					cc_list VARCHAR(1000) NOT NULL DEFAULT '',
					bcc_list VARCHAR(1000) NOT NULL DEFAULT '',
					created_at BIGINT UNSIGNED NOT NULL,
					PRIMARY KEY (id)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]],
			-- Uma linha por conta que vê a mensagem. role: 'from' (quem enviou) ou 'to' (quem recebeu).
			[[
				CREATE TABLE IF NOT EXISTS coe_mail_boxes (
					id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
					account_id BIGINT UNSIGNED NOT NULL,
					message_id BIGINT UNSIGNED NOT NULL,
					folder VARCHAR(12) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					role VARCHAR(4) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					is_read TINYINT(1) NOT NULL DEFAULT 0,
					starred TINYINT(1) NOT NULL DEFAULT 0,
					moved_at BIGINT UNSIGNED NOT NULL,
					PRIMARY KEY (id),
					KEY idx_mail_boxes_folder (account_id, folder, id),
					KEY idx_mail_boxes_message (message_id),
					KEY idx_mail_boxes_trash (folder, moved_at)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]]
		}
	}
}
