---@meta
-- Contrato público de coe_news para LuaLS. Não é carregado pelo servidor.
-- Gerado a partir dos exports registrados no código; refine descrições e tipos ao mexer em cada export.

---@class CoeNewsExports
local exports_coe_news = {}

---Export server `AdminAction` (server/admin.lua).
---@param op any
---@param payload any
---@return any
function exports_coe_news:AdminAction(op, payload) end

---Export server `AdminOverview` (server/admin.lua).
---@return any
function exports_coe_news:AdminOverview() end

---Export server `AdminQuery` (server/admin.lua).
---@param kind any
---@param payload any
---@return any
function exports_coe_news:AdminQuery(kind, payload) end

---Export server `TabletCall` (server/main.lua).
---@param playerId any
---@param appId any
---@param action any
---@param payload any
---@return any
function exports_coe_news:TabletCall(playerId, appId, action, payload) end

---Export server `TabletVisible` (server/main.lua).
---@param playerId any
---@param appId any
---@return any
function exports_coe_news:TabletVisible(playerId, appId) end
