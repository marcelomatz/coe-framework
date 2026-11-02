# coe_mail — API reference

> Generated from `coe_mail/types.lua` by `tools/gen_reference.lua`. Do not edit by hand.

Generated from the exports registered in code; refine descriptions and types when editing each export.

## Exports

### `Send(from, to, subject, body)`

System email (e.g. notifications from other resources). `from`: `{ address, name }`; `to`: an address or list. Returns `{ ok, bounced }` or `{ ok = false, error }`.

| Parameter | Type | Description |
|---|---|---|
| `from` | `any` |  |
| `to` | `any` |  |
| `subject` | `any` |  |
| `body` | `any` |  |

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
