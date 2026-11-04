-- Spaces, Interior Previews & Delivery Address Resolution
local Housing = Housing
local config = Housing.config
local properties = Housing.properties
local tenancies = Housing.tenancies
local leases = Housing.leases
local inside = Housing.inside
local previewing = Housing.previewing
local log = function(...) return Housing.log(...) end
local audit = function(...) return Housing.audit(...) end
local isMember = function(...) return Housing.isMember(...) end
local remote = function(...) return Housing.remote(...) end
local HousingPersistence = HousingPersistence
local HousingInteriors = HousingInteriors

exports('Interiors', function()
	if not adminOnly() then
		return { categories = {}, list = {} }
	end
	return { categories = HousingInteriors.categories, list = HousingInteriors.list }
end)

-- Miniaturas capturadas no jogo: mapa id do interior -> data URL JPEG.
exports('InteriorThumbs', function()
	if not adminOnly() then
		return { error = 'forbidden' }
	end
	if not ready then
		return { error = 'not_ready' }
	end
	local map, errorCode = HousingPersistence.ListThumbs()
	return packResult(map, errorCode)
end)

exports('SaveInteriorThumb', function(interiorId, image)
	if not adminOnly() then
		return { error = 'forbidden' }
	end
	if not ready then
		return { error = 'not_ready' }
	end
	local valid, errorCode = HousingRegistry.Thumb(interiorId, image, HousingInteriors.byId, config.Limits.MaxThumbBytes)
	if not valid then
		return { error = errorCode }
	end
	local saved, saveError = HousingPersistence.SaveThumb(interiorId, image)
	return packResult(saved and true or nil, saveError)
end)

-- Prévia: o admin vai para um mundo só dele enquanto visita interiores; EndPreview o devolve ao mundo comum.
exports('BeginPreview', function(playerId)
	if not adminOnly() then
		return { error = 'forbidden' }
	end
	playerId = tonumber(playerId)
	if not playerId or not GetPlayerName(playerId) then
		return { error = 'invalid_player' }
	end
	-- Quem está dentro de um imóvel também visita: ao voltar, retorna ao mundo do próprio imóvel.
	local bucket = config.PreviewBucketBase + playerId
	local current = Core.Platform.Routing.GetPlayerBucket(playerId)
	if not previewing[playerId] then
		previewing[playerId] = { bucket = current ~= bucket and current or 0 }
	end
	Core.Platform.Routing.SetPlayerBucket(playerId, bucket)
	Core.Platform.Routing.SetPopulationEnabled(bucket, false)
	return true
end)

exports('EndPreview', function(playerId)
	if not adminOnly() then
		return { error = 'forbidden' }
	end
	playerId = tonumber(playerId)
	if playerId and (previewing[playerId] or Core.Platform.Routing.GetPlayerBucket(playerId) == config.PreviewBucketBase + playerId) then
		local preview = previewing[playerId] or {}
		previewing[playerId] = nil
		Core.Platform.Routing.SetPlayerBucket(playerId, inside[playerId] and preview.bucket or 0)
		if preview.door then
			TriggerClientEvent('coe_housing:left', playerId, preview.door)
		end
	end
	return true
end)

-- Visita interrompida (admin ou este resource parou): devolve quem estava visitando ao mundo normal.
AddEventHandler('onResourceStop', function(resourceName)
	if resourceName ~= GetCurrentResourceName() and resourceName ~= 'coe_admin' then
		return
	end
	for playerId, preview in pairs(previewing) do
		previewing[playerId] = nil
		if GetPlayerName(playerId) then
			Core.Platform.Routing.SetPlayerBucket(playerId, inside[playerId] and preview.bucket or 0)
		end
	end
end)

-- Imóveis comerciais de um negócio (alugados ou cedidos), para o tablet de negócios.
exports('BusinessProperties', function(businessId)
	if config.BusinessResources[GetInvokingResource() or ''] ~= true or not ready or type(businessId) ~= 'string' then
		return {}
	end
	local now = os.time()
	local list = {}
	for _, lease in pairs(leases) do
		local property = lease.businessId == businessId and properties[lease.propertyId]
		if property then
			list[#list + 1] = {
				id = property.id, label = property.label, enabled = property.enabled, leased = lease.cycleDays > 0,
				paidUntil = lease.paidUntil, overdue = HousingRules.State(lease, now, config) ~= 'ok',
				x = property.door.x, y = property.door.y
			}
		end
	end
	table.sort(list, function(a, b) return a.label < b.label end)
	return list
end)

-- Entregas (coe_amzg) -----------------------------------------------------------------------------------
-- Endereço = imóvel + dono do espaço (o mesmo do baú). Só resources de config.DeliveryCallers.

local function deliveryCaller()
	return config.DeliveryCallers[GetInvokingResource() or ''] == true and ready
end

