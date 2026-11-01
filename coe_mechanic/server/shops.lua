MechanicShops = {}

local function station(raw)
	return { id = raw.id, label = raw.label, point = { x = raw.x, y = raw.y, z = raw.z, radius = raw.radius } }
end

-- Converte um negócio da categoria "mechanic" (coe_businesses) na oficina usada pelo resto do resource.
function MechanicShops.FromBusiness(business, config)
	local stations = business.stations or {}
	local rules = business.rules or {}
	local center = BusinessArea.Center(business.area)
	local showroom = stations.showroom or { x = center.x, y = center.y, z = center.z, radius = 5.0 }
	local shop = {
		label = business.label,
		owner = business.owner,
		ownerAccess = rules.ownerAccess ~= false,
		clockRequired = rules.clockRequired ~= false,
		priceMultiplier = rules.priceMultiplier or 1.0,
		area = business.area,
		showroom = { x = showroom.x, y = showroom.y, z = showroom.z, radius = showroom.radius },
		blip = config.ShopBlip,
		crafts = {},
		stashes = {},
		clocks = {}
	}
	for _, raw in ipairs(stations.clocks or {}) do
		shop.clocks[#shop.clocks + 1] = station(raw)
	end
	for _, raw in ipairs(stations.crafts or {}) do
		shop.crafts[#shop.crafts + 1] = station(raw)
	end
	for _, raw in ipairs(stations.stashes or {}) do
		local stash = station(raw)
		stash.slots, stash.maxWeight = raw.slots, raw.maxWeight
		shop.stashes[#shop.stashes + 1] = stash
	end
	return shop
end

-- Troca o conteúdo de `target` (a tabela viva config.Shops) pelas oficinas dos negócios ativos.
function MechanicShops.Apply(target, businesses, config)
	for id in pairs(target) do
		target[id] = nil
	end
	for _, business in ipairs(businesses) do
		if business.category == 'mechanic' and business.enabled then
			target[business.id] = MechanicShops.FromBusiness(business, config)
		end
	end
end

-- Encontra a estação pelo id dentro da lista de uma oficina.
function MechanicShops.Station(shop, kind, stationId)
	for _, entry in ipairs(shop and shop[kind] or {}) do
		if entry.id == stationId then
			return entry
		end
	end
end
