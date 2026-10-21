-- Formato da aparência de personagem (versão 1). Regra pura, sem natives: usada pelo cliente (criador, aplicação no
-- ped) e pelos testes. O core guarda o JSON como opaco; aqui se decide o que é válido. Valores fora da faixa são
-- trazidos para a faixa (clamp) e chaves desconhecidas são descartadas. Limites reais de roupas e cabelos dependem do
-- modelo e são conferidos no cliente com natives na hora de aplicar.
AppearanceSchema = { Version = 1 }

local S = AppearanceSchema

S.Models = { male = 'mp_m_freemode_01', female = 'mp_f_freemode_01' }
S.FaceFeatures = 20

-- Ajustes do rosto (SetPedFaceFeature 0..19), agrupados como no criador do GTA Online.
S.FeatureGroups = {
	{ id = 'nose', label = 'Nariz', features = { { 0, 'Largura' }, { 1, 'Altura da ponta' }, { 2, 'Comprimento da ponta' }, { 3, 'Altura do osso' }, { 4, 'Ponta caída' }, { 5, 'Desvio do osso' } } },
	{ id = 'brows', label = 'Sobrancelhas', features = { { 6, 'Altura' }, { 7, 'Profundidade' } } },
	{ id = 'cheeks', label = 'Maçãs e bochechas', features = { { 8, 'Altura das maçãs' }, { 9, 'Largura das maçãs' }, { 10, 'Bochechas' } } },
	{ id = 'eyes', label = 'Olhos e lábios', features = { { 11, 'Abertura dos olhos' }, { 12, 'Espessura dos lábios' } } },
	{ id = 'jaw', label = 'Mandíbula e queixo', features = { { 13, 'Largura da mandíbula' }, { 14, 'Comprimento da mandíbula' }, { 15, 'Altura do queixo' }, { 16, 'Comprimento do queixo' }, { 17, 'Largura do queixo' }, { 18, 'Covinha no queixo' } } },
	{ id = 'neck', label = 'Pescoço', features = { { 19, 'Espessura do pescoço' } } }
}

-- Sobreposições da cabeça (SetPedHeadOverlay 0..12): maior estilo e tipo de cor (0 sem cor, 1 cabelo, 2 maquiagem).
S.Overlays = {
	{ id = 0, key = 'blemishes', label = 'Manchas', max = 23, color = 0 },
	{ id = 1, key = 'beard', label = 'Barba', max = 28, color = 1 },
	{ id = 2, key = 'eyebrows', label = 'Sobrancelhas', max = 33, color = 1 },
	{ id = 3, key = 'ageing', label = 'Envelhecimento', max = 14, color = 0 },
	{ id = 4, key = 'makeup', label = 'Maquiagem', max = 74, color = 0 },
	{ id = 5, key = 'blush', label = 'Blush', max = 6, color = 2 },
	{ id = 6, key = 'complexion', label = 'Pele', max = 11, color = 0 },
	{ id = 7, key = 'sunDamage', label = 'Danos do sol', max = 10, color = 0 },
	{ id = 8, key = 'lipstick', label = 'Batom', max = 9, color = 2 },
	{ id = 9, key = 'freckles', label = 'Sardas e pintas', max = 17, color = 0 },
	{ id = 10, key = 'chestHair', label = 'Pelos do peito', max = 16, color = 1 },
	{ id = 11, key = 'bodyBlemishes', label = 'Manchas no corpo', max = 11, color = 0 },
	{ id = 12, key = 'bodyBlemishes2', label = 'Mais manchas no corpo', max = 1, color = 0 }
}

