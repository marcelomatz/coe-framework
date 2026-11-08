dofile('../coe_core/lib/algorithms/init.lua')
dofile('server/rules.lua')

local function eq(a, b, m)
	if a ~= b then error(('%s: esperado %s, veio %s'):format(m, tostring(b), tostring(a)), 2) end
end

-- Text
eq(MdtRules.Text('  olá mundo  ', 3, 20, false), 'olá mundo', 'trim e UTF-8')
eq(MdtRules.Text('a\0b\1c', 1, 20, false), 'a b c', 'controles viram espaço')
eq(MdtRules.Text('ab\ncd', 1, 20, true), 'ab\ncd', 'multiline mantém quebra')
eq(MdtRules.Text('ab\ncd', 1, 20, false), 'ab cd', 'linha única troca quebra')
eq(select(2, MdtRules.Text('ab', 3, 20, false)), 'invalid_text', 'curto')
eq(select(2, MdtRules.Text(('x'):rep(21), 1, 20, false)), 'invalid_text', 'longo')
eq(select(2, MdtRules.Text(123, 1, 20, false)), 'invalid_text', 'não-string')
eq(MdtRules.Text('', 0, 200, false), '', 'vazio permitido quando min 0')
eq(select(2, MdtRules.Text('\255\254', 1, 20, false)), 'invalid_text', 'UTF-8 inválido')

-- Charge, Plate, StateId
eq(MdtRules.Charge('roubo_veiculo'), 'roubo_veiculo', 'motivo')
eq(select(2, MdtRules.Charge('Roubo')), 'invalid_charge', 'maiúscula')
eq(select(2, MdtRules.Charge('a')), 'invalid_charge', 'curto')
eq(MdtRules.Plate(' ab 123 '), 'AB 123', 'placa normalizada')
eq(select(2, MdtRules.Plate("A'; DROP")), 'invalid_plate', 'placa injeção')
eq(select(2, MdtRules.Plate('123456789')), 'invalid_plate', 'placa longa')
eq(MdtRules.StateId('ab12cd34'), 'AB12CD34', 'state id')
eq(MdtRules.StateId('abc'), nil, 'state id curto')
eq(MdtRules.StateId('ab12cd3!'), nil, 'state id inválido')

-- Tokens
local tokens = MdtRules.Tokens('João da Silva')
eq(#tokens, 3, 'três tokens')
eq(tokens[1], 'João', 'acento preservado')
eq(select(2, MdtRules.Tokens('a')), 'term_too_short', 'um char')
eq(select(2, MdtRules.Tokens('a b c d e')), 'term_too_short', 'só letras soltas')
eq(select(2, MdtRules.Tokens('aa bb cc dd')), 'invalid_term', 'mais de 3')
eq(MdtRules.Tokens("O'Neil")[1], "O'Neil", 'apóstrofo')
eq(MdtRules.Tokens('Silva%')[1], 'Silva', 'curinga removido')
eq(select(2, MdtRules.Tokens(('a'):rep(100))), 'invalid_term', 'termo longo')

-- Ids
eq(MdtRules.CharacterId(42), '42', 'id numérico')
eq(select(2, MdtRules.CharacterId('4 2')), 'invalid_character', 'id inválido')
eq(select(2, MdtRules.CharacterId(nil)), 'invalid_character', 'id nil')
eq(MdtRules.Id(5), 5, 'id inteiro')
eq(select(2, MdtRules.Id(1.5)), 'invalid_id', 'fração')
eq(select(2, MdtRules.Id(0)), 'invalid_id', 'zero')
eq(select(2, MdtRules.Id('5')), 'invalid_id', 'string')

-- Mandados
eq(MdtRules.CanCloseWarrant('active', 'served'), true, 'ativo -> cumprido')
eq(MdtRules.CanCloseWarrant('active', 'revoked'), true, 'ativo -> revogado')
eq(MdtRules.CanCloseWarrant('served', 'revoked'), false, 'estado final')
eq(MdtRules.CanCloseWarrant('active', 'active'), false, 'sem no-op')
eq(MdtRules.CanCloseWarrant('active', 'x'), false, 'estado desconhecido')

-- Boletim
local cfg = { BulletinDefaultHours = 24, BulletinMaxHours = 72 }
eq(MdtRules.BulletinHours(nil, cfg), 24, 'padrão')
eq(MdtRules.BulletinHours(72, cfg), 72, 'máximo')
eq(select(2, MdtRules.BulletinHours(73, cfg)), 'invalid_hours', 'acima')
eq(select(2, MdtRules.BulletinHours(0, cfg)), 'invalid_hours', 'zero')
eq(select(2, MdtRules.BulletinHours(1.5, cfg)), 'invalid_hours', 'fração')

-- Limit
eq(MdtRules.Limit(nil, 10, 50), 10, 'limite padrão')
eq(MdtRules.Limit(500, 10, 50), 50, 'limite máximo')
eq(MdtRules.Limit(-1, 10, 50), 10, 'limite negativo')

-- Janela deslizante
local stamps = {}
eq(MdtRules.Allow(stamps, 100, 2, 60), true, '1a')
eq(MdtRules.Allow(stamps, 101, 2, 60), true, '2a')
eq(MdtRules.Allow(stamps, 102, 2, 60), false, '3a bloqueada')
eq(MdtRules.Allow(stamps, 161, 2, 60), true, 'janela deslizou')
eq(#stamps, 1, 'carimbos antigos descartados')

-- LRU Cache Zero-GC e Rate Limiter GCRA
local cache = MdtRules.NewCache(2)
cache:put('1', { name = 'Alice' })
cache:put('2', { name = 'Bob' })
eq(cache:get('1').name, 'Alice', 'LRU get promove 1')
cache:put('3', { name = 'Carol' })
eq(cache:get('2'), nil, 'LRU ejetou o menos recente (2)')
eq(cache:get('1').name, 'Alice', 'LRU preservou 1')

local limiter = MdtRules.NewRateLimiter(2, 60)
eq(limiter:allow('cop1', 100000, 1), true, 'GCRA 1a')
eq(limiter:allow('cop1', 100000, 1), true, 'GCRA 2a (burst)')
eq(limiter:allow('cop1', 100000, 1), false, 'GCRA 3a bloqueada')
eq(limiter:allow('cop1', 130000, 1), true, 'GCRA liberada após intervalo')

print('mdt rules tests passed')
