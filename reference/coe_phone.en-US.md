# coe_phone — API reference

> Generated from `coe_phone/types.lua` by `tools/gen_reference.lua`. Do not edit by hand.

Generated from the exports registered in code; refine descriptions and types when editing each export.

## Exports

### `ActiveDevice(playerId)`

Device currently in use: `{ serial }` or nil plus an error. Apps that bind a session to a device (e.g. email) use its serial number: anyone who picks up an unlocked device also gets its sessions.

| Parameter | Type | Description |
|---|---|---|
| `playerId` | `any` |  |

**Returns**

- `any`

### `ActiveLine(playerId)`

SIM line (slot 1) on the phone currently in use: `{ number, display, holder }` or nil plus an error.

| Parameter | Type | Description |
|---|---|---|
| `playerId` | `any` |  |

**Returns**

- `any`

### `ConsumePayment(playerId, token, amount)`

Server export `ConsumePayment` (`server/main.lua`).

| Parameter | Type | Description |
|---|---|---|
| `playerId` | `any` |  |
| `token` | `any` |  |
| `amount` | `any` |  |

**Returns**

- `any`

### `NumberOf(characterId)`

Formatted number of the first SIM owned by the character; nil if they do not own one.

| Parameter | Type | Description |
|---|---|---|
| `characterId` | `any` |  |

**Returns**

- `any`

### `RequestPayment(request)`

In-person Wallet payment (e.g. at a coe_shops store counter): opens the phone if needed, displays the payment slip with the amount, and returns authorization. The requesting resource passes the token to its server, which consumes it with ConsumePayment (only callers in `Wallet.PaymentCallers`). Blocks the caller's thread until the player decides. `request`: `{ amount, label, note }`. Returns `{ token, cardId }` or `{ error }` (`cancelled`, `phone_unavailable`, `invalid_amount`).

| Parameter | Type | Description |
|---|---|---|
| `request` | `any` |  |

**Returns**

- `any`

### `ShopCharge(playerId, payment, amount, description)`

Phone Wallet payments at stores (`coe_shops:RegisterPaymentMethod`, method `wallet`): the store client calls this resource's RequestPayment export and sends the token; the charge consumes the token and posts the amount to the selected card's credit account.

| Parameter | Type | Description |
|---|---|---|
| `playerId` | `any` |  |
| `payment` | `any` |  |
| `amount` | `any` |  |
| `description` | `any` |  |

**Returns**

- `any`

### `ShopOptions()`

Server export `ShopOptions` (`server/main.lua`).

**Returns**

- `any`

### `ShopRefund(_, ref, amount, description)`

Server export `ShopRefund` (`server/main.lua`).

| Parameter | Type | Description |
|---|---|---|
| `_` | `any` |  |
| `ref` | `any` |  |
| `amount` | `any` |  |
| `description` | `any` |  |

**Returns**

- `any`

### `UpgradeStatus()`

Report from the latest upgrade from the basic resource (coe_supervisor displays it with the `coe_upgrades` command).

**Returns**

- `any`
