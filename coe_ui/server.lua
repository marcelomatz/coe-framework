local KVP_KEY = 'coe_ui:theme'
local USER_THEME_PREFIX = 'coe_ui:user_theme:'
local USER_THEMES = { theme = true, lime = true, moss = true, cyan = true, ocean = true, amber = true, rose = true, violet = true }

local function isValid(name)
	if type(name) ~= 'string' then
		return false
	end
	for _, theme in ipairs(UiConfig.Themes) do
		if theme.name == name then
			return true
		end
	end
	return false
end

local function playerThemeKey(playerId)
	if type(GetPlayerIdentifiers) ~= 'function' then
		return nil
	end
	local identifiers = GetPlayerIdentifiers(playerId)
	if type(identifiers) ~= 'table' then
		return nil
	end
	local fallback = nil
	for _, id in ipairs(identifiers) do
		if type(id) == 'string' then
			if id:find('^license:') or id:find('^license2:') or id:find('^fivem:') or id:find('^steam:') then
				return USER_THEME_PREFIX .. id
			end
			fallback = fallback or (USER_THEME_PREFIX .. id)
		end
	end
	return fallback
end

local current = GetResourceKvpString(KVP_KEY)
if not isValid(current) then
	current = UiConfig.DefaultTheme
end

exports('GetTheme', function()
	return current
end)

exports('GetThemes', function()
	return { current = current, options = UiConfig.Themes }
end)

-- Retorna true ou um código de erro; só aceita chamada de UiConfig.Caller.
exports('SetTheme', function(name)
	if GetInvokingResource() ~= UiConfig.Caller then
		return 'forbidden'
	end
	if not isValid(name) then
		return 'invalid_theme'
	end
	current = name
	SetResourceKvp(KVP_KEY, name)
	TriggerClientEvent('coe_ui:setTheme', -1, name)
	return true
end)

RegisterNetEvent('coe_ui:requestTheme', function()
	TriggerClientEvent('coe_ui:setTheme', source, current)
end)

RegisterNetEvent('coe_ui:setUserTheme', function(name)
	if type(name) ~= 'string' or not USER_THEMES[name] then
		return
	end
	local key = playerThemeKey(source)
	if not key then
		return
	end
	if name == 'theme' then
		DeleteResourceKvp(key)
	else
		SetResourceKvp(key, name)
	end
end)

AddEventHandler('playerConnecting', function(_, _, deferrals)
	if type(deferrals) ~= 'table' or type(deferrals.handover) ~= 'function' then
		return
	end
	local key = playerThemeKey(source)
	local userTheme = key and GetResourceKvpString(key) or nil
	if not USER_THEMES[userTheme] or userTheme == 'theme' then
		userTheme = nil
	end
	deferrals.handover({
		theme = current,
		userTheme = userTheme
	})
end)
