---@meta
-- Contrato público de coe_crypto para LuaLS. Não é carregado pelo servidor.
-- Ver docs/ANNOTATIONS.md. Valores de moeda em unidades inteiras (1 moeda = 10^Coin.Decimals unidades).
-- Apps do COE OS: TabletVisible/TabletCall (só coe_phone e coe_tablet) e ComputerCall (só coe_deepweb).

---@class CoeCryptoExports
local exports_coe_crypto = {}

---Rede carregada (migrações, reserva da corretora e cotação).
---@return boolean ready
function exports_coe_crypto:IsReady() end

---Cotação atual da corretora em $ por moeda inteira.
---@return integer price
function exports_coe_crypto:Price() end

---Saldo de um endereço. Leitura livre.
---@param address string
---@return integer|nil units `nil` se o endereço não existe na rede
function exports_coe_crypto:Balance(address) end

---Formato de endereço válido (não confere se existe).
---@param address string
---@return boolean valid
function exports_coe_crypto:IsAddress(address) end

---Unidades formatadas com o símbolo (ex.: `1,5000 NOX`).
---@param units integer
---@return string text
function exports_coe_crypto:Format(units) end

---Emissão de uma rodada de mineração. Só `Mining.Callers`, no máximo uma por `Mining.TickMinutes`.
---@param entries { address: string, hash: integer }[]
---@return CoeCryptoMintResult result
function exports_coe_crypto:MintMining(entries) end

---App Cripto num computador do coe_deepweb. Só `ComputerHosts`; `deviceKey` é a chave do aparelho (`laptop:<serial>`...).
---@param playerId integer
---@param deviceKey string
---@param action string
---@param payload table|nil
---@return table result `{ ok, ... }` ou `{ ok = false, error }`
function exports_coe_crypto:ComputerCall(playerId, deviceKey, action, payload) end

---Carteiras com chave à mão no aparelho `deviceKey` (e no inventário do personagem), com saldo. Só `Escrow.Callers`.
---@param playerId integer
---@param deviceKey string
---@return table|nil wallets `{ { address, label, source, balance } }`
function exports_coe_crypto:HeldWallets(playerId, deviceKey) end

---Trava `amount` (mais a taxa da rede) da carteira `from` na custódia do mercado. Exige a chave à mão. Só `Escrow.Callers`.
---@param playerId integer
---@param deviceKey string
---@param from string
---@param amount integer
---@param memo string|nil
---@return table result `{ ok, txId }` ou `{ ok = false, error }`
function exports_coe_crypto:EscrowLock(playerId, deviceKey, from, amount, memo) end

---Libera `amount` da custódia para `to`, sem taxa da rede. Só `Escrow.Callers`.
---@param to string
---@param amount integer
---@param memo string|nil
---@return table result `{ ok, txId }` ou `{ ok = false, error }`
function exports_coe_crypto:EscrowRelease(to, amount, memo) end

---Endereço da reserva da corretora (recebe taxas do mercado e pagamentos a fornecedores NPC).
---@return string address
function exports_coe_crypto:ReserveAddress() end

---Panorama administrativo das configurações, cotação ao vivo, resumo da rede, maiores carteiras e transações recentes. Só `coe_admin`.
---@return table result `{ available = true, ready, settings, defaults, market, summary, topWallets, recentTx }` ou `{ error }`
function exports_coe_crypto:AdminOverview() end

---Inspeciona uma carteira pelo endereço (saldo, criador, aparelhos com chave e extrato). Só `coe_admin`.
---@param address string
---@return table result `{ wallet, devices, history }` ou `{ error }`
function exports_coe_crypto:AdminInspect(address) end

---Valida, persiste e aplica em memória as configurações editáveis do coe_crypto. Só `coe_admin`.
---@param raw table
---@return boolean|table result `true` ou `{ error }`
function exports_coe_crypto:AdminSaveSettings(raw) end

---Restaura as configurações para os padrões de `config.lua`. Só `coe_admin`.
---@return boolean|table result `true` ou `{ error }`
function exports_coe_crypto:AdminResetSettings() end

---Fixa imediatamente a cotação da corretora em $ por moeda inteira. Só `coe_admin`.
---@param price integer
---@return boolean|table result `true` ou `{ error }`
function exports_coe_crypto:AdminSetPrice(price) end

---App Crypto do tablet: visível quando instalado no aparelho.
---@param playerId integer
---@param appId string
---@return boolean visible
function exports_coe_crypto:TabletVisible(playerId, appId) end

---Ações do app Crypto no tablet.
---@param playerId integer
---@param appId string
---@param action string
---@param payload table|nil
---@return table result `{ ok, data }` ou `{ ok = false, error }`
function exports_coe_crypto:TabletCall(playerId, appId, action, payload) end

---@class CoeCryptoMintResult
---@field ok boolean
---@field error string|nil `forbidden|not_ready|too_soon|invalid_entries|database_error`
---@field total integer|nil Unidades emitidas na rodada
---@field payouts table<string, integer>|nil Endereço -> unidades

