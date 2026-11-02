# coe_supervisor

Ordered restart of framework resources, without restarting the server.

Does not declare `dependencies`: it must remain running when any managed resource is stopped. Add `ensure coe_supervisor` to `server.cfg`, before the other `coe_*` resources.

## How it works

1. Reads the dependency graph (`dependency` and `dependencies` in `fxmanifest`) for all resources.
2. The target and all **started** resources that depend on it (directly or indirectly) form the affected set.
3. Stops dependents first and the base resource last (reverse order).
4. Starts from the base resource to dependents (stable topological order) and waits for each to reach `started`; a timeout or failure aborts and logs to the console.

The plan is pure (`plan.lua`) and tested in `test/plan_test.lua`. Circular dependencies are rejected (`dependency_cycle`).

## Exports (only for resources with the `coe.supervisor` ACE; default: `coe_staff`)

- `List()`: managed resources with `state`, `description`/`version` (from fxmanifest), `dependencies`, `dependents`, `restart` (order to be followed), and `replacedBy` (package replacing the basic resource, if any).
- `Restart(name, requesterSource)`: `true` or error code (`forbidden`, `restart_in_progress`, `resource_not_managed`, `dependency_cycle`, `resource_replaced`). Only one restart at a time.
- `GetUpdateStatus()`, `CheckForUpdates()`: version-check status (`nil` for callers without ACE).
- `ApplyUpdate(requesterSource)`: applies the verified update; `false, 'forbidden'` for callers without ACE.

Operator authorization is based on the caller (`coe_staff`'s F10 panel checks the player's `coe.staff.*` ACEs). Another panel is authorized in `server.cfg`: `add_ace resource.meu_painel coe.supervisor allow`. The final result is sent to the requester through `coe_notify`.

Internal `fs_writer.js` exports (`WriteFile`, `ReadFile`, `HashFile`, `DownloadFile`, `CommitFile`, `DiscardFile`, `VerifySignature`) only accept calls from `coe_supervisor` itself, receive `(resource, caminho relativo)`, and reject any path outside the resource folder.

## Updates and integrity

`coe_update apply` (console) or the F10 panel applies the release announced in the repository's `version.json`:

1. The manifest is fetched only over HTTPS. If `Updater.PublicKey` is configured, `version.json.sig` (Ed25519) must be valid; `RequireSignature = true` refuses updates without a key.
2. Files are fetched from the release **tag** (`RawRepoUrl/<tag>/<resource>/<arquivo>`), never from a branch.
3. Only managed resources are included (`Managed`, those in the installed `version.json`, and the supervisor itself); any other name in the manifest is ignored.
4. **Phase 1**: each file is downloaded and checked against the manifest's SHA-256. A tampered, missing, or unhashed file aborts the entire update without writing anything.
5. **Phase 2**: after all files have been verified, they are written. A `config.lua` edited by the owner (different from the installed version) is preserved and the new version is saved as `config.dist.lua`; a config that is merely old receives the new version.

### Manifest signature

1. `node tools/sign_manifest.js --keygen` generates `coe-manifest.key` (private; never commit) and displays the public key.
2. Paste the public key into `SupervisorConfig.Updater.PublicKey` and store the private key as the `COE_MANIFEST_KEY` secret.
3. After `lua tools/bump_version.lua <versão>`, run `node tools/sign_manifest.js` (with `COE_MANIFEST_KEY` or `COE_MANIFEST_KEY_FILE`) and commit `version.json.sig` alongside `version.json`: the supervisor fetches the signature next to the manifest (`ManifestUrl .. '.sig'`). `release.yml` attaches `.sig` to the release when it exists.

Tests: `test/updater_test.lua` (plan, SHA-256, config), `test/apply_test.lua` (verify-and-apply flow with simulated HTTP and disk), and `node --test test/fs_writer.test.js` (path confinement, HTTPS, hash, and signature).

## Configuration

`config.lua`: `Managed` (framework resources), `Catalog` (category and criticality for each; anything not listed becomes `other`), `StopTimeoutMs`, `StartTimeoutMs`, and `Updater` (`ManifestUrl`, `RawRepoUrl`, `PublicKey`, `RequireSignature`, `TimeoutMs`). The `coe_updater_manifest_url` and `coe_updater_raw_repo_url` convars override the URLs.

Third-party packages and scripts can be added without editing the framework by declaring the following in their own `fxmanifest.lua`:

```lua
coe_supervisor 'business'          -- categoria (infrastructure, core, interface, gameplay, business, administration...)
coe_supervisor_critical 'yes'      -- opcional: reiniciar pode derrubar o servidor
```

Dependents outside `Managed` (e.g., third-party scripts that depend on the core) are also restarted so they are not left broken.

## Replacing basic resources with packages

Basic resources that a complete package can take over declare `coe_supervisor_replaceable 'yes'` in `fxmanifest.lua`
(`coe_bank`, `coe_mobile`, `coe_staff`, `coe_workpad`). The package declares what it replaces in its own fxmanifest:

```lua
coe_supervisor_replaces 'coe_mobile'
```

- **Boot**: with the package installed, the supervisor cancels startup of the basic resource (`onResourceStarting`), even if the package starts later alphabetically. The console shows `resource_replaced resource=<basic> by=<package>`.
- **Package did not start** (not in `ensure` or failed): when the server settles (`Replacements.SettleMs` without resources starting or stopping), the basic resource starts (`resource_restored`).
- **At runtime**: a package starting later stops the basic resource; a package stopping brings the basic resource back. A manual `ensure` of the basic resource while the package is running is rejected and `Restart` responds `resource_replaced`. `List()` reports `replacedBy`.
- Only basic resources with `coe_supervisor_replaceable` can be replaced: a package cannot stop the core.
- The framework does not name the package; the package declares itself. The basic resources' `Yield` exports remain an alternative.

The rules are in `replace.lua` and tested in `test/replace_test.lua`. Set `Replacements.Enabled = false` to disable.

In the console, `coe_upgrades` shows the live FROM > TO map: each basic resource, its replacement, and their states. If the active package exposes `UpgradeStatus()`, the next line shows what it imported from the basic resource. Players need the `command.coe_upgrades` ACE.

## Limitations

Restarting `coe_core` unloads online players' sessions and characters; test in-game before using with connected players. This resource uses `print` for logs because `coe_logging` may be stopped.

## Refresh before starting

By default, the supervisor runs `refresh` between stopping and starting (`RefreshBeforeStart`, waits `RefreshWaitMs`), so the server reloads the `fxmanifest` of resources that gained or renamed files. Without this, the client would load new scripts without the new files.

## API reference

[Exports, parameters, and error codes](../reference/coe_supervisor.md), generated from [`types.lua`](types.lua).
