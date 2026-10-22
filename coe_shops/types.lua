---@meta
-- Contrato público de coe_shops para LuaLS. Não é carregado pelo servidor. Ver docs/ANNOTATIONS.md.
-- Exports server-only. A vitrine usa o evento coe_shops:request (pedido/resposta) e não faz parte do contrato.

---@class CoeShopsShelf
---@field quantity integer Unidades na prateleira
---@field price integer|nil Preço definido pelo dono (nil = preço de tabela)

---@class CoeShopsExports
local exports_coe_shops = {}

---Migrações aplicadas e negócios das lojas criados.
---@return boolean ready
function exports_coe_shops:IsReady() end

---Prateleira de uma loja de jogador, por produto. nil para loja da staff (estoque infinito) ou loja desconhecida.
---Base dos carregamentos de abastecimento (fase 4).
---@param storeId string Id da loja (= id do negócio)
---@return table<string,CoeShopsShelf>|nil shelves
function exports_coe_shops:GetShelves(storeId) end

---É uma loja do coe_shops (o id do negócio é o id da loja)? Usado pelo app do negócio para mostrar a aba Loja.
---@param businessId string
---@return boolean store
function exports_coe_shops:IsStore(businessId) end

---Aba Loja do app do negócio no tablet. Só o coe_businesses chama (o acesso ao app já foi conferido lá).
---payload.op: `overview` (prateleira, preços, vendas e caixa) ou `price` (`productId`, `price`; `false` volta à tabela).
---Abastecer e retirar ficam no balcão. Erros: `forbidden`, `not_ready`, `not_a_store`, `unknown_action`, `invalid_price`.
---@param playerId integer
---@param characterId string
---@param businessId string
---@param payload table
---@return table result
function exports_coe_shops:BusinessTablet(playerId, characterId, businessId, payload) end

---Registra um meio de pagamento do resource chamador (ACE coe.shops.payments). O registro some quando ele para.
---def: { id, label, kind = 'instant'|'pin'|'device', charge, refund, options?, client? (device), order? }, nomes de
---exports do próprio resource. Erros: `forbidden`, `invalid_method`, `method_taken`, `too_many_methods`.
---@param def table
---@return boolean|table result true ou { error }
function exports_coe_shops:RegisterPaymentMethod(def) end
