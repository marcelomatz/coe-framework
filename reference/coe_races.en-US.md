# coe_races — API reference

> Generated from `coe_races/types.lua` by `tools/gen_reference.lua`. Do not edit by hand.

Server-only exports called by coe_tablet (the "races" app in the Illegal group). The standalone tablet uses the `coe_races:call` event (request/response via `coe_races:result`); races use `coe_races:ready`, `coe_races:checkpoint`, and `coe_races:quit`. Crypto entry fees are held in escrow by coe_crypto (`EscrowLock`/`EscrowRelease`).

## Exports

### `TabletVisible(playerId, appId)`

Is the racing app visible in COE OS? Only for players carrying the `race_tablet` item. Only coe_tablet calls this.

| Parameter | Type | Description |
|---|---|---|
| `playerId` | `integer` |  |
| `appId` | `string` | `races` |

**Returns**

- `boolean` `visible`

### `TabletCall(playerId, appId, action, payload)`

Action for the racing app in COE OS (same actions as the standalone tablet). Only coe_tablet calls this. Actions: `state`, `setNickname`, `tracks`, `track`, `wallets`, `createRace`, `join`, `leave`, `startNow`, `cancelRace`, `leaderboard`, `history`, `startRecording`, `saveTrack`, `trackStatus`, `adminRaces`. Errors: `forbidden`, `not_ready`, `no_character`, `no_tablet`, `rate_limited`, `no_nickname`, `nickname_taken`, `unknown_track`, `unknown_race`, `race_full`, `race_started`, `already_racing`, `already_organizing`, `invalid_wallet`, `invalid_payout`, `insufficient_funds`, `crypto_unavailable`, `not_enough_races`, `too_few_checkpoints`.

| Parameter | Type | Description |
|---|---|---|
| `playerId` | `integer` |  |
| `appId` | `string` | `races` |
| `action` | `string` |  |
| `payload` | `table` |  |

**Returns**

- `table` `result` — `{ ok = true, data = table }` or `{ ok = false, error = string }`
