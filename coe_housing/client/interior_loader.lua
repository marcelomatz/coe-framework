-- Carrega IPLs e entity sets de um interior do catálogo (shared/interiors.lua) e leva o jogador até ele.
-- Também é incluído pelo coe_admin (@coe_housing/client/interior_loader.lua) para visitar interiores e gerar miniaturas.
HousingInteriorLoader = {}

-- Antes de chegar: descarrega os outros estilos do mesmo espaço e pede os IPLs deste.
function HousingInteriorLoader.Prepare(entry)
	if type(entry) ~= 'table' then
		return
	end
	if entry.group then
		for _, other in ipairs(HousingInteriors.list) do
			if other.group == entry.group and other.id ~= entry.id then
				for _, ipl in ipairs(other.ipls or {}) do
					if IsIplActive(ipl) then
						RemoveIpl(ipl)
					end
				end
			end
		end
	end
	for _, ipl in ipairs(entry.ipls or {}) do
		if not IsIplActive(ipl) then
			RequestIpl(ipl)
		end
	end
end

-- Depois de posicionar o jogador: espera o interior carregar e liga os entity sets.
function HousingInteriorLoader.Finish(entry, point)
	local x, y, z = point.x + 0.0, point.y + 0.0, point.z + 0.0
	local deadline = GetGameTimer() + 5000
	local interior = GetInteriorAtCoords(x, y, z)
	while interior == 0 and GetGameTimer() < deadline do
		Wait(50)
		interior = GetInteriorAtCoords(x, y, z)
	end
	if interior == 0 then
		return 0
	end
	while not IsInteriorReady(interior) and GetGameTimer() < deadline do
		Wait(50)
	end
	if type(entry) == 'table' and entry.entitySets then
		local changed = false
		for _, set in ipairs(entry.entitySets) do
			if not IsInteriorEntitySetActive(interior, set) then
				ActivateInteriorEntitySet(interior, set)
				changed = true
			end
		end
		if changed then
			RefreshInterior(interior)
		end
	end
	return interior
end

-- point = { x, y, z, heading }; interiorId opcional (catálogo); fade escurece a tela durante a troca.
function HousingInteriorLoader.Teleport(point, interiorId, fade)
	local entry = type(interiorId) == 'string' and HousingInteriors.byId[interiorId] or nil
	local x, y, z = point.x + 0.0, point.y + 0.0, point.z + 0.0
	if fade then
		-- Outro script (o spawn, por exemplo) pode cancelar o fade; com prazo, o teleporte nunca fica preso esperando.
		DoScreenFadeOut(400)
		local fadeDeadline = GetGameTimer() + 2000
		while not IsScreenFadedOut() and GetGameTimer() < fadeDeadline do
			if not IsScreenFadingOut() then
				DoScreenFadeOut(400)
			end
			Wait(50)
		end
	end
	-- Lido depois do fade: o spawn pode trocar o modelo (e o ped) enquanto a tela escurece.
	local ped = PlayerPedId()
	HousingInteriorLoader.Prepare(entry)
	RequestCollisionAtCoord(x, y, z)
	Core.Platform.Entities.SetCoords(ped, x, y, z)
	Core.Platform.Entities.SetHeading(ped, (point.heading or 0.0) + 0.0)
	if entry then
		HousingInteriorLoader.Finish(entry, point)
	end
	local deadline = GetGameTimer() + 3000
	while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < deadline do
		RequestCollisionAtCoord(x, y, z)
		Wait(50)
	end
	if fade then
		Wait(200)
		DoScreenFadeIn(400)
	end
end
