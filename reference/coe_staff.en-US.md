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

Registers a garage management provider for administration via the staff panel.

| Parameter | Type | Description |
|---|---|---|
| `provider` | `table` | Provider table defining List, Save, and Delete methods |

**Returns**

- `boolean` `ok`

## Types

```lua
---@class CoeStaffStatus
---@field active boolean Whether base staff panel is active and handling requests
---@field yieldedBy string|nil Resource that assumed staff control
```
