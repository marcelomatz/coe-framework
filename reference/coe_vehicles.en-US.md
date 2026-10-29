# coe_vehicles — API Reference

> Generated from `coe_vehicles/types.lua` by `tools/gen_reference.lua`. Do not edit by hand.

## Exports

### `Create(data)`

Creates an authoritative vehicle record in MariaDB. Restricted to `WriterResources`.

| Parameter | Type | Description |
|---|---|---|
| `data` | `CoeVehicleCreate` | Creation payload attributes |

**Returns**

- `CoeVehicle|string` `vehicleOrError` — Vehicle object or error code: `invalid_model`, `plate_taken`, `vehicle_limit_reached`, ...

### `Get(vehicleId)`

Retrieves a vehicle record by its unique database ID.

| Parameter | Type | Description |
|---|---|---|
| `vehicleId` | `string` | Unique vehicle ID |

**Returns**

- `CoeVehicle|string|nil`

### `GetByPlate(plate)`

Retrieves a vehicle record by its license plate string.

| Parameter | Type | Description |
|---|---|---|
| `plate` | `string` | License plate text |

**Returns**

- `CoeVehicle|string|nil`

### `ListByOwner(characterId)`

Lists all vehicles owned by a specific character.

| Parameter | Type | Description |
|---|---|---|
| `characterId` | `string` | Owner character ID |

**Returns**

- `CoeVehicle[]|string`

### `GetEntity(vehicleId)`

Returns the server-side FiveM entity handle if the vehicle is currently spawned in the world.

| Parameter | Type | Description |
|---|---|---|
| `vehicleId` | `string` | Vehicle record ID |

**Returns**

- `integer|nil` `entity` — Entity handle or `nil` if not spawned

### `GetMileage(vehicleId)`

Returns the cumulative vehicle odometer reading in integer meters.

| Parameter | Type | Description |
|---|---|---|
| `vehicleId` | `string` | Vehicle record ID |

**Returns**

- `number|string` — Odometer in meters, or error code string

### `SetMileage(vehicleId, meters)`

Calibrates odometer reading (persists immediately with audit entry). Restricted to `MileageEditors`.

| Parameter | Type | Description |
|---|---|---|
| `vehicleId` | `string` | Vehicle record ID |
| `meters` | `number` | New mileage value in meters |

**Returns**

- `true|string` — `true` or error code string

### `Spawn(vehicleId, x, y, z, heading, vehicleType)`

Spawns vehicle entity into the world, registers it with tracking state, and begins mileage accumulation.

| Parameter | Type | Description |
|---|---|---|
| `vehicleId` | `string` | Vehicle record ID |
| `x` | `number` | World X coordinate |
| `y` | `number` | World Y coordinate |
| `z` | `number` | World Z coordinate |
| `heading` | `number` | Heading rotation (0-360) |
| `vehicleType` | `string\|nil` | Optional vehicle type category |

**Returns**

- `number|string` `netIdOrError` — Network ID integer or error code string

### `Store(vehicleId)`

Flushes pending odometer distance, despawns the world entity, and transitions vehicle state to `stored`.

| Parameter | Type | Description |
|---|---|---|
| `vehicleId` | `string` | Vehicle record ID |

**Returns**

- `true|string` — `true` or error code string

### `IsReady()`

Verifies if vehicle tables and migrations are ready for transactions.

**Returns**

- `boolean` `ready`

### `HasKey(characterId, vehicleId)`

Checks if a character holds digital key access. The owner inherently has key access; additional shared keys are queried from `coe_vehicle_keys`.

| Parameter | Type | Description |
|---|---|---|
| `characterId` | `string` | Character ID to check |
| `vehicleId` | `string` | Vehicle record ID |

**Returns**

- `boolean` `hasKey`

### `GiveKey(vehicleId, characterId)`

Grants a digital key to a borrower character. Restricted to `WriterResources`.

| Parameter | Type | Description |
|---|---|---|
| `vehicleId` | `string` | Vehicle record ID |
| `characterId` | `string` | Recipient character ID |

**Returns**

- `true|string` `okOrError` — `true` or error code: `already_owner`, `key_limit_reached`, `invalid_character_id`, ...

### `RevokeKey(vehicleId, characterId)`

Revokes a borrowed digital key. Restricted to `WriterResources`.

| Parameter | Type | Description |
|---|---|---|
| `vehicleId` | `string` | Vehicle record ID |
| `characterId` | `string` | Target character ID |

**Returns**

- `true|string` `okOrError`

### `ListKeyHolders(vehicleId)`

Lists all borrower character IDs (excluding the owner) holding digital keys to this vehicle.

| Parameter | Type | Description |
|---|---|---|
| `vehicleId` | `string` | Vehicle record ID |

**Returns**

- `string[]|nil` `characterIds`

## Types

```lua
---@class CoeVehicle
---@field id string Unique persistent vehicle UUID
---@field ownerCharacterId string|nil Owner character ID (nil if dealership stock)
---@field model string Vehicle model name
---@field plate string Unique license plate string
---@field mileage number Cumulative distance in meters
---@field state string Active status: `stored`, `out`, or `impounded`

---@class CoeVehicleCreate
---@field characterId string|nil Owner character ID; nil represents dealership stock
---@field model string Vehicle model name
---@field plate string|nil Custom plate (auto-generated if omitted)
---@field mileage number|nil Initial mileage in meters (for used vehicle imports)
```
