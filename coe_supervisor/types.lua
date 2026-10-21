---@meta
-- Contrato público de coe_supervisor para LuaLS. Não é carregado pelo servidor. Ver docs/ANNOTATIONS.md.
-- Exports server-only, restritos ao resource em `SupervisorConfig.Caller` (coe_admin).

---@class CoeSupervisorEntry
---@field name string
---@field category string
---@field critical boolean Reinício afeta muitos resources
---@field description string|nil
---@field dependencies string[]
---@field dependents string[]

---@class CoeSupervisorExports
local exports_coe_supervisor = {}

---Resources gerenciados, com categoria, dependências e dependentes.
---@return CoeSupervisorEntry[]|nil list `nil` para chamador não autorizado
function exports_coe_supervisor:List() end

---Reinicia o resource e os dependentes na ordem correta (com `refresh` antes dos starts).
---@param name string
---@param requester integer|nil Jogador que pediu (auditoria)
---@return boolean ok
---@return string|nil errorCode
function exports_coe_supervisor:Restart(name, requester) end
