WorkpadConfig = {
	Locale = 'pt-BR',

	-- O tablet só abre com este item no inventário do personagem (usar o item também abre).
	Item = 'business_tablet',
	-- Comando e tecla padrão. Cada jogador troca a tecla em Configurações > Teclas > FiveM ("Abrir tablet de trabalho").
	Command = 'trabalho',
	OpenKey = 'F3',

	-- Seções da tela inicial, na ordem. Cada app indica a sua em `group`.
	Groups = {
		{ id = 'work', label = 'Trabalho' },
		{ id = 'business', label = 'Negócios' }
	},

	-- Apps. `resource` responde pelo export TabletCall(playerId, appId, action, payload, instance); os apps deste
	-- resource (`native`) respondem aqui mesmo. `script` é a interface (só nui://<resource>/html/<arquivo>.js).
	-- `instances = true`: o resource lista as instâncias do jogador (TabletInstances) e cada uma vira um app
	-- (ex.: um app por negócio). Um app cujo resource não está de pé não aparece.
	Apps = {
		duty = {
			label = 'Ponto', order = 1, group = 'work', icon = 'clock', native = true,
			resource = 'coe_workpad', script = 'nui://coe_workpad/html/duty.js'
		},
		freejobs = {
			label = 'Empregos livres', order = 2, group = 'work', icon = 'jobs', native = true,
			resource = 'coe_workpad', script = 'nui://coe_workpad/html/freejobs.js', requires = 'coe_jobs'
		},
		career = {
			label = 'Carreira', order = 3, group = 'work', icon = 'career',
			resource = 'coe_jobs', script = 'nui://coe_jobs/html/career.js'
		},
		business = {
			label = 'Negócio', order = 10, group = 'business', icon = 'business', instances = true,
			resource = 'coe_businesses', script = 'nui://coe_businesses/html/tablet_app.js'
		}
	},

	-- Rótulo de cada categoria de negócio (Ponto e ícones dos negócios).
	CategoryLabels = {
		mechanic = 'Mecânica', shop = 'Loja', gas_station = 'Posto', restaurant = 'Restaurante',
		police = 'Polícia', ems = 'Hospital', media = 'Mídia', other = 'Negócio'
	},

	-- Intervalo mínimo entre ações e tamanho máximo do payload vindo da tela.
	CallCooldownMs = 250,
	MaxPayloadBytes = 2048,

	-- Pacote que assume o tablet (ex.: um tablet completo com mais apps) chama o export Yield; o tablet básico fecha
	-- as telas e para de abrir até esse resource parar. A capacidade vem do server.cfg:
	--   add_ace resource.<nome> coe.workpad.yield allow
	Ace = { Yield = 'coe.workpad.yield' },

	-- Tablet na mão enquanto a tela está aberta.
	Animation = {
		Prop = 'prop_cs_tablet',
		Bone = 28422,
		Dict = 'amb@code_human_in_bus_passenger_idles@female@tablet@base',
		Name = 'base'
	}
}
