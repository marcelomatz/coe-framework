# coe_vehicle_catalog — API Reference

> Generated from `coe_vehicle_catalog/types.lua` by `tools/gen_reference.lua`. Do not edit by hand.

## Exports

### `GetVehicleInfo(model)`

Retrieves comprehensive catalog specifications for a specific vehicle model.

| Parameter | Type | Description |
|---|---|---|
| `model` | `string` | Vehicle model name (case-insensitive) |

**Returns**

- `CoeVehicleInfo|nil`

### `ListVehicles(filter)`

Lists all vehicles matching an optional multi-criteria filter.

| Parameter | Type | Description |
|---|---|---|
| `filter` | `CoeVehicleFilter\|nil` | Optional search and filtering criteria |

**Returns**

- `CoeVehicleInfo[]`

### `GetBaseHandling(model)`

Returns raw scalar parameters parsed from loaded `handling.meta` files (e.g., `fMass`), or `nil`.

| Parameter | Type | Description |
|---|---|---|
| `model` | `string` | Vehicle model name |

**Returns**

- `table<string, number>|nil`

### `GetIssues()`

Returns validation warnings and errors detected across vehicle meta files and addon manifests.

**Returns**

- `CoeVehicleCatalogIssue[]`

### `SetOverride(model, fields)`

Merges and persists vehicle catalog overrides (pricing, stock, category). Restricted to `WriterResources`.

| Parameter | Type | Description |
|---|---|---|
| `model` | `string` | Vehicle model name |
| `fields` | `CoeVehicleOverride` | Override values to apply |

**Returns**

- `true|string` `okOrError` — `forbidden`, `unknown_model`, `invalid_price`, ...

### `ClearOverride(model)`

Removes existing overrides for the specified vehicle model. Restricted to `WriterResources`.

| Parameter | Type | Description |
|---|---|---|
| `model` | `string` | Vehicle model name |

**Returns**

- `true|string` `okOrError`

### `Rescan()`

Re-scans and re-indexes all vehicle resources on the server. Restricted to `WriterResources`.

**Returns**

- `true|string` `okOrError`

### `IsReady()`

Verifies if vehicle metadata indexing is complete and ready.

**Returns**

- `boolean` `ready`

## Types

```lua
---@class CoeVehicleInfo
---@field model string Lowercase model name
---@field name string|nil Localized vehicle display name
---@field brand string|nil Brand/manufacturer name
---@field class string Class name (`compacts`, `sedans`, `super`, ... or `unknown`)
---@field type string Vehicle type (`automobile`, `bike`, `boat`, `heli`, `plane`, `submarine`, `trailer`, `train`)
---@field seats number|nil Maximum passenger seating capacity
---@field isAddon boolean Whether vehicle is a custom addon resource
---@field resource string|nil Origin addon resource name
---@field handlingId string|nil Identifier in handling.meta
---@field hasHandling boolean Whether handling data is mapped
---@field price number Active price (override or default class price)
---@field stock number|nil In-stock units (nil = unlimited)
---@field category string Active category (override or class name)
---@field hidden boolean Whether hidden from dealership catalogs

---@class CoeVehicleFilter
---@field type string|nil Filter by vehicle type
---@field class string|nil Filter by class
---@field category string|nil Filter by category
---@field brand string|nil Filter by brand name
---@field addon boolean|nil Filter by addon status
---@field search string|nil Fuzzy search string for model, name, or brand
---@field minPrice number|nil Minimum price boundary
---@field maxPrice number|nil Maximum price boundary
---@field includeHidden boolean|nil Whether to include hidden models
---@field limit integer|nil Max results (default 200, max 500)

---@class CoeVehicleOverride
---@field price integer|nil Custom price override
---@field stock integer|nil Custom stock count
---@field category string|nil Custom display category
---@field hidden boolean|nil Toggle catalog visibility

---@class CoeVehicleCatalogIssue
---@field level string Issue severity (`warn` or `error`)
---@field code string Issue error code (`duplicate_model`, `handling_missing`, `replaces_native`, ...)
---@field model string|nil Vehicle model involved
---@field resource string|nil Resource containing the issue
```
