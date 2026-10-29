---@meta
-- Contrato público de coe_loadscreen para LuaLS. Não é carregado pelo cliente. Ver docs/ANNOTATIONS.md.
-- Todos os exports são client-side.

---@class CoeLoadscreenExports
local exports_coe_loadscreen = {}

---Informa se a tela de carregamento ainda está ativa no cliente.
---@return boolean isActive Retorna `true` se a tela de carregamento ainda estiver ativa
function exports_coe_loadscreen:IsActive() end

---Fecha imediatamente a tela de carregamento manual no cliente.
function exports_coe_loadscreen:Shutdown() end
