dofile('../coe_businesses/config.lua')
dofile('../coe_businesses/shared/area.lua')
dofile('../coe_businesses/server/grades.lua')
dofile('../coe_businesses/server/registry.lua')
dofile('../coe_businesses/server/access.lua')
dofile('../coe_businesses/server/duty.lua')
dofile('../coe_businesses/server/tablet.lua')

local function eq(a, b, m)
	if a ~= b then error(('%s: esperado %s, veio %s'):format(m, tostring(b), tostring(a)), 2) end
end

local raw = {
	id = 'rest_a', category = 'restaurant', label = 'Restaurante A', enabled = true,
	owner = { characterId = '10', name = 'Dono' },
	staff = { { characterId = '11', name = 'Gerente', grade = 'manager' }, { characterId = '12', name = 'Garcom', grade = 'waiter' } },
	grades = {
		{ id = 'waiter', label = 'Garçom', level = 1, salary = 100, permissions = {} },
		{ id = 'manager', label = 'Gerente', level = 5, salary = 500, permissions = { 'business.staff', 'business.funds' } },
		{ id = 'chief', label = 'Chefe', level = 7, salary = 700, permissions = {} }
	},
	area = { kind = 'circle', x = 0, y = 0, z = 30, radius = 20 }
}

local business = assert(BusinessRegistry.Normalize(BusinessesConfig, raw))
local onDuty = { ['10'] = true, ['11'] = true }
local saved, deposits = nil, {}
local characters = { [1] = '10', [2] = '11', [3] = '12', [4] = '99', [5] = '50' }
local duty = { [1] = 'rest_a', [2] = 'rest_a', [3] = nil, [4] = 'rest_a' }
local clock, offerSeq, sentOffers = 1000, 0, {}

