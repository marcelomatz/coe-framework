-- Acesso entre resources por ACE do FiveM (server). Cada resource tem o principal `resource.<nome>`; o dono do
-- servidor concede as capacidades no server.cfg, sem editar o framework:
--   add_ace resource.meu_script coe.economy allow
-- Os padrões (`defaults`) listam só os resources do próprio framework. Pacotes e scripts de terceiros entram por ACE.
-- Incluído com '@coe_core/lib/access.lua' (não depende do coe_core estar iniciado).
CoeAccess = CoeAccess or {}

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
