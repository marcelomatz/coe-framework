NeedsMigrations = {
	resource = 'coe_needs',
	versions = {
		{
			version = 1,
			name = 'create_coe_needs_state',
			statements = {
				[=[
					CREATE TABLE IF NOT EXISTS coe_needs_state (
						character_id VARCHAR(64) NOT NULL PRIMARY KEY,
						hunger DOUBLE NOT NULL,
						thirst DOUBLE NOT NULL,
						stress DOUBLE NOT NULL,
						updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
					)
				]=]
			}
		},
		{
			version = 2,
			name = 'add_alcohol_and_drugs_columns',
			statements = {
				[=[
					ALTER TABLE coe_needs_state
						ADD COLUMN IF NOT EXISTS alcohol DOUBLE NOT NULL DEFAULT 0,
						ADD COLUMN IF NOT EXISTS drugs DOUBLE NOT NULL DEFAULT 0
				]=]
			}
		}
	}
}
