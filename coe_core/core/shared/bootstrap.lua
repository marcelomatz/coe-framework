if not CoeAlgorithms then
	if type(LoadResourceFile) == 'function' then
		local src = LoadResourceFile('coe_core', 'lib/algorithms/init.lua')
		if type(src) == 'string' and src ~= '' then
			local fn = load(src, '@@coe_core/lib/algorithms/init.lua', 't', _G)
			if fn then
				pcall(fn)
			end
		end
	elseif type(io) == 'table' and type(io.open) == 'function' then
		local candidates = {
			'lib/algorithms/init.lua',
			'../coe_core/lib/algorithms/init.lua',
			'../../coe-framework/coe_core/lib/algorithms/init.lua'
		}
		for i = 1, #candidates do
			local f = io.open(candidates[i], 'r')
			if f then
				f:close()
				pcall(dofile, candidates[i])
				break
			end
		end
	end
end

Core = {
	Name = 'coe_core',
	Prefix = 'coe_core',
	Version = '0.1.0',
	Functions = {},
	Classes = {
		Registry = {}
	},
	Events = {},
	States = {},
	Database = {},
	Identity = {},
	Players = {},
	Groups = {},
	SessionRegistry = {},
	Repositories = {},
	Platform = CoePlatform or {},
	Locale = CoeLocale or {},
	SemVer = CoeSemVer or {},
	Zones = CoeZones or {},
	Algorithms = CoeAlgorithms or {}
}
