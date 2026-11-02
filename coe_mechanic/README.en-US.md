# coe_mechanic

Vehicle mechanics (#140). Parts and service by mileage, visual tuning/paint/livery, workshops and quotes (`coe_businesses`), crafting workbenches (`coe_crafting`), stashes (`coe_inventory`), and the Diagnostics app on the tablet (`coe_tablet`). Future phases: repairs and bodywork, engines and transmissions, dyno, charges, and invoices (#140).

## Parts

Each part wears based on `coe_vehicles` mileage since it was last replaced (no timers). Unregistered vehicles use factory mileage (0 km), so cars that have already been driven arrive worn.

| Part | Life | Effect when worn |
|---|---|---|
| engine_oil | 20 km | less power, more engine damage |
| air_filter | 30 km | less power |
| spark_plugs | 40 km | less power |
| brake_pads | 35 km | less braking |
| brake_discs | 80 km | less braking |
| clutch | 90 km | slower gear changes |
| suspension | 100 km | weaker suspension and anti-roll bar |

No effect until each part's `threshold`; after that, the effect increases up to the maximum. Wear is applied to handling by `coe_handling` (multipliers through `GetEffects`). Everything is configurable in `config.lua`.

## API (server)

`Inspect`, `ReplacePart`, `ServiceVehicle`, `AdjustMileage`, `AddWear`, `GetEffects`, `ListParts`, `IsReady`. Writes are restricted to `WriterResources`; `AdjustMileage` also requires the resource to be in `coe_vehicles`'s `MileageEditors`. Local event `coe_mechanic:partsChanged(vehicleId)`. See `types.lua`.

**Extra wear** (`AddWear(vehicleId, meters, parts)`, `WearResources` only): adds meters to part wear (`extra_wear_m` column, migration 4) without changing mileage. `coe_fuel` adds it with regular gasoline (spark plugs, air filter, and oil wear sooner) and subtracts it with premium gasoline (only the extra wear already accumulated). Replacing a part resets the extra wear.

## Commands (ACE `command.<name>` or console)

- `coe_parts <plate>`: inspect in the console.
- `coe_part_replace <plate> <part|all>`: replace one part or perform a service.
- `coe_mechanic_mileage <plate> <km>`: adjust mileage (audited).

## Visual tuning, paint, and livery (phase 2)

Appearance is saved per vehicle (`coe_vehicle_appearance`, validated JSON) and published in the `coe:appearance` state bag; the client applies it when loading the vehicle. Includes: GTA colors (primary, secondary, pearlescent, wheels, interior, dashboard), free RGB color, mods (`SetVehicleMod` by type), turbo/smoke/xenon, **livery** (native to the model or mod 48, used when offered by the model), windows, plate, wheel type, xenon color, neon, and extras.

- The server only accepts known fields within limits (`config.Appearance`); the client also checks the number of mods supported by the model, so nonexistent indices are ignored.
- `QuoteAppearance` calculates the estimate as a fraction of the vehicle catalog value, with a class multiplier and a level surcharge (`config.Pricing`). Removing an item is free. Charging is not implemented yet: the caller (`coe_economy`/tablet) charges first and then calls `SetAppearance`.
- Client: `coe_appearance_options` (in the vehicle) prints the mods, liveries, and extras supported by the model; the `GetVehicleOptions(vehicle)` export is for the future UI.
- Commands (ACE `command.<name>`): `coe_paint <plate> <primary> [secondary]`, `coe_livery <plate> <index>`, `coe_tune <plate> <modType> <index>`, `coe_appearance_quote <plate> <modType> <index>`.

Pending: preview camera, stance, and LightingControl with effects.

## Workshops and quotes (Benny's)

Workshops are **no longer defined in the config**: each is a business in the *Mechanics* category, created in the **Businesses** tab of `coe_admin` (work area, showroom, stashes, crafting tables, and rules), and stored in `coe_businesses`. If no business is registered, no workshop appears in-game. `config.Shops` is only an in-memory table populated from the registry. Rules: `ownerAccess` (owner can serve customers; default true) and `priceMultiplier` (applied to the quote; the mechanic can still adjust within the limits). Recipes are in `config.Recipes.mechanic` and registered with `coe_crafting` (category `mechanic`).

Client flow:
1. Drive into the showroom (you need the vehicle key) and press **E**.
2. Build the list (colors, parts, turbo/xenon/smoke, windows, livery). Preview is local, on the vehicle itself, and is reverted when exiting; the price estimate comes from the server.
3. **Request quote** opens a request (one per vehicle; expires with no response, `Orders.TtlMs`).
4. The mechanic sees the request on the tablet (Diagnostics app, **Quotes** tab), adjusts the price within ±50% of the estimate, and sends it with a note.
5. The client approves or declines. Once approved, the mechanic **performs the service** (must be within `TabletRadius` of the vehicle): appearance is saved and published.

Server rules: key, vehicle, and player must be inside the showroom; request states (`requested → quoted → approved → done`); only the client who owns the request can approve; only a mechanic on the workshop team (`coe_businesses:Access`, clocked in) within the area (`ShopWorkRadius`) can price or perform the service. Requests are stored in memory. Charging is handled through `deps.charge` when connected to `coe_economy`; the service is currently free.

### Showroom interface and camera

- Category tabs: Colors, Body, Performance, Wheels, Interior, Lights, and Livery (a dot marks tabs with changes).
- Selectors: stepper + slider for parts, toggles for turbo/xenon/extras, named palette and free selector (RGB) for paint, wheel types, windows, and neon (4 sides + color).
- Orbital camera with presets (front, side, rear, top, wheels, engine, cabin), **interior** (driver's head; drag to look around, wheel adjusts FOV), drag to rotate, mouse wheel to zoom, and automatic rotation.
- **Free camera**: WASD, E/Q to move up/down, Shift to speed up, Ctrl to slow down, Backspace to exit. Limited to the workshop radius (`Camera` in `config.lua`).
- The vehicle is frozen while the showroom is open.

Pending: automatic charging through `coe_economy`, consuming items from `coe_inventory` during application, physical part replacement, and bodywork.

## Business: owner, crafting bench, and stash

- **Owner** (by character): set in the **Businesses** tab of `coe_admin`, in the business's own panel (character ID, the same as `/id`; works when the character is offline) and stored in `coe_businesses`. The owner has full access to the workshop tablet and can serve as a mechanic even without the job (`ownerAccess` rule); without an owner, the workshop job applies. Export `GetShopOwner(shopId)`. The `coe_shop_owner` command and `coe_mechanic_businesses` table are no longer used.
- **Clock-in** (`clocks`, `clockRequired`, and `clockOffsite` rules in `coe_businesses`): the registered workshop team (Team tab; the job does not grant access) must clock in to serve customers; the owner must also clock in unless `clockRequired = false`. Clock in at the marked point (E, inside the area) or, if the workshop has none, with `/ponto` inside the area; `/ponto` also clocks out from anywhere. Without `clockOffsite`, leaving the area ends the shift (checked every 5 s).
- **Crafting workbenches** (`crafts`: list of points; recipes in `Recipes.mechanic`): owner and clocked-in team only. Execution and the interface are handled by `coe_crafting` (mechanics only determine the point and who has access). The interface shows what each recipe consumes (have/need). Production takes `timeMs` with an animation; the server rechecks team, distance, and materials at completion, consumes supplies, and grants the part (if it does not fit in the backpack, supplies are returned). One production at a time; leaving the area or closing the interface cancels it. New items (rubber, plastic, repair kit, and workshop parts) are in `coe_inventory/data/coe_parts.lua`.
- **Stashes** (`stashes`: list of points with slots and weight): owner and team only, opened through `coe_inventory`'s `OpenStash` (`stash:mechanic:<workshop>` for the `main` stash, otherwise `stash:mechanic:<workshop>:<stash>`), which closes automatically if the player moves away. Contents persist. Events: `openCraft/openStash(shopId, stationId)`.
- **Interaction prompt**: in the top-left corner, using the same appearance as the HUD location panel, shows the workshop and the option with the **E** key (showroom while inside a vehicle; workbench and stash on foot, for team members only).
- Benny's workbench and stash coordinates are provisional: adjust them in `config.lua` in-game.

## Limitations

Quote charges (`deps.charge` through `coe_economy`) and consuming `coe_inventory` parts during replacement are not connected yet (#140); replacements are performed through the tablet Diagnostics app, by anyone in `WriterResources`, or through administrative commands. Values need in-game tuning.
