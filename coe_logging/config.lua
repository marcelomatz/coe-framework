CoeLoggingConfig = {
	DefaultLevel = 'info',
	-- 'pretty' (legível, com cores) ou 'json' (uma linha JSON por evento, para coletores).
	-- As convars coe_logging_format e coe_logging_color sobrescrevem estes valores.
	DefaultFormat = 'pretty',
	DefaultColor = true,
	-- Nível por resource (os demais usam DefaultLevel ou a convar coe_logging_level_<resource>).
	ResourceLevels = {
		coe_core = 'info',
		coe_database = 'info',
		coe_inventory = 'info',
		coe_audit = 'info',
		coe_vehicles = 'info',
		coe_vehicle_catalog = 'info',
		coe_businesses = 'info',
		coe_economy = 'info',
		coe_needs = 'info',
		coe_spawn = 'info',
		coe_jobs = 'info',
		coe_shops = 'info',
		coe_bank = 'info',
		coe_mobile = 'info',
		coe_workpad = 'info',
		coe_staff = 'info'
	},
	-- Quem grava logs. Padrões do framework; pacotes e scripts de terceiros recebem a ACE no server.cfg:
	--   add_ace resource.<nome> coe.logging allow
	Ace = 'coe.logging',
	AllowedResources = {
		coe_core = true,
		coe_database = true,
		coe_inventory = true,
		coe_audit = true,
		coe_vehicles = true,
		coe_vehicle_catalog = true,
		coe_businesses = true,
		coe_economy = true,
		coe_needs = true,
		coe_spawn = true,
		coe_jobs = true,
		coe_shops = true,
		coe_bank = true,
		coe_mobile = true,
		coe_workpad = true,
		coe_staff = true
	},
	AllowedContextFields = {
		action = true,
		character_id = true,
		count = true,
		error_code = true,
		item = true,
		mileage = true,
		model = true,
		operation = true,
		plate = true,
		player_id = true,
		previous_mileage = true,
		request_id = true,
		resource_state = true,
		result = true,
		retry_ms = true,
		role = true,
		source = true,
		target = true,
		vehicle_id = true
	}
}
