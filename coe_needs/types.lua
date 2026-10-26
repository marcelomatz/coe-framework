---@meta
--- Contratos LuaLS de `coe_needs`. Gerado para IDE/autocomplete; nao carregado em runtime.

---@alias CoeNeedName 'hunger'|'thirst'|'stress'|'alcohol'|'drugs'

---@class CoeNeedsSnapshot
---@field hunger integer # 0..100 (100 = saciado, 0 = faminto)
---@field thirst integer # 0..100 (100 = hidratado, 0 = desidratado)
---@field stress integer # 0..100 (0 = calmo, 100 = estressado)
---@field alcohol integer # 0..100 (0 = sobrio, 100 = alcoolizado)
---@field drugs integer # 0..100 (0 = limpo, 100 = sob efeito de substancias)

---@class exports_coe_needs
local exports_coe_needs = {}

--- [shared] No servidor recebe `playerSource`; no cliente nao recebe argumentos e retorna o snapshot local.
---@param playerSource? integer
---@return CoeNeedsSnapshot|nil
function exports_coe_needs:GetNeeds(playerSource) end

--- [server] Define o valor absoluto (0..100) de uma necessidade. Requer ACE `coe.needs`.
---@param playerSource integer
---@param needName CoeNeedName
---@param value number
---@return boolean|'caller_not_allowed'|'character_not_loaded'|'invalid_need'
function exports_coe_needs:SetNeed(playerSource, needName, value) end

--- [server] Soma `delta` (positivo ou negativo) a uma necessidade. Requer ACE `coe.needs`.
---@param playerSource integer
---@param needName CoeNeedName
---@param delta number
---@return boolean|'caller_not_allowed'|'character_not_loaded'|'invalid_need'
function exports_coe_needs:AddNeed(playerSource, needName, delta) end
