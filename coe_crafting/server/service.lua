CraftingService = {}

-- deps: registry, inventory = { count(id, item) -> n, remove(id, item, n) -> true|false,erro,
-- add(id, item, n) -> true|false,erro }, audit(event, context).
-- Contexto de uma bancada: { inventoryId, stashId, recipes = { [id] = true } | nil (todas da categoria),
-- access = function(playerId) -> bool, motivo (código de erro quando nega; padrão forbidden) }.
-- Fluxo: Begin valida e reserva o jogador; Complete confere de novo, consome os insumos e entrega as saídas.
function CraftingService.New(deps)
	local audit = deps.audit or function() end
	local inventory = deps.inventory
	local busy = {}
	local service = {}

	-- Containers de consumo na ordem de uso.
	local function sources(bench, context)
		local list = {}
		if (bench.source == 'player' or bench.source == 'both') and context.inventoryId then
			list[#list + 1] = context.inventoryId
		end
		if (bench.source == 'stash' or bench.source == 'both') and context.stashId then
			list[#list + 1] = context.stashId
		end
		return list
	end

	local function destination(bench, context)
		if bench.output == 'stash' then
			return context.stashId
		end
		return context.inventoryId
	end

	local function have(containers, item)
		local total = 0
		for _, id in ipairs(containers) do
			total = total + (inventory.count(id, item) or 0)
		end
		return total
	end

	local function lacking(containers, recipe)
		for _, input in ipairs(recipe.inputs) do
			if have(containers, input.item) < input.count then
				return true
			end
		end
		return false
	end

	local function allowedRecipes(context, playerId)
		local raw = type(context.recipes) == 'function' and context.recipes(playerId) or context.recipes
		if raw == nil then
			return nil
		end
		if type(raw) ~= 'table' then
			return {}
		end
		if raw[1] ~= nil then
			local set = {}
			for _, id in ipairs(raw) do
				if type(id) == 'string' then
					set[id] = true
				end
			end
			return set
		end
		return raw
	end

	local function resolve(playerId, benchType, recipeId, context)
		local bench = deps.registry.Bench(benchType)
		if not bench then
			return nil, nil, nil, 'bench_not_found'
		end
		if type(context) ~= 'table' then
			return nil, nil, nil, 'invalid_context'
		end
		if context.access then
			local allowed, reason = context.access(playerId, recipeId)
			if not allowed then
				return nil, nil, nil, reason or 'forbidden'
			end
		end
		local containers = sources(bench, context)
		if #containers == 0 or not destination(bench, context) then
			return nil, nil, nil, 'no_container'
		end
		local recipe
		if recipeId ~= nil then
			recipe = deps.registry.Recipe(recipeId)
			local inCategory = false
			for _, category in ipairs(bench.categories) do
				if recipe and recipe.category == category then
					inCategory = true
				end
			end
			local allowedSet = allowedRecipes(context, playerId)
			local allowed = inCategory and (allowedSet == nil or allowedSet[recipeId] == true)
			if not recipe or not allowed then
				return nil, nil, nil, 'recipe_not_found'
			end
		end
		return bench, containers, recipe
	end

	-- Receitas da bancada com o que o jogador tem de cada insumo, para a interface.
	function service.List(playerId, benchType, context)
		local bench, containers, _, errorCode = resolve(playerId, benchType, nil, context)
		if not bench then
			return nil, errorCode
		end
		local allowedSet = allowedRecipes(context, playerId)
		local out = {}
		for _, recipe in ipairs(deps.registry.RecipesOf(benchType)) do
			local inputs = {}
			for _, input in ipairs(recipe.inputs) do
				inputs[#inputs + 1] = { item = input.item, need = input.count, have = have(containers, input.item) }
			end
			if allowedSet == nil or allowedSet[recipe.id] then
				out[#out + 1] = {
					id = recipe.id, label = recipe.label, category = recipe.category,
					timeMs = recipe.timeMs, inputs = inputs, outputs = recipe.outputs
				}
			end
		end
		return out
	end

	function service.Busy(playerId)
		return busy[playerId] ~= nil
	end

	function service.Begin(playerId, benchType, recipeId, context)
		if busy[playerId] then
			return nil, 'craft_busy'
		end
		local _, containers, recipe, errorCode = resolve(playerId, benchType, recipeId, context)
		if not recipe then
			return nil, errorCode
		end
		if lacking(containers, recipe) then
			return nil, 'missing_items'
		end
		busy[playerId] = { bench = benchType, recipe = recipe, context = context }
		return recipe
	end

	function service.Cancel(playerId)
		busy[playerId] = nil
	end

	service.Drop = service.Cancel

	local function rollback(removed, added)
		for _, done in ipairs(added) do
			inventory.remove(done.container, done.item, done.count)
		end
		for _, done in ipairs(removed) do
			inventory.add(done.container, done.item, done.count)
		end
	end

	-- A reserva é consumida mesmo em falha: o cliente precisa iniciar de novo.
	function service.Complete(playerId)
		local job = busy[playerId]
		busy[playerId] = nil
		if not job then
			return nil, 'no_craft_in_progress'
		end
		local bench, containers, recipe, errorCode = resolve(playerId, job.bench, job.recipe.id, job.context)
		if not recipe then
			return nil, errorCode
		end
		if lacking(containers, recipe) then
			return nil, 'missing_items'
		end
		local removed, added = {}, {}
		for _, input in ipairs(recipe.inputs) do
			local left = input.count
			for _, container in ipairs(containers) do
				if left == 0 then
					break
				end
				local take = math.min(left, inventory.count(container, input.item) or 0)
				if take > 0 then
					local ok = inventory.remove(container, input.item, take)
					if not ok then
						rollback(removed, added)
						return nil, 'remove_failed'
					end
					removed[#removed + 1] = { container = container, item = input.item, count = take }
					left = left - take
				end
			end
			if left > 0 then
				rollback(removed, added)
				return nil, 'remove_failed'
			end
		end
		local target = destination(bench, job.context)
		for _, output in ipairs(recipe.outputs) do
			local ok, addError = inventory.add(target, output.item, output.count)
			if not ok then
				rollback(removed, added)
				return nil, addError == 'inventory_full' and 'inventory_full' or 'add_failed'
			end
			added[#added + 1] = { container = target, item = output.item, count = output.count }
		end
		audit('craft_completed', { player_id = playerId, operation = job.bench, item = recipe.id, result = 'ok' })
		return recipe
	end

	return service
end
