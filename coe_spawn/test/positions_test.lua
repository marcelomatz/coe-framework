dofile('config.lua')
dofile('shared/positions.lua')

local bounds = CoeSpawnConfig.LastPosition.Bounds
local failures = 0
local function eq(actual, expected, message)
	if actual ~= expected then
		failures = failures + 1
		print(('FAIL %s: esperado %s, obtido %s'):format(message, tostring(expected), tostring(actual)))
	end
end

local position = SpawnPositions.Normalize({ x = 100.126, y = -200.444, z = 30.005, heading = -90 }, bounds)
eq(position.x, 100.13, 'arredonda x')
eq(position.y, -200.44, 'arredonda y')
eq(position.heading, 270, 'heading normalizado')
eq(SpawnPositions.Normalize({ x = 100, y = 100, z = 30 }, bounds).heading, 0, 'heading padrão')
eq(SpawnPositions.Normalize({ x = 0.2, y = 0.1, z = 0 }, bounds), nil, 'origem rejeitada')
eq(SpawnPositions.Normalize({ x = 99999, y = 0, z = 0 }, bounds), nil, 'fora do mapa')
eq(SpawnPositions.Normalize({ x = 10, y = 10, z = -500 }, bounds), nil, 'abaixo do mapa')
eq(SpawnPositions.Normalize({ x = 0 / 0, y = 10, z = 1 }, bounds), nil, 'NaN')
eq(SpawnPositions.Normalize({ x = '10', y = 10, z = 1 }, bounds), nil, 'texto')
eq(SpawnPositions.Normalize(nil, bounds), nil, 'nil')
eq(SpawnPositions.Moved(nil, position, 2), true, 'primeira posição')
eq(SpawnPositions.Moved(position, { x = position.x + 1, y = position.y, z = position.z }, 2), false, 'parado')
eq(SpawnPositions.Moved(position, { x = position.x + 3, y = position.y, z = position.z }, 2), true, 'andou')

if failures > 0 then
	error(('%d falha(s)'):format(failures))
end
print('positions_test: ok')