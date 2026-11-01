-- Preferências do COE OS (tablet) guardadas por jogador em KVP no client. Validação pura, testável fora do jogo.
TabletPrefs = {}

TabletPrefs.Wallpapers = { 'padrao', 'noite', 'oceano', 'brasa', 'floresta', 'grafite' }
TabletPrefs.Scales = { 90, 100, 110 }
TabletPrefs.DockMax = 6
TabletPrefs.Defaults = { wallpaper = 'padrao', brightness = 100, scale = 100, dock = nil }

local function oneOf(list, value, fallback)
	for _, option in ipairs(list) do
		if option == value then
			return value
		end
	end
	return fallback
end

-- dock = nil: o tablet escolhe os primeiros apps do jogador. Lista: ids únicos, até DockMax.
local function dockOf(raw)
	if type(raw) ~= 'table' then
		return nil
	end
	local dock, seen = {}, {}
	for _, id in ipairs(raw) do
		if type(id) == 'string' and #id > 0 and #id <= 64 and id:match('^[%w_:%-]+$') and not seen[id] then
			seen[id] = true
			dock[#dock + 1] = id
			if #dock >= TabletPrefs.DockMax then
				break
			end
		end
	end
	return dock
end

function TabletPrefs.Sanitize(raw)
	local source = type(raw) == 'table' and raw or {}
	local brightness = tonumber(source.brightness)
	if not brightness or brightness ~= brightness then
		brightness = TabletPrefs.Defaults.brightness
	end
	return {
		wallpaper = oneOf(TabletPrefs.Wallpapers, source.wallpaper, TabletPrefs.Defaults.wallpaper),
		brightness = math.floor(math.max(30, math.min(100, brightness)) + 0.5),
		scale = oneOf(TabletPrefs.Scales, tonumber(source.scale), TabletPrefs.Defaults.scale),
		dock = dockOf(source.dock)
	}
end
