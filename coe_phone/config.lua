-- Smartphone do COE OS: Telefone, Contatos e Mensagens, mais os apps da loja (coe_apps), que são os mesmos do tablet.
CoePhoneConfig = {
	Command = 'celular',
	-- Outros comandos que abrem o celular (o do telefone básico do framework, para quem fez o upgrade).
	CommandAliases = { 'telefone' },
	-- Tecla padrão. Cada jogador troca em Configurações > Teclas > FiveM ("Abrir smartphone (COE OS)").
	OpenKey = 'F1',
	-- Aparelhos: cada item é um celular com serial próprio (metadata.serial), gravado na primeira vez que é aberto.
	-- Quem tem o item (e a senha) usa o aparelho. Devices: item do inventário -> modelo.
	-- Modelo: sims (slots de chip), storage (MB para fotos) e camera (largura máxima em px e qualidade JPEG da foto).
	Devices = { phone = 'coe_one' },
	Models = {
		coe_one = { label = 'COE One', sims = 1, storage = 32, camera = { width = 960, quality = 0.72 } }
	},
	-- Chip da operadora (item com metadata.iccid). Usar o item coloca o chip no celular; Ajustes > Chip retira.
	SimItem = 'sim_card',

	-- Números: prefixo + dígitos aleatórios, exibidos como 555-0123. O número fica no chip; o primeiro aparelho
	-- de quem ainda não tem chip já vem com um.
	Number = { Prefix = '555', Digits = 4 },

	Calls = {
		RingSeconds = 30,
		RecentsLimit = 40
	},

	Contacts = { Max = 200, NameMax = 32 },
	Messages = { BodyMax = 500, ThreadsLimit = 50, HistoryLimit = 60, CooldownMs = 1000 },

	-- Fotos (Câmera e Galeria): ficam no aparelho (serial), limitadas pelo storage do modelo.
	-- MaxBytes/ThumbMaxBytes: tamanho máximo do JPEG em base64. Thumb: largura da miniatura da galeria.
	-- PageSize: miniaturas por página. CooldownMs: intervalo mínimo entre fotos salvas.
	Photos = { MaxBytes = 400000, ThumbMaxBytes = 30000, ThumbWidth = 240, PageSize = 24, CooldownMs = 2000, UploadBytesPerSecond = 200000 },

	-- Carteira digital: cartões do coe_banking guardados no aparelho (serial), sem backup na nuvem. Cada pagamento é
	-- confirmado com o rosto cadastrado ou a senha do aparelho e gera uma autorização de uso único que vale
	-- PaymentSeconds, consumida por um resource de PaymentCallers (export ConsumePayment).
	Wallet = { MaxCards = 6, PaymentSeconds = 60, LabelMax = 48, MaxAmount = 100000, PaymentCallers = { coe_apps = true, coe_amzg = true, coe_shops = true, coe_fuel = true } },

	-- Volume máximo do toque (volume 10 nos Ajustes), de 0 a 1. Toque e vibração são gerados na interface.
	RingVolume = 0.5,

	-- Telas iniciais: apps por tela (4 colunas x 4 linhas), máximo de telas e de apps na barra inferior.
	Home = { PageSize = 16, MaxPages = 6, DockSize = 4 },

	-- Ajustes de cada aparelho (coe_phone_devices). Defaults valem até o jogador mudar.
	Settings = {
		Defaults = {
			airplane = false, wifi = true, bluetooth = false,
			silent = false, vibrate = true, dnd = false, volume = 5, ringtone = 'classico',
			wallpaper = 'padrao', brightness = 100, faceId = false
		},
		Ringtones = { 'classico', 'digital', 'suave', 'pulso' },
		Wallpapers = { 'padrao', 'noite', 'oceano', 'brasa', 'floresta', 'grafite' },
		Brightness = { Min = 30, Max = 100 },
		-- Senha só com dígitos, de MinLength a MaxLength. Erros seguidos bloqueiam o desbloqueio por LockoutSeconds.
		Passcode = { MinLength = 4, MaxLength = 6, Attempts = 5, LockoutSeconds = 30 }
	},

	-- Sinal: barras pela distância (no plano) até a antena mais próxima. Ranges em metros para 4, 3, 2 e 1 barra.
	-- Sem sinal (0 barras) não liga nem manda mensagem, e quem liga para você ouve "fora de área".
	-- No cliente, ambientes fechados tiram 1 barra (mínimo 1) e debaixo d'água fica sem sinal.
	Signal = {
		Ranges = { 700, 1300, 2100, 3000 },
		Towers = {
			{ 150.0, -800.0 }, { -1300.0, -900.0 }, { -1000.0, -2600.0 }, { 700.0, -2700.0 }, { 1200.0, -1700.0 },
			{ 0.0, 600.0 }, { 900.0, 1000.0 }, { -3100.0, 500.0 }, { -2300.0, 1500.0 }, { -2300.0, 3100.0 },
			{ -200.0, 2000.0 }, { 500.0, 2700.0 }, { 1800.0, 3700.0 }, { 2000.0, 4900.0 }, { 3000.0, 4500.0 },
			{ 500.0, 5600.0 }, { -200.0, 6300.0 }, { 2500.0, -300.0 }, { 2600.0, 1800.0 }
		}
	},

	-- Apps. `native`: tela do próprio coe_phone. `resource = 'coe_apps'`: app da loja, que só aparece se instalado
	-- (coe_apps:TabletVisible). `dock`: fica na barra inferior. Ícones: phone, contacts, messages, settings, store, jobs, news, camera, shutter, gallery, editor, sim, wallet, bank, cart, mail, tv, radio, crypto, onion.
	-- A ordem e a tela de cada app são do jogador (Ajustes > Tela inicial); order e dock valem para o layout padrão.
	Apps = {
		phone = { label = 'Telefone', order = 1, native = true, dock = true, icon = 'phone', color = '#3f9a5c' },
		messages = { label = 'Mensagens', order = 2, native = true, dock = true, icon = 'messages', color = '#3d7ab8' },
		contacts = { label = 'Contatos', order = 3, native = true, dock = true, icon = 'contacts', color = '#8a6d3b' },
		settings = { label = 'Ajustes', order = 5, native = true, icon = 'settings', color = '#5b6470' },
		camera = { label = 'Câmera', order = 7, native = true, icon = 'shutter', color = '#3b4350' },
		gallery = { label = 'Galeria', order = 8, native = true, icon = 'gallery', color = '#c0605a' },
		wallet = { label = 'Carteira', order = 13, native = true, icon = 'wallet', color = '#2b2f36' },
		store = { label = 'Loja', order = 4, resource = 'coe_apps', script = 'nui://coe_apps/html/apps.js', dock = true, icon = 'store', color = '#3f8f7a' },
		insta = { label = 'Insta', order = 10, resource = 'coe_apps', script = 'nui://coe_apps/html/apps.js', icon = 'camera', color = '#b5487a' },
		classifieds = { label = 'Classificados', order = 11, resource = 'coe_apps', script = 'nui://coe_apps/html/apps.js', icon = 'news', color = '#c17a3a' },
		jobs = { label = 'Empregos', order = 12, resource = 'coe_apps', script = 'nui://coe_apps/html/apps.js', icon = 'jobs', color = '#4f7cac' },
		-- Internet banking (coe_banking): o mesmo app Banco do tablet, para todo personagem.
		bank = { label = 'Banco', order = 6, resource = 'coe_banking', script = 'nui://coe_banking/html/tablet_app.js', icon = 'bank', color = '#2e8b57' },
		-- Rede profissional (coe_elos): vem instalada em todo aparelho (builtin na loja do coe_apps).
		elos = { label = 'Elos', order = 20, resource = 'coe_elos', script = 'nui://coe_elos/html/elos.js', icon = 'jobs', color = '#2f86a6' },
		mail = { label = 'E-mail', order = 15, resource = 'coe_mail', script = 'nui://coe_mail/html/mail.js', icon = 'mail', color = '#3a7bd5' },
		weazel = { label = 'Weazel News', order = 16, resource = 'coe_news', script = 'nui://coe_news/html/news.js', icon = 'tv', color = '#c8102e' },
		rebel = { label = 'Rebel News', order = 17, resource = 'coe_news', script = 'nui://coe_news/html/news.js', icon = 'radio', color = '#4a7c2c' },
		amzg = { label = 'Amzg', order = 14, resource = 'coe_amzg', script = 'nui://coe_amzg/html/amzg.js', icon = 'cart', color = '#e08a2c' },
		editor = { label = 'Estúdio', order = 9, resource = 'coe_apps', script = 'nui://coe_apps/html/editor.js', icon = 'editor', color = '#7a5bb5' },
		-- Operadora: só aparece com o coe_telecom iniciado.
		line = { label = 'Minha linha', order = 6, resource = 'coe_telecom', script = 'nui://coe_telecom/html/line.js', icon = 'sim', color = '#6b5bb5' },
		-- Carteira cripto (coe_crypto, instalada pela Loja) e navegador onion (coe_deepweb, instalado por pen drive).
		crypto = { label = 'Cripto', order = 18, resource = 'coe_crypto', script = 'nui://coe_crypto/html/crypto.js', icon = 'crypto', color = '#c9973a' },
		onion = { label = 'Onion', order = 19, resource = 'coe_deepweb', script = 'nui://coe_deepweb/html/deepweb.js', icon = 'onion', color = '#6a4fb3' }
	},

	CallCooldownMs = 200,
	MaxPayloadBytes = 2048,
	LatentReplyBytes = 16000,
	LatentBytesPerSecond = 250000
}
