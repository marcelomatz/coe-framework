dofile('config.lua')
dofile('prefs.lua')
dofile('logo.lua')

local function eq(a, b, msg)
	if a ~= b then error(('%s: esperado %s, obtido %s'):format(msg, tostring(b), tostring(a))) end
end

local saved = nil
local state = Prefs.sanitize(nil)

Logo.Init(function()
	return state
end, function(next)
	saved = next
	state = next
end)

-- Visibilidade padrao e true
eq(Logo.IsVisible(), true, 'logo visivel por padrao')

-- Toggle inverte
local res = Logo.Toggle()
eq(res, false, 'toggle desliga logo')
eq(Logo.IsVisible(), false, 'logo desativado')
eq(saved.showLogo, false, 'preferencia gravada com showLogo false')

-- Toggle inverte novamente
res = Logo.Toggle()
eq(res, true, 'toggle liga logo novamente')
eq(Logo.IsVisible(), true, 'logo ativado')
eq(saved.showLogo, true, 'preferencia gravada com showLogo true')

-- SetVisible direto
Logo.SetVisible(false)
eq(Logo.IsVisible(), false, 'SetVisible(false) funcionou')
Logo.SetVisible(true)
eq(Logo.IsVisible(), true, 'SetVisible(true) funcionou')

print('coe_hud logo tests passed')
