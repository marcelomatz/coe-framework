---@meta
-- Contrato público de coe_banking para LuaLS. Não é carregado pelo servidor.
-- Gerado a partir dos exports registrados no código; refine descrições e tipos ao mexer em cada export.

---@class CoeBankingExports
local exports_coe_banking = {}

---Export server `AdminAccount` (server/main.lua).
---@param characterId any
---@return any
function exports_coe_banking:AdminAccount(characterId) end

---Export server `AdminBusinessAccount` (server/business.lua).
---@param businessId any
---@param filter any
---@return any
function exports_coe_banking:AdminBusinessAccount(businessId, filter) end

---Export server `AdminBusinessAccounts` (server/business.lua).
---@return any
function exports_coe_banking:AdminBusinessAccounts() end

---Ajuste da staff no caixa: delta positivo credita, negativo debita (motivo admin_adjustment, com a observação).
---@param businessId any
---@param delta any
---@param note any
---@return any
function exports_coe_banking:AdminBusinessAdjust(businessId, delta, note) end

---op: limit (value = limite diário, 0 = sem limite). Bloqueio, desbloqueio e validade usam AdminCard.
---@param cardId any
---@param value any
---@return any
function exports_coe_banking:AdminBusinessCardLimit(cardId, value) end

---action: block | unblock | extend (nova validade a partir de agora).
---@param cardId any
---@param action any
---@return any
function exports_coe_banking:AdminCard(cardId, action) end

---decision: { approve = bool, rate, installments, reason }. Aprovado: o valor cai no caixa do negócio e a dívida fica com o dono e os sócios de agora; as parcelas saem do caixa e, se faltar, o atraso pesa em todos.
---@param requestId any
---@param decision any
---@return any
function exports_coe_banking:AdminDecideRequest(requestId, decision) end

---Export server `AdminForgiveLoan` (server/main.lua).
---@param loanId any
---@return any
function exports_coe_banking:AdminForgiveLoan(loanId) end

---input: { principal, rate (% total), installments, note }. O valor cai na conta; parcelas debitadas automaticamente.
---@param characterId any
---@param input any
---@return any
function exports_coe_banking:AdminGrantLoan(characterId, input) end

---Fila de pedidos de empréstimo empresarial: pendentes e as últimas decisões.
---@return any
function exports_coe_banking:AdminLoanRequests() end

---Export server `AdminPoints` (server/main.lua).
---@param characterId any
---@param delta any
---@return any
function exports_coe_banking:AdminPoints(characterId, delta) end

---Export server `AdminSaveTiers` (server/main.lua).
---@param list any
---@return any
function exports_coe_banking:AdminSaveTiers(list) end

---data: { tier, customLimit (número ou false), tierLocked }. Cria a conta de crédito se não existir.
---@param characterId any
---@param data any
---@return any
function exports_coe_banking:AdminSetCredit(characterId, data) end

---Export server `AdminTiers` (server/main.lua).
---@return any
function exports_coe_banking:AdminTiers() end

---Export server `BusinessTablet` (server/business.lua).
---@param playerId any
---@param characterId any
---@param businessId any
---@param payload any
---@return any
function exports_coe_banking:BusinessTablet(playerId, characterId, businessId, payload) end

---Devolve { ok = true, points, available } ou { ok = false, error } (no_card, card_blocked, card_expired, no_credit, credit_late, credit_limit, busy).
---@param cardId any
---@param amount any
---@param description any
---@return any
function exports_coe_banking:CardPurchase(cardId, amount, description) end

---Export server `CardRefund` (server/main.lua).
---@param cardId any
---@param amount any
---@param description any
---@return any
function exports_coe_banking:CardRefund(cardId, amount, description) end

---Export server `PosCards` (server/main.lua).
---@param playerId any
---@return any
function exports_coe_banking:PosCards(playerId) end

---Export server `PosPurchase` (server/main.lua).
---@param playerId any
---@param cardId any
---@param pin any
---@param amount any
---@param description any
---@return any
function exports_coe_banking:PosPurchase(playerId, cardId, pin, amount, description) end

---Export server `ShopCharge` (server/main.lua).
---@param playerId any
---@param payment any
---@param amount any
---@param description any
---@return any
function exports_coe_banking:ShopCharge(playerId, payment, amount, description) end

---Maquininha nas lojas (registrada com coe_shops:RegisterPaymentMethod, meio `card`): opções são os cartões físicos ativos em mãos; a cobrança pede a senha. O chamador continua sendo a loja (Credit.PurchaseCallers).
---@param playerId any
---@return any
function exports_coe_banking:ShopOptions(playerId) end

---Export server `ShopRefund` (server/main.lua).
---@param _ any
---@param ref any
---@param amount any
---@param description any
---@return any
function exports_coe_banking:ShopRefund(_, ref, amount, description) end

---Chamado só pelo coe_tablet. Toda ação devolve o extrato atualizado em `bank`.
---@param playerId any
---@param appId any
---@param action any
---@param payload any
---@return any
function exports_coe_banking:TabletCall(playerId, appId, action, payload) end

---App Banco visível no aparelho: só para o coe_tablet e o coe_phone, com o banco pronto.
---@param playerId integer
---@param appId string `bank`
---@return boolean visible
function exports_coe_banking:TabletVisible(playerId, appId) end

---Situação atual dos cartões de uma carteira (até 10 ids): { ok, cards = { [id] = view } }; cartão inexistente fica de fora.
---@param cardIds any
---@return any
function exports_coe_banking:WalletCards(cardIds) end

---Cartões que o jogador pode pôr na carteira: os físicos ativos no inventário e o virtual ativo da própria conta.
---@param playerId any
---@return any
function exports_coe_banking:WalletEligible(playerId) end

---Pede um cartão virtual pela carteira (mesma regra da agência): devolve o cartão emitido.
---@param playerId any
---@return any
function exports_coe_banking:WalletIssueVirtual(playerId) end

---Vincula um cartão: virtual da própria conta, ou físico em mãos com a senha (erros contam como no caixa eletrônico).
---@param playerId any
---@param cardId any
---@param pin any
---@return any
function exports_coe_banking:WalletLink(playerId, cardId, pin) end
