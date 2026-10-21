-- Guia de estilos: /coeui abre a página com todos os componentes (útil para revisar o visual).
local open = false
local THEME_CACHE_KEY = 'coe_ui:theme_cache'
local ACCENT_KEY = 'coe_ui:accent'
local ACCENTS = { theme = true, lime = true, moss = true, cyan = true, ocean = true, amber = true, rose = true, violet = true }

local theme = GetResourceKvpString(THEME_CACHE_KEY)
if type(theme) ~= 'string' or theme == '' then
	theme = UiConfig and UiConfig.DefaultTheme or 'moss'
end
local themeConfirmed = false

local accent = GetResourceKvpString(ACCENT_KEY)
if not ACCENTS[accent] then
	accent = 'theme'
end

-- Tema escolhido pelo jogador (local ao cliente e espelhado no servidor para a loadscreen).
-- 'theme' significa sem tema próprio: usa o tema padrão do servidor.
exports('GetAccent', function()
	return accent
end)

exports('SetAccent', function(name)
	if not ACCENTS[name] then
		return
	end
	accent = name
	SetResourceKvp(ACCENT_KEY, name)
	TriggerEvent('coe_ui:accentChanged', name)
	TriggerServerEvent('coe_ui:setUserTheme', name)
end)

exports('GetTheme', function()
	return theme
end)

RegisterNetEvent('coe_ui:setTheme', function(name)
	if type(name) ~= 'string' then
		return
	end
	theme = name
	themeConfirmed = true
	SetResourceKvp(THEME_CACHE_KEY, name)
	-- Evento local do client: os theme_bridge dos demais resources repassam às suas NUIs.
	TriggerEvent('coe_ui:themeChanged', name)
end)

CreateThread(function()
	TriggerServerEvent('coe_ui:setUserTheme', accent)
	TriggerEvent('coe_ui:themeChanged', theme)
	TriggerEvent('coe_ui:accentChanged', accent)
	while not themeConfirmed do
		TriggerServerEvent('coe_ui:requestTheme')
		Wait(2000)
	end
end)

local function setOpen(value)
	open = value
	SetNuiFocus(value, value)
	SendNUIMessage({ action = value and 'open' or 'close' })
end

RegisterCommand('coeui', function()
	setOpen(not open)
end, false)

RegisterNUICallback('close', function(_, callback)
	setOpen(false)
	callback({ ok = true })
end)

AddEventHandler('onResourceStop', function(resourceName)
	if resourceName == GetCurrentResourceName() and open then
		SetNuiFocus(false, false)
	end
end)
