# coe_banking — referência da API

> Gerado de `coe_banking/types.lua` por `tools/gen_reference.lua`. Não edite à mão.

Gerado a partir dos exports registrados no código; refine descrições e tipos ao mexer em cada export.

## Exports

### `AdminAccount(characterId)`

Export server `AdminAccount` (server/main.lua).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `characterId` | `any` |  |

**Retorno**

- `any`

### `AdminBusinessAccount(businessId, filter)`

Export server `AdminBusinessAccount` (server/business.lua).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `businessId` | `any` |  |
| `filter` | `any` |  |

**Retorno**

- `any`

### `AdminBusinessAccounts()`

Export server `AdminBusinessAccounts` (server/business.lua).

**Retorno**

- `any`

### `AdminBusinessAdjust(businessId, delta, note)`

Ajuste da staff no caixa: delta positivo credita, negativo debita (motivo admin_adjustment, com a observação).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `businessId` | `any` |  |
| `delta` | `any` |  |
| `note` | `any` |  |

**Retorno**

- `any`

### `AdminBusinessCardLimit(cardId, value)`

op: limit (value = limite diário, 0 = sem limite). Bloqueio, desbloqueio e validade usam AdminCard.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `cardId` | `any` |  |
| `value` | `any` |  |

**Retorno**

- `any`

### `AdminCard(cardId, action)`

action: block | unblock | extend (nova validade a partir de agora).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `cardId` | `any` |  |
| `action` | `any` |  |

**Retorno**

- `any`

### `AdminDecideRequest(requestId, decision)`

decision: { approve = bool, rate, installments, reason }. Aprovado: o valor cai no caixa do negócio e a dívida fica com o dono e os sócios de agora; as parcelas saem do caixa e, se faltar, o atraso pesa em todos.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `requestId` | `any` |  |
| `decision` | `any` |  |

**Retorno**

- `any`

### `AdminForgiveLoan(loanId)`

Export server `AdminForgiveLoan` (server/main.lua).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `loanId` | `any` |  |

**Retorno**

- `any`

### `AdminGrantLoan(characterId, input)`

input: { principal, rate (% total), installments, note }. O valor cai na conta; parcelas debitadas automaticamente.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `characterId` | `any` |  |
| `input` | `any` |  |

**Retorno**

- `any`

### `AdminLoanRequests()`

Fila de pedidos de empréstimo empresarial: pendentes e as últimas decisões.

**Retorno**

- `any`

### `AdminPoints(characterId, delta)`

Export server `AdminPoints` (server/main.lua).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `characterId` | `any` |  |
| `delta` | `any` |  |

**Retorno**

- `any`

### `AdminSaveTiers(list)`

Export server `AdminSaveTiers` (server/main.lua).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `list` | `any` |  |

**Retorno**

- `any`

### `AdminSetCredit(characterId, data)`

data: { tier, customLimit (número ou false), tierLocked }. Cria a conta de crédito se não existir.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `characterId` | `any` |  |
| `data` | `any` |  |

**Retorno**

- `any`

### `AdminTiers()`

Export server `AdminTiers` (server/main.lua).

**Retorno**

- `any`

### `BusinessTablet(playerId, characterId, businessId, payload)`

Export server `BusinessTablet` (server/business.lua).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `playerId` | `any` |  |
| `characterId` | `any` |  |
| `businessId` | `any` |  |
| `payload` | `any` |  |

**Retorno**

- `any`

### `CardPurchase(cardId, amount, description)`

Devolve { ok = true, points, available } ou { ok = false, error } (no_card, card_blocked, card_expired, no_credit, credit_late, credit_limit, busy).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `cardId` | `any` |  |
| `amount` | `any` |  |
| `description` | `any` |  |

**Retorno**

- `any`

### `CardRefund(cardId, amount, description)`

Export server `CardRefund` (server/main.lua).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `cardId` | `any` |  |
| `amount` | `any` |  |
| `description` | `any` |  |

**Retorno**

- `any`

### `PosCards(playerId)`

Export server `PosCards` (server/main.lua).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `playerId` | `any` |  |

**Retorno**

- `any`

### `PosPurchase(playerId, cardId, pin, amount, description)`

Export server `PosPurchase` (server/main.lua).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `playerId` | `any` |  |
| `cardId` | `any` |  |
| `pin` | `any` |  |
| `amount` | `any` |  |
| `description` | `any` |  |

**Retorno**

- `any`

### `ShopCharge(playerId, payment, amount, description)`

Export server `ShopCharge` (server/main.lua).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `playerId` | `any` |  |
| `payment` | `any` |  |
| `amount` | `any` |  |
| `description` | `any` |  |

**Retorno**

- `any`

### `ShopOptions(playerId)`

Maquininha nas lojas (registrada com coe_shops:RegisterPaymentMethod, meio `card`): opções são os cartões físicos ativos em mãos; a cobrança pede a senha. O chamador continua sendo a loja (Credit.PurchaseCallers).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `playerId` | `any` |  |

**Retorno**

- `any`

### `ShopRefund(_, ref, amount, description)`

Export server `ShopRefund` (server/main.lua).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `_` | `any` |  |
| `ref` | `any` |  |
| `amount` | `any` |  |
| `description` | `any` |  |

**Retorno**

- `any`

### `TabletCall(playerId, appId, action, payload)`

Chamado só pelo coe_tablet. Toda ação devolve o extrato atualizado em `bank`.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `playerId` | `any` |  |
| `appId` | `any` |  |
| `action` | `any` |  |
| `payload` | `any` |  |

**Retorno**

- `any`

### `TabletVisible(playerId, appId)`

App Banco visível no aparelho: só para o coe_tablet e o coe_phone, com o banco pronto.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `playerId` | `integer` |  |
| `appId` | `string` | `bank` |

**Retorno**

- `boolean` `visible`

### `WalletCards(cardIds)`

Situação atual dos cartões de uma carteira (até 10 ids): { ok, cards = { [id] = view } }; cartão inexistente fica de fora.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `cardIds` | `any` |  |

**Retorno**

- `any`

### `WalletEligible(playerId)`

Cartões que o jogador pode pôr na carteira: os físicos ativos no inventário e o virtual ativo da própria conta.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `playerId` | `any` |  |

**Retorno**

- `any`

### `WalletIssueVirtual(playerId)`

Pede um cartão virtual pela carteira (mesma regra da agência): devolve o cartão emitido.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `playerId` | `any` |  |

**Retorno**

- `any`

### `WalletLink(playerId, cardId, pin)`

Vincula um cartão: virtual da própria conta, ou físico em mãos com a senha (erros contam como no caixa eletrônico).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `playerId` | `any` |  |
| `cardId` | `any` |  |
| `pin` | `any` |  |

**Retorno**

- `any`

