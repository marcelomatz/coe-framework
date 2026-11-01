CraftingCatalog = {}

-- Receitas e cardápios cadastrados no painel. Três tipos de registro, todos persistidos:
-- recipe   { id, label, category, timeMs, inputs, outputs }  receita própria (as do config.lua não são editáveis);
-- menu     { id, label, category = categoria do negócio, recipes = { ids } }  tipo de cardápio (ex.: Pizzaria);
-- business { menu = id | nil, recipes = { ids } | nil }  cardápio de um negócio: o tipo escolhido e, se ajustado,
--          a lista própria (que vale no lugar da do tipo).
-- deps: config, registry, owner (nome do resource), store = { save(kind, id, data), delete(kind, id) } -> true | nil, erro,
-- itemExists(name) -> bool.
local LABEL_MAX = 48

local function label(value)
	return type(value) == 'string' and value ~= '' and #value <= LABEL_MAX and not value:find('[<>]')
end

local function count(map)
	local n = 0
	for _ in pairs(map) do
		n = n + 1
	end
	return n
end

function CraftingCatalog.New(deps)
	local config, registry, owner = deps.config, deps.registry, deps.owner
	local recipes, menus, assignments, illegalBenches = {}, {}, {}, {}
	local fixed = {}
	for _, recipe in ipairs(config.Recipes) do
		fixed[recipe.id] = true
	end
	local catalog = {}

	local function benchOf(businessCategory)
		return config.BusinessBenches[businessCategory]
	end

	-- Receitas que a bancada da categoria do negócio aceita.
	local function fitsBench(businessCategory, recipeId)
		local bench, recipe = benchOf(businessCategory), registry.Recipe(recipeId)
		if not bench or not recipe then
			return false
		end
		for _, category in ipairs(bench.categories) do
			if recipe.category == category then
				return true
			end
		end
		return false
	end

	local function recipeList(list, businessCategory)
		if type(list) ~= 'table' or #list > config.MaxMenuRecipes then
			return nil
		end
		local out, seen = {}, {}
		for _, id in ipairs(list) do
			if not CraftingRules.Identifier(id) or not fitsBench(businessCategory, id) then
				return nil
			end
			if not seen[id] then
				seen[id] = true
				out[#out + 1] = id
			end
		end
		return out
	end

	local function illegalRecipeList(list)
		if list == nil then
			return nil, true
		end
		if type(list) ~= 'table' or #list > config.MaxMenuRecipes then
			return nil, false
		end
		local out, seen = {}, {}
		for _, id in ipairs(list) do
			local recipe = CraftingRules.Identifier(id) and registry.Recipe(id) or nil
			if not recipe or recipe.category ~= 'illegal' then
				return nil, false
			end
			if not seen[id] then
				seen[id] = true
				out[#out + 1] = id
			end
		end
		return #out > 0 and out or nil, true
	end

	local function validBench(raw)
		if type(raw) ~= 'table' or not CraftingRules.Identifier(raw.id) or #raw.id > 32 then
			return nil, 'invalid_bench_id'
		end
		if not label(raw.label) then
			return nil, 'invalid_bench_label'
		end
		local x, y, z = tonumber(raw.x), tonumber(raw.y), tonumber(raw.z)
		local maxCoord = config.MaxCoordinate or 10000.0
		if not x or not y or not z or math.abs(x) > maxCoord or math.abs(y) > maxCoord or math.abs(z) > maxCoord then
			return nil, 'invalid_bench_coords'
		end
		local radius = raw.radius == nil and 1.5 or tonumber(raw.radius)
		if not radius or radius < 0.5 or radius > 10.0 then
			return nil, 'invalid_bench_coords'
		end
		local list, okList = illegalRecipeList(raw.recipes)
		if not okList then
			return nil, 'invalid_bench_recipes'
		end
		return {
			id = raw.id,
			label = raw.label,
			enabled = raw.enabled ~= false,
			x = x + 0.0,
			y = y + 0.0,
			z = z + 0.0,
			radius = radius + 0.0,
			recipes = list
		}
	end

	local function validRecipe(raw)
		local clean, errorCode = CraftingRules.Recipe(raw, config)
		if not clean then
			return nil, errorCode
		end
		if not config.EditableCategories[clean.category] then
			return nil, 'invalid_recipe_category'
		end
		if not label(clean.label) then
			return nil, 'invalid_recipe_label'
		end
		for _, list in ipairs({ clean.inputs, clean.outputs }) do
			for _, entry in ipairs(list) do
				if not deps.itemExists(entry.item) then
					return nil, 'unknown_item'
				end
			end
		end
		return clean
	end

	local function validMenu(raw)
		if type(raw) ~= 'table' or not CraftingRules.Identifier(raw.id) or #raw.id > 32 then
			return nil, 'invalid_menu_id'
		end
		if not label(raw.label) then
			return nil, 'invalid_menu_label'
		end
		if type(raw.category) ~= 'string' or not benchOf(raw.category) then
			return nil, 'invalid_menu_category'
		end
		local list = recipeList(raw.recipes or {}, raw.category)
		if not list then
			return nil, 'invalid_menu_recipes'
		end
		return { id = raw.id, label = raw.label, category = raw.category, recipes = list }
	end

	local function validAssignment(business, raw)
		if type(raw) ~= 'table' then
			return nil, 'invalid_assignment'
		end
		local menu = raw.menu
		if menu ~= nil and (type(menu) ~= 'string' or not menus[menu] or menus[menu].category ~= business.category) then
			return nil, 'unknown_menu'
		end
		local list
		if raw.recipes ~= nil then
			list = recipeList(raw.recipes, business.category)
			if not list then
				return nil, 'invalid_menu_recipes'
			end
		end
		return { menu = menu, recipes = list }
	end

	-- Registros lidos do banco: { kind, id, data }. Inválidos são ignorados e devolvidos para log.
	function catalog.Load(rows)
		local skipped = {}
		local function skip(row, errorCode)
			skipped[#skipped + 1] = { kind = row.kind, id = row.id, error = errorCode }
		end
		for _, row in ipairs(rows) do
			if row.kind == 'recipe' then
				local data = type(row.data) == 'table' and row.data or {}
				data.id = row.id
				local clean, errorCode = CraftingRules.Recipe(data, config)
				if clean and not fixed[clean.id] then
					local added, addError = registry.AddRecipe(clean, owner)
					if added then
						recipes[clean.id] = true
					else
						skip(row, addError)
					end
				else
					skip(row, errorCode or 'reserved_recipe')
				end
			end
		end
		-- Cardápios e bancadas depois das receitas: as listas só aceitam receitas já registradas.
		for _, row in ipairs(rows) do
			local data = type(row.data) == 'table' and row.data or {}
			if row.kind == 'menu' then
				data.id = row.id
				local clean, errorCode = validMenu(data)
				if clean then
					menus[clean.id] = clean
				else
					skip(row, errorCode)
				end
			elseif row.kind == 'bench' then
				data.id = row.id
				local clean, errorCode = validBench(data)
				if clean then
					illegalBenches[clean.id] = clean
				else
					skip(row, errorCode)
				end
			end
		end
		for _, row in ipairs(rows) do
			if row.kind == 'business' and type(row.data) == 'table' then
				assignments[row.id] = { menu = row.data.menu, recipes = row.data.recipes, category = row.data.category }
			end
		end
		return skipped
	end

	function catalog.SaveRecipe(raw)
		local clean, errorCode = validRecipe(raw)
		if not clean then
			return nil, errorCode
		end
		if fixed[clean.id] then
			return nil, 'reserved_recipe'
		end
		local current = registry.Owner(clean.id)
		if current ~= nil and current ~= owner then
			return nil, 'id_conflict'
		end
		if not recipes[clean.id] and count(recipes) >= config.MaxCustomRecipes then
			return nil, 'recipe_limit'
		end
		local saved, saveError = deps.store.save('recipe', clean.id, clean)
		if not saved then
			return nil, saveError or 'database_error'
		end
		registry.AddRecipe(clean, owner)
		recipes[clean.id] = true
		return clean
	end

	function catalog.DeleteRecipe(id)
		if type(id) ~= 'string' or not recipes[id] then
			return nil, 'unknown_recipe'
		end
		local deleted, deleteError = deps.store.delete('recipe', id)
		if not deleted then
			return nil, deleteError or 'database_error'
		end
		registry.RemoveRecipe(id, owner)
		recipes[id] = nil
		return true
	end

	function catalog.SaveMenu(raw)
		local clean, errorCode = validMenu(raw)
		if not clean then
			return nil, errorCode
		end
		if not menus[clean.id] and count(menus) >= config.MaxMenus then
			return nil, 'menu_limit'
		end
		local stored = { label = clean.label, category = clean.category, recipes = clean.recipes }
		local saved, saveError = deps.store.save('menu', clean.id, stored)
		if not saved then
			return nil, saveError or 'database_error'
		end
		menus[clean.id] = clean
		return clean
	end

	function catalog.DeleteMenu(id)
		if type(id) ~= 'string' or not menus[id] then
			return nil, 'unknown_menu'
		end
		local deleted, deleteError = deps.store.delete('menu', id)
		if not deleted then
			return nil, deleteError or 'database_error'
		end
		menus[id] = nil
		return true
	end

	function catalog.SaveBench(raw)
		local clean, errorCode = validBench(raw)
		if not clean then
			return nil, errorCode
		end
		if not illegalBenches[clean.id] and count(illegalBenches) >= (config.MaxIllegalBenches or 32) then
			return nil, 'bench_limit'
		end
		local saved, saveError = deps.store.save('bench', clean.id, clean)
		if not saved then
			return nil, saveError or 'database_error'
		end
		illegalBenches[clean.id] = clean
		return clean
	end

	function catalog.DeleteBench(id)
		if type(id) ~= 'string' or not illegalBenches[id] then
			return nil, 'unknown_bench'
		end
		local deleted, deleteError = deps.store.delete('bench', id)
		if not deleted then
			return nil, deleteError or 'database_error'
		end
		illegalBenches[id] = nil
		return true
	end

	function catalog.Bench(id)
		return type(id) == 'string' and illegalBenches[id] or nil
	end

	function catalog.Benches()
		local list = {}
		for _, bench in pairs(illegalBenches) do
			list[#list + 1] = bench
		end
		table.sort(list, function(a, b)
			if a.label == b.label then
				return a.id < b.id
			end
			return a.label < b.label
		end)
		return list
	end

	-- business: o negócio (id e categoria). raw: { menu, recipes } (recipes nil = segue o tipo).
	function catalog.SetBusinessMenu(business, raw)
		if type(business) ~= 'table' or type(business.id) ~= 'string' or not benchOf(business.category) then
			return nil, 'unknown_business'
		end
		local clean, errorCode = validAssignment(business, raw)
		if not clean then
			return nil, errorCode
		end
		if clean.menu == nil and clean.recipes == nil then
			local deleted, deleteError = deps.store.delete('business', business.id)
			if not deleted then
				return nil, deleteError or 'database_error'
			end
			assignments[business.id] = nil
			return true
		end
		clean.category = business.category
		local saved, saveError = deps.store.save('business', business.id, clean)
		if not saved then
			return nil, saveError or 'database_error'
		end
		assignments[business.id] = clean
		return true
	end

	-- Receitas do negócio: lista ajustada > cardápio do tipo > config.BusinessRecipes > nil (todas da bancada).
	-- Cardápio salvo para outra categoria (o negócio mudou de categoria) é ignorado.
	function catalog.RecipesFor(business)
		local entry = type(business) == 'table' and assignments[business.id] or nil
		if entry and entry.category == business.category then
			if entry.recipes then
				return entry.recipes
			end
			local menu = entry.menu and menus[entry.menu]
			if menu and menu.category == business.category then
				return menu.recipes
			end
		end
		return config.BusinessRecipes[business and business.id]
	end

	-- Visão completa para o painel admin.
	function catalog.Admin()
		local categories, benches = {}, {}
		for businessCategory, bench in pairs(config.BusinessBenches) do
			benches[businessCategory] = { label = bench.label, categories = bench.categories }
			for _, category in ipairs(bench.categories) do
				if config.EditableCategories[category] then
					categories[#categories + 1] = { id = category, label = bench.label, business = businessCategory }
				end
			end
		end
		if config.IllegalBench and config.EditableCategories.illegal then
			categories[#categories + 1] = { id = 'illegal', label = config.IllegalBench.label }
		end
		table.sort(categories, function(a, b)
			return a.id < b.id
		end)
		local list = {}
		for _, recipe in ipairs(registry.All()) do
			list[#list + 1] = {
				id = recipe.id, label = recipe.label, category = recipe.category, timeMs = recipe.timeMs,
				inputs = recipe.inputs, outputs = recipe.outputs, custom = recipes[recipe.id] == true
			}
		end
		local menuList = {}
		for _, menu in pairs(menus) do
			menuList[#menuList + 1] = menu
		end
		table.sort(menuList, function(a, b)
			return a.label < b.label
		end)
		local businessMenus = {}
		for businessId, entry in pairs(assignments) do
			businessMenus[businessId] = entry
		end
		return {
			categories = categories,
			benches = benches,
			recipes = list,
			menus = menuList,
			businesses = businessMenus,
			illegalBenches = catalog.Benches()
		}
	end

	return catalog
end
