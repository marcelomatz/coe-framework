---@meta
-- Contrato público de coe_ui para LuaLS. Não é carregado pelo servidor. Ver docs/ANNOTATIONS.md.

---@alias CoeAccent 'theme'|'lime'|'cyan'|'amber'|'rose'|'violet'

---@class CoeThemeOption
---@field name string
---@field label string

---@class CoeUiExports
local exports_coe_ui = {}

---Tema ativo. Server: tema padrão; client: tema recebido (`nil` antes do primeiro envio).
---@return string|nil name
function exports_coe_ui:GetTheme() end

---Temas disponíveis e o atual. Server.
---@return { current: string, options: CoeThemeOption[] }
function exports_coe_ui:GetThemes() end

---Define o tema padrão do servidor e avisa todos os clientes. Server; só `UiConfig.Caller` (coe_admin).
---@param name string
---@return true|string result `true` ou `forbidden`, `invalid_theme`
function exports_coe_ui:SetTheme(name) end

---Cor escolhida pelo jogador (`theme` = usar o padrão do servidor). Client.
---@return CoeAccent
function exports_coe_ui:GetAccent() end

---Define a cor do jogador, grava em KVP e dispara `coe_ui:accentChanged`. Client.
---@param name CoeAccent
function exports_coe_ui:SetAccent(name) end
