# coetarget — API Reference

> Generated from `coetarget/types.lua` by `tools/gen_reference.lua`. Do not edit by hand.

Client-only exports. Target interaction options are registered per calling resource and automatically unregistered when the resource stops.

## Exports

### `AddTargetEntity(entity, options)`

Registers interaction options for a specific entity.

| Parameter | Type | Description |
|---|---|---|
| `entity` | `integer` | Target entity handle |
| `options` | `CoeTargetOption[]` | List of target options |

**Returns**

- `boolean` `ok` — `false` if entity does not exist or options are invalid

### `RemoveTargetEntity(entity)`

Removes target options for a specific entity.

| Parameter | Type | Description |
|---|---|---|
| `entity` | `integer` | Target entity handle |

### `AddTargetModel(model, options)`

Registers interaction options for all entities matching a model hash or name.

| Parameter | Type | Description |
|---|---|---|
| `model` | `integer\|string` | Model hash or model name |
| `options` | `CoeTargetOption[]` | List of target options |

**Returns**

- `boolean` `ok`

### `RemoveTargetModel(model)`

Removes target options for a model.

| Parameter | Type | Description |
|---|---|---|
| `model` | `integer\|string` | Model hash or model name |

### `AddTargetGlobal(entityType, options)`

Registers interaction options for all entities of a global category.

| Parameter | Type | Description |
|---|---|---|
| `entityType` | `CoeTargetGlobalType` | Entity type category |
| `options` | `CoeTargetOption[]` | List of target options |

**Returns**

- `boolean` `ok`

### `RemoveTargetGlobal(entityType)`

Removes target options for an entity category.

| Parameter | Type | Description |
|---|---|---|
| `entityType` | `CoeTargetGlobalType` | Entity type category |

### `AddTargetSurface(options)`

Registers options for any targeted surface; `entity` is 0 when raycast hits static map geometry.

| Parameter | Type | Description |
|---|---|---|
| `options` | `CoeTargetOption[]` | List of target options |

**Returns**

- `boolean` `ok`

### `RemoveTargetSurface()`

Removes all registered surface target options.

## Types

```lua
---@class CoeTargetOption
---@field label string Display label shown in interaction UI
---@field onSelect fun(entity: integer, option: CoeTargetOption, hit: vector3|nil) Selection callback
---@field distance number|nil Maximum interaction distance (defaults to DefaultOptionDistance)
---@field canInteract (fun(entity: integer, distance: number, hit: vector3|nil): boolean)|nil Condition check function

---@alias CoeTargetGlobalType 'player'|'ped'|'vehicle'|'object'
```
