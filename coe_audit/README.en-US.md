# coe_audit

**Durable** MariaDB audit trail, independent of the console (`coe_logging`). Records security and audit events (staff actions, character lifecycle, item deliveries/drops, and denied access) for later review.

## How it works

- The `coe_core`, `coe_inventory`, and `coe_admin` resources already call `log(..., 'audit' | 'security', ...)`. This local helper also sends the event to `coe_audit` (best effort, via `pcall`); the console log remains.
- Server-side export: `exports.coe_audit:Record(severity, category, event, context?)`, with `severity` set to `info|warn|error`. Returns `true` when the event is accepted into the queue, or `false, reason`.
- The resource name comes from the runtime (`GetInvokingResource`), never from the payload; only the `CoeAuditConfig.AllowedResources` patterns (framework resources) and callers with the `coe.audit` ACE (`add_ace resource.<name> coe.audit allow`) may write. There is no network write event or read export.
- Context is filtered through the `config.lua` allowlist (scalars, up to 16 fields, strings up to 96 bytes).
- At registration time, `source`/`player_id` and `target` (server IDs) are resolved to `license:` and stored in `actor_license` / `target_license`, since server IDs are not stable.

## Failures and limits

- `Record` never blocks: the event enters an in-memory queue (maximum 1000), and a thread writes batches of up to 50 every 1 s.
- Database unavailable: the batch stays queued and retries use exponential backoff (1 s to 30 s). The error is logged once per failure streak (`audit_flush_failed`).
- Queue full: new events are dropped and counted (`audit_queue_overflow` in the console log). Therefore, the console log remains as a backup.
- Known limitation: events still queued are lost if the process crashes. When the resource stops, it attempts to flush the queue (`audit_events_lost_on_stop` if anything remains).

## Schema (`coe_audit_log`, migration v1)

`id`, `occurred_at` (UTC, ms), `severity`, `category`, `event`, `resource`, `actor_license`, `target_license`, `context` (JSON). Indexes by date, event, actor, and target. Migration tracking is in `coe_audit_schema_migrations`.

Example queries:

```sql
SELECT occurred_at, event, actor_license, target_license, context
FROM coe_audit_log WHERE actor_license = 'license:...' ORDER BY id DESC LIMIT 50;

SELECT occurred_at, event, actor_license FROM coe_audit_log
WHERE category = 'security' AND occurred_at > UTC_TIMESTAMP() - INTERVAL 1 DAY;
```

`exports.coe_audit:IsReady()` indicates whether persistence has finished migrations.

## Retention and access

- Default: keep everything (`RetentionDays = 0`). `set coe_audit_retention_days 90` removes older records when the resource starts (in batches of 5000).
- The table is *append-only by convention*: no code updates it; only retention purge deletes records. For actual immutability, use a separate database user for queries/reports with `SELECT` only.
- The table contains licenses (personal data): restrict database access and set retention according to your policy.

## Covered events

| Source | Events |
|---|---|
| `coe_core` | `character_created`, `character_selected`, `character_archived`, `player_identity_unavailable` |
| `coe_admin` | `admin_item_granted/failed`, `staff_role_assigned/removed/..._failed`, `*_denied`, `admin_panel_access_denied` |
| `coe_inventory` | `inventory_item_given`, `inventory_give_denied`, `world_container_dropped`, `world_container_picked_up` |

`ensure` order: after `coe_core` (uses `@coe_core/lib/migrations.lua`); consumers do not depend on it to start.

## Tests

`test/audit_test.lua` (ingestion, queue, batch, backoff) and integration scenario `coe_database/test/integration/audit_scenario.lua` (idempotent migration, atomic batch, NULLs, retention).

## API reference

[Exports, parameters, and error codes](../reference/coe_audit.md), generated from [`types.lua`](types.lua).
