---@meta
-- Tipagens públicas de coe_rentals para LuaLS.

---@class RentalVehicleDef
---@field model string
---@field label string
---@field category string
---@field price number
---@field deposit number

---@class RentalStationDef
---@field id string
---@field label string
---@field coords table
---@field spawn table
---@field returnZone table
---@field blip table

---@class ActiveRentalInfo
---@field entity integer
---@field netId integer
---@field plate string
---@field model string
---@field deposit number
---@field stationId string
---@field rentedAt integer

---@class CoeRentalsExports
local exports_coe_rentals = {}

---Retorna o aluguel ativo de um personagem ou nil.
---@param characterId string
---@return ActiveRentalInfo|nil
function exports_coe_rentals:GetActiveRental(characterId) end
