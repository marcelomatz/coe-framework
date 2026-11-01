---@meta
-- Contrato público de coe_mail para LuaLS. Não é carregado pelo servidor.
-- Gerado a partir dos exports registrados no código; refine descrições e tipos ao mexer em cada export.

---@class CoeMailExports
local exports_coe_mail = {}

---E-mail do sistema (ex.: avisos de outros resources). from: { address, name }; to: endereço ou lista. Devolve { ok, bounced } ou { ok = false, error }.
---@param from any
---@param to any
---@param subject any
---@param body any
---@return any
function exports_coe_mail:Send(from, to, subject, body) end

---Export server `TabletCall` (server/main.lua).
---@param playerId any
---@param appId any
---@param action any
---@param payload any
---@return any
function exports_coe_mail:TabletCall(playerId, appId, action, payload) end

---Export server `TabletVisible` (server/main.lua).
---@param playerId any
---@param appId any
---@return any
function exports_coe_mail:TabletVisible(playerId, appId) end
