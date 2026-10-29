---@meta
-- Contrato público de coe_hud para LuaLS. Não é carregado pelo cliente. Ver docs/ANNOTATIONS.md.
-- Todos os exports são client-side.

---@class CoeHudExports
local exports_coe_hud = {}

---Esconde ou mostra o HUD por motivo. Use o nome do seu resource como motivo; o HUD só volta quando nenhum motivo
---restar. Também disponível pelo evento local `coe_hud:setHidden`.
---@param reason string Motivo (ex.: `GetCurrentResourceName()`)
---@param hidden boolean
---@return boolean ok `false` para motivo vazio ou não-string
function exports_coe_hud:SetHidden(reason, hidden) end

---Algum resource está escondendo o HUD agora?
---@return boolean hidden
function exports_coe_hud:IsHidden() end

---Mostra ou esconde a logo do servidor (preferência salva do jogador).
---@param visible boolean
---@return boolean visible Estado final da logo
function exports_coe_hud:SetLogoVisible(visible) end

---A logo está visível pela preferência do jogador?
---@return boolean visible
function exports_coe_hud:IsLogoVisible() end

---Alterna a logo (mesmo efeito do comando `/logo`).
---@return boolean visible Estado depois de alternar
function exports_coe_hud:ToggleLogo() end
