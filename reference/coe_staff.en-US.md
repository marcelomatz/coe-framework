# coe_staff — API Reference

> Generated from `coe_staff/types.lua` by `tools/gen_reference.lua`. Do not edit by hand.

Server-only exports. The staff panel UI uses the `coe_staff:open` and `coe_staff:request` net events and is not part of this public export contract.

## Exports

### `Yield()`

Allows a comprehensive administrative pack to take over staff tooling: base panel closes and stops opening until caller stops. Restricted to resources with `coe.staff.yield` ACE. Call upon startup and re-call in `onResourceStart` of `coe_staff`.

**Returns**

- `true|{ error: string }` `result` — `true` or `{ error = 'forbidden' }`

### `Status()`

Current status of base staff administration panel.

**Returns**

- `CoeStaffStatus` `status`

### `RegisterGaragesProvider(provider)`

Registers a garage provider for administration via the staff panel (Garages tab).

| Parameter | Type | Description |
|---|---|---|
| `provider` | `table` | List(), Save(raw), Delete(id) and `kinds` (editable kinds, default { 'public' }) |

**Returns**

- `boolean` `ok`
- `string|nil` `errorCode` — `invalid_provider`

### `RegisterRentalsProvider(provider)`

Registers the rental stations provider (Rentals tab). Usually coe_rentals.

| Parameter | Type | Description |
|---|---|---|
| `provider` | `table` | List(), Save(raw), Delete(id) and, optionally, Catalog() |

**Returns**

- `boolean` `ok`
- `string|nil` `errorCode` — `invalid_provider`

## Types

```lua
---@class CoeStaffStatus
---@field active boolean Whether base staff panel is active and handling requests
---@field yieldedBy string|nil Resource that assumed staff control
```
