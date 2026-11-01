-- App `vehicles` do COE OS (coe_tablet): os veículos do personagem, onde estão e a quilometragem. Só leitura;
-- retirar e guardar continuam na vaga da garagem.
GaragesTablet = {}

local function fail(code)
	return { ok = false, error = code }
end

function GaragesTablet.Call(deps, playerId, appId, action)
	local caller = deps.caller and deps.caller() or ''
	if caller ~= 'coe_tablet' or appId ~= 'vehicles' then
		return fail('forbidden')
	end
	if deps.ready and not deps.ready() then
		return fail('not_ready')
	end
	if action ~= 'list' then
		return fail('unknown_action')
	end
	local characterId = deps.characterOf and deps.characterOf(tonumber(playerId)) or nil
	if not characterId then
		return fail('no_character')
	end
	local owned = deps.ownedVehicles and deps.ownedVehicles(characterId) or nil
	local slots = deps.slotsOf and deps.slotsOf(characterId) or {}
	local list = {}
	for _, record in ipairs(type(owned) == 'table' and owned or {}) do
		local view = deps.vehicleView(record)
		view.km = math.floor((tonumber(record.mileage) or 0) / 1000)
		if record.state == 'stored' then
			local garageId = slots[tostring(record.id)]
			local garage = garageId and deps.garage and deps.garage(garageId) or nil
			local spot = garage and garage.spots and garage.spots[1] or nil
			view.where = garage and garage.label or 'Qualquer garagem pública'
			if spot then
				view.x, view.y = spot.x, spot.y
			end
		elseif record.state == 'out' then
			local at = deps.entityCoords and deps.entityCoords(record.id) or nil
			if at then
				view.x, view.y = at.x, at.y
			end
		end
		list[#list + 1] = view
	end
	table.sort(list, function(a, b) return tostring(a.name) < tostring(b.name) end)
	return { ok = true, vehicles = list }
end
