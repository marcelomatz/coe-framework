StaffConfig = {
	Locale = 'pt-BR',

	-- Comando e tecla padrão (só abre para quem tem alguma ACE abaixo). Cada jogador troca a tecla em
	-- Configurações > Teclas > FiveM ("Abrir painel da staff").
	Command = 'staff',
	OpenKey = 'F10',

	-- Uma ACE por módulo e uma que libera todos. No server.cfg, por exemplo:
	--   add_ace group.admin coe.staff.all allow
	--   add_ace group.moderator coe.staff.self allow
	--   add_ace group.moderator coe.staff.players allow
	Ace = {
		All = 'coe.staff.all',
		Modules = {
			self = 'coe.staff.self',           -- noclip, teleporte, curar, invisível, invencível, coordenadas
			players = 'coe.staff.players',     -- lista online, ir até, trazer, congelar, expulsar, item, dinheiro, grupos
			vehicles = 'coe.staff.vehicles',   -- criar, consertar, abastecer, limpar, desvirar, apagar
			hotel = 'coe.staff.hotel',
			garages = 'coe.staff.garages',
			rentals = 'coe.staff.rentals',     -- estações de aluguel: atendente, retirada, devolução e blip
			world = 'coe.staff.world',         -- hora, clima e aviso para todos
			businesses = 'coe.staff.businesses' -- criar e editar negócios, dono, equipe e pontos
		},
		-- Pacote que assume o painel (ex.: um painel completo): add_ace resource.<nome> coe.staff.yield allow
		Yield = 'coe.staff.yield'
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
