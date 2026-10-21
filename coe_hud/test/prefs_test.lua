-- Validacao do layout do modo de edicao (prefs.lua) e da matematica do minimapa (minimap.lua).
dofile('config.lua')
dofile('prefs.lua')
dofile('minimap.lua')

local function eq(a, b, msg)
	if a ~= b then error(('%s: esperado %s, obtido %s'):format(msg, tostring(b), tostring(a))) end
end

-- padrao: todos os componentes, ancorados, 100%
local defaults = Prefs.sanitize(nil)
for _, id in ipairs(Config.Layout.components) do
	eq(defaults.layout[id].size, 100, id .. ' tamanho padrao')
	eq(defaults.layout[id].x, nil, id .. ' sem x por padrao')
	eq(defaults.layout[id].y, nil, id .. ' sem y por padrao')
	eq(type(defaults[Config.Layout.visibility[id]]), 'boolean', id .. ' tem visibilidade')
end
eq(defaults.showIndicators, true, 'indicadores visiveis por padrao')
eq(defaults.editor.grid, true, 'grade ligada por padrao')
eq(defaults.editor.safezone, false, 'zona segura desligada por padrao')
eq(defaults.editor.anchors, true, 'zonas de ancora ligadas por padrao')
eq(defaults.editor.hidden, true, 'ocultos aparecem no editor por padrao')

-- coordenadas relativas validas sao mantidas e arredondadas
local p = Prefs.sanitize({ layout = { status = { x = 0.123456, y = 0.5, size = 120 } } })
eq(p.layout.status.x, 0.1235, 'x arredondado em 4 casas')
eq(p.layout.status.y, 0.5, 'y mantido')
eq(p.layout.status.size, 120, 'tamanho mantido')

-- limites
p = Prefs.sanitize({ layout = { status = { x = -3, y = 9, size = 999 }, speedo = { size = 1 } } })
eq(p.layout.status.x, 0, 'x limitado a 0')
eq(p.layout.status.y, 1, 'y limitado a 1')
eq(p.layout.status.size, 200, 'tamanho maximo')
eq(p.layout.speedo.size, 50, 'tamanho minimo')
eq(Prefs.sanitize({ layout = { status = { size = 101.6 } } }).layout.status.size, 102, 'tamanho inteiro')

-- x e y andam juntos; lixo volta ao padrao
p = Prefs.sanitize({ layout = { status = { x = 0.3 }, location = { x = 0.2, y = 'a' } } })
eq(p.layout.status.x, nil, 'so x: volta a ancorar')
eq(p.layout.location.x, nil, 'y invalido: volta a ancorar')
eq(p.layout.location.y, nil, 'y invalido some')
p = Prefs.sanitize({ layout = { status = { x = 0 / 0, y = 0.2, size = 0 / 0 } } })
eq(p.layout.status.x, nil, 'NaN descartado')
eq(p.layout.status.size, 100, 'tamanho NaN volta ao padrao')
p = Prefs.sanitize({ layout = { status = { x = math.huge, y = 0.2 } } })
eq(p.layout.status.x, nil, 'infinito descartado')
p = Prefs.sanitize({ layout = 'x' })
eq(p.layout.minimap.size, 100, 'layout invalido volta ao padrao')
p = Prefs.sanitize({ layout = { status = 'x', hacker = { x = 0.1, y = 0.1 } } })
eq(p.layout.status.size, 100, 'entrada invalida volta ao padrao')
eq(p.layout.hacker, nil, 'componente desconhecido descartado')

-- editor
p = Prefs.sanitize({ editor = { grid = false, safezone = 'sim', extra = true } })
eq(p.editor.grid, false, 'grade desligada mantida')
eq(p.editor.safezone, false, 'opcao invalida volta ao padrao')
eq(p.editor.extra, nil, 'opcao desconhecida descartada')

-- visibilidade dos componentes
eq(Prefs.sanitize({ showIndicators = false }).showIndicators, false, 'indicadores ocultos')
eq(Prefs.sanitize({ showIndicators = 'x' }).showIndicators, true, 'visibilidade invalida volta ao padrao')

