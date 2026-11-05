-- Property Management & Contracts Admin Exports
local Housing = Housing
local properties = Housing.properties
local tenancies = Housing.tenancies
local leases = Housing.leases
local inside = Housing.inside
local config = Housing.config
local log = function(...) return Housing.log(...) end
local audit = function(...) return Housing.audit(...) end
local notify = function(...) return Housing.notify(...) end
local HousingRegistry = HousingRegistry
local HousingPersistence = HousingPersistence
local remote = function(...) return Housing.remote(...) end
local adminOnly = function(...) return Housing.adminOnly(...) end
local isReady = function() return Housing.isReady() end
local sorted = function(...) return Housing.sorted(...) end
local usedUnits = function(...) return Housing.usedUnits(...) end
local packResult = function(...) return Housing.packResult(...) end
local saveProperty = function(...) return Housing.saveProperty(...) end
local deleteProperty = function(...) return Housing.deleteProperty(...) end
local businessLabel = function(...) return Housing.businessLabel(...) end
local evict = function(...) return Housing.evict(...) end
local endLease = function(...) return Housing.endLease(...) end

exports('ListProperties', function()
	if not adminOnly() or not isReady() then
		return {}
	end
	local list = {}
	for _, property in ipairs(sorted()) do
		local _, count = usedUnits(property.id)
		local entry = {}
		for key, value in pairs(property) do
			entry[key] = value
		end
		entry.occupied = count
		list[#list + 1] = entry
	end
	return list
end)

exports('SaveProperty', function(raw)
	if not adminOnly() then
		return { error = 'forbidden' }
	end
	return packResult(saveProperty(raw))
end)

exports('DeleteProperty', function(propertyId)
	if not adminOnly() then
		return { error = 'forbidden' }
	end
	return packResult(deleteProperty(propertyId))
end)

-- Imobiliária (admin): contratos de um imóvel, com quem está dentro agora.
exports('PropertyContracts', function(propertyId)
	if not adminOnly() then
		return { error = 'forbidden' }
	end
	if not isReady() then
		return { error = 'not_ready' }
	end
	if type(propertyId) ~= 'string' or not properties[propertyId] then
		return { error = 'unknown_property' }
	end
	local present = {}
	for _, state in pairs(inside) do
		local key = state.leaseId and ('lease:' .. state.leaseId) or ('tenancy:' .. tostring(state.tenancyId))
		present[key] = (present[key] or 0) + 1
	end
	local now, list = os.time(), {}
	for _, tenancy in pairs(tenancies) do
		if tenancy.propertyId == propertyId then
			list[#list + 1] = {
				kind = 'tenancy', id = tenancy.id, unit = tenancy.unit, characterId = tenancy.characterId,
				cycleDays = tenancy.cycleDays, dailyRate = tenancy.dailyRate, paidUntil = tenancy.paidUntil,
				state = HousingRules.State(tenancy, now, config), starter = tenancy.cycleDays == 0,
				present = present['tenancy:' .. tenancy.id] or 0
			}
		end
	end
	for _, lease in pairs(leases) do
		if lease.propertyId == propertyId then
			list[#list + 1] = {
				kind = 'lease', id = lease.id, unit = lease.unit, businessId = lease.businessId, businessLabel = businessLabel(lease.businessId),
				cycleDays = lease.cycleDays, dailyRate = lease.dailyRate, paidUntil = lease.paidUntil,
				state = HousingRules.State(lease, now, config), granted = lease.cycleDays == 0,
				present = present['lease:' .. lease.id] or 0
			}
		end
	end
	table.sort(list, function(a, b) return a.unit < b.unit end)
	return list
end)

-- Imobiliária (admin): encerra um contrato. O inicial e o cedido a um negócio não são encerrados por aqui.
exports('EndContract', function(kind, contractId)
	if not adminOnly() then
		return { error = 'forbidden' }
	end
	if not isReady() then
		return { error = 'not_ready' }
	end
	contractId = tonumber(contractId)
	if kind == 'tenancy' then
		local tenancy = contractId and tenancies[contractId]
		if not tenancy then
			return { error = 'unknown_contract' }
		end
		if tenancy.cycleDays == 0 then
			return { error = 'starter_locked' }
		end
		return evict(tenancy, 'admin') and true or { error = 'database_error' }
	elseif kind == 'lease' then
		local lease = contractId and leases[contractId]
		if not lease then
			return { error = 'unknown_contract' }
		end
		if lease.cycleDays == 0 then
			return { error = 'granted_locked' }
		end
		return endLease(lease, 'admin') and true or { error = 'database_error' }
	end
	return { error = 'unknown_contract' }
end)
