---@meta
-- Contrato público de coe_workpad para LuaLS. Não é carregado pelo servidor. Ver docs/ANNOTATIONS.md.
-- Exports server-only. A tela usa os eventos coe_workpad:open / coe_workpad:call e não faz parte do contrato.
-- Apps de outros resources respondem por TabletCall(playerId, appId, action, payload, instance) e, com instâncias,
-- TabletInstances(playerId); a interface registra-se com window.CoeTablet.register(id, render(container, api)).

---@class CoeWorkpadStatus
---@field active boolean O tablet básico está atendendo (abre pelo item, tecla e comando)
---@field yieldedBy string|nil Resource que assumiu o tablet

---@class CoeWorkpadExports
local exports_coe_workpad = {}

---Um pacote com tablet completo assume: o básico fecha as telas e para de abrir até o resource chamador parar.
---Só resources com a ACE `coe.workpad.yield`. Chame ao iniciar e de novo no `onResourceStart` do coe_workpad.
---@return true|{ error: string } result `forbidden`
function exports_coe_workpad:Yield() end

---Situação do tablet básico.
---@return CoeWorkpadStatus status
function exports_coe_workpad:Status() end