-- Peças de roupa (SetPedComponentVariation) e acessórios (SetPedPropIndex) editáveis no criador.
S.Components = {
	{ id = 11, key = 'top', label = 'Parte de cima' },
	{ id = 8, key = 'undershirt', label = 'Camiseta de baixo' },
	{ id = 3, key = 'arms', label = 'Braços e luvas' },
	{ id = 4, key = 'legs', label = 'Calça' },
	{ id = 6, key = 'shoes', label = 'Calçado' },
	{ id = 7, key = 'accessory', label = 'Acessórios' },
	{ id = 5, key = 'bag', label = 'Mochila' },
	{ id = 1, key = 'mask', label = 'Máscara' },
	{ id = 9, key = 'armor', label = 'Colete' },
	{ id = 10, key = 'decals', label = 'Adesivos' }
}
S.Props = {
	{ id = 0, key = 'hat', label = 'Chapéu' },
	{ id = 1, key = 'glasses', label = 'Óculos' },
	{ id = 2, key = 'ears', label = 'Brincos' },
	{ id = 6, key = 'watch', label = 'Relógio' },
	{ id = 7, key = 'bracelet', label = 'Pulseira' }
}

-- Subcategorias da etapa Roupas: cada peça (componente ou prop) aparece em exatamente uma.
-- Cada parte: { kind = 'component'|'prop', id, label, shot = câmera da foto (Thumbnails.Cameras) }.
S.ClothingCategories = {
	{ key = 'torso', label = 'Tronco', parts = {
		{ kind = 'component', id = 11, label = 'Jaquetas e camisas', shot = 'torso' },
		{ kind = 'component', id = 8, label = 'Camisetas de baixo', shot = 'torso' },
		{ kind = 'component', id = 3, label = 'Braços e luvas', shot = 'torso' },
		{ kind = 'component', id = 9, label = 'Coletes', shot = 'torso' }
	} },
	{ key = 'legs', label = 'Pernas e pés', parts = {
		{ kind = 'component', id = 4, label = 'Calças e saias', shot = 'legs' },
		{ kind = 'component', id = 6, label = 'Calçados', shot = 'feet' }
	} },
	{ key = 'head', label = 'Cabeça', parts = {
		{ kind = 'prop', id = 0, label = 'Chapéus e bonés', shot = 'head' },
		{ kind = 'prop', id = 1, label = 'Óculos', shot = 'head' },
		{ kind = 'prop', id = 2, label = 'Brincos', shot = 'head' },
		{ kind = 'component', id = 1, label = 'Máscaras', shot = 'head' }
	} },
	{ key = 'extras', label = 'Acessórios', parts = {
		{ kind = 'component', id = 7, label = 'Colares e gravatas', shot = 'torso' },
		{ kind = 'prop', id = 6, label = 'Relógios', shot = 'wrist' },
		{ kind = 'prop', id = 7, label = 'Pulseiras', shot = 'wrist' },
		{ kind = 'component', id = 5, label = 'Mochilas e bolsas', shot = 'back' },
		{ kind = 'component', id = 10, label = 'Adesivos', shot = 'torso' }
	} }
}

-- Nome do arquivo da foto de uma peça (sem pasta): male_c11_12.webp, female_p0_3.webp.
function S.ThumbName(gender, kind, id, drawable, extension)
	return ('%s_%s%d_%d.%s'):format(gender == 'female' and 'female' or 'male', kind == 'prop' and 'p' or 'c',
		math.floor(tonumber(id) or 0), math.floor(tonumber(drawable) or 0), extension or 'webp')
end

-- Confere um nome vindo da rede: devolve gender, kind, id, drawable ou nil.
function S.ParseThumbName(name, extension)
	if type(name) ~= 'string' or #name > 48 then
		return nil
	end
	local gender, kind, id, drawable, ext = name:match('^(%l+)_([cp])(%d+)_(%d+)%.(%l+)$')
	if (gender ~= 'male' and gender ~= 'female') or ext ~= (extension or 'webp') then
		return nil
	end
	id, drawable = tonumber(id), tonumber(drawable)
	local catalog = kind == 'p' and S.Props or S.Components
	local known = false
	for _, entry in ipairs(catalog) do
		if entry.id == id then
			known = true
		end
	end
	if not known or drawable > 999 then
		return nil
	end
	return gender, kind == 'p' and 'prop' or 'component', id, drawable
end

