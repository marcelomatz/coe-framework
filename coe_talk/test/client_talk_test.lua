-- Mocks de ambiente FiveM para testes do cliente
local messages, commands, serverEvents, keymaps = {}, {}, {}, {}
local currentProximity = nil
local voiceActive = false
local playerTalking = false

NetworkSetVoiceActive = function(active) voiceActive = active end
NetworkSetTalkerProximity = function(dist) currentProximity = dist end
NetworkIsPlayerTalking = function() return playerTalking end
PlayerId = function() return 1 end
GetPlayerServerId = function() return 1 end
PlayerPedId = function() return 100 end
DoesEntityExist = function() return true end
IsEntityDead = function() return false end
RequestAnimDict = function() end
HasAnimDictLoaded = function() return true end
TaskPlayAnim = function() end
StopAnimTask = function() end
GetGameTimer = function() return 1000 end
PlaySoundFrontend = function() end
Wait = function() end
CreateThread = function() end -- Nao dispara o loop infinito durante o teste unitario

SendNUIMessage = function(m) messages[#messages + 1] = m end
RegisterCommand = function(name, fn) commands[name] = fn end
RegisterKeyMapping = function(name, _, _, key) keymaps[name] = key end
TriggerServerEvent = function(name, ...) serverEvents[#serverEvents + 1] = { name = name, args = { ... } } end
TriggerEvent = function() end
RegisterNetEvent = function() end
AddEventHandler = function() end

MumbleSetSubmixForServerId = function() end
CreateAudioSubmix = function() return 1 end
SetAudioSubmixEffectRadioFx = function() end
SetAudioSubmixEffectParamInt = function() end
SetAudioSubmixEffectParamFloat = function() end
AddAudioSubmixOutput = function() end

local exportedFunctions = {}
exports = setmetatable({}, {
	__call = function(_, name, fn)
		exportedFunctions[name] = fn
	end,
	__index = function(_, resourceName)
		return exportedFunctions
	end
})

dofile('config.lua')
dofile('shared/rules.lua')
dofile('client/submix.lua')
dofile('client/radio.lua')
dofile('client/phone.lua')
dofile('client/main.lua')

local function eq(a, b, msg)
	if a ~= b then
		error(('%s: esperado %s, obtido %s'):format(msg, tostring(b), tostring(a)))
	end
end

-- Keybinds registradas
eq(keymaps['+talk'], 'N', 'tecla N para Push-To-Talk de voz')
eq(keymaps['coe_talk:voiceUp'], 'PAGEUP', 'tecla PAGEUP para aumentar alcance de voz')
eq(keymaps['coe_talk:voiceDown'], 'PAGEDOWN', 'tecla PAGEDOWN para diminuir alcance de voz')
eq(keymaps['+radioptt'], 'CAPITAL', 'tecla Caps Lock para PTT de radio')

-- Push-To-Talk na tecla N
eq(exports.coe_talk:IsTalking(), false, 'nao falando inicialmente')
commands['+talk']()
eq(exports.coe_talk:IsTalking(), true, 'falando ao segurar N')
eq(serverEvents[#serverEvents].name, 'coe_talk:server:setVoiceRange', 'evento de alcance enviado ao servidor')
eq(serverEvents[#serverEvents].args[2], true, 'transmissao ativa no servidor')

commands['-talk']()
eq(exports.coe_talk:IsTalking(), false, 'parou de falar ao soltar N')
eq(serverEvents[#serverEvents].args[2], false, 'transmissao inativa no servidor ao soltar PTT')

-- Comandos registrados
eq(type(commands['proximidade']), 'function', 'comando /proximidade registrado')
eq(type(commands['voz']), 'function', 'comando /voz registrado')
eq(type(commands['radio']), 'function', 'comando /radio registrado')

-- Teste de subir e descer proximidade (PAGEUP / PAGEDOWN)
local dist, label, id = exports.coe_talk:GetVoiceRange()
eq(dist, 5.0, 'distancia inicial e normal (5.0m)')
eq(id, 'normal', 'id inicial e normal')

-- Executa voiceUp -> vai para Grito (15.0m)
commands['coe_talk:voiceUp']()
dist, label, id = exports.coe_talk:GetVoiceRange()
eq(dist, 15.0, 'distancia apos voiceUp e grito (15.0m)')
eq(id, 'shout', 'id apos voiceUp e shout')

-- Executa voiceDown -> volta para Normal (5.0m)
commands['coe_talk:voiceDown']()
dist, label, id = exports.coe_talk:GetVoiceRange()
eq(dist, 5.0, 'distancia apos voiceDown e normal (5.0m)')
eq(id, 'normal', 'id apos voiceDown e normal')

-- Executa voiceDown novamente -> vai para Sussurro (1.5m)
commands['coe_talk:voiceDown']()
dist, label, id = exports.coe_talk:GetVoiceRange()
eq(dist, 1.5, 'distancia apos voiceDown e sussurro (1.5m)')
eq(id, 'whisper', 'id apos voiceDown e whisper')

-- Executa comando de proximidade -> vai para Normal (5.0m)
commands['proximidade']()
dist, label, id = exports.coe_talk:GetVoiceRange()
eq(dist, 5.0, 'distancia apos comando /proximidade (5.0m)')
eq(id, 'normal', 'id apos comando /proximidade e normal')

-- SetVoiceRange por ID
exports.coe_talk:SetVoiceRange('normal')
dist, label, id = exports.coe_talk:GetVoiceRange()
eq(dist, 5.0, 'SetVoiceRange(normal) funcionou')

-- Radio
Radio.members = { 1, 2, 3 }
Radio.frequency = 101.5

eq(Radio.transmitting, false, 'radio nao transmitindo inicialmente')
commands['+radioptt']()
eq(Radio.transmitting, true, 'radio transmitindo com PTT ativado')
eq(serverEvents[#serverEvents].name, 'coe_talk:server:startRadioTransmitting', 'evento de inicio enviado ao servidor')

commands['-radioptt']()
eq(Radio.transmitting, false, 'radio parou transmissao com PTT desativado')
eq(serverEvents[#serverEvents].name, 'coe_talk:server:stopRadioTransmitting', 'evento de fim enviado ao servidor')

-- Phone
Phone.SetCall('call_test_123')
eq(Phone.callId, 'call_test_123', 'id de chamada configurado')
Phone.SyncMembers('call_test_123', { 1, 2 })
eq(#Phone.members, 2, '2 membros na chamada')

Phone.SetCall(nil)
eq(Phone.callId, nil, 'chamada encerrada')
eq(#Phone.members, 0, 'membros limpos')

print('coe_talk client tests passed')
