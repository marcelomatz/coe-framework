# coe_vehicle_catalog

Unified vehicle catalog for the framework: GTA V native vehicles and addons streamed as resources. Used by the dealership (#141), mechanic (#140), handling (#139), and garages.

## Sources

- **Native vehicles:** `data/native_vehicles.lua` (model, name, make, class, type, seats). The server cannot query the game, so this list is the source of truth; expand it as needed.
- **Addons:** on each resource start/stop, the catalog reads `data_file` entries `VEHICLE_METADATA_FILE` (vehicles.meta) and `HANDLING_FILE` (handling.meta) declared in `fxmanifest` and rebuilds the index (with debounce). Paths containing `*` are not supported and generate a warning.
- **Overrides:** price, stock, category, and hidden status, stored in `coe_vehicle_overrides` without editing the addon resource.

Known limitations: addons have no class (they remain `unknown`) or seats until they receive an override/seed; the parser reads only scalar handling fields and expects `<modelName>` to be the first field for each vehicle.

## Validation

`GetIssues()` / `coe_catalog_issues` list: `duplicate_model`, `duplicate_handling`, `replaces_native`, `handling_missing`, `unknown_vehicle_type`, `invalid_model_name`, `meta_file_not_found`, `glob_not_supported`.

To check files outside the server (CI/CLI):

```
cd coe_vehicle_catalog
lua tools/check.lua caminho/vehicles.meta caminho/handling.meta
```

Exits with code 1 if there are errors.

## Exports (server)

`GetVehicleInfo(model)`, `ListVehicles(filtro)`, `GetBaseHandling(model)`, `GetIssues()`, `IsReady()` (any resource); `SetOverride(model, campos)`, `ClearOverride(model)`, `Rescan()` (only callers with the `coe.vehicles.catalog` ACE, e.g., `add_ace resource.coe_admin coe.vehicles.catalog allow`). Full contract in `types.lua`.

## Commands (ACE)

`coe_catalog_rescan`, `coe_catalog_issues`, `coe_catalog_info <model>`.

## Tests

```
cd coe_vehicle_catalog
lua test/catalog_test.lua
```

## Out of scope

Validation that a model exists in-game (requires a client), packaging conventions, and licensing for third-party models (research pending in #138).
