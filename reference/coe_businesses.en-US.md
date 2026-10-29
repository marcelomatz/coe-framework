# coe_businesses — API Reference

> Generated from `coe_businesses/types.lua` by `tools/gen_reference.lua`. Do not edit by hand.

Server-only exports. Multi-returns are lost across resource boundaries: errors are returned as `{ error = code }`.
ACE permissions (configured in `config.lua`): `coe.businesses.write` (Save/Seed/Delete/ClockIn), `coe.businesses.clock` (Clock/ClockOut),
`coe.businesses.tablet` (Tablet*), `coe.businesses.permissions` (RegisterPermissions), `coe.businesses.payroll`
(Salary/Payroll), `coe.businesses.admin` (DutySummary), `coe.businesses.extend` (RegisterTab/RegisterProvider).

## Exports

### `IsReady()`

Returns whether the business registry is fully initialized.

**Returns**

- `boolean` `ready`

### `Categories()`

Business category definitions from `BusinessesConfig.Categories`.

**Returns**

- `table` `categories`

### `RuleSchema()`

Configurable business rule schemas (`BusinessesConfig.Rules`).

**Returns**

- `table` `schema`

### `List(category)`

List of registered businesses (optionally filtered by category). Empty before `IsReady`.

| Parameter | Type | Description |
|---|---|---|
| `category` | `string\|nil` | Optional category filter |

**Returns**

- `table[]` `businesses`

### `Get(id)`

Retrieves business data by unique business ID.

| Parameter | Type | Description |
|---|---|---|
| `id` | `string` | Unique business ID |

**Returns**

- `table|nil` `business`

### `Save(raw, by)`

Creates or updates a business (zones, duty stations, owner, staff, grades). Requires `coe.businesses.write`.

| Parameter | Type | Description |
|---|---|---|
| `raw` | `table` | Business configuration payload |
| `by` | `string\|integer\|nil` | Author identifier for audit logging |

**Returns**

- `table|CoeBusinessesError` `business`

### `Seed(raw)`

Creates business only if it does not already exist (package seed, e.g. coe_shops). Requires `coe.businesses.write`.

| Parameter | Type | Description |
|---|---|---|
| `raw` | `table` | Business seed definition |

**Returns**

- `table|CoeBusinessesError` `business`

### `Delete(id, by)`

Deletes a business registry entry. Requires `coe.businesses.write`.

| Parameter | Type | Description |
|---|---|---|
| `id` | `string` | Business identifier |
| `by` | `string\|integer\|nil` | Author identifier for audit logging |

**Returns**

- `true|CoeBusinessesError` `result`

### `ClockIn(source, characterId, businessId, at, atStation)`

Clocks a character into active duty. Requires `coe.businesses.write`.

| Parameter | Type | Description |
|---|---|---|
| `source` | `integer` | Player server ID |
| `characterId` | `string\|integer` | Character identifier |
| `businessId` | `string` | Target business ID |
| `at` | `vector3\|table\|nil` | Position vector (validated against business zone) |
| `atStation` | `boolean\|nil` | Whether duty was clocked at physical station |

**Returns**

- `true|CoeBusinessesError` `result` — `unknown_business`, `already_on_duty`, `on_duty_elsewhere`, `outside_area`

### `ClockOut(source, reason)`

Clocks out a character. Requires `coe.businesses.write` or `coe.businesses.clock`.

| Parameter | Type | Description |
|---|---|---|
| `source` | `integer` | Player server ID |
| `reason` | `string\|nil` | Optional clock out reason |

**Returns**

- `true|CoeBusinessesError` `result` — `not_on_duty`

### `Clock(source, businessId, stationId)`

Full clock in/out flow at a duty station (validation, notifications, audit). Requires `coe.businesses.clock`.

| Parameter | Type | Description |
|---|---|---|
| `source` | `integer` | Player server ID |
| `businessId` | `string` | Business identifier |
| `stationId` | `string` | Station identifier |

**Returns**

- `{ ok: true }|CoeBusinessesError` `result`

### `IsOnDuty(businessId, characterId)`

Returns whether character is currently on duty for the business.

| Parameter | Type | Description |
|---|---|---|
| `businessId` | `string` | Target business ID |
| `characterId` | `string\|integer` | Character identifier |

**Returns**

- `boolean` `onDuty`

### `DutySummary()`

Returns total and per-business active duty headcounts. Requires `coe.businesses.admin`.

**Returns**

- `{ total: integer, byBusiness: table<string, integer> }` `summary`

### `CurrentDuty(source)`

Returns the business ID where the player is currently clocked in.

| Parameter | Type | Description |
|---|---|---|
| `source` | `integer` | Player server ID |

**Returns**

- `string|nil` `businessId`

### `Access(businessId, characterId)`

Resolves permissions and role capabilities for a character within a business.

