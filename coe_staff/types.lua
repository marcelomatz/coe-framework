---@meta
-- Contrato público de coe_staff para LuaLS. Não é carregado pelo servidor. Ver docs/ANNOTATIONS.md.
-- Exports server-only. A tela usa os eventos coe_staff:open / coe_staff:request e não faz parte do contrato.

---@class CoeStaffStatus
---@field active boolean O painel básico está atendendo
---@field yieldedBy string|nil Resource que assumiu o painel

---@class CoeStaffExports
local exports_coe_staff = {}

---Um pacote com painel completo assume: o básico fecha e para de abrir até o resource chamador parar.
---Só resources com a ACE `coe.staff.yield`. Chame ao iniciar e de novo no `onResourceStart` do coe_staff.
---@return true|{ error: string } result `forbidden`
function exports_coe_staff:Yield() end

---Situação do painel básico.
---@return CoeStaffStatus status
function exports_coe_staff:Status() end

---Registra um provedor de garagens para administração pelo painel staff (aba Garagens).
---@param provider table List(), Save(raw), Delete(id) e `kinds` (tipos editáveis, padrão { 'public' })
---@return boolean ok
---@return string|nil errorCode `invalid_provider`
function exports_coe_staff:RegisterGaragesProvider(provider) end

---Registra o provedor das estações de aluguel (aba Aluguel). Normalmente o coe_rentals.
---@param provider table List(), Save(raw), Delete(id) e, opcional, Catalog()
---@return boolean ok
---@return string|nil errorCode `invalid_provider`
function exports_coe_staff:RegisterRentalsProvider(provider) end
