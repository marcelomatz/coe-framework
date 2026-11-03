# coe_logging

`coe_logging` provides structured server-side logs for Coe resources. Records are emitted to the FXServer console in a readable format (default) or as a JSON line; the resource does not write logs to MariaDB or send logs to clients.

## Contract

Use the server-side `Log(level, category, event, context?)` export:

```lua
exports.coe_logging:Log('info', 'audit', 'character_selected', {
	player_id = source,
	character_id = characterId
})
```

Each line includes `timestamp` in UTC, `level`, `category`, `event`, `resource`, and `context`. Accepted levels are `debug`, `info`, `warn`, and `error`. Recommended categories include `lifecycle`, `persistence`, `database`, `security`, `audit`, and `notification`.

`event` must be a stable `snake_case` code; do not use UI text, SQL, exceptions, or arbitrary data as its name. Context is limited to an allowlist in `config.lua`, scalar values, and up to 16 fields. Sensitive fields and nested structures are not logged.

Callers may be resources in the `AllowedResources` defaults (framework resources) and anyone with the `coe.logging` ACE (`add_ace resource.<name> coe.logging allow`). `resource` is obtained server-side from the caller and is not accepted in the payload. There is no network event for writing logs.

## Configuration

The fallback level and initial levels per resource are set in `config.lua`. The global convar sets the minimum for all resources; a resource-specific convar overrides the global level:

```cfg
set coe_logging_level "info"
set coe_logging_level_coe_inventory "debug"
```

Precedence is: per-resource convar, global convar, resource level in `config.lua`, then fallback level. Invalid convar values are ignored. Levels below the configured minimum are filtered. Use `debug` temporarily during diagnosis; avoid leaving it enabled unnecessarily.

## Output format

The default (`pretty`) prints `time LEVEL resource category event key=value ...`, with aligned columns, context in alphabetical order, and color by level (debug blue, info green, warn yellow, error red):

```text
17:35:42 INFO  coe_core       lifecycle    database_waiting
17:35:42 ERROR coe_admin      persistence  database_initialization_failed  error_code=database_error retry_ms=5000
```

For log collectors, use one JSON line per event (`timestamp` in UTC, `level`, `category`, `event`, `resource`, `context`). Convars (override `DefaultFormat` and `DefaultColor` in `config.lua`):

```cfg
set coe_logging_format "json"   # pretty (padrão) ou json
set coe_logging_color "0"       # desliga as cores no formato pretty
```

Context values are sanitized in readable format: control characters and `^` become `?`, so text cannot inject color or break the line. An unknown format falls back to `pretty`.

## Logs and notifications

Operational/audit logs are not automatically forwarded to the player. A use case should call `coe_logging` for observability and `coe_notify` separately when a message makes sense during gameplay. This prevents technical failures and internal data from leaking into the UI.

## Limitations

Current output depends on the FXServer console/collector. Durable storage, rotation, retention, and audit queries are future work. Existing audit events are partial and do not cover all gameplay actions; see the [catalog and history](https://docs.coeroleplay.app/#doc=CHANGELOG.md). `coe_logging` cannot depend on the database so it continues to work when the database is unavailable.

## Tests

Files: `config.lua` defines levels, caller allowlist, and safe fields; `server.lua` validates, filters, and emits JSON; `fxmanifest.lua` loads server-side scripts only. Run `lua test\logging_test.lua` from the resource folder. The test covers levels, per-resource overrides, allowlists, and sanitization. High volume, collector/rotation, persistent storage, and real export permissions are future operational validations; see [TEST_COVERAGE.md](../TEST_COVERAGE.md).

## API reference

[Exports, parameters, and error codes](../reference/coe_logging.md), generated from [`types.lua`](types.lua).
