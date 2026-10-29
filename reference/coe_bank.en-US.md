# coe_bank — API Reference

> Generated from `coe_bank/types.lua` by `tools/gen_reference.lua`. Do not edit by hand.

Server-only exports. The banking UI uses the `coe_bank:request` net event (request/response) and is not part of this public export contract.

## Exports

### `Yield()`

Allows an enterprise banking pack to take over operations: the base bank hides branch desks, ATMs, and blips, and closes open UIs until the caller stops. Restricted to resources with `coe.bank.yield` ACE. Call upon startup and re-call in `onResourceStart` of `coe_bank`.

**Returns**

- `true|{ error: string }` `result` — `true` or `{ error = 'forbidden' }`

### `Status()`

Current status of the base banking system.

**Returns**

- `CoeBankStatus` `status`

## Types

```lua
---@class CoeBankStatus
---@field active boolean Whether base bank is actively servicing (branches, ATMs, and blips visible)
---@field yieldedBy string|nil Resource that assumed banking control
```
