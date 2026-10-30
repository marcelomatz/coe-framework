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

---@class CoeNotifyPromptOption
---@field key string tecla mostrada (até 12 caracteres)
---@field label string ação (até 80 caracteres)

---@class CoeNotifyPrompt
---@field title string até 64 caracteres
---@field subtitle string|nil até 64 caracteres
---@field badge string|nil selo à esquerda (até 3 caracteres; padrão: tecla da primeira opção)
---@field options CoeNotifyPromptOption[] até 6

---Mostra (ou limpa, com nil) o aviso de interação padrão do resource chamador. Client.
---Chame só quando o conteúdo mudar; um aviso por resource; o resource parado tem o aviso removido.
---@param data CoeNotifyPrompt|nil
---@return boolean ok
---@return string|nil errorCode `invalid_prompt`
function exports_coe_notify:Prompt(data) end
