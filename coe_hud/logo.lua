-- Controle do logotipo do servidor na HUD.
Logo = { getPrefs = nil, savePrefs = nil }

local function notify(kind, message)
	if type(exports) == 'table' or type(exports) == 'userdata' then
		pcall(function()
			exports.coe_notify:Show(kind, message, 2000)
		end)
	end
end

function Logo.Init(getFn, saveFn)
	Logo.getPrefs = getFn
	Logo.savePrefs = saveFn
end

function Logo.IsVisible()
	local prefs = Logo.getPrefs and Logo.getPrefs()
	return not prefs or prefs.showLogo ~= false
end

function Logo.SetVisible(visible)
	if not Logo.getPrefs or not Logo.savePrefs then
		return false
	end
	local current = Logo.getPrefs()
	local next = Prefs.sanitize(current)
	next.showLogo = visible and true or false
	Logo.savePrefs(next)
	return next.showLogo
end

function Logo.Toggle()
	if not Logo.getPrefs or not Logo.savePrefs then
		return false
	end
	local current = Logo.getPrefs()
	local next = Prefs.sanitize(current)
	next.showLogo = not next.showLogo
	Logo.savePrefs(next)
	return next.showLogo
end

if RegisterCommand then
	RegisterCommand('logo', function()
		local visible = Logo.Toggle()
		local status = visible and 'visível' or 'oculto'
		notify('info', ('Logotipo do servidor: %s'):format(status))
	end, false)
end

if AddEventHandler then
	AddEventHandler('coe_hud:setLogoVisible', function(visible)
		Logo.SetVisible(visible)
	end)

	AddEventHandler('coe_hud:toggleLogo', function()
		Logo.Toggle()
	end)
end

if type(exports) == 'function' then
	pcall(function()
		exports('SetLogoVisible', Logo.SetVisible)
		exports('IsLogoVisible', Logo.IsVisible)
		exports('ToggleLogo', Logo.Toggle)
	end)
end
