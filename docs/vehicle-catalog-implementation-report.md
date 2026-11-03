# Vehicle catalog implementation report

## Data source and coverage

The generated native catalog uses DurtyFree's `gta-v-data-dumps/vehicles.json`, pinned to commit `b8f9dfaee5139fe372f264df4030506d1450fd8a` (GTA V v3717.0 / Online 1.72 / `mp2025_02_g9ec`). The upstream file SHA-256 is `cbb3912a3fc3f97c452d5d51f06a78049151e91fe8597541a6f62ae4ea552911`. The committed minimized source contains 921 unique model names, all 23 native classes and 47 DLC identifiers. `python tools/generate_native_vehicles.py --check` verifies the generated Lua file against that source; `--refresh-source` fetches only the pinned URL and rejects an unexpected hash or count.

The previous framework seed contained 64 models, all present in the pinned source. The added records yield 921 candidates: 696 `CAR`, 29 `TRAILER`, 11 `TRAIN`, 4 `SUBMARINE`, 3 `BLIMP`, 58 `BIKE`, 22 `BOAT`, 32 `HELI`, 43 `PLANE`, 8 `QUADBIKE`, 9 `BICYCLE`, 3 `AMPHIBIOUS_AUTOMOBILE`, 2 `SUBMARINECAR`, and 1 `AMPHIBIOUS_QUADBIKE`. Native class counts are compacts 18, sedans 47, SUVs 49, coupes 21, muscle 96, sports classics 54, sports 123, super 63, motorcycles 59, offroad 70, industrial 12, utility 52, vans 41, cycles 9, boats 26, helicopters 31, planes 46, service 14, emergency 34, military 17, commercial 24, trains 11, and open wheel 4.

The supplied GTABase page reports 803 vehicles, a numeric difference of 118 versus this dump. Its retrieved HTML exposed a count but no verifiable model-name list, so this report does not claim model-level reconciliation or attribute the difference to particular inclusion rules. The 921 entries are source candidates, not proof that each model is spawnable or available to every client.

The user identified the target game as FiveM Enhanced through DLC 1.73 Kortz. The pinned source is v3717 / 1.72 and does not independently establish 1.73 coverage. A safe availability check is to page through the server catalog and, in a controlled Enhanced client, record `IsModelInCdimage`, `IsModelValid`, and the result of `RequestModel`/`HasModelLoaded` with a per-model timeout, without spawning entities. The check observes declared entries only; it cannot discover unlisted assets. Client results are diagnostic and must not authorize spawning.

The dump README reports 1,109 peds, 21,631 objects in its common YTYP set, and 5,883 ped props. These are counts from that source only; this repository has no generic ped/prop source or enumeration API, and this work makes no claim of complete Enhanced coverage for them.

## Catalog behavior

- `data/native_vehicles_v3717.json` pins the minimized input; `tools/generate_native_vehicles.py` deterministically emits `data/native_vehicles.lua`.
- Catalog entries retain model, display name, brand, native class ID/name, normalized entity type, seats, and DLC metadata.
- Addon metadata may replace a native record for the same model, preserving existing catalog behavior and persisted overrides.
- `ListVehiclesPage` returns stable model ordering, `offset`, `limit`, and filtered `total`, with filters for class ID, configurable category, DLC, addon, and existing search fields. `ListVehicles` remains available for bounded legacy calls.
- The staff Vehicles view uses paginated results, class/category/DLC filters, and explicit load errors with retry. Temporary staff spawns are checked against the server catalog.
- Existing admin and staff fleet catalog consumers iterate pages where they need a full list.

`classId` is the native GTA vehicle class (`GetVehicleClass`, IDs 0–22); configurable `category` is a separate framework value and can differ from the native class. DLC remains source metadata and is not inferred for addon vehicles. Server-side catalog and addon validation remain authoritative; a client-reported inventory is not trusted for authorization.

The dump maps archetype types to FiveM entity types as follows: `CAR` and `AMPHIBIOUS_AUTOMOBILE` → `automobile`; `BIKE`, `QUADBIKE`, `BICYCLE`, and `AMPHIBIOUS_QUADBIKE` → `bike`; `BOAT` → `boat`; `HELI` → `heli`; `PLANE` and `BLIMP` → `plane`; `SUBMARINE` and `SUBMARINECAR` → `submarine`; `TRAILER` → `trailer`; `TRAIN` → `train`. These are normalized metadata mappings, not claims that every entry is valid to spawn in every server context.

## Reproducible checks

- From the repository root: `python tools\generate_native_vehicles.py --check`
- From `coe_vehicle_catalog`: `lua test\catalog_test.lua`
- From `coe_admin`: `lua test\tools_server_test.lua`, `lua test\tools_rules_test.lua`, and `node test\tools_catalog_ui_test.js`
- From the repository root: `python tools\test_generate_native_vehicles.py`
- From the repository root: `lua tools\check_contracts.lua --strict --audit-natives --audit-locales`, `lua tools\smoke_boot_test.lua`, and `lua tools\smoke_boot_scripts_test.lua`

Server startup and catalog fixtures cannot prove effective client-model availability. The Enhanced client check above remains necessary before declaring build coverage exhaustive.
