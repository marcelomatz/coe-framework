# coe_phone — referência da API

> Gerado de `coe_phone/types.lua` por `tools/gen_reference.lua`. Não edite à mão.

Gerado a partir dos exports registrados no código; refine descrições e tipos ao mexer em cada export.

## Exports

### `ActiveDevice(playerId)`

Aparelho que o jogador está usando: { serial } ou nil + erro. Apps que prendem a sessão ao aparelho (ex.: e-mail) usam o número de série: quem pega o aparelho desbloqueado pega as sessões junto.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `playerId` | `any` |  |

**Retorno**

- `any`

### `ActiveLine(playerId)`

Linha do chip (slot 1) no celular que o jogador está usando: { number, display, holder } ou nil + erro.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `playerId` | `any` |  |

**Retorno**

- `any`

### `ConsumePayment(playerId, token, amount)`

Export server `ConsumePayment` (server/main.lua).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `playerId` | `any` |  |
| `token` | `any` |  |
| `amount` | `any` |  |

**Retorno**

- `any`

### `NumberOf(characterId)`

Número (formatado) do primeiro chip de que o personagem é titular; nil se nenhum.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `characterId` | `any` |  |

**Retorno**

- `any`

### `RequestPayment(request)`

Pagamento presencial pela Carteira (ex.: balcão de loja do coe_shops): abre o celular se preciso, mostra a folha de pagamento com o valor e devolve a autorização. O resource que pediu entrega o token ao seu servidor, que o consome com ConsumePayment (só os de Wallet.PaymentCallers). Bloqueia a thread de quem chama até o jogador decidir. request: { amount, label, note }. Retorna { token, cardId } ou { error } (cancelled, phone_unavailable, invalid_amount).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `request` | `any` |  |

**Retorno**

- `any`

### `ShopCharge(playerId, payment, amount, description)`

Carteira do celular nas lojas (coe_shops:RegisterPaymentMethod, meio `wallet`): o client da loja chama o export RequestPayment deste resource e manda o token; a cobrança consome o token e lança no crédito do cartão escolhido.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `playerId` | `any` |  |
| `payment` | `any` |  |
| `amount` | `any` |  |
| `description` | `any` |  |

**Retorno**

- `any`

### `ShopOptions()`

Export server `ShopOptions` (server/main.lua).

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

### `UpgradeStatus()`

Relatório do último upgrade do básico (o coe_supervisor mostra no comando coe_upgrades).

**Retorno**

- `any`

