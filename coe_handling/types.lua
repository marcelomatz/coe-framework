---@meta
-- Contrato público de coe_handling para LuaLS. Não é carregado pelo servidor. Ver docs/ANNOTATIONS.md.

---@class CoeTyreState
---@field compound string `street`, `sport`, `performance`, `slick`, `all_terrain`, `offroad` ou `drift`
---@field fittedAtMeters number Quilometragem do veículo (m) quando os pneus foram montados
---@field wear number 0 = novo, 1 = no limite

---@class exports_coe_handling
local exports_coe_handling = {}

---@param vehicleId number
---@return CoeTyreState|nil
function exports_coe_handling:GetTyre(vehicleId) end

--- Monta pneus novos (zera o desgaste). Apenas resources em `WriterResources`.
---@param vehicleId number
---@param compound string
---@return true|string result `true` ou código de erro (`forbidden`, `unknown_tyre`, `vehicle_not_found`, `not_ready`)
function exports_coe_handling:SetTyre(vehicleId, compound) end

---@return string[]
function exports_coe_handling:ListTyres() end

---@return string[]
function exports_coe_handling:ListClasses() end

--- Multiplicadores finais (perfil x pneu x desgaste) por campo de CHandlingData.
---@param vehicleId number
---@return table<string, number>|nil
function exports_coe_handling:GetModifiers(vehicleId) end

---@return boolean
function exports_coe_handling:IsReady() end
