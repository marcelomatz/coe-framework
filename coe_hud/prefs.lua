-- Validacao pura das preferencias do HUD (sem natives), testavel fora do jogo.
Prefs = {}

local function oneOf(list, value, fallback)
	for _, option in ipairs(list) do
		if option == value then
			return value
		end
	end
	return fallback
end

local function bool(value, fallback)
	if type(value) == 'boolean' then
		return value
	end
	return fallback
end

local function finite(value)
	local number = tonumber(value)
	if not number or number ~= number or number == math.huge or number == -math.huge then
		return nil
	end
	return number
end

local function fraction(value)
	local number = finite(value)
	if not number then
		return nil
	end
	number = math.max(0, math.min(1, number))
	return math.floor(number * 10000 + 0.5) / 10000
end

-- Uma entrada do layout: x/y juntos (ou nenhum = posicao padrao) e tamanho limitado.
local function layoutEntry(raw)
	local source = type(raw) == 'table' and raw or {}
	local size = finite(source.size) or 100
	size = math.floor(math.max(Config.Layout.sizeMin, math.min(Config.Layout.sizeMax, size)) + 0.5)
	local x, y = fraction(source.x), fraction(source.y)
	if x == nil or y == nil then
		x, y = nil, nil
	end
	return { x = x, y = y, size = size }
end

function Prefs.sanitizeLayout(raw)
	local source = type(raw) == 'table' and raw or {}
	local layout = {}
	for _, id in ipairs(Config.Layout.components) do
		layout[id] = layoutEntry(source[id])
	end
	return layout
end

function Prefs.sanitizeEditor(raw)
	local source = type(raw) == 'table' and raw or {}
	local editor = {}
	for key, fallback in pairs(Config.EditorDefaults) do
		editor[key] = bool(source[key], fallback)
	end
	return editor
end

function Prefs.sanitize(raw)
	local defaults = Config.Defaults
	local source = type(raw) == 'table' and raw or {}
	local scale = tonumber(source.scale)
	if not scale or scale ~= scale then
		scale = defaults.scale
	end
	scale = math.floor(math.max(Config.ScaleMin, math.min(Config.ScaleMax, scale)))

	return {
		accent = oneOf(Config.Options.accent, source.accent, defaults.accent),
		style = oneOf(Config.Options.style, source.style, defaults.style),
		icons = oneOf(Config.Options.icons, source.icons, defaults.icons),
		position = oneOf(Config.Options.position, source.position, defaults.position),
		unit = oneOf(Config.Options.unit, source.unit, defaults.unit),
		tint = oneOf(Config.Options.tint, source.tint, defaults.tint),
		speedo = oneOf(Config.Options.speedo, source.speedo, defaults.speedo),
		aspect = oneOf(Config.Options.aspect, source.aspect, defaults.aspect),
		minimapMode = oneOf(Config.Options.minimapMode, source.minimapMode, defaults.minimapMode),
		locationMode = oneOf(Config.Options.locationMode, source.locationMode, defaults.locationMode),
		autoScale = bool(source.autoScale, defaults.autoScale),
		scale = scale,
		showHealth = bool(source.showHealth, defaults.showHealth),
		showVehicle = bool(source.showVehicle, defaults.showVehicle),
		showNeeds = bool(source.showNeeds, defaults.showNeeds),
		showLocation = bool(source.showLocation, defaults.showLocation),
		showRoute = bool(source.showRoute, defaults.showRoute),
		showPercent = bool(source.showPercent, defaults.showPercent),
		showMinimap = bool(source.showMinimap, defaults.showMinimap),
		showIndicators = bool(source.showIndicators, defaults.showIndicators),
		showLogo = bool(source.showLogo, defaults.showLogo),
		layout = Prefs.sanitizeLayout(source.layout),
		editor = Prefs.sanitizeEditor(source.editor)
	}
end
