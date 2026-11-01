MechanicOrders = {}

local OPEN = { requested = true, quoted = true, approved = true }

-- deps: config, now() em ms, quote(vehicleId, patch) -> {total, lines}|nil,erro,
-- apply(vehicleId, patch) -> true|erro, charge(source, amount, reason) -> true|erro (opcional),
-- audit(event, context).
function MechanicOrders.New(deps)
	local config = deps.config.Orders
	local audit = deps.audit or function() end
	local orders, nextId = {}, 0
	local service = {}

	local function summary(order)
		return {
			id = order.id,
			shop = order.shopId,
			plate = order.plate,
			model = order.model,
			status = order.status,
			estimate = order.estimate,
			total = order.total,
			note = order.note,
			patch = order.patch
		}
	end

	local function isExpired(order)
		return deps.now() - order.touchedAt > config.TtlMs
	end

	function service.Purge()
		for id, order in pairs(orders) do
			if OPEN[order.status] and isExpired(order) then
				order.status = 'expired'
			end
			if not OPEN[order.status] and deps.now() - order.touchedAt > config.TtlMs * 2 then
				orders[id] = nil
			end
		end
	end

	local function find(id)
		local order = orders[id]
		if order and OPEN[order.status] and isExpired(order) then
			order.status = 'expired'
		end
		return order
	end

	local function openFor(vehicleId)
		for _, order in pairs(orders) do
			if order.vehicleId == vehicleId and OPEN[order.status] and not isExpired(order) then
				return order
			end
		end
	end

	-- customer = { source, characterId }; vehicle = { id, plate, model }.
	function service.Create(shopId, customer, vehicle, patch)
		if openFor(vehicle.id) then
			return nil, 'order_already_open'
		end
		local count = 0
		for _, order in pairs(orders) do
			if order.shopId == shopId and OPEN[order.status] and not isExpired(order) then
				count = count + 1
			end
		end
		if count >= config.MaxOpenPerShop then
			return nil, 'shop_busy'
		end
		local estimate, errorCode = deps.quote(vehicle.id, patch)
		if not estimate then
			return nil, errorCode or 'invalid_appearance'
		end
		if #estimate.lines == 0 then
			return nil, 'nothing_to_change'
		end
		nextId = nextId + 1
		local multiplier = deps.multiplier and deps.multiplier(shopId) or 1.0
		local total = math.floor(estimate.total * multiplier + 0.5)
		local order = {
			id = nextId,
			shopId = shopId,
			vehicleId = vehicle.id,
			plate = vehicle.plate,
			model = vehicle.model,
			customer = customer,
			patch = patch,
			estimate = estimate,
			base = total,
			total = total,
			status = 'requested',
			createdAt = deps.now(),
			touchedAt = deps.now()
		}
		orders[order.id] = order
		audit('mechanic_order_requested', { vehicle_id = vehicle.id, operation = shopId, count = #estimate.lines })
		return summary(order)
	end

	function service.ListForShop(shopId)
		local list = {}
		for _, order in pairs(orders) do
			if order.shopId == shopId and OPEN[order.status] and not isExpired(order) then
				list[#list + 1] = summary(order)
			end
		end
		table.sort(list, function(a, b)
			return a.id < b.id
		end)
		return list
	end

	function service.GetForCustomer(source)
		for _, order in pairs(orders) do
			if order.customer.source == source and OPEN[order.status] and not isExpired(order) then
				return summary(order)
			end
		end
	end

	-- O mecânico fixa o valor final dentro da faixa permitida em relação à estimativa.
	function service.Price(orderId, shopId, total, note)
		local order = find(orderId)
		if not order or order.shopId ~= shopId then
			return nil, 'order_not_found'
		end
		if order.status ~= 'requested' and order.status ~= 'quoted' then
			return nil, 'invalid_status'
		end
		if type(total) ~= 'number' or total % 1 ~= 0 or total < 0 then
			return nil, 'invalid_total'
		end
		local base = order.base
		if total < math.floor(base * (1 - config.MaxDiscount)) or total > math.ceil(base * (1 + config.MaxMarkup)) then
			return nil, 'total_out_of_range'
		end
		order.total = total
		order.note = type(note) == 'string' and note:sub(1, config.MaxNoteLength) or nil
		order.status = 'quoted'
		order.touchedAt = deps.now()
		return summary(order)
	end

	function service.Respond(orderId, source, approve)
		local order = find(orderId)
		if not order or order.customer.source ~= source then
			return nil, 'order_not_found'
		end
		if order.status ~= 'quoted' then
			return nil, 'invalid_status'
		end
		order.status = approve and 'approved' or 'declined'
		order.touchedAt = deps.now()
		audit('mechanic_order_' .. order.status, { vehicle_id = order.vehicleId, operation = order.shopId })
		return summary(order)
	end

	function service.Cancel(orderId, source)
		local order = find(orderId)
		if not order or order.customer.source ~= source or not OPEN[order.status] then
			return nil, 'order_not_found'
		end
		order.status = 'cancelled'
		order.touchedAt = deps.now()
		return summary(order)
	end

	-- Cobra (se houver economia) e aplica a aparência. Cobrança falha = pedido continua aprovado.
	function service.Complete(orderId, shopId)
		local order = find(orderId)
		if not order or order.shopId ~= shopId then
			return nil, 'order_not_found'
		end
		if order.status ~= 'approved' then
			return nil, 'invalid_status'
		end
		if deps.charge and order.total > 0 then
			local charged = deps.charge(order.customer.source, order.total, 'mechanic_order')
			if charged ~= true then
				return nil, 'payment_failed'
			end
		end
		local applied = deps.apply(order.vehicleId, order.patch)
		if applied ~= true then
			return nil, tostring(applied)
		end
		order.status = 'done'
		order.touchedAt = deps.now()
		audit('mechanic_order_done', { vehicle_id = order.vehicleId, operation = shopId, count = #order.estimate.lines })
		return summary(order)
	end

	function service.Customer(orderId)
		local order = orders[orderId]
		return order and order.customer or nil
	end

	function service.Vehicle(orderId)
		local order = orders[orderId]
		return order and order.vehicleId or nil
	end

	function service.Drop(source)
		for _, order in pairs(orders) do
			if order.customer.source == source and OPEN[order.status] then
				order.status = 'cancelled'
			end
		end
	end

	return service
end
