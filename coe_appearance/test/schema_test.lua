dofile('shared/schema.lua')

local S = AppearanceSchema
local failures = 0
local function eq(actual, expected, message)
	if actual ~= expected then
		failures = failures + 1
		print(('FAIL %s: esperado %s, obtido %s'):format(message, tostring(expected), tostring(actual)))
	end
end

-- Modelos
eq(S.ModelFor('female'), 'mp_f_freemode_01', 'modelo feminino')
eq(S.ModelFor('outro'), 'mp_m_freemode_01', 'gênero desconhecido usa o masculino')
eq(S.GenderOf('mp_f_freemode_01'), 'female', 'gênero pelo modelo')

-- Padrão
local male = S.Default('male')
eq(male.model, 'mp_m_freemode_01', 'padrão masculino')
eq(#male.features, 20, '20 ajustes do rosto')
eq(#male.overlays, #S.Overlays, 'todas as sobreposições')
eq(male.overlays[2].style, -1, 'sem barba no padrão')
eq(male.overlays[3].style, 0, 'sobrancelha no padrão')
local female = S.Default('female', { ['11'] = { drawable = 5, texture = 1 } }, { ['0'] = { drawable = -1, texture = 0 } })
eq(female.components['11'].drawable, 5, 'roupa vinda do ped')
eq(female.props['0'].drawable, -1, 'acessório vazio')

-- Normalização: faixas, tipos e lixo
local raw = {
	model = 'mp_m_freemode_01',
	heritage = { mother = 99, father = -4, shapeMix = 1.7, skinMix = '0.333' },
	features = { 2, -3, 0.123456, 'x' },
	overlays = { { style = 500, opacity = 3, color = 99 }, { style = -9 } },
	hair = { style = 12.6, texture = -1, color = 70, highlight = 'a' },
	eyeColor = 40,
	components = { ['11'] = { drawable = 9999, texture = 2 }, ['2'] = { drawable = 3, texture = 0 }, ['4'] = 'x' },
	props = { ['1'] = { drawable = -5, texture = 0 }, ['99'] = { drawable = 1 } },
	admin = true
}
local normalized = S.Normalize(raw)
eq(normalized.heritage.mother, 45, 'mãe limitada a 45')
eq(normalized.heritage.father, 0, 'pai limitado a 0')
eq(normalized.heritage.shapeMix, 1.0, 'mistura limitada a 1')
eq(normalized.heritage.skinMix, 0.33, 'texto numérico arredondado')
eq(normalized.features[1], 1.0, 'ajuste limitado a 1')
eq(normalized.features[2], -1.0, 'ajuste limitado a -1')
eq(normalized.features[3], 0.12, 'duas casas decimais')
eq(normalized.features[4], 0.0, 'ajuste inválido zera')
eq(normalized.features[20], 0.0, 'ajustes ausentes zerados')
eq(normalized.overlays[1].style, 23, 'estilo limitado ao máximo da sobreposição')
eq(normalized.overlays[1].opacity, 1.0, 'opacidade limitada')
eq(normalized.overlays[1].color, 63, 'cor limitada')
eq(normalized.overlays[2].style, -1, 'estilo abaixo de -1 vira nenhum')
eq(normalized.hair.style, 13, 'cabelo arredondado')
eq(normalized.hair.texture, 0, 'textura negativa')
eq(normalized.hair.highlight, 0, 'luzes inválidas')
eq(normalized.eyeColor, 31, 'cor dos olhos limitada')
eq(normalized.components['11'].drawable, 511, 'roupa limitada')
eq(normalized.components['2'], nil, 'cabelo não entra em roupas')
eq(normalized.components['4'], nil, 'peça inválida descartada')
eq(normalized.props['1'].drawable, -1, 'acessório negativo vira nenhum')
eq(normalized.props['99'], nil, 'acessório desconhecido descartado')
eq(normalized.admin, nil, 'chave desconhecida descartada')
eq(select(2, S.Normalize({ model = 'a_m_y_hipster_01' })), 'invalid_model', 'só modelos freemode')
eq(select(2, S.Normalize('x')), 'invalid_appearance', 'não é tabela')

-- Idempotente
local again = S.Normalize(normalized)
eq(again.heritage.skinMix, normalized.heritage.skinMix, 'normalizar duas vezes não muda')
eq(again.components['11'].drawable, 511, 'roupa preservada')

-- Aleatório coerente e determinístico com rand injetado
local seed = 0
local function rand(a, b)
	seed = seed + 1
	if not b then
		return (seed % a) + 1
	end
	return a + (seed % (b - a + 1))
end
local random = S.Randomize(S.Default('female'), rand)
eq(random.model, 'mp_f_freemode_01', 'aleatório mantém o gênero')
eq(random.overlays[2].style, -1, 'personagem feminina sem barba')
eq(random.overlays[3].color, random.hair.color, 'sobrancelha na cor do cabelo')
local validMother = false
for _, entry in ipairs(S.Mothers) do
	if entry[1] == random.heritage.mother then validMother = true end
end
eq(validMother, true, 'mãe sorteada da lista')

-- Retratos
eq(S.Portrait(0), 'male_0', 'retrato pai')
eq(S.Portrait(21), 'female_0', 'retrato mãe')
eq(S.Portrait(43), 'special_male_1', 'retrato Niko')
eq(S.Portrait(45), 'special_female_0', 'retrato Misty')

-- Catálogo
local seen = {}
for _, group in ipairs(S.FeatureGroups) do
	for _, feature in ipairs(group.features) do
		eq(seen[feature[1]], nil, 'ajuste sem repetição ' .. feature[1])
		seen[feature[1]] = true
	end
end
for index = 0, 19 do
	eq(seen[index], true, 'ajuste no criador ' .. index)
end

-- Subcategorias de roupa: cada peça em exatamente uma
local seen = {}
for _, category in ipairs(S.ClothingCategories) do
	for _, part in ipairs(category.parts) do
		local key = part.kind .. part.id
		eq(seen[key], nil, 'peça repetida nas subcategorias: ' .. key)
		seen[key] = true
	end
end
for _, component in ipairs(S.Components) do eq(seen['component' .. component.id], true, 'componente sem subcategoria ' .. component.id) end
for _, prop in ipairs(S.Props) do eq(seen['prop' .. prop.id], true, 'prop sem subcategoria ' .. prop.id) end

-- Nomes das fotos
eq(S.ThumbName('female', 'prop', 0, 3), 'female_p0_3.webp', 'nome da foto de prop')
eq(S.ThumbName('male', 'component', 11, 12), 'male_c11_12.webp', 'nome da foto de roupa')
local g, k, i, d = S.ParseThumbName('male_c11_12.webp')
eq(g, 'male', 'gênero do nome'); eq(k, 'component', 'tipo do nome'); eq(i, 11, 'id do nome'); eq(d, 12, 'drawable do nome')
eq(S.ParseThumbName('../server.lua'), nil, 'caminho estranho recusado')
eq(S.ParseThumbName('male_c2_1.webp'), nil, 'componente fora do catálogo (cabelo) recusado')
eq(S.ParseThumbName('male_c11_1.png'), nil, 'extensão diferente recusada')
eq(S.ParseThumbName('alien_c11_1.webp'), nil, 'gênero desconhecido recusado')
eq(S.ParseThumbName('male_c11_5000.webp'), nil, 'drawable absurdo recusado')

if failures > 0 then
	error(('schema_test: %d falha(s)'):format(failures))
end
print('schema_test: ok')
