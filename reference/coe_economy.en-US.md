# coe_economy — API Reference

> Generated from `coe_economy/types.lua` by `tools/gen_reference.lua`. Do not edit by hand.

Server-only exports. The invoking resource (`GetInvokingResource`) must be in `EconomyConfig.AllowedResources`
or hold the `coe.economy.money` ACE (`add_ace resource.<name> coe.economy.money allow`). Values are positive integers >= 1 and
<= `MaxAmount`; character IDs are positive integers (numeric or string); `reason` conforms to `[a-z0-9_]{1,32}` and
`reference` to `[A-Za-z0-9_:-]{0,64}`. Standard error codes: `forbidden`, `not_ready`, `invalid_amount`,
`invalid_character`, `invalid_reason`, `invalid_reference`, `insufficient_funds`, `balance_limit`, `database_error`.

## Exports

### `IsReady()`

Returns whether economy persistence is ready and caller is authorized.

**Returns**

- `boolean` `ready`

### `Summary()`

Returns total economy metrics (total accounts and aggregate balance). Requires `coe.economy.admin` ACE.

**Returns**

- `{ accounts: integer, total: integer }|CoeEconomyError` `summary`

### `GetBalance(characterId)`

Current balance of character (account is provisioned with `StartingBalance` on first access).

| Parameter | Type | Description |
|---|---|---|
| `characterId` | `integer\|string` | Character identifier |

**Returns**

- `integer|nil` `balance`
- `string|nil` `errorCode`

### `Credit(characterId, amount, reason, reference)`

Credits money to character account respecting `MaxBalance` ceiling. Audited (`money_credited`).

| Parameter | Type | Description |
|---|---|---|
| `characterId` | `integer\|string` | Character identifier |
| `amount` | `integer` | Amount to credit |
| `reason` | `string` | Transaction reason slug |
| `reference` | `string\|nil` | Tracking reference |

**Returns**

- `true|nil` `ok`
- `string|nil` `errorCode`

### `Debit(characterId, amount, reason, reference)`

Debits money from character account; rejects if insufficient funds (strict atomic DB transaction). Audited (`money_debited`).

| Parameter | Type | Description |
|---|---|---|
| `characterId` | `integer\|string` | Character identifier |
| `amount` | `integer` | Amount to debit |
| `reason` | `string` | Transaction reason slug |
| `reference` | `string\|nil` | Tracking reference |

**Returns**

- `true|nil` `ok`
- `string|nil` `errorCode`

### `Transfer(fromId, toId, amount, reason, reference)`

Transfers money between two characters in a single atomic transaction. Audited (`money_transferred`).

| Parameter | Type | Description |
|---|---|---|
| `fromId` | `integer\|string` | Origin character ID |
| `toId` | `integer\|string` | Destination character ID |
| `amount` | `integer` | Amount to transfer |
| `reason` | `string` | Transaction reason slug |
| `reference` | `string\|nil` | Tracking reference |

**Returns**

- `true|nil` `ok`
- `string|nil` `errorCode` — Includes `same_account`

### `Ledger(characterId, limit)`

Returns character transaction ledger, ordered newest first.

| Parameter | Type | Description |
|---|---|---|
| `characterId` | `integer\|string` | Character identifier |
| `limit` | `integer\|nil` | Limit 1-100 (defaults to 20) |

**Returns**

- `CoeEconomyLedgerRow[]|CoeEconomyError` `rows`

### `LedgerStats(characterId, days, ignored)`

Calculates ledger income and inflow metrics for the specified time window.

| Parameter | Type | Description |
|---|---|---|
| `characterId` | `integer\|string` | Character identifier |
| `days` | `integer\|nil` | Days lookback 1-365 (defaults to 7) |
| `ignored` | `string[]\|nil` | Reason codes excluded from inflow totals |

**Returns**

- `{ firstAt: integer|nil, inflow: integer }|CoeEconomyError` `stats`

### `SocietyBalance(businessId)`

Returns the available balance of a society / business account.

| Parameter | Type | Description |
|---|---|---|
| `businessId` | `string` | Business identifier |

**Returns**

- `integer|CoeEconomyError` `balance`

### `SocietyLedger(businessId, limit)`

Returns transaction history for a society account.

| Parameter | Type | Description |
|---|---|---|
| `businessId` | `string` | Business identifier |
| `limit` | `integer\|nil` | Limit 1-100 (defaults to 20) |

**Returns**

- `table[]|CoeEconomyError` `rows`

### `SocietyDeposit(businessId, characterId, amount)`

Deposits personal character funds into the society account. Restricted to business owner or staff (`not_staff`).

| Parameter | Type | Description |
|---|---|---|
| `businessId` | `string` | Business identifier |
| `characterId` | `integer\|string` | Character identifier |
| `amount` | `integer` | Deposit amount |

**Returns**

- `true|CoeEconomyError` `result`

### `SocietyWithdraw(businessId, characterId, amount)`

Withdraws society funds to character personal balance. Requires `business.funds` grade permission (owner has all).

| Parameter | Type | Description |
|---|---|---|
| `businessId` | `string` | Business identifier |
| `characterId` | `integer\|string` | Character identifier |
| `amount` | `integer` | Withdrawal amount |

