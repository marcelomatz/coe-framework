BusinessTablet = {}

local LEDGER_LIMIT = 20
local MAX_AMOUNT = 1000000000
BusinessTablet.OfferSeconds = 60

local function fail(code)
	return { ok = false, error = code }
end

local function isOwner(business, characterId)
	return type(business.owner) == 'table' and tostring(business.owner.characterId) == tostring(characterId)
end

local function levelOf(business, characterId)
	local grade = BusinessGrades.Of(business, characterId)
	return grade and grade.level or -1
end

local function memberOf(business, characterId)
	for index, member in ipairs(business.staff) do
		if tostring(member.characterId) == tostring(characterId) then
			return member, index
		end
	end
	return nil
end

local function copyBusiness(business, staff)
	local raw = {}
	for key, value in pairs(business) do
		raw[key] = value
	end
	raw.staff = staff
	return raw
end

local function copyStaff(business)
	local staff = {}
	for _, member in ipairs(business.staff) do
		staff[#staff + 1] = { characterId = member.characterId, name = member.name, grade = member.grade }
	end
	return staff
end

local function partnerOf(business, characterId)
	for index, partner in ipairs(business.partners or {}) do
		if tostring(partner.characterId) == tostring(characterId) then
			return partner, index
		end
	end
	return nil
end

local function copyPartners(business)
	local partners = {}
	for _, partner in ipairs(business.partners or {}) do
		partners[#partners + 1] = { characterId = partner.characterId, name = partner.name }
	end
	return partners
end

local function cleanAmount(value)
	local amount = type(value) == 'number' and math.tointeger(value) or nil
	if not amount or amount < 1 or amount > MAX_AMOUNT then
		return nil
	end
	return amount
end

-- Quem gerencia só mexe em cargos abaixo do próprio; o dono não tem teto.
local function mayManage(business, ctx, targetLevel, newLevel)
	if isOwner(business, ctx.characterId) then
		return true
	end
	local own = levelOf(business, ctx.characterId)
	return targetLevel < own and (newLevel == nil or newLevel < own)
end

local function gradeList(business, canSeeSalary)
	local list = {}
	for _, grade in ipairs(business.grades) do
		list[#list + 1] = { id = grade.id, label = grade.label, level = grade.level, salary = canSeeSalary and grade.salary or nil }
	end
	return list
end

local actions = {}

function actions.overview(deps, ctx, business)
	local grade = BusinessGrades.Of(business, ctx.characterId)
	local onDuty = 0
	for _, member in ipairs(business.staff) do
		if deps.onDuty(business.id, member.characterId) then
			onDuty = onDuty + 1
		end
	end
	local owner = isOwner(business, ctx.characterId)
	if business.owner and deps.onDuty(business.id, business.owner.characterId) then
		onDuty = onDuty + 1
	end
	local result = {
		ok = true,
		business = {
			id = business.id, label = business.label, category = business.category,
			owner = business.owner and business.owner.name or nil, isOwner = owner,
			grade = grade and grade.label or (owner and 'Proprietário' or nil),
			staffCount = #business.staff, onDuty = onDuty,
			rules = business.rules,
			shop = deps.isShop ~= nil and deps.isShop(business.id) == true or nil
		},
		can = {
			funds = deps.can(business.id, ctx.characterId, 'business.funds'),
			staff = deps.can(business.id, ctx.characterId, 'business.staff'),
			fleet = deps.can(business.id, ctx.characterId, 'business.fleet')
		}
	}
	if result.can.funds then
		result.business.balance = deps.balance(business.id)
	end
	return result
end

function actions.staff(deps, ctx, business)
	local canManage = deps.can(business.id, ctx.characterId, 'business.staff')
	local canSeeSalary = canManage or deps.can(business.id, ctx.characterId, 'business.funds')
	local list = {}
	for _, member in ipairs(business.staff) do
		local grade = BusinessGrades.Find(business.grades, member.grade)
		list[#list + 1] = {
			characterId = member.characterId, name = member.name, grade = member.grade, gradeLabel = grade and grade.label or nil,
			level = grade and grade.level or nil, salary = canSeeSalary and grade and grade.salary or nil,
			onDuty = deps.onDuty(business.id, member.characterId)
		}
	end
	return { ok = true, staff = list, grades = gradeList(business, canSeeSalary), canManage = canManage }
end

function actions.hire(deps, ctx, business, payload)
	if not deps.can(business.id, ctx.characterId, 'business.staff') then
		return fail('forbidden')
	end
	local gradeId = payload.grade
	if gradeId ~= nil and type(gradeId) ~= 'string' then
		return fail('invalid_grade')
	end
	local grade
	if gradeId ~= nil then
		grade = BusinessGrades.Find(business.grades, gradeId)
	else
		grade = business.grades[1]
	end
	if #business.grades > 0 and not grade then
		return fail('invalid_grade')
	end
	if not mayManage(business, ctx, -1, grade and grade.level or nil) then
		return fail('grade_too_high')
	end
	local target, targetError = deps.resolve(payload.stateId)
	if not target then
		return fail(targetError or 'target_not_found')
	end
	if not target.source then
		return fail('target_not_online')
	end
	if isOwner(business, target.characterId) then
		return fail('is_owner')
	end
	if memberOf(business, target.characterId) then
		return fail('already_staff')
	end
	local pending = deps.offers[target.characterId]
	if pending and pending.expiresAt > deps.now() then
		return fail('offer_pending')
	end
	local offer = {
		id = deps.nextOfferId(), businessId = business.id, businessLabel = business.label, characterId = target.characterId,
		name = target.name, source = target.source, grade = grade and grade.id or nil, gradeLabel = grade and grade.label or nil,
		by = ctx.characterId, bySource = ctx.source, expiresAt = deps.now() + BusinessTablet.OfferSeconds
	}
	deps.offers[target.characterId] = offer
	deps.sendOffer(offer)
	deps.audit('tablet_hire_offer', ctx, target.characterId)
	return { ok = true, pending = true }
end

function actions.setGrade(deps, ctx, business, payload)
	if not deps.can(business.id, ctx.characterId, 'business.staff') then
		return fail('forbidden')
	end
	local characterId = type(payload.characterId) == 'string' and payload.characterId or nil
	local member = characterId and memberOf(business, characterId)
	if not member then
		return fail('unknown_member')
	end
	local grade = type(payload.grade) == 'string' and BusinessGrades.Find(business.grades, payload.grade) or nil
	if not grade then
		return fail('invalid_grade')
	end
	if not mayManage(business, ctx, levelOf(business, characterId), grade.level) then
		return fail('grade_too_high')
	end
	local staff = copyStaff(business)
	for _, entry in ipairs(staff) do
		if entry.characterId == characterId then
			entry.grade = grade.id
		end
	end
	local saved, saveError = deps.save(copyBusiness(business, staff))
	if not saved then
		return fail(saveError or 'database_error')
	end
	deps.audit('tablet_set_grade', ctx, characterId)
	return { ok = true }
end

function actions.fire(deps, ctx, business, payload)
	if not deps.can(business.id, ctx.characterId, 'business.staff') then
		return fail('forbidden')
	end
	local characterId = type(payload.characterId) == 'string' and payload.characterId or nil
	local member = characterId and memberOf(business, characterId)
	if not member then
		return fail('unknown_member')
	end
	if tostring(characterId) == tostring(ctx.characterId) then
		return fail('same_character')
	end
	if not mayManage(business, ctx, levelOf(business, characterId), nil) then
		return fail('grade_too_high')
	end
	local staff = {}
	for _, entry in ipairs(copyStaff(business)) do
		if entry.characterId ~= characterId then
			staff[#staff + 1] = entry
		end
	end
	local saved, saveError = deps.save(copyBusiness(business, staff))
	if not saved then
		return fail(saveError or 'database_error')
	end
	deps.audit('tablet_fire', ctx, characterId)
	return { ok = true }
end

function actions.finance(deps, ctx, business)
	if not deps.can(business.id, ctx.characterId, 'business.funds') then
		return fail('forbidden')
	end
	local balance = deps.balance(business.id)
	if balance == nil then
		return fail('economy_unavailable')
	end
	local payroll = 0
	for _, member in ipairs(business.staff) do
		local grade = BusinessGrades.Find(business.grades, member.grade)
		payroll = payroll + (grade and grade.salary or 0)
	end
	return { ok = true, balance = balance, payroll = payroll, ledger = deps.ledger(business.id, LEDGER_LIMIT) or {} }
end

function actions.deposit(deps, ctx, business, payload)
	local amount = cleanAmount(payload.amount)
	if not amount then
		return fail('invalid_amount')
	end
	local result = deps.deposit(business.id, ctx.characterId, amount)
	if result ~= true then
		return fail(type(result) == 'table' and result.error or 'economy_unavailable')
	end
	deps.audit('tablet_deposit', ctx, nil, amount)
	return { ok = true }
end

function actions.withdraw(deps, ctx, business, payload)
	if not deps.can(business.id, ctx.characterId, 'business.funds') then
		return fail('forbidden')
	end
	local amount = cleanAmount(payload.amount)
	if not amount then
		return fail('invalid_amount')
	end
	local result = deps.withdraw(business.id, ctx.characterId, amount)
	if result ~= true then
		return fail(type(result) == 'table' and result.error or 'economy_unavailable')
	end
	deps.audit('tablet_withdraw', ctx, nil, amount)
	return { ok = true }
end

-- Conta bancária empresarial (coe_banking): a aba Banco do app encaminha a operação ao banco, que confere as
-- permissões de cargo (banking.*) e devolve a conta atualizada. payload: { op, ... }.
function actions.bank(deps, ctx, business, payload)
	if not deps.bank then
		return fail('bank_unavailable')
	end
	local result = deps.bank(ctx.source, ctx.characterId, business.id, payload)
	if type(result) ~= 'table' then
		return fail('bank_unavailable')
	end
	return result
end

-- Loja (coe_shops): a aba Loja encaminha ao export BusinessTablet das lojas, que confere o acesso de cada operação
-- (preços com shops.prices, vendas para quem gerencia). payload: { op = 'overview' | 'price', ... }.
function actions.shop(deps, ctx, business, payload)
	if not deps.shop then
		return fail('shop_unavailable')
	end
	local result = deps.shop(ctx.source, ctx.characterId, business.id, payload)
	if type(result) ~= 'table' then
		return fail('shop_unavailable')
	end
	return result
end

-- Matriz de cargos x permissões (somente leitura; a edição de cargos fica no painel admin).
function actions.access(deps, ctx, business)
	if not deps.can(business.id, ctx.characterId, 'business.staff') then
		return fail('forbidden')
	end
	local labels = deps.permissions()
	local names = {}
	for name in pairs(labels) do
		names[#names + 1] = name
	end
	table.sort(names)
	local permissions = {}
	for _, name in ipairs(names) do
		permissions[#permissions + 1] = { name = name, label = labels[name] }
	end
	local grades = {}
	for _, grade in ipairs(business.grades) do
		local granted = {}
		for _, name in ipairs(grade.permissions) do
			granted[name] = true
		end
		grades[#grades + 1] = { id = grade.id, label = grade.label, level = grade.level, granted = granted }
	end
	return { ok = true, permissions = permissions, grades = grades, ownerAccess = business.rules.ownerAccess ~= false }
end

-- Estrutura física: área e pontos (ponto, baús, bancadas, showroom). Leitura para toda a equipe de ponto.
local STATION_KINDS = { { 'clocks', 'Ponto' }, { 'stashes', 'Baú' }, { 'crafts', 'Bancada' }, { 'showroom', 'Showroom' } }

local function areaCenter(area)
	if area.kind == 'circle' then
		return area.x, area.y
	end
	local x, y = 0, 0
	for _, p in ipairs(area.points) do
		x, y = x + p.x, y + p.y
	end
	return x / #area.points, y / #area.points
end

function actions.structure(_, _, business)
	local cx, cy = areaCenter(business.area)
	local area = { kind = business.area.kind, x = cx, y = cy, radius = business.area.radius, points = business.area.points and #business.area.points or nil }
	local stations = {}
	for _, entry in ipairs(STATION_KINDS) do
		for index, station in ipairs(business.stations[entry[1]] or {}) do
			stations[#stations + 1] = {
				kind = entry[1], kindLabel = entry[2], label = station.label or (entry[2] .. ' ' .. index),
				x = station.x, y = station.y, slots = station.slots, maxWeight = station.maxWeight
			}
		end
	end
	return { ok = true, area = area, stations = stations }
end

-- Frota: veículos das garagens do negócio. Toda a equipe vê; liberar para a equipe exige business.fleet.
function actions.fleet(deps, ctx, business)
	local garages = deps.fleet(business.id)
	if type(garages) ~= 'table' or garages.error then
		return fail(type(garages) == 'table' and garages.error or 'garages_unavailable')
	end
	return { ok = true, garages = garages, canManage = deps.can(business.id, ctx.characterId, 'business.fleet') }
end

function actions.fleetAccess(deps, ctx, business, payload)
	if not deps.can(business.id, ctx.characterId, 'business.fleet') then
		return fail('forbidden')
	end
	local vehicleId = type(payload.vehicleId) == 'string' and #payload.vehicleId <= 32 and payload.vehicleId:match('^%d+$') or nil
	if not vehicleId or type(payload.staff) ~= 'boolean' then
		return fail('invalid_vehicle')
	end
	local result = deps.setFleetStaff(business.id, vehicleId, payload.staff)
	if result ~= true then
		return fail(type(result) == 'table' and result.error or 'garages_unavailable')
	end
	deps.audit(payload.staff and 'tablet_fleet_on' or 'tablet_fleet_off', ctx, vehicleId)
	return { ok = true }
end

-- Propriedades: garagens de frota (coe_garages) e imóveis comerciais (coe_housing) do negócio.
function actions.properties(deps, _, business)
	local garages, buildings = deps.fleet(business.id), deps.properties(business.id)
	local garagesOk = type(garages) == 'table' and garages.error == nil
	local buildingsOk = type(buildings) == 'table' and buildings.error == nil
	if not garagesOk and not buildingsOk then
		return fail('properties_unavailable')
	end
	local list = {}
	for _, building in ipairs(buildingsOk and buildings or {}) do
		list[#list + 1] = {
			kind = 'commercial', kindLabel = 'Imóvel comercial', id = building.id, label = building.label, enabled = building.enabled,
			detail = building.leased and ('Alugado até ' .. os.date('%d/%m/%Y', building.paidUntil)) or 'Cedido ao negócio', x = building.x, y = building.y,
			overdue = building.overdue
		}
	end
	for _, garage in ipairs(garagesOk and garages or {}) do
		list[#list + 1] = {
			kind = 'garage', kindLabel = 'Garagem', id = garage.id, label = garage.label, enabled = garage.enabled,
			detail = garage.spots .. ' vaga(s), ' .. #garage.vehicles .. ' veículo(s)', x = garage.x, y = garage.y
		}
	end
	return { ok = true, properties = list }
end

-- Sócios: respondem pelas dívidas do negócio (empréstimos empresariais) junto com o dono. Só o dono adiciona e remove.
function actions.partners(_, ctx, business)
	local list = {}
	for _, partner in ipairs(business.partners or {}) do
		list[#list + 1] = { characterId = partner.characterId, name = partner.name }
	end
	return { ok = true, partners = list, owner = business.owner and business.owner.name or nil, canManage = isOwner(business, ctx.characterId) }
end

function actions.addPartner(deps, ctx, business, payload)
	if not isOwner(business, ctx.characterId) then
		return fail('forbidden')
	end
	if #(business.partners or {}) >= (deps.maxPartners or 10) then
		return fail('partner_limit')
	end
	local target, targetError = deps.resolve(payload.stateId)
	if not target then
		return fail(targetError or 'target_not_found')
	end
	if not target.source then
		return fail('target_not_online')
	end
	if isOwner(business, target.characterId) then
		return fail('is_owner')
	end
	if partnerOf(business, target.characterId) then
		return fail('already_partner')
	end
	local pending = deps.offers[target.characterId]
	if pending and pending.expiresAt > deps.now() then
		return fail('offer_pending')
	end
	local offer = {
		id = deps.nextOfferId(), kind = 'partner', businessId = business.id, businessLabel = business.label,
		characterId = target.characterId, name = target.name, source = target.source,
		by = ctx.characterId, bySource = ctx.source, expiresAt = deps.now() + BusinessTablet.OfferSeconds
	}
	deps.offers[target.characterId] = offer
	deps.sendOffer(offer)
	deps.audit('tablet_partner_offer', ctx, target.characterId)
	return { ok = true, pending = true }
end

-- Dívidas já contratadas continuam com quem era sócio na contratação.
function actions.removePartner(deps, ctx, business, payload)
	if not isOwner(business, ctx.characterId) then
		return fail('forbidden')
	end
	local characterId = type(payload.characterId) == 'string' and payload.characterId or nil
	if not characterId or not partnerOf(business, characterId) then
		return fail('unknown_partner')
	end
	local raw = copyBusiness(business, copyStaff(business))
	raw.partners = {}
	for _, partner in ipairs(copyPartners(business)) do
		if partner.characterId ~= characterId then
			raw.partners[#raw.partners + 1] = partner
		end
	end
	local saved, saveError = deps.save(raw)
	if not saved then
		return fail(saveError or 'database_error')
	end
	deps.audit('tablet_partner_removed', ctx, characterId)
	return { ok = true }
end

-- Resposta do contratado à proposta. Tudo é revalidado no aceite: o negócio pode ter mudado nesse meio tempo.
-- Devolve { ok, offer } ou { ok = false, error, offer }; `offer` permite avisar quem contratou.
function BusinessTablet.Answer(deps, source, offerId, accept)
	local characterId = deps.characterOf(source)
	if not characterId then
		return fail('no_character')
	end
	local offer = deps.offers[tostring(characterId)]
	if not offer or offer.id ~= offerId then
		return fail('no_offer')
	end
	deps.offers[offer.characterId] = nil
	local function failWith(code)
		local result = fail(code)
		result.offer = offer
		return result
	end
	if offer.expiresAt <= deps.now() then
		return failWith('offer_expired')
	end
	local ctx = { source = offer.bySource, characterId = offer.by, businessId = offer.businessId }
	local partner = offer.kind == 'partner'
	if accept ~= true then
		deps.audit(partner and 'tablet_partner_declined' or 'tablet_hire_declined', ctx, offer.characterId)
		return { ok = true, declined = true, offer = offer }
	end
	local business = deps.get(offer.businessId)
	if not business or not business.enabled then
		return failWith('no_business')
	end
	if isOwner(business, offer.characterId) then
		return failWith('is_owner')
	end
	if partner then
		-- O convite vale só enquanto quem convidou ainda for o dono.
		if not isOwner(business, offer.by) then
			return failWith('no_business')
		end
		if partnerOf(business, offer.characterId) then
			return failWith('already_partner')
		end
		if #(business.partners or {}) >= (deps.maxPartners or 10) then
			return failWith('partner_limit')
		end
		local raw = copyBusiness(business, copyStaff(business))
		raw.partners = copyPartners(business)
		raw.partners[#raw.partners + 1] = { characterId = offer.characterId, name = offer.name }
		local saved, saveError = deps.save(raw)
		if not saved then
			return failWith(saveError or 'database_error')
		end
		deps.audit('tablet_partner', ctx, offer.characterId)
		return { ok = true, offer = offer }
	end
	if memberOf(business, offer.characterId) then
		return failWith('already_staff')
	end
	if offer.grade and not BusinessGrades.Find(business.grades, offer.grade) then
		return failWith('invalid_grade')
	end
	local staff = copyStaff(business)
	staff[#staff + 1] = { characterId = offer.characterId, name = offer.name, grade = offer.grade }
	local saved, saveError = deps.save(copyBusiness(business, staff))
	if not saved then
		return failWith(saveError or 'database_error')
	end
	deps.audit('tablet_hire', ctx, offer.characterId)
	return { ok = true, offer = offer }
end

-- deps: get(id), currentDuty(source), characterOf(source), can(id, characterId, permission), onDuty(id, characterId),
-- balance(id), ledger(id, limit), deposit/withdraw(id, characterId, amount), save(raw), resolve(stateId), permissions(),
-- fleet(id), setFleetStaff(id, vehicleId, bool), properties(id), audit(event, ctx, target, count), bank(...), shop(...), isShop(id),
-- offers (tabela por characterId), now(), nextOfferId(), sendOffer(offer), maxPartners.
-- Pode usar o app do negócio agora: o dono e os cargos com business.remote (gerentes) a distância; o resto da
-- equipe só de ponto (canWork). access: BusinessAccess.Evaluate.
function BusinessTablet.Remote(business, characterId, access)
	if access.canRemote ~= nil then
		return access.canWork or access.canRemote
	end
	return access.owner or access.canWork
		or (access.staff and BusinessGrades.Can(business, characterId, 'business.remote', false)) or false
end

-- businessId: o negócio do app no tablet (um app por negócio). Acesso por BusinessTablet.Remote.
-- Sem businessId, vale o negócio do ponto batido.
function BusinessTablet.Handle(deps, source, action, payload, businessId)
	local handler = type(action) == 'string' and actions[action] or nil
	if not handler then
		return fail('unknown_action')
	end
	local characterId = deps.characterOf(source)
	if not characterId then
		return fail('no_character')
	end
	if businessId ~= nil then
		local business = type(businessId) == 'string' and deps.get(businessId) or nil
		local access = BusinessAccess.Evaluate(business, characterId, business ~= nil and deps.onDuty(business.id, characterId))
		if not access.owner and not access.staff then
			return fail('forbidden')
		end
		if not BusinessTablet.Remote(business, characterId, access) then
			return fail('not_on_duty')
		end
		local ctx = { source = source, characterId = tostring(characterId), businessId = business.id }
		return handler(deps, ctx, business, type(payload) == 'table' and payload or {})
	end
	businessId = deps.currentDuty(source)
	local business = type(businessId) == 'string' and deps.get(businessId) or nil
	if not business or not business.enabled then
		return fail('not_on_duty')
	end
	if not deps.onDuty(business.id, characterId) then
		return fail('not_on_duty')
	end
	local ctx = { source = source, characterId = tostring(characterId), businessId = business.id }
	return handler(deps, ctx, business, type(payload) == 'table' and payload or {})
end

-- Negócios do personagem para o tablet (um app por negócio): dono (com ownerAccess) ou equipe, só os ativos.
-- list: todos os negócios. Retorna { id, label, category }[] em ordem de nome.
function BusinessTablet.Instances(list, characterId)
	local result = {}
	if characterId == nil then
		return result
	end
	for _, business in ipairs(list or {}) do
		local access = BusinessAccess.Evaluate(business, characterId, false)
		if access.owner or access.staff then
			result[#result + 1] = { id = business.id, label = business.label or business.id, category = business.category }
		end
	end
	table.sort(result, function(a, b) return a.label < b.label end)
	return result
end