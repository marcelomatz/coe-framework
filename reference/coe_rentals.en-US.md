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
---@field coords table
---@field spawn table
---@field returnZone table
---@field blip table

---@class ActiveRentalInfo
---@field entity integer
---@field netId integer
---@field plate string
---@field model string
---@field deposit number
---@field stationId string
---@field rentedAt integer
```
