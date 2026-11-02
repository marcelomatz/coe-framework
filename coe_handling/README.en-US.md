# coe_handling

Simulator-style handling by class/category, affected by tire type and wear. Part of the vehicle package (#139).

## How it works

1. The class comes from `coe_vehicle_catalog`; a category defined by an override takes precedence over the class (`CategoryProfiles`). Addons without a class use `FallbackProfile`.
2. The server combines profile × tire × wear into multipliers and publishes them in the `coe:handling` and `coe:tyre` state bags.
3. The client reads the model's original handling once and applies `original × multiplier` with `SetVehicleHandlingFloat`. When the resource stops, the original values are restored.

Wear is calculated from mileage (`coe_vehicles`) since installation: no timers. Republishing happens only when the compound or wear changes by 1%.

## Base profile (simulator)

More mass, less initial drive force, lower peak grip, more low-speed wheelspin, and heavier brakes and suspension. Each class (`ClassProfiles`) adjusts this: supercars have more downforce and grip, muscle cars have little grip and lots of wheelspin, SUVs/vans/commercial vehicles are heavier and less agile, and off-road vehicles tolerate rough surfaces. Missing classes (boats, helicopters, airplanes) are unchanged.

## Tires

| Compound | Grip | Brakes | Rough surface | Life |
|---|---|---|---|---|
| street | 1.00 | 1.00 | 1.00 | 60 km |
| sport | 1.08 | 1.05 | 1.10 | 40 km |
| performance | 1.15 | 1.10 | 1.25 | 25 km |
| slick | 1.25 | 1.18 | 1.60 | 15 km |
| all_terrain | 0.94 | 0.97 | 0.65 | 70 km |
| offroad | 0.88 | 0.95 | 0.50 | 80 km |
| drift | 0.80 | 0.95 | 1.10 | 12 km |

"Rough surface" is the loss of traction off-road (lower = better). Default class: super uses `performance`, sports uses `sport`, off-road uses `all_terrain`, and all others use `street`.

## API

Server exports: `GetTyre(vehicleId)`, `SetTyre(vehicleId, compound)` (`WriterResources` only), `ListTyres()`, `ListClasses()`, `GetModifiers(vehicleId)`, `IsReady()`. See `types.lua`.

Commands: `coe_tyre <plate> <compound>` (ACE `command.coe_tyre` or console) and `coe_handling_dump` (client, prints the state bag and current values for the vehicle you are in).

Events consumed from `coe_vehicles`: `coe_vehicles:spawned`, `coe_vehicles:mileageChanged`, `coe_vehicles:released`.

## Fuel

The tank mixture (`coe_fuel:GetEffects`) multiplies engine power (`fInitialDriveForce`) along with part wear: ethanol +6%, premium +2% (proportional to the liters). Handling is recalculated on the `coe_fuel:effectsChanged` event (when refueling).

## Limitations

- The multipliers are starting points and need in-game tuning (`config.lua`).
- If this resource restarts while modified vehicles are in the street, the models' original values are lost: respawn the vehicles.
- Advanced editor, telemetry, exportable profiles, and mechanic integration are tracked in #139.
