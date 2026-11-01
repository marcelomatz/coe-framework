CraftingRegistry = {}

-- Guarda receitas e tipos de bancada. Cada receita e bancada pertence a quem registrou (owner, o nome do resource):
-- outro owner não substitui nem remove (id_conflict). Só o coe_admin (overrides do painel) pode substituir. Bancadas
-- business_*, faction e illegal são reservadas ao próprio coe_crafting.
local OVERRIDER, RESERVED_PREFIX, SELF = 'coe_admin', 'business_', 'coe_crafting'
local RESERVED_BENCHES = { faction = true, illegal = true }

local function mayWrite(existing, owner)
	return existing == nil or existing == owner or owner == OVERRIDER
end

function CraftingRegistry.New(config)
	local recipes, benches, order, owners, benchOwners = {}, {}, {}, {}, {}
	local registry = {}

	function registry.AddRecipe(recipe, owner)
		local clean, errorCode = CraftingRules.Recipe(recipe, config)
		if not clean then
			return nil, errorCode
		end
		local categoryOwner = config.CategoryOwners and config.CategoryOwners[clean.category]
		if categoryOwner and categoryOwner ~= owner and owner ~= OVERRIDER then
			return nil, 'category_forbidden'
		end
		if not mayWrite(owners[clean.id], owner) then
			return nil, 'id_conflict'
		end
		owners[clean.id] = owner
		if not recipes[clean.id] then
			order[#order + 1] = clean.id
		end
		recipes[clean.id] = clean
		return clean
	end

	function registry.RemoveRecipe(id, owner)
		if not recipes[id] or not mayWrite(owners[id], owner) then
			return false
		end
		recipes[id], owners[id] = nil, nil
		for index, value in ipairs(order) do
			if value == id then
				table.remove(order, index)
				break
			end
		end
		return true
	end

	function registry.AddBench(benchType, def, owner)
		if not CraftingRules.Identifier(benchType) then
			return nil, 'invalid_bench_type'
		end
		if (benchType:sub(1, #RESERVED_PREFIX) == RESERVED_PREFIX or RESERVED_BENCHES[benchType]) and owner ~= SELF then
			return nil, 'reserved_bench'
		end
		if not mayWrite(benchOwners[benchType], owner) then
			return nil, 'id_conflict'
		end
		local clean, errorCode = CraftingRules.Bench(def, config)
		if not clean then
			return nil, errorCode
		end
		benches[benchType], benchOwners[benchType] = clean, owner
		return clean
	end

	function registry.Bench(benchType)
		return benches[benchType]
	end

	function registry.Recipe(id)
		return recipes[id]
	end

	function registry.Owner(id)
		return owners[id]
	end

	-- Todas as receitas, na ordem de registro (catálogo do painel).
	function registry.All()
		local out = {}
		for _, id in ipairs(order) do
			out[#out + 1] = recipes[id]
		end
		return out
	end

	-- Receitas da bancada, na ordem de registro, filtradas pelas categorias aceitas.
	function registry.RecipesOf(benchType)
		local bench = benches[benchType]
		if not bench then
			return nil, 'bench_not_found'
		end
		local accepted = {}
		for _, category in ipairs(bench.categories) do
			accepted[category] = true
		end
		local out = {}
		for _, id in ipairs(order) do
			if accepted[recipes[id].category] then
				out[#out + 1] = recipes[id]
			end
		end
		return out
	end

	return registry
end
