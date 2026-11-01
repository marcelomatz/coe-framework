---@meta
-- Contrato público de coe_dispatch para LuaLS. Não é carregado pelo servidor.
-- Gerado a partir dos exports registrados no código; refine descrições e tipos ao mexer em cada export.

---@class CoeDispatchExports
local exports_coe_dispatch = {}

---Export server `Accept` (server/main.lua).
---@param source any
---@param id any
---@return any
function exports_coe_dispatch:Accept(source, id) end

---Export server `Active` (server/main.lua).
---@param source any
---@return any
function exports_coe_dispatch:Active(source) end

---Alerta automático de outros resources: Alert(code, x, y, z). Retorna o id ou { error }.
---@param code any
---@param x any
---@param y any
---@param z any
---@return any
function exports_coe_dispatch:Alert(code, x, y, z) end

---Export server `Close` (server/main.lua).
---@param source any
---@param id any
---@return any
function exports_coe_dispatch:Close(source, id) end
