---@meta
-- Contrato público de coe_vehicle_catalog para LuaLS. Não é carregado pelo servidor. Ver docs/ANNOTATIONS.md.

---@class CoeVehicleInfo
---@field model string Minúsculo
---@field name string|nil
---@field brand string|nil
---@field class string `compacts`, `sedans`, `super`, ... ou `unknown` (addon sem classe)
---@field type string `automobile`, `bike`, `boat`, `heli`, `plane`, `submarine`, `trailer`, `train`
---@field seats number|nil
---@field isAddon boolean
---@field resource string|nil Resource do addon
---@field handlingId string|nil
---@field hasHandling boolean
---@field price number Override ou preço da classe
---@field stock number|nil nil = ilimitado
---@field category string Override ou a classe
---@field hidden boolean

---@class CoeVehicleFilter
---@field type string|nil
---@field class string|nil
---@field category string|nil
---@field brand string|nil
---@field addon boolean|nil
---@field search string|nil Trecho do modelo, nome ou marca
---@field minPrice number|nil
---@field maxPrice number|nil
---@field includeHidden boolean|nil
---@field limit integer|nil Padrão 200, máximo 500

---@class CoeVehicleOverride
---@field price integer|nil
---@field stock integer|nil
---@field category string|nil
---@field hidden boolean|nil

---@class CoeVehicleCatalogIssue
---@field level string `warn` ou `error`
---@field code string `duplicate_model`, `handling_missing`, `replaces_native`, ...
---@field model string|nil
---@field resource string|nil

---@class CoeVehicleCatalogExports
local exports_coe_vehicle_catalog = {}

---@param model string
---@return CoeVehicleInfo|nil
function exports_coe_vehicle_catalog:GetVehicleInfo(model) end

---@param filter CoeVehicleFilter|nil
---@return CoeVehicleInfo[]
function exports_coe_vehicle_catalog:ListVehicles(filter) end

---Valores escalares do handling.meta carregado (ex.: `fMass`), ou nil.
---@param model string
---@return table<string, number>|nil
function exports_coe_vehicle_catalog:GetBaseHandling(model) end

---@return CoeVehicleCatalogIssue[]
function exports_coe_vehicle_catalog:GetIssues() end

---Mescla e grava um override. Somente `WriterResources`.
---@param model string
---@param fields CoeVehicleOverride
---@return true|string okOrError `forbidden`, `unknown_model`, `invalid_price`, ...
function exports_coe_vehicle_catalog:SetOverride(model, fields) end

---Remove o override do modelo. Somente `WriterResources`.
---@param model string
---@return true|string okOrError
function exports_coe_vehicle_catalog:ClearOverride(model) end

---Relê os resources de veículo. Somente `WriterResources`.
---@return true|string okOrError
function exports_coe_vehicle_catalog:Rescan() end

---@return boolean ready
function exports_coe_vehicle_catalog:IsReady() end
