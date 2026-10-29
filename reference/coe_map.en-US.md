# coe_map — API Reference

> Generated from `coe_map/types.lua` by `tools/gen_reference.lua`. Do not edit by hand.

Client-only exports. Local event: `coe_map:changed` (mode, scale).

## Exports

### `GetMode()`

Returns the current active minimap display mode.

**Returns**

- `CoeMapMode`

### `OpenFull()`

Opens the full-screen GTA V pause map allowing the player to inspect the city and place waypoints.

## Types

```lua
---@alias CoeMapMode 'mini'|'extended'
```
