---@meta
-- Contrato público de coe_apps para LuaLS. Não é carregado pelo servidor.
-- Gerado a partir dos exports registrados no código; refine descrições e tipos ao mexer em cada export.

---@class CoeAppsExports
local exports_coe_apps = {}

---Guarda a foto enviada pelo aparelho (token do upload) e devolve { ok, image } (`media:<id>` ou URL https).
---@param playerId any
---@param token any
---@return any
function exports_coe_apps:ClaimPhoto(playerId, token) end

---Export server `DeletePhoto` (server/main.lua).
---@param image any
---@return any
function exports_coe_apps:DeletePhoto(image) end

---Outros resources com apps na loja (ex.: coe_amzg) conferem se o personagem instalou o app no aparelho.
---@param playerId any
---@param appId any
---@param device any
---@return any
function exports_coe_apps:HasApp(playerId, appId, device) end

---Conteúdo de uma foto guardada no banco (`media:<id>`).
---@param id any
---@return any
function exports_coe_apps:PhotoData(id) end

---Export client `StorePhoto` (client/camera.lua).
---@param image any
---@return any
function exports_coe_apps:StorePhoto(image) end

---Export server `TabletCall` (server/main.lua).
---@param playerId any
---@param appId any
---@param action any
---@param payload any
---@return any
function exports_coe_apps:TabletCall(playerId, appId, action, payload) end

---Export server `TabletVisible` (server/main.lua).
---@param playerId any
---@param appId any
---@return any
function exports_coe_apps:TabletVisible(playerId, appId) end

---Export client `TakePhoto` (client/camera.lua).
---@return any
function exports_coe_apps:TakePhoto() end
