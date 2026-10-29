# coe_needs — API Reference

> Generated from `coe_needs/types.lua` by `tools/gen_reference.lua`. Do not edit by hand.

## Exports

### `GetNeeds(playerSource)`

[shared] On server receives `playerSource`; on client takes no arguments and returns the local snapshot.

| Parameter | Type | Description |
|---|---|---|
| `playerSource?` | `integer` | Target player server ID (server-side only) |

**Returns**

- `CoeNeedsSnapshot|nil` `snapshot` — `nil` if player needs state is not yet loaded

### `SetNeed(playerSource, needName, value)`

[server] Sets the absolute value (0..100) of a vital need. Requires ACE `coe.needs`.

| Parameter | Type | Description |
|---|---|---|
| `playerSource` | `integer` | Target player server ID |
| `needName` | `CoeNeedName` | Need identifier |
| `value` | `number` | Target value (0..100) |

**Returns**

- `boolean|'caller_not_allowed'|'character_not_loaded'|'invalid_need'`

### `AddNeed(playerSource, needName, delta)`

[server] Adds `delta` (positive or negative) to a vital need. Requires ACE `coe.needs`.

| Parameter | Type | Description |
|---|---|---|
| `playerSource` | `integer` | Target player server ID |
| `needName` | `CoeNeedName` | Need identifier |
| `delta` | `number` | Delta offset to add |

**Returns**

- `boolean|'caller_not_allowed'|'character_not_loaded'|'invalid_need'`

## Types

```lua
---@alias CoeNeedName 'hunger'|'thirst'|'stress'|'alcohol'|'drugs'

---@class CoeNeedsSnapshot
---@field hunger number
---@field thirst number
---@field stress number
---@field alcohol number
---@field drugs number
---@field updatedAt integer
```
