---@meta
-- Contrato público de coe_telecom para LuaLS. Não é carregado pelo servidor.
-- Gerado a partir dos exports registrados no código; refine descrições e tipos ao mexer em cada export.

---@class CoeTelecomExports
local exports_coe_telecom = {}

---O telefone pergunta antes de ligar ou mandar mensagem pela linha `number` (chip do aparelho). holder: titular do chip (nil = anônimo). Retorna { ok, maxSeconds } ou { ok = false, error }.
---@param number any
---@param kind any
---@param holder any
---@return any
function exports_coe_telecom:Authorize(number, kind, holder) end

---Uso concluído (ligação encerrada ou mensagem enviada). seconds só vale para voz e vídeo.
---@param number any
---@param kind any
---@param seconds any
---@param peer any
---@param holder any
---@return any
function exports_coe_telecom:Charge(number, kind, seconds, peer, holder) end

---Resumo da linha de um número para outros resources.
---@param number any
---@return any
function exports_coe_telecom:LineOf(number) end

---Export server `TabletCall` (server/main.lua).
---@param playerId any
---@param appId any
---@param action any
---@param payload any
---@return any
function exports_coe_telecom:TabletCall(playerId, appId, action, payload) end

---Export server `TabletVisible` (server/main.lua).
---@param playerId any
---@param appId any
---@return any
function exports_coe_telecom:TabletVisible(playerId, appId) end
