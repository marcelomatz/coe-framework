---@meta
-- Contrato público de coetarget para LuaLS. Não é carregado pelo servidor. Ver docs/ANNOTATIONS.md.
-- Exports client-only. As opções ficam registradas por resource chamador e saem ao parar o resource.

---@class CoeTargetOption
---@field label string
---@field onSelect fun(entity: integer, option: CoeTargetOption, hit: vector3|nil)
---@field distance number|nil Alcance máximo (padrão `DefaultOptionDistance`)
---@field canInteract (fun(entity: integer, distance: number, hit: vector3|nil): boolean)|nil

---@alias CoeTargetGlobalType 'player'|'ped'|'vehicle'|'object'

---@class CoeTargetExports
local exports_coetarget = {}

---Opções para uma entidade específica.
---@param entity integer
---@param options CoeTargetOption[]
---@return boolean ok `false` se a entidade não existe ou as opções são inválidas
function exports_coetarget:AddTargetEntity(entity, options) end

---@param entity integer
function exports_coetarget:RemoveTargetEntity(entity) end

---Opções para todas as entidades de um modelo.
---@param model integer|string Hash ou nome do modelo
---@param options CoeTargetOption[]
---@return boolean ok
function exports_coetarget:AddTargetModel(model, options) end

---@param model integer|string
function exports_coetarget:RemoveTargetModel(model) end

---Opções para todas as entidades de um tipo.
---@param entityType CoeTargetGlobalType
---@param options CoeTargetOption[]
---@return boolean ok
function exports_coetarget:AddTargetGlobal(entityType, options) end

---@param entityType CoeTargetGlobalType
function exports_coetarget:RemoveTargetGlobal(entityType) end

---Opções para qualquer superfície mirada; `entity` é 0 quando a mira acerta o mapa.
---@param options CoeTargetOption[]
---@return boolean ok
function exports_coetarget:AddTargetSurface(options) end

function exports_coetarget:RemoveTargetSurface() end
