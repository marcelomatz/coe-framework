---@meta
-- Contrato público de coe_notify para LuaLS. Não é carregado pelo servidor. Ver docs/ANNOTATIONS.md.

---@alias CoeNotifyKind 'info'|'success'|'warning'|'error'

---@class CoeNotifyExports
local exports_coe_notify = {}

---Mostra uma notificação a um jogador. Server; só resources autorizados.
---@param playerId integer
---@param kind CoeNotifyKind
---@param message string 1 a 240 caracteres
---@param duration integer|nil 1500 a 10000 ms (padrão 4000)
---@return boolean ok
---@return string|nil errorCode `caller_not_allowed`, `invalid_target`, `invalid_notification`
function exports_coe_notify:Notify(playerId, kind, message, duration) end

---Mostra uma notificação local. Client.
---@param kind CoeNotifyKind
---@param message string 1 a 240 caracteres
---@param duration integer|nil 1500 a 10000 ms (padrão 4000)
---@return boolean ok
---@return string|nil errorCode `invalid_notification`
function exports_coe_notify:Show(kind, message, duration) end
