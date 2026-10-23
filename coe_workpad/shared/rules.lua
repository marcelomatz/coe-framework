-- Regras do tablet de trabalho, sem natives (testáveis fora do jogo).
WorkpadRules = {}

local SCRIPT_PATTERN = '^nui://[a-z0-9_]+/html/[a-z0-9_]+%.js$'
local INSTANCE_PATTERN = '^[%w_%-]+$'

function WorkpadRules.IsValidScript(path)
	return type(path) == 'string' and #path <= 96 and path:match(SCRIPT_PATTERN) ~= nil
end

local function available(app, started)
	if app.requires and not started(app.requires) then
		return false
	end
	return app.native == true or started(app.resource)
end

---Apps que o jogador vê. ctx.started(resource) -> bool; ctx.instances(app) -> { {id, label, category} } (apps com
---instâncias, ex.: um por negócio). Retorna { apps, groups } ou nil + 'no_apps'.
function WorkpadRules.Resolve(config, ctx)
	local ids = {}
	for id, app in pairs(config.Apps) do
		if WorkpadRules.IsValidScript(app.script) and available(app, ctx.started) then
			ids[#ids + 1] = id
		end
	end
	table.sort(ids, function(a, b)
		local orderA, orderB = config.Apps[a].order or 100, config.Apps[b].order or 100
		if orderA ~= orderB then
			return orderA < orderB
		end
		return a < b
	end)
	local apps = {}
	for _, id in ipairs(ids) do
		local app = config.Apps[id]
		if app.instances == true then
			local list = ctx.instances(app)
			for _, instance in ipairs(type(list) == 'table' and list or {}) do
				local key = type(instance) == 'table' and instance.id
				if type(key) == 'string' and #key <= 48 and key:match(INSTANCE_PATTERN) then
					apps[#apps + 1] = {
						id = id .. ':' .. key, base = id, instance = key, label = tostring(instance.label or key):sub(1, 40),
						kind = (config.CategoryLabels or {})[instance.category] or app.label,
						script = app.script, icon = app.icon, group = app.group
					}
				end
			end
		else
			apps[#apps + 1] = { id = id, base = id, label = app.label, script = app.script, icon = app.icon, group = app.group }
		end
	end
	if #apps == 0 then
		return nil, 'no_apps'
	end
	return { apps = apps, groups = config.Groups }
end

function WorkpadRules.Find(profile, appId)
	for _, app in ipairs(profile and profile.apps or {}) do
		if app.id == appId then
			return app
		end
	end
	return nil
end

---Pedido da tela: ids curtos e payload pequeno. encode(payload) -> string (json.encode no jogo).
function WorkpadRules.Request(appId, action, payload, maxBytes, encode)
	if type(appId) ~= 'string' or type(action) ~= 'string' or #appId > 96 or #action > 32 then
		return false, 'invalid_request'
	end
	if payload ~= nil and (type(payload) ~= 'table' or #encode(payload) > maxBytes) then
		return false, 'invalid_payload'
	end
	return true
end

-- Empregos livres -------------------------------------------------------------------------------------------

local function money(value)
	local text = tostring(math.floor(tonumber(value) or 0))
	return '$ ' .. text:reverse():gsub('(%d%d%d)', '%1.'):reverse():gsub('^%.', '')
end
WorkpadRules.Money = money

---Linhas de pagamento de um emprego (definição pública do coe_jobs).
function WorkpadRules.PayLines(job)
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
function WorkpadRules.FreeJobs(catalog, career, working)
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
			pay = WorkpadRules.PayLines(job),
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
function WorkpadRules.AreaCenter(area)
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
	return WorkpadRules.AreaCenter(business.area)
end

---Locais de trabalho do personagem. entries: { business, access = { owner, staff }, grade = { label }|nil }.
---current: id do negócio em que está de ponto; since/now: segundos (início do ponto, se conhecido).
function WorkpadRules.Workplaces(config, entries, current, since, now)
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
