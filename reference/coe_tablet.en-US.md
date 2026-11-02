# coe_tablet — API reference

> Generated from `coe_tablet/types.lua` by `tools/gen_reference.lua`. Do not edit by hand.

## Exports

### `TabletVisible(playerId, appId)`

Built-in tablet apps (Duty and Free Jobs, from the basic work tablet): is the app visible? Only coe_tablet calls this itself (ownerCheck). `duty` requires coe_businesses; `freejobs` requires coe_jobs.

| Parameter | Type | Description |
|---|---|---|
| `playerId` | `integer` |  |
| `appId` | `string` | `duty` or `freejobs` |

**Returns**

- `boolean` `visible`

### `TabletCall(playerId, appId, action)`

Actions for built-in tablet apps. Only coe_tablet calls this itself (the app list and access have already been checked). `duty`: `overview`, `clockOut`. `freejobs`: `list`. Errors: `forbidden`, `invalid_action`, `no_character`, `app_unavailable`, `not_on_duty`.

| Parameter | Type | Description |
|---|---|---|
| `playerId` | `integer` |  |
| `appId` | `string` |  |
| `action` | `string` |  |

**Returns**

- `table` `result` — `{ ok = true, data }` or `{ ok = false, error }`

## Types

```lua
---@class CoeTabletApp
---@field id string
---@field label string
---@field script string

---@class CoeTabletProfile
---@field job string|nil
---@field label string|nil
---@field grade number
---@field apps CoeTabletApp[]
```
