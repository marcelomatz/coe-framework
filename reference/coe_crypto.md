# coe_crypto — referência da API

> Gerado de `coe_crypto/types.lua` por `tools/gen_reference.lua`. Não edite à mão.

Apps do COE OS: TabletVisible/TabletCall (só coe_phone e coe_tablet) e ComputerCall (só coe_deepweb).

## Exports

### `IsReady()`

Rede carregada (migrações, reserva da corretora e cotação).

**Retorno**

- `boolean` `ready`

### `Price()`

Cotação atual da corretora em $ por moeda inteira.

**Retorno**

- `integer` `price`

### `Balance(address)`

Saldo de um endereço. Leitura livre.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `address` | `string` |  |

**Retorno**

- `integer|nil` `units` — `nil` se o endereço não existe na rede

### `IsAddress(address)`

Formato de endereço válido (não confere se existe).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `address` | `string` |  |

**Retorno**

- `boolean` `valid`

### `Format(units)`

Unidades formatadas com o símbolo (ex.: `1,5000 NOX`).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `units` | `integer` |  |

**Retorno**

- `string` `text`

### `MintMining(entries)`

Emissão de uma rodada de mineração. Só `Mining.Callers`, no máximo uma por `Mining.TickMinutes`.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `entries` | `{` | address: string, hash: integer }[] |

**Retorno**

- `CoeCryptoMintResult` `result`

### `ComputerCall(playerId, deviceKey, action, payload)`

App Cripto num computador do coe_deepweb. Só `ComputerHosts`; `deviceKey` é a chave do aparelho (`laptop:<serial>`...).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `playerId` | `integer` |  |
| `deviceKey` | `string` |  |
| `action` | `string` |  |
| `payload` | `table\|nil` |  |

**Retorno**

- `table` `result` — `{ ok, ... }` ou `{ ok = false, error }`

### `HeldWallets(playerId, deviceKey)`

Carteiras com chave à mão no aparelho `deviceKey` (e no inventário do personagem), com saldo. Só `Escrow.Callers`.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `playerId` | `integer` |  |
| `deviceKey` | `string` |  |

**Retorno**

- `table|nil` `wallets` — `{ { address, label, source, balance } }`

### `EscrowLock(playerId, deviceKey, from, amount, memo)`

Trava `amount` (mais a taxa da rede) da carteira `from` na custódia do mercado. Exige a chave à mão. Só `Escrow.Callers`.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `playerId` | `integer` |  |
| `deviceKey` | `string` |  |
| `from` | `string` |  |
| `amount` | `integer` |  |
| `memo` | `string\|nil` |  |

**Retorno**

- `table` `result` — `{ ok, txId }` ou `{ ok = false, error }`

### `EscrowRelease(to, amount, memo)`

Libera `amount` da custódia para `to`, sem taxa da rede. Só `Escrow.Callers`.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `to` | `string` |  |
| `amount` | `integer` |  |
| `memo` | `string\|nil` |  |

**Retorno**

- `table` `result` — `{ ok, txId }` ou `{ ok = false, error }`

### `ReserveAddress()`

Endereço da reserva da corretora (recebe taxas do mercado e pagamentos a fornecedores NPC).

**Retorno**

- `string` `address`

### `AdminOverview()`

Panorama administrativo das configurações, cotação ao vivo, resumo da rede, maiores carteiras e transações recentes. Só `coe_admin`.

**Retorno**

- `table` `result` — `{ available = true, ready, settings, defaults, market, summary, topWallets, recentTx }` ou `{ error }`

### `AdminInspect(address)`

Inspeciona uma carteira pelo endereço (saldo, criador, aparelhos com chave e extrato). Só `coe_admin`.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `address` | `string` |  |

**Retorno**

- `table` `result` — `{ wallet, devices, history }` ou `{ error }`

### `AdminSaveSettings(raw)`

Valida, persiste e aplica em memória as configurações editáveis do coe_crypto. Só `coe_admin`.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `raw` | `table` |  |

**Retorno**

- `boolean|table` `result` — `true` ou `{ error }`

### `AdminResetSettings()`

Restaura as configurações para os padrões de `config.lua`. Só `coe_admin`.

**Retorno**

- `boolean|table` `result` — `true` ou `{ error }`

### `AdminSetPrice(price)`

Fixa imediatamente a cotação da corretora em $ por moeda inteira. Só `coe_admin`.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `price` | `integer` |  |

**Retorno**

- `boolean|table` `result` — `true` ou `{ error }`

### `TabletVisible(playerId, appId)`

App Crypto do tablet: visível quando instalado no aparelho.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `playerId` | `integer` |  |
| `appId` | `string` |  |

**Retorno**

- `boolean` `visible`

### `TabletCall(playerId, appId, action, payload)`

Ações do app Crypto no tablet.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `playerId` | `integer` |  |
| `appId` | `string` |  |
| `action` | `string` |  |
| `payload` | `table\|nil` |  |

**Retorno**

- `table` `result` — `{ ok, data }` ou `{ ok = false, error }`

## Tipos

```lua
---@class CoeCryptoMintResult
---@field ok boolean
---@field error string|nil `forbidden|not_ready|too_soon|invalid_entries|database_error`
---@field total integer|nil Unidades emitidas na rodada
---@field payouts table<string, integer>|nil Endereço -> unidades
```

