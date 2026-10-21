Config = Config or {}

Config.Command = 'hud'
Config.KvpKey = 'coe_hud:prefs'
Config.FootIntervalMs = 250
Config.VehicleIntervalMs = 100

-- Opcoes aceitas nas preferencias; qualquer outro valor volta ao padrao.
Config.Options = {
	accent = { 'theme', 'lime', 'cyan', 'amber', 'rose', 'violet' },
	style = { 'glass', 'flat', 'minimal' },
	icons = { 'round', 'square', 'hex' },
	position = { 'left', 'right' },
	unit = { 'kmh', 'mph' },
	tint = { 'status', 'accent' },
	speedo = { 'panel', 'modern', 'modernpro', 'bold', 'retro', 'minimal', 'analog' },
	-- Area util do HUD: tela inteira ou centralizada em 16:9 / 21:9 (monitores ultrawide).
	aspect = { 'full', '16:9', '21:9' },
	-- Minimapa e bussola: sempre ou so dentro de veiculos (motorista ou passageiro).
	minimapMode = { 'always', 'vehicle' },
	locationMode = { 'always', 'vehicle' }
}

Config.Defaults = {
	accent = 'theme',
	style = 'glass',
	icons = 'round',
	position = 'left',
	unit = 'kmh',
	tint = 'status',
	speedo = 'panel',
	aspect = 'full',
	minimapMode = 'always',
	locationMode = 'always',
	-- Escala pela altura da tela (1080p = 100%), para o HUD ter o mesmo tamanho em 1440p e 4K.
	autoScale = true,
	scale = 100,
	showHealth = true,
	showVehicle = true,
	showNeeds = true,
	showLocation = true,
	showRoute = true,
	showPercent = false,
	showMinimap = true,
	showIndicators = true,
	showLogo = true
}

Config.ScaleMin = 70
Config.ScaleMax = 130

-- Modo de edicao (/hud): componentes posicionaveis. Cada um guarda x/y (canto superior esquerdo,
-- fracao 0-1 da tela; ausente = posicao padrao ancorada) e size (% do tamanho padrao).
-- A visibilidade de cada componente usa o show* correspondente.
Config.Layout = {
	components = { 'status', 'location', 'minimap', 'speedo', 'indicators', 'logo' },
	visibility = {
		status = 'showHealth',
		location = 'showLocation',
		minimap = 'showMinimap',
		speedo = 'showVehicle',
		indicators = 'showIndicators',
		logo = 'showLogo'
	},
	sizeMin = 50,
	sizeMax = 200
}

-- Opcoes do editor lembradas por jogador.
Config.EditorDefaults = { grid = true, safezone = false, anchors = true, hidden = true }
