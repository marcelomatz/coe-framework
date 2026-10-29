# coe_supervisor — API Reference

> Generated from `coe_supervisor/types.lua` by `tools/gen_reference.lua`. Do not edit by hand.

Server-only exports, strictly restricted to the caller resource defined in `SupervisorConfig.Caller`.

## Exports

### `List()`

Retrieves all managed resources along with categories, dependencies, and dependents.

**Returns**

- `CoeSupervisorEntry[]|nil` `list` — `nil` if caller is unauthorized

### `Restart(name, requester)`

Restarts a resource and its dependents in strict topological order (executing `refresh` prior to starts).

| Parameter | Type | Description |
|---|---|---|
| `name` | `string` | Target resource name |
| `requester` | `integer\|nil` | Player server ID who requested restart (for audit logs) |

**Returns**

- `boolean` `ok`
- `string|nil` `errorCode`

## Types

```lua
---@class CoeSupervisorEntry
---@field name string Resource folder name
---@field category string Architectural category
---@field critical boolean If true, restarting affects critical infrastructure
---@field description string|nil Brief summary of the resource
---@field dependencies string[] List of required dependency resources
---@field dependents string[] List of downstream dependent resources
```
