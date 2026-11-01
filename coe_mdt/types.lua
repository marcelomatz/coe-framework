---@meta
-- Contrato público de coe_mdt para LuaLS. Não é carregado pelo servidor.
-- Gerado a partir dos exports registrados no código; refine descrições e tipos ao mexer em cada export.

---@class CoeMdtExports
local exports_coe_mdt = {}

---Registro de acessos para a corregedoria (somente resources autorizados).
---@param subject any
---@param limit any
---@return any
function exports_coe_mdt:AccessLog(subject, limit) end

---Ponto único de entrada: coe_tablet:call -> TabletCall(playerId, appId, action, payload).
---@param playerId any
---@param appId any
---@param action any
---@param payload any
---@return any
function exports_coe_mdt:TabletCall(playerId, appId, action, payload) end