local deps = {
	get = function(id) return id == 'rest_a' and business or nil end,
	currentDuty = function(source) return duty[source] end,
	characterOf = function(source) return characters[source] end,
	can = function(id, characterId, permission)
		local access = BusinessAccess.Evaluate(business, characterId, onDuty[tostring(characterId)] == true)
		return BusinessTablet.Remote(business, characterId, access) and BusinessGrades.Can(business, characterId, permission, access.owner) or false
	end,
	onDuty = function(_, characterId) return onDuty[tostring(characterId)] == true end,
	balance = function() return 1500 end,
	ledger = function() return { { delta = 100, reason = 'x' } } end,
	deposit = function(_, characterId, amount) deposits[#deposits + 1] = { characterId, amount }; return true end,
	withdraw = function() return { error = 'insufficient_funds' } end,
	save = function(rawBusiness)
		local normalized, errorCode = BusinessRegistry.Normalize(BusinessesConfig, rawBusiness)
		if not normalized then return nil, errorCode end
		saved = normalized
		return normalized
	end,
	resolve = function(stateId)
		if stateId == 'ONLINE01' then return { characterId = '50', name = 'Novo', source = 5 } end
		if stateId == 'DONO0001' then return { characterId = '10', name = 'Dono', source = 1 } end
		if stateId == 'SEMSRC01' then return { characterId = '51', name = 'Sem sessão' } end
		return nil, 'target_not_online'
	end,
	permissions = function() return { ['business.staff'] = 'Equipe', ['business.funds'] = 'Caixa' } end,
	properties = function() return nil end,
	offers = {},
	now = function() return clock end,
	nextOfferId = function() offerSeq = offerSeq + 1; return offerSeq end,
	sendOffer = function(offer) sentOffers[#sentOffers + 1] = offer end,
	audit = function() end
}

local function call(source, action, payload) return BusinessTablet.Handle(deps, source, action, payload) end

-- App por negócio: dono administra a distância, equipe só de ponto, estranho nunca
eq(BusinessTablet.Handle(deps, 1, 'overview', nil, 'rest_a').ok, true, 'dono pelo app do negócio')
onDuty['10'] = nil
local remote = BusinessTablet.Handle(deps, 1, 'overview', nil, 'rest_a')
eq(remote.ok, true, 'dono a distancia')
eq(remote.can.funds, true, 'dono mexe no caixa a distancia')
onDuty['10'] = true
eq(BusinessTablet.Handle(deps, 3, 'overview', nil, 'rest_a').error, 'not_on_duty', 'garcom sem ponto')
eq(BusinessTablet.Handle(deps, 4, 'overview', nil, 'rest_a').error, 'forbidden', 'estranho')
-- Gerente: sem business.remote só de ponto; com a permissão, a distância e com as permissões do cargo.
onDuty['11'] = nil
eq(BusinessTablet.Handle(deps, 2, 'overview', nil, 'rest_a').error, 'not_on_duty', 'gerente sem remote')
local managerGrade = business.grades[2]
managerGrade.permissions[#managerGrade.permissions + 1] = 'business.remote'
local manager = BusinessTablet.Handle(deps, 2, 'overview', nil, 'rest_a')
eq(manager.ok, true, 'gerente a distancia')
eq(manager.can.funds, true, 'gerente mexe no caixa a distancia')
eq(manager.can.fleet, false, 'so as permissoes do cargo')
eq(call(2, 'overview').error, 'not_on_duty', 'caminho do ponto continua exigindo ponto')
table.remove(managerGrade.permissions)
onDuty['11'] = true
eq(BusinessTablet.Handle(deps, 1, 'overview', nil, 'nope').error, 'forbidden', 'negocio inexistente')
local mine = BusinessTablet.Instances({ business, { id = 'b2', label = 'Outro', enabled = true, owner = { characterId = '99' }, staff = {} } }, '12')
eq(#mine, 1, 'so os negocios do personagem')
eq(mine[1].id, 'rest_a', 'negocio da equipe')
eq(#BusinessTablet.Instances({ business }, '99'), 0, 'estranho sem apps')

-- Sem ponto, sem acesso
eq(call(3, 'overview').error, 'not_on_duty', 'sem ponto no negócio')
eq(call(4, 'overview').error, 'not_on_duty', 'não é do negócio nem está de ponto')
eq(call(9, 'overview').error, 'no_character', 'sem personagem')
eq(call(1, 'explode').error, 'unknown_action', 'ação desconhecida')
eq(call(1, '__index').error, 'unknown_action', 'ação inválida')

-- Resumo
local overview = call(2, 'overview')
eq(overview.ok, true, 'resumo')
eq(overview.business.balance, 1500, 'gerente vê o caixa')
eq(overview.business.grade, 'Gerente', 'cargo')
eq(overview.business.onDuty, 2, 'de ponto')
eq(call(1, 'overview').business.grade, 'Proprietário', 'dono')

-- Financeiro e acessos exigem permissão
onDuty['12'], duty[3] = true, 'rest_a'
eq(call(3, 'finance').error, 'forbidden', 'garçom sem financeiro')
eq(call(3, 'access').error, 'forbidden', 'garçom sem acessos')
eq(call(3, 'overview').business.balance, nil, 'garçom não vê caixa')
eq(call(3, 'staff').staff[1].salary, nil, 'garçom não vê salários')
eq(call(2, 'staff').staff[1].salary, 500, 'gerente vê salários')
eq(call(2, 'finance').payroll, 600, 'folha')
eq(call(2, 'access').grades[2].granted['business.funds'], true, 'matriz')

-- Depósito: qualquer um de ponto; saque exige permissão e repassa o erro da economia
eq(call(3, 'deposit', { amount = 50 }).ok, true, 'depósito')
eq(deposits[1][2], 50, 'valor')
eq(call(3, 'deposit', { amount = -5 }).error, 'invalid_amount', 'negativo')
eq(call(3, 'deposit', { amount = 1.5 }).error, 'invalid_amount', 'fracionado')
eq(call(3, 'deposit', { amount = '9' }).error, 'invalid_amount', 'texto')
eq(call(3, 'withdraw', { amount = 10 }).error, 'forbidden', 'garçom sem saque')
eq(call(2, 'withdraw', { amount = 10 }).error, 'insufficient_funds', 'erro da economia')

-- Equipe
eq(call(3, 'hire', { stateId = 'ONLINE01', grade = 'waiter' }).error, 'forbidden', 'garçom não contrata')
eq(call(2, 'hire', { stateId = 'ONLINE01', grade = 'chief' }).error, 'grade_too_high', 'gerente não promove acima de si')
eq(call(2, 'hire', { stateId = 'ONLINE01', grade = 'manager' }).error, 'grade_too_high', 'nem ao próprio nível')
eq(call(2, 'hire', { stateId = 'ONLINE01', grade = 'xx' }).error, 'invalid_grade', 'cargo inexistente')
eq(call(2, 'hire', { stateId = 'NOPE0000', grade = 'waiter' }).error, 'target_not_online', 'offline')
eq(call(2, 'hire', { stateId = 'DONO0001', grade = 'waiter' }).error, 'is_owner', 'dono')
eq(call(2, 'hire', { stateId = 'SEMSRC01', grade = 'waiter' }).error, 'target_not_online', 'sem sessão')

-- Contratação exige o aceite do contratado
local hired = call(2, 'hire', { stateId = 'ONLINE01', grade = 'waiter' })
eq(hired.ok, true, 'proposta enviada')
eq(hired.pending, true, 'pendente')
eq(saved, nil, 'nada gravado antes do aceite')
eq(sentOffers[1].source, 5, 'proposta ao contratado')
eq(sentOffers[1].gradeLabel, 'Garçom', 'cargo na proposta')
eq(call(2, 'hire', { stateId = 'ONLINE01', grade = 'waiter' }).error, 'offer_pending', 'uma proposta por vez')
eq(BusinessTablet.Answer(deps, 3, sentOffers[1].id, true).error, 'no_offer', 'só o contratado responde')
eq(BusinessTablet.Answer(deps, 5, 999, true).error, 'no_offer', 'id errado')
local declined = BusinessTablet.Answer(deps, 5, sentOffers[1].id, false)
eq(declined.declined, true, 'recusou')
eq(saved, nil, 'recusa não grava')
eq(BusinessTablet.Answer(deps, 5, sentOffers[1].id, true).error, 'no_offer', 'proposta consumida')
call(2, 'hire', { stateId = 'ONLINE01', grade = 'waiter' })
clock = clock + BusinessTablet.OfferSeconds
eq(BusinessTablet.Answer(deps, 5, sentOffers[2].id, true).error, 'offer_expired', 'expirou')
call(2, 'hire', { stateId = 'ONLINE01', grade = 'waiter' })
local accepted = BusinessTablet.Answer(deps, 5, sentOffers[3].id, true)
eq(accepted.ok, true, 'aceitou')
eq(accepted.offer.bySource, 2, 'avisa quem contratou')
eq(#saved.staff, 3, 'equipe cresceu')
eq(saved.staff[3].characterId, '50', 'novo funcionário')
eq(saved.staff[3].grade, 'waiter', 'cargo da proposta')
eq(saved.owner.characterId, '10', 'dono preservado')

eq(call(2, 'setGrade', { characterId = '12', grade = 'chief' }).error, 'grade_too_high', 'promoção acima')
eq(call(2, 'setGrade', { characterId = '11', grade = 'waiter' }).error, 'grade_too_high', 'gerente não rebaixa a si (mesmo nível)')
eq(call(1, 'setGrade', { characterId = '12', grade = 'chief' }).ok, true, 'dono promove')
eq(saved.staff[2].grade, 'chief', 'promovido')
eq(call(2, 'fire', { characterId = '11' }).error, 'same_character', 'não demite a si')
eq(call(2, 'fire', { characterId = '77' }).error, 'unknown_member', 'inexistente')
eq(call(1, 'fire', { characterId = '12' }).ok, true, 'dono demite')
eq(#saved.staff, 1, 'equipe após demissão')

-- Erros de persistência (ex.: dedicação exclusiva) chegam ao jogador
deps.save = function() return nil, 'multiple_jobs' end
call(1, 'hire', { stateId = 'ONLINE01', grade = 'waiter' })
eq(BusinessTablet.Answer(deps, 5, sentOffers[#sentOffers].id, true).error, 'multiple_jobs', 'multiJob no aceite')

-- Estrutura: área e pontos, para toda a equipe de ponto
business.stations = { clocks = { { id = 'p1', label = 'Ponto', x = 1, y = 2, z = 3, radius = 1 } }, stashes = { { id = 'b1', label = 'Baú', x = 4, y = 5, z = 6, radius = 1, slots = 40, maxWeight = 150000 } } }
local structure = call(3, 'structure')
eq(structure.ok, true, 'estrutura')
eq(structure.area.kind, 'circle', 'área')
eq(#structure.stations, 2, 'pontos')
eq(structure.stations[2].slots, 40, 'baú com espaços')
business.area = { kind = 'polygon', points = { { x = 0, y = 0 }, { x = 10, y = 0 }, { x = 10, y = 10 }, { x = 0, y = 10 } }, z = 30, height = 10 }
eq(call(3, 'structure').area.x, 5, 'centro do polígono')

-- Frota: todos veem; liberar para a equipe exige business.fleet
local fleetCalls = {}
deps.fleet = function(id) return { { id = 'g1', label = 'Garagem', enabled = true, spots = 2, x = 1, y = 2, vehicles = { { id = '5', plate = 'AAA111', state = 'stored', staff = false, accessCount = 0 } } } } end
deps.setFleetStaff = function(id, vehicleId, enabled) fleetCalls[#fleetCalls + 1] = { id, vehicleId, enabled }; return true end
local fleet = call(3, 'fleet')
eq(fleet.ok, true, 'frota')
eq(fleet.canManage, false, 'garçom não gerencia frota')
eq(#fleet.garages[1].vehicles, 1, 'veículos')
eq(call(3, 'fleetAccess', { vehicleId = '5', staff = true }).error, 'forbidden', 'garçom não libera')
eq(call(1, 'fleetAccess', { vehicleId = '5', staff = true }).ok, true, 'dono libera')
eq(fleetCalls[1][1], 'rest_a', 'negócio do ponto, não do payload')
eq(fleetCalls[1][3], true, 'liberado')
eq(call(1, 'fleetAccess', { vehicleId = '5', staff = 'sim' }).error, 'invalid_vehicle', 'staff não booleano')
eq(call(1, 'fleetAccess', { vehicleId = "5' OR 1", staff = true }).error, 'invalid_vehicle', 'id inválido')
deps.setFleetStaff = function() return { error = 'not_in_fleet' } end
eq(call(1, 'fleetAccess', { vehicleId = '9', staff = true }).error, 'not_in_fleet', 'veículo de outro negócio')
deps.fleet = function() return nil end
eq(call(3, 'fleet').error, 'garages_unavailable', 'sem coe_garages')
eq(call(3, 'properties').error, 'properties_unavailable', 'propriedades sem garagens nem imóveis')

-- Propriedades: imóveis comerciais e garagens vinculadas
deps.properties = function() return { { id = 'loja1', label = 'Sala 1', enabled = true, leased = true, paidUntil = 0, overdue = true, x = 3, y = 4 } } end
eq(call(3, 'properties').properties[1].kind, 'commercial', 'só imóveis, sem garagens')
deps.fleet = function() return { { id = 'g1', label = 'Garagem', enabled = true, spots = 2, x = 1, y = 2, vehicles = {} } } end
local properties = call(3, 'properties')
eq(properties.ok, true, 'propriedades')
eq(#properties.properties, 2, 'imóvel e garagem')
eq(properties.properties[1].overdue, true, 'vencido')
eq(properties.properties[2].kind, 'garage', 'garagem')
deps.properties = function() return { { id = 'loja2', label = 'Sala 2', enabled = true, leased = false, x = 3, y = 4 } } end
eq(call(3, 'properties').properties[1].detail, 'Cedido ao negócio', 'cedido pelo admin')

-- Sócios: só o dono convida e remove; o convidado precisa aceitar
deps.offers = {}
deps.save = function(rawBusiness)
	local normalized, errorCode = BusinessRegistry.Normalize(BusinessesConfig, rawBusiness)
	if not normalized then return nil, errorCode end
	saved = normalized
	return normalized
end
eq(call(1, 'partners').canManage, true, 'dono gerencia sócios')
eq(call(2, 'partners').canManage, false, 'gerente não gerencia sócios')
eq(call(2, 'addPartner', { stateId = 'ONLINE01' }).error, 'forbidden', 'gerente não convida sócio')
eq(call(1, 'addPartner', { stateId = 'DONO0001' }).error, 'is_owner', 'dono não é sócio de si')
eq(call(1, 'addPartner', { stateId = 'SEMSRC01' }).error, 'target_not_online', 'convidado offline')
eq(call(1, 'addPartner', { stateId = 'ONLINE01' }).ok, true, 'convite enviado')
eq(sentOffers[#sentOffers].kind, 'partner', 'convite de sociedade')
eq(call(1, 'addPartner', { stateId = 'ONLINE01' }).error, 'offer_pending', 'convite pendente')
eq(#(business.partners or {}), 0, 'sócio só após aceite')
local partnerAnswer = BusinessTablet.Answer(deps, 5, sentOffers[#sentOffers].id, true)
eq(partnerAnswer.ok, true, 'aceitou a sociedade')
eq(#saved.partners, 1, 'sócio salvo')
eq(saved.partners[1].characterId, '50', 'sócio certo')
business = saved
eq(BusinessAccess.Evaluate(business, '50', true).partner, true, 'acesso marca sócio')
eq(BusinessAccess.Evaluate(business, '50', true).canWork, false, 'sócio não ganha acesso de trabalho')
eq(call(1, 'addPartner', { stateId = 'ONLINE01' }).error, 'already_partner', 'já é sócio')
eq(call(1, 'partners').partners[1].name, 'Novo', 'lista de sócios')
eq(call(1, 'removePartner', { characterId = '77' }).error, 'unknown_partner', 'sócio inexistente')
eq(call(2, 'removePartner', { characterId = '50' }).error, 'forbidden', 'gerente não remove sócio')
eq(call(1, 'removePartner', { characterId = '50' }).ok, true, 'dono remove sócio')
eq(#saved.partners, 0, 'sócio removido')
business = saved
-- Dono deixou de ser dono antes do aceite: convite cai
eq(call(1, 'addPartner', { stateId = 'ONLINE01' }).ok, true, 'novo convite')
business.owner = { characterId = '11', name = 'Gerente' }
eq(BusinessTablet.Answer(deps, 5, sentOffers[#sentOffers].id, true).error, 'no_business', 'convite de ex-dono')

-- Aba Banco: encaminha ao coe_banking com o negócio do app e quem chamou; sem banco, avisa
business.owner = { characterId = '10', name = 'Dono' }
eq(call(1, 'bank', { op = 'overview' }).error, 'bank_unavailable', 'sem coe_banking a aba Banco avisa')
local forwarded
deps.bank = function(source, characterId, businessId, payload)
	forwarded = { source = source, characterId = characterId, businessId = businessId, op = payload.op }
	return { ok = true, bank = { mode = 'business' } }
end
eq(call(1, 'bank', { op = 'overview' }).bank.mode, 'business', 'conta empresarial pelo tablet')
eq(forwarded.businessId, 'rest_a', 'negócio do app, não do payload')
eq(forwarded.characterId, '10', 'personagem de quem chamou')
eq(forwarded.op, 'overview', 'operação encaminhada')
deps.bank = function() return nil end
eq(call(1, 'bank', { op = 'overview' }).error, 'bank_unavailable', 'banco sem resposta')
deps.bank = nil

-- Aba Loja: só aparece para lojas do coe_shops; encaminha com o negócio do app
eq(call(1, 'overview').business.shop, nil, 'sem coe_shops nao e loja')
eq(call(1, 'shop', { op = 'overview' }).error, 'shop_unavailable', 'sem coe_shops a aba Loja avisa')
deps.isShop = function(id) return id == 'rest_a' end
eq(call(1, 'overview').business.shop, true, 'loja marcada no resumo')
local shopCall
deps.shop = function(source, characterId, businessId, payload)
	shopCall = { source = source, characterId = characterId, businessId = businessId, op = payload.op, price = payload.price }
	return { ok = true, mode = 'player' }
end
eq(call(1, 'shop', { op = 'price', productId = 'water', price = 6 }).mode, 'player', 'loja pelo tablet')
eq(shopCall.businessId, 'rest_a', 'loja do app')
eq(shopCall.characterId, '10', 'quem chamou')
eq(shopCall.price, 6, 'payload encaminhado')
deps.shop = function() return nil end
eq(call(1, 'shop', {}).error, 'shop_unavailable', 'loja sem resposta')
deps.shop, deps.isShop = nil, nil

print('tablet tests passed')
