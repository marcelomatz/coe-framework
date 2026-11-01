CoeTabletConfig = {
	Command = 'tablet',
	-- Outros comandos que abrem o tablet (o do tablet de trabalho básico do framework, para quem fez o upgrade).
	CommandAliases = { 'trabalho' },
	-- Tecla padrão para abrir o tablet. Cada jogador pode trocar em Configurações > Teclas > FiveM.
	OpenKey = 'F3',
	-- Comandos que abrem o tablet já dentro de um app (ex.: /casa abre o app Casa ou Esconderijo, o primeiro que o jogador vê).
	-- O botão Início leva à tela com todos os apps do jogador. Sem nenhum app do atalho visível, recebe `deniedMessage`.
	Shortcuts = {
		casa = { apps = { 'home', 'hideout' }, deniedMessage = 'Você não é dono de nenhum imóvel.' }
	},

	-- Quem tem a ACE `coe_tablet.all` vê todos os aplicativos (administração e testes).
	AdminAce = 'coe_tablet.all',

	-- Rótulo da interface por emprego (tipo `job` do coe_core). Emprego sem entrada usa o nome do grupo.
	Profiles = {
		mechanic = { label = 'Oficina' }
	},
	-- Rótulo por categoria do negócio em que o jogador está de ponto (empregos vivem em negócios).
	CategoryLabels = {
		police = 'Polícia',
		ems = 'Hospital',
		mechanic = 'Oficina',
		shop = 'Loja',
		gas_station = 'Posto',
		restaurant = 'Restaurante',
		media = 'Redação',
		other = 'Negócio'
	},

	-- Item do inventário que também abre o tablet (o comando /tablet abre sem item).
	BusinessTabletItem = 'business_tablet',

	-- Seções da tela inicial do COE OS, na ordem. Cada app indica a sua em `group` (padrão: personal).
	Groups = {
		{ id = 'personal', label = 'Pessoal' },
		{ id = 'apps', label = 'Aplicativos' },
		{ id = 'work', label = 'Trabalho' },
		{ id = 'business', label = 'Negócios' },
		{ id = 'illegal', label = 'Ilegal' }
	},

	-- Aplicativos. `jobs` lista os empregos que enxergam o app; `minGrade` é o grau mínimo.
	-- `categories` libera o app a quem está de ponto em um negócio da categoria (ex.: police); `anyDuty`, a quem está
	-- de ponto em qualquer negócio; `item` exige o item no inventário; `everyone`, todo personagem.
	-- `resource` responde às ações pelo export `TabletCall(source, appId, action, payload)`; com `ownerCheck`, o export
	-- `TabletVisible(source, appId)` decide se o app aparece.
	-- `script` é carregado na NUI (somente `nui://<resource>/html/<arquivo>.js`).
	-- `icon` (home, hideout, business, workshop, mdt, bank, car, faction, key, store, jobs, cart, news, camera, mail, tv, radio, crypto, onion, clock) e `color` (hex) definem o ícone na tela inicial.
	-- `instances = true`: o resource responde `TabletInstances(source)` com `{ id, label }[]` e cada item vira um app
	-- (ex.: um app por negócio do jogador); `TabletCall` recebe o id da instância como 5º argumento.
	Apps = {
		-- Loja e apps instaláveis (coe_apps, compartilhados com o smartphone). A loja é nativa; os demais aparecem
		-- depois de instalados por ela (coe_apps:TabletVisible).
		store = {
			label = 'Loja',
			order = 40,
			ownerCheck = true,
			resource = 'coe_apps',
			script = 'nui://coe_apps/html/apps.js',
			icon = 'store', color = '#3f8f7a', group = 'apps'
		},
		jobs = {
			label = 'Empregos',
			order = 41,
			ownerCheck = true,
			resource = 'coe_apps',
			script = 'nui://coe_apps/html/apps.js',
			icon = 'jobs', color = '#4f7cac', group = 'apps'
		},
		classifieds = {
			label = 'Classificados',
			order = 42,
			ownerCheck = true,
			resource = 'coe_apps',
			script = 'nui://coe_apps/html/apps.js',
			icon = 'news', color = '#c17a3a', group = 'apps'
		},
		insta = {
			label = 'Insta',
			order = 43,
			ownerCheck = true,
			resource = 'coe_apps',
			script = 'nui://coe_apps/html/apps.js',
			icon = 'camera', color = '#b5487a', group = 'apps'
		},
		amzg = {
			label = 'Amzg',
			order = 44,
			ownerCheck = true,
			resource = 'coe_amzg',
			script = 'nui://coe_amzg/html/amzg.js',
			icon = 'cart', color = '#e08a2c', group = 'apps'
		},
		-- Rede profissional (coe_elos): vem instalada em todo aparelho pela loja (coe_apps).
		elos = {
			label = 'Elos',
			order = 49,
			ownerCheck = true,
			resource = 'coe_elos',
			script = 'nui://coe_elos/html/elos.js',
			icon = 'jobs', color = '#2f86a6', group = 'apps'
		},
		mail = {
			label = 'E-mail',
			order = 45,
			ownerCheck = true,
			resource = 'coe_mail',
			script = 'nui://coe_mail/html/mail.js',
			icon = 'mail', color = '#3a7bd5', group = 'apps'
		},
		-- Portais de notícias (coe_news): um app por veículo de comunicação, todos no mesmo script.
		weazel = {
			label = 'Weazel News',
			order = 46,
			ownerCheck = true,
			resource = 'coe_news',
			script = 'nui://coe_news/html/news.js',
			icon = 'tv', color = '#c8102e', group = 'apps'
		},
		rebel = {
			label = 'Rebel News',
			order = 47,
			ownerCheck = true,
			resource = 'coe_news',
			script = 'nui://coe_news/html/news.js',
			icon = 'radio', color = '#4a7c2c', group = 'apps'
		},
		-- Carteira cripto (coe_crypto): instalada pela Loja.
		crypto = {
			label = 'Cripto',
			order = 48,
			ownerCheck = true,
			resource = 'coe_crypto',
			script = 'nui://coe_crypto/html/crypto.js',
			icon = 'crypto', color = '#c9973a', group = 'apps'
		},
		-- Navegador onion (coe_deepweb): aparece depois de instalado pelo pen drive (item onion_usb).
		onion = {
			label = 'Onion',
			order = 32,
			ownerCheck = true,
			resource = 'coe_deepweb',
			script = 'nui://coe_deepweb/html/deepweb.js',
			icon = 'onion', color = '#6a4fb3', group = 'illegal'
		},
		bank = {
			label = 'Banco',
			order = 0,
			everyone = true,
			resource = 'coe_banking',
			script = 'nui://coe_banking/html/tablet_app.js',
			icon = 'bank', color = '#2e8b57', group = 'personal'
		},
		-- Carreira nos empregos livres (coe_jobs): XP, habilidades, reputação e cada emprego com GPS.
		career = {
			label = 'Carreira',
			order = 4,
			everyone = true,
			resource = 'coe_jobs',
			script = 'nui://coe_jobs/html/career.js',
			icon = 'career', color = '#b8862e', group = 'personal'
		},
		vehicles = {
			label = 'Veículos',
			order = 1,
			everyone = true,
			resource = 'coe_garages',
			script = 'nui://coe_garages/html/tablet_app.js',
			icon = 'car', color = '#c0504d', group = 'personal'
		},
		home = {
			label = 'Casa',
			order = 2,
			-- Só aparece para o dono de um local de portas (coe_doors:TabletVisible).
			ownerCheck = true,
			resource = 'coe_doors',
			script = 'nui://coe_doors/html/tablet_app.js',
			icon = 'home', color = '#4f9d69', group = 'personal',
			deniedMessage = 'Você não é dono de nenhuma casa.'
		},
		rentals = {
			label = 'Aluguéis',
			order = 3,
			-- Só aparece para quem tem contrato de aluguel, pessoal ou do negócio (coe_housing:TabletVisible).
			ownerCheck = true,
			resource = 'coe_housing',
			script = 'nui://coe_housing/html/tablet_app.js',
			icon = 'key', color = '#b08d57', group = 'personal'
		},
		hideout = {
			label = 'Esconderijo',
			order = 30,
			-- Só aparece para o dono de um imóvel ilegal (coe_housing:TabletVisible).
			ownerCheck = true,
			resource = 'coe_housing',
			script = 'nui://coe_housing/html/tablet_app.js',
			icon = 'hideout', color = '#6b5b95', group = 'illegal',
			deniedMessage = 'Você não controla nenhum local restrito.'
		},
		-- Ponto e Empregos livres: os mesmos do tablet de trabalho básico do framework (coe_workpad), que este tablet
		-- substitui. Respondidos pelo próprio coe_tablet (server/work.lua).
		duty = {
			label = 'Ponto',
			order = 6,
			ownerCheck = true,
			resource = 'coe_tablet',
			script = 'nui://coe_tablet/html/duty.js',
			icon = 'clock', color = '#5a8f6a', group = 'work'
		},
		freejobs = {
			label = 'Empregos livres',
			order = 7,
			ownerCheck = true,
			resource = 'coe_tablet',
			script = 'nui://coe_tablet/html/freejobs.js',
			icon = 'jobs', color = '#4f7cac', group = 'work'
		},
		business = {
			label = 'Negócio',
			order = 5,
			-- Um app por negócio de que o jogador é dono ou da equipe.
			instances = true,
			resource = 'coe_businesses',
			script = 'nui://coe_businesses/html/tablet_app.js',
			icon = 'business', color = '#3d7ab8', group = 'business'
		},
		workshop = {
			label = 'Diagnóstico',
			order = 10,
			jobs = { mechanic = true },
			minGrade = 0,
			resource = 'coe_mechanic',
			script = 'nui://coe_mechanic/html/tablet_app.js',
			icon = 'workshop', color = '#d08a3a', group = 'work'
		},
		faction = {
			label = 'Facção',
			order = 31,
			-- Um app por facção do personagem.
			instances = true,
			resource = 'coe_factions',
			script = 'nui://coe_factions/html/tablet_app.js',
			icon = 'faction', color = '#8b2635', group = 'illegal'
		},
		-- Corridas ilegais (coe_races): o mesmo app do tablet de corridas, para quem carrega o item race_tablet.
		races = {
			label = 'Corridas',
			order = 33,
			item = 'race_tablet',
			resource = 'coe_races',
			script = 'nui://coe_races/html/app.js',
			icon = 'car', color = '#ff2e88', group = 'illegal'
		},
		mdt = {
			label = 'MDT',
			order = 20,
			categories = { police = true },
			resource = 'coe_mdt',
			script = 'nui://coe_mdt/html/tablet_app.js',
			icon = 'mdt', color = '#2f5d9c', group = 'work'
		}
	},

	-- Ações por segundo e tamanho máximo do payload vindo da NUI.
	CallCooldownMs = 250,
	MaxPayloadBytes = 2048,
	-- Respostas com `data` maior que isso (ex.: fotos) seguem por evento latente nesta velocidade.
	LatentReplyBytes = 16000,
	LatentBytesPerSecond = 250000,
	-- Raio para detectar o veículo mais próximo ao escanear.
	NearestVehicleRadius = 6.0
}
