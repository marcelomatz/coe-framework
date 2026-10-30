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
---@field enabled boolean
---@field ped table { x, y, z, h, model? } atendente (NPC) e balcão
---@field spawns table[] pontos de retirada { x, y, z, h } (1 a 8); o veículo sai no primeiro livre
---@field returnZone table { x, y, z, radius } zona de devolução
---@field vehicles string[] modelos oferecidos (vazio: todo o catálogo)
---@field blip table { enabled, sprite, color, scale }

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

---Estações cadastradas. Só `AdminResources`/ACE `coe.rentals.admin` (outros recebem lista vazia).
---@return RentalStationDef[]
function exports_coe_rentals:ListStations() end

---Cria ou atualiza uma estação. Só `AdminResources`/ACE `coe.rentals.admin`.
---@param raw RentalStationDef
---@return RentalStationDef|table station a estação salva ou { error = código }
function exports_coe_rentals:SaveStation(raw) end

---Remove uma estação. Só `AdminResources`/ACE `coe.rentals.admin`.
---@param stationId string
---@return boolean|table ok `true` ou { error = código }
function exports_coe_rentals:DeleteStation(stationId) end

---Catálogo de veículos do aluguel (config.lua).
---@return RentalVehicleDef[]
function exports_coe_rentals:Catalog() end
