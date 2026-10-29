Config = Config or {}

-- Modos de proximidade de voz (em metros)
Config.Modes = {
	{ id = 'whisper', label = 'Sussurrar', distance = 1.5, level = 1 },
	{ id = 'normal',  label = 'Normal',    distance = 5.0, level = 2 },
	{ id = 'shout',   label = 'Gritar',    distance = 15.0, level = 3 }
}

Config.DefaultModeIndex = 2 -- Normal

-- Teclas padrao (configuraveis pelo jogador no menu Teclado > FiveM)
Config.Keybinds = {
	talk = 'N',             -- Tecla padrao de conversa (Falar / Microfone)
	voiceUp = 'PAGEUP',     -- Aumentar alcance da voz (Subir voz)
	voiceDown = 'PAGEDOWN', -- Diminuir alcance da voz (Baixar voz)
	radioPtt = 'CAPITAL'    -- Falar no radio comunicador
}

-- Modo de conversa padrao: 'ptt' (Push-To-Talk / segurar tecla N) ou 'voice' (ativacao continua por voz)
Config.VoiceActivation = false

-- Frequencias de radio
Config.Radio = {
	enabled = true,
	minFrequency = 1.0,
	maxFrequency = 999.9,
	step = 0.1,
	-- Canais restritos para faccoes/servicos (COE, policia, samu)
	restricted = {
		[1] = { name = 'COE - Comando & Operações', jobs = { 'police', 'coe' } },
		[2] = { name = 'Polícia Militar',          jobs = { 'police', 'coe' } },
		[3] = { name = 'Polícia Civil',            jobs = { 'police', 'coe' } },
		[4] = { name = 'SAMU / Resgate',           jobs = { 'ems' } },
		[5] = { name = 'Corpo de Bombeiros',       jobs = { 'ems', 'fire' } }
	},
	-- Som de clique de transmissao (bip)
	clicks = true,
	-- Animacao de segurar o radio com a mao
	animation = true,
	animDict = 'random@arrests',
	animName = 'generic_radio_chatter'
}

-- Efeitos nativos RAGE Audio (FiveM Enhanced Submixes)
Config.Submix = {
	radio = true,
	phone = true
}

-- Intervalo de verificacao de voz em milissegundos
Config.VoiceTickMs = 150

-- Quem pode colocar jogadores em chamadas e radios pelos exports de servidor (SetPlayerCall/SetPlayerRadio).
-- Chamadas so entram pelo servidor (coe_mobile); scripts de terceiros: add_ace resource.<nome> coe.talk allow
Config.Access = {
	Ace = 'coe.talk',
	Resources = { coe_mobile = true }
}

-- Intervalo minimo entre eventos de voz/radio vindos do mesmo jogador (ms)
Config.EventCooldownMs = 250
