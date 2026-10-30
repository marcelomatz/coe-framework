# coe_rentals — API Reference

> Generated from `coe_rentals/types.lua` by `tools/gen_reference.lua`. Do not edit by hand.

Public type definitions of coe_rentals for LuaLS.

## Exports

### `GetActiveRental(characterId)`

Returns the active vehicle rental record for a character or `nil`.

| Parameter | Type | Description |
|---|---|---|
| `characterId` | `string` | Character identifier |

**Returns**

- `ActiveRentalInfo|nil` `rental`

### `ListStations()`

Registered stations. Only `AdminResources`/ACE `coe.rentals.admin` (others get an empty list).

**Returns**

- `RentalStationDef[]`

### `SaveStation(raw)`

Creates or updates a station. Only `AdminResources`/ACE `coe.rentals.admin`.

| Parameter | Type | Description |
|---|---|---|
| `raw` | `RentalStationDef` |  |

**Returns**

- `RentalStationDef|table` `station` — the saved station or { error = code }

### `DeleteStation(stationId)`

Removes a station. Only `AdminResources`/ACE `coe.rentals.admin`.

| Parameter | Type | Description |
|---|---|---|
| `stationId` | `string` |  |

**Returns**

- `boolean|table` `ok` — `true` or { error = code }

### `Catalog()`

Rental vehicle catalog (config.lua).

**Returns**

- `RentalVehicleDef[]`

## Types

```lua
---@class RentalVehicleDef
---@field model string
---@field label string
---@field category string
---@field price number
---@field deposit number

---@class RentalStationDef
---@field id string
---@field label string
---@field enabled boolean
---@field ped table { x, y, z, h, model? } attendant (NPC) and counter
---@field spawns table[] pickup points { x, y, z, h } (1 to 8); the vehicle leaves at the first free one
---@field returnZone table { x, y, z, radius } return zone
---@field vehicles string[] offered models (empty: whole catalog)
---@field blip table { enabled, sprite, color, scale }

---@class ActiveRentalInfo
---@field entity integer
---@field netId integer
---@field plate string
---@field model string
---@field deposit number
---@field stationId string
---@field rentedAt integer
```
