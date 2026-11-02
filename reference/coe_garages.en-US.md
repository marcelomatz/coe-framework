# coe_garages — API reference

> Generated from `coe_garages/types.lua` by `tools/gen_reference.lua`. Do not edit by hand.

Generated from the exports registered in code; refine descriptions and types when editing each export.

## Exports

### `AddBusinessFleet(businessId, model, staff)`

Fleet purchased by a business resource (`FleetResources`, e.g. coe_fuel): creates the vehicle at the business's first business garage and, when `staff` is true, grants access to the team. Returns the record (`{ id, plate, ... }`) or `{ error }`.

| Parameter | Type | Description |
|---|---|---|
| `businessId` | `any` |  |
| `model` | `any` |  |
| `staff` | `any` |  |

**Returns**

- `any`

### `AddFleetVehicle(garageId, model)`

Server export `AddFleetVehicle` (`server/main.lua`).

| Parameter | Type | Description |
|---|---|---|
| `garageId` | `any` |  |
| `model` | `any` |  |

**Returns**

- `any`

### `BusinessFleet(businessId)`

Server export `BusinessFleet` (`server/main.lua`).

| Parameter | Type | Description |
|---|---|---|
| `businessId` | `any` |  |

**Returns**

- `any`

### `DeleteGarage(garageId)`

Server export `DeleteGarage` (`server/main.lua`).

| Parameter | Type | Description |
|---|---|---|
| `garageId` | `any` |  |

**Returns**

- `any`

### `ListFleet(garageId)`

Server export `ListFleet` (`server/main.lua`).

| Parameter | Type | Description |
|---|---|---|
| `garageId` | `any` |  |

**Returns**

- `any`

### `ListGarages()`

Server export `ListGarages` (`server/main.lua`).

**Returns**

- `any`

### `RemoveFleetVehicle(garageId, vehicleId)`

Server export `RemoveFleetVehicle` (`server/main.lua`).

| Parameter | Type | Description |
|---|---|---|
| `garageId` | `any` |  |
| `vehicleId` | `any` |  |

**Returns**

- `any`

### `SaveGarage(raw)`

Server export `SaveGarage` (`server/main.lua`).

| Parameter | Type | Description |
|---|---|---|
| `raw` | `any` |  |

**Returns**

- `any`

### `SetFleetStaffAccess(businessId, vehicleId, enabled)`

Server export `SetFleetStaffAccess` (`server/main.lua`).

| Parameter | Type | Description |
|---|---|---|
| `businessId` | `any` |  |
| `vehicleId` | `any` |  |
| `enabled` | `any` |  |

**Returns**

- `any`

### `TabletCall(playerId, appId, action)`

Server export `TabletCall` (`server/main.lua`).

| Parameter | Type | Description |
|---|---|---|
| `playerId` | `any` |  |
| `appId` | `any` |  |
| `action` | `any` |  |

**Returns**

- `any`
