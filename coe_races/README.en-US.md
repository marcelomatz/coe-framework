# coe_races

Street races: illegal races between players on tracks with checkpoints, organized through the **racing tablet** (item `race_tablet`), with buy-ins placed in crypto (`coe_crypto`), driver rankings, track records, and the risk of police showing up (`coe_dispatch`).

## Racing tablet

- Dedicated device (visual "RACHA//NET"): use the `race_tablet` item or `/corridas` (item required). Works on foot or inside a car.
- The same app appears in COE OS (`coe_tablet`), in the **Illegal** group, for anyone carrying the item.
- Tabs: **Races** (open in the city and yours), **Organize**, **Tracks** (with map, records, and recording), **Ranking**, and **History**.
- On first access, the driver chooses a **handle** (unique, 3–16 letters, numbers, `_`, or `-`). This is the name shown on the grid, rankings, and records.

## Tracks

- **Sprint** (A → B) or **circuit** (with laps; the finish is at the starting line, closed automatically).
- Recorded **while driving**: on the tablet, select "Record new track" (name, description, type); then, in the car, `Y` marks the starting line (grid position and direction) and each checkpoint, `U` undoes, `Enter` saves, and `Delete` cancels (keys in Settings > Key Bindings > FiveM). The server validates minimum spacing (`MinSpacing`), 3 to 60 checkpoints, and coordinates.
- Who can create: drivers with `MinRacesToCreate` completed races (up to `MaxPerCreator` tracks each) and staff, with no limit.
- Moderation: staff (`coe_races.admin`) can feature (★), hide, and reactivate tracks; creators can hide and reactivate their own. Hidden tracks disappear from the list and cannot receive new races.
- Track records: best laps and best total times by number of laps.

## Races

1. **Organize**: track, laps (circuit), vehicle class, buy-in, maximum racers, and start in X minutes. The organizer can race or only organize, and can start before the scheduled time.
2. **Join**: with a buy-in, the driver chooses the wallet to pay from (phone wallets and paper/USB-drive wallets in inventory) and where to receive the prize. The buy-in is held in `coe_crypto` **escrow** (`EscrowLock`) until the end. Leaving the lobby returns the buy-in.
3. **Grid**: at the start, everyone must be near the starting point (`GridRadius`), in the driver's seat, and in a vehicle of the specified class. Anyone who is not eligible leaves with their buy-in returned. If fewer than `MinRacers` are present, the race is canceled and everyone is refunded.
4. **Countdown**: cars locked, checkpoints on screen, and a **ghost start** — no collisions between racers on the grid until `GhostSeconds` after "GO".
5. **Race**: the next checkpoint and the one after it appear with an arrow (checkered flag at the finish), numbered blip, and GPS route. The client reports crossing, and the **server verifies** order, position (radius + tolerance), height, plausible speed since the previous checkpoint (anti-teleport), and that it is the same vehicle as at the start; time is server-side. The HUD shows position, time, lap, checkpoint, best lap, and the top 8.
6. **Finish**: once the first racer crosses, the others have `FinishWindowSeconds` to finish. A racer also drops out if they stay out of the vehicle for `OutOfVehicleSeconds`, disconnect, use `/sairdacorrida`, or exceed the maximum time (`MaxSecondsPerKm`).

### Pot

- Pot = buy-in × racers who started. The organizer receives `OrganizerFeeBps` (5%) in the wallet they chose.
- The remainder is split according to the `Payouts` table, selected by racer count (2: 100%; 3+: 70/30; 5+: 60/25/15; 8+: 50/25/15/10). Prize positions without a finisher and rounding go to 1st place.
- If no one finishes, everyone gets their buy-in back. The crypto network transfer fee is not refunded.
- If the resource goes down mid-race, buy-ins still in escrow are refunded on the next startup.

## Ranking

- Elo-style rating across all pairs in each race (`Rating.K` divided by the opponents), starts at 1000 and does not go below `Rating.Min`. Dropping out counts as last place.
- Career: races, wins, podiums, dropouts, and prizes. History includes the last `HistorySize` races.

## Police

- At the start, chance of a `street_race` alert in `coe_dispatch` (`StartChance` + `PerRacer` per racer beyond two, + `SirenBonus` when a siren-equipped police vehicle with its siren on is within `SirenRadius` of the grid; capped at `MaxChance`).
- During the race, every `TickSeconds`, `TickChance` chance of another alert at the leader's position.

## Integration

- `coe_crypto`: `coe_races` in `Escrow.Callers` (`HeldWallets`, `EscrowLock`, `EscrowRelease`, `IsAddress`, `Format`). Without `coe_crypto`, only races without a buy-in are available.
- `coe_dispatch`: code `street_race` and `coe_races` in `ActionResources`.
- `coe_tablet`: app `races` (group `illegal`, `item = 'race_tablet'`), calling `TabletCall`.
- `coe_phone`: phone wallet key comes from `ActiveDevice` (`phone:<serial>`).
- Item `race_tablet` in the framework's `coe_inventory`.
- Capabilities granted by the framework (`CoeAccess.FirstParty`): `coe.database`, `coe.audit`, `coe.logging`, `coe.notify`. Staff:
  `add_ace group.admin coe_races.admin allow`.

## Tests

```
lua test/rules_test.lua
lua test/server_test.lua
lua test/client_test.lua
```
