dofile('../coe_core/lib/algorithms/init.lua')
dofile('../coe_housing/config.lua')
dofile('../coe_housing/server/rules.lua')
dofile('../coe_housing/server/registry.lua')
dofile('../coe_housing/shared/interiors.lua')

local function eq(a, b, m)
	if a ~= b then error(('%s: esperado %s, veio %s'):format(m, tostring(b), tostring(a)), 2) end
end

local c = HousingConfig
local DAY = 86400

eq(HousingRules.ValidCycle(7, c), true, 'semanal')
eq(HousingRules.ValidCycle(15, c), true, 'quinzenal')
eq(HousingRules.ValidCycle(30, c), true, 'mensal')
eq(HousingRules.ValidCycle(10, c), false, 'ciclo invalido')
eq(HousingRules.Total(100, 7), 700, 'total')
eq(HousingRules.NextPaidUntil(1000, 7), 1000 + 7 * DAY, 'proximo vencimento')

local rent = { cycleDays = 7, paidUntil = 10 * DAY }
eq(HousingRules.State(rent, 10 * DAY - 1, c), 'ok', 'em dia')
eq(HousingRules.State(rent, 10 * DAY, c), 'due', 'venceu')
eq(HousingRules.State(rent, 10 * DAY + c.GraceDays * DAY - 1, c), 'due', 'na tolerancia')
eq(HousingRules.State(rent, 10 * DAY + c.GraceDays * DAY, c), 'expired', 'expirou')
eq(HousingRules.State({ cycleDays = 0, paidUntil = 0 }, 99 * DAY, c), 'ok', 'gratuito nunca vence')

eq(HousingRules.FirstFreeUnit(3, {}), 1, 'primeira unidade')
eq(HousingRules.FirstFreeUnit(3, { [1] = true, [3] = true }), 2, 'buraco')
eq(HousingRules.FirstFreeUnit(2, { [1] = true, [2] = true }), nil, 'lotado')

local function base(extra)
	local p = {
		id = 'hotel_central', kind = 'hotel', label = 'Hotel Central', units = 20,
		door = { x = 1.0, y = 2.0, z = 3.0, heading = 90.0 },
		interior = { x = 100.0, y = 200.0, z = 30.0, heading = 0.0 },
		rent = { daily = 150, cycles = { 30, 7 } }
	}
	for k, v in pairs(extra or {}) do p[k] = v end
	return p
end

local p = HousingRegistry.Normalize(base(), c)
eq(p.id, 'hotel_central', 'id')
eq(p.rent.cycles[1], 7, 'ciclos ordenados')
eq(p.door.radius, 2.0, 'raio da porta padrao')
eq(p.interior.radius, 1.5, 'raio interior padrao')
eq(p.blip.enabled, true, 'blip padrao nao inicial')
eq(p.starter, false, 'nao inicial')

local starter = HousingRegistry.Normalize(base({ id = 'ap_inicial', kind = 'apartment', starter = true, rent = false }), c)
eq(starter, nil, 'rent=false nao e tabela')
local raw = base({ id = 'ap_inicial', kind = 'apartment', starter = true })
raw.rent = nil
starter = HousingRegistry.Normalize(raw, c)
eq(starter.starter, true, 'inicial')
eq(starter.rent, nil, 'inicial sem aluguel')
eq(starter.blip.enabled, false, 'inicial sem blip')
eq(select(2, HousingRegistry.Normalize(base({ starter = true }), c)), 'invalid_rent', 'inicial nao aluga')

