# coe_fuel

Coe fuel: vehicle consumption, four fuel types, all map gas stations with branding, pumps with payment and jerry cans (stage A) and, for player-owned stations, tanks by level, owner-set price per liter, supply fleet (van → truck → tanker), refinery, and upgrades unlocked by money + liters sold (stage B).

## Fuel types

| Fuel | Engine | Price/L | Consumption | Power | Engine parts |
|---|---|---|---|---|---|
| Regular gasoline | flex | $6 | 1.00× | 1.00× | +0.5 m of extra wear per meter (spark plugs, air filter, oil) |
| Premium gasoline | flex | $7 | 0.88× (goes farther) | 1.02× | −0.25 m per meter: cleans extra wear accumulated from regular gasoline |
| Ethanol | flex | $4 | 1.30× (burns more) | 1.06× (goes faster) | — |
| Diesel | diesel | $5 | 1.00× | 1.00× | — |

- The tank stores a **mixture** (liters of each fuel). Consumption, power, and wear are averaged by liters; consumption removes each fuel in proportion.
- Power is applied to handling by `coe_handling` (the `fInitialDriveForce` field, multiplied by part wear).
- Extra wear is sent to `coe_mechanic` (`AddWear`, every 500 m accumulated) and resets when the part is replaced.
- Everything is configurable in `config.lua` (`Fuels`).

## Engines

- **Flex** (gasoline and ethanol): all vehicles except those below.
- **Diesel**: commercial, industrial, utility, service, and military classes (`DieselClasses`) and models in `DieselModels` (pickup trucks and cargo vans). `FlexModels` forces a model to use flex.
- **No fuel**: bicycles, helicopters, airplanes, and trains (`NoFuelClasses`; aircraft support is coming later).
- The pump and jerry can **block** the wrong fuel.

## Consumption

- Tank capacity and consumption by GTA class (`Classes`: liters and L/100 km), multiplied by `ConsumptionScale` (8×, map scale: a full tank lasts about an hour of driving), RPM, and mixture. Idling: `IdlePerHour`.
- The driver's client measures distance, time with the engine running, and average RPM and reports every `ReportSeconds` (5 s). The server accepts only the driver, limits time to actual elapsed time and distance to `MaxSpeed` × time, and calculates liters. Large jumps (teleports) are not counted.
- The tank is stored in the `coe:fuel` state bag (`liters`, `capacity`, `level`, `engine`, `main`, `tank`). The client sets the value through `SetVehicleFuelLevel`, so the HUD (`coe_hud`) displays it without changes. An empty tank turns off the engine.
- Registered vehicles (`coe_vehicles`) store the tank in the database (start half full); others (NPC, admin) start at 20% to 60% and are not saved.
- `/combustivel` (F8) shows the tank in the vehicle you are in.

## Stations and pumps

- 27 stations (`Stations`) with brands: **Ron**, **Globe Oil**, **Xero**, **LTD Gasoline**, and **unbranded**. Station blips use the brand color ("Ron Station", "Unbranded station"...). Brands and positions are provisional: check each station's sign in-game and adjust in the config.
- Each station is a `coe_businesses` business (`gas_station` category): `posto_<id>`, created without an owner. The five LTD stations use the `coe_shops` store business (`ltd_*`), so the store and pumps are the same business.
- **Refuel** target at all map pumps (`PumpModels`), only inside a station. The screen resembles the front of a pump with the brand identity (`Brands[...].theme`: primary color, accent, and text): LCD display with total, liters, and price per liter; product buttons with price per liter; destination (vehicle near the pump, your jerry can, or a new jerry can); liters; and payment: **cash**, **phone Wallet**, or **card at the terminal** (with PIN), as in stores.
- While refueling, a **display** in the corner of the screen counts liters and total up to the amount paid, in the brand color. Time is proportional to liters (`PumpRate`, 2.5 L/s at the pump; `Can.pourRate`, 2 L/s from a jerry can), and the vehicle's fuel gauge rises along with it.
- Revenue goes to the business register (`SocietyCollect`, reason `fuel_sale`); the sale is recorded in `coe_fuel_sales`.
- **Staff station** (no owner): unlimited stock and list price. **Player-owned station**: sells only what is in its tanks, at the owner's price.

## Player-owned stations: tanks, fleet, and refinery

Everything is managed from the business app's **Station** tab on the tablet (`coe_businesses`), which shows liters sold (history), today's and 7-day sales, register, tanks, prices, fleet, and refinery GPS.

