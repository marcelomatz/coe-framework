---@meta
-- Contrato público de coe_races para LuaLS. Não é carregado pelo servidor. Ver docs/ANNOTATIONS.md.
-- Exports server-only, chamados pelo coe_tablet (app "races" no grupo Ilegal). O tablet próprio usa o evento
-- coe_races:call (pedido/resposta em coe_races:result); a corrida usa coe_races:ready, coe_races:checkpoint e
-- coe_races:quit. Entradas em cripto ficam na custódia do coe_crypto (EscrowLock/EscrowRelease).

---@class CoeRacesExports
local exports_coe_races = {}

---O app de corridas aparece no COE OS? Só para quem carrega o item `race_tablet`. Só o coe_tablet chama.
---@param playerId integer
---@param appId string `races`
---@return boolean visible
function exports_coe_races:TabletVisible(playerId, appId) end

---Ação do app de corridas no COE OS (mesmas ações do tablet próprio). Só o coe_tablet chama.
---Ações: `state`, `setNickname`, `tracks`, `track`, `wallets`, `createRace`, `join`, `leave`, `startNow`, `cancelRace`,
---`leaderboard`, `history`, `startRecording`, `saveTrack`, `trackStatus`, `adminRaces`.
---Erros: `forbidden`, `not_ready`, `no_character`, `no_tablet`, `rate_limited`, `no_nickname`, `nickname_taken`,
---`unknown_track`, `unknown_race`, `race_full`, `race_started`, `already_racing`, `already_organizing`, `invalid_wallet`,
---`invalid_payout`, `insufficient_funds`, `crypto_unavailable`, `not_enough_races`, `too_few_checkpoints`.
---@param playerId integer
---@param appId string `races`
---@param action string
---@param payload table
---@return table result `{ ok = true, data = table }` ou `{ ok = false, error = string }`
function exports_coe_races:TabletCall(playerId, appId, action, payload) end
