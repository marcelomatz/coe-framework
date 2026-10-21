JobsMigrations = {
	{
		version = 1,
		name = 'progress',
		statements = {
			[[
				CREATE TABLE IF NOT EXISTS coe_jobs_progress (
					character_id BIGINT UNSIGNED NOT NULL,
					job_id VARCHAR(24) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					xp INT UNSIGNED NOT NULL DEFAULT 0,
					tasks INT UNSIGNED NOT NULL DEFAULT 0,
					earned BIGINT UNSIGNED NOT NULL DEFAULT 0,
					updated_at BIGINT UNSIGNED NOT NULL,
					PRIMARY KEY (character_id, job_id),
					KEY idx_jobs_progress_job (job_id, xp)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]]
		}
	},
	{
		version = 2,
		name = 'career_profile',
		statements = {
			-- Reputação nos empregos livres e contadores de trabalhos concluídos e abandonados.
			[[
				CREATE TABLE IF NOT EXISTS coe_jobs_profile (
					character_id BIGINT UNSIGNED NOT NULL,
					reputation SMALLINT NOT NULL DEFAULT 0,
					completed INT UNSIGNED NOT NULL DEFAULT 0,
					abandoned INT UNSIGNED NOT NULL DEFAULT 0,
					updated_at BIGINT UNSIGNED NOT NULL,
					PRIMARY KEY (character_id)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]]
		}
	},
	{
		version = 3,
		name = 'sessions',
		statements = {
			-- Últimos trabalhos de cada personagem: o que fez em cada sessão (do "Começar" ao fim).
			[[
				CREATE TABLE IF NOT EXISTS coe_jobs_sessions (
					id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
					character_id BIGINT UNSIGNED NOT NULL,
					job_id VARCHAR(24) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					started_at BIGINT UNSIGNED NOT NULL,
					ended_at BIGINT UNSIGNED NOT NULL,
					tasks INT UNSIGNED NOT NULL DEFAULT 0,
					xp INT UNSIGNED NOT NULL DEFAULT 0,
					earned BIGINT UNSIGNED NOT NULL DEFAULT 0,
					discarded INT UNSIGNED NOT NULL DEFAULT 0,
					reason VARCHAR(16) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
					PRIMARY KEY (id),
					KEY idx_jobs_sessions_character (character_id, ended_at)
				) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			]]
		}
	},
	{
		version = 4,
		name = 'worked_time',
		statements = {
			-- Tempo trabalhado em cada emprego (currículo do coe_elos): soma das sessões e primeira/última vez.
			[[
				ALTER TABLE coe_jobs_progress
					ADD COLUMN IF NOT EXISTS seconds INT UNSIGNED NOT NULL DEFAULT 0,
					ADD COLUMN IF NOT EXISTS first_at BIGINT UNSIGNED NULL,
					ADD COLUMN IF NOT EXISTS last_at BIGINT UNSIGNED NULL
			]],
			[[
				UPDATE coe_jobs_progress p
				JOIN (
					SELECT character_id, job_id, SUM(IF(ended_at > started_at, ended_at - started_at, 0)) AS worked,
						MIN(started_at) AS first_seen, MAX(ended_at) AS last_seen
					FROM coe_jobs_sessions GROUP BY character_id, job_id
				) s ON s.character_id = p.character_id AND s.job_id = p.job_id
				SET p.seconds = s.worked, p.first_at = s.first_seen, p.last_at = s.last_seen
			]]
		}
	}
}
