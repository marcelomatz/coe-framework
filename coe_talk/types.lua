---@meta
-- Contrato público de coe_talk para LuaLS. Não é carregado pelo servidor. Ver docs/ANNOTATIONS.md.

---@class CoeTalkExports
local exports_coe_talk = {}

-- Servidor ---------------------------------------------------------------------------------------------------

---Coloca o jogador numa frequência de rádio (ou tira, com `nil`/`0`). Só `Config.Access.Resources` (padrão
---`coe_mobile`) ou quem tem a ACE `coe.talk`. Não aplica a restrição por job: quem chama decide.
---@param source integer Jogador
---@param frequency number|nil
---@return boolean ok
---@return string|nil errorCode `forbidden`, `invalid_player`
function exports_coe_talk:SetPlayerRadio(source, frequency) end

---@param source integer
---@return number|nil frequency
function exports_coe_talk:GetPlayerRadio(source) end

---Coloca o jogador numa chamada de voz (ou tira, com `nil`). É o único jeito de entrar numa chamada: o client não
---escolhe a chamada. Mesmo controle de acesso de `SetPlayerRadio`.
---@param source integer
---@param callId string|nil Até 64 caracteres `[A-Za-z0-9_:-]`
---@return boolean ok
---@return string|nil errorCode `forbidden`, `invalid_player`, `invalid_call`
function exports_coe_talk:SetPlayerCall(source, callId) end

---@param source integer
---@return string|nil callId
function exports_coe_talk:GetPlayerCall(source) end

---@param frequency number
---@return integer[] members
function exports_coe_talk:GetRadioMembers(frequency) end

---@param callId string
---@return integer[] members
function exports_coe_talk:GetCallMembers(callId) end

-- Cliente ----------------------------------------------------------------------------------------------------

---Modo de voz atual.
---@return number distance
---@return string label
---@return string id
function exports_coe_talk:GetVoiceRange() end

---Troca o modo de voz por id (`whisper`, `normal`, `shout`) ou distância.
---@param modeOrDistance string|number
---@return boolean ok
function exports_coe_talk:SetVoiceRange(modeOrDistance) end

---@return number|nil frequency
function exports_coe_talk:GetRadioChannel() end

---Pede ao servidor para entrar numa frequência (canais restritos exigem o job; ver `Config.Radio.restricted`).
---@param frequency number|nil `nil`/`0` sai do rádio
---@return boolean sent
function exports_coe_talk:SetRadioChannel(frequency) end

---@return string|nil callId
function exports_coe_talk:GetCallChannel() end

---Só sai da chamada atual (`nil`). Entrar numa chamada é decisão do servidor (`SetPlayerCall`).
---@param callId nil
---@return boolean ok `false` quando recebe um id
function exports_coe_talk:SetCallChannel(callId) end

---@return boolean talking
function exports_coe_talk:IsTalking() end

---@return boolean transmitting
function exports_coe_talk:IsRadioTransmitting() end

---Volume da voz recebida (0-100).
---@param volume number
---@return boolean ok
function exports_coe_talk:SetVoiceVolume(volume) end
