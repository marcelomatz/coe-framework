VehicleMeta = {}

local TYPE_MAP = {
	VEHICLE_TYPE_CAR = 'automobile',
	VEHICLE_TYPE_QUADBIKE = 'automobile',
	VEHICLE_TYPE_AMPHIBIOUS_AUTOMOBILE = 'automobile',
	VEHICLE_TYPE_AMPHIBIOUS_QUADBIKE = 'automobile',
	VEHICLE_TYPE_BIKE = 'bike',
	VEHICLE_TYPE_BICYCLE = 'bike',
	VEHICLE_TYPE_BOAT = 'boat',
	VEHICLE_TYPE_SUBMARINE = 'submarine',
	VEHICLE_TYPE_HELI = 'heli',
	VEHICLE_TYPE_BLIMP = 'heli',
	VEHICLE_TYPE_PLANE = 'plane',
	VEHICLE_TYPE_TRAILER = 'trailer',
	VEHICLE_TYPE_TRAIN = 'train'
}

local function stripComments(xml)
	return (xml:gsub('<!%-%-.-%-%->', ''))
end

local function field(segment, tag)
	local value = segment:match('<' .. tag .. '>%s*([^<]-)%s*</' .. tag .. '>')
	if value == '' then
		return nil
	end
	return value
end

-- Cada veículo começa em <modelName>; os demais campos vêm até o próximo modelName.
function VehicleMeta.ParseVehicles(xml)
	if type(xml) ~= 'string' then
		return nil, 'invalid_xml'
	end
	xml = stripComments(xml)
	local entries = {}
	local position = 1
	while true do
		local startAt, endAt = xml:find('<modelName>', position, true)
		if not startAt then
			break
		end
		local nextStart = xml:find('<modelName>', endAt + 1, true)
		local segment = xml:sub(startAt, (nextStart or #xml + 1) - 1)
		local modelName = field(segment, 'modelName')
		if modelName then
			local rawType = field(segment, 'type')
			entries[#entries + 1] = {
				model = modelName:lower(),
				handlingId = (field(segment, 'handlingId') or modelName):lower(),
				gameName = field(segment, 'gameName'),
				brand = field(segment, 'vehicleMakeName'),
				rawType = rawType,
				type = rawType and TYPE_MAP[rawType] or nil
			}
		end
		position = nextStart or #xml + 1
	end
	return entries
end

-- Só valores escalares (<fMass value="1500.0"/>); vetores e sub-handlings ficam de fora.
function VehicleMeta.ParseHandling(xml)
	if type(xml) ~= 'string' then
		return nil, 'invalid_xml'
	end
	xml = stripComments(xml)
	local handlings = {}
	local position = 1
	while true do
		local startAt, endAt = xml:find('<handlingName>', position, true)
		if not startAt then
			break
		end
		local nextStart = xml:find('<handlingName>', endAt + 1, true)
		local segment = xml:sub(startAt, (nextStart or #xml + 1) - 1)
		local name = field(segment, 'handlingName')
		if name then
			local values = {}
			for key, value in segment:gmatch('<([fn]%w+)%s+value="([^"]-)"%s*/>') do
				local number = tonumber(value)
				if number then
					values[key] = number
				end
			end
			handlings[#handlings + 1] = { name = name:lower(), values = values }
		end
		position = nextStart or #xml + 1
	end
	return handlings
end
