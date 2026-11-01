---@meta
-- Contrato público de coe_police para LuaLS. Não é carregado pelo servidor.
-- Gerado a partir dos exports registrados no código; refine descrições e tipos ao mexer em cada export.

---@class CoePoliceExports
local exports_coe_police = {}

---Export server `Arrest` (server/main.lua).
---@param officerSource any
---@param targetSource any
---@param minutes any
---@param charge any
---@return any
function exports_coe_police:Arrest(officerSource, targetSource, minutes, charge) end

---Export server `Cuff` (server/main.lua).
---@param officerSource any
---@param targetSource any
---@return any
function exports_coe_police:Cuff(officerSource, targetSource) end

---Export server `Escort` (server/main.lua).
---@param officerSource any
---@param targetSource any
---@return any
function exports_coe_police:Escort(officerSource, targetSource) end

---Export server `Fine` (server/main.lua).
---@param officerSource any
---@param targetSource any
---@param amount any
---@param charge any
---@return any
function exports_coe_police:Fine(officerSource, targetSource, amount, charge) end

---Export server `IsCuffed` (server/main.lua).
---@param source any
---@return any
function exports_coe_police:IsCuffed(source) end

---Export server `IsEscorted` (server/main.lua).
---@param source any
---@return any
function exports_coe_police:IsEscorted(source) end

---Export server `IsJailed` (server/main.lua).
---@param source any
---@return any
function exports_coe_police:IsJailed(source) end

---Ficha criminal de um personagem: exige police.records em um negócio police de ponto.
---@param officerSource any
---@param subjectCharacterId any
---@param limit any
---@return any
function exports_coe_police:Records(officerSource, subjectCharacterId, limit) end

---Export server `Search` (server/main.lua).
---@param officerSource any
---@param targetSource any
---@return any
function exports_coe_police:Search(officerSource, targetSource) end

---Export server `Seize` (server/main.lua).
---@param officerSource any
---@param targetSource any
---@param slot any
---@param count any
---@return any
function exports_coe_police:Seize(officerSource, targetSource, slot, count) end

---Export server `Uncuff` (server/main.lua).
---@param officerSource any
---@param targetSource any
---@return any
function exports_coe_police:Uncuff(officerSource, targetSource) end
