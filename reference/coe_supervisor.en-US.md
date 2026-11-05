# coe_supervisor — API Reference

> Generated from `coe_supervisor/types.lua` by `tools/gen_reference.lua`. Do not edit by hand.

Server-only exports. List/Restart/GetUpdateStatus/CheckForUpdates/ApplyUpdate require the `coe.supervisor` ACE
(default: coe_staff). WriteFile/ReadFile/HashFile/DownloadFile/CommitFile/DiscardFile/VerifySignature are internal:
only coe_supervisor itself may invoke them.

## Exports

### `List()`

Managed resources, including category, dependencies, and dependents.

**Returns**

- `CoeSupervisorEntry[]|nil` `list` — `nil` for unauthorized caller

### `Restart(name, requester)`

Restarts the resource and its dependents in the proper dependency order (executes `refresh` before starts).

| Parameter | Type | Description |
|---|---|---|
| `name` | `string` | Target resource name |
| `requester` | `integer\|nil` | Requester player source ID (for audit logging) |

**Returns**

- `boolean` `ok`
- `string|nil` `errorCode`

### `GetUpdateStatus()`

Returns the current state of COE Framework update checks.

**Returns**

- `CoeSupervisorUpdateStatus|nil` `status` — `nil` for unauthorized caller

### `CheckForUpdates(requester)`

Queries the official remote repository for newer COE Framework versions.

| Parameter | Type | Description |
|---|---|---|
| `requester` | `integer\|nil` | Requester player source ID (for audit logging) |

**Returns**

- `CoeSupervisorUpdateStatus|nil` `status` — `nil` for unauthorized caller

### `ApplyUpdate(requester)`

Downloads and applies the latest framework scripts from the official repository onto local resources.

| Parameter | Type | Description |
|---|---|---|
| `requester` | `integer\|nil` | Requester player source ID (for audit logging) |

**Returns**

- `boolean` `ok`
- `CoeSupervisorUpdateResult|string` `resultOrError`

## Types

```lua
---@class CoeSupervisorEntry
---@field name string
---@field category string
---@field critical boolean Critical resource restart affects dependent cascade
---@field description string|nil
---@field dependencies string[]
---@field dependents string[]
---@field replacedBy string|nil Package replacing this base resource (coe_supervisor_replaces)

---@class CoeSupervisorUpdateStatus
---@field available boolean Whether newer version is available in repository
---@field checking boolean Whether check is currently in progress
---@field updating boolean Whether file update is currently in progress
---@field localVersion string Currently installed version (e.g. '0.1.0-beta.1')
---@field remoteVersion string|nil Latest version available in repository
---@field tag string|nil Release tag (e.g. 'v0.1.0-beta.1')
---@field channel string Release channel ('beta', 'rc', 'stable', ...)
---@field notes string|nil Release summary notes
---@field repository string GitHub repository (e.g. 'marcelomatz/coe-framework')
---@field branch string Monitored branch or ref
---@field outdatedCount integer Number of resources with pending updates
---@field outdatedResources string[] List of outdated resource names
---@field filesCount integer Number of files in update execution plan
---@field requiresFullRestart boolean Whether update touches critical core resources
---@field needsRestart boolean Whether update was applied and awaits restart
---@field lastError string|nil Error code of last check or update failure

---@class CoeSupervisorUpdateResult
---@field version string Installed version after update
---@field updatedResources integer Total updated resources count
---@field filesUpdated integer Total written files count
---@field requiresFullRestart boolean Whether full FXServer restart is recommended
```
