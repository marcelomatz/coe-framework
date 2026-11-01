TabletProfile = {}

local SCRIPT_PATTERN = '^nui://[a-z0-9_]+/html/[a-z0-9_]+%.js$'
local INSTANCE_PATTERN = '^[%w_%-]+$'

function TabletProfile.IsValidScript(path)
	return type(path) == 'string' and #path <= 96 and path:match(SCRIPT_PATTERN) ~= nil
end

local function appVisible(id, app, jobGroup, dutyCategory, hasItem, canSee)
	if app.item and not (type(hasItem) == 'function' and hasItem(app.item) == true) then
		return false
	end
	if app.everyone == true then
		return true
	end
	-- `ownerCheck`: o resource do app decide (ex.: Casa só para quem é dono de um local).
	if app.ownerCheck == true then
		return type(canSee) == 'function' and canSee(app, id) == true
	end
	if app.anyDuty == true and dutyCategory then
		return true
	end
	if type(app.categories) == 'table' and dutyCategory and app.categories[dutyCategory] == true then
		return true
	end
	if type(app.jobs) ~= 'table' or not jobGroup then
		return false
	end
	return app.jobs[jobGroup.name] == true and (tonumber(jobGroup.grade) or 0) >= (app.minGrade or 0)
end

-- groups: { [tipo] = { name, grade } } (coe_core). dutyCategory: categoria do negócio em que o jogador
-- está de ponto (ex.: police) ou nil. hasItem(nome) -> bool diz se o jogador tem o item exigido por apps com `item`.
-- canSee(app, id) -> bool responde pelos apps com `ownerCheck` (id: a chave do app em config.Apps).
-- instancesOf(app) -> { id, label }[] responde pelos apps com `instances` (ex.: um app por negócio do jogador);
-- cada instância vira um app `<app>:<instância>`, mesmo para administradores (só as do próprio personagem).
-- Retorna o perfil do jogador ou nil + código.
function TabletProfile.Resolve(config, groups, isAdmin, dutyCategory, hasItem, canSee, instancesOf)
	local jobGroup = type(groups) == 'table' and groups.job or nil
	local ids = {}
	for id, app in pairs(config.Apps) do
		if TabletProfile.IsValidScript(app.script) and (app.instances == true or isAdmin or appVisible(id, app, jobGroup, dutyCategory, hasItem, canSee)) then
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
		local base = { label = app.label or id, script = app.script, icon = app.icon, color = app.color, group = app.group or 'personal' }
		if app.instances == true then
			local list = type(instancesOf) == 'function' and instancesOf(app) or nil
			for _, instance in ipairs(type(list) == 'table' and list or {}) do
				local key = type(instance) == 'table' and instance.id
				if type(key) == 'string' and key:match(INSTANCE_PATTERN) then
					apps[#apps + 1] = {
						id = id .. ':' .. key, base = id, instance = key, label = tostring(instance.label or key):sub(1, 40),
						kind = base.label, script = base.script, icon = base.icon, color = base.color, group = base.group
					}
				end
			end
		else
			apps[#apps + 1] = { id = id, base = id, label = base.label, script = base.script, icon = base.icon, color = base.color, group = base.group }
		end
	end
	if #apps == 0 then
		return nil, 'no_apps'
	end

	local job = jobGroup and jobGroup.name or nil
	local override = job and config.Profiles[job]
	local categoryLabel = dutyCategory and config.CategoryLabels and config.CategoryLabels[dutyCategory]
	return {
		job = isAdmin and 'admin' or job or dutyCategory,
		label = isAdmin and 'Administração' or (override and override.label) or categoryLabel or job or dutyCategory or 'Pessoal',
		grade = jobGroup and tonumber(jobGroup.grade) or 0,
		apps = apps,
		groups = config.Groups
	}
end

-- O jogador pode chamar o app? Reavaliado a cada ação (o emprego pode mudar com o tablet aberto).
-- Retorna o app do perfil (com `base` e `instance`) ou nil.
function TabletProfile.CanUse(config, groups, isAdmin, appId, dutyCategory, hasItem, canSee, instancesOf)
	local profile = TabletProfile.Resolve(config, groups, isAdmin, dutyCategory, hasItem, canSee, instancesOf)
	if not profile then
		return nil
	end
	for _, app in ipairs(profile.apps) do
		if app.id == appId then
			return app
		end
	end
	return nil
end

-- Atalho (ex.: /casa): abre o mesmo tablet, com todos os apps do jogador, já dentro do primeiro app do atalho
-- que ele vê (launch). Sem nenhum, devolve nil e a mensagem de recusa.
function TabletProfile.Scope(config, profile, shortcutName)
	local shortcut = type(shortcutName) == 'string' and config.Shortcuts and config.Shortcuts[shortcutName]
	if type(shortcut) ~= 'table' or type(shortcut.apps) ~= 'table' then
		return nil, nil
	end
	local wanted = {}
	for _, appId in ipairs(shortcut.apps) do
		wanted[appId] = true
	end
	for _, app in ipairs(profile and profile.apps or {}) do
		if wanted[app.base or app.id] then
			local scoped = {}
			for key, value in pairs(profile) do
				scoped[key] = value
			end
			scoped.launch = app.id
			return scoped
		end
	end
	local first = config.Apps[shortcut.apps[1]]
	return nil, shortcut.deniedMessage or (first and first.deniedMessage) or nil
end
