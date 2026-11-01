GaragesRegistry = {}

local function number(value, min, max)
	if type(value) ~= 'number' or value ~= value or value == math.huge or value == -math.huge then
		return nil
	end
	if value < min or value > max then
		return nil
	end
	return math.floor(value * 100 + 0.5) / 100
end

local function integer(value, min, max, default)
	if value == nil then
		return default
	end
	if type(value) ~= 'number' or value % 1 ~= 0 or value < min or value > max then
		return nil
	end
	return value
end

local function text(value, max)
	if type(value) ~= 'string' then
		return nil
	end
	value = value:gsub('^%s+', ''):gsub('%s+$', '')
	if value == '' or #value > max or value:find('[%c<>]') then
		return nil
	end
	return value
end

local function normalizeSpot(raw, config)
	if type(raw) ~= 'table' or type(raw.id) ~= 'string' or not raw.id:match('^[a-z0-9_]+$') or #raw.id > 24 then
		return nil
	end
	local c = config.Limits.MaxCoordinate
	local x, y, z = number(raw.x, -c, c), number(raw.y, -c, c), number(raw.z, -1000.0, 3000.0)
	local radius = number(raw.radius == nil and 3.0 or raw.radius, 1.0, 8.0)
	local heading = number(raw.heading == nil and 0.0 or raw.heading, -360.0, 360.0)
	local label = raw.label == nil and raw.id or text(raw.label, 32)
	if not (x and y and z and radius and heading and label) then
		return nil
	end
	return { id = raw.id, label = label, x = x, y = y, z = z, radius = radius, heading = heading }
end

-- Valida uma garagem vinda do painel. Devolve a garagem normalizada ou nil, código.
function GaragesRegistry.Normalize(raw, config)
	if type(raw) ~= 'table' then
		return nil, 'invalid_garage'
	end
	if type(raw.id) ~= 'string' or not raw.id:match('^[a-z0-9_]+$') or #raw.id < 2 or #raw.id > 32 then
		return nil, 'invalid_id'
	end
	if config.Kinds[raw.kind] == nil then
		return nil, 'invalid_kind'
	end
	local label = text(raw.label, 48)
	if not label then
		return nil, 'invalid_label'
	end
	local garage = { id = raw.id, kind = raw.kind, label = label, enabled = raw.enabled ~= false, spots = {} }

	if type(raw.spots) ~= 'table' or #raw.spots < 1 or #raw.spots > config.Limits.MaxSpots then
		return nil, 'invalid_spots'
	end
	local seen = {}
	for _, rawSpot in ipairs(raw.spots) do
		local spot = normalizeSpot(rawSpot, config)
		if not spot or seen[spot.id] then
			return nil, 'invalid_spots'
		end
		seen[spot.id] = true
		garage.spots[#garage.spots + 1] = spot
	end

	if raw.kind == 'business' then
		if type(raw.businessId) ~= 'string' or not raw.businessId:match('^[a-z0-9_]+$') or #raw.businessId > 32 then
			return nil, 'invalid_business'
		end
		garage.businessId = raw.businessId
	elseif raw.kind == 'job' then
		if type(raw.jobs) ~= 'table' or #raw.jobs < 1 or #raw.jobs > config.Limits.MaxJobs then
			return nil, 'invalid_jobs'
		end
		garage.jobs = {}
		local jobSeen = {}
		for _, job in ipairs(raw.jobs) do
			if type(job) ~= 'string' or not job:match('^[a-z0-9_]+$') or #job > 32 or jobSeen[job] then
				return nil, 'invalid_jobs'
			end
			jobSeen[job] = true
			garage.jobs[#garage.jobs + 1] = job
		end
	end

	local blip = type(raw.blip) == 'table' and raw.blip or {}
	local defaults = config.DefaultBlip
	local sprite = integer(blip.sprite, 1, 900, defaults.sprite)
	local color = integer(blip.color, 0, 85, defaults.color)
	local scale = number(blip.scale == nil and defaults.scale or blip.scale, 0.5, 1.5)
	if not (sprite and color and scale) then
		return nil, 'invalid_blip'
	end
	local blipEnabled = blip.enabled
	if blipEnabled == nil then
		blipEnabled = raw.kind == 'public'
	end
	garage.blip = { enabled = blipEnabled == true, sprite = sprite, color = color, scale = scale }
	return garage
end
