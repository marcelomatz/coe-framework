CraftingBusiness = {}

-- Quem opera é decidido pelo coe_businesses (Access): dono ou funcionário cadastrado naquele negócio, de ponto.

local function nearestStashId(stashes, station)
	local best, bestDistance = nil, math.huge
	for _, stash in ipairs(stashes or {}) do
		if type(stash.id) == 'string' and tonumber(stash.x) and tonumber(stash.y) and tonumber(stash.z) then
			local dx, dy, dz = stash.x - station.x, stash.y - station.y, stash.z - station.z
			local distance = dx * dx + dy * dy + dz * dz
			if distance < bestDistance then
				best, bestDistance = stash.id, distance
			end
		end
	end
	return best or station.id
end

-- Estações de craft de um negócio que tem bancada configurada para a categoria.
function CraftingBusiness.Stations(business, benches)
	local out = {}
	if type(business) ~= 'table' or business.enabled == false or not benches[business.category] then
		return out
	end
	local stations = type(business.stations) == 'table' and business.stations.crafts or nil
	for _, station in ipairs(stations or {}) do
		if type(station.id) == 'string' and tonumber(station.x) and tonumber(station.y) and tonumber(station.z) then
			out[#out + 1] = {
				kind = 'business', businessId = business.id, id = station.id, label = station.label,
				x = station.x + 0.0, y = station.y + 0.0, z = station.z + 0.0, radius = tonumber(station.radius) or 1.5
			}
		end
	end
	return out
end

function CraftingBusiness.StashId(businessId, stationId)
	return ('stash:business:%s:%s'):format(businessId, stationId)
end

-- Baú usado pela bancada: o baú do negócio (estação stashes) mais próximo dela, o mesmo que a equipe abre no local.
-- Sem baú cadastrado, cai no baú próprio da estação de craft.
function CraftingBusiness.StashFor(business, station)
	local stashes = type(business.stations) == 'table' and business.stations.stashes or nil
	return CraftingBusiness.StashId(business.id, nearestStashId(stashes, station))
end

-- Estações de craft e baús de uma facção ativa (coe_factions).
function CraftingBusiness.FactionStations(faction)
	local out = {}
	if type(faction) ~= 'table' or faction.enabled == false then
		return out
	end
	local stations = type(faction.stations) == 'table' and faction.stations or {}
	for _, station in ipairs(stations.crafts or {}) do
		if type(station.id) == 'string' and tonumber(station.x) and tonumber(station.y) and tonumber(station.z) then
			out[#out + 1] = {
				kind = 'faction', factionId = faction.id, factionLabel = faction.label, id = station.id, label = station.label,
				x = station.x + 0.0, y = station.y + 0.0, z = station.z + 0.0, radius = tonumber(station.radius) or 1.5
			}
		end
	end
	for _, station in ipairs(stations.stashes or {}) do
		if type(station.id) == 'string' and tonumber(station.x) and tonumber(station.y) and tonumber(station.z) then
			out[#out + 1] = {
				kind = 'faction_stash', factionId = faction.id, factionLabel = faction.label, id = station.id, label = station.label,
				x = station.x + 0.0, y = station.y + 0.0, z = station.z + 0.0, radius = tonumber(station.radius) or 1.5,
				slots = tonumber(station.slots) or 50, maxWeight = tonumber(station.maxWeight) or 100000
			}
		end
	end
	return out
end

function CraftingBusiness.FactionStashId(factionId, stationId)
	return ('stash:faction:%s:%s'):format(factionId, stationId)
end

function CraftingBusiness.FactionStashFor(faction, station)
	local stashes = type(faction.stations) == 'table' and faction.stations.stashes or nil
	return CraftingBusiness.FactionStashId(faction.id, nearestStashId(stashes, station))
end

-- Bancadas clandestinas livres cadastradas no catálogo.
function CraftingBusiness.IllegalStations(benches)
	local out = {}
	for _, bench in ipairs(benches or {}) do
		if type(bench) == 'table' and bench.enabled ~= false and type(bench.id) == 'string'
			and tonumber(bench.x) and tonumber(bench.y) and tonumber(bench.z) then
			out[#out + 1] = {
				kind = 'illegal', id = bench.id, label = bench.label,
				x = bench.x + 0.0, y = bench.y + 0.0, z = bench.z + 0.0, radius = tonumber(bench.radius) or 1.5
			}
		end
	end
	return out
end
