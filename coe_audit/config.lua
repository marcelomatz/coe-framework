CoeAuditConfig = {
	-- Quem registra eventos; o nome vem do runtime, não do payload. Padrões do framework abaixo; pacotes e scripts de
	-- terceiros recebem a ACE no server.cfg: add_ace resource.<nome> coe.audit allow
	Ace = 'coe.audit',
	AllowedResources = {
		coe_core = true,
		coe_inventory = true,
		coe_vehicles = true,
		coe_vehicle_catalog = true,
		coe_economy = true,
		coe_businesses = true,
		coe_shops = true,
		coe_bank = true
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
		result = true,
		role = true,
		source = true,
		target = true,
		vehicle_id = true
	},
	Queue = {
		MaxSize = 1000,
		BatchSize = 50,
		FlushIntervalMs = 1000,
		MaxBackoffMs = 30000
	},
	-- 0 mantém os registros indefinidamente. Sobrescreva com `set coe_audit_retention_days N`.
	RetentionDays = 0,
	PurgeBatchSize = 5000
}
