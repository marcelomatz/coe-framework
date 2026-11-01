-- DeepWeb: rede anônima acessada por níveis de equipamento. Quanto melhor o equipamento, mais conteúdo liberado.
-- Esta fase entrega o acesso (aparelhos e níveis), a identidade anônima (apelido com senha), os computadores
-- (notebook, desktop e servidor doméstico) e a mineração. Mercado, contratos, reputação e o risco de atenção da
-- polícia usam esta base nas próximas fases (`Features` já reserva o nível de cada um).
DeepwebConfig = {
	-- Níveis de equipamento. Celular e tablet precisam do navegador onion instalado (item `BrowserItem`).
	Tiers = {
		phone = { level = 1, label = 'Celular' },
		tablet = { level = 2, label = 'Tablet' },
		laptop = { level = 3, label = 'Notebook' },
		desktop = { level = 4, label = 'Desktop' },
		server = { level = 5, label = 'Servidor doméstico' }
	},

	-- Nível mínimo de cada recurso. `soon = true`: aparece bloqueado como "em breve" (próximas fases).
	Features = {
		{ id = 'identity', label = 'Identidade anônima', level = 1, description = 'Apelido com senha. Ninguém vê quem está por trás.' },
		{ id = 'search', label = 'DuckDark', level = 1, description = 'Buscador da rede: sites, posts do Rabbit e anúncios.' },
		{ id = 'forum', label = 'Rabbit', level = 1, description = 'Comunidades, posts, comentários e votos, pelo apelido.' },
		{ id = 'market_browse', label = 'Deep Market: vitrine', level = 1, description = 'Ver anúncios de jogadores e fornecedores.' },
		{ id = 'market_buy', label = 'Deep Market: comprar', level = 2, description = 'Comprar com cripto, com custódia até a entrega.' },
		{ id = 'market_sell', label = 'Deep Market: vender', level = 3, description = 'Anunciar e vender com reputação.' },
		{ id = 'forum_create', label = 'Rabbit: criar comunidade', level = 3, description = 'Abrir e moderar a sua própria comunidade.' },
		{ id = 'contracts', label = 'Contratos', level = 3, soon = true, description = 'Contratos entre jogadores com garantia em cripto.' },
		{ id = 'services', label = 'Serviços pagos', level = 4, soon = true, description = 'Lavagem, rastreio, informação e outros serviços.' },
		{ id = 'mining', label = 'Mineração', level = 4, description = 'Minerar cripto com a máquina instalada em casa.' },
		{ id = 'burn', label = 'Gravar navegador', level = 4, description = 'Gravar o navegador onion em pen drives vazios, na bancada do computador.' },
		{ id = 'hosting', label = 'Hospedar site', level = 5, soon = true, description = 'Seu próprio site oculto na rede, montado por blocos.' }
	},

	-- Itens. Notebook é portátil; desktop e servidor são instalados dentro de um imóvel (coe_housing).
	-- O navegador onion vem num pen drive que instala no celular (aparelho em uso) ou, sem celular, no tablet.
	Items = {
		Laptop = 'laptop',
		Desktop = 'desktop_pc',
		Server = 'home_server',
		Browser = 'onion_usb'
	},

	-- Computadores instalados: máximo por espaço de imóvel e distância para usar (metros).
	Install = { MaxPerSpace = 3, UseDistance = 2.5, Command = 'computador' },

	-- Apelidos: tamanho, senha, quantos cada personagem cria e reservados.
	Handles = {
		Min = 3, Max = 20, PasswordMin = 6, PasswordMax = 32, MaxPerCharacter = 3,
		LoginFailures = 5, LockSeconds = 60,
		Reserved = { admin = true, root = true, policia = true, police = true, lspd = true, fib = true, sistema = true, moderador = true }
	},

	-- Senha do computador (opcional): erros seguidos antes do bloqueio.
	Device = { PasswordMin = 4, PasswordMax = 32, Failures = 5, LockSeconds = 60 },

	-- Mineração (coe_crypto): poder (hash) e energia por rodada, cobrada do banco de quem instalou. Sem saldo ou com o
	-- contrato do imóvel vencido, a máquina não minera naquela rodada. A emissão vem do coe_crypto (MintMining).
	Mining = {
		TickMinutes = 10,
		Hash = { desktop = 10, server = 40 },
		PowerCost = { desktop = 35, server = 110 }
	},

	-- Bancada do computador (coe_crafting): desktop e servidor gravam o navegador onion em pen drives vazios.
	-- Abre pelo app Onion (aba Computador). A receita também pode ser liberada a facções no admin.
	Craft = {
		Bench = 'deepweb_rig',
		Label = 'Gravação de pen drive',
		Kinds = { desktop = true, server = true },
		Animation = { dict = 'anim@heists@prison_heiststation@cop_reactions', name = 'cop_b_idle' },
		Recipes = {
			{ id = 'hacking_onion_usb', label = 'Pen drive com navegador onion', category = 'hacking', timeMs = 45000,
				inputs = { { item = 'usb_black', count = 1 } }, outputs = { { item = 'onion_usb', count = 1 } } }
		}
	},

	-- Contato NPC do mercado negro: vende o navegador onion em espécie. Muda de lugar a cada `RotationMinutes`
	-- (todos os jogadores veem o mesmo lugar). Estoque por rodízio, para todo o servidor. Paga com o primeiro item de
	-- `Payment` que o jogador tiver em quantidade suficiente (dinheiro sujo primeiro). Cada venda tem `Alert.Chance`
	-- de abrir um chamado no coe_dispatch no local. Coordenadas provisórias: confira no jogo e ajuste.
	Dealer = {
		Enabled = true,
		Model = 'a_m_y_hipster_02',
		Scenario = 'WORLD_HUMAN_SMOKING',
		RotationMinutes = 120,
		SpawnDistance = 80.0,
		UseDistance = 3.0,
		CooldownSeconds = 10,
		Spots = {
			{ x = 195.17, y = -933.77, z = 30.69, heading = 144.0, label = 'Legion Square' },
			{ x = -1850.50, y = -1231.50, z = 13.02, heading = 320.0, label = 'Píer de Del Perro' },
			{ x = -60.00, y = -1745.00, z = 29.33, heading = 50.0, label = 'Davis, perto da Grove Street' },
			{ x = 1163.40, y = -323.80, z = 69.20, heading = 100.0, label = 'Mirror Park' },
			{ x = 1961.50, y = 3740.70, z = 32.34, heading = 300.0, label = 'Sandy Shores' }
		},
		Payment = { 'black_money', 'money' },
		Stock = {
			{ item = 'onion_usb', label = 'Pen drive com navegador onion', price = 2500, perRotation = 3 }
		},
		Alert = { Chance = 0.2, Code = 'suspicious_deal' }
	},

	-- Apps do computador: o navegador (este resource) e a carteira cripto (coe_crypto, se iniciado).
	ComputerApps = {
		{ id = 'onion', label = 'Onion', script = 'nui://coe_deepweb/html/deepweb.js' },
		{ id = 'crypto', label = 'Carteira', script = 'nui://coe_crypto/html/crypto.js', resource = 'coe_crypto' }
	},

	-- Smartphone e tablet chamam o app `onion` por estes resources.
	Hosts = { coe_phone = 'phone', coe_tablet = 'tablet' },

	-- Navegador: página inicial, abas e favoritos (por aparelho). O histórico fica só na sessão aberta.
	Browser = { Home = 'duckdark.onion', MaxTabs = 4, MaxBookmarks = 30, TitleMax = 48 },

	-- Sites da rede (`coe_deepweb_sites`). Os de sistema são recriados a cada início com estes dados; os outros são
	-- cadastrados no admin (staff) e, numa próxima fase, pelos jogadores (hospedagem, nível 5), montados por blocos.
	Sites = {
		System = {
			{ domain = 'duckdark.onion', app = 'search', title = 'DuckDark', description = 'Buscador da rede onion. Não rastreia, não lembra, não pergunta.', keywords = 'busca buscador pesquisa procurar search' },
			{ domain = 'rabbit.onion', app = 'forum', title = 'Rabbit', description = 'A toca da rede: comunidades, boatos, golpes, armas e tudo o que não passa no jornal.', keywords = 'forum comunidade post boato discussao reddit' },
			{ domain = 'deepmarket.onion', app = 'market', title = 'Deep Market', description = 'Mercado com custódia em NOX. Fornecedores verificados e vendedores com reputação.', keywords = 'mercado loja comprar vender produto servico droga arma deep market' },
			-- Conta da staff que cuida do mundo hacking. `listed = false`: fora do diretório e da busca do DuckDark;
			-- só chega quem souber o endereço. As mensagens do contato caem na aba DeepWeb do admin (Contatos).
			{
				domain = 'fantasma.onion', app = 'profile', title = 'Fantasma', listed = false,
				description = 'Quem cuida da rede. Se você chegou aqui, alguém te passou o endereço.', keywords = '',
				profile = {
					handle = 'fantasma',
					tagline = 'root@rede:~# whoami',
					bio = 'Eu vejo o tráfego passar. Mantenho a rede de pé, decido quem fica e quem cai, e respondo a quem tem algo que valha o meu tempo.\n\nNão faço favor. Não negocio com quem não sabe o que quer. Mensagem vaga vai para o lixo.',
					skills = { 'Intrusão', 'Engenharia reversa', 'Criptografia', 'Redes anônimas', 'Forense', 'Contrainteligência' },
					facts = {
						{ label = 'Status', value = 'online quando quer' },
						{ label = 'Chave', value = '7F3A 9C21 E04B 5D88 1A6F' },
						{ label = 'Resposta', value = 'pelo seu apelido, aqui mesmo' }
					},
					rules = { 'Diga quem te indicou.', 'Uma mensagem por assunto.', 'Nada de nomes reais.' },
					contact = true
				}
			}
		},
		DomainMin = 3, DomainMax = 24, TitleMax = 48, DescriptionMax = 200, KeywordsMax = 120,
		MaxBlocks = 30, BlockTextMax = 1200, ListItemsMax = 12,
		-- Nomes que ninguém registra (além dos sistemas).
		Reserved = { admin = true, root = true, policia = true, police = true, lspd = true, fib = true, sistema = true, onion = true, about = true, bazar = true }
	},

	-- Rabbit (fórum). Escrever exige apelido conectado; criar comunidade exige `forum_create`.
	Forum = {
		SlugMin = 3, SlugMax = 21, TitleMin = 4, TitleMax = 120, BodyMax = 2000, CommentMax = 800, CommunityTitleMax = 40,
		CommunityDescriptionMax = 200, MaxCommunitiesPerHandle = 2, PageSize = 20, MaxCommentsShown = 200, MaxDepth = 4,
		PostCooldownSeconds = 60, CommentCooldownSeconds = 10,
		-- Comunidades iniciais (criadas pelo sistema, sem moderador).
		Communities = {
			{ slug = 'geral', title = 'Geral', description = 'Qualquer assunto. Leia antes de postar: aqui ninguém conhece ninguém.' },
			{ slug = 'boatos', title = 'Boatos', description = 'O que está rolando na cidade e ninguém confirma.' },
			{ slug = 'golpes', title = 'Golpes', description = 'Quem passou a perna em quem. Denuncie vendedor ruim.' },
			{ slug = 'hacking', title = 'Hacking', description = 'Ferramentas, falhas e quem paga por elas.' },
			{ slug = 'armas', title = 'Armas', description = 'Peças, modelos e preços. Negócio fechado vai para o Deep Market.' },
			{ slug = 'bazar', title = 'Deep Market', description = 'Avaliações de vendedores e pedidos de mercadoria.' }
		}
	},

	-- Contato dos sites de perfil (`app = 'profile'` com `contact = true`): exige apelido conectado; a resposta da
	-- staff (admin, aba DeepWeb > Contatos) aparece na página para o mesmo apelido e avisa quem estiver online.
	Contact = { BodyMin = 10, BodyMax = 1000, ReplyMax = 1000, CooldownSeconds = 300, MaxOpen = 3, Shown = 20 },

	-- Deep Market (mercado). Preços em unidades da cripto (1 NOX = 10^4 unidades). O pagamento fica em custódia
	-- (`coe_crypto` escrow) até a entrega: itens são deixados e coletados num ponto de coleta (Drops); serviços são
	-- confirmados pelo comprador ou liberados sozinhos após `AutoReleaseHours`. A taxa vai para a reserva da corretora.
	Market = {
		-- Casas decimais da moeda (o mesmo `Coin.Decimals` do coe_crypto) para ler os preços digitados.
		CoinDecimals = 4,
		FeeBps = 500,
		MinPrice = 100, MaxPrice = 100000000000,
		TitleMin = 4, TitleMax = 60, DescriptionMax = 600, MaxStock = 999, MaxQuantity = 20, MaxCountPerUnit = 100,
		MaxListingsPerHandle = 10, PageSize = 24,
		-- Prazo para o vendedor entregar (depois disso o comprador cancela e recebe de volta) e para liberar sozinho.
		DeliverHours = 48, AutoReleaseHours = 72, DisputeMax = 200, ReviewMax = 200,
		-- Coleta/entrega no ponto: o botão do site arma o ponto (GPS + objeto com alvo do coetarget) e a ação é feita
		-- pelo alvo no local. DropDistance é a distância horizontal ao ponto; DropHeight a diferença de altura tolerada
		-- (as coordenadas dos pontos são provisórias). DropProp é o objeto local onde o alvo aparece.
		DropDistance = 3.0, DropHeight = 4.0, DropProp = 'prop_cs_cardbox_01', DropSpawnDistance = 60.0,
		-- Validade do ponto armado (o jogador precisa voltar ao site para armar de novo depois disso).
		DropTicketMinutes = 120,
		Categories = {
			{ id = 'drugs', label = 'Substâncias' },
			{ id = 'weapons', label = 'Armas e munição' },
			{ id = 'tools', label = 'Ferramentas e eletrônicos' },
			{ id = 'docs', label = 'Documentos' },
			{ id = 'services', label = 'Serviços' },
			{ id = 'other', label = 'Outros' }
		},
		-- Pontos de coleta (dead drops). Cada pedido sorteia um. Coordenadas provisórias: confira no jogo.
		Drops = {
			{ x = 1137.80, y = -1597.20, z = 34.69, label = 'Atrás do galpão de El Burro Heights' },
			{ x = -1176.10, y = -1582.40, z = 4.37, label = 'Lixeira da orla de Vespucci' },
			{ x = 478.30, y = -1278.60, z = 29.54, label = 'Pátio de trens de Strawberry' },
			{ x = -324.70, y = -1356.20, z = 31.30, label = 'Viaduto de La Mesa' },
			{ x = 1700.90, y = 3292.00, z = 41.15, label = 'Hangar abandonado de Sandy Shores' },
			{ x = -458.40, y = 6018.30, z = 31.49, label = 'Fundos do posto de Paleto Bay' }
		},
		-- Chance de chamar a atenção da polícia ao deixar ou coletar uma entrega.
		Alert = { Chance = 0.1, Code = 'suspicious_deal' },
		-- Fornecedores NPC iniciais (só na primeira vez; depois, gerenciados no admin).
		Vendors = {
			{ vendor = 'Fantasma', title = 'Pen drive com navegador onion', description = 'Gravado e testado. Instala no celular ou no tablet.', category = 'tools', item = 'onion_usb', count = 1, price = 12000, stock = 20 },
			{ vendor = 'Fantasma', title = 'Pen drive vazio', description = 'Sem marca, sem série, sem perguntas.', category = 'tools', item = 'usb_black', count = 1, price = 2500, stock = 50 }
		}
	},

	CallCooldownMs = 250,
	MaxPayloadBytes = 8192
}
