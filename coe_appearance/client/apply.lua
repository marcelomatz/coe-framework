-- Aplica uma aparência (AppearanceSchema) a um ped freemode. Usado pelo criador, pela cena de seleção
-- (coe_characters) e pelo spawn (coe_spawn). Roupas e cabelo são conferidos com natives: valores além do que o
-- modelo tem voltam para 0, então uma aparência antiga nunca deixa o ped invisível.
local S = AppearanceSchema
AppearanceClient = {}

function AppearanceClient.LoadModel(model)
	local hash = type(model) == 'number' and model or GetHashKey(model)
	if not IsModelInCdimage(hash) then
		return nil
	end
	RequestModel(hash)
	local deadline = GetGameTimer() + 10000
	while not HasModelLoaded(hash) do
		if GetGameTimer() > deadline then
			return nil
		end
		Wait(10)
	end
	return hash
end

local function setComponent(ped, id, drawable, texture)
	local drawables = GetNumberOfPedDrawableVariations(ped, id)
	if drawables <= 0 then
		return
	end
	if drawable < 0 or drawable >= drawables then
		drawable = 0
	end
	local textures = GetNumberOfPedTextureVariations(ped, id, drawable)
	if texture < 0 or texture >= textures then
		texture = 0
	end
	SetPedComponentVariation(ped, id, drawable, texture, 0)
end

local function setProp(ped, id, drawable, texture)
	if drawable < 0 or drawable >= GetNumberOfPedPropDrawableVariations(ped, id) then
		ClearPedProp(ped, id)
		return
	end
	local textures = GetNumberOfPedPropTextureVariations(ped, id, drawable)
	if texture < 0 or texture >= textures then
		texture = 0
	end
	SetPedPropIndex(ped, id, drawable, texture, true)
end

-- Aplica tudo menos o modelo (o ped já precisa ser do modelo da aparência).
function AppearanceClient.Apply(ped, raw)
	local appearance = S.Normalize(raw)
	if not appearance or not DoesEntityExist(ped) then
		return false
	end
	local heritage = appearance.heritage
	SetPedHeadBlendData(ped, heritage.mother, heritage.father, 0, heritage.mother, heritage.father, 0,
		heritage.shapeMix, heritage.skinMix, 0.0, false)
	for index = 1, S.FaceFeatures do
		SetPedFaceFeature(ped, index - 1, appearance.features[index] + 0.0)
	end
	for index, overlay in ipairs(S.Overlays) do
		local entry = appearance.overlays[index]
		if entry.style < 0 then
			SetPedHeadOverlay(ped, overlay.id, 255, 0.0)
		else
			SetPedHeadOverlay(ped, overlay.id, entry.style, entry.opacity + 0.0)
			if overlay.color > 0 then
				SetPedHeadOverlayColor(ped, overlay.id, overlay.color, entry.color, entry.secondColor)
			end
		end
	end
	setComponent(ped, 2, appearance.hair.style, appearance.hair.texture)
	SetPedHairColor(ped, appearance.hair.color, appearance.hair.highlight)
	SetPedEyeColor(ped, appearance.eyeColor)
	for _, component in ipairs(S.Components) do
		local entry = appearance.components[tostring(component.id)]
		if entry then
			setComponent(ped, component.id, entry.drawable, entry.texture)
		end
	end
	for _, prop in ipairs(S.Props) do
		local entry = appearance.props[tostring(prop.id)]
		if entry then
			setProp(ped, prop.id, entry.drawable, entry.texture)
		end
	end
	return true
end

-- Roupa e acessórios atuais do ped (usado para começar o criador com uma roupa válida do modelo).
function AppearanceClient.ReadParts(ped)
	local components, props = {}, {}
	for _, component in ipairs(S.Components) do
		components[tostring(component.id)] = {
			drawable = GetPedDrawableVariation(ped, component.id), texture = GetPedTextureVariation(ped, component.id)
		}
	end
	for _, prop in ipairs(S.Props) do
		props[tostring(prop.id)] = { drawable = GetPedPropIndex(ped, prop.id), texture = math.max(0, GetPedPropTextureIndex(ped, prop.id)) }
	end
	return components, props
