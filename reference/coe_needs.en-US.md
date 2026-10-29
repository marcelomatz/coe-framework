# coe_needs — API Reference

> Generated from `coe_needs/types.lua` by `tools/gen_reference.lua`. Do not edit by hand.

## Exports

### `GetNeeds(source)`

Retrieves the current vital needs snapshot of a player. Server-side.

| Parameter | Type | Description |
|---|---|---|
| `source` | `integer` | Player server ID |

**Returns**

- `CoeNeedsState|nil` `snapshot` — `nil` if character data is not yet loaded

### `AddNeed(source, name, delta)`

Adds `delta` to a vital need (clamped between 0 and 100). Server-side; restricted to resources in `AllowedResources`. Changes are saved via periodic batch flush.

| Parameter | Type | Description |
|---|---|---|
| `source` | `integer` | Player server ID |
| `name` | `CoeNeedName` | Need identifier |
| `delta` | `number` | Value offset to add (positive or negative) |

**Returns**

- `true|string` `result` — `true` or error code: `caller_not_allowed`, `needs_not_loaded`, `invalid_need`

### `SetNeed(source, name, value)`

Sets the exact value of a vital need (clamped between 0 and 100). Same authorization rules as `AddNeed`.

| Parameter | Type | Description |
|---|---|---|
| `source` | `integer` | Player server ID |
| `name` | `CoeNeedName` | Need identifier |
| `value` | `number` | Absolute target value |

**Returns**

- `true|string` `result` — `true` or error code: `caller_not_allowed`, `needs_not_loaded`, `invalid_need`

### `GetState()`

Returns the latest vital needs state synchronized from the server. Client-side.

**Returns**

- `CoeNeedsState|nil`

## Types

```lua
---@alias CoeNeedName 'hunger'|'thirst'|'stress'

---@class CoeNeedsState
---@field hunger integer Value between 0 and 100
---@field thirst integer Value between 0 and 100
---@field stress integer Value between 0 and 100
```