| Parameter | Type | Description |
|---|---|---|
| `businessId` | `string` | Target business ID |
| `characterId` | `string\|integer` | Character identifier |

**Returns**

- `CoeBusinessAccess` `access`

### `Partners(businessId)`

Lists registered partners of a business.

| Parameter | Type | Description |
|---|---|---|
| `businessId` | `string` | Business identifier |

**Returns**

- `{ characterId: string|integer, name: string }[]` `partners`

### `Debtors(businessId)`

List of liability contacts: business owner first, then partners. Empty if no owner.

| Parameter | Type | Description |
|---|---|---|
| `businessId` | `string` | Business identifier |

**Returns**

- `(string|integer)[]` `characterIds`

### `Permissions()`

Dictionary of known role permissions (`name = label`), including third-party registrations.

**Returns**

- `table<string, string>` `permissions`

### `RegisterPermissions(list)`

Registers custom grade permissions from a package. Prefix defaults to resource name without `coe_` (e.g. `police.arrest`). Requires `coe.businesses.permissions`.

| Parameter | Type | Description |
|---|---|---|
| `list` | `{ name: string, label: string }[]` | Permission definitions (up to 64) |

**Returns**

- `true|CoeBusinessesError` `result` — `invalid_permissions`

### `Grades(businessId)`

List of configured job grades for the business.

| Parameter | Type | Description |
|---|---|---|
| `businessId` | `string` | Target business ID |

**Returns**

- `table[]` `grades` — Name, level, salary, and permission flags for each grade

### `GradeOf(businessId, characterId)`

Returns the grade assigned to a character in this business.

| Parameter | Type | Description |
|---|---|---|
| `businessId` | `string` | Business identifier |
| `characterId` | `string\|integer` | Character identifier |

**Returns**

- `table|nil` `grade` — `nil` if not an employee or business has no grades

### `Can(businessId, characterId, permission, remoteOnly)`

Checks if a character is authorized for a specific permission. Owners have all; staff have grade permissions (while on duty, unless remote access).

| Parameter | Type | Description |
|---|---|---|
| `businessId` | `string` | Business identifier |
| `characterId` | `string\|integer` | Character identifier |
| `permission` | `string` | Permission key (e.g. `business.funds`) |
| `remoteOnly` | `boolean\|nil` | Requires authorization without active duty |

**Returns**

- `boolean` `allowed`

### `Salary(businessId, characterId)`

Returns the salary rate for the character's grade. Requires `coe.businesses.payroll` (otherwise returns 0).

| Parameter | Type | Description |
|---|---|---|
| `businessId` | `string` | Business identifier |
| `characterId` | `string\|integer` | Character identifier |

**Returns**

- `integer` `salary`

### `Payroll(businessId)`

Retrieves full payroll schedule for business staff. Requires `coe.businesses.payroll` (otherwise empty list).

| Parameter | Type | Description |
|---|---|---|
| `businessId` | `string` | Target business ID |

**Returns**

- `{ characterId: string|integer, name: string, grade: string, salary: integer }[]` `payroll`

### `RegisterTab(def)`

Registers an extension tab on the business tablet application. Requires `coe.businesses.extend`. Unregisters on caller stop.

| Parameter | Type | Description |
|---|---|---|
| `def` | `table` | Tab definition schema |

**Returns**

- `true|CoeBusinessesError` `result`

### `RegisterProvider(kind, def)`

Registers a data provider for Fleet (`fleet`: `{ list, setStaff? }`) and Property (`properties`: `{ list }`) tabs. Requires `coe.businesses.extend`.

| Parameter | Type | Description |
|---|---|---|
| `kind` | `'fleet'\|'properties'` | Provider domain |
| `def` | `table` | Export endpoint mappings |

**Returns**

- `true|CoeBusinessesError` `result`

### `TabletInstances(playerId)`

Lists business apps accessible to player on tablet (one per owned or employed business). Requires `coe.businesses.tablet`.

| Parameter | Type | Description |
|---|---|---|
| `playerId` | `integer` | Player server ID |

**Returns**

- `table[]` `instances`

### `TabletCall(playerId, appId, action, payload, instance)`

Handles business tablet app actions. `instance` specifies business context (never trusted from payload). Requires `coe.businesses.tablet`.

| Parameter | Type | Description |
|---|---|---|
| `playerId` | `integer` | Player server ID |
| `appId` | `'business'` | Application identifier |
| `action` | `string` | Action name |
| `payload` | `table\|nil` | Action arguments |
| `instance` | `string` | Business instance identifier |

**Returns**

- `table` `result` — `{ ok = false, error = code }` on failure

## Types

```lua
---@class CoeBusinessesError
---@field error string `forbidden`, `not_ready`, `invalid_*`, `database_error`, ...

---@class CoeBusinessAccess
---@field owner boolean
---@field staff boolean
---@field partner boolean
---@field canClock boolean
---@field canWork boolean
```
