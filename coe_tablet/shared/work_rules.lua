-- Apps de trabalho do COE OS que substituem o tablet de trabalho básico do framework (coe_workpad): Ponto e Empregos
-- livres. Regras sem natives (testáveis fora do jogo), as mesmas do básico para o jogador não perder nada no upgrade.
TabletWorkRules = {}

-- Empregos livres -------------------------------------------------------------------------------------------

local function money(value)
	local text = tostring(math.floor(tonumber(value) or 0))
	return '$ ' .. text:reverse():gsub('(%d%d%d)', '%1.'):reverse():gsub('^%.', '')
end
TabletWorkRules.Money = money

---Linhas de pagamento de um emprego (definição pública do coe_jobs).
function TabletWorkRules.PayLines(job)
	local lines = {}
	local route, gather = job.route, job.gather
	if gather and gather.sell then
		lines[#lines + 1] = ('%s por %s vendido'):format(money(gather.sell.price), gather.unit or 'unidade')
	end
	if route then
		if tonumber(route.pay) and route.pay > 0 then
			lines[#lines + 1] = ('%s por %s'):format(money(route.pay), route.mode == 'collect' and 'coleta' or 'parada')
		end
		if tonumber(route.payPerKm) and route.payPerKm > 0 then
			lines[#lines + 1] = ('%s por km rodado'):format(money(route.payPerKm))
		end
		if tonumber(route.bonus) and route.bonus > 0 then
			local per = tonumber(route.perRoute)
			lines[#lines + 1] = per and ('%s de bônus a cada %d paradas'):format(money(route.bonus), per)
				or ('%s de bônus por rota'):format(money(route.bonus))
		end
	end
	return lines
end

---Catálogo para o app: definição pública (ListJobs) + a carreira do personagem (GetCareer) + o emprego atual.
function TabletWorkRules.FreeJobs(catalog, career, working)
	local mine = {}
	for _, entry in ipairs(type(career) == 'table' and career.jobs or {}) do
		mine[entry.id] = entry
	end
	local list = {}
	for _, job in ipairs(type(catalog) == 'table' and catalog or {}) do
		local progress = mine[job.id] or {}
		local center = type(job.center) == 'table' and job.center or nil
		list[#list + 1] = {
			id = job.id, label = job.label, description = job.description,
			kind = progress.kindLabel or (job.gather and 'Coleta e venda' or 'Rota'),
			pay = TabletWorkRules.PayLines(job),
			deposit = job.vehicle and tonumber(job.vehicle.deposit) or nil,
			tool = job.tool ~= nil,
			allowed = progress.allowed ~= false,
			lockedReason = progress.lockedReason,
			level = progress.level or 1, maxLevel = progress.maxLevel or (type(job.levels) == 'table' and #job.levels or 1),
			earned = progress.earned or 0,
			working = working == job.id,
			x = center and center[1], y = center and center[2]
		}
	end
	table.sort(list, function(a, b)
		if a.working ~= b.working then
			return a.working
		end
		if a.allowed ~= b.allowed then
			return a.allowed
		end
		return a.label < b.label
	end)
	return list
end

-- Ponto -----------------------------------------------------------------------------------------------------

---Centro aproximado de uma área (círculo ou polígono).
function TabletWorkRules.AreaCenter(area)
	if type(area) ~= 'table' then
		return nil
	end
	if area.kind == 'circle' and tonumber(area.x) and tonumber(area.y) then
		return area.x, area.y
	end
	if type(area.points) == 'table' and #area.points > 0 then
		local sx, sy = 0, 0
		for _, point in ipairs(area.points) do
			sx, sy = sx + (tonumber(point.x or point[1]) or 0), sy + (tonumber(point.y or point[2]) or 0)
		end
		return sx / #area.points, sy / #area.points
	end
	return nil
end

-- Onde bater o ponto: o primeiro relógio do negócio ou, sem relógio, o centro da área.
local function clockSpot(business)
	local clocks = type(business.stations) == 'table' and business.stations.clocks or nil
	local first = type(clocks) == 'table' and clocks[1] or nil
	if type(first) == 'table' and tonumber(first.x) and tonumber(first.y) then
		return first.x, first.y
	end
	return TabletWorkRules.AreaCenter(business.area)
end

---Locais de trabalho do personagem. entries: { business, access = { owner, staff }, grade = { label }|nil }.
---current: id do negócio em que está de ponto; since/now: segundos (início do ponto, se conhecido).
function TabletWorkRules.Workplaces(config, entries, current, since, now)
	local list = {}
	local currentView = nil
	for _, entry in ipairs(entries or {}) do
		local business, access = entry.business, entry.access or {}
		if type(business) == 'table' and (access.owner or access.staff) then
			local rules = type(business.rules) == 'table' and business.rules or {}
			local x, y = clockSpot(business)
			local view = {
				id = business.id, label = business.label or business.id,
				category = (config.CategoryLabels or {})[business.category] or business.category or 'Negócio',
				role = access.owner and 'Dono' or (type(entry.grade) == 'table' and entry.grade.label) or 'Equipe',
				salary = not access.owner and type(entry.grade) == 'table' and tonumber(entry.grade.salary) or nil,
				clockRequired = rules.clockRequired ~= false, offsite = rules.clockOffsite == true,
				enabled = business.enabled ~= false, onDuty = business.id == current, x = x, y = y
			}
			list[#list + 1] = view
			if view.onDuty then
				currentView = view
			end
		end
	end
	table.sort(list, function(a, b)
		if a.onDuty ~= b.onDuty then
			return a.onDuty
		end
		return a.label < b.label
	end)
	local duty = nil
	if current then
		duty = {
			id = current, label = currentView and currentView.label or current,
			category = currentView and currentView.category or nil,
			seconds = (since and now and now >= since) and (now - since) or nil
		}
	end
	return { duty = duty, workplaces = list }
end
