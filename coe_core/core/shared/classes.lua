function Core.Classes.Register(name, parent)
	if not Core.Functions.IsValidName(name) then
		return nil, 'invalid_class_name'
	end

	if Core.Classes.Registry[name] then
		return nil, 'class_already_registered'
	end

	if type(parent) == 'string' then
		local parentName = parent
		parent = Core.Classes.Registry[parentName]
		if not parent then
			return nil, 'parent_class_not_found'
		end
	end

	if parent ~= nil and type(parent) ~= 'table' then
		return nil, 'invalid_parent_class'
	end

	local class = {
		__name = name
	}
	class.__index = class

	if parent then
		setmetatable(class, { __index = parent })
	end

	function class:new(...)
		local instance = setmetatable({}, self)
		if type(instance.init) == 'function' then
			instance:init(...)
		end
		return instance
	end

	function class:is(className)
		local current = getmetatable(self)
		while type(current) == 'table' do
			if current == className or current.__name == className then
				return true
			end

			local parentMetatable = getmetatable(current)
			current = parentMetatable and parentMetatable.__index or nil
		end

		return false
	end

	Core.Classes.Registry[name] = class
	return class
end

function Core.Classes.Get(name)
	return Core.Classes.Registry[name]
end

function Core.Classes.Is(instance, className)
	if type(instance) ~= 'table' then
		return false
	end

	local isInstance = instance.is
	return type(isInstance) == 'function' and isInstance(instance, className) or false
end
