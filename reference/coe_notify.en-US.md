# coe_notify — API Reference

> Generated from `coe_notify/types.lua` by `tools/gen_reference.lua`. Do not edit by hand.

## Exports

### `Notify(playerId, kind, message, duration)`

Pushes an animated UI toast notification to a specific player. Server-side; authorized resources only.

| Parameter | Type | Description |
|---|---|---|
| `playerId` | `integer` | Target player server ID |
| `kind` | `CoeNotifyKind` | Visual style category |
| `message` | `string` | Text content (1 to 240 characters) |
| `duration` | `integer\|nil` | Screen duration in ms (1500 to 10000, defaults to 4000) |

**Returns**

- `boolean` `ok`
- `string|nil` `errorCode` — `caller_not_allowed`, `invalid_target`, `invalid_notification`

### `Show(kind, message, duration)`

Displays a UI toast notification locally on the client. Client-side.

| Parameter | Type | Description |
|---|---|---|
| `kind` | `CoeNotifyKind` | Visual style category |
| `message` | `string` | Text content (1 to 240 characters) |
| `duration` | `integer\|nil` | Screen duration in ms (1500 to 10000, defaults to 4000) |

**Returns**

- `boolean` `ok`
- `string|nil` `errorCode` — `invalid_notification`

## Types

```lua
---@alias CoeNotifyKind 'info'|'success'|'warning'|'error'
```
