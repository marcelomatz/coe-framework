# coe_doors — API reference

> Generated from `coe_doors/types.lua` by `tools/gen_reference.lua`. Do not edit by hand.

Generated from the exports registered in code; refine descriptions and types when editing each export.

## Exports

### `CanAccess(playerId, id)`

Server export `CanAccess` (`server/main.lua`).

| Parameter | Type | Description |
|---|---|---|
| `playerId` | `any` |  |
| `id` | `any` |  |

**Returns**

- `any`

### `Delete(placeId)`

Server export `Delete` (`server/main.lua`).

| Parameter | Type | Description |
|---|---|---|
| `placeId` | `any` |  |

**Returns**

- `any`

### `IsLocked(id)`

API for other resources (robberies, events, business scripts). `id`: `"<place>:<door>"` for one door, or `"<place>"` for all doors at a location.

| Parameter | Type | Description |
|---|---|---|
| `id` | `any` |  |

**Returns**

- `any`

### `IsReady()`

Server export `IsReady` (`server/main.lua`).

**Returns**

- `any`

### `List()`

Server export `List` (`server/main.lua`).

**Returns**

- `any`

### `Save(raw)`

Server export `Save` (`server/main.lua`).

| Parameter | Type | Description |
|---|---|---|
| `raw` | `any` |  |

**Returns**

- `any`

### `SetLocked(id, locked)`

Server export `SetLocked` (`server/main.lua`).

| Parameter | Type | Description |
|---|---|---|
| `id` | `any` |  |
| `locked` | `any` |  |

**Returns**

- `any`

### `TabletCall(playerId, _, action, payload)`

Server export `TabletCall` (`server/main.lua`).

| Parameter | Type | Description |
|---|---|---|
| `playerId` | `any` |  |
| `_` | `any` |  |
| `action` | `any` |  |
| `payload` | `any` |  |

**Returns**

- `any`

### `TabletVisible(playerId)`

Server export `TabletVisible` (`server/main.lua`).

| Parameter | Type | Description |
|---|---|---|
| `playerId` | `any` |  |

**Returns**

- `any`
