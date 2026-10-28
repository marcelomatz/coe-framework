---@meta
-- Contrato público de coe_garage para LuaLS. Não é carregado pelo servidor (fora do fxmanifest). Ver docs/ANNOTATIONS.md.

---@class CoeGarageSpot
---@field id string
---@field label string
---@field x number
---@field y number
---@field z number
---@field heading number
---@field radius number

---@class CoeGarageBlip
---@field enabled boolean
---@field sprite integer
---@field color integer
---@field scale number

---@class CoeGarage
---@field id string
---@field label string
---@field kind string
---@field enabled boolean
---@field spots CoeGarageSpot[]
---@field blip CoeGarageBlip

---@class CoeGarageExports
local exports_coe_garage = {}

---Informa se o subsistema de garagens está pronto e inicializado.
---@return boolean ready
function exports_coe_garage:IsReady() end

---Lista todas as garagens públicas cadastradas.
---@return CoeGarage[] garages
function exports_coe_garage:ListGarages() end

---Retorna uma garagem cadastrada pelo seu ID único.
---@param id string ID único da garagem
---@return CoeGarage|nil garage
function exports_coe_garage:GetGarage(id) end

---Retorna o ID da garagem onde o veículo está alocado/guardado.
---@param vehicleId string|integer ID do veículo
---@return string|nil garageId
function exports_coe_garage:GetVehicleGarage(vehicleId) end

---Salva ou atualiza uma garagem pública.
---@param data table Dados brutos da garagem
---@return CoeGarage|nil garage Dados sanitizados e salvos
---@return string|nil errorCode Código de erro caso falhe
function exports_coe_garage:SaveGarage(data) end

---Remove uma garagem cadastrada pelo seu ID único.
---@param id string ID único da garagem
---@return boolean|nil ok
---@return string|nil errorCode
function exports_coe_garage:DeleteGarage(id) end
