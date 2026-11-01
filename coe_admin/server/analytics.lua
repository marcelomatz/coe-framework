AdminAnalytics = {}

local function count(list)
	return type(list) == 'table' and #list or 0
end

-- Resumo agregado das áreas do painel, calculado a partir de dados já em memória (sem consultas ao banco).
-- input: players = { { ping, hasCharacter } }, businesses/garages/housing = { available, list, ... },
-- fleets = { [garageId] = lista }, duty = { total, byBusiness }, resources = lista, database/economy = opcionais.
function AdminAnalytics.Build(input)
	local result = {}

	local pings, withCharacter = 0, 0
	for _, player in ipairs(input.players or {}) do
		pings = pings + (tonumber(player.ping) or 0)
		if player.hasCharacter then
			withCharacter = withCharacter + 1
		end
	end
	local online = count(input.players)
	result.players = {
		online = online,
		withCharacter = withCharacter,
		averagePing = online > 0 and math.floor(pings / online + 0.5) or 0,
		characters = input.database and input.database.characters or nil
	}

	local businesses = input.businesses or {}
	if businesses.available then
		local summary = { available = true, total = 0, byCategory = {}, withOwner = 0, staff = 0, withoutStaff = 0, disabled = 0,
			stations = { crafts = 0, stashes = 0, clocks = 0 }, onDuty = input.duty and input.duty.total or 0, dutyByBusiness = {} }
		for _, business in ipairs(businesses.list or {}) do
			summary.total = summary.total + 1
			summary.byCategory[business.category] = (summary.byCategory[business.category] or 0) + 1
			if business.owner then
				summary.withOwner = summary.withOwner + 1
			end
			if business.enabled == false then
				summary.disabled = summary.disabled + 1
			end
			local staff = count(business.staff)
			summary.staff = summary.staff + staff
			if staff == 0 then
				summary.withoutStaff = summary.withoutStaff + 1
			end
			for _, kind in ipairs({ 'crafts', 'stashes', 'clocks' }) do
				summary.stations[kind] = summary.stations[kind] + count(business.stations and business.stations[kind])
			end
			local present = input.duty and input.duty.byBusiness and input.duty.byBusiness[business.id]
			if present then
				summary.dutyByBusiness[#summary.dutyByBusiness + 1] = { id = business.id, label = business.label, count = present }
			end
		end
		table.sort(summary.dutyByBusiness, function(a, b) return a.count > b.count end)
		summary.withoutOwner = summary.total - summary.withOwner
		result.businesses = summary
	else
		result.businesses = { available = false }
	end

	local garages = input.garages or {}
	if garages.available then
		local summary = { available = true, total = 0, byKind = {}, spots = 0, fleetVehicles = 0, disabled = 0 }
		for _, garage in ipairs(garages.list or {}) do
			summary.total = summary.total + 1
			summary.byKind[garage.kind] = (summary.byKind[garage.kind] or 0) + 1
			summary.spots = summary.spots + count(garage.spots)
			summary.fleetVehicles = summary.fleetVehicles + count(input.fleets and input.fleets[garage.id])
			if garage.enabled == false then
				summary.disabled = summary.disabled + 1
			end
		end
		result.garages = summary
	else
		result.garages = { available = false }
	end

	local housing = input.housing or {}
	if housing.available then
		local summary = { available = true, total = 0, byKind = {}, units = 0, occupied = 0, disabled = 0 }
		for _, property in ipairs(housing.list or {}) do
			summary.total = summary.total + 1
			summary.byKind[property.kind] = (summary.byKind[property.kind] or 0) + 1
			summary.units = summary.units + (tonumber(property.units) or 1)
			summary.occupied = summary.occupied + (tonumber(property.occupied) or 0)
			if property.enabled == false then
				summary.disabled = summary.disabled + 1
			end
		end
		summary.vacant = math.max(0, summary.units - summary.occupied)
		result.housing = summary
	else
		result.housing = { available = false }
	end

	local economy = input.economy
	result.economy = economy and not economy.error
		and { available = true, accounts = economy.accounts, total = economy.total } or { available = false }

	local framework = { total = 0, started = 0, stopped = 0, critical = 0 }
	for _, resource in ipairs(input.resources or {}) do
		framework.total = framework.total + 1
		if resource.state == 'started' then
			framework.started = framework.started + 1
		else
			framework.stopped = framework.stopped + 1
		end
		if resource.critical then
			framework.critical = framework.critical + 1
		end
	end
	result.framework = framework

	return result
end

-- Cache com atualização em segundo plano: devolve o último valor na hora e só recalcula depois do TTL.
-- Consultas de banco nunca bloqueiam a abertura do painel (exceto a primeira, quando ainda não há valor).
-- deps: now() -> ms; load() -> valor|nil (pode bloquear); async(fn) executa fn fora da chamada.
function AdminAnalytics.Cache(deps, ttlMs)
	local value, at, refreshing = nil, nil, false
	local service = {}

	local function refresh()
		refreshing = true
		local loaded = deps.load()
		if loaded ~= nil then
			value, at = loaded, deps.now()
		end
		refreshing = false
	end

	function service.Get()
		if value == nil then
			if not refreshing then
				refresh()
			end
			return value
		end
		if not refreshing and deps.now() - at >= ttlMs then
			deps.async(refresh)
		end
		return value
	end

	return service
end