-- Pais do criador do GTA Online (índice da herança e textura do retrato em char_creator_portraits).
S.Fathers = {
	{ 0, 'Benjamin' }, { 1, 'Daniel' }, { 2, 'Joshua' }, { 3, 'Noah' }, { 4, 'Andrew' }, { 5, 'Juan' }, { 6, 'Alex' },
	{ 7, 'Isaac' }, { 8, 'Evan' }, { 9, 'Ethan' }, { 10, 'Vincent' }, { 11, 'Angel' }, { 12, 'Diego' }, { 13, 'Adrian' },
	{ 14, 'Gabriel' }, { 15, 'Michael' }, { 16, 'Santiago' }, { 17, 'Kevin' }, { 18, 'Louis' }, { 19, 'Samuel' },
	{ 20, 'Anthony' }, { 42, 'Claude' }, { 43, 'Niko' }, { 44, 'John' }
}
S.Mothers = {
	{ 21, 'Hannah' }, { 22, 'Aubrey' }, { 23, 'Jasmine' }, { 24, 'Gisele' }, { 25, 'Amelia' }, { 26, 'Isabella' },
	{ 27, 'Zoe' }, { 28, 'Ava' }, { 29, 'Camila' }, { 30, 'Violet' }, { 31, 'Sophia' }, { 32, 'Evelyn' }, { 33, 'Nicole' },
	{ 34, 'Ashley' }, { 35, 'Grace' }, { 36, 'Brianna' }, { 37, 'Natalie' }, { 38, 'Olivia' }, { 39, 'Elizabeth' },
	{ 40, 'Charlotte' }, { 41, 'Emma' }, { 45, 'Misty' }
}

function S.Portrait(index)
	if index >= 42 and index <= 44 then
		return 'special_male_' .. (index - 42)
	end
	if index == 45 then
		return 'special_female_0'
	end
	if index >= 21 then
		return 'female_' .. (index - 21)
	end
	return 'male_' .. index
end

local MAX_DRAWABLE = 511
local MAX_TEXTURE = 63
local MAX_COLOR = 63

local function clamp(value, min, max, fallback)
	local number = tonumber(value)
	if not number or number ~= number then
		return fallback
	end
	if number < min then
		return min
	end
	if number > max then
		return max
	end
	return number
end

local function int(value, min, max, fallback)
	local number = clamp(value, min, max, fallback)
	return math.floor(number + 0.5)
end

-- Duas casas decimais bastam e deixam o JSON pequeno.
local function float(value, min, max, fallback)
	return math.floor(clamp(value, min, max, fallback) * 100 + 0.5) / 100
end

function S.ModelFor(gender)
	return S.Models[gender] or S.Models.male
end

function S.GenderOf(model)
	return model == S.Models.female and 'female' or 'male'
end

-- Aparência inicial. `components`/`props` podem vir do ped (natives) para começar com uma roupa válida.
function S.Default(gender, components, props)
	local female = gender == 'female'
	local overlays = {}
	for index, overlay in ipairs(S.Overlays) do
		overlays[index] = { style = -1, opacity = 1.0, color = 0, secondColor = 0 }
		if overlay.key == 'eyebrows' then
			overlays[index].style = female and 1 or 0
		end
	end
	local features = {}
	for index = 1, S.FaceFeatures do
		features[index] = 0.0
	end
	return S.Normalize({
		model = S.ModelFor(gender),
		heritage = { mother = female and 21 or 25, father = female and 0 or 4, shapeMix = female and 0.2 or 0.8, skinMix = 0.5 },
		features = features,
		overlays = overlays,
		hair = { style = female and 4 or 2, texture = 0, color = 0, highlight = 0 },
		eyeColor = 0,
		components = components or {},
		props = props or {}
	})
end

