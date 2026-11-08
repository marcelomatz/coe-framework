-- Regras do Elos: perfil, currículo montado do histórico, visibilidade e conexões.
dofile('../coe_core/lib/algorithms/init.lua')
dofile('config.lua')
dofile('shared/rules.lua')

local function eq(a, b, m)
	if a ~= b then error(('%s: esperado %s, veio %s'):format(m, tostring(b), tostring(a)), 2) end
end
local config = ElosConfig

-- textos
eq(ElosRules.Text('  Mecânico   na  Bennys ', 80), 'Mecânico na Bennys', 'apresentacao limpa')
eq(ElosRules.Text('linha 1\n\n\n\nlinha 2', 600, true), 'linha 1\n\nlinha 2', 'sobre com quebras')
eq(ElosRules.Text('a\tb', 80), 'a b', 'controle vira espaco')
eq(ElosRules.Text(('x'):rep(81), 80), nil, 'longo demais')
eq(ElosRules.Text(('é'):rep(80), 80), ('é'):rep(80), 'conta caracteres, nao bytes')
eq(ElosRules.Text(nil, 80), '', 'vazio')
eq(ElosRules.Text(5, 80), nil, 'nao texto')

-- perfil
local patch = ElosRules.ProfilePatch(config, { headline = ' Taxista ', visibility = 'closed', showEarnings = true })
eq(patch.headline, 'Taxista', 'headline')
eq(patch.visibility, 'closed', 'visibilidade')
eq(patch.showEarnings, true, 'mostrar ganhos')
eq(patch.about, nil, 'so os campos enviados')
local _, err = ElosRules.ProfilePatch(config, { visibility = 'publico' })
eq(err, 'invalid_visibility', 'visibilidade invalida')
_, err = ElosRules.ProfilePatch(config, { showCareer = 'sim' })
eq(err, 'invalid_profile', 'flag precisa ser booleana')
_, err = ElosRules.ProfilePatch(config, {})
eq(err, 'invalid_profile', 'nada para mudar')
_, err = ElosRules.ProfilePatch(config, { about = ('a'):rep(601) })
eq(err, 'invalid_about', 'sobre longo')

-- ids
eq(ElosRules.ItemKey('job', 'lumberjack'), 'job:lumberjack', 'chave de emprego')
eq(ElosRules.ItemKey('business', 'bennys'), 'business:bennys', 'chave de negocio')
eq(ElosRules.ItemKey('casa', 'x1'), nil, 'tipo invalido')
eq(ElosRules.ItemKey('job', 'a b'), nil, 'ref invalida')
eq(ElosRules.StateId(' ab3c defg '), 'AB3CDEFG', 'stateId normalizado')
eq(ElosRules.StateId('AB3CDEF'), nil, 'stateId curto')
eq(ElosRules.StateId('AB1CDEFG'), nil, 'stateId sem 1')

