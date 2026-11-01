-- Voz da ligação na API de voz do FiveM para GTAV Enhanced (server-side; as natives Mumble estão deprecadas).
-- Cada ligação atendida ganha um canal não espacial (2D) só com os dois jogadores; desligar apaga o canal.
-- A voz de proximidade continua normal: quem está perto de quem fala ao telefone também ouve.
PhoneVoice = {}

local NON_SPATIAL = 0
local MAX_CHANNELS = 65535
local warned = false

local function log(level, event, context)
	pcall(function()
		return exports.coe_logging:Log(level, 'system', event, context or {})
	end)
end

local function supported()
	local ok = type(CreateVoiceChannel) == 'function' and type(AddPlayerToVoiceChannel) == 'function'
		and type(DeleteVoiceChannel) == 'function'
	if not ok and not warned then
		warned = true
		log('warn', 'phone_voice_unsupported', { result = 'missing_voice_natives' })
	end
	return ok
end

-- Abre o canal da ligação e coloca os dois jogadores. Devolve o id do canal ou nil.
function PhoneVoice.Open(playerA, playerB)
	if not supported() then
		return nil
	end
	local ok, channel = pcall(CreateVoiceChannel, NON_SPATIAL, 0.0)
	if not ok or type(channel) ~= 'number' or channel < 0 or channel >= MAX_CHANNELS then
		log('error', 'phone_voice_failed', { operation = 'create', error_code = tostring(channel):sub(1, 120) })
		return nil
	end
	for _, playerId in ipairs({ playerA, playerB }) do
		local added, errorCode = pcall(AddPlayerToVoiceChannel, channel, playerId)
		if not added then
			log('error', 'phone_voice_failed', { operation = 'add', player_id = playerId, error_code = tostring(errorCode):sub(1, 120) })
		end
	end
	return channel
end

function PhoneVoice.Close(channel)
	if type(channel) == 'number' and supported() then
		pcall(DeleteVoiceChannel, channel)
	end
end