local function normalizeParts(raw, list, allowNone)
	local parts = {}
	if type(raw) ~= 'table' then
		return parts
	end
	for _, part in ipairs(list) do
		local entry = raw[tostring(part.id)] or raw[part.id]
		if type(entry) == 'table' then
			parts[tostring(part.id)] = {
				drawable = int(entry.drawable, allowNone and -1 or 0, MAX_DRAWABLE, allowNone and -1 or 0),
				texture = int(entry.texture, 0, MAX_TEXTURE, 0)
			}
		end
	end
	return parts
end

-- Normaliza qualquer entrada para a versão atual. Devolve a aparência ou nil, erro.
function S.Normalize(raw)
	if type(raw) ~= 'table' then
		return nil, 'invalid_appearance'
	end
	local model = raw.model
	if model ~= S.Models.male and model ~= S.Models.female then
		return nil, 'invalid_model'
	end
	local heritage = type(raw.heritage) == 'table' and raw.heritage or {}
	local hair = type(raw.hair) == 'table' and raw.hair or {}
	local features = {}
	for index = 1, S.FaceFeatures do
		features[index] = float(type(raw.features) == 'table' and raw.features[index] or 0, -1.0, 1.0, 0.0)
	end
	local overlays = {}
	for index, overlay in ipairs(S.Overlays) do
		local entry = type(raw.overlays) == 'table' and raw.overlays[index] or nil
		entry = type(entry) == 'table' and entry or {}
		overlays[index] = {
			style = int(entry.style, -1, overlay.max, -1),
			opacity = float(entry.opacity, 0.0, 1.0, 1.0),
			color = int(entry.color, 0, MAX_COLOR, 0),
			secondColor = int(entry.secondColor, 0, MAX_COLOR, 0)
		}
	end
	return {
		model = model,
		heritage = {
			mother = int(heritage.mother, 0, 45, 21),
			father = int(heritage.father, 0, 45, 0),
			shapeMix = float(heritage.shapeMix, 0.0, 1.0, 0.5),
			skinMix = float(heritage.skinMix, 0.0, 1.0, 0.5)
		},
		features = features,
		overlays = overlays,
		hair = {
			style = int(hair.style, 0, MAX_DRAWABLE, 0),
			texture = int(hair.texture, 0, MAX_TEXTURE, 0),
			color = int(hair.color, 0, MAX_COLOR, 0),
			highlight = int(hair.highlight, 0, MAX_COLOR, 0)
		},
		eyeColor = int(raw.eyeColor, 0, 31, 0),
		components = normalizeParts(raw.components, S.Components, false),
		props = normalizeParts(raw.props, S.Props, true)
	}
end

-- Sorteio coerente para o botão "Aleatório" (rand: função como math.random, injetável nos testes).
function S.Randomize(base, rand)
	rand = rand or math.random
	local appearance = S.Normalize(base) or S.Default('male')
	local female = appearance.model == S.Models.female
	local mothers, fathers = S.Mothers, S.Fathers
	appearance.heritage = {
		mother = mothers[rand(#mothers)][1], father = fathers[rand(#fathers)][1],
		shapeMix = rand(0, 100) / 100, skinMix = rand(0, 100) / 100
	}
	for index = 1, S.FaceFeatures do
		appearance.features[index] = (rand(0, 60) - 30) / 100
	end
	appearance.hair.color = rand(0, 20)
	appearance.hair.highlight = appearance.hair.color
	appearance.eyeColor = rand(0, 8)
	for index, overlay in ipairs(S.Overlays) do
		local entry = appearance.overlays[index]
		if overlay.key == 'eyebrows' then
			entry.style, entry.color, entry.opacity = rand(0, overlay.max), appearance.hair.color, 1.0
		elseif overlay.key == 'beard' then
			entry.style = (not female and rand(1, 2) == 1) and rand(0, overlay.max) or -1
			entry.color, entry.opacity = appearance.hair.color, 1.0
		elseif overlay.key == 'ageing' or overlay.key == 'freckles' or overlay.key == 'blemishes' then
			entry.style = rand(1, 3) == 1 and rand(0, overlay.max) or -1
			entry.opacity = rand(20, 70) / 100
		end
	end
	return S.Normalize(appearance)
end
