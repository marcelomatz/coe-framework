MobileConfig = {
	Locale = 'pt-BR',

	-- O telefone só abre com este item no inventário do personagem (usar o item também abre).
	Item = 'phone',
	-- Comando e tecla padrão. Cada jogador troca a tecla em Configurações > Teclas > FiveM ("Abrir telefone").
	Command = 'telefone',
	OpenKey = 'F1',

	-- Número do personagem: gerado no primeiro uso, prefixo + dígitos aleatórios, exibido como 555-0123.
	Number = { Prefix = '555', Digits = 4 },

	Calls = {
		-- Segundos tocando antes de virar chamada perdida.
		RingSeconds = 30,
		-- Ligações mostradas em Recentes.
		RecentsLimit = 30
	},

	Contacts = { Max = 100, NameMax = 32 },

	-- BodyMax: caracteres por mensagem. ThreadsLimit: conversas listadas. HistoryLimit: mensagens por conversa.
	-- CooldownMs: intervalo mínimo entre mensagens enviadas pelo mesmo jogador.
	Messages = { BodyMax = 300, ThreadsLimit = 30, HistoryLimit = 50, CooldownMs = 1000 },

	-- Ajustes simples por personagem. Defaults valem até o jogador mudar.
	Settings = {
		Defaults = { silent = false, volume = 5, ringtone = 'classico', wallpaper = 'padrao' },
		Ringtones = { 'classico', 'digital', 'suave' },
		Wallpapers = { 'padrao', 'noite', 'oceano', 'grafite' }
	},

	-- Intervalo mínimo entre pedidos que gravam (contatos, ligações e ajustes) do mesmo jogador.
	ActionIntervalMs = 400,

	-- Pacote que assume o telefone (ex.: um smartphone completo com apps) chama o export Yield; o telefone básico
	-- encerra as ligações, fecha as telas e para de abrir até esse resource parar. A capacidade vem do server.cfg:
	--   add_ace resource.<nome> coe.mobile.yield allow
	Ace = { Yield = 'coe.mobile.yield' },

	-- Celular na mão enquanto a tela está aberta.
	Animation = {
		Prop = 'prop_npc_phone_02',
		Bone = 28422,
		Dict = 'cellphone@',
		VehicleDict = 'anim@cellphone@in_car@ps',
		Text = 'cellphone_text_read_base',
		Call = 'cellphone_call_listen_base'
	}
}
