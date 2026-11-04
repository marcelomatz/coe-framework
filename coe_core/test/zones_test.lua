-- test/zones_test.lua
-- Testes unitários do subsistema espacial Core.Zones / CoeZones

local Zones = dofile('lib/zones.lua')

local function eq(actual, expected, msg)
	if actual ~= expected then
		error(string.format('%s: esperado [%s], obtido [%s]', msg or 'eq falhou', tostring(expected), tostring(actual)), 2)
	end
end

-- 1. Registro e consulta em grade espacial 2D (esferas)
do
	local z = Zones.New({ cellSize = 50.0 })
	eq(z.Count(), 0, 'inicia vazio')

	z.AddSphere('bank_1', { x = 150.0, y = -1040.0, z = 29.3, radius = 2.5, data = 'fleeca' })
	z.AddSphere('bank_2', { x = -1212.0, y = -330.0, z = 37.8, radius = 2.5, data = 'rockford' })
	eq(z.Count(), 2, 'duas zonas registradas')

	-- Longe de qualquer zona: Query retorna vazio
	local far = z.Query(2000.0, 2000.0, 30.0)
	eq(#far, 0, 'nenhuma candidata longe')

	-- Perto de bank_1 (mesma célula / vizinhança 3x3)
	local near = z.Query(151.0, -1039.5, 29.3)
	eq(#near, 1, 'uma candidata na célula vizinha')
	eq(near[1].id, 'bank_1', 'id correto na consulta espacial')

	-- Dentro do raio de bank_1
	local best, dist, hasNear = z.Nearest(151.0, -1040.0, 29.3)
	eq(best and best.id, 'bank_1', 'Nearest encontra bank_1')
	eq(dist, 1.0, 'distância exata')
	eq(hasNear, true, 'hasNear verdadeiro')

	-- Fora do raio de bank_1, mas ainda próximo (10m)
	local outZone, _, stillNear = z.Nearest(160.0, -1040.0, 29.3)
	eq(outZone, nil, 'fora do raio não ativa a zona')
	eq(stillNear, true, 'ainda detecta proximidade para intervalo adaptativo')

	-- Remoção limpa a grade espacial
	eq(z.Remove('bank_1'), true, 'remove bank_1')
	eq(z.Count(), 1, 'resta 1 zona')
	eq(#z.Query(150.0, -1040.0, 29.3), 0, 'grade espacial limpa após remoção')
end

-- 2. Zona retangular orientada (AddBox) e filtro canInteract
do
	local z = Zones.New({ cellSize = 50.0 })
	local allowed = false
	z.AddBox('garage_spot', {
		x = 0.0, y = 0.0, z = 10.0,
		length = 6.0, width = 4.0, height = 4.0, heading = 0.0,
		canInteract = function() return allowed end
	})

	local hit = z.Nearest(1.0, 2.0, 10.0)
	eq(hit, nil, 'canInteract falso bloqueia ativação')

	allowed = true
	hit = z.Nearest(1.0, 2.0, 10.0)
	eq(hit and hit.id, 'garage_spot', 'canInteract verdadeiro libera ativação')

	local outside = z.Nearest(3.0, 0.0, 10.0)
	eq(outside, nil, 'fora da largura da caixa (halfWidth = 2.0)')
end

-- 3. Evento de interação unificado (OnInteract) e deduplicação de SetPrompt
do
	local handlers = {}
	local nuiMessages = {}
	AddEventHandler = function(name, fn)
		handlers[name] = fn
	end
	SendNUIMessage = function(msg)
		nuiMessages[#nuiMessages + 1] = msg
	end

	local triggered = 0
	Zones.OnInteract(function()
		triggered = triggered + 1
	end)
	assert(type(handlers['coe_core:interact']) == 'function', 'registrou handler coe_core:interact')
	handlers['coe_core:interact']()
	eq(triggered, 1, 'disparou callback OnInteract')

	Zones.SetPrompt({ title = 'Banco', subtitle = 'Agência', options = { { key = 'E', label = 'Atendimento' } } })
	Zones.SetPrompt({ title = 'Banco', subtitle = 'Agência', options = { { key = 'E', label = 'Atendimento' } } })
	eq(#nuiMessages, 1, 'SetPrompt deduplica prompts idênticos')

	Zones.SetPrompt(nil)
	eq(#nuiMessages, 2, 'SetPrompt(nil) oculta o prompt')
	eq(nuiMessages[2].data, nil, 'payload nil enviado ao ocultar')
end

print('coe_core zones_test: ok')
