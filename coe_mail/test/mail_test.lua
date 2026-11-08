dofile('../coe_core/lib/algorithms/init.lua')
dofile('config.lua')
dofile('shared/rules.lua')

local config = MailConfig
local failures = 0

local function eq(actual, expected, message)
	if actual ~= expected then
		failures = failures + 1
		print(('FAIL %s: esperado %s, obtido %s'):format(message, tostring(expected), tostring(actual)))
	end
end

-- Nome da conta
eq(MailRules.LocalPart(config, '  Joao.Silva '), 'joao.silva', 'minúsculas e sem espaços')
eq(MailRules.LocalPart(config, 'ab'), nil, 'curto demais')
eq(MailRules.LocalPart(config, string.rep('a', 25)), nil, 'longo demais')
eq(MailRules.LocalPart(config, '.joao'), nil, 'começa com ponto')
eq(MailRules.LocalPart(config, 'joao-'), nil, 'termina com hífen')
eq(MailRules.LocalPart(config, 'jo..ao'), nil, 'símbolos seguidos')
eq(MailRules.LocalPart(config, 'joão'), nil, 'acento')
eq(select(2, MailRules.LocalPart(config, 'admin')), 'address_reserved', 'nome reservado')
eq(MailRules.LocalPart(config, 'loja_24-h'), 'loja_24-h', 'underline e hífen no meio')

-- Endereço
eq(MailRules.Address(' Ana@Correio.COE '), 'ana@correio.coe', 'normaliza endereço')
eq(select(3, MailRules.Address('ana@empresa.com.br')), 'empresa.com.br', 'domínio com vários níveis')
eq(MailRules.Address('ana@correio'), nil, 'domínio sem ponto')
eq(MailRules.Address('ana@@correio.coe'), nil, 'dois @')
eq(MailRules.Address('ana@correio..coe'), nil, 'pontos seguidos no domínio')
eq(MailRules.Address('.ana@correio.coe'), nil, 'nome começa com ponto')

-- Senha
eq(MailRules.Password(config, '12345'), nil, 'senha curta')
eq(MailRules.Password(config, ' 123456'), nil, 'espaço na ponta')
eq(MailRules.Password(config, 'segredo1'), 'segredo1', 'senha válida')
eq(MailRules.Password(config, string.rep('x', 33)), nil, 'senha longa')

-- Destinatários
local list, code, bad = MailRules.Recipients(config, 'a@correio.coe, B@correio.coe; a@correio.coe', { 'c@correio.coe' }, 'b@correio.coe d@correio.coe')
eq(list and #list.to, 2, 'Para sem repetir')
eq(list and list.cc[1], 'c@correio.coe', 'Cc em lista')
eq(list and #list.bcc, 1, 'Cco não repete quem já está em Para')
eq(list and #list.all, 4, 'total de destinatários')
list, code, bad = MailRules.Recipients(config, 'a@correio.coe, nada', nil, nil)
eq(code, 'invalid_recipient', 'endereço inválido')
eq(bad, 'nada', 'aponta o endereço inválido')
eq(select(2, MailRules.Recipients(config, '', 'a@correio.coe', nil)), 'no_recipients', 'precisa de alguém em Para')
local many = {}
for index = 1, 11 do
	many[#many + 1] = ('u%d@correio.coe'):format(index)
end
eq(select(2, MailRules.Recipients(config, many)), 'too_many_recipients', 'limite de destinatários')

-- Mensagem
eq(select(2, MailRules.Compose(config, { subject = '  ', body = '\n' })), 'empty_message', 'mensagem vazia')
local message = MailRules.Compose(config, { subject = 'Oi', body = 'linha 1\r\n\r\n\r\n\r\nlinha 2' })
eq(message and message.body, 'linha 1\n\nlinha 2', 'quebras normalizadas')
eq(MailRules.Compose(config, { subject = string.rep('á', 130) }).subject, string.rep('á', 120), 'assunto cortado por caractere')
local draft = MailRules.Draft(config, { to = 'nao-validado', body = 'x' })
eq(draft.to, 'nao-validado', 'rascunho guarda o texto digitado')
eq(draft.subject, '', 'rascunho sem assunto')

-- Ids
eq(#MailRules.Ids({ 1, 2, 2, '3' }, 10), 3, 'ids sem repetir')
eq(MailRules.Ids({ 1, -2 }, 10), nil, 'id negativo')
eq(MailRules.Ids({}, 10), nil, 'lista vazia')
eq(MailRules.Ids({ 1, 2, 3 }, 2), nil, 'ids demais')
eq(MailRules.Ids(5, 10)[1], 5, 'id solto vira lista')

-- Bloqueio de senha
local state
for _ = 1, config.Login.MaxFailures - 1 do
	state = MailRules.Fail(config, state, 100)
end
eq(MailRules.Locked(state, 100), false, 'ainda não bloqueia')
state = MailRules.Fail(config, state, 100)
eq(MailRules.Locked(state, 100), true, 'bloqueia na última tentativa')
eq(MailRules.Locked(state, 100 + config.Login.LockSeconds), false, 'libera depois do tempo')

-- Algoritmos (GCRA, LRU Cache, LockManager)
local limiter = MailRules.NewSendLimiter(3)
eq(limiter:allow(10, 1000), true, 'GCRA permite primeiro envio')
eq(limiter:allow(10, 2000), false, 'GCRA bloqueia spam antes de 3s')
eq(limiter:allow(10, 4000), true, 'GCRA libera após 3s')

local cache = MailRules.NewSessionCache(4)
cache:put('phone:SER1', { id = 1 }, 5000, 1000)
eq(cache:get('phone:SER1', 2000).id, 1, 'LRU Cache retorna sessão ativa')
eq(cache:get('phone:SER1', 7000), nil, 'LRU Cache expira TTL')

if failures > 0 then
	print(('%d falha(s)'):format(failures))
	os.exit(1)
end
print('mail_test: ok')
