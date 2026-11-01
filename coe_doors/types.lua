---@meta
-- Contrato público de coe_doors para LuaLS. Não é carregado pelo servidor.
-- Gerado a partir dos exports registrados no código; refine descrições e tipos ao mexer em cada export.

---@class CoeDoorsExports
local exports_coe_doors = {}

---Export server `CanAccess` (server/main.lua).
---@param playerId any
---@param id any
---@return any
function exports_coe_doors:CanAccess(playerId, id) end

---Export server `Delete` (server/main.lua).
---@param placeId any
---@return any
function exports_coe_doors:Delete(placeId) end

---API para outros resources (assaltos, eventos, scripts de negócio) ------------------------------------- id: "<local>:<porta>" para uma porta, ou "<local>" para todas as portas do local.
---@param id any
---@return any
function exports_coe_doors:IsLocked(id) end

---Export server `IsReady` (server/main.lua).
---@return any
function exports_coe_doors:IsReady() end

---Export server `List` (server/main.lua).
---@return any
function exports_coe_doors:List() end

---Export server `Save` (server/main.lua).
---@param raw any
---@return any
function exports_coe_doors:Save(raw) end

---Export server `SetLocked` (server/main.lua).
---@param id any
---@param locked any
---@return any
function exports_coe_doors:SetLocked(id, locked) end

---Export server `TabletCall` (server/main.lua).
---@param playerId any
---@param _ any
---@param action any
---@param payload any
---@return any
function exports_coe_doors:TabletCall(playerId, _, action, payload) end

---Export server `TabletVisible` (server/main.lua).
---@param playerId any
---@return any
function exports_coe_doors:TabletVisible(playerId) end
