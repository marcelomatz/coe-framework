local function copyValue(value, seen)
	if type(value) ~= 'table' then
		return value
	end

	if seen[value] then
		return seen[value]
	end

	local copy = {}
	seen[value] = copy

	for key, entry in pairs(value) do
		copy[copyValue(key, seen)] = copyValue(entry, seen)
	end

	return copy
end

function Core.Functions.DeepCopy(value)
	return copyValue(value, {})
end

function Core.Functions.IsInteger(value)
	return type(value) == 'number'
		and value == value
		and value ~= math.huge
		and value ~= -math.huge
		and value % 1 == 0
end

function Core.Functions.IsValidName(value, maxLength)
	return type(value) == 'string'
		and #value > 0
		and #value <= (maxLength or 100)
		and value:match('^[%w_.%-]+$') ~= nil
end

function Core.Functions.Trim(value)
	if type(value) ~= 'string' then
		return nil
	end

	return (value:gsub('^%s*(.-)%s*$', '%1'))
end
