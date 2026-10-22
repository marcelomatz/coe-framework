-- Persistência do telefone básico com o coe_database simulado: geração de número com colisão, contatos repetidos,
-- conversas (última mensagem e não lidas), leitura de conversa e recentes.
local calls = {}
local replies = {}
function GetResourceState() return 'started' end
promise = { new = function() local p = {}; function p:resolve(v) self.value = v end; return p end }
Citizen = { Await = function(p) return p.value end }
json = { encode = function() return '{"silent":true}' end, decode = function(text) return text == '{"volume":7}' and { volume = 7 } or {} end }

-- Cada chamada consome a próxima resposta da fila: { ok, result, errorCode }.
local function database(kind)
	return function(_, sql, params, cb)
		calls[#calls + 1] = { kind = kind, sql = sql, params = params }
		local reply = table.remove(replies, 1) or { true, {} }
		cb(reply[1], reply[2], reply[3])
	end
end
exports = { coe_database = { Query = database('Query'), Execute = database('Execute') } }

dofile('config.lua')
dofile('server/migrations.lua')
dofile('server/persistence.lua')

local function eq(a, b, m)
	if a ~= b then error(('%s: esperado %s, veio %s'):format(m, tostring(b), tostring(a)), 2) end
end
local function queue(...) for _, reply in ipairs({ ... }) do replies[#replies + 1] = reply end end

-- Número já existente
queue({ true, { { number = '555-0001' } } })
eq(MobilePersistence.EnsureNumber('11', function() error('nao deveria gerar') end), '555-0001', 'numero existente')

-- Primeiro uso: o primeiro candidato colide (INSERT IGNORE não grava), o segundo vale
local candidates = { '555-1000', '555-2000' }
queue({ true, {} }, { true, { affectedRows = 0 } }, { true, {} }, { true, { affectedRows = 1 } }, { true, { { number = '555-2000' } } })
calls = {}
eq(MobilePersistence.EnsureNumber('11', function() return table.remove(candidates, 1) end), '555-2000', 'gera depois da colisao')
eq(calls[2].sql:find('INSERT IGNORE', 1, true) ~= nil, true, 'insert ignore')
eq(calls[2].params[2], '555-1000', 'primeiro candidato')
eq(calls[4].params[2], '555-2000', 'segundo candidato')

-- Banco fora do ar
queue({ false, nil, 'database_not_ready' })
eq(select(2, MobilePersistence.EnsureNumber('11', function() return '555-3000' end)), 'database_not_ready', 'erro do banco')

-- Contato repetido vira duplicate_contact; edição sem linha afetada vira contact_not_found
queue({ false, nil, 'ER_DUP_ENTRY' })
eq(select(2, MobilePersistence.SaveContact('11', nil, '555-2000', 'Ana')), 'duplicate_contact', 'repetido')
queue({ true, { affectedRows = 0 } })
eq(select(2, MobilePersistence.SaveContact('11', 9, '555-2000', 'Ana')), 'contact_not_found', 'contato de outro')
queue({ true, { affectedRows = 1 } })
eq(MobilePersistence.SaveContact('11', 9, '555-2000', 'Ana'), true, 'editado')

-- Conversas: contraparte, quem mandou a última e não lidas
queue(
	{ true, {
		{ id = 9, sender = '555-0001', receiver = '555-7777', body = 'oi', created_at = 100 },
		{ id = 5, sender = '555-8888', receiver = '555-0001', body = 'ola', created_at = 90 }
	} },
	{ true, { { sender = '555-8888', total = 2 } } }
)
calls = {}
local threads = MobilePersistence.Threads('555-0001')
eq(#threads, 2, 'duas conversas')
eq(threads[1].number, '555-7777', 'contraparte da enviada')
eq(threads[1].mine, true, 'ultima foi minha')
eq(threads[1].unread, 0, 'sem nao lidas')
eq(threads[2].number, '555-8888', 'contraparte da recebida')
eq(threads[2].unread, 2, 'nao lidas')
eq(calls[1].sql:find('LIMIT ' .. MobileConfig.Messages.ThreadsLimit, 1, true) ~= nil, true, 'limite no texto')

-- Conversa: ordem cronológica e marca como lida
queue({ true, { { id = 3, sender = '555-8888', body = 'b', created_at = 2 }, { id = 1, sender = '555-0001', body = 'a', created_at = 1 } } },
	{ true, { affectedRows = 1 } })
calls = {}
local messages = MobilePersistence.Thread('555-0001', '555-8888')
eq(messages[1].body, 'a', 'mais antiga primeiro')
eq(messages[1].mine, true, 'minha')
eq(messages[2].mine, false, 'dele')
eq(calls[2].sql:find('read_at', 1, true) ~= nil, true, 'marca lidas')
eq(calls[2].params[2], '555-0001', 'so as recebidas')

-- Recentes
queue({ true, {
	{ id = 4, caller = '555-0001', callee = '555-7777', status = 'answered', duration = 65, created_at = 10 },
	{ id = 3, caller = '555-8888', callee = '555-0001', status = 'missed', duration = 0, created_at = 9 }
} })
local recents = MobilePersistence.Recents('555-0001')
eq(recents[1].outgoing, true, 'feita')
eq(recents[1].number, '555-7777', 'para quem')
eq(recents[1].duration, 65, 'duracao')
eq(recents[2].outgoing, false, 'recebida')
eq(recents[2].number, '555-8888', 'de quem')

-- Ajustes
queue({ true, { { data = '{"volume":7}' } } })
eq(MobilePersistence.Settings('11').volume, 7, 'ajustes lidos')
queue({ true, {} })
eq(next(MobilePersistence.Settings('11')), nil, 'sem ajustes')

-- Migrações: tabelas do resource
local tables = {}
for _, statement in ipairs(MobileMigrations[1].statements) do
	tables[#tables + 1] = statement:match('CREATE TABLE IF NOT EXISTS ([%w_]+)')
end
eq(table.concat(tables, ','), 'coe_mobile_numbers,coe_mobile_contacts,coe_mobile_messages,coe_mobile_calls,coe_mobile_settings', 'tabelas')

print('coe_mobile persistence: ok')
