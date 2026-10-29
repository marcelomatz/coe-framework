# coe_jobs — API Reference

> Generated from `coe_jobs/types.lua` by `tools/gen_reference.lua`. Do not edit by hand.

Server-only exports. Default jobs are defined in `jobs/*.lua`; third-party resources can register custom jobs dynamically via `RegisterJob` (declarative data only).
Career progression (total XP, skills, and corporate reputation) is globally shared across all occupations.

## Exports

### `RegisterJob(definition)`

Registers or updates a job definition. Ownership is tied to the invoking resource; upon resource stop, registered jobs are removed and active work sessions terminate cleanly.

| Parameter | Type | Description |
|---|---|---|
| `definition` | `CoeJobDefinition` | Declarative job configuration table |

**Returns**

- `true|string` `result` — `true` or error code string: `invalid_id`, `invalid_kind`, `invalid_nodes:<i>`, `id_taken`, ...

### `UnregisterJob(jobId)`

Unregisters a job previously registered by the calling resource.

| Parameter | Type | Description |
|---|---|---|
| `jobId` | `string` | Unique job ID |

**Returns**

- `boolean` `removed`

### `ListJobs()`

Returns the public job catalog (synchronized to clients).

**Returns**

- `table[]` `jobs`

### `IsReady()`

Verifies if jobs database tables and migrations are ready. Third-party resources may also listen to the server event `coe_jobs:ready`.

**Returns**

- `boolean` `ready`

### `GetSession(playerId)`

Retrieves the active work session for an online player.

| Parameter | Type | Description |
|---|---|---|
| `playerId` | `integer` | Player server ID |

**Returns**

- `table|nil` `session` — `{ jobId, cargo, vehicle, progress, route?, cooldowns }`

### `GetProgress(characterId, jobId)`

Retrieves career progress for a specific character in a designated job.

| Parameter | Type | Description |
|---|---|---|
| `characterId` | `string` | Character ID |
| `jobId` | `string` | Unique job identifier |

**Returns**

- `CoeJobProgress|nil` `progress`

### `GetCareer(characterId)`

Retrieves the comprehensive career profile for a character (online or offline): overall level, reputation, skills, total time on duty (`workedSeconds`), and per-job records (level, payout bonus, requirements, `workedSeconds`, `firstAt`, `lastAt`). Used by community UI tablet apps and resumes.

| Parameter | Type | Description |
|---|---|---|
| `characterId` | `string` | Character ID |

**Returns**

- `table|nil` `career`

### `TabletVisible()`

Checks if the Career tablet application is available (`coe_jobs` initialized).

**Returns**

- `boolean` `visible`

### `TabletCall(playerId, appId, action, payload)`

Handles Career app queries: `profile` (career stats and recent work history) and `guide` (`payload.jobId`: how-to guide and player metrics). Available for custom community UI integration.

| Parameter | Type | Description |
|---|---|---|
| `playerId` | `integer` | Player server ID |
| `appId` | `string` | Application identifier |
| `action` | `string` | Action name (`profile` or `guide`) |
| `payload` | `table\|nil` | Action payload |

**Returns**

- `table` `result` — `{ ok = true, data = ... }` or `{ ok = false, error = ... }`

## Types

```lua
---@class CoeJobPoint
---@field x number
---@field y number
---@field z number
---@field h number|nil Heading rotation

---@class CoeJobDefinition
---@field id string Pattern `[a-z][a-z0-9_]`, 2 to 24 characters (`deposit` is reserved)
---@field label string Display job title
---@field kind 'gather'|'route' Work type
---@field center CoeJobPoint|number[] Clock-in NPC coords (accepts `{ x, y, z, h }`)
---@field levels integer[]|nil Minimum XP curve per level, strictly ascending starting at 0
---@field levelBonus number|nil Payout multiplier bonus per level above 1 (default 0.05)
---@field vehicle table|nil `{ model, spawn, plate?, deposit?, returnRadius? }`
---@field tool table|nil Handheld prop during actions: `{ model, bone?, offset?, rotation? }`
---@field gather table|nil `{ nodes, sell = { points, price, ped?, label? }, seconds?, yield?, capacity?, nodeCooldown?, xp?, nodeProp?, animation?, unit?, units?, actionLabel? }`
---@field skills string[]|nil Skills trained by this occupation (`Career.skills`)
---@field tips string[]|nil Up to 6 operational tips displayed in the guide (NPC and Tablet)
---@field requires table|nil `{ career?, reputation?, skills? = { id = level } }` prerequisites
---@field route table|nil `{ stops, pay, mode? ('deliver'|'collect'|'passenger'|'zone'), perRoute?, payPerKm?, bonus?, xp?, stopRadius?, vehicleRange?, stopProp?, carry?, carryAnimation?, recipients?, actionLabel?, pickupLabel?, dropLabel? }`; mode `zone`: `{ zones, perZone?, binModels, binCooldown?, rearDoor?, openLabel?, closeLabel? }` in place of `stops`

---@class CoeJobProgress
---@field xp integer Cumulative experience points
---@field tasks integer Total completed task iterations
---@field earned integer Total lifetime earnings from this job
---@field level integer Current mastery level
---@field maxLevel integer Highest achievable level
---@field nextXp integer|nil XP required for subsequent tier
```
