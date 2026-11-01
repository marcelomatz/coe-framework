BankingMigrations = {
	{
		version = 1,
		name = 'cards',
		statements = {
			[[
				CREATE TABLE IF NOT EXISTS coe_banking_cards (
					id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
					account_type VARCHAR(16) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT 'personal',
					account_ref VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					holder_id BIGINT UNSIGNED NOT NULL,
					holder_name VARCHAR(64) NOT NULL DEFAULT '',
					serial CHAR(16) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					pin_hash VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					pin_salt VARCHAR(16) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					attempts TINYINT UNSIGNED NOT NULL DEFAULT 0,
					blocked_reason VARCHAR(16) CHARACTER SET ascii COLLATE ascii_bin NULL,
					blocked_at DATETIME(3) NULL,
					created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
					PRIMARY KEY (id),
					UNIQUE KEY uq_cards_serial (serial),
					KEY idx_cards_account (account_type, account_ref)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]]
		}
	},
	{
		version = 2,
		name = 'credit',
		statements = {
			-- Conta de crédito por personagem; tempos em epoch (segundos). `version` evita gravação concorrente.
			[[
				CREATE TABLE IF NOT EXISTS coe_banking_credit (
					character_id BIGINT UNSIGNED NOT NULL,
					tier VARCHAR(16) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					credit_limit BIGINT UNSIGNED NOT NULL,
					open_amount BIGINT UNSIGNED NOT NULL DEFAULT 0,
					invoice_amount BIGINT UNSIGNED NOT NULL DEFAULT 0,
					invoice_min BIGINT UNSIGNED NOT NULL DEFAULT 0,
					invoice_paid BIGINT UNSIGNED NOT NULL DEFAULT 0,
					due_at BIGINT NULL,
					closes_at BIGINT NOT NULL,
					late TINYINT(1) NOT NULL DEFAULT 0,
					late_since BIGINT NULL,
					interest_at BIGINT NULL,
					on_time INT UNSIGNED NOT NULL DEFAULT 0,
					late_count INT UNSIGNED NOT NULL DEFAULT 0,
					points BIGINT UNSIGNED NOT NULL DEFAULT 0,
					version INT UNSIGNED NOT NULL DEFAULT 0,
					created_at BIGINT NOT NULL,
					PRIMARY KEY (character_id),
					KEY idx_credit_closes (closes_at),
					KEY idx_credit_due (due_at)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]],
			[[
				CREATE TABLE IF NOT EXISTS coe_banking_credit_entries (
					id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
					character_id BIGINT UNSIGNED NOT NULL,
					kind VARCHAR(24) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					amount BIGINT NOT NULL,
					description VARCHAR(64) NOT NULL DEFAULT '',
					created_at BIGINT NOT NULL,
					PRIMARY KEY (id),
					KEY idx_credit_entries_character (character_id, id)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]]
		}
	},
	{
		version = 3,
		name = 'card_expiry_tiers_loans',
		statements = {
			-- Validade do cartão (epoch); cartões já emitidos valem 60 dias a partir da emissão.
			'ALTER TABLE coe_banking_cards ADD COLUMN IF NOT EXISTS expires_at BIGINT NULL',
			'UPDATE coe_banking_cards SET expires_at = UNIX_TIMESTAMP(created_at) + 5184000 WHERE expires_at IS NULL',
			-- Limite definido pela staff (sobrepõe o do nível) e nível travado (não rebaixa).
			'ALTER TABLE coe_banking_credit ADD COLUMN IF NOT EXISTS custom_limit BIGINT UNSIGNED NULL',
			'ALTER TABLE coe_banking_credit ADD COLUMN IF NOT EXISTS tier_locked TINYINT(1) NOT NULL DEFAULT 0',
			-- Níveis editáveis pelo admin; vazia = valores do config.lua.
			[[
				CREATE TABLE IF NOT EXISTS coe_banking_tiers (
					id VARCHAR(16) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					label VARCHAR(24) NOT NULL,
					min_score SMALLINT UNSIGNED NOT NULL,
					credit_limit BIGINT UNSIGNED NOT NULL,
					points_per_100 DECIMAL(6,2) NOT NULL,
					fee BIGINT UNSIGNED NOT NULL,
					free_atm TINYINT(1) NOT NULL DEFAULT 0,
					updated_at BIGINT NOT NULL,
					PRIMARY KEY (id)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]],
			-- Empréstimos concedidos pela staff: parcelas semanais com débito automático.
			[[
				CREATE TABLE IF NOT EXISTS coe_banking_loans (
					id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
					character_id BIGINT UNSIGNED NOT NULL,
					principal BIGINT UNSIGNED NOT NULL,
					rate DECIMAL(6,2) NOT NULL,
					total BIGINT UNSIGNED NOT NULL,
					installments SMALLINT UNSIGNED NOT NULL,
					paid_count SMALLINT UNSIGNED NOT NULL DEFAULT 0,
					paid_amount BIGINT UNSIGNED NOT NULL DEFAULT 0,
					remaining BIGINT UNSIGNED NOT NULL,
					due_at BIGINT NULL,
					late TINYINT(1) NOT NULL DEFAULT 0,
					on_time INT UNSIGNED NOT NULL DEFAULT 0,
					late_count INT UNSIGNED NOT NULL DEFAULT 0,
					status VARCHAR(12) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT 'active',
					note VARCHAR(64) NOT NULL DEFAULT '',
					version INT UNSIGNED NOT NULL DEFAULT 0,
					created_at BIGINT NOT NULL,
					closed_at BIGINT NULL,
					PRIMARY KEY (id),
					KEY idx_loans_character (character_id, status),
					KEY idx_loans_due (status, due_at)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]]
		}
	},
	{
		version = 4,
		name = 'loan_interest_business_loans',
		statements = {
			-- Juros diários de atraso (% ao dia, fixados no contrato), juros já lançados e o próximo dia a cobrar.
			-- Contratos anteriores ficam com 0: não foram firmados com juros de atraso.
			'ALTER TABLE coe_banking_loans ADD COLUMN IF NOT EXISTS late_rate DECIMAL(6,3) NOT NULL DEFAULT 0',
			'ALTER TABLE coe_banking_loans ADD COLUMN IF NOT EXISTS interest BIGINT UNSIGNED NOT NULL DEFAULT 0',
			'ALTER TABLE coe_banking_loans ADD COLUMN IF NOT EXISTS interest_at BIGINT NULL',
			-- Empréstimo empresarial: pago pelo caixa do negócio; a dívida fica com os devedores (dono e sócios).
			'ALTER TABLE coe_banking_loans ADD COLUMN IF NOT EXISTS business_id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NULL',
			'ALTER TABLE coe_banking_loans ADD COLUMN IF NOT EXISTS business_label VARCHAR(64) NOT NULL DEFAULT \'\'',
			'ALTER TABLE coe_banking_loans ADD INDEX IF NOT EXISTS idx_loans_business (business_id, status)',
			[[
				CREATE TABLE IF NOT EXISTS coe_banking_loan_debtors (
					loan_id BIGINT UNSIGNED NOT NULL,
					character_id BIGINT UNSIGNED NOT NULL,
					PRIMARY KEY (loan_id, character_id),
					KEY idx_loan_debtors_character (character_id)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]],
			'INSERT IGNORE INTO coe_banking_loan_debtors (loan_id, character_id) SELECT id, character_id FROM coe_banking_loans',
			-- Pedidos de empréstimo empresarial feitos na agência; a staff aprova ou recusa no admin.
			[[
				CREATE TABLE IF NOT EXISTS coe_banking_loan_requests (
					id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
					business_id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					business_label VARCHAR(64) NOT NULL DEFAULT '',
					character_id BIGINT UNSIGNED NOT NULL,
					principal BIGINT UNSIGNED NOT NULL,
					installments SMALLINT UNSIGNED NOT NULL,
					note VARCHAR(64) NOT NULL DEFAULT '',
					score SMALLINT UNSIGNED NOT NULL DEFAULT 0,
					rate DECIMAL(6,2) NOT NULL,
					late_rate DECIMAL(6,3) NOT NULL,
					status VARCHAR(12) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT 'pending',
					reason VARCHAR(64) NOT NULL DEFAULT '',
					loan_id BIGINT UNSIGNED NULL,
					created_at BIGINT NOT NULL,
					decided_at BIGINT NULL,
					PRIMARY KEY (id),
					KEY idx_loan_requests_status (status, id),
					KEY idx_loan_requests_business (business_id, status)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]]
		}
	},
	{
		version = 5,
		name = 'virtual_cards',
		statements = {
			-- Cartão virtual: sem item nem senha, existe só na carteira do smartphone. Os anteriores são físicos.
			'ALTER TABLE coe_banking_cards ADD COLUMN IF NOT EXISTS kind VARCHAR(10) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT \'physical\''
		}
	},
	{
		version = 6,
		name = 'business_accounts',
		statements = {
			-- Cartão empresarial (account_type = 'business', account_ref = id do negócio, holder = alguém da equipe):
			-- limite diário (NULL = sem limite) e o gasto do dia (`spent_day` = dias desde a época).
			'ALTER TABLE coe_banking_cards ADD COLUMN IF NOT EXISTS daily_limit BIGINT UNSIGNED NULL',
			'ALTER TABLE coe_banking_cards ADD COLUMN IF NOT EXISTS spent_amount BIGINT UNSIGNED NOT NULL DEFAULT 0',
			'ALTER TABLE coe_banking_cards ADD COLUMN IF NOT EXISTS spent_day INT UNSIGNED NULL',
			-- Operações da conta empresarial feitas pelo banco: quem fez, para quem e observação. O extrato do coe_economy
			-- leva a referência `bop:<id>` para ligar cada lançamento à operação.
			[[
				CREATE TABLE IF NOT EXISTS coe_banking_business_ops (
					id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
					business_id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					character_id BIGINT UNSIGNED NULL,
					actor_name VARCHAR(64) NOT NULL DEFAULT '',
					kind VARCHAR(16) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					amount BIGINT UNSIGNED NOT NULL,
					counterparty VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT '',
					counterparty_label VARCHAR(64) NOT NULL DEFAULT '',
					memo VARCHAR(96) NOT NULL DEFAULT '',
					status VARCHAR(10) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT 'pending',
					created_at BIGINT NOT NULL,
					PRIMARY KEY (id),
					KEY idx_business_ops (business_id, id)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]]
		}
	}
}
