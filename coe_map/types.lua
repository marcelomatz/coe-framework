---@meta
-- Contrato público de coe_map para LuaLS. Não é carregado pelo servidor. Ver docs/ANNOTATIONS.md.
-- Exports client-only. Evento local: `coe_map:changed` (mode, scale).

---@alias CoeMapMode 'mini'|'extended'

---@class CoeMapExports
local exports_coe_map = {}

---Modo atual do minimapa.
---@return CoeMapMode
function exports_coe_map:GetMode() end

---Abre o mapa completo do GTA para o jogador marcar um destino.
function exports_coe_map:OpenFull() end