**Returns**

- `true|CoeEconomyError` `result`

### `SocietyCredit(businessId, amount, reason)`

Administrative deposit without character association. Requires `coe.economy.admin` ACE.

| Parameter | Type | Description |
|---|---|---|
| `businessId` | `string` | Business identifier |
| `amount` | `integer` | Credit amount |
| `reason` | `string\|nil` | Reason code (defaults to `admin_adjustment`) |

**Returns**

- `true|CoeEconomyError` `result`

### `SocietyCollect(businessId, amount, reason)`

Revenue intake from customer payments (e.g. shop retail checkout). Requires `SocietyCollectors` or `coe.economy.society.collect` ACE.

| Parameter | Type | Description |
|---|---|---|
| `businessId` | `string` | Business identifier |
| `amount` | `integer` | Revenue amount |
| `reason` | `string` | Collection reason |

**Returns**

- `true|CoeEconomyError` `result`

### `SocietyCharge(businessId, amount, reason, reference)`

Direct society business expense without character account (e.g. commercial rent). Requires `SocietyPayers` or `coe.economy.society.pay` ACE.

| Parameter | Type | Description |
|---|---|---|
| `businessId` | `string` | Business identifier |
| `amount` | `integer` | Expense amount |
| `reason` | `string` | Charge reason |
| `reference` | `string\|nil` | Tracking reference |

**Returns**

- `true|CoeEconomyError` `result`

### `BankSocietyPay(businessId, characterId, amount, reason, reference)`

Transfers money from society account to a character personal account.

| Parameter | Type | Description |
|---|---|---|
| `businessId` | `string` | Business identifier |
| `characterId` | `integer\|string` | Destination character ID |
| `amount` | `integer` | Payment amount |
| `reason` | `string` | Payment reason |
| `reference` | `string\|nil` | Tracking reference |

**Returns**

- `true|CoeEconomyError` `result`

### `BankSocietyDeposit(businessId, characterId, amount, reason, reference)`

Transfers money from a character personal account into the society account.

| Parameter | Type | Description |
|---|---|---|
| `businessId` | `string` | Business identifier |
| `characterId` | `integer\|string` | Origin character ID |
| `amount` | `integer` | Deposit amount |
| `reason` | `string` | Deposit reason |
| `reference` | `string\|nil` | Tracking reference |

**Returns**

- `true|CoeEconomyError` `result`

### `BankSocietyDebit(businessId, amount, reason, reference)`

Outflow from society account without destination character (cash withdrawal, corporate card expense).

| Parameter | Type | Description |
|---|---|---|
| `businessId` | `string` | Business identifier |
| `amount` | `integer` | Outflow amount |
| `reason` | `string` | Outflow reason |
| `reference` | `string\|nil` | Tracking reference |

**Returns**

- `true|CoeEconomyError` `result`

### `BankSocietyCredit(businessId, amount, reason, reference)`

Inflow into society account without origin character (cash deposit, reversal credit).

| Parameter | Type | Description |
|---|---|---|
| `businessId` | `string` | Business identifier |
| `amount` | `integer` | Inflow amount |
| `reason` | `string` | Inflow reason |
| `reference` | `string\|nil` | Tracking reference |

**Returns**

- `true|CoeEconomyError` `result`

### `BankSocietyTransfer(fromId, toId, amount, reason, reference)`

B2B corporate transfer between two business accounts.

| Parameter | Type | Description |
|---|---|---|
| `fromId` | `string` | Origin business ID |
| `toId` | `string` | Destination business ID |
| `amount` | `integer` | Transfer amount |
| `reason` | `string` | Transfer reason |
| `reference` | `string\|nil` | Tracking reference |

**Returns**

- `true|CoeEconomyError` `result`

### `BankSocietyLedger(businessId, filter)`

Filtered corporate transaction ledger with period aggregate totals.

| Parameter | Type | Description |
|---|---|---|
| `businessId` | `string` | Business identifier |
| `filter` | `{ direction: 'in'\|'out'\|nil, reasons: string[]\|nil, days: integer\|nil, limit: integer\|nil, beforeId: integer\|nil }\|nil` | Ledger query filter |

**Returns**

- `{ rows: table[], totals: table }|CoeEconomyError` `page`

### `RunPayroll(businessId)`

Pays grade salary to characters currently on duty from the society account; if funds are insufficient, skips without incurring debt. Requires `coe.economy.admin` ACE or banker role. Emits local event `coe_economy:payrollPaid`.

| Parameter | Type | Description |
|---|---|---|
| `businessId` | `string` | Business identifier |

**Returns**

- `CoeEconomyPayrollSummary|CoeEconomyError` `summary`

## Types

```lua
---@class CoeEconomyError
---@field error string Error code string

---@class CoeEconomyLedgerRow
---@field delta integer Positive = credit, negative = debit
---@field reason string
---@field reference string
---@field created_at any

---@class CoeEconomyPayrollSummary
---@field paid table[] Successful payouts (`characterId`, `salary`)
---@field total integer Total amount paid out
---@field skipped table[] Skipped employees (`characterId`, `salary`, `reason`: `off_duty` | `insufficient_funds`)
```
