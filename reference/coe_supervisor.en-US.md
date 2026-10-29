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

### `WriteFile(resource, relPath, content, isBinary)`

Internal. Writes a file inside a resource directory (Node.js). Rejects foreign callers and paths outside the resource root.

| Parameter | Type | Description |
|---|---|---|
| `resource` | `string` | Destination resource name |
| `relPath` | `string` | Relative path inside the resource (no `..`, no absolute paths) |
| `content` | `string` | File payload content |
| `isBinary` | `boolean\|nil` | Whether the file is binary (e.g. image/audio) |

**Returns**

- `boolean` `ok`

### `ReadFile(resource, relPath)`

Internal. Reads a text file within a resource directory (Node.js).

| Parameter | Type | Description |
|---|---|---|
| `resource` | `string` | Target resource name |
| `relPath` | `string` | Relative path inside the resource |

**Returns**

- `string|nil` `content`

### `HashFile(resource, relPath, isBinary)`

Internal. Computes SHA-256 (hex) of an installed file; text CRLF is normalized to LF.

| Parameter | Type | Description |
|---|---|---|
| `resource` | `string` | Target resource name |
| `relPath` | `string` | Relative path inside the resource |
| `isBinary` | `boolean\|nil` | Whether file is binary |

**Returns**

- `string|nil` `sha256`

### `DownloadFile(url, resource, relPath, sha256, cb)`

Internal. Downloads via HTTPS (GitHub host) to `<file>.coe-new` and only finalizes if SHA-256 matches.

| Parameter | Type | Description |
|---|---|---|
| `url` | `string` | HTTPS download URL |
| `resource` | `string` | Target resource name |
| `relPath` | `string` | Destination relative path |
| `sha256` | `string` | Expected SHA-256 hash (hex, 64 characters) |
| `cb` | `fun(ok:` | boolean, err: string\|nil) Completion callback |

**Returns**

- `boolean` `started` — Whether the download request was initiated

### `CommitFile(resource, relPath)`

Internal. Atomically moves verified download (`<file>.coe-new`) to its final destination.

| Parameter | Type | Description |
|---|---|---|
| `resource` | `string` | Target resource name |
| `relPath` | `string` | Relative file path |

**Returns**

- `boolean` `ok`

### `DiscardFile(resource, relPath)`

Internal. Discards a staged download candidate that will not be applied.

| Parameter | Type | Description |
|---|---|---|
| `resource` | `string` | Target resource name |
| `relPath` | `string` | Relative file path |

**Returns**

- `boolean` `ok`

### `VerifySignature(body, signature, publicKeyPem)`

Internal. Verifies Ed25519 signature (base64) of version.json against public key in PEM format.

| Parameter | Type | Description |
|---|---|---|
| `body` | `string` | Raw payload string |
| `signature` | `string` | Base64-encoded signature string |
| `publicKeyPem` | `string` | PEM-encoded public key |

**Returns**

- `boolean` `ok`

### `ApplyUpdate(requester)`

Downloads and applies the latest script versions from official repository to installed resources.

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
