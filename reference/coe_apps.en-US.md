# coe_apps — API reference

> Generated from `coe_apps/types.lua` by `tools/gen_reference.lua`. Do not edit by hand.

Generated from the exports registered in code; refine descriptions and types when editing each export.

## Exports

### `ClaimPhoto(playerId, token)`

Stores a photo uploaded by the device (upload token) and returns `{ ok, image }` (`media:<id>` or an HTTPS URL).

| Parameter | Type | Description |
|---|---|---|
| `playerId` | `any` |  |
| `token` | `any` |  |

**Returns**

- `any`

### `DeletePhoto(image)`

Server export `DeletePhoto` (`server/main.lua`).

| Parameter | Type | Description |
|---|---|---|
| `image` | `any` |  |

**Returns**

- `any`

### `HasApp(playerId, appId, device)`

Other resources with store apps (e.g. coe_amzg) use this to check whether the character installed the app on the device.

| Parameter | Type | Description |
|---|---|---|
| `playerId` | `any` |  |
| `appId` | `any` |  |
| `device` | `any` |  |

**Returns**

- `any`

### `PhotoData(id)`

Returns the contents of a photo stored in the database (`media:<id>`).

| Parameter | Type | Description |
|---|---|---|
| `id` | `any` |  |

**Returns**

- `any`

### `StorePhoto(image)`

Client export `StorePhoto` (`client/camera.lua`).

| Parameter | Type | Description |
|---|---|---|
| `image` | `any` |  |

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

### `TakePhoto()`

Client export `TakePhoto` (`client/camera.lua`).

**Returns**

- `any`