-- Endereços em que o personagem pode receber: moradias, comerciais dos negócios em que trabalha e imóveis ilegais
-- com acesso. Contratos vencidos (fora da carência) ficam de fora.
exports('DeliveryAddresses', function(playerId)
	local characterId = deliveryCaller() and Core.Players.GetActiveCharacterId(playerId)
	if not characterId then
		return {}
	end
	characterId = tostring(characterId)
	local list, now = {}, os.time()
	local function add(property, owner, detail)
		if property and property.enabled then
			list[#list + 1] = {
				propertyId = property.id, owner = owner, label = property.label, kind = property.kind,
				kindLabel = config.Kinds[property.kind] or property.kind, detail = detail, x = property.door.x, y = property.door.y
			}
		end
	end
	for _, tenancy in pairs(tenancies) do
		if tenancy.characterId == characterId and HousingRules.State(tenancy, now, config) == 'ok' then
			add(properties[tenancy.propertyId], 'c' .. characterId)
		end
	end
	for _, lease in pairs(leases) do
		if isMember(lease.businessId, characterId) and HousingRules.State(lease, now, config) == 'ok' then
			add(properties[lease.propertyId], 'b' .. lease.businessId, businessLabel(lease.businessId))
		end
	end
	for _, property in pairs(properties) do
		if property.kind == 'hideout' and property.world and HousingRegistry.HasAccess(property, characterId) then
			add(property, 'shared')
		end
	end
	table.sort(list, function(a, b) return a.label < b.label end)
	return list
end)

-- O endereço ainda existe (contrato ativo ou imóvel ilegal com mundo)? Devolve o interior para posicionar a entrega.
exports('AddressActive', function(propertyId, owner)
	local property = deliveryCaller() and type(propertyId) == 'string' and properties[propertyId]
	if not property or not property.enabled or type(owner) ~= 'string' then
		return false
	end
	local active
	if owner == 'shared' then
		active = property.kind == 'hideout' and property.world ~= nil
	elseif owner:sub(1, 1) == 'b' then
		active = leaseOf(owner:sub(2), propertyId) ~= nil
	elseif owner:sub(1, 1) == 'c' then
		active = tenancyOf(owner:sub(2), propertyId) ~= nil
	end
	return active == true
end)

-- Espaço em que o jogador está agora: { propertyId, owner, interior }, ou nil fora de um imóvel.
exports('CurrentSpace', function(playerId)
	local state = deliveryCaller() and inside[playerId]
	local property = state and properties[state.propertyId]
	if not property then
		return nil
	end
	local owner = spaceOwner(state, property, state.characterId)
	if not owner then
		return nil
	end
	local interior = property.interior
	return { propertyId = property.id, owner = owner, interior = { x = interior.x, y = interior.y, z = interior.z, heading = interior.heading or 0.0 } }
end)

-- Jogadores dentro de um espaço (para mostrar entregas a quem já está lá).
exports('PlayersInSpace', function(propertyId, owner)
	local list = {}
	if not deliveryCaller() then
		return list
	end
	for playerId, state in pairs(inside) do
		local property = state.propertyId == propertyId and properties[propertyId]
		if property and spaceOwner(state, property, state.characterId) == owner then
			list[#list + 1] = playerId
		end
	end
	return list
end)

CreateThread(function()
	local waitingLogged = false
	while true do
		local initialized, errorCode = HousingPersistence.Initialize()
		if initialized then
			break
		end
		if errorCode == 'database_not_ready' then
			if not waitingLogged then
				log('info', 'persistence', 'database_waiting', {})
				waitingLogged = true
			end
			Wait(1000)
		else
			log('error', 'persistence', 'database_initialization_failed', { error_code = errorCode or 'database_error', retry_ms = 5000 })
			Wait(5000)
		end
	end
	local dependenciesLogged = false
	while not (GetResourceState('coe_economy') == 'started' and exports.coe_economy:IsReady()) do
		if not dependenciesLogged then
			log('info', 'system', 'housing_waiting', {})
			dependenciesLogged = true
		end
		Wait(1000)
	end
	rebuild()
	ready = true
	log('info', 'system', 'housing_ready', {})
	broadcast()
	while true do
		Wait(config.TickMs)
		tick()
	end
end)

-- Provedor dos imóveis comerciais no app do negócio (coe_businesses:RegisterProvider 'properties'): aba Propriedades.
-- De novo sempre que o coe_businesses reiniciar.
local function registerPropertiesProvider()
	if GetResourceState('coe_businesses') ~= 'started' then
		return
	end
	local ok, result = pcall(function()
		return exports.coe_businesses:RegisterProvider('properties', { list = 'BusinessProperties' })
	end)
	if not ok or result ~= true then
		log('warn', 'system', 'housing_provider_failed', { error_code = ok and type(result) == 'table' and tostring(result.error) or 'unavailable' })
	end
end

AddEventHandler('onResourceStart', function(resource)
	if resource == 'coe_businesses' then
		registerPropertiesProvider()
	end
end)
CreateThread(registerPropertiesProvider)
