---@meta
-- Contrato público de coe_needs para LuaLS. Não é carregado pelo servidor. Ver docs/ANNOTATIONS.md.

---@alias CoeNeedName 'hunger'|'thirst'|'stress'

---@class CoeNeedsState
---@field hunger integer 0-100
---@field thirst integer 0-100
---@field stress integer 0-100

---@class CoeNeedsExports
local exports_coe_needs = {}

---Estado atual do jogador. Server.
---@param source integer
---@return CoeNeedsState|nil snapshot `nil` se o personagem não está carregado
function exports_coe_needs:GetNeeds(source) end

---Soma `delta` a uma necessidade (limitada a 0-100). Server; só resources em `AllowedResources`.
---Gravação em lote periódico.
---@param source integer
---@param name CoeNeedName
---@param delta number
---@return true|string result `true` ou `caller_not_allowed`, `needs_not_loaded`, `invalid_need`
function exports_coe_needs:AddNeed(source, name, delta) end

---Define o valor de uma necessidade. Mesmas regras de `AddNeed`.
---@param source integer
---@param name CoeNeedName
---@param value number
---@return true|string result `true` ou `caller_not_allowed`, `needs_not_loaded`, `invalid_need`
function exports_coe_needs:SetNeed(source, name, value) end

---Último estado recebido do servidor. Client.
---@return CoeNeedsState|nil
function exports_coe_needs:GetState() end
