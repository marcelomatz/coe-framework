-- server/persistence.lua contra um coe_database falso: parâmetros nil viram NULL no SQL (o export recusa buracos).
local failures = 0
local function eq(actual, expected, message)
	if actual ~= expected then
		failures = failures + 1
		print(('FAIL %s: esperado %s, obtido %s'):format(message, tostring(expected), tostring(actual)))
	end
end

local calls = {}
function GetResourceState() return 'started' end
promise = { new = function() local p = {}; function p:resolve(value) self.value = value end; return p end }
Citizen = { Await = function(p) return p.value end }
local function record(kind)
	return function(_, sql, parameters, callback)
		local count = 0
		for index in pairs(parameters) do count = math.max(count, index) end
		calls[#calls + 1] = { kind = kind, sql = sql, parameters = parameters, length = #parameters, highest = count }
		callback(true, kind == 'Execute' and { insertId = 7, affectedRows = 1 } or {})
	end
end
exports = { coe_database = { Execute = record('Execute'), Query = record('Query') } }

dofile('server/persistence.lua')
local P = DeepwebPersistence

local sql, list = P.Bind('INSERT INTO t (a, b, c) VALUES (?, ?, ?)', { 1, nil, 3 })
eq(sql, 'INSERT INTO t (a, b, c) VALUES (?, NULL, ?)', 'nil vira NULL')
eq(#list, 2, 'parâmetros sem buraco')
eq(list[2], 3, 'ordem mantida')
sql, list = P.Bind('SELECT ? , ?', { 'x', 'y' })
eq(sql, 'SELECT ? , ?', 'sem nil fica igual')
sql, list = P.Bind('UPDATE t SET a = ? WHERE id = ?', { nil, nil })
eq(sql, 'UPDATE t SET a = NULL WHERE id = NULL', 'todos nil')
eq(#list, 0, 'lista vazia')

-- Chamadas reais que levam NULL: comunidade do sistema, fornecedor NPC, comentário sem pai, site sem blocos/dono.
local function last() return calls[#calls] end
local function sequential(call) return call.length == call.highest end

eq(P.InsertCommunity({ slug = 'geral', title = 'Geral', description = '' }, 1), 7, 'comunidade do sistema')
eq(sequential(last()), true, 'comunidade sem buraco nos parâmetros')
eq(last().sql:find('NULL', 1, true) ~= nil, true, 'created_by NULL')

P.InsertListing({ kind = 'item', category = 'tools', title = 'Pen drive', description = '', item = 'usb_black', count = 1, price = 100, stock = 1 }, 1)
eq(sequential(last()), true, 'fornecedor NPC sem buraco')

P.InsertComment({ postId = 1, handleId = 2, body = 'oi' }, 1)
eq(sequential(calls[#calls - 1]), true, 'comentário sem pai sem buraco')

P.SaveSite({ domain = 'duckdark.onion', app = 'search', title = 'DuckDark' }, 1)
eq(sequential(last()), true, 'site de sistema sem buraco')

P.InsertOrder({ listingId = 1, kind = 'item', title = 'x', buyerHandle = 1, buyerCharacter = '11', item = 'a', count = 1, quantity = 1,
	total = 1, fee = 0, buyerAddress = 'nx', payout = 'nx', dropIndex = 1, status = 'dropped' }, 1)
eq(sequential(last()), true, 'pedido de fornecedor sem buraco')

for index, call in ipairs(calls) do
	if not sequential(call) then
		failures = failures + 1
		print(('FAIL chamada %d com buraco: %s'):format(index, call.sql:gsub('%s+', ' '):sub(1, 80)))
	end
end

if failures > 0 then
	print(('%d falha(s)'):format(failures))
	os.exit(1)
end
print('deepweb persistence_test: ok')
