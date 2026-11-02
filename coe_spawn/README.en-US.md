# coe_spawn

Client adapter that keeps `spawnmanager` disabled until it receives confirmation from the server that the character has loaded. Before selection, the player has no control and is invisible; when switching characters, this state is cleared and the player returns to selection. After selection, `spawnmanager` handles the initial spawn and respawns.

## Last position

The character returns to where they were when leaving (`CoeSpawnConfig.LastPosition`). The server reads the ped's position every `SampleMs` (5 s), only after spawn and only in the normal world (routing bucket 0). Inside properties and admin visits, it uses the last street position, and `coe_housing` returns a player who left inside a property to that interior. The client never sends coordinates. Position is written to table `coe_spawn_positions` (migration in `server/migrations.lua`) every `FlushMs` (60 s), when switching characters, and when disconnecting.

When loading a character, the client requests the position (`coe_spawn:requestPosition`) and only then calls `spawnmanager`. If no position is saved (first access), the position is invalid, or there is no response within `TimeoutMs`, it uses `CoeSpawnConfig.location`. Subsequent respawns (e.g., after death) use `location`.

The initial spawn point (first access) is in [config.lua](./config.lua). Set `CoeSpawnConfig.location` to the coordinates and heading for the map in use. With a saved appearance (provided by `player.characterLoaded`), spawn uses its model and applies the appearance with `coe_appearance` (including on respawns). Without an appearance (legacy character or `coe_appearance` not started), a ped is chosen randomly from `CoeSpawnConfig.models` (common peds): a freemode ped without head blend has no face. Final fade-in is 500 ms, after appearance is applied. After spawning, the adapter makes the ped visible, unfreezes it, and returns control to the player, since these states are changed during selection. `CoeSpawnConfig.Debug = true` prints the steps to the F8 console (`[coe_spawn] ...`), including a dump of ped state, camera, and game time after spawn; disable it after validating.

Before selection, the adapter also ends the loading screen (`ShutdownLoadingScreen`/`ShutdownLoadingScreenNui`) and fades in, because with auto-spawn disabled `spawnmanager` does not do so and the screen would obscure the selection UI.

This resource does not modify `spawnmanager` or resources distributed by Cfx. Do not start `basic-gamemode` with this flow: it enables respawning without waiting for the Core's authoritative state.

## Starter hotel

`exports.coe_spawn:GetStarterHotel()` returns the current configuration for the hotel where a new character spawns; `SetStarterHotel(dados)` saves it and synchronizes it with connected players (`true` or `false, codigo`). The `coe_staff` panel uses both. Contract in [`types.lua`](types.lua).

## Files and tests

- `config.lua`: coordinates and heading for the initial spawn and last-position settings.
- `shared/positions.lua`: position validation and rounding (pure).
- `server/main.lua`, `server/persistence.lua`, `server/migrations.lua`: server-side position reading and writing to `coe_spawn_positions`.
- `client.lua`: blocks auto-spawn until selection, validates the origin of Core events, requests the last position, and delegates spawn to `spawnmanager`.
- `fxmanifest.lua`: dependencies and load order.

Run `lua test\client_test.lua` and `lua test\positions_test.lua` in the resource folder. Tests cover trusted event origins, player blocking, callback registration, spawn at last position with fallback to the configured point, position validation, returning to selection, and use of saved appearance (model, application, and respawn; random selection for those without one). Spawn/control natives, real network synchronization, and behavior in Enhanced require an in-game smoke test; see [TEST_COVERAGE.md](../TEST_COVERAGE.md).