-- minimapa: retangulo pelo layout
local base = { l = 0.025, r = 0.1656, t = 0.7988, b = 0.975 }
local rect = MinimapLayout.Rect(base, nil, 1)
eq(rect.l, 0.025, 'padrao no canto')
eq(rect.b, 0.975, 'padrao na base')
rect = MinimapLayout.Rect(base, { size = 200 }, 1)
eq(rect.l, 0.025, 'ancorado cresce a partir do canto')
eq(rect.b, 0.975, 'ancorado mantem a base')
eq(rect.r, 0.3062, 'largura dobrada')
eq(rect.t, 0.6226, 'altura dobrada para cima')
rect = MinimapLayout.Rect(base, { x = 0.95, y = 0.95, size = 100 }, 1)
eq(rect.r <= 1 and rect.b <= 1, true, 'minimapa movido fica dentro da tela')
rect = MinimapLayout.Rect(base, { x = 0.3, y = 0.2, size = 100 }, 1.9)
eq(rect.l, 0.3, 'estendido parte do canto movido')
eq(rect.b, 0.3762, 'estendido mantem a base movida')
eq(MinimapLayout.Rect(nil, nil, 1), nil, 'sem base sem retangulo')

-- componentes nativos: padrao igual ao do GTA; deslocamento e escala
local native = MinimapLayout.Components(base, MinimapLayout.Rect(base, nil, 1), 16 / 9)
for name, item in pairs(MinimapLayout.DEFAULTS) do
	eq(native[name].x, item.x, name .. ' x padrao')
	eq(native[name].y, item.y, name .. ' y padrao')
	eq(native[name].w, item.w, name .. ' w padrao')
end
native = MinimapLayout.Components(base, { l = 0.125, r = 0.2656, t = 0.6988, b = 0.875 }, 16 / 9)
eq(native.minimap.x, 0.0955, 'deslocamento horizontal em unidades 16:9')
eq(native.minimap.y, -0.098, 'deslocamento vertical pela base')
eq(math.floor((native.minimap_mask.x - native.minimap.x) * 10000 + 0.5), 245, 'mascara acompanha o minimapa')
native = MinimapLayout.Components(base, { l = 0.025, r = 0.1656 + 0.1406, t = 0.6226, b = 0.975 }, 21 / 9)
eq(native.minimap.w, 0.3, 'escala 2x na largura')
eq(native.minimap_mask.x, 0.0445, 'mascara escalada a partir do canto')
native = MinimapLayout.Components(base, { l = 0.125, r = 0.2656, t = 0.6988, b = 0.875 }, 21 / 9)
eq(native.minimap.x, 0.1268, 'tela ultrawide converte o deslocamento')

-- ultrawide e 4K
eq(defaults.aspect, 'full', 'area padrao e a tela inteira')
eq(defaults.autoScale, true, 'escala automatica ligada por padrao')
eq(Prefs.sanitize({ aspect = '16:9' }).aspect, '16:9', 'area 16:9 aceita')
eq(Prefs.sanitize({ aspect = '32:9' }).aspect, 'full', 'area desconhecida volta ao padrao')
eq(Prefs.sanitize({ autoScale = false }).autoScale, false, 'escala automatica desligada')

local area = MinimapLayout.Area('16:9', 21 / 9)
eq(area.w, 0.7619, '16:9 numa tela 21:9 ocupa 76% da largura')
eq(area.l, 0.1191, 'area centralizada')
eq(MinimapLayout.Area('21:9', 32 / 9).w, 0.6563, '21:9 numa tela 32:9')
eq(MinimapLayout.Area('21:9', 16 / 9).w, 1, 'tela mais estreita usa a tela inteira')
eq(MinimapLayout.Area('full', 32 / 9).w, 1, 'tela inteira')
local shifted = MinimapLayout.AreaBase(base, area)
eq(shifted.l, 0.1441, 'minimapa padrao entra na area')
eq(shifted.b, base.b, 'altura nao muda')
eq(MinimapLayout.AreaBase(base, { l = 0, w = 1 }), base, 'tela inteira mantem o retangulo')
rect = MinimapLayout.Rect(shifted, { x = 0.5, y = 0.2, size = 100 }, 1, area)
eq(rect.l, 0.5001, 'x do layout relativo a area (0.1191 + 0.5 * 0.7619)')
rect = MinimapLayout.Rect(shifted, { x = 1, y = 0.2, size = 100 }, 1, area)
eq(rect.r <= area.l + area.w + 0.0001, true, 'minimapa limitado a area')
native = MinimapLayout.Components(base, MinimapLayout.Rect(shifted, nil, 1, area), 21 / 9)
eq(native.minimap.x, 0.1518, 'radar nativo deslocado para a area em unidades 16:9')

eq(defaults.minimapMode, 'always', 'minimapa sempre por padrao')
eq(defaults.locationMode, 'always', 'bussola sempre por padrao')
eq(Prefs.sanitize({ minimapMode = 'vehicle' }).minimapMode, 'vehicle', 'minimapa so em veiculo')
eq(Prefs.sanitize({ locationMode = 'x' }).locationMode, 'always', 'modo invalido volta ao padrao')

print('coe_hud prefs tests passed')
