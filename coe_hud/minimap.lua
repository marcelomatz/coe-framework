-- Minimapa reposicionavel pelo modo de edicao (/hud). A parte pura (retangulo na tela e
-- componentes nativos) e testavel fora do jogo; Apply e o unico ponto que chama natives.
MinimapLayout = {}

-- Posicoes padrao do GTA (frontend.xml), alinhadas a esquerda/baixo da safezone.
-- x/w estao em unidades 16:9; y/h em fracoes da altura. Com alinhamento B, y desloca a borda de baixo.
MinimapLayout.DEFAULTS = {
	minimap = { x = -0.0045, y = 0.002, w = 0.150, h = 0.188888 },
	minimap_mask = { x = 0.020, y = 0.032, w = 0.111, h = 0.159 },
	minimap_blur = { x = -0.03, y = 0.022, w = 0.266, h = 0.237 }
}

local function round(value)
	return math.floor(value * 10000 + 0.5) / 10000
end

local function clamp(value, min, max)
	return math.max(min, math.min(max, value))
end

MinimapLayout.RATIOS = { ['16:9'] = 16 / 9, ['21:9'] = 21 / 9 }

-- Area util do HUD na tela (fracoes): l = margem esquerda, w = largura. Telas mais estreitas
-- que a proporcao escolhida (ou 'full') usam a tela inteira.
function MinimapLayout.Area(mode, screenAspect)
	local ratio = MinimapLayout.RATIOS[mode]
	local aspect = tonumber(screenAspect)
	if not ratio or not aspect or aspect <= ratio then
		return { l = 0, w = 1 }
	end
	local width = round(ratio / aspect)
	return { l = round((1 - width) / 2), w = width }
end

-- Retangulo padrao deslocado para dentro da area util (a margem da safezone conta a partir dela).
function MinimapLayout.AreaBase(base, area)
	if not base or not area or area.l == 0 then
		return base
	end
	local copy = {}
	for key, value in pairs(base) do
		copy[key] = value
	end
	copy.l = round(base.l + area.l)
	copy.r = round(base.r + area.l)
	return copy
end

-- Retangulo do minimapa (fracoes 0-1) a partir do retangulo padrao (base, ja na area) e da entrada
-- do layout. x do layout e relativo a area util; y, a altura da tela. Sem x/y fica no canto padrao e
-- cresce para cima/direita; extended (> 1) e o bigmap do coe_map.
function MinimapLayout.Rect(base, entry, extended, area)
	if not base then
		return nil
	end
	area = area or { l = 0, w = 1 }
	local size = ((entry and tonumber(entry.size)) or 100) / 100
	local width, height = (base.r - base.l) * size, (base.b - base.t) * size
	local left, top = base.l, base.b - height
	if entry and entry.x and entry.y then
		left, top = area.l + entry.x * area.w, entry.y
	end
	left = clamp(left, area.l, math.max(area.l, area.l + area.w - width))
	top = clamp(top, 0, math.max(0, 1 - height))
	local bottom = top + height
	local factor = tonumber(extended) or 1.0
	if factor > 1 then
		-- O bigmap abre a partir do canto inferior esquerdo do minimapa.
		width, height = width * factor, height * factor
		top = bottom - height
	end
	return { l = round(left), t = round(top), r = round(left + width), b = round(bottom) }
end

-- Componentes nativos para um retangulo (nao estendido): desloca a partir do canto inferior
-- esquerdo padrao e escala mascara/desfoque junto, mantendo a proporcao entre eles.
function MinimapLayout.Components(base, rect, aspect)
	local scale = (rect.r - rect.l) / (base.r - base.l)
	local toNative = (aspect or (16 / 9)) / (16 / 9)
	local dx = (rect.l - base.l) * toNative
	local dy = rect.b - base.b
	local origin = MinimapLayout.DEFAULTS.minimap
	local out = {}
	for name, item in pairs(MinimapLayout.DEFAULTS) do
		out[name] = {
			x = round(origin.x + dx + (item.x - origin.x) * scale),
			y = round(origin.y + dy + (item.y - origin.y) * scale),
			w = round(item.w * scale),
			h = round(item.h * scale)
		}
	end
	return out
end

function MinimapLayout.Key(components)
	local parts = {}
	for _, name in ipairs({ 'minimap', 'minimap_mask', 'minimap_blur' }) do
		local item = components[name]
		parts[#parts + 1] = ('%s:%s:%s:%s'):format(item.x, item.y, item.w, item.h)
	end
	return table.concat(parts, '|')
end

local appliedKey = nil

-- Aplica as posicoes so quando mudam. O radar so le as novas posicoes depois de alternar o
-- bigmap uma vez; com o estendido do coe_map aberto a troca fica para a proxima aplicacao.
function MinimapLayout.Apply(components, extended)
	local key = MinimapLayout.Key(components)
	if key == appliedKey then
		return false
	end
	if (tonumber(extended) or 1.0) > 1 then
		return false
	end
	appliedKey = key
	for name, item in pairs(components) do
		SetMinimapComponentPosition(name, 'L', 'B', item.x, item.y, item.w, item.h)
	end
	CreateThread(function()
		SetRadarBigmapEnabled(true, false)
		Wait(0)
		SetRadarBigmapEnabled(false, false)
	end)
	return true
end

function MinimapLayout.Reset()
	appliedKey = nil
end