eq(select(2, HousingRegistry.Normalize(nil, c)), 'invalid_property', 'nil')
eq(select(2, HousingRegistry.Normalize(base({ id = 'A B' }), c)), 'invalid_id', 'id')
eq(select(2, HousingRegistry.Normalize(base({ kind = 'castelo' }), c)), 'invalid_kind', 'tipo')
eq(select(2, HousingRegistry.Normalize(base({ label = '' }), c)), 'invalid_label', 'nome')
eq(select(2, HousingRegistry.Normalize(base({ door = { x = 'a' } }), c)), 'invalid_door', 'porta')
eq(select(2, HousingRegistry.Normalize(base({ interior = {} }), c)), 'invalid_interior', 'interior')
eq(select(2, HousingRegistry.Normalize(base({ units = 0 }), c)), 'invalid_units', 'unidades')
eq(select(2, HousingRegistry.Normalize(base({ units = c.Limits.MaxUnits + 1 }), c)), 'invalid_units', 'unidades max')
eq(select(2, HousingRegistry.Normalize(base({ rent = { daily = 0, cycles = { 7 } } }), c)), 'invalid_rent', 'diaria zero')
eq(select(2, HousingRegistry.Normalize(base({ rent = { daily = 10, cycles = { 10 } } }), c)), 'invalid_rent', 'ciclo fora')
eq(select(2, HousingRegistry.Normalize(base({ rent = { daily = 10, cycles = { 7, 7 } } }), c)), 'invalid_rent', 'ciclo repetido')
eq(select(2, HousingRegistry.Normalize(base({ rent = { daily = 10, cycles = {} } }), c)), 'invalid_rent', 'sem ciclos')
eq(select(2, HousingRegistry.Normalize(base({ blip = { sprite = 'x' } }), c)), 'invalid_blip', 'blip')

