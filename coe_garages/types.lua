---@meta
-- Contrato público de coe_garages para LuaLS. Não é carregado pelo servidor.
-- Gerado a partir dos exports registrados no código; refine descrições e tipos ao mexer em cada export.

---@class CoeGaragesExports
local exports_coe_garages = {}

---Frota comprada por um resource do negócio (FleetResources, ex.: coe_fuel): cria o veículo na primeira garagem de negócio do negócio e, se `staff`, libera para a equipe. Devolve o registro ({ id, plate, ... }) ou { error }.
---@param businessId any
---@param model any
---@param staff any
---@return any
function exports_coe_garages:AddBusinessFleet(businessId, model, staff) end

---Export server `AddFleetVehicle` (server/main.lua).
---@param garageId any
---@param model any
---@return any
function exports_coe_garages:AddFleetVehicle(garageId, model) end

---Export server `BusinessFleet` (server/main.lua).
---@param businessId any
---@return any
function exports_coe_garages:BusinessFleet(businessId) end

---Export server `DeleteGarage` (server/main.lua).
---@param garageId any
---@return any
function exports_coe_garages:DeleteGarage(garageId) end

---Export server `ListFleet` (server/main.lua).
---@param garageId any
---@return any
function exports_coe_garages:ListFleet(garageId) end

---Export server `ListGarages` (server/main.lua).
---@return any
function exports_coe_garages:ListGarages() end

---Export server `RemoveFleetVehicle` (server/main.lua).
---@param garageId any
---@param vehicleId any
---@return any
function exports_coe_garages:RemoveFleetVehicle(garageId, vehicleId) end

---Export server `SaveGarage` (server/main.lua).
---@param raw any
---@return any
function exports_coe_garages:SaveGarage(raw) end

---Export server `SetFleetStaffAccess` (server/main.lua).
---@param businessId any
---@param vehicleId any
---@param enabled any
---@return any
function exports_coe_garages:SetFleetStaffAccess(businessId, vehicleId, enabled) end

---Export server `TabletCall` (server/main.lua).
---@param playerId any
---@param appId any
---@param action any
---@return any
function exports_coe_garages:TabletCall(playerId, appId, action) end
