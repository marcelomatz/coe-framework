---@meta
-- Contrato público de coe_vehicles para LuaLS. Não é carregado pelo servidor. Ver docs/ANNOTATIONS.md.

---@class CoeVehicle
---@field id string
---@field ownerCharacterId string|nil
---@field model string
---@field plate string
---@field mileage number Metros inteiros
---@field state string `stored`, `out` ou `impounded`

---@class CoeVehicleCreate
---@field characterId string|nil Dono; sem dono = estoque
---@field model string
---@field plate string|nil Gerada pelo padrão se omitida
---@field mileage number|nil Metros iniciais (usados)

---@class CoeVehiclesExports
local exports_coe_vehicles = {}

---Cria um veículo registrado. Somente `WriterResources`.
---@param data CoeVehicleCreate
---@return CoeVehicle|string vehicleOrError Código de erro: `invalid_model`, `plate_taken`, `vehicle_limit_reached`, ...
function exports_coe_vehicles:Create(data) end

---@param vehicleId string
---@return CoeVehicle|string|nil
function exports_coe_vehicles:Get(vehicleId) end

---@param plate string
---@return CoeVehicle|string|nil
function exports_coe_vehicles:GetByPlate(plate) end

---@param characterId string
---@return CoeVehicle[]|string
function exports_coe_vehicles:ListByOwner(characterId) end

---Retorna a entidade FiveM do veículo se estiver spawnado no servidor.
---@param vehicleId string
---@return integer|nil entity
function exports_coe_vehicles:GetEntity(vehicleId) end

---Quilometragem em metros.
---@param vehicleId string
---@return number|string
function exports_coe_vehicles:GetMileage(vehicleId) end

---Corrige a quilometragem (grava na hora e audita). Somente `MileageEditors`.
---@param vehicleId string
---@param meters number
---@return true|string
function exports_coe_vehicles:SetMileage(vehicleId, meters) end

---Cria a entidade no mundo, fixa o veículo no registro e ativa o Mileage.
---@param vehicleId string
---@param x number
---@param y number
---@param z number
---@param heading number
---@param vehicleType string|nil
---@return number|string netIdOrError
function exports_coe_vehicles:Spawn(vehicleId, x, y, z, heading, vehicleType) end

---Grava a quilometragem, remove a entidade e marca o veículo como `stored`.
---@param vehicleId string
---@return true|string
function exports_coe_vehicles:Store(vehicleId) end

---@return boolean ready
function exports_coe_vehicles:IsReady() end

---O dono sempre tem a chave; as demais ficam em `coe_vehicle_keys`.
---@param characterId string
---@param vehicleId string
---@return boolean hasKey
function exports_coe_vehicles:HasKey(characterId, vehicleId) end

---Concede uma chave (ex.: concessionária). Somente `WriterResources`.
---@param vehicleId string
---@param characterId string
---@return true|string okOrError `already_owner`, `key_limit_reached`, `invalid_character_id`, ...
function exports_coe_vehicles:GiveKey(vehicleId, characterId) end

---Retira uma chave emprestada. Somente `WriterResources`.
---@param vehicleId string
---@param characterId string
---@return true|string okOrError
function exports_coe_vehicles:RevokeKey(vehicleId, characterId) end

---Personagens (além do dono) que têm a chave.
---@param vehicleId string
---@return string[]|nil characterIds
function exports_coe_vehicles:ListKeyHolders(vehicleId) end

---Transiciona atomicamente o estado do veículo. Somente `WriterResources`.
---@param vehicleId string
---@param expectedState string
---@param nextState string
---@return true|string okOrError
function exports_coe_vehicles:TransitionState(vehicleId, expectedState, nextState) end

---Altera a fase de manutenção de um veículo estacionado em garagem residencial/oficina. Somente `WriterResources`.
---@param vehicleId string
---@param expected string
---@param target string
---@return boolean ok
---@return string|nil errorCode
function exports_coe_vehicles:SetHousingVehiclePhase(vehicleId, expected, target) end

---Verifica se o veículo está estacionado fisicamente em garagem residencial. Somente `WriterResources`.
---@param vehicleId string
---@return boolean isHousing
function exports_coe_vehicles:IsHousingVehicle(vehicleId) end

---Retoma o estado de veículo estacionado em garagem residencial após manutenção. Somente `WriterResources`.
---@param vehicleId string
---@return boolean ok
---@return string|nil errorCode
function exports_coe_vehicles:ResumeHousingVehicle(vehicleId) end

---Recupera travas de manutenção pendentes após reinício. Somente `WriterResources`.
---@return boolean ok
---@return string|nil errorCode
function exports_coe_vehicles:RecoverHousingLocks() end
