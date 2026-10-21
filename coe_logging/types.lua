---@meta
-- Contrato público de coe_logging para LuaLS. Não é carregado pelo servidor. Ver docs/ANNOTATIONS.md.

---@alias CoeLogLevel 'debug'|'info'|'warn'|'error'

---@class CoeLoggingExports
local exports_coe_logging = {}

---Registra uma linha estruturada (JSON ou "pretty", conforme convar). O recurso chamador vira o campo `resource`.
---@param level CoeLogLevel
---@param category string Até 48 caracteres
---@param event string Até 80 caracteres
---@param context table|nil Contexto sanitizado (sem segredos)
---@return boolean ok
---@return string|nil errorCode `invalid_level`, `invalid_event`, `encoding_failed`, ...
function exports_coe_logging:Log(level, category, event, context) end
