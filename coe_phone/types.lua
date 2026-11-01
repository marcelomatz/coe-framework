---@meta
-- Contrato público de coe_phone para LuaLS. Não é carregado pelo servidor.
-- Gerado a partir dos exports registrados no código; refine descrições e tipos ao mexer em cada export.

---@class CoePhoneExports
local exports_coe_phone = {}

---Aparelho que o jogador está usando: { serial } ou nil + erro. Apps que prendem a sessão ao aparelho (ex.: e-mail) usam o número de série: quem pega o aparelho desbloqueado pega as sessões junto.
---@param playerId any
---@return any
function exports_coe_phone:ActiveDevice(playerId) end

---Linha do chip (slot 1) no celular que o jogador está usando: { number, display, holder } ou nil + erro.
---@param playerId any
---@return any
function exports_coe_phone:ActiveLine(playerId) end

---Export server `ConsumePayment` (server/main.lua).
---@param playerId any
---@param token any
---@param amount any
---@return any
function exports_coe_phone:ConsumePayment(playerId, token, amount) end

---Número (formatado) do primeiro chip de que o personagem é titular; nil se nenhum.
---@param characterId any
---@return any
function exports_coe_phone:NumberOf(characterId) end

---Pagamento presencial pela Carteira (ex.: balcão de loja do coe_shops): abre o celular se preciso, mostra a folha de pagamento com o valor e devolve a autorização. O resource que pediu entrega o token ao seu servidor, que o consome com ConsumePayment (só os de Wallet.PaymentCallers). Bloqueia a thread de quem chama até o jogador decidir. request: { amount, label, note }. Retorna { token, cardId } ou { error } (cancelled, phone_unavailable, invalid_amount).
---@param request any
---@return any
function exports_coe_phone:RequestPayment(request) end

---Carteira do celular nas lojas (coe_shops:RegisterPaymentMethod, meio `wallet`): o client da loja chama o export RequestPayment deste resource e manda o token; a cobrança consome o token e lança no crédito do cartão escolhido.
---@param playerId any
---@param payment any
---@param amount any
---@param description any
---@return any
function exports_coe_phone:ShopCharge(playerId, payment, amount, description) end

---Export server `ShopOptions` (server/main.lua).
---@return any
function exports_coe_phone:ShopOptions() end

---Export server `ShopRefund` (server/main.lua).
---@param _ any
---@param ref any
---@param amount any
---@param description any
---@return any
function exports_coe_phone:ShopRefund(_, ref, amount, description) end

---Relatório do último upgrade do básico (o coe_supervisor mostra no comando coe_upgrades).
---@return any
function exports_coe_phone:UpgradeStatus() end
