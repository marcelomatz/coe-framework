dofile('../coe_businesses/config.lua')
dofile('../coe_businesses/shared/area.lua')
dofile('../coe_businesses/server/grades.lua')
dofile('../coe_businesses/server/registry.lua')

local function eq(a, b, m)
	if a ~= b then error(('%s: esperado %s, veio %s'):format(m, tostring(b), tostring(a)), 2) end
end

local config = BusinessesConfig

local function valid()
	return {
		id = 'bennys', category = 'mechanic', label = "Benny's",
		area = { kind = 'circle', x = -205.0, y = -1312.0, z = 31.0, radius = 40 },
		stations = {
			showroom = { x = -205.7, y = -1312.2, z = 31.3, radius = 7 },
			crafts = { { id = 'bancada', label = 'Bancada', x = -196.4, y = -1318.1, z = 31.1, radius = 1.6 } },
			stashes = { { id = 'main', x = -199.6, y = -1311.0, z = 31.1, radius = 1.6, slots = 40, maxWeight = 150000 } }
		},
		rules = { ownerAccess = true, priceMultiplier = 1.25 }
	}
end

local function normalize(mutate)
	local raw = valid()
	if mutate then mutate(raw) end
	return BusinessRegistry.Normalize(config, raw)
end

-- Normalize
local ok = normalize()
eq(ok.id, 'bennys', 'válida')
eq(ok.stations.stashes[1].label, 'main', 'rótulo padrão é o id')
eq(ok.rules.priceMultiplier, 1.25, 'regra numérica')
eq(select(2, normalize(function(r) r.id = 'Bad Id' end)), 'invalid_id', 'id inválido')
eq(select(2, normalize(function(r) r.category = 'nada' end)), 'invalid_category', 'categoria inválida')
eq(select(2, normalize(function(r) r.label = '' end)), 'invalid_label', 'rótulo vazio')
eq(select(2, normalize(function(r) r.label = '<b>x</b>' end)), 'invalid_label', 'rótulo com marcação')
eq(select(2, normalize(function(r) r.area.radius = 0 end)), 'invalid_area', 'raio mínimo')
eq(select(2, normalize(function(r) r.area.x = 0 / 0 end)), 'invalid_area', 'NaN')
eq(select(2, normalize(function(r) r.area.x = 1e9 end)), 'invalid_area', 'coordenada fora do mundo')
eq(select(2, normalize(function(r) r.rules.priceMultiplier = 9 end)), 'invalid_rule', 'multiplicador alto')
eq(select(2, normalize(function(r) r.rules.ownerAccess = 'sim' end)), 'invalid_rule', 'tipo errado')
eq(select(2, normalize(function(r) r.stations.stashes[2] = { id = 'main', x = 0, y = 0, z = 0, radius = 1 } end)), 'duplicate_station', 'id repetido')
eq(select(2, normalize(function(r) r.stations.stashes[1].slots = 9999 end)), 'invalid_station', 'slots')
eq(select(2, normalize(function(r) r.stations.crafts[1].radius = 50 end)), 'invalid_station', 'raio de bancada')
eq(select(2, normalize(function(r)
	for i = 1, 9 do r.stations.stashes[i] = { id = 's' .. i, x = 0, y = 0, z = 0, radius = 1 } end
end)), 'invalid_station', 'estações demais')

