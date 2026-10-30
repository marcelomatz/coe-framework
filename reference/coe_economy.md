# coe_economy — referência da API

> Gerado de `coe_economy/types.lua` por `tools/gen_reference.lua`. Não edite à mão.

Exports server-only. O chamador vem do runtime (GetInvokingResource) e precisa estar em `EconomyConfig.AllowedResources`
ou ter a ACE `coe.economy.money` (add_ace resource.<nome> coe.economy.money allow). Valores são inteiros >= 1 e
<= `MaxAmount`; ids de personagem são inteiros positivos (número ou string); `reason` é `[a-z0-9_]{1,32}` e
`reference` é `[A-Za-z0-9_:-]{0,64}`. Códigos de erro comuns: `forbidden`, `not_ready`, `invalid_amount`,
`invalid_character`, `invalid_reason`, `invalid_reference`, `insufficient_funds`, `balance_limit`, `database_error`.
Contas pessoais --------------------------------------------------------------------------------------------

## Exports

### `IsReady()`

Persistência pronta e chamador autorizado.

**Retorno**

- `boolean` `ready`

### `Summary()`

Totais da economia (contas e soma dos saldos). Exige também a ACE `coe.economy.admin`.

**Retorno**

- `{` `accounts:` — integer, total: integer }|CoeEconomyError summary

### `GetBalance(characterId)`

Saldo do personagem (a conta é criada com `StartingBalance` no primeiro acesso).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `characterId` | `integer\|string` |  |

**Retorno**

- `integer|nil` `balance`
- `string|nil` `errorCode`

### `Credit(characterId, amount, reason, reference)`

Credita na conta do personagem, respeitando o teto `MaxBalance`. Auditado (`money_credited`).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `characterId` | `integer\|string` |  |
| `amount` | `integer` |  |
| `reason` | `string` |  |
| `reference` | `string\|nil` |  |

**Retorno**

- `true|nil` `ok`
- `string|nil` `errorCode`

### `Debit(characterId, amount, reason, reference)`

Debita da conta do personagem; recusa sem saldo (transação estrita no banco). Auditado (`money_debited`).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `characterId` | `integer\|string` |  |
| `amount` | `integer` |  |
| `reason` | `string` |  |
| `reference` | `string\|nil` |  |

**Retorno**

- `true|nil` `ok`
- `string|nil` `errorCode`

### `Transfer(fromId, toId, amount, reason, reference)`

Transfere entre dois personagens numa única transação. Auditado (`money_transferred`).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `fromId` | `integer\|string` |  |
| `toId` | `integer\|string` |  |
| `amount` | `integer` |  |
| `reason` | `string` |  |
| `reference` | `string\|nil` |  |

**Retorno**

- `true|nil` `ok`
- `string|nil` `errorCode` — `same_account` além dos comuns

### `Ledger(characterId, limit)`

Extrato pessoal, mais recentes primeiro.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `characterId` | `integer\|string` |  |
| `limit` | `integer\|nil` | 1-100 (padrão 20) |

**Retorno**

- `CoeEconomyLedgerRow[]|CoeEconomyError` `rows`

### `LedgerStats(characterId, days, ignored)`

Estatísticas do extrato no período.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `characterId` | `integer\|string` |  |
| `days` | `integer\|nil` | 1-365 (padrão 7) |
| `ignored` | `string[]\|nil` | Motivos que não contam como entrada (até 20) |

**Retorno**

- `{` `firstAt:` — integer|nil, inflow: integer }|CoeEconomyError stats

### `SocietyBalance(businessId)`

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `businessId` | `string` |  |

**Retorno**

- `integer|CoeEconomyError` `balance`

### `SocietyLedger(businessId, limit)`

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `businessId` | `string` |  |
| `limit` | `integer\|nil` | 1-100 (padrão 20) |

**Retorno**

- `table[]|CoeEconomyError` `rows`

### `SocietyDeposit(businessId, characterId, amount)`

Depósito do saldo pessoal na sociedade. Só dono ou equipe do negócio (`not_staff`).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `businessId` | `string` |  |
| `characterId` | `integer\|string` |  |
| `amount` | `integer` |  |

**Retorno**

- `true|CoeEconomyError` `result`

### `SocietyWithdraw(businessId, characterId, amount)`

Saque da sociedade para o saldo pessoal. Exige a permissão de cargo `business.funds` (o dono tem todas).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `businessId` | `string` |  |
| `characterId` | `integer\|string` |  |
| `amount` | `integer` |  |

