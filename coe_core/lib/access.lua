-- Acesso entre resources por ACE do FiveM (server). Cada resource tem o principal `resource.<nome>`; o dono do
-- servidor concede as capacidades no server.cfg, sem editar o framework:
--   add_ace resource.meu_script coe.economy allow
-- Os padrões (`defaults`) e `CoeAccess.FirstParty` listam só os resources do próprio framework. Scripts de terceiros entram por ACE.
-- Incluído com '@coe_core/lib/access.lua' (não depende do coe_core estar iniciado).
CoeAccess = CoeAccess or {}

-- Capacidades dos scripts avançados do próprio framework (antigo coe-resources). Valem sem ACE no server.cfg, como os
-- padrões de cada resource da base: assim nada depende de `exec permissions.cfg` dar certo na hospedagem.
-- Mantenha em sincronia com o uso real (tools/check_contracts.lua confere as chamadas protegidas).
CoeAccess.FirstParty = {
	coe_phone = { ['coe.database'] = true, ['coe.logging'] = true, ['coe.notify'] = true, ['coe.shops.payments'] = true, ['coe.talk'] = true },
	coe_tablet = { ['coe.logging'] = true, ['coe.businesses.tablet'] = true, ['coe.jobs.tablet'] = true, ['coe.businesses.clock'] = true, ['coe.notify'] = true, ['coe.dispatch'] = true, ['coe.factions.tablet'] = true, ['coe.mechanic.tablet'] = true },
	coe_apps = { ['coe.database'] = true, ['coe.economy.money'] = true, ['coe.audit'] = true, ['coe.logging'] = true, ['coe.notify'] = true, ['coe.jobs.tablet'] = true },
	coe_telecom = { ['coe.database'] = true, ['coe.economy.money'] = true, ['coe.logging'] = true, ['coe.notify'] = true },
	coe_mail = { ['coe.database'] = true, ['coe.audit'] = true, ['coe.logging'] = true, ['coe.notify'] = true },
	coe_elos = { ['coe.database'] = true, ['coe.logging'] = true, ['coe.notify'] = true },
	coe_news = { ['coe.database'] = true, ['coe.economy.money'] = true, ['coe.economy.society.collect'] = true, ['coe.economy.society.pay'] = true, ['coe.audit'] = true, ['coe.logging'] = true, ['coe.notify'] = true, ['coe.businesses.write'] = true, ['coe.businesses.permissions'] = true },
	coe_mechanic = { ['coe.database'] = true, ['coe.economy.money'] = true, ['coe.audit'] = true, ['coe.logging'] = true, ['coe.notify'] = true, ['coe.vehicles.mileage'] = true, ['coe.businesses.write'] = true, ['coe.businesses.clock'] = true, ['coe.businesses.permissions'] = true, ['coe.handling.write'] = true, ['coe.mechanic.write'] = true, ['coe.crafting'] = true },
	coe_handling = { ['coe.database'] = true, ['coe.audit'] = true, ['coe.logging'] = true, ['coe.handling.write'] = true },
	coe_fuel = { ['coe.database'] = true, ['coe.economy.money'] = true, ['coe.economy.society.collect'] = true, ['coe.economy.society.pay'] = true, ['coe.audit'] = true, ['coe.logging'] = true, ['coe.notify'] = true, ['coe.businesses.write'] = true, ['coe.businesses.permissions'] = true, ['coe.businesses.extend'] = true, ['coe.mechanic.wear'] = true },
	coe_garages = { ['coe.database'] = true, ['coe.economy.money'] = true, ['coe.audit'] = true, ['coe.logging'] = true, ['coe.notify'] = true, ['coe.vehicles.write'] = true, ['coe.businesses.extend'] = true },
	coe_deepweb = { ['coe.database'] = true, ['coe.economy.money'] = true, ['coe.audit'] = true, ['coe.logging'] = true, ['coe.notify'] = true, ['coe.dispatch'] = true, ['coe.loot'] = true, ['coe.crafting'] = true },
	coe_crypto = { ['coe.database'] = true, ['coe.economy.money'] = true, ['coe.audit'] = true, ['coe.logging'] = true, ['coe.notify'] = true },
	coe_races = { ['coe.database'] = true, ['coe.audit'] = true, ['coe.logging'] = true, ['coe.notify'] = true, ['coe.dispatch'] = true, ['coe.loot'] = true },
	coe_loot = { ['coe.audit'] = true, ['coe.logging'] = true, ['coe.notify'] = true, ['coe.dispatch'] = true },
	coe_amzg = { ['coe.database'] = true, ['coe.audit'] = true, ['coe.logging'] = true, ['coe.notify'] = true },
	coe_factions = { ['coe.database'] = true, ['coe.audit'] = true, ['coe.crafting'] = true },
	coe_police = { ['coe.database'] = true, ['coe.economy.money'] = true, ['coe.economy.society.collect'] = true, ['coe.audit'] = true, ['coe.businesses.permissions'] = true, ['coe.notify'] = true, ['coe.dispatch'] = true },
	coe_ems = { ['coe.database'] = true, ['coe.audit'] = true, ['coe.businesses.permissions'] = true, ['coe.notify'] = true, ['coe.needs'] = true, ['coe.dispatch'] = true },
	coe_dispatch = { ['coe.audit'] = true, ['coe.notify'] = true },
	coe_mdt = { ['coe.database'] = true, ['coe.audit'] = true, ['coe.businesses.permissions'] = true, ['coe.dispatch'] = true },
	coe_banking = { ['coe.database'] = true, ['coe.economy.money'] = true, ['coe.economy.society.collect'] = true, ['coe.economy.society.pay'] = true, ['coe.economy.society.bank'] = true, ['coe.audit'] = true, ['coe.logging'] = true, ['coe.notify'] = true, ['coe.businesses.permissions'] = true, ['coe.businesses.payroll'] = true, ['coe.businesses.extend'] = true, ['coe.shops.payments'] = true },
	coe_housing = { ['coe.database'] = true, ['coe.economy.money'] = true, ['coe.economy.society.collect'] = true, ['coe.economy.society.pay'] = true, ['coe.audit'] = true, ['coe.logging'] = true, ['coe.notify'] = true, ['coe.businesses.extend'] = true },
	coe_doors = { ['coe.database'] = true, ['coe.audit'] = true, ['coe.logging'] = true, ['coe.notify'] = true, ['coe.factions.read'] = true },
	coe_crafting = { ['coe.database'] = true, ['coe.audit'] = true, ['coe.logging'] = true, ['coe.notify'] = true, ['coe.factions.read'] = true },
	coe_admin = { ['coe.database'] = true, ['coe.economy.money'] = true, ['coe.economy.admin'] = true, ['coe.audit'] = true, ['coe.logging'] = true, ['coe.notify'] = true, ['coe.rentals.admin'] = true, ['coe.needs'] = true, ['coe.vehicles.write'] = true, ['coe.vehicles.mileage'] = true, ['coe.vehicles.catalog'] = true, ['coe.businesses.write'] = true, ['coe.businesses.payroll'] = true, ['coe.businesses.admin'] = true, ['coe.groups.admin'] = true, ['coe.ui.theme'] = true, ['coe.supervisor'] = true, ['coe.dispatch'] = true, ['coe.factions.read'] = true, ['coe.factions.admin'] = true, ['coe.handling.write'] = true, ['coe.loot'] = true, ['coe.mechanic.write'] = true, ['coe.crafting'] = true },
}

