dofile('../coe_garages/config.lua')
dofile('../coe_garages/server/registry.lua')

local function eq(a, b, m)
	if a ~= b then error(('%s: esperado %s, veio %s'):format(m, tostring(b), tostring(a)), 2) end
end

local config = GaragesConfig
local function spot(id) return { id = id, x = 10.0, y = 20.0, z = 30.0, heading = 90.0 } end
local function base(extra)
	local g = { id = 'central', kind = 'public', label = 'Garagem Central', spots = { spot('a') } }
	for k, v in pairs(extra or {}) do g[k] = v end
	return g
end

local ok = GaragesRegistry.Normalize(base(), config)
eq(ok.kind, 'public', 'pública válida')
eq(ok.blip.enabled, true, 'pública tem blip por padrão')
eq(ok.blip.sprite, 357, 'sprite padrão')
eq(ok.spots[1].radius, 3.0, 'raio padrão')
eq(ok.enabled, true, 'ativa por padrão')

local g = GaragesRegistry.Normalize(base({ kind = 'job', jobs = { 'police' } }), config)
eq(g.blip.enabled, false, 'corporação sem blip por padrão')
eq(g.jobs[1], 'police', 'job')

local _, e = GaragesRegistry.Normalize(base({ kind = 'job' }), config)
eq(e, 'invalid_jobs', 'corporação exige jobs')
_, e = GaragesRegistry.Normalize(base({ kind = 'business' }), config)
eq(e, 'invalid_business', 'negócio exige businessId')
g = GaragesRegistry.Normalize(base({ kind = 'business', businessId = 'bennys' }), config)
eq(g.businessId, 'bennys', 'negócio válido')
_, e = GaragesRegistry.Normalize(base({ kind = 'casa' }), config)
eq(e, 'invalid_kind', 'tipo inválido')
_, e = GaragesRegistry.Normalize(base({ id = 'A B' }), config)
eq(e, 'invalid_id', 'id inválido')
_, e = GaragesRegistry.Normalize(base({ label = '<b>' }), config)
eq(e, 'invalid_label', 'rótulo inválido')
_, e = GaragesRegistry.Normalize(base({ spots = {} }), config)
eq(e, 'invalid_spots', 'sem vagas')
_, e = GaragesRegistry.Normalize(base({ spots = { spot('a'), spot('a') } }), config)
eq(e, 'invalid_spots', 'vaga repetida')
_, e = GaragesRegistry.Normalize(base({ blip = { sprite = 5000 } }), config)
eq(e, 'invalid_blip', 'blip inválido')
g = GaragesRegistry.Normalize(base({ blip = { enabled = false } }), config)
eq(g.blip.enabled, false, 'blip desligável')

print('registry_test ok')
