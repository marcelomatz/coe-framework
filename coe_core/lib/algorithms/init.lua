-- Carregador preguiçoso (lazy-loader Zero-IPC) para @coe_core/lib/algorithms/.
-- Suporta execução local em qualquer resource no FXServer (via LoadResourceFile) e standalone em Lua 5.4 offline.
local MODULE_FILES = {
	Spatial     = 'spatial.lua',
	Sampling    = 'sampling.lua',
	Containers  = 'containers.lua',
	Graph       = 'graph.lua',
	Concurrency = 'concurrency.lua',
	RateLimit   = 'ratelimit.lua',
	Crypto      = 'crypto.lua',
	Anomaly     = 'anomaly.lua',
}

local loaded = {}

local function loadSubmodule(key)
	local fileName = MODULE_FILES[key]
	if not fileName then
		error(("[coe_core:algorithms] Submodulo desconhecido: '%s'"):format(tostring(key)), 3)
	end

	local relPath = 'lib/algorithms/' .. fileName
	if type(LoadResourceFile) == 'function' then
		local content = LoadResourceFile('coe_core', relPath)
		if content then
			local fn, err = load(content, '@coe_core/' .. relPath)
			if not fn then
				error(err, 3)
			end
			return fn()
		end
	end

	local modName = fileName:gsub('%.lua$', '')
	for _, reqPath in ipairs({
		'coe_core.lib.algorithms.' .. modName,
		'lib.algorithms.' .. modName,
		'@coe_core.lib.algorithms.' .. modName,
	}) do
		local ok, mod = pcall(require, reqPath)
		if ok and type(mod) == 'table' then
			return mod
		end
	end

	if type(io) == 'table' and type(io.open) == 'function' then
		for _, diskPath in ipairs({
			relPath,
			'../coe_core/' .. relPath,
			'../dev/coe_core/' .. relPath,
			'../../dev/coe_core/' .. relPath,
			'../../coe-framework/coe_core/' .. relPath,
		}) do
			local f = io.open(diskPath, 'r')
			if f then
				f:close()
				return dofile(diskPath)
			end
		end
	end

	error(("[coe_core:algorithms] Falha ao carregar submodulo '%s' (%s)"):format(tostring(key), relPath), 3)
end

local Algorithms = setmetatable({}, {
	__index = function(_, key)
		local mod = loaded[key]
		if mod then
			return mod
		end
		mod = loadSubmodule(key)
		loaded[key] = mod
		return mod
	end
})

CoeAlgorithms = Algorithms
if type(Core) == 'table' then
	Core.Algorithms = Algorithms
elseif type(IsDuplicityVersion) ~= 'function' then
	Core = { Algorithms = Algorithms }
end

return Algorithms
