# coe_elos — API reference

> Generated from `coe_elos/types.lua` by `tools/gen_reference.lua`. Do not edit by hand.

Server-only exports. The app (smartphone and tablet) uses TabletCall; other resources read the public profile.

## Exports

### `IsReady()`

Migrations have been applied and the resource is ready.

**Returns**

- `boolean` `ready`

### `GetProfile(characterId)`

Public profile for a character (the portion visible to a disconnected visitor, including the résumé), or nil if no profile exists. Used for job applications (phase 2).

| Parameter | Type | Description |
|---|---|---|
| `characterId` | `string` |  |

**Returns**

- `CoeElosProfile|nil` `profile`

### `TabletVisible(playerId, appId)`

Elos app visible on the device (installed from the coe_apps store). Only coe_tablet and coe_phone call this.

| Parameter | Type | Description |
|---|---|---|
| `playerId` | `integer` |  |
| `appId` | `string` |  |

**Returns**

- `boolean` `visible`

### `TabletCall(playerId, appId, action, payload)`

App actions: `state`, `saveProfile`, `setItem`, `search`, `person`, `request`, `respond`, `remove`. Only coe_tablet and coe_phone call this.

| Parameter | Type | Description |
|---|---|---|
| `playerId` | `integer` |  |
| `appId` | `string` |  |
| `action` | `string` |  |
| `payload` | `table\|nil` |  |

**Returns**

- `table` `result` — `{ ok, ... }` or `{ ok = false, error }`

## Types

```lua
---@class CoeElosExperience
---@field kind 'job'|'business' Free job (coe_jobs) or business (coe_businesses)
---@field title string Job or role
---@field org string "Free Jobs" or the business name
---@field subtitle string|nil Job type or business category
---@field seconds integer Time worked
---@field tasks integer|nil Tasks (free job)
---@field shifts integer|nil Duty shifts (business)
---@field level integer|nil Free job level
---@field earned integer|nil Earnings (only when the owner makes them visible)
---@field firstAt integer|nil
---@field lastAt integer|nil
---@field current boolean Current business affiliation
---@field note string|nil Owner's comment

---@class CoeElosProfile
---@field stateId string
---@field name string
---@field headline string
---@field about string
---@field resume CoeElosExperience[] Only experiences the owner included in the résumé
---@field summary table `{ seconds, count, current }`
---@field career table|nil `{ level, maxLevel, tier, completed, skills }` when made visible by the owner
```
