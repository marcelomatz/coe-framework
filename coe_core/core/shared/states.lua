local function getStateKey(name)
	if not Core.Functions.IsValidName(name) then
		return nil, 'invalid_state_name'
	end

	return Core.Prefix .. ':' .. name
end

function Core.States.Get(name)
	local stateKey, errorMessage = getStateKey(name)
	if not stateKey then
		return nil, errorMessage
	end

	return GlobalState[stateKey]
end

function Core.States.Set(name, value)
	if not IsDuplicityVersion() then
		return false, 'server_only'
	end

	local stateKey, errorMessage = getStateKey(name)
	if not stateKey then
		return false, errorMessage
	end

	local ok = pcall(function()
		GlobalState[stateKey] = value
	end)
	if not ok then
		return false, 'state_set_failed'
	end

	return true
end

function Core.States.OnChange(name, callback)
	local stateKey, errorMessage = getStateKey(name)
	if not stateKey then
		return nil, errorMessage
	end
	if type(callback) ~= 'function' then
		return nil, 'invalid_callback'
	end
	if type(AddStateBagChangeHandler) ~= 'function' then
		return nil, 'state_bags_unavailable'
	end

	return AddStateBagChangeHandler(stateKey, 'global', function(_, _, value, _, replicated)
		callback(value, replicated)
	end)
end

function Core.States.RemoveChangeHandler(handlerId)
	if type(handlerId) ~= 'number' or type(RemoveStateBagChangeHandler) ~= 'function' then
		return false
	end

	RemoveStateBagChangeHandler(handlerId)
	return true
end
