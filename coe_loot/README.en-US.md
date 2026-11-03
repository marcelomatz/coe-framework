# coe_loot

Loot tables for robberies. Robbery scripts (residential, pedestrian, vehicle, business, heists) do not store their own item lists: they call `exports.coe_loot:Give(playerId, 'house_robbery')` when complete, and loot is handled here. This keeps balancing (what drops and at what chance) in one place.

## Tables (`config.lua`)

Each table has `rolls` (number of rolls, from `min` to `max`) and `entries` with `weight`. `nothing = true` is an empty roll; `min`/`max` is the quantity; `unique = true` marks an item that does not stack (added one unit at a time).

Chance of getting **at least one** in a robbery (calculated by `LootRules.Chance`, with the default weights):

| Table | Use | Onion USB drive | Laptop | Blank USB drive |
|---|---|---|---|---|
| `house_robbery` | Residential robbery | 11.5% | 16.8% | 26.8% |
| `pedestrian_robbery` | Pedestrian mugging | 4.5% | — | 7.4% |
| `vehicle_break_in` | Vehicle break-in | 4.5% | 7.4% | 11.7% |
| `store_robbery` | Business robbery | 7.4% | — | 14.5% |

Cash, cell phones, cigarettes, bandages, and repair kits may also drop, depending on the table.

## Exports (server)

See [`reference/coe_loot.md`](../reference/coe_loot.md). `Give(playerId, tableId)` → `{ ok, given, lost }` (`lost`: items that did not fit; the robbery script decides whether to drop them on the ground) and `Roll(tableId)` → `{ ok, items }`: only resources in `Callers` (`coe_heists`, `coe_robbery`, `coe_admin`; add yours). `Tables()` is freely readable. Each grant is audited (`loot_given`, with the table and resource).

## Testing

`/coe_loot_test <table>` (ACE `command.coe_loot_test`) gives loot to yourself:

```
add_ace group.admin command.coe_loot_test allow
```

## Not yet available

The robbery scripts themselves (residential, pedestrian, vehicle) are not implemented yet. This resource is their integration point; `coe_dispatch` already accepts `coe_loot`/`coe_heists` to open calls.

## Tests

```
cd coe_loot
lua test/loot_test.lua
```
