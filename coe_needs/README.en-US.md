# coe_needs

Hunger, thirst, and stress per character. Scale 0–100: hunger/thirst 100 = full; stress 0 = calm.

## How it works

- **Authoritative server.** The client only reports the *activity* (`idle`, `walk`, `run`, `sprint`, `swim`, `drive`, `driveFast`, `combat`); the server validates the key, measures elapsed time (limit of 30 s per update), and applies the per-minute rates from `Config.Needs.Rates`. Repeated messages within 800 ms are ignored.
- **Persistence.** Table `coe_needs_state` per `character_id` (own migration), saved every 60 s, when switching characters, when disconnecting, and when stopping the resource. If reading fails, the state is not written over the database.
- **Item consumption.** `inventory.itemUsed` applies `Config.Needs.ItemEffects[item]` (e.g., `burger = { hunger = 35 }`).
- **Ped effects** (client): native health recovery is disabled; health slowly regenerates with hunger and thirst ≥ 60 and stress ≤ 70; hunger or thirst at zero drains health (never below 105); below 20 running is slower and at zero sprint is blocked (with a player notification); stress ≥ 60/85 shakes the camera.

## API

Server: `exports.coe_needs:GetNeeds(source)`, `AddNeed(source, 'stress', 5)`, `SetNeed(source, 'hunger', 50)` (`AddNeed`/`SetNeed` are only for the defaults in `Config.Needs.AllowedResources` and callers with the `coe.needs` ACE; they return `true` or an error code). Robberies, crimes, and events should call `AddNeed(source, 'stress', n)`.

Client: `exports.coe_needs:GetState()` and the local event `coe_needs:changed`.

Tests: `lua test\needs_test.lua` and `lua test\service_test.lua`.

## API reference

[Exports, parameters, and error codes](../reference/coe_needs.md), generated from [`types.lua`](types.lua).
