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

### `Prompt(data)`

Shows (or clears, with nil) the calling resource's standard interaction prompt. Client-side.
Call only when the content changes; one prompt per resource; a stopped resource has its prompt removed.

| Parameter | Type | Description |
|---|---|---|
| `data` | `CoeNotifyPrompt\|nil` |  |

**Returns**

- `boolean` `ok`
- `string|nil` `errorCode` — `invalid_prompt`

## Types

```lua
---@alias CoeNotifyKind 'info'|'success'|'warning'|'error'
---@class CoeNotifyPromptOption
---@field key string key shown (up to 12 characters)
---@field label string action (up to 80 characters)

---@class CoeNotifyPrompt
---@field title string up to 64 characters
---@field subtitle string|nil up to 64 characters
---@field badge string|nil badge on the left (up to 3 characters; default: first option key)
---@field options CoeNotifyPromptOption[] up to 6
```
