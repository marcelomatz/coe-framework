# Plan: identity and lifecycle

## Objective

Define and implement persistent player identity, independent characters, MariaDB persistence, and the server-authoritative lifecycle. The design keeps business rules in Lua and does not depend on ox_core, oxmysql, or transient FiveM IDs as persistent identity.

## Implementation status

- **Completed in this phase:** custom MariaDB provider, initial migrations, Player/Character repositories, session and selection services, server-side validation, request cache/rate limiting, initial UI, and spawn gated on Core confirmation. The inventory resolves the `character:<character_id>` key on the server, persists snapshots in MariaDB, and rejects operations without an active character. Custom admin roles also use MariaDB.
- **Validated locally:** Node provider unit tests and Lua tests for identity, sessions, lifecycle, migrations, and inventory operations using a mock provider.
- **Current observability:** `coe_logging` emits JSON events to the console/collector and `coe_notify` provides explicit player feedback. The audit history is still partial and is not persisted by the framework; do not use current logs as a durable/compliance audit trail.
- **Pending before real use:** integration testing on FXServer Enhanced with Node 22, the asynchronous JS/Lua bridge, and MariaDB; configuring database convars in the environment; confirming that the configured Cfx key is active in Keymaster.
- **Next steps:** validate on FXServer Enhanced/Node 22 and real MariaDB; cover integration tests with constraints/transactions; add character state and appearance if defined as in scope for the MVP; develop gameplay save/load and review operations/rollback.
- Per-resource coverage and current gaps are consolidated in [TEST_COVERAGE.en-US.md](../TEST_COVERAGE.en-US.md); the history of this review and the partial audit-event catalog are in the [changelog](https://docs.coeroleplay.app/#doc=CHANGELOG.en-US.md).

## Confirmed domain decisions

- **FiveM session:** `source` is only a transient connection identifier. It can be reused after disconnect and will never be a player, character, or inventory key.
- **Player:** each Coe account receives an internal, persistent, immutable `player_id`. A Cfx identifier obtained on the server locates the account, but is not the primary key and is never sent to the client.
- **External identifiers:** stored separately from `player_id`, with uniqueness by type/value. Linking or replacing identifiers is an explicit operation; identifiers are never merged automatically.
- **Character:** each character receives its own immutable `character_id`, with `player_id` as its owner. Data, state, and inventory belong to the character.
- **Selection:** an authenticated session may have no active character while selection is in progress and may have at most one active character. The server validates that the character belongs to the authenticated player; creating or selecting a character is required before gameplay.
- **Limits and deletion:** default limit of five characters, configurable server-side; names consist of a first and last name; removal is a soft archive. No character or inventory is deleted as a side effect of disconnecting.
- **Inventory:** the persistent key is `character_id`, not a license, `source`, or `player_id`. The MVP starts with a new schema and new data; it does not support compatibility with prior KVP storage.

## Proposed architecture

```text
coe_admin / other resources
              |
          coe_core
   (Lua domain and use cases)
              |
        coe_database
 (MariaDB transport and migrations)
              |
           MariaDB

coe_inventory ---> coe_core identity contracts
```

- `coe_core` owns the Player, Character, and Session domains, lifecycle use cases, and repository ports.
- `coe_database` is a standalone resource limited to the pool/connection, parameterized queries, transactions, migrations, and database error normalization. It contains no gameplay or identity rules.
- The connection uses server-only convar credentials; secrets must not be put in manifests, documentation, logs, or the repository.
- The persistence layer is asynchronous and has defined timeout, pool, and concurrency limits. A database callback may complete an operation only for the same session generation that started it.
- Approved decision: use the FiveM server-side Node.js 22 runtime and `mysql2` as the transport dependency, while keeping the API, repositories, schema, and migrations custom. The Core and its domain modules remain in Lua; the MariaDB protocol will not be implemented manually.
- Provider dependencies are installed with `npm ci --omit=dev` in the `coe_database` folder; there is no dependency on a `yarn` resource. Integration still needs validation on a compatible FXServer Enhanced build.

## Implementation phases

### 0. Contracts and threats

**Deliverables**

- Finalize the external primary identifier format and source, character limit, deletion policy, and MariaDB driver.
- Define states and transitions, event payloads, and session invariants.
- Classify events as local (server-server/client-client) or network events; internal events will not be registered as network events.
- Define server-side validation for all requests: `source`, session state, ownership, argument types/limits, permissions, frequency, and authoritative entity state.

**Acceptance criteria**

- No client request selects `player_id`, `character_id`, owner, or inventory ID for privileged operations.
- Client-derived data, such as quantity, position, and entity, is verified on the server; no security rule depends on the UI/client.
- Client-side events intended exclusively for server-to-client messages verify the sender according to official guidance (`source == 65535`).

### 1. Custom MariaDB persistence

**Deliverables**

- `coe_database` resource with secure configuration, pool, parameterized queries, transactions, observable errors; Core repositories already use the provider.
- Versioned and idempotent migrations for `players`, `player_identifiers`, `characters`, and version tracking.
- Provider unit tests and migration orchestration tests.
- **Pending:** validate connection, constraints, transactions, and shutdown against real MariaDB in the FiveM/Enhanced runtime.

**Acceptance criteria**

- Foreign keys and indexes guarantee uniqueness of linked identifiers and character ownership.
- A connection/migration failure prevents the Core from declaring the service ready; there is no silent fallback to KVP.
- No database secret is exposed to the client.

### 2. Core domain and lifecycle

**States**

```text
connecting -> identifying -> player_loaded -> character_selection
                                      -> character_loaded -> disconnecting -> disconnected
```

**Deliverables**

- Testable services and models to locate/create a player, list/create/select a character, and clean up a session.
- In-memory `source -> session` mapping, with a connection token/generation; invalidate it on disconnect and after restart/stop.
- Local events for player loaded, selection required, character loaded/unloaded, and session ended.
- Initial create/select UI; block spawnmanager until the server-originated character-loaded event.
- Idempotent and ordered operations; publish the Core `ready` state only after dependencies are initialized.

**Acceptance criteria**

- A player never observes another player's state after a `source` is reused.
- A character that belongs to someone else, does not exist, is archived, or is incompatible with the current state cannot be loaded.
- Failure or disconnect during a query/create leaves no partially loaded session and sends no late response to a connection that reused the same `source`.

### 3. Per-character inventory and migration

**Deliverables**

- The inventory API obtains the active character from the Core session context; client requests do not select a player inventory ID.
- Inventories and containers use their own MariaDB records; character inventories use `character:<character_id>`.
- Transfers between inventories save both snapshots in a single transaction. Snapshots are JSON in the MVP; normalization can be evaluated based on query and scale requirements.
- There is no legacy KVP import tool; data from the earlier prototype is outside the compatibility scope.

**Acceptance criteria**

- A failed transfer leaves both inventories consistent, including after a crash/restart.
- Legacy inventory without an unambiguous association is not silently assigned: it is placed in a report/quarantine for an operational decision.
- Old data remains recoverable until migration is explicitly validated.

### 4. Security and resource integration

**Deliverables**

- Migrate `coe_admin` and other consumers to player/character APIs; item grants already use the character-based inventory API. The license remains only an internal identifier for the staff list until the administrative account policy is replaced.
- Enforce server-side authorization for administrative actions and ownership checks for inventory actions.
- Rate limit by session/action, strictly validate payloads, and enforce size limits.
- Audit state bags and events: replicate only the minimum public state; keep private state on the server.

**Acceptance criteria**

- Tests demonstrate rejection of calls without a session/character, forged IDs, invalid payloads, and spam.
- There is no circular dependency between Core, inventory, admin, and database.

### 5. Testing, Enhanced, and operations

**Deliverables**

- Unit tests for domain rules with fake repositories; integration tests using real MariaDB and isolated fixtures.
- Scenarios for reused sessions, two simultaneous players, two characters on one player, invalid selection, disconnect during I/O, concurrency, and rollback.
- Inventory tests for slots, stacks, metadata, weight, transfers, failures, and restart.
- Installation, configuration, migration/rollback, events, and exports guide; logs without PII/secrets and operational metrics.

**Acceptance criteria**

- Unit and integration suites pass in the defined CI/execution environment.
- The target Enhanced server starts resources in the documented order, applies the schema, and runs the full flow without falling back to test state.
- The migration process has been rehearsed with backup and restore before being considered production-ready.

## Risks and controls

| Risk | Control |
|---|---|
| Reuse of `source` and delayed asynchronous responses | Per-session generation token, validation before each effect, and cleanup in `playerDropped` |
| Client forges events or IDs | Derive identity and ownership from server-side context; validate arguments, permissions, and current state |
| Partial failure while moving items | MariaDB transaction for related changes |
| Data from the earlier prototype | No compatibility or import; MVP starts with new storage |
| Exposed credentials | Server-only convars, secret outside the workspace, and rotation if it has already been committed |
| Incompatible Enhanced runtime or driver | Pin supported version, validate on target FXServer, and do not promote without integration testing |

## References

- [Cfx.re: Secure your events](https://docs.fivem.net/docs/developers/server-security/)
- [Cfx.re: Network and local IDs](https://docs.fivem.net/docs/scripting-manual/networking/ids/)
- [Cfx.re: JavaScript runtime](https://docs.fivem.net/docs/scripting-manual/runtimes/javascript/)
- [Cfx.re: OneSync](https://docs.fivem.net/docs/scripting-reference/onesync/)
- [Cfx.re: Legacy vs Enhanced](https://docs.fivem.net/docs/developers/legacy-vs-enhanced/)
- [mysql2](https://github.com/sidorares/node-mysql2)
