# coe_database

`coe_database` is the Coe framework's MariaDB transport provider. It manages connections/pooling, prepared queries, and transactions outside domain rules.

## Architecture and boundaries

- Only authorized resources call SQL exports; the caller name comes from the runtime (`GetInvokingResource`). Framework defaults (`server/access.js`): `coe_core`, `coe_inventory`, `coe_audit`, `coe_vehicles`, `coe_vehicle_catalog`, `coe_businesses`, `coe_needs`, `coe_economy`, `coe_spawn`, `coe_jobs`, `coe_shops`, `coe_bank`, `coe_mobile`, and `coe_staff`. Packages and third-party scripts with persistence receive the ACE in `server.cfg`, without editing the framework: `add_ace resource.<name> coe.database allow`. Each resource is responsible for its module's schema and persistence rules.
- `coe_database` depends on `coe_logging` for operational error logging; the logger does not depend on the provider or database.
- `Query`, `Execute`, and `Transaction` use prepared statements; `multipleStatements` remains disabled.
- `Transaction` executes statements in sequence on the same connection and attempts a rollback before reporting failure.
- Core/repositories remain responsible for identity SQL and versioned Core migrations. `coe_inventory` and `coe_admin` maintain their own adapters and apply their own versioned migrations through `CoeMigrations` (`coe_core/lib/migrations.lua`), each with its own tracking table (`coe_inventory_schema_migrations`, `coe_admin_schema_migrations`). No client accesses the provider.
- Database results are not automatically sent to the client. The calling resource must filter and project any response.
- Configuration or connection failures keep the provider unavailable and return an explicit error; there is no silent fallback. Operational errors go to `coe_logging` with error codes, without SQL, parameters, or credentials; if the logger is unavailable, the provider writes a fallback JSON line to the console.

## Runtime requirements

- FXServer with server-side Node.js 22 runtime.
- JavaScript dependencies installed in the resource folder before starting the server. `package-lock.json` pins the npm dependency tree; `yarn` is not an FXServer resource or runtime dependency.
- MariaDB accessible to the FXServer process.
- `mysql2` is restricted to transport and pinned in `package.json`.

Install or restore dependencies from the resource folder with `npm ci --omit=dev`. Do not install a third-party `yarn` resource or declare `yarn` as an FXServer dependency. The local unit suite does not require a MariaDB connection; Node.js 22 runtime, driver, and JavaScript/Lua bridge compatibility still need to be verified in the target FXServer Enhanced environment.

## Configuration

Configure server-only convars outside version-controlled files whenever possible:

| Convar | Required | Default | Description |
|---|---:|---|---|
| `coe_database_host` | no | `127.0.0.1` | MariaDB host |
| `coe_database_port` | no | `3306` | TCP port |
| `coe_database_user` | yes | empty | Dedicated framework user |
| `coe_database_password` | yes | empty | User password |
| `coe_database_name` | yes | empty | Framework schema |
| `coe_database_connection_limit` | no | `10` | Connection pool size, from 1 to 50 |
| `coe_database_ssl` | no | `false` | Set to `true` to require TLS with a validated certificate |

Use a dedicated MariaDB user with minimum privileges on the Coe schema; do not use `root`. Configure TLS for remote hosts.

## Server-side exports

Exports take a callback because database I/O is asynchronous. The callback receives `(success, result, errorCode)`:

```lua
exports.coe_database:Query(
	'SELECT player_id FROM coe_players WHERE identifier = ?',
	{ identifier },
	function(success, rows, errorCode)
		if not success then
			print(('Consulta falhou: %s'):format(errorCode))
			return
		end

		-- Validar/projetar os dados antes de usá-los ou enviá-los ao client.
	end
)
```

- `Query(sql, parameters, callback)` returns query rows/results.
- `Execute(sql, parameters, callback)` returns write metadata.
- `Transaction(statements, callback)` takes a list `{ sql = '...', parameters = {...} }` and returns metadata in the same order.
- `IsReady()` indicates that the pool has connected and remains available.

### Script map

- `server/index.js`: FiveM exports, calling-resource verification, provider lifecycle, and `coe_logging` integration. Local `require()` calls use paths from the resource root (`./server/provider`), because FXServer does not resolve relative to the file's folder; `provider.js` and `validation.js` cannot import siblings with `./`.
- `server/provider.js`: pool, parameterized execution, transactions, rollback, and lifecycle without FiveM APIs.
- `server/validation.js`: SQL command allowlist and parameter/statement validation.
- `package.json` and `package-lock.json`: pinned Node dependencies for npm installation.
- `fxmanifest.lua`: Node 22 runtime and logging dependency.

Error codes include `caller_not_allowed`, `invalid_sql`, `invalid_parameters`, `database_not_ready`, `query_failed`, `transaction_failed`, and `transaction_rollback_failed`. Logs do not include SQL, parameters, identifiers, or credentials.

## Startup

Start `coe_database` before `coe_core`. Core checks `IsReady()` and publishes its own `ready` state only after the connection and required migrations are complete. Configure database convars through the environment's secret-management mechanism, not in this file or version-controlled `server.cfg`.

## Tests

Run `npm test` from the resource folder. `test/validation.test.js` covers statements/arguments; `test/provider.test.js` uses a fake driver to test initialization, retry, execution, transaction, rollback, and shutdown. `test/access.test.js` covers the caller allowlist and `coe.database` ACE.

`npm run test:integration` runs scenarios in `test/integration/` against a real MariaDB (variables `COE_TEST_DB_USER`, `COE_TEST_DB_PASSWORD`, `COE_TEST_DB_NAME` ending in `_test`; optional `COE_TEST_DB_HOST`/`COE_TEST_DB_PORT`; requires `lua` on PATH). CI runs this suite on a MariaDB 11.4 service. Lua↔Node export bridge and real FXServer `GetInvokingResource()` are still simulated; see [TEST_COVERAGE.md](../TEST_COVERAGE.md).

## API reference

[Exports, parameters, and error codes](../reference/coe_database.md), generated from [`types.lua`](types.lua).
