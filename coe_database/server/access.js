// Quem pode usar o banco: os resources do framework (padrão) ou quem recebeu a ACE no server.cfg:
//   add_ace resource.meu_script coe.database allow
// O nome do chamador vem do runtime (GetInvokingResource), nunca do payload.
const DEFAULT_CALLERS = Object.freeze([
	'coe_core', 'coe_inventory', 'coe_audit', 'coe_vehicles', 'coe_vehicle_catalog', 'coe_businesses',
	'coe_needs', 'coe_economy', 'coe_spawn', 'coe_jobs', 'coe_shops', 'coe_rentals',
	// scripts avançados do framework (antigo coe-resources)
	'coe_phone', 'coe_apps', 'coe_telecom', 'coe_mail', 'coe_elos', 'coe_news', 'coe_mechanic', 'coe_handling', 'coe_fuel', 'coe_garages', 'coe_deepweb', 'coe_crypto', 'coe_races', 'coe_amzg', 'coe_factions', 'coe_police', 'coe_ems', 'coe_mdt', 'coe_banking', 'coe_housing', 'coe_doors', 'coe_crafting', 'coe_admin'
])
const DATABASE_ACE = 'coe.database'
const CACHE_MS = 5000

function createCallerCheck(options) {
	const defaults = new Set(options.defaults || DEFAULT_CALLERS)
	const ace = options.ace || DATABASE_ACE
	const isAceAllowed = options.isAceAllowed
	const now = options.now || Date.now
	const cache = new Map()

	return function allowed(caller) {
		if (typeof caller !== 'string' || caller === '') {
			return false
		}
		if (defaults.has(caller)) {
			return true
		}
		if (typeof isAceAllowed !== 'function') {
			return false
		}
		const at = now()
		const hit = cache.get(caller)
		if (hit && at - hit.at < CACHE_MS) {
			return hit.ok
		}
		const ok = Boolean(isAceAllowed(`resource.${caller}`, ace))
		cache.set(caller, { ok, at })
		return ok
	}
}

module.exports = { DEFAULT_CALLERS, DATABASE_ACE, createCallerCheck }