- **Price per liter**: the owner (or position with `fuel.manage`) sets each fuel between 0.5× and 3× its list price (`PriceBand`), or resets it to the list price.
- **Tanks by level** (`TankLevels`), one level per fuel: 5,000 L → 10,000 L ($20,000 + 10,000 L sold) → 20,000 L ($50,000 + 40,000 L) → 40,000 L ($120,000 + 120,000 L).
- **Supply fleet** (`FleetTiers`), purchased in order: **Small van** (`speedo`, 800 L, $8,000) → **Truck** (`benson`, 3,500 L, $45,000 + 15,000 L sold) → **Tanker truck** (`phantom`, 12,000 L, $150,000 + 80,000 L sold). Each purchase creates a registered vehicle (`coe_vehicles`) in the **station fleet garage** (`coe_garages`), available to the team. Staff must create this garage (Business type, linked to the station) in the admin Garages tab; without one, the purchase is declined and no money is charged.
- **Operating history**: liters sold by the station as a player-owned station (`coe_fuel_sales`, mode `player`).
- Upgrades and wholesale fuel are paid from the **station register** (`SocietyCharge`: `fuel_tank_upgrade`, `fuel_fleet_upgrade`, `fuel_refinery`).
- **Refinery** (`Refinery`, map blip; provisional position): with the fleet vehicle parked there, the **Load fuel** target opens the loading screen: liters of each fuel (whole numbers, totaling up to the vehicle capacity), wholesale price per liter (`Refinery.prices`), cost, and register. The load is stored on the vehicle (state bag `coe:fuelCargo` and database), including after it is stored.
- **Unload**: at the station itself, the **Unload at station** target transfers the cargo into the tanks until they are full; anything that does not fit remains in the vehicle.
- Loading and unloading show the display on screen and take time proportional to the liters (`LoadRate`, 100 L/s).
- **Who can do it**: the owner or clocked-in team with `fuel.supply` can load and unload (Station: refinery loading); the owner or someone with `fuel.manage` can manage prices and upgrades (Station: prices and upgrades).
- Staff can still correct a tank with `coe_fuel_tank <station> <fuel> <liters>`.

## Jerry can

Item `fuel_can` (`coe_inventory`, 20 L, metadata `{ fuel, liters }`). At the pump: new jerry can ($60 + fuel) or refill one of yours (an empty can accepts any fuel). **Using** it in the inventory pours into the nearest vehicle (up to 3.5 m), checking the engine.

## Database

| Table | Contents |
|---|---|
| `coe_fuel_vehicles` | Tanks for registered vehicles: engine, capacity, and liters of each fuel. |
| `coe_fuel_tanks` | Player-owned station tanks: liters and level of each fuel. |
| `coe_fuel_prices` | Owner-set price per liter (no row = list price). |
| `coe_fuel_fleet` | Supply fleet vehicles: station, level, and cargo for each fuel. |
| `coe_fuel_sales` | Sales: station, character, fuel, liters, total, payment, destination, and mode. Basis for upgrade operating history. |

Migrations in `coe_fuel_schema_migrations`.

## Exports (server)

| Export | Return |
|---|---|
| `IsReady()` | `true` after migrations and tank data have loaded. |
| `GetFuel(vehicleId)` | Tank summary for a registered vehicle in use, or `nil`. |
| `GetEffects(vehicleId)` | `{ mods = { fInitialDriveForce }, key }` for the mixture (used by `coe_handling`). |
| `GetStationTanks(stationId)` | `{ business, tanks, levels, capacities }` for station tanks. |
| `IsStation(businessId)` | `true` if the business is a station (tablet Station tab). |
| `BusinessTablet(playerId, characterId, businessId, payload)` | Station tab (registered tab handler; called only by `coe_businesses`): `op` `overview`, `price`, `upgradeTank`, or `upgradeFleet`. |

Local event `coe_fuel:effectsChanged(vehicleId)` when the mixture changes engine power.

## Commands (ACE `coe_fuel.manage` or console)

- `coe_fuel_tank <station> <fuel> <liters>`: sets a player-owned station tank.
- `coe_fuel_fill [player id] [fuel]`: fills the player's vehicle tank (testing).

## Dependencies and permission allowlists

`coe_core`, `coe_database`, `coe_logging`, `coe_inventory`, `coe_businesses`, `coetarget`; at runtime `coe_vehicles`, `coe_mechanic`, `coe_economy`, `coe_banking`, `coe_phone`, `coe_audit`, `coe_notify`. In the framework, capabilities come from the framework (`CoeAccess.FirstParty`: banking, money, business register, logs, audit, notifications, business records, position permissions, and tabs), and `coe_supervisor` reads `coe_supervisor 'business'` from `fxmanifest`. The **Station** tab is registered through `coe_businesses:RegisterTab` (visible where `IsStation` returns `true`). In packages: `coe_banking` (`Credit.PurchaseCallers`), `coe_phone` (`Wallet.PaymentCallers`), `coe_mechanic` (`WearResources`), and `coe_garages` (`FleetResources`).

Audit events: `fuel_sale`, `fuel_tank_set`, `fuel_price`, `fuel_tank_upgrade`, `fuel_fleet_upgrade`, `fuel_refinery_load`, `fuel_unload`.

## Tests

`test/rules_test.lua` (catalog, engine, mixture, consumption, effects, price, stations), `test/server_test.lua` (registered and unregistered tanks, validated consumption, wear and effects, pump with the three payment methods, wrong fuel, jerry can, player-owned station with stock, commands, Station tab, prices, tank and fleet upgrades, refinery and unloading), and `test/client_test.lua` (blips, target, tank request, report, native level, engine shutoff, display, fleet target).
