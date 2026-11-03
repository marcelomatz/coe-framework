# coe_mdt — API reference

> Generated from `coe_mdt/types.lua` by `tools/gen_reference.lua`. Do not edit by hand.

Generated from the exports registered in code; refine descriptions and types when editing each export.

## Exports

### `AccessLog(subject, limit)`

Access log for internal affairs (authorized resources only).

| Parameter | Type | Description |
|---|---|---|
| `subject` | `any` |  |
| `limit` | `any` |  |

**Returns**

- `any`

### `TabletCall(playerId, appId, action, payload)`

Single entry point: `coe_tablet:call` -> `TabletCall(playerId, appId, action, payload)`.

| Parameter | Type | Description |
|---|---|---|
| `playerId` | `any` |  |
| `appId` | `any` |  |
| `action` | `any` |  |
| `payload` | `any` |  |

**Returns**

- `any`
