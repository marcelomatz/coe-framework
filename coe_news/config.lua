-- Veículos de comunicação do COE OS. Cada veículo é um negócio da categoria `media` (coe_businesses) e tem o próprio
-- app (mesmo id do `Outlets`, cadastrado no coe_apps, no coe_phone e no coe_tablet).
NewsConfig = {
	Outlets = {
		weazel = {
			business = 'weazel_news',
			label = 'Weazel News',
			color = '#c8102e',
			region = 'Los Santos',
			tagline = 'Confirmado por fontes.',
			editorial = 'Cobertura de Los Santos: política, polícia, economia e a vida das celebridades.',
			-- Semente do negócio: criado uma única vez; depois área, pontos, dono e cargos ficam no admin.
			seed = {
				area = { kind = 'circle', x = -598.3, y = -929.8, z = 23.9, radius = 45.0 },
				clock = { x = -598.3, y = -929.8, z = 23.9 }
			}
		},
		rebel = {
			business = 'rebel_news',
			label = 'Rebel News',
			color = '#4a7c2c',
			region = 'Condado de Blaine',
			tagline = 'A voz do norte.',
			editorial = 'Jornalismo independente do condado de Blaine, de Paleto Bay a Sandy Shores.',
			seed = {
				area = { kind = 'circle', x = -150.0, y = 6305.0, z = 31.5, radius = 40.0 },
				clock = { x = -150.0, y = 6305.0, z = 31.5 }
			}
		}
	},

	-- Editorias disponíveis. Cada veículo escolhe quais usa na linha editorial.
	Sections = {
		{ id = 'news', label = 'Notícias' },
		{ id = 'events', label = 'Acontecimentos' },
		{ id = 'gossip', label = 'Fofocas' },
		{ id = 'opinion', label = 'Opinião' },
		{ id = 'police', label = 'Polícia' },
		{ id = 'economy', label = 'Economia' },
		{ id = 'sports', label = 'Esportes' }
	},
	DefaultSections = { 'news', 'events', 'gossip' },

	-- Permissões de cargo registradas no coe_businesses (o dono tem todas).
	Permissions = {
		{ name = 'news.write', label = 'Escrever matérias' },
		{ name = 'news.publish', label = 'Revisar e publicar matérias' },
		{ name = 'news.ads', label = 'Aprovar anúncios' },
		{ name = 'news.editorial', label = 'Definir a linha editorial' }
	},

	-- Cargos da semente de cada veículo.
	Grades = {
		{ id = 'estagiario', label = 'Estagiário', level = 0, salary = 250, permissions = { 'news.write' } },
		{ id = 'reporter', label = 'Repórter', level = 10, salary = 500, permissions = { 'news.write' } },
		{ id = 'editor', label = 'Editor', level = 20, salary = 800, permissions = { 'news.write', 'news.publish', 'news.ads' } },
		{ id = 'chefe', label = 'Editor-chefe', level = 30, salary = 1200,
			permissions = { 'news.write', 'news.publish', 'news.ads', 'news.editorial', 'business.staff', 'business.funds', 'business.remote' } }
	},

	Editorial = { TaglineMax = 80, EditorialMax = 600 },

	Articles = {
		TitleMax = 100,
		LeadMax = 240,
		BodyMax = 6000,
		NoteMax = 200,
		PageSize = 15,
		DeskMax = 60,
		SearchMax = 40,
		-- Rascunhos e matérias em revisão por autor, em cada veículo.
		MaxDraftsPerAuthor = 15,
		SaveCooldownSeconds = 3,
		-- Urgente: avisa quem tem o app; um por veículo a cada `BreakingCooldownMinutes`.
		BreakingCooldownMinutes = 10
	},

	Ads = {
		DefaultPricePerDay = 500,
		MinPricePerDay = 50,
		MaxPricePerDay = 50000,
		Days = { 1, 3, 7 },
		AdvertiserMax = 48,
		TitleMax = 60,
		BodyMax = 300,
		NoteMax = 160,
		-- Anúncios aguardando aprovação por comprador, em cada veículo.
		MaxPendingPerBuyer = 3,
		MaxActivePerOutlet = 30,
		-- Sem decisão em `PendingHours`, o anúncio é recusado e o valor volta para quem pagou.
		PendingHours = 48,
		-- Anúncios intercalados no feed (um a cada N matérias).
		FeedEvery = 4,
		History = 20
	},

	-- Equipamentos de imprensa: itens do coe_inventory (definidos em coe_inventory/data/coe_base_items.lua). O admin
	-- (aba Imprensa) abastece o baú `Stash` do negócio e a equipe retira lá. Usar o item segura o equipamento com a
	-- animação; usar de novo, entrar num veículo ou apertar `CancelKey` guarda. Offsets e rotações são ponto de
	-- partida: confira no jogo.
	Equipment = {
		Stash = 'arquivo',
		StashSlots = 40,
		MaxPerOperation = 20,
		CancelKey = 73, -- X
		Items = {
			{
				name = 'news_camera', label = 'Câmera de TV', prop = 'prop_v_cam_01', bone = 28422,
				offset = { 0.0, 0.0, 0.0 }, rotation = { 0.0, 0.0, 0.0 },
				dict = 'missfinale_c2mcs_1', anim = 'fin_c2_mcs_1_camman', flag = 49
			},
			{
				name = 'news_mic', label = 'Microfone', prop = 'p_ing_microphonel_01', bone = 60309,
				offset = { 0.055, 0.05, 0.0 }, rotation = { 240.0, 0.0, 0.0 },
				dict = 'missheistdocksprep1hold_cellphone', anim = 'hold_cellphone', flag = 49
			},
			{
				name = 'news_boom', label = 'Microfone boom', prop = 'prop_v_bmike_01', bone = 28422,
				offset = { -0.08, 0.0, 0.0 }, rotation = { 0.0, 0.0, 0.0 },
				dict = 'missfra1', anim = 'mcs2_crew_idle_m_boom', flag = 49
			}
		}
	},

	-- Modelos sugeridos na frota do veículo (garagem de negócio, aba Imprensa > Equipamentos). Confira a pintura no jogo.
	SuggestedVehicles = { 'rumpo', 'maverick' },

	-- Quem chama os exports de administração (AdminOverview, AdminQuery, AdminAction).
	AdminResources = { coe_admin = true },

	TickSeconds = 60
}
