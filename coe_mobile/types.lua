---@meta
-- Contrato público de coe_mobile para LuaLS. Não é carregado pelo servidor. Ver docs/ANNOTATIONS.md.
-- Exports server-only. A tela usa o evento coe_mobile:request (pedido/resposta) e não faz parte do contrato.

---@class CoeMobileStatus
---@field active boolean O telefone básico está atendendo (abre, liga e recebe mensagens)
---@field yieldedBy string|nil Resource que assumiu o telefone

---@class CoeMobileExports
local exports_coe_mobile = {}

---Um pacote com smartphone completo assume o telefone: o básico encerra as ligações, fecha as telas e para de abrir
---até o resource chamador parar. Só resources com a ACE `coe.mobile.yield`.
---Chame ao iniciar e de novo no `onResourceStart` do coe_mobile.
---@return true|{ error: string } result `forbidden`
function exports_coe_mobile:Yield() end

---Situação do telefone básico.
---@return CoeMobileStatus status
function exports_coe_mobile:Status() end

---Número do personagem no telefone básico (formato 555-0123), ou nil se ele ainda não usou o telefone.
---Não gera número. Chame de dentro de uma thread (consulta o banco).
---@param characterId string|integer
---@return string|nil number
function exports_coe_mobile:NumberOf(characterId) end
