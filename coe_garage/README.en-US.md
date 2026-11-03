# coe_garage

Basic public garages for the COE Framework (Open-Core MIT).
Allows citizens to store and retrieve their personal vehicles in map-marked spaces, with support for visible blips and full administration through the admin panel (`coe_staff`).

## Features

- **Public garages across the map**: Pink Cage, Legion Square, LSIA Airport, and Sandy Shores are created automatically through a migration.
- **Native interaction (0.00 ms while idle)**:
  - On foot at a parking space: opens the interface to select and retrieve a stored vehicle (with an automatic key handoff).
  - In the vehicle as the driver: option to store the vehicle in the current space.
- **`coe_staff` integration**: automatically registers as a garage provider for administration through the staff panel (add new garages at the current coordinates, edit spaces, toggle blips, delete, and teleport).
- **NUI interface**: modern menu using `coe_ui` design system tokens.

## Exports (server)

| Export | Parameters | Return | Description |
|---|---|---|---|
| `IsReady()` | — | `boolean` | Indicates whether the subsystem is initialized |
| `ListGarages()` | — | `CoeGarage[]` | Lists all registered garages |
| `GetGarage(id)` | `id: string` | `CoeGarage\|nil` | Returns a specific garage |
| `GetVehicleGarage(vehicleId)` | `vehicleId: string\|number` | `string\|nil` | Returns where the vehicle is stored |
| `SaveGarage(data)` | `data: table` | `CoeGarage\|nil, error` | Saves or updates a garage |
| `DeleteGarage(id)` | `id: string` | `boolean, error` | Removes a garage |

## Access to other resources

`coe_garage` is included in the framework's allowlists for what it uses: `coe_database` (`DEFAULT_CALLERS`) and `coe_vehicles` (`WriterResources`: `Spawn`, `GiveKey`, `Store`). Nothing needs to be configured in `server.cfg` beyond `ensure coe_garage` (already in `recipe.yaml`). `tools/check_contracts.lua` fails CI if any of these allowlists drops the resource.

Server rules: the player must be within the parking space radius (default 4 m) to list and retrieve vehicles, and the vehicle must be within 5 m to store it; only the owner can retrieve it; a vehicle with a fixed space can only leave the garage where it was stored (`wrong_garage`); one action per player per `GarageConfig.Limits.ActionCooldownMs`.

## Database

- Table `coe_garage_registry`: stores garages and their parking spaces as JSON.
- Table `coe_garage_slots`: tracks which garage each vehicle is stored in.
- Automatic versioned migrations via `CoeMigrations`.

## Tests

```powershell
cd coe_garage
lua test/domain_test.lua
lua test/service_test.lua
```

The MariaDB integration (`coe_database/test/integration/garage_mobile_scenario.lua`) covers migrations, garages, and spaces in a real database.
