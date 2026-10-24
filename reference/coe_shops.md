# coe_shops — referência da API

> Gerado de `coe_shops/types.lua` por `tools/gen_reference.lua`. Não edite à mão.

Exports server-only. A vitrine usa o evento coe_shops:request (pedido/resposta) e não faz parte do contrato.

## Exports

### `IsReady()`

Migrações aplicadas e negócios das lojas criados.

**Retorno**

- `boolean` `ready`

### `GetShelves(storeId)`

Prateleira de uma loja de jogador, por produto. nil para loja da staff (estoque infinito) ou loja desconhecida. Base dos carregamentos de abastecimento (fase 4).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `storeId` | `string` | Id da loja (= id do negócio) |

**Retorno**

- `table<string,CoeShopsShelf>|nil` `shelves`

### `IsStore(businessId)`

É uma loja do coe_shops (o id do negócio é o id da loja)? Usado pelo app do negócio para mostrar a aba Loja.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `businessId` | `string` |  |

**Retorno**

- `boolean` `store`

### `BusinessTablet(playerId, characterId, businessId, payload)`

Aba Loja do app do negócio no tablet. Só o coe_businesses chama (o acesso ao app já foi conferido lá). payload.op: `overview` (prateleira, preços, vendas e caixa) ou `price` (`productId`, `price`; `false` volta à tabela). Abastecer e retirar ficam no balcão. Erros: `forbidden`, `not_ready`, `not_a_store`, `unknown_action`, `invalid_price`.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `playerId` | `integer` |  |
| `characterId` | `string` |  |
| `businessId` | `string` |  |
| `payload` | `table` |  |

**Retorno**

- `table` `result`

### `RegisterPaymentMethod(def)`

Registra um meio de pagamento do resource chamador (ACE coe.shops.payments). O registro some quando ele para. def: { id, label, kind = 'instant'|'pin'|'device', charge, refund, options?, client? (device), order? }, nomes de exports do próprio resource. Erros: `forbidden`, `invalid_method`, `method_taken`, `too_many_methods`.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `def` | `table` |  |

**Retorno**

- `boolean|table` `result` — true ou { error }

## Tipos

```lua
---@class CoeShopsShelf
---@field quantity integer Unidades na prateleira
---@field price integer|nil Preço definido pelo dono (nil = preço de tabela)
```

