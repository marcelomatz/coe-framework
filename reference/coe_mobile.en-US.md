# coe_mobile — API Reference

> Generated from `coe_mobile/types.lua` by `tools/gen_reference.lua`. Do not edit by hand.

Server-only exports. The mobile interface uses the `coe_mobile:request` net event (request/response) and is not part of this public export contract.

## Exports

### `Yield()`

Allows a smartphone pack to take over mobile communications: the base phone ends active calls, closes UI views, and stops opening until the caller stops. Restricted to resources with `coe.mobile.yield` ACE. Call upon startup and re-call in `onResourceStart` of `coe_mobile`.

**Returns**

- `true|{ error: string }` `result` — `true` or `{ error = 'forbidden' }`

### `Status()`

Current status of the base mobile phone subsystem.

**Returns**

- `CoeMobileStatus` `status`

### `NumberOf(characterId)`

Phone number of the character in base mobile system (format 555-0123), or `nil` if phone has not yet been used. Does not generate new numbers. Invoke from within a coroutine thread (performs asynchronous database query).

| Parameter | Type | Description |
|---|---|---|
| `characterId` | `string\|integer` | Target character identifier |

**Returns**

- `string|nil` `number`

## Types

```lua
---@class CoeMobileStatus
---@field active boolean Whether base phone is active (opens, places calls, receives messages)
---@field yieldedBy string|nil Resource that assumed phone control
```
