---@meta
-- Contrato público de coe_bank para LuaLS. Não é carregado pelo servidor. Ver docs/ANNOTATIONS.md.
-- Exports server-only. A tela usa o evento coe_bank:request (pedido/resposta) e não faz parte do contrato.

---@class CoeBankStatus
---@field active boolean O banco básico está atendendo (agências, caixas e blips visíveis)
---@field yieldedBy string|nil Resource que assumiu o banco

---@class CoeBankExports
local exports_coe_bank = {}

---Um pacote com banco completo assume o atendimento: o banco básico esconde agências, caixas eletrônicos e blips e
---fecha as telas abertas até o resource chamador parar. Só resources com a ACE `coe.bank.yield`.
---Chame ao iniciar e de novo no `onResourceStart` do coe_bank.
---@return true|{ error: string } result `forbidden`
function exports_coe_bank:Yield() end

---Situação do banco básico.
---@return CoeBankStatus status
function exports_coe_bank:Status() end
