dofile('route.lua')

local function eq(a, b, msg)
	if a ~= b then error(('%s: esperado %s, obtido %s'):format(msg, tostring(b), tostring(a))) end
end

-- Mapa fake (heading 0 = norte): Main em x ~ 0; Esq cruza a esquerda em y=60; Dir cruza a direita em y=90; Frente comeca em y=120.
local function nameAt(x, y)
	if y >= 120 then return 'Frente' end
	if y >= 55 and y <= 65 and x < -20 then return 'Esq' end
	if y >= 85 and y <= 95 and x > 20 then return 'Dir' end
	return 'Main'
end

local steps = Route.Next({ x = 0.0, y = 0.0, z = 0.0 }, 0.0, 0.0, nameAt)
eq(#steps, 3, 'tres ruas')
eq(steps[1].name, 'Esq', 'primeira: esquerda')
eq(steps[1].side, 'esquerda', 'lado esquerda')
eq(steps[1].dist, 60, 'distancia da esquerda')
eq(steps[2].name, 'Dir', 'segunda: direita')
eq(steps[2].side, 'direita', 'lado direita')
eq(steps[3].name, 'Frente', 'terceira: a frente')
eq(steps[3].side, 'frente', 'lado frente')

-- virado para oeste (heading 90), a rua que estava a direita (leste) passa a ficar atras e a esquerda do norte vira direita
local rotated = Route.Next({ x = 0.0, y = 0.0, z = 0.0 }, 90.0, 0.0, function(x, y)
	if x <= -60 and x >= -70 and y > 20 then return 'Norte' end
	return 'Main'
end)
eq(rotated[1].name, 'Norte', 'rua ao norte')
eq(rotated[1].side, 'direita', 'norte e a direita quando se olha para oeste')

-- alcance cresce com a velocidade e nunca passa do limite
eq(Route.Reach(0), 180.0, 'alcance minimo')
eq(Route.Reach(1000), 600.0, 'alcance maximo')

-- sem nomes: lista vazia
eq(#Route.Next({ x = 0.0, y = 0.0, z = 0.0 }, 0.0, 10.0, function() return '' end), 0, 'sem nomes')

print('coe_hud route tests passed')