-- curriculo: empregos livres com tarefas, horas de ponto e vinculos atuais
local career = { jobs = {
	{ id = 'lumberjack', label = 'Lenhador', kindLabel = 'Coleta e venda', level = 2, maxLevel = 5, xp = 200, tasks = 40, earned = 900, workedSeconds = 7200, firstAt = 100, lastAt = 500 },
	{ id = 'taxi', label = 'Taxista', tasks = 0, workedSeconds = 0 }
} }
local works = {
	{ businessId = 'bennys', label = "Benny's", category = 'mechanic', role = 'Mecânico', seconds = 36000, shifts = 9, firstAt = 50, lastAt = 400 },
	{ businessId = 'burger', label = 'Burger Shot', category = 'restaurant', role = 'Atendente', seconds = 3600, shifts = 2, firstAt = 10, lastAt = 900 }
}
local members = { { businessId = 'bennys', label = "Benny's", category = 'mechanic', role = 'Chefe de oficina' }, { businessId = 'lojinha', label = 'Lojinha', category = 'shop', owner = true, role = 'Dono' } }
local items = { ['job:lumberjack'] = { note = 'Melhor da serraria' }, ['business:bennys'] = { note = '' } }
local list = ElosRules.Experiences(config, career, works, members, items)
eq(#list, 4, 'lenhador, bennys, burger e lojinha (taxi sem tarefas fica de fora)')
eq(list[1].current, true, 'vinculos atuais primeiro')
local byKey = {}
for _, entry in ipairs(list) do byKey[entry.key] = entry end
eq(byKey['business:bennys'].title, 'Chefe de oficina', 'cargo atual vence o do ultimo turno')
eq(byKey['business:bennys'].subtitle, 'Oficina', 'categoria em texto')
eq(byKey['business:bennys'].seconds, 36000, 'horas de ponto')
eq(byKey['business:bennys'].added, true, 'no curriculo')
eq(byKey['business:lojinha'].owner, true, 'dono')
eq(byKey['business:lojinha'].seconds, 0, 'dono sem ponto')
eq(byKey['business:burger'].current, false, 'negocio anterior')
eq(byKey['job:lumberjack'].org, 'Empregos livres', 'emprego livre')
eq(byKey['job:lumberjack'].note, 'Melhor da serraria', 'comentario')
eq(byKey['job:lumberjack'].seconds, 7200, 'tempo do emprego livre')
eq(list[#list].key, 'job:lumberjack', 'anteriores pela ultima vez')

local summary = ElosRules.Summary(list, true)
eq(summary.count, 2, 'duas no curriculo')
eq(summary.seconds, 43200, 'horas do curriculo')
eq(summary.current, 1, 'uma atual')
eq(ElosRules.Summary(list, false).count, 4, 'todas')
eq(#ElosRules.Experiences(config, nil, {}, {}, {}), 0, 'sem historico')

-- o que os outros veem
local public = ElosRules.PublicResume({ showEarnings = false }, list)
eq(#public, 2, 'so o que esta no curriculo')
local lumber
for _, entry in ipairs(public) do if entry.title == 'Lenhador' then lumber = entry end end
eq(lumber.earned, nil, 'ganhos escondidos')
eq(lumber.key, nil, 'sem chave interna')
eq(ElosRules.PublicResume({ showEarnings = true }, list)[2].earned ~= nil or ElosRules.PublicResume({ showEarnings = true }, list)[1].earned ~= nil, true, 'ganhos quando o dono mostra')

-- relacao e visibilidade
eq(ElosRules.Relation('1', '1', nil), 'self', 'proprio')
eq(ElosRules.Relation('1', '2', nil), 'none', 'sem ligacao')
eq(ElosRules.Relation('1', '2', { requester = '1', target = '2', status = 'pending' }), 'outgoing', 'eu pedi')
eq(ElosRules.Relation('2', '1', { requester = '1', target = '2', status = 'pending' }), 'incoming', 'pediram para mim')
eq(ElosRules.Relation('2', '1', { requester = '1', target = '2', status = 'accepted' }), 'connected', 'conectados')
eq(ElosRules.CanSeeAll({ visibility = 'open' }, 'none'), true, 'aberto para todos')
eq(ElosRules.CanSeeAll({ visibility = 'closed' }, 'none'), false, 'fechado para estranhos')
eq(ElosRules.CanSeeAll({ visibility = 'closed' }, 'incoming'), false, 'pedido pendente nao abre')
eq(ElosRules.CanSeeAll({ visibility = 'closed' }, 'connected'), true, 'fechado para conexoes')

-- pedidos
eq(ElosRules.CanRequest(config, 'none', 0, 0), true, 'pode pedir')
eq(select(2, ElosRules.CanRequest(config, 'self', 0, 0)), 'self', 'nao pede a si')
eq(select(2, ElosRules.CanRequest(config, 'connected', 0, 0)), 'already_connected', 'ja conectado')
eq(select(2, ElosRules.CanRequest(config, 'outgoing', 0, 0)), 'already_requested', 'ja pedido')
eq(select(2, ElosRules.CanRequest(config, 'none', 0, config.Network.MaxPendingOut)), 'pending_limit', 'pedidos demais')
eq(ElosRules.CanRequest(config, 'incoming', 0, config.Network.MaxPendingOut), true, 'aceitar nao conta como pedido')
eq(select(2, ElosRules.CanRequest(config, 'none', config.Network.MaxConnections, 0)), 'connection_limit', 'conexoes demais')

local limiter = ElosRules.NewCallLimiter(300)
eq(limiter ~= nil, true, 'limiter GCRA criado')
local cache = ElosRules.NewProfileCache(16)
cache:put('11', { name = 'Ana' })
eq(cache:get('11').name, 'Ana', 'LRU cache funciona')

print('coe_elos rules tests passed')
