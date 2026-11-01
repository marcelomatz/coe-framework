MechanicAppearance = {}

local function isInt(value, minimum, maximum)
	return type(value) == 'number' and value % 1 == 0 and value >= minimum and value <= maximum
end

local function rgbOf(value, limits)
	if type(value) ~= 'table' then
		return nil
	end
	local r, g, b = value[1] or value.r, value[2] or value.g, value[3] or value.b
	if isInt(r, 0, 255) and isInt(g, 0, 255) and isInt(b, 0, 255) then
		return { r, g, b }
	end
	return nil
end

local COLOR_KEYS = { 'primary', 'secondary', 'pearl', 'wheel', 'interior', 'dashboard' }
local TOGGLE_KEYS = { 'turbo', 'tyreSmoke', 'xenon' }

-- Aceita só campos conhecidos e valores dentro dos limites; o resto é descartado. Retorna (limpo, erro).
function MechanicAppearance.Sanitize(config, input)
	if type(input) ~= 'table' then
		return nil, 'invalid_appearance'
	end
	local limits = config.Appearance
	local clean = {}

	if type(input.colors) == 'table' then
		local colors = {}
		for _, key in ipairs(COLOR_KEYS) do
			local value = input.colors[key]
			if value ~= nil then
				if not isInt(value, 0, limits.MaxColorIndex) then
					return nil, 'invalid_color'
				end
				colors[key] = value
			end
		end
		for _, key in ipairs({ 'primaryRgb', 'secondaryRgb' }) do
			if input.colors[key] ~= nil then
				local rgb = rgbOf(input.colors[key])
				if not rgb then
					return nil, 'invalid_color'
				end
				colors[key] = rgb
			end
		end
		clean.colors = colors
	end

	if type(input.mods) == 'table' then
		local mods = {}
		for key, value in pairs(input.mods) do
			local modType = tonumber(key)
			if not modType or not isInt(modType, 0, limits.MaxModType) or limits.BlockedModTypes[modType] then
				return nil, 'invalid_mod'
			end
			if not isInt(value, -1, limits.MaxModIndex) then
				return nil, 'invalid_mod'
			end
			mods[tostring(modType)] = value
		end
		clean.mods = mods
	end

	if type(input.toggles) == 'table' then
		local toggles = {}
		for _, key in ipairs(TOGGLE_KEYS) do
			local value = input.toggles[key]
			if value ~= nil then
				if type(value) ~= 'boolean' then
					return nil, 'invalid_toggle'
				end
				toggles[key] = value
			end
		end
		clean.toggles = toggles
	end

	local scalars = {
		{ 'livery', -1, limits.MaxLivery },
		{ 'tint', 0, limits.MaxTint },
		{ 'plateIndex', 0, limits.MaxPlateIndex },
		{ 'wheelType', 0, limits.MaxWheelType },
		{ 'xenonColor', -1, limits.MaxXenonColor }
	}
	for _, scalar in ipairs(scalars) do
		local value = input[scalar[1]]
		if value ~= nil then
			if not isInt(value, scalar[2], scalar[3]) then
				return nil, 'invalid_' .. scalar[1]
			end
			clean[scalar[1]] = value
		end
	end

	if type(input.neon) == 'table' then
		local neon = {}
		if input.neon.sides ~= nil then
			if type(input.neon.sides) ~= 'table' then
				return nil, 'invalid_neon'
			end
			neon.sides = {}
			for index = 1, 4 do
				neon.sides[index] = input.neon.sides[index] == true
			end
		end
		if input.neon.rgb ~= nil then
			neon.rgb = rgbOf(input.neon.rgb)
			if not neon.rgb then
				return nil, 'invalid_neon'
			end
		end
		clean.neon = neon
	end

	if type(input.extras) == 'table' then
		local extras = {}
		for key, value in pairs(input.extras) do
			local id = tonumber(key)
			if not id or not isInt(id, 0, limits.MaxExtra) or type(value) ~= 'boolean' then
				return nil, 'invalid_extra'
			end
			extras[tostring(id)] = value
		end
		clean.extras = extras
	end

	return clean
end

local MERGED = { 'colors', 'mods', 'toggles', 'neon', 'extras' }

-- Aplica `patch` sobre `current`: tabelas internas são mescladas, escalares substituem.
function MechanicAppearance.Merge(current, patch)
	local result = {}
	for key, value in pairs(current or {}) do
		result[key] = value
	end
	for key, value in pairs(patch or {}) do
		result[key] = value
	end
	for _, key in ipairs(MERGED) do
		local base, over = (current or {})[key], (patch or {})[key]
		if type(base) == 'table' and type(over) == 'table' then
			local combined = {}
			for innerKey, innerValue in pairs(base) do
				combined[innerKey] = innerValue
			end
			for innerKey, innerValue in pairs(over) do
				combined[innerKey] = innerValue
			end
			result[key] = combined
		end
	end
	return result
end

local function same(a, b)
	if type(a) ~= type(b) then
		return false
	end
	if type(a) ~= 'table' then
		return a == b
	end
	for key, value in pairs(a) do
		if not same(value, b[key]) then
			return false
		end
	end
	for key in pairs(b) do
		if a[key] == nil then
			return false
		end
	end
	return true
end

-- Orçamento do que mudou entre `current` e `target`. O preço é proporcional ao valor do veículo.
-- Retornar a "sem item" (-1/false) é grátis.
function MechanicAppearance.Quote(config, current, target, vehiclePrice, class)
	local pricing = config.Pricing
	local base = type(vehiclePrice) == 'number' and vehiclePrice > 0 and vehiclePrice or pricing.DefaultVehiclePrice
	local multiplier = pricing.ClassMultipliers[class] or 1
	current = current or {}
	local lines, total = {}, 0

	local function add(kind, key, fraction, steps)
		local price = math.max(pricing.MinPrice, math.floor(base * fraction * (1 + (steps or 0) * pricing.IndexStep) * multiplier))
		lines[#lines + 1] = { kind = kind, key = key, price = price }
		total = total + price
	end

	for key, value in pairs(target.mods or {}) do
		local before = (current.mods or {})[key]
		if value ~= before and value >= 0 and not (before == nil and value == -1) then
			add('mod', key, pricing.ModFractionByType[tonumber(key)] or pricing.ModFraction, value)
		end
	end
	for key, value in pairs(target.colors or {}) do
		if not same(value, (current.colors or {})[key]) then
			local fraction = pricing.ColorFraction
			if key == 'primaryRgb' or key == 'secondaryRgb' then
				fraction = pricing.RgbFraction
			elseif key == 'pearl' then
				fraction = pricing.PearlFraction
			end
			add('color', key, fraction)
		end
	end
	for key, value in pairs(target.toggles or {}) do
		if value == true and (current.toggles or {})[key] ~= true then
			add('toggle', key, pricing.ToggleFraction)
		end
	end
	if target.livery ~= nil and target.livery >= 0 and target.livery ~= current.livery then
		add('livery', 'livery', pricing.LiveryFraction)
	end
	for _, key in ipairs({ 'tint', 'plateIndex', 'wheelType', 'xenonColor' }) do
		if target[key] ~= nil and target[key] >= 0 and target[key] ~= current[key] then
			add('scalar', key, pricing.MinorFraction)
		end
	end
	if target.neon and not same(target.neon, current.neon) then
		add('neon', 'neon', pricing.NeonFraction)
	end
	table.sort(lines, function(a, b)
		return a.kind .. a.key < b.kind .. b.key
	end)
	return { total = total, lines = lines }
end
