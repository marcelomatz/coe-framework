CraftingRules = {}

local function ident(value)
	return type(value) == 'string' and #value >= 2 and #value <= 48 and value:match('^[%w_]+$') ~= nil
end

local function count(value, config)
	return math.type(value) == 'integer' and value >= 1 and value <= config.MaxCount
end

local function stacks(list, max, config)
	if type(list) ~= 'table' or #list < 1 or #list > max then
		return false
	end
	local seen = {}
	for _, entry in ipairs(list) do
		if type(entry) ~= 'table' or not ident(entry.item) or seen[entry.item] or not count(entry.count, config) then
			return false
		end
		seen[entry.item] = true
	end
	return true
end

function CraftingRules.Identifier(value)
	return ident(value)
end

-- Valida e normaliza uma receita. Retorna cópia limpa ou nil, código.
function CraftingRules.Recipe(recipe, config)
	if type(recipe) ~= 'table' or not ident(recipe.id) then
		return nil, 'invalid_recipe_id'
	end
	if type(recipe.label) ~= 'string' or recipe.label == '' or #recipe.label > 64 then
		return nil, 'invalid_recipe_label'
	end
	if not ident(recipe.category) then
		return nil, 'invalid_recipe_category'
	end
	if math.type(recipe.timeMs) ~= 'integer' or recipe.timeMs < config.MinTimeMs or recipe.timeMs > config.MaxTimeMs then
		return nil, 'invalid_recipe_time'
	end
	if not stacks(recipe.inputs, config.MaxInputs, config) then
		return nil, 'invalid_recipe_inputs'
	end
	if not stacks(recipe.outputs, config.MaxOutputs, config) then
		return nil, 'invalid_recipe_outputs'
	end
	local clean = { id = recipe.id, label = recipe.label, category = recipe.category, timeMs = recipe.timeMs, inputs = {}, outputs = {} }
	for _, entry in ipairs(recipe.inputs) do
		clean.inputs[#clean.inputs + 1] = { item = entry.item, count = entry.count }
	end
	for _, entry in ipairs(recipe.outputs) do
		clean.outputs[#clean.outputs + 1] = { item = entry.item, count = entry.count }
	end
	return clean
end

-- Valida o tipo de bancada: quais categorias de receita ela aceita e de onde vêm os insumos.
function CraftingRules.Bench(def, config)
	if type(def) ~= 'table' then
		return nil, 'invalid_bench'
	end
	if type(def.label) ~= 'string' or def.label == '' or #def.label > 64 then
		return nil, 'invalid_bench_label'
	end
	local source = def.source or 'player'
	if not config.Sources[source] then
		return nil, 'invalid_bench_source'
	end
	local output = def.output or 'player'
	if output ~= 'player' and output ~= 'stash' then
		return nil, 'invalid_bench_output'
	end
	if type(def.categories) ~= 'table' or #def.categories == 0 then
		return nil, 'invalid_bench_categories'
	end
	local categories = {}
	for _, category in ipairs(def.categories) do
		if not ident(category) then
			return nil, 'invalid_bench_categories'
		end
		categories[#categories + 1] = category
	end
	local animation
	if def.animation ~= nil then
		local a = def.animation
		if type(a) ~= 'table' or type(a.dict) ~= 'string' or type(a.name) ~= 'string' or #a.dict > 64 or #a.name > 64 then
			return nil, 'invalid_bench_animation'
		end
		animation = { dict = a.dict, name = a.name }
	end
	return { label = def.label, source = source, output = output, categories = categories, animation = animation }
end
