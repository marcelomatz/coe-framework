# coe_mechanic — API reference

> Generated from `coe_mechanic/types.lua` by `tools/gen_reference.lua`. Do not edit by hand.

## Exports

### `TabletCall(source, appId, action, payload)`

Workshop tablet actions (`scan`, `replace`). Accepts calls only from coe_tablet.

| Parameter | Type | Description |
|---|---|---|
| `source` | `number` |  |
| `appId` | `string` |  |
| `action` | `string` |  |
| `payload` | `table` |  |

**Returns**

- `table` `result` — `{ ok = true, vehicle = ... }` or `{ ok = false, error = string }`

### `Inspect(vehicleId)`

| Parameter | Type | Description |
|---|---|---|
| `vehicleId` | `number` |  |

**Returns**

- `CoePartStatus[]|nil`

### `ReplacePart(vehicleId, part)`

Only resources in `WriterResources`.

| Parameter | Type | Description |
|---|---|---|
| `vehicleId` | `number` |  |
| `part` | `string` |  |

**Returns**

- `true|string` `result` — `true` or `forbidden`, `unknown_part`, `vehicle_not_found`, `not_ready`

### `ServiceVehicle(vehicleId)`

Replaces all parts in warning or critical condition.

| Parameter | Type | Description |
|---|---|---|
| `vehicleId` | `number` |  |

**Returns**

- `true|string`

### `AdjustMileage(vehicleId, meters)`

Adjusts mileage (meters); audited by coe_vehicles.

| Parameter | Type | Description |
|---|---|---|
| `vehicleId` | `number` |  |
| `meters` | `number` |  |

**Returns**

- `true|string`

### `AddWear(vehicleId, meters, parts)`

Adds extra wear to parts (only `WearResources`, currently coe_fuel). `meters > 0` increases wear; `< 0` subtracts accumulated extra wear (never makes a part newer than when it was replaced). Resets when the part is replaced.

| Parameter | Type | Description |
|---|---|---|
| `vehicleId` | `number\|string` |  |
| `meters` | `integer` |  |
| `parts` | `string[]` |  |

**Returns**

- `true|string`

### `GetEffects(vehicleId, mileage)`

Effects of parts on handling, used by coe_handling.

| Parameter | Type | Description |
|---|---|---|
| `vehicleId` | `number` |  |
| `mileage` | `number\|nil` |  |

**Returns**

- `{` `mods:` — table<string, number>, key: string }|nil

### `ListParts()`

**Returns**

- `string[]`

### `IsReady()`

**Returns**

- `boolean`

### `GetShopOwner(shopId)`

| Parameter | Type | Description |
|---|---|---|
| `shopId` | `string` |  |

**Returns**

- `string|nil` `characterId` — Workshop owner (character), or nil if there is no owner

### `GetAppearance(vehicleId)`

| Parameter | Type | Description |
|---|---|---|
| `vehicleId` | `number` |  |

**Returns**

- `CoeAppearance|nil`

### `QuoteAppearance(vehicleId, patch)`

Quote for a patch (proportional to catalog value), without saving it.

| Parameter | Type | Description |
|---|---|---|
| `vehicleId` | `number` |  |
| `patch` | `CoeAppearance` |  |

**Returns**

- `{` `total:` — number, lines: table[] }|string result Quote or error code

### `SetAppearance(vehicleId, patch)`

Merges the patch into the saved appearance and applies it to the vehicle. Only `WriterResources`; the caller handles payment.

| Parameter | Type | Description |
|---|---|---|
| `vehicleId` | `number` |  |
| `patch` | `CoeAppearance` |  |

**Returns**

- `true|string` `result` — `true` or `forbidden`, `invalid_*`, `vehicle_not_found`, `not_ready`

### `GetShops()`

List of configured workshops.

**Returns**

- `table<string,` `table>` — shops

### `GetVehicleOptions(vehicle)`

Customization and mod options available for the vehicle entity. Client-side.

| Parameter | Type | Description |
|---|---|---|
| `vehicle` | `integer` | Vehicle entity |

**Returns**

- `table|nil` `options`

## Types

```lua
---@class CoePartStatus
---@field part string
---@field wear number 0 = new, 1 = at the limit
---@field installedAtMeters number
---@field condition string `ok`, `warn`, or `critical`

---@class exports_coe_mechanic

---@class CoeAppearance
---@field colors table|nil `primary`, `secondary`, `pearl`, `wheel`, `interior`, `dashboard` (GTA indices), `primaryRgb`/`secondaryRgb` ({r,g,b})
---@field mods table<string, number>|nil Mod type (string) -> index; -1 removes
---@field toggles table<string, boolean>|nil `turbo`, `tyreSmoke`, `xenon`
---@field livery number|nil -1 removes
---@field tint number|nil
---@field plateIndex number|nil
---@field wheelType number|nil
---@field xenonColor number|nil
---@field neon { sides: boolean[]|nil, rgb: number[]|nil }|nil
---@field extras table<string, boolean>|nil
```