**Retorno**

- `true|CoeEconomyError` `result`

### `SocietyCredit(businessId, amount, reason)`

Aporte administrativo, sem personagem. Exige a ACE `coe.economy.admin`.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `businessId` | `string` |  |
| `amount` | `integer` |  |
| `reason` | `string\|nil` | Padrão `admin_adjustment` |

**Retorno**

- `true|CoeEconomyError` `result`

### `SocietyCollect(businessId, amount, reason)`

Repasse de receita já cobrada de um cidadão (ex.: venda da loja). Só `SocietyCollectors` ou ACE `coe.economy.society.collect`.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `businessId` | `string` |  |
| `amount` | `integer` |  |
| `reason` | `string` |  |

**Retorno**

- `true|CoeEconomyError` `result`

### `SocietyCharge(businessId, amount, reason, reference)`

Despesa do negócio sem personagem (ex.: aluguel). Só `SocietyPayers` ou ACE `coe.economy.society.pay`.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `businessId` | `string` |  |
| `amount` | `integer` |  |
| `reason` | `string` |  |
| `reference` | `string\|nil` |  |

**Retorno**

- `true|CoeEconomyError` `result`

### `BankSocietyPay(businessId, characterId, amount, reason, reference)`

Da sociedade para a conta de um personagem.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `businessId` | `string` |  |
| `characterId` | `integer\|string` |  |
| `amount` | `integer` |  |
| `reason` | `string` |  |
| `reference` | `string\|nil` |  |

**Retorno**

- `true|CoeEconomyError` `result`

### `BankSocietyDeposit(businessId, characterId, amount, reason, reference)`

Da conta de um personagem para a sociedade.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `businessId` | `string` |  |
| `characterId` | `integer\|string` |  |
| `amount` | `integer` |  |
| `reason` | `string` |  |
| `reference` | `string\|nil` |  |

**Retorno**

- `true|CoeEconomyError` `result`

### `BankSocietyDebit(businessId, amount, reason, reference)`

Saída sem conta de personagem do outro lado (saque em espécie, compra com cartão empresarial).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `businessId` | `string` |  |
| `amount` | `integer` |  |
| `reason` | `string` |  |
| `reference` | `string\|nil` |  |

**Retorno**

- `true|CoeEconomyError` `result`

### `BankSocietyCredit(businessId, amount, reason, reference)`

Entrada sem conta de personagem do outro lado (depósito em espécie, estorno).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `businessId` | `string` |  |
| `amount` | `integer` |  |
| `reason` | `string` |  |
| `reference` | `string\|nil` |  |

**Retorno**

- `true|CoeEconomyError` `result`

### `BankSocietyTransfer(fromId, toId, amount, reason, reference)`

Entre duas empresas.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `fromId` | `string` |  |
| `toId` | `string` |  |
| `amount` | `integer` |  |
| `reason` | `string` |  |
| `reference` | `string\|nil` |  |

**Retorno**

- `true|CoeEconomyError` `result`

### `BankSocietyLedger(businessId, filter)`

Extrato filtrado com totais do período.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `businessId` | `string` |  |
| `filter` | `{` | direction: 'in'\|'out'\|nil, reasons: string[]\|nil, days: integer\|nil, limit: integer\|nil, beforeId: integer\|nil }\|nil |

**Retorno**

- `{` `rows:` — table[], totals: table }|CoeEconomyError page

### `RunPayroll(businessId)`

Paga o salário do cargo a quem está de ponto, da conta da sociedade; sem saldo, não paga e não acumula dívida. Exige ACE `coe.economy.admin` ou ser banqueiro. Dispara o evento local `coe_economy:payrollPaid`.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `businessId` | `string` |  |

**Retorno**

- `CoeEconomyPayrollSummary|CoeEconomyError` `summary`

## Tipos

```lua
---@class CoeEconomyError
---@field error string Código de erro

---@class CoeEconomyLedgerRow
---@field delta integer Positivo = entrada, negativo = saída
---@field reason string
---@field reference string
---@field created_at any texto do banco (fuso do servidor MariaDB)
---@field at number|string segundos Unix (UNIX_TIMESTAMP), prefira este para exibir datas

---@class CoeEconomyPayrollSummary
---@field paid table[] Pagamentos feitos (`characterId`, `salary`)
---@field total integer Total pago
---@field skipped table[] Quem não recebeu (`characterId`, `salary`, `reason`: `off_duty` | `insufficient_funds`)
```

