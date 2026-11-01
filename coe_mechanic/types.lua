---@meta
-- Contrato público de coe_mechanic para LuaLS. Não é carregado pelo servidor. Ver docs/ANNOTATIONS.md.

---@class CoePartStatus
---@field part string
---@field wear number 0 = novo, 1 = no limite
---@field installedAtMeters number
---@field condition string `ok`, `warn` ou `critical`

---@class exports_coe_mechanic
local exports_coe_mechanic = {}

--- Ações do tablet de oficina (`scan`, `replace`). Só aceita o `coe_tablet`.
---@param source number
---@param appId string
---@param action string
---@param payload table
---@return table result `{ ok = true, vehicle = ... }` ou `{ ok = false, error = string }`
function exports_coe_mechanic:TabletCall(source, appId, action, payload) end

---@param vehicleId number
---@return CoePartStatus[]|nil
function exports_coe_mechanic:Inspect(vehicleId) end

--- Apenas resources em `WriterResources`.
---@param vehicleId number
---@param part string
---@return true|string result `true` ou `forbidden`, `unknown_part`, `vehicle_not_found`, `not_ready`
function exports_coe_mechanic:ReplacePart(vehicleId, part) end

--- Troca todas as peças em aviso/crítico.
---@param vehicleId number
---@return true|string
function exports_coe_mechanic:ServiceVehicle(vehicleId) end

--- Corrige a quilometragem (metros); auditado por `coe_vehicles`.
---@param vehicleId number
---@param meters number
---@return true|string
function exports_coe_mechanic:AdjustMileage(vehicleId, meters) end

--- Desgaste extra nas peças (só `WearResources`, hoje o coe_fuel). meters > 0 envelhece; < 0 desconta o extra já
--- acumulado (nunca deixa a peça mais nova que a troca). Zera quando a peça é trocada.
---@param vehicleId number|string
---@param meters integer
---@param parts string[]
---@return true|string
function exports_coe_mechanic:AddWear(vehicleId, meters, parts) end

--- Efeitos das peças no handling, usados por `coe_handling`.
---@param vehicleId number
---@param mileage number|nil
---@return { mods: table<string, number>, key: string }|nil
function exports_coe_mechanic:GetEffects(vehicleId, mileage) end

---@return string[]
function exports_coe_mechanic:ListParts() end

---@return boolean
function exports_coe_mechanic:IsReady() end

---@param shopId string
---@return string|nil characterId Dono da oficina (personagem), ou nil sem dono
function exports_coe_mechanic:GetShopOwner(shopId) end

---@class CoeAppearance
---@field colors table|nil `primary`, `secondary`, `pearl`, `wheel`, `interior`, `dashboard` (índices GTA), `primaryRgb`/`secondaryRgb` ({r,g,b})
---@field mods table<string, number>|nil Tipo de mod (string) -> índice; -1 remove
---@field toggles table<string, boolean>|nil `turbo`, `tyreSmoke`, `xenon`
---@field livery number|nil -1 remove
---@field tint number|nil
---@field plateIndex number|nil
---@field wheelType number|nil
---@field xenonColor number|nil
---@field neon { sides: boolean[]|nil, rgb: number[]|nil }|nil
---@field extras table<string, boolean>|nil

---@param vehicleId number
---@return CoeAppearance|nil
function exports_coe_mechanic:GetAppearance(vehicleId) end

--- Orçamento (proporcional ao valor do catálogo) de um patch, sem gravar.
---@param vehicleId number
---@param patch CoeAppearance
---@return { total: number, lines: table[] }|string result Orçamento ou código de erro
function exports_coe_mechanic:QuoteAppearance(vehicleId, patch) end

--- Mescla o patch na aparência salva e aplica no veículo. Apenas `WriterResources`; a cobrança é do chamador.
---@param vehicleId number
---@param patch CoeAppearance
---@return true|string result `true` ou `forbidden`, `invalid_*`, `vehicle_not_found`, `not_ready`
function exports_coe_mechanic:SetAppearance(vehicleId, patch) end

---Lista de oficinas configuradas.
---@return table<string, table> shops
function exports_coe_mechanic:GetShops() end

---Opções de customização e mods disponíveis para a entidade do veículo. Client.
---@param vehicle integer Entidade do veículo
---@return table|nil options
function exports_coe_mechanic:GetVehicleOptions(vehicle) end
