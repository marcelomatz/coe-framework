local config = CoeVehiclesConfig.Mileage
local sampler = VehicleMileage.NewSampler(config.MinStepMeters, config.MaxJumpMeters)
local current = 0
local lastReportAt = 0

local function report(vehicle)
	local meters = sampler.Take()
	if meters > 0 and Core.Platform.Entities.Exists(vehicle) then
		local netId = Core.Platform.Entities.GetNetworkId(vehicle)
		if netId then
			TriggerServerEvent('coe_vehicles:reportMileage', netId, meters)
		end
	end
end

-- Só amostra enquanto o jogador dirige um veículo registrado; fora disso dorme em intervalo longo.
CreateThread(function()
	while true do
		local ped = PlayerPedId()
		local vehicle = GetVehiclePedIsIn(ped, false)
		local active = vehicle ~= 0
			and GetPedInVehicleSeat(vehicle, -1) == ped
			and Core.Platform.Entities.GetState(vehicle, 'coe:vehicleId') ~= nil

		if active then
			local now = GetGameTimer()
			if vehicle ~= current then
				if current ~= 0 then
					report(current)
				end
				current = vehicle
				sampler.Reset()
				sampler.Take()
				lastReportAt = now
			end
			local position = Core.Platform.Entities.GetCoords(vehicle)
			if position then
				sampler.Step(position.x, position.y, position.z)
			end
			if now - lastReportAt >= config.ReportIntervalMs then
				report(vehicle)
				lastReportAt = now
			end
			Wait(config.SampleIntervalMs)
		else
			if current ~= 0 then
				report(current)
				current = 0
				sampler.Reset()
			end
			Wait(config.IdleIntervalMs)
		end
	end
end)
