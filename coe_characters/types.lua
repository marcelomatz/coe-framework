---@meta
-- Contrato público de coe_characters para LuaLS. Não é carregado pelo cliente. Ver docs/ANNOTATIONS.md.
-- Todos os exports são client-side.

---@class CoeCharactersExports
local exports_coe_characters = {}

---Verifica se a interface de seleção de personagem está aberta no cliente.
---@return boolean isOpen Retorna `true` se a seleção estiver aberta.
function exports_coe_characters:IsOpen() end

---Fecha a interface de seleção de personagem e destrói a cena 3D atual.
function exports_coe_characters:CloseSelection() end