local shop = BusinessRegistry.Normalize(config, {
	id = 'loja1', category = 'shop', label = 'Loja',
	area = { kind = 'polygon', z = 30, height = 10, points = { { x = 0, y = 0 }, { x = 10, y = 0 }, { x = 10, y = 10 }, { x = 0, y = 10 } } },
	stations = { showroom = { x = 0, y = 0, z = 0, radius = 5 }, stashes = {} },
	rules = { priceMultiplier = 2 }
})
eq(shop.stations.showroom, nil, 'categoria ignora estação que não aceita')
eq(shop.rules.priceMultiplier, nil, 'categoria ignora regra que não aceita')
eq(shop.rules.ownerAccess, true, 'padrão da regra')
eq(shop.owner, nil, 'sem dono por padrão')
eq(normalize(function(r) r.owner = { characterId = '3', name = 'Ana' } end).owner.characterId, '3', 'dono aceito')
eq(select(2, normalize(function(r) r.owner = { characterId = "3'; --", name = 'x' } end)), 'invalid_owner', 'dono com id inválido')
eq(select(2, normalize(function(r) r.owner = 'x' end)), 'invalid_owner', 'dono não tabela')
eq(select(2, BusinessRegistry.Normalize(config, { id = 'ab', category = 'shop', label = 'x',
	area = { kind = 'polygon', z = 0, height = 5, points = { { x = 0, y = 0 }, { x = 1, y = 1 } } } })), 'invalid_area', 'polígono com 2 pontos')

-- Área
eq(BusinessArea.Contains(ok.area, -205, -1312, 31), true, 'dentro do círculo')
eq(BusinessArea.Contains(ok.area, -100, -1312, 31), false, 'fora do círculo')
eq(BusinessArea.Contains(shop.area, 5, 5, 32), true, 'dentro do polígono')
eq(BusinessArea.Contains(shop.area, 15, 5, 32), false, 'fora do polígono')
eq(BusinessArea.Contains(shop.area, 5, 5, 80), false, 'acima do polígono')
eq(BusinessArea.Center(shop.area).x, 5, 'centro')

