# Test coverage map

Which automated tests each resource has, what CI runs, and what still requires in-game testing.
Update this page when adding or removing a test file.

## What CI runs

| Stage | Command | Where |
| --- | --- | --- |
| Lua unit tests (83 files) | `lua test/<file>.lua` inside each resource | `ci.yml` and `release.yml` |
| Contracts, access, HAL, and i18n | `lua tools/check_contracts.lua --strict --audit-natives --audit-locales` | `ci.yml` and `release.yml` |
| Up-to-date API reference | `lua tools/gen_reference.lua --check` | `ci.yml` and `release.yml` |
| Smoke boot (runtime chunks and locales) | `lua tools/smoke_boot_test.lua` | `ci.yml` and `release.yml` |
| Open-core boundary | `lua tools/check_boundary.lua` | `ci.yml` and `release.yml` |
| Database (Node) | `node --test test/access.test.js test/provider.test.js test/validation.test.js` in `coe_database` | `ci.yml` and `release.yml` |
| Supervisor (Node) | `node --test test/fs_writer.test.js` in `coe_supervisor` | `ci.yml` and `release.yml` |
| UI and HUD DOM (jsdom) | `node --test test/*.test.js` in `coe_ui` and `coe_hud` | `ci.yml` |
| MariaDB integration | `node --test test/integration/integration.test.js` in `coe_database` (MariaDB 11.4 service) | `ci.yml` |
| Version, tag, and manifest hashes | `lua tools/bump_version.lua --check --tag <tag>` | `release.yml` |

`check_contracts` also fails when:

- A resource with exports has no `types.lua`, or an export is not annotated in it.
- A framework resource calls a protected export without being on the target's default allowlist (`coe_database`,
  `coe_vehicles`, `coe_economy`, `coe_talk`, `coe_supervisor`).
- A file declared in `fxmanifest.lua` does not exist.
- Keys are missing in either direction between `locales/pt-br.lua` and `locales/en-us.lua`.

## By resource

| Resource | Lua (`test/`) | Node (`test/`) | MariaDB integration |
| --- | --- | --- | --- |
| `coe_appearance` | `schema_test`, `thumbs_server_test` | | |
| `coe_audit` | `audit_test` | | `audit_scenario` |
| `coe_bank` | `rules_test`, `server_test` | | |
| `coe_businesses` | `access_test`, `duty_test`, `extensions_test`, `grades_test`, `registry_test`, `tablet_test` | | `jobs_businesses_scenario` |
| `coe_characters` | `client_test` | | |
| `coe_core` | 15 files (identity, profile, groups, lifecycle, migrations, platform, locale, semver, hash, access) | | `core_scenario` |
| `coe_database` | | `access.test`, `provider.test`, `validation.test` | `integration.test` (scenario runner) |
| `coe_economy` | `rules_test`, `server_test` | | `commerce_scenario`, `jobs_businesses_scenario` |
| `coe_garage` | `domain_test`, `service_test` | | `garage_mobile_scenario` |
| `coe_hud` | `client_hud_test`, `logo_test`, `prefs_test`, `route_test` | `editor.test`, `speedo.test` | |
| `coe_inventory` | 9 files (service, containers, stash, weapons, persistence, world concurrency, presentation) | | `inventory_scenario`, `commerce_scenario` |
| `coe_jobs` | `career_test`, `guide_test`, `jobs_test`, `rules_test`, `server_test` | | `jobs_businesses_scenario` |
| `coe_loadscreen` | `client_test` | | |
| `coe_logging` | `logging_test` | | |
| `coe_map` | `client_map_test` | | |
| `coe_mobile` | `persistence_test`, `rules_test`, `server_test` | | `garage_mobile_scenario` |
| `coe_needs` | `needs_test`, `service_test` | | `needs_scenario` |
| `coe_notify` | `client_notify_test`, `server_notify_test` | | |
| `coe_rentals` | `rentals_test`, `server_test` | | |
| `coe_shops` | `client_test`, `rules_test`, `server_test` | | `commerce_scenario` |
| `coe_spawn` | `client_test`, `positions_test` | | |
| `coe_staff` | `rules_test`, `server_test` | | |
| `coe_supervisor` | `ansi_test`, `apply_test`, `plan_test`, `replace_test`, `updater_test` | `fs_writer.test` | |
| `coe_talk` | `client_talk_test`, `rules_test`, `server_main_test`, `server_talk_test` | | |
| `coe_ui` | | `components.test` | |
| `coe_vehicle_catalog` | `catalog_test` | | `vehicles_scenario` |
| `coe_vehicles` | `keys_test`, `vehicles_test` | | `vehicles_scenario` |
| `coe_workpad` | `rules_test`, `server_test` | | |
| `coetarget` | `client_test` | | |

`all_migrations_scenario` runs every database-backed resource's migrations twice on a new database and fails if a repository `migrations.lua` file is left outside that database.

## Known gaps

- Real natives, NUI, and network behavior are exercised only in-game: follow the portal's `INGAME_CHECKLIST` before each release.
- The FXServer Lua ↔ Node exports bridge and real `GetInvokingResource()` are simulated in tests; authorization is checked statically by `check_contracts` (access contract) and with stubs in server tests.
- `coe_appearance`, `coe_characters`, `coe_loadscreen`, `coe_map`, and `coetarget` have only rules/client tests; visual behavior depends on the game.
- MariaDB integration does not yet cover `coe_staff`, `coe_bank` (uses the economy), `coe_spawn` (migrations only), or `coe_vehicle_catalog` beyond migrations.
