# coe_handling — API reference

> Generated from `coe_handling/types.lua` by `tools/gen_reference.lua`. Do not edit by hand.

## Exports

### `GetTyre(vehicleId)`

| Parameter | Type | Description |
|---|---|---|
| `vehicleId` | `number` |  |

**Returns**

- `CoeTyreState|nil`

### `SetTyre(vehicleId, compound)`

Fits new tires (resets wear). Only resources in `WriterResources`.

| Parameter | Type | Description |
|---|---|---|
| `vehicleId` | `number` |  |
| `compound` | `string` |  |

**Returns**

- `true|string` `result` — `true` or an error code (`forbidden`, `unknown_tyre`, `vehicle_not_found`, `not_ready`)

### `ListTyres()`

**Returns**

- `string[]`

### `ListClasses()`

**Returns**

- `string[]`

### `GetModifiers(vehicleId)`

Final multipliers (profile x tire x wear) for each CHandlingData field.

| Parameter | Type | Description |
|---|---|---|
| `vehicleId` | `number` |  |

**Returns**

- `table<string,` `number>|nil`

### `IsReady()`

**Returns**

- `boolean`

## Types

```lua
---@class CoeTyreState
---@field compound string `street`, `sport`, `performance`, `slick`, `all_terrain`, `offroad`, or `drift`
---@field fittedAtMeters number Vehicle mileage (m) when the tires were fitted
---@field wear number 0 = new, 1 = at the limit

---@class exports_coe_handling
```
