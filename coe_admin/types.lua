---@meta
-- Contrato público de coe_admin para LuaLS. Não é carregado pelo servidor. Ver docs/ANNOTATIONS.md.
-- O painel não expõe exports: outros resources não chamam o coe_admin. A integração é no sentido contrário (o painel
-- consome os exports de coe_inventory, coe_businesses, coe_economy, coe_banking, coe_crypto...), e o acesso da staff é
-- por ACE: coe_admin.root, coe_admin.tools.all, coe_admin.tools.<módulo> e as coe.staff.* herdadas do coe_staff.
-- A tela usa eventos internos (NUI) que não fazem parte do contrato.

---@class CoeAdminExports
local exports_coe_admin = {}
