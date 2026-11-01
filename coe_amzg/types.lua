---@meta
-- Contrato público de coe_amzg para LuaLS. Não é carregado pelo servidor.
-- Gerado a partir dos exports registrados no código; refine descrições e tipos ao mexer em cada export.

---@class CoeAmzgExports
local exports_coe_amzg = {}

---Export server `AdminCatalog` (server/main.lua).
---@return any
function exports_coe_amzg:AdminCatalog() end

---Export server `AdminDeleteProduct` (server/main.lua).
---@param input any
---@return any
function exports_coe_amzg:AdminDeleteProduct(input) end

---Export server `AdminSaveProduct` (server/main.lua).
---@param input any
---@return any
function exports_coe_amzg:AdminSaveProduct(input) end

---Export server `TabletCall` (server/main.lua).
---@param playerId any
---@param appId any
---@param action any
---@param payload any
---@return any
function exports_coe_amzg:TabletCall(playerId, appId, action, payload) end

---Export server `TabletVisible` (server/main.lua).
---@param playerId any
---@param appId any
---@return any
function exports_coe_amzg:TabletVisible(playerId, appId) end
