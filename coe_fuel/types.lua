---@meta
-- Contrato público de coe_fuel para LuaLS. Não é carregado pelo servidor. Ver docs/ANNOTATIONS.md.
-- Exports server-only. Bombas e galão usam o evento coe_fuel:request (pedido/resposta); o consumo usa
-- coe_fuel:init e coe_fuel:report. O tanque fica no state bag `coe:fuel` do veículo.

---@class CoeFuelSummary
---@field liters number Litros no tanque
---@field capacity integer Capacidade (litros)
---@field level number 0..1
---@field engine 'flex'|'diesel'|'none'
---@field main string|nil Combustível com mais litros
---@field tank table<string,number> Litros de cada combustível (regular, premium, ethanol, diesel)

---@class CoeFuelExports
local exports_coe_fuel = {}

---Migrações aplicadas e tanques dos postos lidos.
---@return boolean ready
function exports_coe_fuel:IsReady() end

---Tanque de um veículo registrado que está em uso (ou nil).
---@param vehicleId string|integer
---@return CoeFuelSummary|nil fuel
function exports_coe_fuel:GetFuel(vehicleId) end

---Efeito da mistura no motor para o coe_handling (força com etanol e aditivada). nil sem tanque em uso.
---@param vehicleId string|integer
---@return table|nil effects `{ mods = { fInitialDriveForce = number }, key = string }`
function exports_coe_fuel:GetEffects(vehicleId) end

---Tanques de um posto (postos de jogador vendem só o que está aqui), com nível e capacidade de cada combustível.
---@param stationId string
---@return table|nil tanks `{ business, tanks = { [combustível] = litros }, levels, capacities }`
function exports_coe_fuel:GetStationTanks(stationId) end

---É um posto do coe_fuel (o id do negócio do posto)? Usado pelo app do negócio para mostrar a aba Posto.
---@param businessId string
---@return boolean station
function exports_coe_fuel:IsStation(businessId) end

---Aba Posto do app do negócio no tablet. Só o coe_businesses chama (o acesso ao app já foi conferido lá).
---payload.op: `overview`, `price` (`fuel`, `price`; `false` volta à tabela), `upgradeTank` (`fuel`) ou `upgradeFleet`.
---Erros: `forbidden`, `not_ready`, `not_a_station`, `staff_station`, `invalid_price`, `not_enough_sales`,
---`insufficient_funds`, `max_level`, `no_fleet_garage`.
---@param playerId integer
---@param characterId string
---@param businessId string
---@param payload table
---@return table result
function exports_coe_fuel:BusinessTablet(playerId, characterId, businessId, payload) end