-- Imóvel comercial: alugado por negócios ou cedido a um negócio (businessId).
local shop = HousingRegistry.Normalize(base({ id = 'loja_centro', kind = 'commercial', units = 2 }), c)
eq(shop.kind, 'commercial', 'comercial')
eq(shop.rent.daily, 150, 'comercial com aluguel')
eq(shop.businessId, nil, 'comercial sem vinculo')
eq(shop.blip.sprite, c.DefaultBlips.commercial.sprite, 'blip comercial')
local linkedRaw = base({ id = 'loja_cedida', kind = 'commercial', units = 1, businessId = 'mecanica_centro' })
linkedRaw.rent = nil
local linked = HousingRegistry.Normalize(linkedRaw, c)
eq(linked.businessId, 'mecanica_centro', 'vinculo do admin')
eq(linked.rent, nil, 'cedido sem aluguel')
eq(select(2, HousingRegistry.Normalize(base({ kind = 'commercial', units = 1, businessId = 'mecanica_centro' }), c)), 'invalid_rent', 'cedido nao aluga')
linkedRaw.units = 2
eq(select(2, HousingRegistry.Normalize(linkedRaw, c)), 'invalid_units', 'cedido tem uma unidade')
linkedRaw.units, linkedRaw.businessId = 1, 'Bad Id'
eq(select(2, HousingRegistry.Normalize(linkedRaw, c)), 'invalid_business', 'negocio invalido')
eq(select(2, HousingRegistry.Normalize(base({ kind = 'commercial', starter = true }), c)), 'invalid_starter', 'comercial nao e inicial')
eq(HousingRegistry.Normalize(base({ businessId = 'mecanica_centro' }), c).businessId, nil, 'vinculo so em comercial')
-- Catálogo de interiores nativos: ids únicos e válidos, categoria conhecida, coordenadas dentro dos limites.
local categories, seen = {}, {}
for _, pair in ipairs(HousingInteriors.categories) do categories[pair[1]] = true end
for _, entry in ipairs(HousingInteriors.list) do
	assert(type(entry.id) == 'string' and entry.id:match('^[a-z0-9_]+$') and #entry.id <= 32, 'id do interior: ' .. tostring(entry.id))
	assert(not seen[entry.id], 'interior repetido: ' .. entry.id)
	seen[entry.id] = true
	assert(categories[entry.category], 'categoria: ' .. entry.id)
	assert(type(entry.label) == 'string' and #entry.label <= 48, 'nome: ' .. entry.id)
	for _, axis in ipairs({ 'x', 'y' }) do
		assert(math.abs(entry[axis]) <= c.Limits.MaxCoordinate, 'coordenada: ' .. entry.id)
	end
	assert(entry.z >= -1000 and entry.z <= 3000, 'altura: ' .. entry.id)
	assert(HousingRegistry.Normalize(base({ interiorId = entry.id, interior = entry }), c, HousingInteriors.byId), 'interior aceito: ' .. entry.id)
	assert(entry.ipls == nil or (entry.group ~= nil and #entry.ipls > 0), 'ipls exigem grupo: ' .. entry.id)
end
eq(HousingInteriors.byId.apt_low.label, 'Apartamento simples', 'indice por id')

local chosen = HousingRegistry.Normalize(base({ interiorId = 'apt_low' }), c, HousingInteriors.byId)
eq(chosen.interiorId, 'apt_low', 'interior do catalogo')
eq(HousingRegistry.Normalize(base({ interiorId = '' }), c, HousingInteriors.byId).interiorId, nil, 'vazio = personalizado')
eq(HousingRegistry.Normalize(base(), c).interiorId, nil, 'sem catalogo')
eq(select(2, HousingRegistry.Normalize(base({ interiorId = 'nao_existe' }), c, HousingInteriors.byId)), 'invalid_interior_id', 'interior inexistente')
eq(select(2, HousingRegistry.Normalize(base({ interiorId = 5 }), c, HousingInteriors.byId)), 'invalid_interior_id', 'interior nao texto')
eq(select(2, HousingRegistry.Normalize(base({ interiorId = 'apt_low' }), c)), 'invalid_interior_id', 'sem catalogo carregado')

-- Miniaturas: data URL JPEG em base64, só de interiores do catálogo e dentro do limite.
local max = c.Limits.MaxThumbBytes
eq(HousingRegistry.Thumb('apt_low', 'data:image/jpeg;base64,QUJD+/9=', HousingInteriors.byId, max), true, 'miniatura valida')
eq(select(2, HousingRegistry.Thumb('x', 'data:image/jpeg;base64,QUJD', HousingInteriors.byId, max)), 'invalid_interior_id', 'miniatura de interior inexistente')
eq(select(2, HousingRegistry.Thumb('apt_low', 'data:image/png;base64,QUJD', HousingInteriors.byId, max)), 'invalid_thumb', 'so jpeg')
eq(select(2, HousingRegistry.Thumb('apt_low', 'data:image/jpeg;base64,', HousingInteriors.byId, max)), 'invalid_thumb', 'vazia')
eq(select(2, HousingRegistry.Thumb('apt_low', 'data:image/jpeg;base64,QU"><script>', HousingInteriors.byId, max)), 'invalid_thumb', 'caracteres fora do base64')
eq(select(2, HousingRegistry.Thumb('apt_low', 'data:image/jpeg;base64,' .. ('A'):rep(max), HousingInteriors.byId, max)), 'invalid_thumb', 'grande demais')
eq(select(2, HousingRegistry.Thumb('apt_low', nil, HousingInteriors.byId, max)), 'invalid_thumb', 'sem imagem')
-- Baú: ponto no mesmo interior, capacidade padrão por tipo ou ajustada pelo admin.
local withStash = HousingRegistry.Normalize(base({ stash = { x = 102.0, y = 201.0, z = 30.0 } }), c)
eq(withStash.stash.slots, c.Stash.Defaults.hotel.slots, 'slots padrao do tipo')
eq(withStash.stash.maxWeight, c.Stash.Defaults.hotel.maxWeight, 'peso padrao do tipo')
eq(withStash.stash.radius, 1.2, 'raio padrao do bau')
local custom = HousingRegistry.Normalize(base({ stash = { x = 100.0, y = 200.0, z = 31.0, slots = 10, maxWeight = 5000, radius = 2.0 } }), c)
eq(custom.stash.slots, 10, 'slots do admin')
eq(custom.stash.maxWeight, 5000, 'peso do admin')
eq(HousingRegistry.Normalize(base(), c).stash, nil, 'sem bau')
eq(select(2, HousingRegistry.Normalize(base({ stash = { x = 500.0, y = 200.0, z = 30.0 } }), c)), 'invalid_stash', 'bau longe do interior')
eq(select(2, HousingRegistry.Normalize(base({ stash = { x = 100.0, y = 200.0, z = 30.0, slots = 0 } }), c)), 'invalid_stash', 'slots zero')
eq(select(2, HousingRegistry.Normalize(base({ stash = { x = 100.0, y = 200.0, z = 30.0, slots = c.Stash.MaxSlots + 1 } }), c)), 'invalid_stash', 'slots demais')
eq(select(2, HousingRegistry.Normalize(base({ stash = { x = 100.0, y = 200.0, z = 30.0, maxWeight = 1.5 } }), c)), 'invalid_stash', 'peso fracionado')
eq(select(2, HousingRegistry.Normalize(base({ stash = 'x' }), c)), 'invalid_stash', 'bau nao tabela')
-- Imóvel ilegal: sem mapa e sem aluguel; acesso só do dono e dos membros.
local function hideout(extra)
	local p = base({ id = 'porao_vinhedo', kind = 'hideout', label = 'Porão' })
	p.units, p.rent = nil, nil
	for k, v in pairs(extra or {}) do p[k] = v end
	return p
end
local h = HousingRegistry.Normalize(hideout({
	owner = { characterId = 7, name = 'Ana Souza' },
	members = { { characterId = '9', name = 'Beto' }, { characterId = 9, name = 'Beto' }, { characterId = 7, name = 'Ana Souza' } },
	blip = { enabled = true }
}), c)
eq(h.blip.enabled, false, 'ilegal nunca tem blip')
eq(h.units, 1, 'uma unidade')
eq(h.owner.characterId, 7, 'dono')
eq(#h.members, 1, 'membros sem duplicata nem dono')
eq(h.members[1].characterId, 9, 'id de texto vira numero')
eq(h.world, nil, 'mundo e definido pelo servidor')
eq(HousingRegistry.Normalize(hideout(), c).owner, nil, 'sem dono')
eq(#HousingRegistry.Normalize(hideout(), c).members, 0, 'sem membros')
eq(select(2, HousingRegistry.Normalize(hideout({ rent = { daily = 10, cycles = { 7 } } }), c)), 'invalid_rent', 'ilegal sem aluguel')
eq(select(2, HousingRegistry.Normalize(hideout({ units = 2 }), c)), 'invalid_units', 'ilegal com uma unidade')
eq(select(2, HousingRegistry.Normalize(hideout({ starter = true }), c)), 'invalid_starter', 'ilegal nao e inicial')
eq(select(2, HousingRegistry.Normalize(hideout({ owner = { characterId = 0, name = 'X' } }), c)), 'invalid_owner', 'dono invalido')
eq(select(2, HousingRegistry.Normalize(hideout({ owner = { characterId = 3, name = '<b>' } }), c)), 'invalid_owner', 'nome invalido')
eq(select(2, HousingRegistry.Normalize(hideout({ members = 'x' }), c)), 'invalid_members', 'membros nao tabela')
eq(select(2, HousingRegistry.Normalize(hideout({ members = { { characterId = 1.5, name = 'X' } } }), c)), 'invalid_members', 'membro invalido')
local many = {}
for i = 1, c.Limits.MaxHideoutMembers + 1 do many[i] = { characterId = 100 + i, name = 'P' .. i } end
eq(select(2, HousingRegistry.Normalize(hideout({ members = many }), c)), 'invalid_members', 'membros demais')
eq(HousingRegistry.Normalize(hideout({ stash = { x = 100.0, y = 200.0, z = 30.0 } }), c).stash.slots, c.Stash.Defaults.hideout.slots, 'bau padrao do ilegal')

eq(HousingRegistry.HasAccess(h, 7), true, 'dono entra')
eq(HousingRegistry.HasAccess(h, '7'), true, 'dono por texto')
eq(HousingRegistry.HasAccess(h, 9.0), true, 'membro')
eq(HousingRegistry.HasAccess(h, 8), false, 'estranho')
eq(HousingRegistry.HasAccess(h, nil), false, 'sem personagem')
eq(HousingRegistry.HasAccess(HousingRegistry.Normalize(base(), c), 7), false, 'tipo comum nao usa a regra')

eq(HousingRegistry.FreeWorld({}, nil), 1, 'primeiro mundo')
eq(HousingRegistry.FreeWorld({ a = { kind = 'hideout', world = 1 }, b = { kind = 'hideout', world = 3 }, c = { kind = 'house', world = 2 } }, nil), 2, 'buraco de mundo')
eq(HousingRegistry.FreeWorld({ a = { kind = 'hideout', world = 1 } }, 'a'), 1, 'ignora o proprio')
for kind in pairs(c.Kinds) do
	eq(type(c.DefaultBlips[kind]), 'table', 'blip padrao de ' .. kind)
	eq(type(c.Stash.Defaults[kind]), 'table', 'bau padrao de ' .. kind)
end

local refunded = false
local sagaOk, sagaErr = HousingRules.ExecuteSaga({
	{ name = 'debit', forward = function() return true end, compensate = function() refunded = true end },
	{ name = 'tenancy', forward = function() return false, 'no_vacancy' end }
}, {})
eq(sagaOk, false, 'saga falha sem vaga')
eq(sagaErr, 'no_vacancy', 'erro da saga preservado')
eq(refunded, true, 'estorno executado na saga')

print('housing tests ok')