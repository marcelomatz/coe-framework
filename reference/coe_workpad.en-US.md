# coe_workpad — API Reference

> Generated from `coe_workpad/types.lua` by `tools/gen_reference.lua`. Do not edit by hand.

Server-only exports. The tablet UI uses the `coe_workpad:open` and `coe_workpad:call` net events and is not part of this public export contract.
Third-party apps integrate via `TabletCall(playerId, appId, action, payload, instance)` and multi-instance apps via
`TabletInstances(playerId)`; UI frontends register via `window.CoeTablet.register(id, render(container, api))`.

## Exports

### `Yield()`

Allows a comprehensive enterprise tablet pack to take over tablet operations: the base tablet closes UI views and stops opening until caller stops. Restricted to resources with `coe.workpad.yield` ACE. Call upon startup and re-call in `onResourceStart` of `coe_workpad`.

**Returns**

- `true|{ error: string }` `result` — `true` or `{ error = 'forbidden' }`

### `Status()`

Current status of base workpad tablet system.

**Returns**

- `CoeWorkpadStatus` `status`

## Types

```lua
---@class CoeWorkpadStatus
---@field active boolean Whether base workpad is active (opens via item, hotkey, and command)
---@field yieldedBy string|nil Resource that assumed tablet control
```
