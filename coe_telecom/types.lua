---@meta
-- Contrato público de coe_telecom para LuaLS. Não é carregado pelo servidor.
-- Gerado a partir dos exports registrados no código; refine descrições e tipos ao mexer em cada export.

---@class CoeTelecomExports
local exports_coe_telecom = {}

---O telefone pergunta antes de ligar ou mandar mensagem pela linha `number` (chip do aparelho). holder: titular do chip (nil = anônimo). Retorna { ok, maxSeconds } ou { ok = false, error }.
---@param number any
---@param kind any
---@param holder any
---@return any
function exports_coe_telecom:Authorize(number, kind, holder) end

---Uso concluído (ligação encerrada ou mensagem enviada). seconds só vale para voz e vídeo.
---@param number any
---@param kind any
---@param seconds any
---@param peer any
---@param holder any
---@return any
function exports_coe_telecom:Charge(number, kind, seconds, peer, holder) end

---Resumo da linha de um número para outros resources.
---@param number any
---@return any
function exports_coe_telecom:LineOf(number) end

---Export server `TabletCall` (server/main.lua).
---@param playerId any
---@param appId any
---@param action any
---@param payload any
---@return any
function exports_coe_telecom:TabletCall(playerId, appId, action, payload) end

---Export server `TabletVisible` (server/main.lua).
---@param playerId any
---@param appId any
---@return any
function exports_coe_telecom:TabletVisible(playerId, appId) end

---Avalia a qualidade de sinal, banda (5G/4G/3G/SAT/FIBRA/OFFLINE) e latência para uma operadora e coordenada.
---@param carrierId string
---@param coords table|nil
---@param context table|nil
---@return table
function exports_coe_telecom:EvaluateSignal(carrierId, coords, context) end

---Verifica se a banda atual suporta a feature requisitada (text, voice, video, high_freq_market, remote_rig, cloud_sync).
---@param band string
---@param feature string
---@return boolean
function exports_coe_telecom:CanAccessBandFeature(band, feature) end

---Sabota fisicamente uma torre de celular (ERB) pelo tempo determinado.
---@param towerId string
---@param durationSec number|nil
---@return boolean, string|nil
function exports_coe_telecom:SabotageTower(towerId, durationSec) end

---Repara imediatamente uma torre de celular (ERB) sabotada.
---@param towerId string
---@return boolean
function exports_coe_telecom:RepairTower(towerId) end

---Ativa um contrato de fibra óptica dedicada Wi-Fi 6 para um espaço (imóvel/empresa).
---@param spaceKey string
---@return boolean
function exports_coe_telecom:ActivateFiber(spaceKey) end

---Verifica se o espaço possui fibra óptica dedicada ativa.
---@param spaceKey string
---@return boolean
function exports_coe_telecom:HasActiveFiber(spaceKey) end

---Instala ou remove o kit veicular de antena satelital OrbitLink em uma placa.
---@param plate string
---@param active boolean
---@return boolean
function exports_coe_telecom:SetVehicleOrbitlink(plate, active) end

---Retorna o panorama em memória das ERBs (3G/4G/5G), fibras ópticas e operadoras para o painel admin.
---@return table
function exports_coe_telecom:AdminOverview() end
