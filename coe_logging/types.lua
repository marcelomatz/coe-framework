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

---Retorna as entradas recentes mantidas no buffer circular Zero-GC em memória.
---Exige permissão ACE `coe.logging.log` do recurso chamador.
---@param limit integer|nil Quantidade máxima de entradas (padrão: capacidade total do RingBuffer)
---@return table|nil entries Lista de entradas estruturadas (da mais antiga para a mais recente)
---@return string|nil errorCode `resource_not_allowed` se o chamador não possuir ACE
function exports_coe_logging:GetRecent(limit) end
