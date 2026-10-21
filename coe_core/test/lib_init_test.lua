local registered = {}
local netRegistered = {}
local removed = {}

exports = {
	coe_core = {
		GetCoreObject = function()
			return {
				Prefix = 'coe_core',
				Classes = {
					Registry = {},
					Register = function()
						error('proxied Register must not be used')
					end
				},
				Events = {
					On = function()
						error('proxied On must not be used')
					end,
					OnNet = function()
						error('proxied OnNet must not be used')
					end
				}
			}
		end
	}
}

function AddEventHandler(name, callback)
	registered[#registered + 1] = { name = name, callback = callback }
	return #registered
end

function RegisterNetEvent(name)
	netRegistered[#netRegistered + 1] = name
end

function RemoveEventHandler(id)
	removed[#removed + 1] = id
end

setmetatable(exports.coe_core, {
	__call = function()
		return nil
	end
})
local originalExports = exports
exports = setmetatable({}, {
	__index = function(_, key)
		local resource = originalExports[key]
		return setmetatable({}, {
			__index = function(_, method)
				return function(_, ...)
					return resource[method](...)
				end
			end
		})
	end
})

dofile('lib/init.lua')

local handler = function() end
assert(Core.Events.On('a.b', handler) == 1)
assert(registered[1].name == 'coe_core:a.b' and registered[1].callback == handler)
assert(#netRegistered == 0)

assert(Core.Events.OnNet('x.y', handler) == 2)
assert(registered[2].name == 'coe_core:x.y')
assert(netRegistered[1] == 'coe_core:x.y')

local id, err = Core.Events.OnNet('bad name', handler)
assert(id == nil and err == 'invalid_event_name')
id, err = Core.Events.On('ok', 'not_a_function')
assert(id == nil and err == 'invalid_callback')

assert(Core.Events.Remove(2) == true and removed[1] == 2)
assert(Core.Events.Remove('x') == false)

local Base = assert(Core.Classes.Register('Base'))
function Base:init(value)
	self.value = value
end
function Base:double()
	return self.value * 2
end
local Child = assert(Core.Classes.Register('Child', 'Base'))
local instance = Child:new(21)
assert(instance:double() == 42, 'instances keep their methods')
assert(instance:is('Base') and Core.Classes.Is(instance, 'Child'))
assert(not Core.Classes.Is({}, 'Base'))
assert(Core.Classes.Get('Base') == Base)
local duplicate, duplicateError = Core.Classes.Register('Base')
assert(duplicate == nil and duplicateError == 'class_already_registered')
local missing, missingError = Core.Classes.Register('Other', 'Missing')
assert(missing == nil and missingError == 'parent_class_not_found')

print('lib init tests passed')
