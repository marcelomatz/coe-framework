-- Testes puros do domínio de coe_garage. Rodar a partir da pasta do resource: lua test/domain_test.lua
dofile('config.lua')
dofile('domain/garage.lua')

local function eq(a, b, msg)
	if a ~= b then
		error(('%s: esperado %s, obtido %s'):format(msg, tostring(b), tostring(a)), 2)
	end
end

-- Validação de cadastro de garagem
local validRaw = {
	id = 'Garagem_Central',
	label = 'Garagem Legion Square',
	kind = 'public',
	enabled = true,
	spots = {
		{ id = 'v1', label = 'Vaga 1', x = 215.0, y = -805.0, z = 30.0, heading = 90.0, radius = 3.5 }
	},
	blip = { enabled = true, sprite = 357, color = 3, scale = 0.8 }
}

local clean, err = GarageDomain.ValidateGarage(validRaw)
eq(err, nil, 'sem erro na validação válida')
eq(clean.id, 'garagem_central', 'id sanitizado para minusculas')
eq(clean.label, 'Garagem Legion Square', 'label preservado')
eq(#clean.spots, 1, 'spots sanitizados')
eq(clean.spots[1].x, 215.0, 'coord x')

-- Casos inválidos
eq(select(2, GarageDomain.ValidateGarage(nil)), 'invalid_payload', 'payload nil')
eq(select(2, GarageDomain.ValidateGarage({ id = '', label = 'Teste' })), 'invalid_id', 'id vazio')
eq(select(2, GarageDomain.ValidateGarage({ id = 'valido', label = '' })), 'invalid_label', 'label vazio')
eq(select(2, GarageDomain.ValidateGarage({ id = 'valido', label = 'Ok', spots = {} })), 'invalid_spots', 'spots vazios')
eq(select(2, GarageDomain.ValidateGarage({ id = 'valido', label = 'Ok', spots = { { x = 'nao_num', y = 10, z = 20 } } })), 'invalid_spot_coords', 'coords invalidas')

-- Validação de Distância
local spot = { x = 100.0, y = 200.0, z = 30.0, radius = 3.5 }
eq(GarageDomain.ValidateDistance({ x = 100.0, y = 200.0, z = 30.0 }, spot), true, 'mesma posicao')
eq(GarageDomain.ValidateDistance({ x = 102.0, y = 200.0, z = 30.0 }, spot), true, 'distancia 2m dentro do raio 3.5m')
eq(GarageDomain.ValidateDistance({ x = 110.0, y = 200.0, z = 30.0 }, spot), false, 'distancia 10m fora do raio 3.5m')

-- BuildStationList
local garages = {
	g1 = clean,
	g2 = {
		id = 'g2',
		label = 'Garagem Desativada',
		enabled = false,
		spots = { { id = 'v1', x = 0, y = 0, z = 0 } }
	}
}
local stations = GarageDomain.BuildStationList(garages)
eq(#stations, 1, 'apenas garagem ativa vira estacao')
eq(stations[1].garageId, 'garagem_central', 'id da estacao')

print('coe_garage domain_test: ok')
