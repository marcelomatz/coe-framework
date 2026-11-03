# coe_loot — API reference

> Generated from `coe_loot/types.lua` by `tools/gen_reference.lua`. Do not edit by hand.

## Exports

### `Give(playerId, tableId)`

Rolls on a loot table and delivers the result to the player's character inventory.

| Parameter | Type | Description |
|---|---|---|
| `playerId` | `integer` |  |
| `tableId` | `string` | E.g. `house_robbery`, `pedestrian_robbery`, `vehicle_break_in`, `store_robbery` |

**Returns**

- `CoeLootGiveResult` `result`

### `Roll(tableId)`

Rolls without delivering the loot (for placing it in a stash, container, or on the ground).

| Parameter | Type | Description |
|---|---|---|
| `tableId` | `string` |  |

**Returns**

- `CoeLootRollResult` `result`

### `Tables()`

Loaded tables. Read access is unrestricted.

**Returns**

- `{` `id:` — string, label: string }[] tables

## Types

```lua
---@class CoeLootGiveResult
---@field ok boolean
---@field error string|nil `forbidden|unknown_table|no_character`
---@field given { item: string, count: integer }[]|nil Items delivered
---@field lost { item: string, count: integer }[]|nil Items that did not fit in the inventory

---@class CoeLootRollResult
---@field ok boolean
---@field error string|nil `forbidden|unknown_table`
---@field items { item: string, count: integer, unique: boolean }[]|nil
```
