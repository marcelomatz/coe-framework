---@meta
-- Contrato público de coe_ems para LuaLS. Não é carregado pelo servidor.
-- Gerado a partir dos exports registrados no código; refine descrições e tipos ao mexer em cada export.

---@class CoeEmsExports
local exports_coe_ems = {}

---Prontuário de um paciente (personagem): exige o cargo com ems.records em um negócio ems de ponto.
---@param medicSource any
---@param patientCharacterId any
---@param limit any
---@return any
function exports_coe_ems:Records(medicSource, patientCharacterId, limit) end

---Export server `Revive` (server/main.lua).
---@param medicSource any
---@param targetSource any
---@param detail any
---@return any
function exports_coe_ems:Revive(medicSource, targetSource, detail) end

---coe_needs, coe_hud e coe_admin podem definir o estado (ex.: dano vindo de outro sistema).
---@param source any
---@param state any
---@return any
function exports_coe_ems:SetState(source, state) end

---Export server `State` (server/main.lua).
---@param source any
---@return any
function exports_coe_ems:State(source) end

---Export server `Treat` (server/main.lua).
---@param medicSource any
---@param targetSource any
---@param detail any
---@return any
function exports_coe_ems:Treat(medicSource, targetSource, detail) end
