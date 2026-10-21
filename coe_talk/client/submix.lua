-- coe_talk - Filtros e Efeitos Nativos RAGE Audio Submix (FiveM Enhanced)
Submix = { radioId = nil, phoneId = nil }

function Submix.Init()
	if not CreateAudioSubmix then return end

	-- Submix de Radio (Walkie-Talkie / Distorcao Tatica)
	if Config.Submix and Config.Submix.radio then
		pcall(function()
			local sub = CreateAudioSubmix('coe_talk_radio')
			if sub and sub ~= -1 then
				SetAudioSubmixEffectRadioFx(sub, 0)
				SetAudioSubmixEffectParamInt(sub, 0, GetHashKey('default'), 1)
				SetAudioSubmixEffectParamFloat(sub, 0, GetHashKey('rm_mix'), 0.16)
				SetAudioSubmixEffectParamFloat(sub, 0, GetHashKey('fudge'), 1.8)
				SetAudioSubmixEffectParamFloat(sub, 0, GetHashKey('o_freq_lo'), 350.0)
				SetAudioSubmixEffectParamFloat(sub, 0, GetHashKey('o_freq_hi'), 4800.0)
				AddAudioSubmixOutput(sub, 0)
				Submix.radioId = sub
			end
		end)
	end

	-- Submix de Telefone (Filtro de audio celular/telefone)
	if Config.Submix and Config.Submix.phone then
		pcall(function()
			local sub = CreateAudioSubmix('coe_talk_phone')
			if sub and sub ~= -1 then
				SetAudioSubmixEffectRadioFx(sub, 0)
				SetAudioSubmixEffectParamInt(sub, 0, GetHashKey('default'), 1)
				SetAudioSubmixEffectParamFloat(sub, 0, GetHashKey('rm_mix'), 0.05)
				SetAudioSubmixEffectParamFloat(sub, 0, GetHashKey('o_freq_lo'), 300.0)
				SetAudioSubmixEffectParamFloat(sub, 0, GetHashKey('o_freq_hi'), 3400.0)
				AddAudioSubmixOutput(sub, 0)
				Submix.phoneId = sub
			end
		end)
	end
end

-- Aplica o filtro de radio no jogador alvo
function Submix.ApplyRadio(targetServerId)
	if not Submix.radioId or not MumbleSetSubmixForServerId then return end
	pcall(function()
		MumbleSetSubmixForServerId(targetServerId, Submix.radioId)
	end)
end

-- Aplica o filtro de telefone no jogador alvo
function Submix.ApplyPhone(targetServerId)
	if not Submix.phoneId or not MumbleSetSubmixForServerId then return end
	pcall(function()
		MumbleSetSubmixForServerId(targetServerId, Submix.phoneId)
	end)
end

-- Remove filtros de submix do jogador alvo
function Submix.Clear(targetServerId)
	if not MumbleSetSubmixForServerId then return end
	pcall(function()
		MumbleSetSubmixForServerId(targetServerId, -1)
	end)
end
