-- Regras do telefone básico (sem natives).
dofile('config.lua')
dofile('shared/rules.lua')

local function eq(a, b, m)
	if a ~= b then error(('%s: esperado %s, veio %s'):format(m, tostring(b), tostring(a)), 2) end
end
local config = MobileConfig

-- Número
eq(MobileRules.Number('555-0123', config), '555-0123', 'formato de exibicao')
eq(MobileRules.Number('5550123', config), '555-0123', 'so digitos')
eq(MobileRules.Number(' (555) 01.23 ', config), '555-0123', 'espacos, parenteses e pontos')
eq(MobileRules.Number(5550123, config), '555-0123', 'numero do Lua')
eq(MobileRules.Number('555-012', config), nil, 'curto')
eq(MobileRules.Number('555-01234', config), nil, 'longo')
eq(MobileRules.Number('444-0123', config), nil, 'outro prefixo')
eq(MobileRules.Number('555-01a3', config), nil, 'letra')
eq(MobileRules.Number(nil, config), nil, 'nil')
eq(select(2, MobileRules.Number({}, config)), 'invalid_number', 'codigo do erro')

-- Geração
local seq = { 0, 4, 2, 9 }
local i = 0
local generated = MobileRules.Generate(config, function(min, max)
	eq(min, 0, 'minimo'); eq(max, 9, 'maximo')
	i = i + 1
	return seq[i]
end)
eq(generated, '555-0429', 'numero gerado')
eq(MobileRules.Number(generated, config), generated, 'gerado passa na validacao')

-- Nome de contato
eq(MobileRules.ContactName('  Ana  ', 32), 'Ana', 'apara')
eq(MobileRules.ContactName('Ana\nSouza', 32), 'Ana Souza', 'quebra de linha vira espaco')
eq(MobileRules.ContactName('João', 4), 'João', 'conta caracteres UTF-8')
eq(MobileRules.ContactName('Joãoo', 4), nil, 'acima do limite')
eq(MobileRules.ContactName('   ', 32), nil, 'vazio')
eq(MobileRules.ContactName('\255\254', 32), nil, 'UTF-8 invalido')
eq(select(2, MobileRules.ContactName(nil, 32)), 'invalid_name', 'codigo do erro')

-- Mensagem
eq(MobileRules.Body('oi\r\ntudo bem?', 300), 'oi\ntudo bem?', 'mantem quebra de linha')
eq(MobileRules.Body('a\n\n\n\n\nb', 300), 'a\n\nb', 'limita linhas vazias')
eq(MobileRules.Body('a\0b\7c', 300), 'abc', 'remove controle')
eq(MobileRules.Body(string.rep('x', 301), 300), nil, 'longa demais')
eq(MobileRules.Body(string.rep('x', 300), 300), string.rep('x', 300), 'no limite')
eq(select(2, MobileRules.Body('', 300)), 'invalid_message', 'codigo do erro')

-- Ajustes
local s = MobileRules.Settings(nil, config, nil)
eq(s.silent, false, 'default silencioso')
eq(s.volume, 5, 'default volume')
eq(s.ringtone, 'classico', 'default toque')
s = MobileRules.Settings({ silent = true, volume = 11, ringtone = 'xyz', wallpaper = 'noite', extra = 1 }, config,
	{ volume = 3, ringtone = 'digital' })
eq(s.silent, true, 'silencioso novo')
eq(s.volume, 3, 'volume invalido mantem o atual')
eq(s.ringtone, 'digital', 'toque invalido mantem o atual')
eq(s.wallpaper, 'noite', 'papel de parede novo')
eq(s.extra, nil, 'campo desconhecido descartado')
eq(MobileRules.Settings({ volume = 2.5 }, config, nil).volume, 5, 'volume fracionado')

-- Canal da ligação
local id = MobileRules.CallId(function() return 10 end)
eq(id, 'coe_mobile:' .. string.rep('a', 16), 'id do canal')
eq(#MobileRules.CallId(math.random), #'coe_mobile:' + 16, 'tamanho do id')

-- Ids, nomes e pedidos
eq(MobileRules.Id('12'), 12, 'id em texto')
eq(MobileRules.Id(0), nil, 'id zero')
eq(MobileRules.Id(1.5), nil, 'id fracionado')
eq(MobileRules.Name('Ana', 'Souza'), 'Ana Souza', 'nome completo')
eq(MobileRules.Name(nil, nil), nil, 'sem nome')
eq(MobileRules.Actions.message_send, 'message', 'categoria de mensagem')
eq(MobileRules.Actions.call_end, 'call', 'categoria de ligacao')
eq(MobileRules.Actions.open, nil, 'open nao e acao')

print('coe_mobile rules: ok')
