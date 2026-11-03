# coe_rentals

Rental of popular vehicles for new citizens: the player pays the rental fee plus a deposit at a station counter and gets the deposit back when returning the vehicle to any station.

## How it works

- Stations and catalog in `config.lua` (`RentalsConfig.Stations` and `RentalsConfig.Vehicles`). Each vehicle has a `price` (non-refundable) and `deposit`.
- Stations are stored in the database (`coe_rental_stations`) and edited in the panel (Rentals tab in `coe_staff`; package panels use the exports with the `coe.rentals.admin` ACE): attendant (NPC and counter), multiple pickup points (vehicle spawns at the first available one), return zone, offered models, and blip. `RentalsConfig.Stations` seeds the database only the first time.
- When renting, the player receives a **rental contract** (`rental_contract`; using it displays a document with vehicle, plate, renter, date, and amounts) and the **key** (`carkey` with `rental = true`; without it, the vehicle will not start or lock). Both items are removed from inventory upon return or termination.
- Return: while driving, in a station's return zone (E), or on foot at the counter (Return menu) with the car parked nearby (`CounterReturnDistance`) and empty. If the vehicle was destroyed or disappeared, **End rental** allows renting again and the deposit is kept.
- At the counter, `E` opens the menu (`html/`, `coe_ui` theme): lists the station's vehicles with rental fee, deposit, and total; arrows/click select, `Enter`/Rent confirms, `Esc` closes. `vehicles = { ... }` on a station limits its catalog there.
- The menu requests `rentals.rent`; the server checks the active character, station, model, distance (`InteractRadius`, 6 m), and interval between requests (`CooldownMs`, 2 s), and only then charges.
- **Fail-closed charging**: if `coe_economy` is not running, the rental is refused (`economy_unavailable`); nothing is given away for free. If the vehicle cannot be created, the amount is refunded.
- Return (`rentals.return`): the player must be driving the rented vehicle within a station's `returnZone`. The deposit is returned through the economy system; if crediting fails, the error is logged and the player is notified.
- One active rental per character. On server disconnect, the vehicle is removed and the deposit is kept.

## Access to other resources

`coe_rentals` is in `coe_economy`'s `AllowedResources` (rental debit and deposit credit). No ACE needs to be configured; `ensure coe_rentals` is already in `recipe.yaml`.

## Exports (server)

| Export | Return |
| --- | --- |
| `GetActiveRental(characterId)` | Active rental (`entity`, `netId`, `plate`, `model`, `deposit`, `stationId`, `rentedAt`) or `nil` |

Contract in [`types.lua`](types.lua) and the [API reference](../reference/coe_rentals.md).

## Tests

```powershell
cd coe_rentals
lua test/rentals_test.lua
lua test/server_test.lua
```

`rentals_test.lua` covers pure rules (catalog, station, amounts, plate, distance); `server_test.lua` covers the server flow with simulated economy (economy offline, distance, cooldown, insufficient balance, and return).