end

-- Quantas variações o modelo tem (para os seletores do criador).
function AppearanceClient.Limits(ped, appearance)
	local limits = { components = {}, textures = {}, props = {}, propTextures = {}, overlays = {} }
	for _, component in ipairs(S.Components) do
		local key = tostring(component.id)
		limits.components[key] = GetNumberOfPedDrawableVariations(ped, component.id)
		local entry = appearance and appearance.components[key]
		limits.textures[key] = GetNumberOfPedTextureVariations(ped, component.id, entry and entry.drawable or 0)
	end
	for _, prop in ipairs(S.Props) do
		local key = tostring(prop.id)
		limits.props[key] = GetNumberOfPedPropDrawableVariations(ped, prop.id)
		local entry = appearance and appearance.props[key]
		limits.propTextures[key] = entry and entry.drawable >= 0 and GetNumberOfPedPropTextureVariations(ped, prop.id, entry.drawable) or 0
	end
	limits.hair = GetNumberOfPedDrawableVariations(ped, 2)
	limits.hairTextures = GetNumberOfPedTextureVariations(ped, 2, appearance and appearance.hair.style or 0)
	for _, overlay in ipairs(S.Overlays) do
		limits.overlays[tostring(overlay.id)] = GetNumHeadOverlayValues(overlay.id)
	end
	return limits
end

-- Paletas do jogo para cabelo e maquiagem (RGB de cada índice).
function AppearanceClient.Palettes()
	local hair, makeup = {}, {}
	for index = 0, GetNumHairColors() - 1 do
		local r, g, b = GetPedHairRgbColor(index)
		hair[#hair + 1] = { r, g, b }
	end
	for index = 0, GetNumMakeupColors() - 1 do
		local r, g, b = GetPedMakeupRgbColor(index)
		makeup[#makeup + 1] = { r, g, b }
	end
	return { hair = hair, makeup = makeup }
end

-- Ped local (não sincronizado) com a aparência, para cenas (seleção, criador). Sem aparência, usa o modelo do
-- gênero com a roupa padrão. O chamador cuida de apagar o ped.
function AppearanceClient.CreatePed(raw, x, y, z, heading, gender)
	local appearance = raw and S.Normalize(raw) or nil
	local hash = AppearanceClient.LoadModel(appearance and appearance.model or S.ModelFor(gender))
	if not hash then
		return nil
	end
	local ped = CreatePed(4, hash, x, y, z, heading or 0.0, false, true)
	SetModelAsNoLongerNeeded(hash)
	if not ped or ped == 0 then
		return nil
	end
	SetPedDefaultComponentVariation(ped)
	if appearance then
		AppearanceClient.Apply(ped, appearance)
	else
		SetPedHeadBlendData(ped, 21, 0, 0, 21, 0, 0, 0.5, 0.5, 0.0, false)
	end
	SetEntityInvincible(ped, true)
	SetBlockingOfNonTemporaryEvents(ped, true)
	SetPedCanRagdoll(ped, false)
	return ped
end

-- Troca o modelo do jogador e aplica a aparência. Devolve true se aplicou.
function AppearanceClient.ApplyToPlayer(raw)
	local appearance = S.Normalize(raw)
	if not appearance then
		return false
	end
	local hash = AppearanceClient.LoadModel(appearance.model)
	if not hash then
		return false
	end
	if GetEntityModel(PlayerPedId()) ~= hash then
		SetPlayerModel(PlayerId(), hash)
		SetPedDefaultComponentVariation(PlayerPedId())
	end
	SetModelAsNoLongerNeeded(hash)
	return AppearanceClient.Apply(PlayerPedId(), appearance)
end

exports('Apply', AppearanceClient.Apply)
exports('ApplyToPlayer', AppearanceClient.ApplyToPlayer)
exports('CreatePed', AppearanceClient.CreatePed)
exports('Normalize', function(raw)
	return (S.Normalize(raw))
end)
exports('Default', function(gender)
	return S.Default(gender)
end)
exports('Version', function()
	return S.Version
end)
