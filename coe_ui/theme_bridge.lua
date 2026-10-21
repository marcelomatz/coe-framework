-- Incluir nos client_scripts de cada resource com NUI: '@coe_ui/theme_bridge.lua'.
-- Entrega o tema e o idioma atuais à página (mensagens 'coe:theme', 'coe:accent', 'coe:locale'), tratadas por components.js.
local function push(theme)
	if theme and type(SendNUIMessage) == 'function' then
		SendNUIMessage({ action = 'coe:theme', theme = theme })
	end
end

local function currentTheme()
	local ok, theme = pcall(function()
		return exports.coe_ui:GetTheme()
	end)
	return ok and theme or nil
end

local function pushAccent(accent)
	if type(SendNUIMessage) == 'function' then
		SendNUIMessage({ action = 'coe:accent', accent = accent or 'theme' })
	end
end

local function currentAccent()
	local ok, accent = pcall(function()
		return exports.coe_ui:GetAccent()
	end)
	return ok and accent or 'theme'
end

local function currentLocale()
	local lang = 'pt-BR'
	local serverName = 'Coe RP'
	local dict = {}

	if Core and Core.Locale then
		if Core.Locale.GetDefaultLang then
			lang = Core.Locale.GetDefaultLang()
		end
		if Core.Locale.GetServerName then
			serverName = Core.Locale.GetServerName()
		end
		if Core.Locale.ExportForNui then
			dict = Core.Locale.ExportForNui(lang)
		end
	end

	return lang, dict, serverName
end

local function pushLocale(lang, dict, serverName)
	if type(SendNUIMessage) ~= 'function' then
		return
	end
	if not lang then
		lang, dict, serverName = currentLocale()
	end
	SendNUIMessage({
		action = 'coe:locale',
		lang = lang or 'pt-BR',
		dict = dict or {},
		serverName = serverName or 'Coe RP'
	})
end

local function pushAll()
	push(currentTheme())
	pushAccent(currentAccent())
	pushLocale()
end

-- A página avisa quando carrega; o tema ou o idioma podem ainda não ter chegado do servidor.
if type(RegisterNUICallback) == 'function' then
	RegisterNUICallback('coe_theme_ready', function(_, callback)
		pushAll()
		if type(callback) == 'function' then
			callback({ ok = true })
		end
	end)
end

if type(AddEventHandler) == 'function' then
	AddEventHandler('coe_ui:themeChanged', push)
	AddEventHandler('coe_ui:accentChanged', pushAccent)
	AddEventHandler('coe_locale:changed', function(newLang)
		local lang, dict, serverName = currentLocale()
		pushLocale(newLang or lang, dict, serverName)
	end)
	AddEventHandler('onClientResourceStart', function(resourceName)
		if resourceName == 'coe_ui' or (type(GetCurrentResourceName) == 'function' and resourceName == GetCurrentResourceName()) then
			if type(SetTimeout) == 'function' then
				SetTimeout(100, pushAll)
			else
				pushAll()
			end
		end
	end)
end
