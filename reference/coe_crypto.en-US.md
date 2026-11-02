# coe_crypto — API reference

> Generated from `coe_crypto/types.lua` by `tools/gen_reference.lua`. Do not edit by hand.

COE OS apps: TabletVisible/TabletCall (only coe_phone and coe_tablet) and ComputerCall (only coe_deepweb).

## Exports

### `IsReady()`

The network is loaded (migrations, exchange reserve, and quote).

**Returns**

- `boolean` `ready`

### `Price()`

Current exchange quote in dollars per whole coin.

**Returns**

- `integer` `price`

### `Balance(address)`

Balance of an address. Read access is unrestricted.

| Parameter | Type | Description |
|---|---|---|
| `address` | `string` |  |

**Returns**

- `integer|nil` `units` — `nil` if the address does not exist on the network

### `IsAddress(address)`

Checks whether the address format is valid (does not check whether it exists).

| Parameter | Type | Description |
|---|---|---|
| `address` | `string` |  |

**Returns**

- `boolean` `valid`

### `Format(units)`

Formats units with the currency symbol (e.g. `1,5000 NOX`).

| Parameter | Type | Description |
|---|---|---|
| `units` | `integer` |  |

**Returns**

- `string` `text`

### `MintMining(entries)`

Issues a mining round. Only `Mining.Callers` can call it, at most once per `Mining.TickMinutes`.

| Parameter | Type | Description |
|---|---|---|
| `entries` | `{` | address: string, hash: integer }[] |

**Returns**

- `CoeCryptoMintResult` `result`

### `ComputerCall(playerId, deviceKey, action, payload)`

Crypto app on a coe_deepweb computer. Only `ComputerHosts`; `deviceKey` is the device key (`laptop:<serial>`, etc.).

| Parameter | Type | Description |
|---|---|---|
| `playerId` | `integer` |  |
| `deviceKey` | `string` |  |
| `action` | `string` |  |
| `payload` | `table\|nil` |  |

**Returns**

- `table` `result` — `{ ok, ... }` or `{ ok = false, error }`

### `HeldWallets(playerId, deviceKey)`

Wallets with a key available on `deviceKey` (and in the character's inventory), with their balances. Only `Escrow.Callers`.

| Parameter | Type | Description |
|---|---|---|
| `playerId` | `integer` |  |
| `deviceKey` | `string` |  |

**Returns**

- `table|nil` `wallets` — `{ { address, label, source, balance } }`

### `EscrowLock(playerId, deviceKey, from, amount, memo)`

Locks `amount` (plus the network fee) from wallet `from` in the marketplace escrow. The key must be available. Only `Escrow.Callers`.

| Parameter | Type | Description |
|---|---|---|
| `playerId` | `integer` |  |
| `deviceKey` | `string` |  |
| `from` | `string` |  |
| `amount` | `integer` |  |
| `memo` | `string\|nil` |  |

**Returns**

- `table` `result` — `{ ok, txId }` or `{ ok = false, error }`

### `EscrowRelease(to, amount, memo)`

Releases `amount` from escrow to `to`, with no network fee. Only `Escrow.Callers`.

| Parameter | Type | Description |
|---|---|---|
| `to` | `string` |  |
| `amount` | `integer` |  |
| `memo` | `string\|nil` |  |

**Returns**

- `table` `result` — `{ ok, txId }` or `{ ok = false, error }`

### `ReserveAddress()`

Address of the exchange reserve (receives marketplace fees and payments to NPC suppliers).

**Returns**

- `string` `address`

### `AdminOverview()`

Administrative overview of settings, live quote, network summary, top wallets, and recent transactions. Only `coe_admin`.

**Returns**

- `table` `result` — `{ available = true, ready, settings, defaults, market, summary, topWallets, recentTx }` or `{ error }`

### `AdminInspect(address)`

Inspects a wallet by address (balance, creator, devices with keys, and history). Only `coe_admin`.

| Parameter | Type | Description |
|---|---|---|
| `address` | `string` |  |

**Returns**

- `table` `result` — `{ wallet, devices, history }` or `{ error }`

### `AdminSaveSettings(raw)`

Validates and persists editable coe_crypto settings and applies them in memory. Only `coe_admin`.

| Parameter | Type | Description |
|---|---|---|
| `raw` | `table` |  |

**Returns**

- `boolean|table` `result` — `true` or `{ error }`

### `AdminResetSettings()`

Restores settings to the defaults in `config.lua`. Only `coe_admin`.

**Returns**

- `boolean|table` `result` — `true` or `{ error }`

### `AdminSetPrice(price)`

Immediately sets the exchange quote in dollars per whole coin. Only `coe_admin`.

| Parameter | Type | Description |
|---|---|---|
| `price` | `integer` |  |

**Returns**

- `boolean|table` `result` — `true` or `{ error }`

### `TabletVisible(playerId, appId)`

Crypto app on the tablet: visible when installed on the device.

| Parameter | Type | Description |
|---|---|---|
| `playerId` | `integer` |  |
| `appId` | `string` |  |

**Returns**

- `boolean` `visible`

### `TabletCall(playerId, appId, action, payload)`

Actions for the Crypto app on the tablet.

| Parameter | Type | Description |
|---|---|---|
| `playerId` | `integer` |  |
| `appId` | `string` |  |
| `action` | `string` |  |
| `payload` | `table\|nil` |  |

**Returns**

- `table` `result` — `{ ok, data }` or `{ ok = false, error }`

## Types

```lua
---@class CoeCryptoMintResult
---@field ok boolean
---@field error string|nil `forbidden|not_ready|too_soon|invalid_entries|database_error`
---@field total integer|nil Units issued in the round
---@field payouts table<string, integer>|nil Address -> units
```
