# coe_races — referência da API

> Gerado de `coe_races/types.lua` por `tools/gen_reference.lua`. Não edite à mão.

Exports server-only, chamados pelo coe_tablet (app "races" no grupo Ilegal). O tablet próprio usa o evento
coe_races:call (pedido/resposta em coe_races:result); a corrida usa coe_races:ready, coe_races:checkpoint e
coe_races:quit. Entradas em cripto ficam na custódia do coe_crypto (EscrowLock/EscrowRelease).

## Exports

### `TabletVisible(playerId, appId)`

O app de corridas aparece no COE OS? Só para quem carrega o item `race_tablet`. Só o coe_tablet chama.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `playerId` | `integer` |  |
| `appId` | `string` | `races` |

**Retorno**

- `boolean` `visible`

### `TabletCall(playerId, appId, action, payload)`

Ação do app de corridas no COE OS (mesmas ações do tablet próprio). Só o coe_tablet chama. Ações: `state`, `setNickname`, `tracks`, `track`, `wallets`, `createRace`, `join`, `leave`, `startNow`, `cancelRace`, `leaderboard`, `history`, `startRecording`, `saveTrack`, `trackStatus`, `adminRaces`. Erros: `forbidden`, `not_ready`, `no_character`, `no_tablet`, `rate_limited`, `no_nickname`, `nickname_taken`, `unknown_track`, `unknown_race`, `race_full`, `race_started`, `already_racing`, `already_organizing`, `invalid_wallet`, `invalid_payout`, `insufficient_funds`, `crypto_unavailable`, `not_enough_races`, `too_few_checkpoints`.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `playerId` | `integer` |  |
| `appId` | `string` | `races` |
| `action` | `string` |  |
| `payload` | `table` |  |

**Retorno**

- `table` `result` — `{ ok = true, data = table }` ou `{ ok = false, error = string }`

