# coe_core

`coe_core` is the shared foundation of the framework. It does not load inventory, administrative UI, or a target system.

## Architecture

Resources follow a modular layered architecture inspired by Clean/Hexagonal Architecture:

- **Domain:** module-specific models and rules, with no direct access to NUI or persistence.
- **Application:** coordinates use cases, validates inputs, and defines resource flows.
- **Adapters:** connect events, FiveM exports, and external providers.
- **Presentation:** client scripts and NUI interfaces.

Resource boundaries are deployment modules. Dependencies should point inward to the required capabilities, never back to Core:

```text
coe_admin ───────> coe_inventory ───────> coe_core ───────> coe_database
coe_characters ─────────────────────────>   |
coe_spawn ──────────────────────────────>   +─────────────> spawnmanager
coetarget (integração de interação usada por coe_inventory)
coe_core, coe_inventory, coe_admin, coe_database ─────────> coe_logging
coe_core, coe_inventory, coe_admin, coe_characters ───────> coe_notify
```

The diagram shows only the foundation; today, nearly all `coe_*` resources depend on `coe_core` (complete map in `ARCHITECTURE.md` in coe-docs). `coe_core` does not depend on `coe_inventory` or `coetarget`. Identity and characters use their own MariaDB repositories through the `coe_database` provider. `coe_inventory` and `coe_admin` persist their own MariaDB data through their respective resource adapters; Core does not provide generic persistence or maintain these modules' business rules. `coe_logging` and `coe_notify` are independent infrastructure resources: logging is server-side and does not depend on the database; notifications are an explicit UX output, never an automatic projection of logs.

## Startup

Start `coe_core` before resources that import it. This workspace also starts `coe_inventory` before `coe_admin`:

```cfg
ensure coe_logging
ensure coe_notify
ensure coe_database
ensure coe_core
ensure coe_spawn
ensure coe_characters
ensure coe_inventory
ensure coe_admin
ensure [coelho]
```

`basic-gamemode` must not be started alongside the selection flow: it forces a respawn before there is an active character. `coe_spawn` keeps the player unable to move until server-side selection and uses `spawnmanager` only after Core confirms the character.

## Importing APIs

A resource that needs only the foundation should declare:

```lua
dependency 'coe_core'
shared_script '@coe_core/lib/init.lua'
```

A resource that also needs the inventory API can declare:

```lua
dependencies {
	'coe_core',
	'coe_inventory'
}
shared_script '@coe_core/lib/init.lua'
shared_script '@coe_inventory/lib/init.lua'
```

This makes `Core` and, when requested, `Inventory` available on the client and server. Without `lib/init.lua`, `exports.coe_core:GetCoreObject()` returns the `Core` object (events, players, groups, and states) on the server and client. Inventory and catalog APIs belong to `coe_inventory`, not `Core`.

### Migrating from the previous API

Scripts that used `exports.coe_core` for inventory operations should switch to `exports.coe_inventory`. Lua scripts that accessed `Core.Items` should import `@coe_inventory/lib/init.lua` and use `Inventory.Items`. The old `ensure coe_core` configuration must be supplemented with `ensure coe_inventory`. The event bus prefix remains `coe_core:`.

## Core APIs

- `Core.Functions`: `DeepCopy`, `IsInteger`, `IsValidName`, and `Trim`.
- `Core.Classes`: class registration, inheritance, and checks.
- `Core.Events`: local and network events with the `coe_core:` prefix.
- `Core.States`: access to replicated GlobalState. Do not publish private data or secrets.

Network events are untrusted inputs: validate `source`, arguments, permissions, and frequency in the resource implementing the use case.

### Script map

