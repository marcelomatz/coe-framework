# coe_vehicles

Persistent player vehicle registry: owner, model, plate, state, and **Mileage**. Every registered vehicle has Mileage. This is the foundation for garages, mechanics, dealerships, and handling.

## Mileage

- Unit: **whole meters** (`mileage_m`). Conversion to km/mph is for display (`VehicleMileage.ToUnit`).
- The driver's client samples position and reports in batches (`ReportIntervalMs`).
- The server validates each report: the vehicle must have been created by the server, the sender must be the driver, and distance is limited by credit proportional to elapsed time. Invalid reports are rejected and logged.
- The counter is kept in memory and written in transactional batches (`FlushIntervalMs`), when storing the vehicle, when removing the entity, and when stopping the resource.
- Only callers with `coe.vehicles.mileage` (ACE in `server.cfg`, e.g., panel and mechanic) can correct the value, always with an audit record.
- State bags on the vehicle: `coe:vehicleId` and `coe:mileage` (updated every 100 m).

## Keys

- The key is the `carkey` inventory item (metadata `vehicleId`, `plate`). The owner receives the item when the vehicle is created on the street (retrieved from a garage, panel, dealership) and **all** keys for the vehicle are removed from online inventories (and the offline owner's) when it is stored or removed — nothing accumulates. Keys for vehicles that are already stored are also removed when loading the character (restart while the car is on the street).
- Without the item, the vehicle will not start or lock. Giving the key to another player (through inventory) also transfers its use.
- Lock/unlock: `L` key (configurable in Key Bindings > FiveM) or use the key item, within `LockDistanceMeters`.
- Rented vehicles (`coe_rentals`) use the same item with `{ plate, rental = true }` and the `coe:keyPlate` state bag.
- If `coe_inventory` is not running, the old rule applies: the owner has an implicit key and any loaned keys.
- The owner can lend a key to another nearby player and revoke it. The recipient cannot lend it again. Limit: `MaxLoanedKeysPerVehicle`.
- Mileage accrues to the vehicle, regardless of who drives.
- The client asks the server (`coe_vehicles:checkKey`) when taking the driver's seat; without a response or key, the vehicle becomes undriveable. The decision belongs to the server, but the block itself is applied client-side (not cheat protection; hotwiring/theft will be handled by the crime package).
- Commands: `/chave_emprestar <id do jogador>` and `/chave_retirar <id do jogador>` (vehicle the player is in or nearest one, up to `LendDistanceMeters`).
- Dealership/admin tools use the `GiveKey`/`RevokeKey` exports.

## Exports (server)

| Export | Who can call | Return |
| --- | --- | --- |
| `Create(data)` | `coe.vehicles.write` (default: `coe_vehicles`, `coe_staff` panel, and `coe_garage`) | vehicle or error code |
| `Get(id)`, `GetByPlate(plate)`, `ListByOwner(characterId)`, `GetMileage(id)` | anyone | data or error |
| `GetEntity(id)` | anyone | spawned entity or `nil` |
| `SetMileage(id, meters)` | `coe.vehicles.mileage` | `true` or error |
| `Spawn(id, x, y, z, heading, type)` | `coe.vehicles.write` | netId or error |
| `Store(id)` | `coe.vehicles.write` | `true` or error |
| `IsReady()` | anyone | boolean |
| `HasKey(characterId, id)`, `ListKeyHolders(id)` | anyone | boolean / list |
| `GiveKey(id, characterId)`, `RevokeKey(id, characterId)` | `coe.vehicles.write` | `true` or error |

Full contract in `types.lua`.

## Commands (ACE)

- `coe_vehicle_create <model> [plate]`: creates and spawns the vehicle, then puts the player inside.
- `coe_vehicle_mileage <plate> <km>`: sets the mileage.

## Database

Table `coe_vehicles` is created by its own migration (`coe_vehicles_schema_migrations`). Access goes through `coe_database`, which must list `coe_vehicles` among its allowed callers.

## Tests

```
cd coe_vehicles
lua test/vehicles_test.lua
lua test/keys_test.lua
```

## Out of scope

Keys, garages, impound, fuel, and insurance (#130); catalog (#138); odometer on the HUD (#117).
