# coe_logging — API Reference

> Generated from `coe_logging/types.lua` by `tools/gen_reference.lua`. Do not edit by hand.

## Exports

### `Log(level, category, event, context)`

Emits a structured log line (JSON or formatted according to server convars). The invoking resource is automatically recorded as the `resource` field.

| Parameter | Type | Description |
|---|---|---|
| `level` | `CoeLogLevel` | Log severity level |
| `category` | `string` | Category tag (up to 48 characters) |
| `event` | `string` | Event identifier (up to 80 characters) |
| `context` | `table\|nil` | Sanitized context data (no sensitive secrets) |

**Returns**

- `boolean` `ok`
- `string|nil` `errorCode` — `invalid_level`, `invalid_event`, `encoding_failed`, ...

## Types

```lua
---@alias CoeLogLevel 'debug'|'info'|'warn'|'error'
```
