AdminToolsConfig = {
	Locale = 'pt-BR',

	-- Comando e tecla padrão (só abre para quem tem alguma ACE abaixo). Cada jogador troca a tecla em
	-- Configurações > Teclas > FiveM ("Abrir painel da staff").
	Command = 'staff',
	-- F10 é do painel (Config.OpenKey): quem só tem as ferramentas abre direto nelas pela mesma tecla.
	OpenKey = nil,

	-- Uma ACE por módulo e uma que libera todos. No server.cfg, por exemplo:
	--   add_ace group.admin coe.staff.all allow
	--   add_ace group.moderator coe.staff.self allow
	--   add_ace group.moderator coe.staff.players allow
	-- ACEs das ferramentas (no principal do jogador). coe_admin.root libera tudo. As ACEs do painel básico
	-- (coe.staff.*) continuam valendo: quem era staff no básico segue com as mesmas ferramentas depois do upgrade.
	Ace = {
		All = 'coe_admin.tools.all',
		Modules = {
			self = 'coe_admin.tools.self',           -- noclip, teleporte, curar, invisível, invencível, coordenadas
			players = 'coe_admin.tools.players',     -- lista online, ir até, trazer, congelar, expulsar, item, dinheiro, grupos
			vehicles = 'coe_admin.tools.vehicles',   -- criar, consertar, abastecer, limpar, desvirar, apagar
			world = 'coe_admin.tools.world',         -- hora, clima e aviso para todos
			businesses = 'coe_admin.tools.businesses' -- criar e editar negócios, dono, equipe e pontos
		},
		Legacy = {
			All = 'coe.staff.all',
			Modules = {
				self = 'coe.staff.self', players = 'coe.staff.players', vehicles = 'coe.staff.vehicles',
				world = 'coe.staff.world', businesses = 'coe.staff.businesses'
			}
		}
	},

	-- Intervalo mínimo entre ações do mesmo admin e tamanho máximo do payload vindo da tela.
	ActionIntervalMs = 200,
	MaxPayloadBytes = 4096,

	Limits = {
		MaxItemCount = 1000,
		MaxMoney = 10000000,
		MaxKickReason = 120,
		MaxAnnouncement = 200,
		VehicleSearch = 40,
		MaxStationRadius = 5.0,
		MinAreaRadius = 3.0,
		MaxAreaRadius = 300.0
	},

	-- Motivo no extrato do coe_economy para dinheiro dado ou retirado pela staff.
	MoneyReason = 'admin_adjustment',

	-- Climas oferecidos na aba Mundo.
	Weathers = {
		'EXTRASUNNY', 'CLEAR', 'CLOUDS', 'OVERCAST', 'SMOG', 'FOGGY', 'RAIN', 'THUNDER', 'CLEARING', 'SNOW', 'XMAS', 'HALLOWEEN'
	},

	Noclip = { Speeds = { 0.5, 1.5, 4.0, 10.0 } }
}
