BusinessDuty = {}

-- Ponto da equipe. Cada jogador fica de ponto em um negócio por vez; o estado vive só em memória (cai ao sair do servidor).
-- deps: get(businessId) -> negócio, changed(source, businessId, onDuty, reason), member(negócio, characterId) -> bool (opcional).
function BusinessDuty.New(deps)
	local entries = {}
	local service = {}

	local function changed(source, businessId, onDuty, reason)
		if deps.changed then
			deps.changed(source, businessId, onDuty, reason)
		end
	end

	-- atStation: o jogador está num ponto de bater cartão do negócio (já validado por quem chama);
	-- sem isso, só vale de dentro da área.
	function service.ClockIn(source, characterId, businessId, at, atStation)
		local business = deps.get(businessId)
		if not business or not business.enabled then
			return nil, 'unknown_business'
		end
		local current = entries[source]
		if current and current.characterId == tostring(characterId) then
			return nil, current.businessId == businessId and 'already_on_duty' or 'on_duty_elsewhere'
		end
		if not atStation and not (type(at) == 'table' and BusinessArea.Contains(business.area, at.x, at.y, at.z)) then
			return nil, 'outside_area'
		end
		entries[source] = { businessId = businessId, characterId = tostring(characterId) }
		changed(source, businessId, true, 'clock_in')
		return true
	end

	function service.ClockOut(source, reason)
		local entry = entries[source]
		if not entry then
			return nil, 'not_on_duty'
		end
		entries[source] = nil
		changed(source, entry.businessId, false, reason or 'clock_out')
		return true
	end

	function service.Current(source)
		local entry = entries[source]
		return entry and entry.businessId or nil
	end

	function service.Counts()
		local counts, total = {}, 0
		for _, entry in pairs(entries) do
			counts[entry.businessId] = (counts[entry.businessId] or 0) + 1
			total = total + 1
		end
		return { total = total, byBusiness = counts }
	end

	function service.IsOnDuty(businessId, characterId)
		characterId = tostring(characterId)
		for _, entry in pairs(entries) do
			if entry.businessId == businessId and entry.characterId == characterId then
				return true
			end
		end
		return false
	end

	-- Encerra o ponto de quem fechou o negócio ou saiu da área quando o negócio não permite ponto fora dela.
	function service.Sweep(position)
		local ended = {}
		for source, entry in pairs(entries) do
			local business = deps.get(entry.businessId)
			if not business or not business.enabled then
				ended[#ended + 1] = { source, 'business_closed' }
			elseif deps.member and not deps.member(business, entry.characterId) then
				ended[#ended + 1] = { source, 'not_staff' }
			elseif not (business.rules and business.rules.clockOffsite) then
				local at = position(source)
				if not at or not BusinessArea.Contains(business.area, at.x, at.y, at.z) then
					ended[#ended + 1] = { source, 'left_area' }
				end
			end
		end
		for _, item in ipairs(ended) do
			service.ClockOut(item[1], item[2])
		end
		return #ended
	end

	function service.Drop(source)
		entries[source] = nil
	end

	return service
end
