VehicleCatalog = {}

local MODEL_PATTERN = '^[%w_]+$'
local MAX_MODEL_LENGTH = 48
local CATEGORY_PATTERN = '^[%l%d_]+$'
local MAX_PRICE = 1000000000

local function integerInRange(value, minimum, maximum)
	return math.type(value) == 'integer' and value >= minimum and value <= maximum
end

-- Valida e normaliza os campos de override; só estes campos são aceitos.
function VehicleCatalog.NormalizeOverride(fields)
	if type(fields) ~= 'table' then
		return nil, 'invalid_override'
	end
	local result = {}
	for key, value in pairs(fields) do
		if key == 'price' then
			if not integerInRange(value, 0, MAX_PRICE) then
				return nil, 'invalid_price'
			end
		elseif key == 'stock' then
			if not integerInRange(value, 0, 1000000) then
				return nil, 'invalid_stock'
			end
		elseif key == 'category' then
			if type(value) ~= 'string' or #value > 32 or not value:match(CATEGORY_PATTERN) then
				return nil, 'invalid_category'
			end
		elseif key == 'hidden' then
			if type(value) ~= 'boolean' then
				return nil, 'invalid_hidden'
			end
		else
			return nil, 'unknown_override_field'
		end
		result[key] = value
	end
	return result
end

