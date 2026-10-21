Core = exports['coe_core']:GetCoreObject()

-- Garante que a camada de plataforma (Platform / HAL) execute SEMPRE localmente
-- no resource para evitar RPC IPC desnecessário e preservar objetos tipados
local okPlatform, platformMod = pcall(function()
	if type(CoePlatform) == 'table' then
		return CoePlatform
	end
	if type(LoadResourceFile) == 'function' then
		local content = LoadResourceFile('coe_core', 'lib/platform.lua')
		if content then
			local fn = load(content, '@coe_core/lib/platform.lua')
			if fn then return fn() end
		end
	end
	return dofile('lib/platform.lua')
end)
if okPlatform and type(platformMod) == 'table' then
	Core.Platform = platformMod
end

-- Garante que o subsistema de internacionalização (Locale / i18n) execute SEMPRE localmente
-- no resource para preservar metatables (__call), permitir instanciação local e zero-IPC
local okLocale, localeMod = pcall(function()
	if type(CoeLocale) == 'table' then
		return CoeLocale
	end
	if type(LoadResourceFile) == 'function' then
		local content = LoadResourceFile('coe_core', 'lib/locale.lua')
		if content then
			local fn = load(content, '@coe_core/lib/locale.lua')
			if fn then return fn() end
		end
	end
	return dofile('lib/locale.lua')
end)
if okLocale and type(localeMod) == 'table' then
	Core.Locale = localeMod
end

-- Funções recebidas via export executam no coe_core. Registrar handlers lá faria
-- `source` e o contexto do evento não pertencerem ao resource chamador, então
-- o registro de handlers é refeito localmente em cada resource consumidor.
local events = Core.Events
local prefix = Core.Prefix

local function eventName(name)
	if type(name) ~= 'string' or #name == 0 or #name > 100 or not name:match('^[%w_.%-]+$') then
		return nil, 'invalid_event_name'
	end
	return prefix .. ':' .. name
end

function events.On(name, callback)
	local resolved, errorMessage = eventName(name)
	if not resolved then
		return nil, errorMessage
	end
	if type(callback) ~= 'function' then
		return nil, 'invalid_callback'
	end

	return AddEventHandler(resolved, callback)
end

function events.OnNet(name, callback)
	local resolved, errorMessage = eventName(name)
	if not resolved then
		return nil, errorMessage
	end
	if type(callback) ~= 'function' then
		return nil, 'invalid_callback'
	end

	RegisterNetEvent(resolved)
	return AddEventHandler(resolved, callback)
end

function events.Remove(handlerId)
	if type(handlerId) ~= 'number' then
		return false
	end

	RemoveEventHandler(handlerId)
	return true
end

-- Classes também precisam nascer no resource consumidor: instâncias criadas dentro do coe_core
-- perdem a metatable (e portanto os métodos) ao voltar por export, e o registro seria compartilhado.
local classes = Core.Classes
local registry = {}
classes.Registry = registry

function classes.Register(name, parent)
	if type(name) ~= 'string' or #name == 0 or #name > 100 or not name:match('^[%w_.%-]+$') then
		return nil, 'invalid_class_name'
	end
	if registry[name] then
		return nil, 'class_already_registered'
	end

	if type(parent) == 'string' then
		local parentName = parent
		parent = registry[parentName]
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

	registry[name] = class
	return class
end

function classes.Get(name)
	return registry[name]
end

function classes.Is(instance, className)
	if type(instance) ~= 'table' then
		return false
	end

	local isInstance = instance.is
	return type(isInstance) == 'function' and isInstance(instance, className) or false
end
