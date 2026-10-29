---@meta
-- Contrato público de coe_businesses para LuaLS. Não é carregado pelo servidor. Ver docs/ANNOTATIONS.md.
-- Exports server-only. Multi-retorno se perde entre resources: erros voltam como { error = codigo }.
-- ACEs (padrões em config.lua): coe.businesses.write (Save/Seed/Delete/ClockIn), coe.businesses.clock (Clock/ClockOut),
-- coe.businesses.tablet (Tablet*), coe.businesses.permissions (RegisterPermissions), coe.businesses.payroll
-- (Salary/Payroll), coe.businesses.admin (DutySummary), coe.businesses.extend (RegisterTab/RegisterProvider).

---@class CoeBusinessesExports
local exports_coe_businesses = {}

---@class CoeBusinessesError
---@field error string `forbidden`, `not_ready`, `invalid_*`, `database_error`, ...

---@class CoeBusinessAccess
---@field owner boolean
---@field staff boolean
---@field partner boolean
---@field canClock boolean
---@field canWork boolean

-- Registro -----------------------------------------------------------------------------------------------------

---@return boolean ready
function exports_coe_businesses:IsReady() end

---Categorias de negócio de `BusinessesConfig.Categories`.
---@return table categories
function exports_coe_businesses:Categories() end

---Esquema das regras configuráveis por negócio (`BusinessesConfig.Rules`).
---@return table schema
function exports_coe_businesses:RuleSchema() end

---Negócios cadastrados (opcionalmente de uma categoria). Vazio antes do `IsReady`.
---@param category string|nil
---@return table[] businesses
function exports_coe_businesses:List(category) end

---@param id string
---@return table|nil business
function exports_coe_businesses:Get(id) end

---Cria ou atualiza um negócio (área, pontos, dono, equipe, cargos). ACE `coe.businesses.write`.
---@param raw table
---@param by string|integer|nil Autor (auditoria)
---@return table|CoeBusinessesError business
function exports_coe_businesses:Save(raw, by) end

---Cria o negócio só se ainda não existir (seed de pacotes, ex.: lojas do coe_shops). ACE `coe.businesses.write`.
---@param raw table
---@return table|CoeBusinessesError business
function exports_coe_businesses:Seed(raw) end

---@param id string
---@param by string|integer|nil
---@return true|CoeBusinessesError result
function exports_coe_businesses:Delete(id, by) end

-- Ponto ---------------------------------------------------------------------------------------------------------

---Marca o jogador de ponto. ACE `coe.businesses.write`.
---@param source integer
---@param characterId string|integer
---@param businessId string
---@param at vector3|table|nil Posição (conferida contra a área do negócio)
---@param atStation boolean|nil Ponto batido numa estação
---@return true|CoeBusinessesError result `unknown_business`, `already_on_duty`, `on_duty_elsewhere`, `outside_area`
function exports_coe_businesses:ClockIn(source, characterId, businessId, at, atStation) end

---Encerra o ponto do jogador. ACE `coe.businesses.write` ou `coe.businesses.clock`.
---@param source integer
---@param reason string|nil
---@return true|CoeBusinessesError result `not_on_duty`
function exports_coe_businesses:ClockOut(source, reason) end

---Fluxo completo de bater/encerrar ponto numa estação (validações, notificação, auditoria). ACE `coe.businesses.clock`.
---@param source integer
---@param businessId string
---@param stationId string
---@return { ok: true }|CoeBusinessesError result
function exports_coe_businesses:Clock(source, businessId, stationId) end

---@param businessId string
---@param characterId string|integer
---@return boolean onDuty
function exports_coe_businesses:IsOnDuty(businessId, characterId) end

---Contagem de quem está de ponto. ACE `coe.businesses.admin`.
---@return { total: integer, byBusiness: table<string, integer> } summary
function exports_coe_businesses:DutySummary() end

---Negócio em que o jogador está de ponto agora.
---@param source integer
---@return string|nil businessId
function exports_coe_businesses:CurrentDuty(source) end

-- Acesso, sócios e cargos -----------------------------------------------------------------------------------------

---Quem é o quê no negócio. Nada vaza entre negócios.
---@param businessId string
---@param characterId string|integer
---@return CoeBusinessAccess access
function exports_coe_businesses:Access(businessId, characterId) end

---@param businessId string
---@return { characterId: string|integer, name: string }[] partners
function exports_coe_businesses:Partners(businessId) end

---Quem responde pelas dívidas: o dono primeiro, depois os sócios. Vazio sem dono.
---@param businessId string
---@return (string|integer)[] characterIds
function exports_coe_businesses:Debtors(businessId) end

---Permissões de cargo conhecidas (`nome = rótulo`), incluindo as registradas por pacotes.
---@return table<string, string> permissions
function exports_coe_businesses:Permissions() end

---Registra permissões de cargo de um pacote. O prefixo é o nome do resource sem `coe_` (ex.: `police.arrest`).
---ACE `coe.businesses.permissions`.
---@param list { name: string, label: string }[] Até 64
---@return true|CoeBusinessesError result `invalid_permissions`
function exports_coe_businesses:RegisterPermissions(list) end

---@param businessId string
---@return table[] grades Nome, nível, salário e permissões de cada cargo
function exports_coe_businesses:Grades(businessId) end

---@param businessId string
---@param characterId string|integer
---@return table|nil grade `nil` se não é da equipe ou o negócio não tem cargos
function exports_coe_businesses:GradeOf(businessId, characterId) end

---O personagem pode exercer a permissão? O dono tem todas; a equipe, as do cargo (de ponto, salvo acesso remoto).
---@param businessId string
---@param characterId string|integer
---@param permission string Ex.: `business.funds`
---@param remoteOnly boolean|nil Exige acesso sem ponto batido
---@return boolean allowed
function exports_coe_businesses:Can(businessId, characterId, permission, remoteOnly) end

---Salário do cargo do personagem. ACE `coe.businesses.payroll` (sem ela, 0).
---@param businessId string
---@param characterId string|integer
---@return integer salary
function exports_coe_businesses:Salary(businessId, characterId) end

---Folha do negócio. ACE `coe.businesses.payroll` (sem ela, lista vazia).
---@param businessId string
---@return { characterId: string|integer, name: string, grade: string, salary: integer }[] payroll
function exports_coe_businesses:Payroll(businessId) end

-- Extensões e tablet ----------------------------------------------------------------------------------------------

---Registra uma aba no app do negócio. ACE `coe.businesses.extend`. O registro some quando o resource para.
---@param def table
---@return true|CoeBusinessesError result
function exports_coe_businesses:RegisterTab(def) end

---Provedor de dados das abas Frota (`fleet`: { list, setStaff? }) e Propriedades (`properties`: { list }).
---ACE `coe.businesses.extend`.
---@param kind 'fleet'|'properties'
---@param def table Nomes dos exports do seu resource
---@return true|CoeBusinessesError result
function exports_coe_businesses:RegisterProvider(kind, def) end

---Apps de negócio do jogador no tablet (um por negócio de que é dono ou da equipe). ACE `coe.businesses.tablet`.
---@param playerId integer
---@return table[] instances
function exports_coe_businesses:TabletInstances(playerId) end

---Ação do app `business` no tablet. `instance` é o negócio do app (nunca vem do payload). ACE `coe.businesses.tablet`.
---@param playerId integer
---@param appId 'business'
---@param action string
---@param payload table|nil
---@param instance string
---@return table result `{ ok = false, error = codigo }` em falha
function exports_coe_businesses:TabletCall(playerId, appId, action, payload, instance) end