-- Serviço
local store, fail = {}, nil
local events, changes = {}, {}
local service = BusinessRegistry.New({
	config = config,
	persistence = {
		List = function() local l = {} for _, b in pairs(store) do l[#l + 1] = b end return l end,
		Save = function(b) if fail then return nil, fail end store[b.id] = b return true end,
		Delete = function(id) store[id] = nil return true end
	},
	audit = function(e, c) events[#events + 1] = e end,
	onChange = function(id) changes[#changes + 1] = id or '*' end
})
service.Load()
eq(#service.List(), 0, 'começa vazio')
eq(service.Save(valid(), 'admin').id, 'bennys', 'cria')
eq(events[1], 'business_created', 'auditoria de criação')
eq(service.Save(valid(), 'admin').id, 'bennys', 'atualiza')
eq(events[2], 'business_updated', 'auditoria de atualização')
local other = valid(); other.category = 'shop'
eq(select(2, service.Save(other, 'admin')), 'category_locked', 'categoria não muda')
fail = 'database_error'
local changed = valid(); changed.label = 'Outro'
eq(select(2, service.Save(changed, 'admin')), 'database_error', 'falha de banco propaga')
eq(service.Get('bennys').label, "Benny's", 'estado em memória intacto na falha')
fail = nil
local seeded = valid(); seeded.label = 'Semente'
eq(service.Seed(seeded).label, "Benny's", 'semente não sobrescreve')
eq(#service.List('shop'), 0, 'filtra categoria')
eq(select(2, service.Delete('nada', 'admin')), 'unknown_business', 'remove inexistente')
eq(service.Delete('bennys', 'admin'), true, 'remove')
eq(service.Get('bennys'), nil, 'removido')
eq(changes[#changes], 'bennys', 'notifica mudança')

-- ponto: regras e pontos de bater cartão
local clocked = normalize(function(raw)
	raw.stations.clocks = { { id = 'ponto1', label = 'Ponto 1', x = -200.0, y = -1310.0, z = 31.0, radius = 1.5 } }
	raw.rules.clockOffsite = true
end)
eq(clocked.stations.clocks[1].id, 'ponto1', 'aceita ponto de bater cartão')
eq(clocked.rules.clockOffsite, true, 'ponto fora da área permitido')
eq(clocked.rules.clockRequired, true, 'ponto obrigatório por padrão')
eq(normalize().rules.clockOffsite, false, 'ponto fora da área negado por padrão')
eq(select(2, normalize(function(raw) raw.rules.clockOffsite = 'sim' end)), 'invalid_rule', 'regra de ponto booleana')

-- vários empregos: padrão liberado, polícia e EMS exclusivos, sem emprego duplo quando alguma ponta é exclusiva
eq(normalize().rules.multiJob, true, 'vários empregos por padrão')
eq(normalize(function(raw) raw.category = 'police'; raw.stations = {} end).rules.multiJob, false, 'polícia é exclusiva por padrão')
eq(select(2, normalize(function(raw) raw.rules.multiJob = 'sim' end)), 'invalid_rule', 'multiJob booleano')

local jobs = BusinessRegistry.New({ config = config, persistence = { List = function() return {} end, Save = function() return true end, Delete = function() return true end } })
local function biz(id, category, multiJob, staffIds, extra)
	local staff = {}
	for _, characterId in ipairs(staffIds) do staff[#staff + 1] = { characterId = characterId, name = 'x' } end
	local raw = {
		id = id, category = category, label = id, staff = staff, rules = { multiJob = multiJob },
		area = { kind = 'circle', x = 0.0, y = 0.0, z = 30.0, radius = 20 }
	}
	for key, value in pairs(extra or {}) do raw[key] = value end
	return raw
end
eq(jobs.Save(biz('rest_a', 'restaurant', true, { '1' }), 't') ~= nil, true, 'restaurante com equipe')
eq(jobs.Save(biz('oficina', 'mechanic', true, { '1' }), 't') ~= nil, true, 'mesmo funcionário em dois negócios liberados')
eq(jobs.Save(biz('rest_c', 'restaurant', true, { '1' }, { owner = { characterId = '1', name = 'Ana' } }), 't') ~= nil, true, 'dono de vários negócios é livre')
eq(select(2, jobs.Save(biz('dp', 'police', false, { '1' }), 't')), 'multiple_jobs', 'exclusivo recusa quem já trabalha em outro')
eq(jobs.Save(biz('dp', 'police', false, { '2' }), 't') ~= nil, true, 'exclusivo aceita quem não trabalha em outro')
eq(select(2, jobs.Save(biz('rest_a', 'restaurant', true, { '1', '2' }), 't')), 'multiple_jobs', 'liberado recusa quem está em negócio exclusivo')
eq(jobs.Save(biz('rest_c', 'restaurant', false, {}, { owner = { characterId = '1', name = 'Ana' } }), 't') ~= nil, true, 'dono entra em negócio exclusivo sem ser equipe')
eq(select(2, jobs.Save(biz('rest_a', 'restaurant', false, { '1' }), 't')), 'multiple_jobs', 'virar exclusivo confere a equipe atual')
eq(jobs.Save(biz('dp', 'police', false, { '2' }, { enabled = false }), 't') ~= nil, true, 'desligar mantém a equipe')
eq(jobs.Save(biz('rest_a', 'restaurant', true, { '1', '2' }), 't') ~= nil, true, 'negócio exclusivo desligado não bloqueia')

-- Sócios: validados, sem duplicados e sem o dono
local withPartners = assert(normalize(function(raw)
	raw.owner = { characterId = '1', name = 'Dono' }
	raw.partners = { { characterId = '2', name = 'Sócio' }, { characterId = '2', name = 'Sócio' }, { characterId = '1', name = 'Dono' } }
end))
eq(#withPartners.partners, 1, 'sócio duplicado e dono ignorados')
eq(#assert(normalize()).partners, 0, 'sem sócios')
eq(select(2, normalize(function(raw) raw.partners = { { characterId = "1' OR 1", name = 'x' } } end)), 'invalid_partners', 'id inválido')
eq(select(2, normalize(function(raw) raw.partners = 'x' end)), 'invalid_partners', 'tipo inválido')
eq(select(2, normalize(function(raw)
	raw.partners = {}
	for i = 1, config.Limits.MaxPartners + 1 do raw.partners[i] = { characterId = tostring(i + 10), name = 'S' } end
end)), 'invalid_partners', 'limite de sócios')

print('businesses ok')
