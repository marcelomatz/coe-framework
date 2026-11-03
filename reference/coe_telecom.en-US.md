# coe_telecom — API reference

> Generated from `coe_telecom/types.lua` by `tools/gen_reference.lua`. Do not edit by hand.

Generated from the exports registered in code; refine descriptions and types when editing each export.

## Exports

### `Authorize(number, kind, holder)`

The phone checks before placing a call or sending a message through line `number` (the device's SIM). `holder`: SIM owner (nil = anonymous). Returns `{ ok, maxSeconds }` or `{ ok = false, error }`.

| Parameter | Type | Description |
|---|---|---|
| `number` | `any` |  |
| `kind` | `any` |  |
| `holder` | `any` |  |

**Returns**

- `any`

### `Charge(number, kind, seconds, peer, holder)`

Completed usage (call ended or message sent). `seconds` is used only for voice and video.

| Parameter | Type | Description |
|---|---|---|
| `number` | `any` |  |
| `kind` | `any` |  |
| `seconds` | `any` |  |
| `peer` | `any` |  |
| `holder` | `any` |  |

**Returns**

- `any`

### `LineOf(number)`

Line summary for a number, for use by other resources.

| Parameter | Type | Description |
|---|---|---|
| `number` | `any` |  |

**Returns**

- `any`

### `TabletCall(playerId, appId, action, payload)`

Server export `TabletCall` (`server/main.lua`).

| Parameter | Type | Description |
|---|---|---|
| `playerId` | `any` |  |
| `appId` | `any` |  |
| `action` | `any` |  |
| `payload` | `any` |  |

**Returns**

- `any`

### `TabletVisible(playerId, appId)`

Server export `TabletVisible` (`server/main.lua`).

| Parameter | Type | Description |
|---|---|---|
| `playerId` | `any` |  |
| `appId` | `any` |  |

**Returns**

- `any`
