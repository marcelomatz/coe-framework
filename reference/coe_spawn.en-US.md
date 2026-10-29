# coe_spawn — API Reference

> Generated from `coe_spawn/types.lua` by `tools/gen_reference.lua`. Do not edit by hand.

## Exports

### `GetStarterHotel()`

Returns the current starter hotel configuration for newly spawned characters.

**Returns**

- `StarterHotel` `hotel`

### `SetStarterHotel(data)`

Saves and updates starter hotel spawn settings, broadcasting updates to active connected players.

| Parameter | Type | Description |
|---|---|---|
| `data` | `StarterHotel\|table` | Starter hotel configuration table |

**Returns**

- `boolean` `success`
- `string|nil` `errorCode`

## Types

```lua
---@class StarterHotelCoords
---@field x number
---@field y number
---@field z number
---@field h number?

---@class StarterHotelStash
---@field x number
---@field y number
---@field z number
---@field slots number
---@field maxWeight number

---@class StarterHotel
---@field name string
---@field enabled boolean
---@field entrance StarterHotelCoords
---@field room StarterHotelCoords
---@field exit StarterHotelCoords
---@field stash StarterHotelStash
```