function VehicleCatalog.New(deps)
	local config = deps.config
	local seed = deps.seed or {}

	local catalog = {}
	local entries = {}
	local handlings = {}
	local issues = {}
	local overrides = {}
	local sources = {}

	local function addIssue(level, code, model, resource)
		issues[#issues + 1] = { level = level, code = code, model = model, resource = resource }
	end

	local function priceOf(entry, override)
		if override and override.price ~= nil then
			return override.price
		end
		return config.PriceByClass[entry.class] or config.DefaultPrice
	end

	local function view(entry)
		local override = overrides[entry.model]
		return {
			model = entry.model,
			name = entry.name,
			brand = entry.brand,
			class = entry.class,
			type = entry.type,
			seats = entry.seats,
			isAddon = entry.isAddon,
			resource = entry.resource,
			handlingId = entry.handlingId,
			hasHandling = entry.handlingId ~= nil and handlings[entry.handlingId] ~= nil,
			price = priceOf(entry, override),
			stock = override and override.stock or nil,
			category = override and override.category or entry.class,
			hidden = override and override.hidden == true or false
		}
	end

	-- sources: lista de { resource, vehicles = ParseVehicles(), handlings = ParseHandling() }.
	function catalog.Rebuild(newSources)
		entries, handlings, issues, sources = {}, {}, {}, newSources or {}

		for _, row in ipairs(seed) do
			entries[row[1]] = {
				model = row[1], name = row[2], brand = row[3], class = row[4],
				type = row[5], seats = row[6], isAddon = false
			}
		end

		for _, source in ipairs(sources) do
			for _, problem in ipairs(source.problems or {}) do
				addIssue('warn', problem, nil, source.resource)
			end
			for _, handling in ipairs(source.handlings or {}) do
				if handlings[handling.name] then
					addIssue('warn', 'duplicate_handling', handling.name, source.resource)
				else
					handlings[handling.name] = { resource = source.resource, values = handling.values }
				end
			end
		end

		for _, source in ipairs(sources) do
			for _, vehicle in ipairs(source.vehicles or {}) do
				local model = vehicle.model
				if #model > MAX_MODEL_LENGTH or not model:match(MODEL_PATTERN) then
					addIssue('error', 'invalid_model_name', model, source.resource)
				elseif entries[model] and entries[model].isAddon then
					addIssue('error', 'duplicate_model', model, source.resource)
				else
					if entries[model] then
						addIssue('warn', 'replaces_native', model, source.resource)
					end
					local previous = entries[model]
					if not vehicle.type then
						addIssue('warn', 'unknown_vehicle_type', model, source.resource)
					end
					if not handlings[vehicle.handlingId] then
						addIssue('warn', 'handling_missing', model, source.resource)
					end
					entries[model] = {
						model = model,
						name = vehicle.gameName or (previous and previous.name) or model,
						brand = vehicle.brand or (previous and previous.brand),
						class = previous and previous.class or 'unknown',
						type = vehicle.type or (previous and previous.type) or 'automobile',
						seats = previous and previous.seats,
						isAddon = true,
						resource = source.resource,
						handlingId = vehicle.handlingId
					}
				end
			end
		end
		return true
	end

	function catalog.SetOverrides(map)
		overrides = map or {}
	end

	function catalog.GetOverride(model)
		return overrides[model]
	end

	-- Mescla campos validados ao override do modelo; retorna o override resultante.
	function catalog.MergeOverride(model, fields)
		if type(model) ~= 'string' or not entries[model:lower()] then
			return nil, 'unknown_model'
		end
		model = model:lower()
		local normalized, errorCode = VehicleCatalog.NormalizeOverride(fields)
		if not normalized then
			return nil, errorCode
		end
		local merged = {}
		for key, value in pairs(overrides[model] or {}) do
			merged[key] = value
		end
		for key, value in pairs(normalized) do
			merged[key] = value
		end
		overrides[model] = merged
		return merged, model
	end

	function catalog.RemoveOverride(model)
		if type(model) ~= 'string' or not entries[model:lower()] then
			return nil, 'unknown_model'
		end
		overrides[model:lower()] = nil
		return true
	end

	-- Desfaz uma alteração cuja gravação falhou.
	function catalog.RestoreOverride(model, previous)
		overrides[model] = previous
	end

	function catalog.GetVehicleInfo(model)
		if type(model) ~= 'string' then
			return nil
		end
		local entry = entries[model:lower()]
		return entry and view(entry) or nil
	end

	function catalog.GetBaseHandling(model)
		local entry = type(model) == 'string' and entries[model:lower()] or nil
		local handling = entry and entry.handlingId and handlings[entry.handlingId]
		if not handling then
			return nil
		end
		local copy = {}
		for key, value in pairs(handling.values) do
			copy[key] = value
		end
		return copy
	end

	function catalog.List(filter)
		filter = type(filter) == 'table' and filter or {}
		local limit = math.type(filter.limit) == 'integer' and filter.limit or config.ListDefaultLimit
		limit = math.max(1, math.min(limit, config.ListMaxLimit))
		local search = type(filter.search) == 'string' and filter.search:lower() or nil
		local brand = type(filter.brand) == 'string' and filter.brand:lower() or nil

		local models = {}
		for model in pairs(entries) do
			models[#models + 1] = model
		end
		table.sort(models)

		local result = {}
		for _, model in ipairs(models) do
			local info = view(entries[model])
			local match = (filter.includeHidden == true or not info.hidden)
				and (filter.type == nil or info.type == filter.type)
				and (filter.class == nil or info.class == filter.class)
				and (filter.category == nil or info.category == filter.category)
				and (filter.addon == nil or info.isAddon == filter.addon)
				and (brand == nil or (info.brand or ''):lower() == brand)
				and (type(filter.minPrice) ~= 'number' or info.price >= filter.minPrice)
				and (type(filter.maxPrice) ~= 'number' or info.price <= filter.maxPrice)
				and (search == nil
					or model:find(search, 1, true)
					or (info.name or ''):lower():find(search, 1, true)
					or (info.brand or ''):lower():find(search, 1, true))
			if match then
				result[#result + 1] = info
				if #result >= limit then
					break
				end
			end
		end
		return result
	end

	function catalog.Issues()
		local copy = {}
		for index, issue in ipairs(issues) do
			copy[index] = { level = issue.level, code = issue.code, model = issue.model, resource = issue.resource }
		end
		return copy
	end

	function catalog.Count()
		local total = 0
		for _ in pairs(entries) do
			total = total + 1
		end
		return total
	end

	return catalog
end
