---@meta
-- Contrato público de coe_tablet para LuaLS. Não é carregado pelo servidor. Ver docs/ANNOTATIONS.md.

---@class CoeTabletApp
---@field id string
---@field label string
---@field script string

---@class CoeTabletProfile
---@field job string|nil
---@field label string|nil
---@field grade number
---@field apps CoeTabletApp[]

---@class CoeTabletExports
local exports_coe_tablet = {}

---Apps próprios do tablet (Ponto e Empregos livres, os do tablet de trabalho básico): o app aparece? Só o próprio
---coe_tablet chama (ownerCheck). `duty` precisa do coe_businesses; `freejobs`, do coe_jobs.
---@param playerId integer
---@param appId string `duty` ou `freejobs`
---@return boolean visible
function exports_coe_tablet:TabletVisible(playerId, appId) end

---Ações dos apps próprios do tablet. Só o próprio coe_tablet chama (a lista de apps e o acesso já foram conferidos).
---`duty`: `overview`, `clockOut`. `freejobs`: `list`. Erros: `forbidden`, `invalid_action`, `no_character`,
---`app_unavailable`, `not_on_duty`.
---@param playerId integer
---@param appId string
---@param action string
---@return table result `{ ok = true, data }` ou `{ ok = false, error }`
function exports_coe_tablet:TabletCall(playerId, appId, action) end
