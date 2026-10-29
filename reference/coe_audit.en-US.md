# coe_audit — API Reference

> Generated from `coe_audit/types.lua` by `tools/gen_reference.lua`. Do not edit by hand.

## Exports

### `Record(severity, category, event, context)`

Enqueues an audit event and returns immediately; write operations are batched asynchronously. The calling resource is automatically registered and must be present in `AllowedResources`.

| Parameter | Type | Description |
|---|---|---|
| `severity` | `string` | Log severity level |
| `category` | `string` | Audit domain category |
| `event` | `string` | Event identifier name |
| `context` | `table\|nil` | Only fields declared in `AllowedContextFields` |

**Returns**

- `boolean` `ok`
- `string|nil` `errorCode` — `invalid_*`, `resource_not_allowed`, `queue_full`, ...

### `IsReady()`

Verifies if persistence is ready and database migrations have been successfully applied.

**Returns**

- `boolean` `ready`