- `core/shared/bootstrap.lua`, `functions.lua`, `identity.lua`, `classes.lua`, `events.lua`, `states.lua`: shared API and contracts without persistent I/O.
- `core/server/database.lua`: validated facade for asynchronous `coe_database` exports.
- `core/server/migrations.lua`: ordered, versioned application of Core migrations. Each step is an SQL string or a Lua `function(done)` (used to populate `state_id` in migration 2). Current migrations: 1 identity (`coe_players`, `coe_player_identifiers`, `coe_characters`), 2 `state_id` (population in Lua), 3 required `state_id`, 4 `coe_player_settings` (slots), 5 character profile, 6 groups (`coe_groups`, `coe_character_groups`), and 7 name-search indexes (`first_name`/`last_name` with `archived_at`), used by `coe_admin` player search. Back up the database before deploying a version with a new migration (#46).
- `stateId`: public character identity (8 characters from `ABCDEFGHJKMNPQRSTUVWXYZ23456789`), generated server-side by `Core.Identity.GenerateStateId` and unique in the database (`UNIQUE`; creation retries on collision). It is not a secret. `characterId` remains the internal key.
- `lib/migrations.lua`: generic executor (`CoeMigrations.Run`) used by other resources with persistence; each has its own `*_schema_migrations` table.
- `core/server/player_repository.lua`: player/character queries and transactions.
- `core/server/session_registry.lua`: transient connection states and session generation.
- `core/application/player_service.lua`: identity, selection, creation, archival, and lifecycle use cases.
- `core/server/player_lifecycle.lua`: connection lifecycle and FiveM request/event adapter, including the `player.clientReady` handshake that resends character selection to sessions in `character_selection`.
- `core/server/init.lua`: database-dependent initialization, `ready` state, and shutdown.
- `core/client/init.lua` and `lib/init.lua`: access to the shared object in the corresponding contexts. `lib/init.lua` redefines `Core.Events.On`, `OnNet`, `Remove`, and `Core.Classes` (`Register`, `Get`, `Is`, with local registration) in each consuming resource: functions returned by exports execute in `coe_core`, which would register handlers in the wrong resource, leave `source` incorrect, and cause class instances to lose their metatable (methods) when returned through the export.

## Tests and gaps

Run from the resource folder:

```powershell
lua test\identity_lifecycle_test.lua
lua test\player_service_test.lua
lua test\migrations_test.lua
lua test\group_definitions_test.lua
lua test\group_service_test.lua
lua test\migration_runner_test.lua
lua test\player_lifecycle_test.lua
lua test\lib_init_test.lua
lua test\player_repository_test.lua
lua test\character_profile_test.lua
```

These tests cover identity, character profile, groups, invariants and service operations, migrations, and part of lifecycle registration/shutdown. The MariaDB integration scenario (`coe_database/test/integration/core_scenario.lua`) applies migrations twice and exercises the repository. Repository integration against MariaDB, the real bridge with Node 26 (libnode26), a full session on FXServer Enhanced, and the startup contract must be validated in the target runtime. The overall matrix is in [TEST_COVERAGE.md](../TEST_COVERAGE.md).

## Observability and gameplay feedback

`coe_logging` provides structured server-side logs with a resource allowlist, permitted context fields, and configurable minimum level. Audit events should use stable codes and must not include licenses, SQL, credentials, arbitrary metadata, or exception messages.

`coe_notify` provides `exports.coe_notify:Show(type, message, duration?)` on the client and `exports.coe_notify:Notify(source, type, message, duration?)` on the server to authorized resources. Notify players only about relevant outcomes; technical messages belong in logs. See the [coe_logging](../coe_logging/README.md) and [coe_notify](../coe_notify/README.md) READMEs.

## Module documentation

- [Identity and lifecycle plan](./IDENTITY_LIFECYCLE_PLAN.md): player/character model, MariaDB persistence, security, and implementation phases.
- [coe_database](../coe_database/README.md): its own MariaDB provider, asynchronous exports, and configuration.
- [coe_logging](../coe_logging/README.md): logging contract, levels, and context security.
- [coe_notify](../coe_notify/README.md): client/server notification NUI library.
- [coe_inventory](../coe_inventory/README.md): catalog, items, containers, exports, and configuration.
- [coe_staff](../coe_staff/README.md): basic staff panel and ACE permission model.
- [coe_characters](../coe_characters/README.md): character selection, creation, and archiving.
- [coe_spawn](../coe_spawn/README.md): spawn integration conditioned on lifecycle.
- [Test map](../TEST_COVERAGE.md): automated coverage and integration gaps.
- [Changelog](https://docs.coeroleplay.app/#doc=CHANGELOG.md): release history and documented changes.

## Character slots

The effective limit is the player's value in `coe_player_settings.character_slots` or, if null, the `coe_max_characters` convar (default 5), always capped by `coe_max_characters_hard` (default 10). Set per player with `Core.Players.SetCharacterSlots` (internal use; authorization belongs to `coe_admin`).

## Character profile

`character.createRequest` accepts an optional `profile` (`birthDate` `YYYY-MM-DD`, `gender`, `appearance` + `appearanceVersion`). The server validates everything and rejects unknown keys. Rules: `coe_character_min_age` (18), `coe_character_max_age` (90), and `coe_character_genders` (`male,female`) convars. Appearance is opaque to Core (up to 16 KB) and its format belongs to `coe_appearance`. It is returned in the character list, `character.selectResult`, and `player.characterLoaded` (`appearance`, `appearanceVersion`). Characters created before the creator may set their appearance once during selection: `character.appearanceRequest(requestId, characterId, appearance, version)` → `character.appearanceResult` (`Core.Players.SetInitialAppearance`; rejects with `appearance_locked` if an appearance already exists). Changing appearance later is the role of barber shops and clothing stores.

## Public identity (stateId)

- Replicated state bag `Player(src).state['coe:stateId']`: set when selecting a character and cleared when switching characters or stopping Core. Only `stateId` is replicated; `characterId` remains server-side. The client must treat it as read-only.
- Lookup across online players: `GetCharacterByStateId(stateId)` (character snapshot) and `GetPlayerByStateId(stateId)` (`source`, `playerId`, and active character); return `nil, 'invalid_state_id'` or `nil, 'character_not_online'`. Also available in `Core.Players`.
- `GetActiveCharacter(source)`: active-character snapshot for an online player, or `nil` (single return value, safe across resources); used by panels to show the character's name.
- `/id` command: the player sees their own `stateId` in a notification (2-second cooldown). This is the ID an admin provides to set a business owner.
- Local `player.characterCreated` event (`source`, `playerId`, `generation`, `character`), emitted after persisted creation.

## Groups

Core groups are the ACE layer. **Jobs, roles, and salaries belong to businesses** (`coe_businesses`), and **illegal factions** belong to `coe_factions`; the `police`, `mechanic`, and `ambulance` job groups in `config/groups.lua` are legacy and have no admin UI.

- Definitions in `config/groups.lua` (`CoeGroupsConfig`): types (`job`, `gang`), groups with `type`, `label`, and `grades` (0–255). Validated at startup; invalid configuration prevents Core from becoming ready.
- `Core.Groups.Sync` upserts into `coe_groups` (never deletes; changing an existing group's type is rejected with `group_type_changed`). Grades are not stored in the database.
- `coe_character_groups`: one active group per type per character, enforced by the database.
- API (server-side, `Core.Groups`): `GetCharacterGroups(source)` → `{ [type] = { name, grade } }` for the active character; `Has(source, name, minimumGrade?)`; `Set(characterId, name, grade, cb)` activates the group in its type and `Remove(characterId, name, cb)` deletes the link (idempotent). Groups load when a character is selected; until loading completes, or if it fails, `Has` returns false. Local event `player.groupChanged` (`source`, `characterId`, `type`, `group`, `grade`, `previous`; `source` is nil if the character is offline). The caller is responsible for authorizing `Set`/`Remove`. Exports: `GetGroupDefinitions()`, `GetPlayerGroups(source)` (read), and `SetPlayerGroup`/`RemovePlayerGroup(source, name, [grade,] cb)`, which accept only the basic `coe_staff` panel (default) and resources with the `coe.groups.admin` ACE (`add_ace resource.<panel> coe.groups.admin allow`; otherwise `forbidden`); operator authorization and maximum grade are the panel's responsibility.
- `/grupo` command (restricted to console or callers with `command.grupo`) for administering without a panel: `grupo definir <ID> <grupo> [grau]`, `grupo remover <ID> <grupo>`, `grupo ver <ID>`, and `grupo lista`. The ID is the online character's `stateId` (`/id`). Example: `add_ace group.admin command.grupo allow`.
- ACE: a loaded character inherits `coe.group.<group>` and `coe.group.<group>.<grade>`; each grade inherits the lower ones. Policy is configured in `server.cfg`, e.g. `add_ace coe.group.police.2 coe.police.arrest allow` (sergeant or higher). Principals are removed when switching characters, leaving the server, changing group, or stopping Core. Only an account with an active character receives principals; groups never grant access to the admin panel.

## API reference

[Exports, parameters, and error codes](../reference/coe_core.md), generated from [`types.lua`](types.lua).
