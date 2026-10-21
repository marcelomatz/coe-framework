---@meta
-- Contrato público de coe_audit para LuaLS. Não é carregado pelo servidor. Ver docs/ANNOTATIONS.md.

---@class CoeAuditExports
local exports_coe_audit = {}

---Enfileira um evento de auditoria e retorna na hora; a gravação é assíncrona em lote.
---O recurso chamador é registrado automaticamente e precisa estar em `AllowedResources`.
---@param severity string
---@param category string
---@param event string
---@param context table|nil Só campos de `AllowedContextFields`
---@return boolean ok
---@return string|nil errorCode `invalid_*`, `resource_not_allowed`, `queue_full`, ...
function exports_coe_audit:Record(severity, category, event, context) end

---Persistência inicializada (migrações aplicadas).
---@return boolean ready
function exports_coe_audit:IsReady() end
