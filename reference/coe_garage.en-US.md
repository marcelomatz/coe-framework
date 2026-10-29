# coe_garage — API Reference

> Generated from `coe_garage/types.lua` by `tools/gen_reference.lua`. Do not edit by hand.

## Exports

### `IsReady()`

Returns whether the garage subsystem is fully ready and initialized.

**Returns**

- `boolean` `ready`

### `ListGarages()`

Lists all registered public garages.

**Returns**

- `CoeGarage[]` `garages`

### `GetGarage(id)`

Retrieves a registered garage by its unique ID.

| Parameter | Type | Description |
|---|---|---|
| `id` | `string` | Unique garage identifier |

**Returns**

- `CoeGarage|nil` `garage`

### `GetVehicleGarage(vehicleId)`

Returns the garage ID where a vehicle is currently stored or assigned.

| Parameter | Type | Description |
|---|---|---|
| `vehicleId` | `string\|integer` | Vehicle identifier |

**Returns**

- `string|nil` `garageId`

### `SaveGarage(data)`

Creates or updates a public garage.

| Parameter | Type | Description |
|---|---|---|
| `data` | `table` | Raw garage payload |

**Returns**

- `CoeGarage|nil` `garage` — Sanitized and persisted garage data
- `string|nil` `errorCode` — Error code on failure

### `DeleteGarage(id)`

Deletes a garage configuration by its unique ID.

| Parameter | Type | Description |
|---|---|---|
| `id` | `string` | Unique garage identifier |

**Returns**

- `boolean|nil` `ok`
- `string|nil` `errorCode`

## Types

```lua
---@class CoeGarageSpot
---@field id string
---@field label string
---@field x number
---@field y number
---@field z number
---@field heading number
---@field radius number

---@class CoeGarageBlip
---@field enabled boolean
---@field sprite integer
---@field color integer
---@field scale number

---@class CoeGarage
---@field id string
---@field label string
---@field kind string
---@field enabled boolean
---@field spots CoeGarageSpot[]
---@field blip CoeGarageBlip
```