local CACHE_MS = 5000
local cache = {}

local function now()
	if type(GetGameTimer) == 'function' then
		return GetGameTimer()
	end
	return nil
end

---O resource pode usar a capacidade? Padrão do framework ou ACE `ace` concedida a `resource.<nome>`.
---@param resource string|nil
---@param ace string Ex.: 'coe.economy'
---@param defaults table<string, boolean>|nil
---@return boolean
function CoeAccess.Allowed(resource, ace, defaults)
	if type(resource) ~= 'string' or resource == '' then
		return false
	end
	if type(defaults) == 'table' and defaults[resource] == true then
		return true
	end
	local granted = CoeAccess.FirstParty[resource]
	if granted and type(ace) == 'string' and granted[ace] == true then
		return true
	end
	if type(ace) ~= 'string' or ace == '' or type(IsPrincipalAceAllowed) ~= 'function' then
		return false
	end
	local key = resource .. '|' .. ace
	local at = now()
	local hit = cache[key]
	if hit and at and hit.at and at - hit.at < CACHE_MS then
		return hit.ok
	end
	local ok = IsPrincipalAceAllowed('resource.' .. resource, ace) == true
	cache[key] = { ok = ok, at = at }
	return ok
end

---Nome do resource que chamou o export, se ele pode usar a capacidade (nil se não pode ou não houve chamador).
---@param ace string
---@param defaults table<string, boolean>|nil
---@return string|nil
function CoeAccess.Caller(ace, defaults)
	local resource = GetInvokingResource()
	if CoeAccess.Allowed(resource, ace, defaults) then
		return resource
	end
	return nil
end

---Limpa o cache (testes, ou depois de mudar ACEs pelo console).
function CoeAccess.Reset()
	cache = {}
end

return CoeAccess
