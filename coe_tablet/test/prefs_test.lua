-- Preferências do COE OS no tablet (papel de parede, brilho, tamanho, dock), validadas antes de ir para o KVP.
dofile('shared/prefs.lua')

local function eq(a, b, m)
	if a ~= b then error(('%s: esperado %s, veio %s'):format(m, tostring(b), tostring(a)), 2) end
end

local p = TabletPrefs.Sanitize(nil)
eq(p.wallpaper, 'padrao', 'papel de parede padrao')
eq(p.brightness, 100, 'brilho padrao')
eq(p.scale, 100, 'tamanho padrao')
eq(p.dock, nil, 'dock automatica por padrao')

p = TabletPrefs.Sanitize({ wallpaper = 'oceano', brightness = 55.4, scale = 110 })
eq(p.wallpaper, 'oceano', 'papel de parede valido')
eq(p.brightness, 55, 'brilho arredondado')
eq(p.scale, 110, 'tamanho valido')

p = TabletPrefs.Sanitize({ wallpaper = 'x', brightness = 5, scale = 300 })
eq(p.wallpaper, 'padrao', 'papel de parede invalido volta ao padrao')
eq(p.brightness, 30, 'brilho minimo')
eq(p.scale, 100, 'tamanho invalido volta ao padrao')
eq(TabletPrefs.Sanitize({ brightness = 0 / 0 }).brightness, 100, 'brilho NaN')
eq(TabletPrefs.Sanitize({ brightness = 999 }).brightness, 100, 'brilho maximo')

p = TabletPrefs.Sanitize({ dock = { 'bank', 'bank', 'business:12', 'a b', 7, 'car', 'mail', 'news', 'store', 'crypto' } })
eq(#p.dock, TabletPrefs.DockMax, 'dock limitada')
eq(p.dock[1], 'bank', 'dock mantem a ordem')
eq(p.dock[2], 'business:12', 'id de instancia aceito e repetido descartado')
eq(p.dock[3], 'car', 'ids invalidos descartados')
eq(#TabletPrefs.Sanitize({ dock = {} }).dock, 0, 'dock vazia fica vazia')
eq(TabletPrefs.Sanitize({ dock = 'bank' }).dock, nil, 'dock invalida volta a automatica')

print('coe_tablet prefs tests passed')
