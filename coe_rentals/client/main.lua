-- Cliente de aluguel de veículos populares com blips e interações (0.00 ms em idle).
local _t_inst = (Core and Core.Locale and Core.Locale.New) and Core.Locale.New({
	default = (RentalsConfig and RentalsConfig.Locale) or (Core and Core.Locale and Core.Locale.GetDefaultLang()) or 'pt-BR',
	locales = Locales
})
local function _t(key, params)
	if _t_inst then
		if type(_t_inst) == 'function' then
			local ok, res = pcall(_t_inst, key, params)
			if ok and res ~= nil then return res end
		elseif type(_t_inst) == 'table' and type(_t_inst.T) == 'function' then
			local ok, res = pcall(_t_inst.T, _t_inst, key, params)
			if ok and res ~= nil then return res end
		end
	end
	if Locales and Locales['pt-BR'] and Locales['pt-BR'][key] then
		return Locales['pt-BR'][key]
	end
	return key
end
local blips = {}
local activeRentalPlate = nil
local activeRentalDeposit = 0

local function showHelp(text)
	BeginTextCommandDisplayHelp('STRING')
	AddTextComponentSubstringPlayerName(text)
	EndTextCommandDisplayHelp(0, false, true, -1)
end

-- Inicializa blips das estações no mapa
CreateThread(function()
	for _, station in ipairs(RentalsConfig.Stations or {}) do
		if station.blip and station.blip.enabled and station.coords then
			local b = AddBlipForCoord(station.coords.x + 0.0, station.coords.y + 0.0, station.coords.z + 0.0)
			SetBlipSprite(b, station.blip.sprite or 226)
			SetBlipDisplay(b, 4)
			SetBlipScale(b, station.blip.scale or 0.7)
			SetBlipColour(b, station.blip.color or 3)
			SetBlipAsShortRange(b, true)
			BeginTextCommandSetBlipName('STRING')
			AddTextComponentSubstringPlayerName(station.label or 'Aluguel de Veículos')
			EndTextCommandSetBlipName(b)
			blips[#blips + 1] = b
		end
	end
end)

-- Loop de proximidade (0.00 ms em idle)
CreateThread(function()
	while true do
		local sleep = 1000
		local ped = PlayerPedId()
		if ped > 0 and DoesEntityExist(ped) and not IsEntityDead(ped) then
			local coords = GetEntityCoords(ped)
			local inVehicle = IsPedInAnyVehicle(ped, false)

			for _, station in ipairs(RentalsConfig.Stations or {}) do
				if station.coords then
					local dist = #(coords - vector3(station.coords.x, station.coords.y, station.coords.z))
					if dist < 15.0 then
						sleep = 0
						if inVehicle then
							-- Área de devolução
							local retZone = station.returnZone or station.spawn or station.coords
							local distRet = #(coords - vector3(retZone.x, retZone.y, retZone.z))
							if distRet <= (retZone.radius or 5.0) and activeRentalPlate then
								showHelp(_t('press_to_return'))
								if IsControlJustReleased(0, 38) then -- Tecla E
									Core.Events.ToServer('rentals.return', station.id)
									Wait(500)
								end
							end
						else
							-- Ponto de aluguel a pé
							if dist <= 2.0 then
								showHelp(_t('press_to_rent'))
								if IsControlJustReleased(0, 38) then -- Tecla E
									openRentalMenu(station)
									Wait(500)
								end
							end
						end
					end
				end
			end
		end
		Wait(sleep)
	end
end)

function openRentalMenu(station)
	-- Se houver sistema de menu nativo ou chat prompt
	local vehicles = RentalsConfig.Vehicles or {}
	if #vehicles == 0 then return end

	-- Exemplo direto de seleção: cicla pelo primeiro disponível ou aciona o veículo padrão
	-- Se o jogador já tem aluguel ativo, o servidor avisará
	local defaultVehicle = vehicles[1]
	Core.Events.ToServer('rentals.rent', station.id, defaultVehicle.model)
end

Core.Events.OnNet('rentals.spawned', function(netId, plate, deposit)
	activeRentalPlate = plate
	activeRentalDeposit = deposit
	CreateThread(function()
		local timeout = 50
		while not NetworkDoesEntityExistWithNetworkId(netId) and timeout > 0 do
			Wait(100)
			timeout = timeout - 1
		end
		if NetworkDoesEntityExistWithNetworkId(netId) then
			local veh = NetworkGetEntityFromNetworkId(netId)
			TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1)
		end
	end)
end)

Core.Events.OnNet('rentals.returned', function()
	activeRentalPlate = nil
	activeRentalDeposit = 0
end)
