dofile('server/directory.lua')

local function eq(a, b, m)
	if a ~= b then error(('%s: esperado %s, veio %s'):format(m, tostring(b), tostring(a)), 2) end
end

local clock = 0
local queries = {}
local rows = {
	{ character_id = 1, state_id = 'ABCD2345', first_name = 'Ana', last_name = 'Souza' },
	{ character_id = 2, state_id = 'EFGH6789', first_name = 'Ana', last_name = 'Silva' }
}
local online = { { characterId = '2', stateId = 'EFGH6789', name = 'Ana Silva' } }
local dir = AdminDirectory.New({
	query = function(sql, params) queries[#queries + 1] = { sql = sql, params = params }; return rows end,
	online = function() return online end,
	now = function() return clock end,
	isStateId = function(text) return #text == 8 and text:match('^[A-Z0-9]+$') ~= nil end
}, { ttlMs = 1000, maxEntries = 3, limit = 10 })

-- Termos curtos e inválidos não chegam ao banco
eq(select(2, dir.Search('a')), 'term_too_short', 'curto')
eq(select(2, dir.Search('  ')), 'term_too_short', 'vazio')
eq(select(2, dir.Search(nil)), 'term_too_short', 'nil')
eq(#queries, 0, 'sem consulta')

-- Curingas são neutralizados e a consulta é por prefixo
local result = dir.Search('an%_')
eq(queries[1].params[1], 'an%', 'curinga removido, prefixo')
eq(queries[1].sql:find('LIKE ?', 1, true) ~= nil, true, 'parametrizada')
eq(queries[1].sql:find('LIMIT ?', 1, true) ~= nil, true, 'limitada')

-- Online vem primeiro, sem duplicar, marcado como online
eq(#result, 2, 'dois resultados sem duplicar')
eq(result[1].online, true, 'online primeiro')
eq(result[1].characterId, '2', 'online é a Ana Silva')
eq(result[2].online, false, 'offline')
eq(result[2].name, 'Ana Souza', 'nome completo')

-- Cache: mesma busca não consulta o banco de novo
dir.Search('an%_')
dir.Search('AN')
eq(#queries, 1, 'cache (insensível a caixa e curingas)')
clock = 1500
dir.Search('an')
eq(#queries, 2, 'TTL expirado consulta de novo')

-- Vários termos: cada um precisa casar com nome ou sobrenome
dir.Search('ana souza')
eq(queries[#queries].params[1], 'ana%', 'primeiro termo')
eq(queries[#queries].params[3], 'souza%', 'segundo termo')
eq(select(2, queries[#queries].sql:gsub('LIKE', '')), 4, 'dois termos, quatro LIKE')

-- ID público: consulta exata por índice único
rows = { rows[1] }
local byId = dir.Search('abcd2345')
eq(#byId, 1, 'busca por ID')
eq(byId[1].stateId, 'ABCD2345', 'ID normalizado')
eq(queries[#queries].sql:find('state_id = ?', 1, true) ~= nil, true, 'por state_id')
local before = #queries
dir.Search('ABCD2345')
eq(#queries, before, 'ID em cache')

-- Limite de cache
dir.Search('bruno'); dir.Search('carla'); dir.Search('diego'); dir.Search('elena')
eq(dir.Stats().entries <= 3, true, 'cache limitado')

-- Falha do banco não vira cache nem quebra
local failing = AdminDirectory.New({
	query = function() return nil, 'database_error' end,
	online = function() return {} end, now = function() return 0 end, isStateId = function() return false end
})
eq(select(2, failing.Search('ana')), 'database_error', 'erro propagado')
eq(failing.Stats().entries, 0, 'erro não entra no cache')

-- Só online: sem ir ao banco quando já enche o limite
local small = AdminDirectory.New({
	query = function() error('não deveria consultar') end,
	online = function() return { { characterId = '1', stateId = 'ABCD2345', name = 'Ana Souza' } } end,
	now = function() return 0 end, isStateId = function() return false end
}, { limit = 1 })
eq(#small.Search('ana'), 1, 'limite atingido só com online')

print('directory_test ok')
