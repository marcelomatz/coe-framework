-- Pescador (pesca livre): com a vara do inventário, pesca de qualquer ponto virado para a água dentro das áreas de
-- pesca (píer de Del Perro, píer de Paleto Cove, litoral de Chumash, doca do Alamo Sea e represa do Land Act).
-- Cada lance gasta uma isca; quando o peixe morde, um minigame decide se ele vem. Varas e iscas são itens do
-- coe_inventory vendidos na loja de pesca; as melhores pedem nível no emprego e trazem mais peixes raros.
-- Usar a vara dentro de uma área já começa o trabalho (não precisa ir ao NPC). Os peixes são carga do trabalho e
-- se vendem nos compradores do mapa. Coordenadas provisórias (exceto Del Perro): confira no jogo e ajuste.

-- Equipamento: o nível é o do emprego de pescador (1 a 5). speed multiplica a espera pela mordida; window é a
-- largura da faixa do minigame (0-1); rarity soma no peso dos peixes raros; keep é a chance de a isca sobrar.
local RODS = {
	{ item = 'fishing_rod', label = 'Vara de bambu', price = 120, level = 1, speed = 1.0, window = 0.16, rarity = 0,
		description = 'Vara simples para começar. Faixa estreita no minigame.' },
	{ item = 'fishing_rod_fiber', label = 'Vara de fibra', price = 650, level = 2, speed = 0.85, window = 0.21, rarity = 0.15,
		description = 'Mais leve: o peixe morde antes e a fisgada é mais fácil.' },
	{ item = 'fishing_rod_carbon', label = 'Vara de carbono', price = 1800, level = 4, speed = 0.7, window = 0.27, rarity = 0.35,
		description = 'Profissional: mordida rápida, faixa larga e mais peixes raros.' }
}
local BAITS = {
	{ item = 'bait_bread', label = 'Isca de pão', price = 2, level = 1, speed = 1.0, rarity = 0, max = 50,
		description = 'Barata e fácil de achar. Atrai os peixes comuns.' },
	{ item = 'bait_worm', label = 'Minhoca', price = 5, level = 2, speed = 0.9, rarity = 0.2, max = 50,
		description = 'Peixe morde mais rápido e aparecem mais espécies médias.' },
	{ item = 'bait_shrimp', label = 'Camarão', price = 9, level = 3, speed = 0.85, rarity = 0.45, max = 50,
		description = 'Isca nobre: bem mais chance de peixe grande.' },
	{ item = 'bait_lure', label = 'Isca artificial', price = 260, level = 5, speed = 0.9, rarity = 0.6, keep = 0.85, max = 5,
		description = 'Reaproveitável: só se perde em 15% dos lances. A melhor para raros.' }
}

local function percent(value)
	return math.floor(value * 100 + 0.5)
end

-- Loja: os mesmos itens, com os efeitos em texto para a vitrine.
local shopItems = {}
for _, rod in ipairs(RODS) do
	shopItems[#shopItems + 1] = {
		item = rod.item, label = rod.label, price = rod.price, level = rod.level, max = 1, kind = 'rod', description = rod.description,
		stats = {
			rod.speed < 1 and ('Mordida %d%% mais rápida'):format(percent(1 - rod.speed)) or 'Mordida normal',
			('Faixa da fisgada: %d%%'):format(percent(rod.window)),
			rod.rarity > 0 and ('Peixes raros: +%d%%'):format(percent(rod.rarity)) or 'Sem bônus de raros'
		}
	}
end
for _, bait in ipairs(BAITS) do
	shopItems[#shopItems + 1] = {
		item = bait.item, label = bait.label, price = bait.price, level = bait.level, max = bait.max, kind = 'bait', description = bait.description,
		stats = {
			bait.speed < 1 and ('Mordida %d%% mais rápida'):format(percent(1 - bait.speed)) or 'Mordida normal',
			bait.rarity > 0 and ('Peixes raros: +%d%%'):format(percent(bait.rarity)) or 'Sem bônus de raros',
			(bait.keep or 0) > 0 and ('Sobra em %d%% dos lances'):format(percent(bait.keep)) or 'Gasta uma por lance'
		}
	}
end

JobsCatalog[#JobsCatalog + 1] = {
	id = 'fisher',
	label = 'Pescador',
	description = 'Pesque do píer, do litoral e dos lagos com a sua vara e venda os peixes. Varas e iscas na loja de pesca.',
	kind = 'gather',
	center = { -1806.5, -1196.0, 13.0, 50.0 },
	centerPed = 's_m_m_cntrybar_01',
	blip = { sprite = 68, color = 3 },
	levels = { 0, 150, 450, 1000, 2000 },
	levelBonus = 0.05,
	skills = { 'outdoor' },
	-- Dicas extras do guia "Como funciona" (o passo a passo sai da própria definição).
	tips = {
		'Compre uma vara e iscas na loja de pesca. Use a isca no inventário para escolher qual vai no anzol.',
		'Fique de frente para a água: do alto do píer também funciona.',
		'Quando morder, aperte E com o marcador dentro da faixa verde. Errar perde o peixe e a isca.',
		'Lagos (Alamo Sea, Land Act) têm peixes de água doce; o mar tem os seus. Os raros valem bem mais.',
		'Pescar treina Campo, que deixa as ações de coleta mais rápidas em todos os empregos.'
	},
	uniform = {
		label = 'Roupa de pescador',
		male = { components = { [4] = { 36, 0 }, [6] = { 27, 0 }, [11] = { 69, 0 }, [8] = { 15, 0 }, [3] = { 1, 0 } }, props = { [0] = { 5, 0 } } },
		female = { components = { [4] = { 35, 0 }, [6] = { 26, 0 }, [11] = { 63, 0 }, [8] = { 14, 0 }, [3] = { 3, 0 } }, props = { [0] = { 5, 0 } } }
	},
	-- Loja de pesca (itens do coe_inventory). Paga em dinheiro vivo ou, sem ele, no banco.
	shop = {
		label = 'Loja de pesca',
		ped = 's_m_m_cntrybar_01',
		points = { { -1813.8, -1202.6, 13.0, 50.0 }, { 1309.4, 4230.2, 33.9, 260.0 }, { -1594.6, 5249.8, 4.0, 60.0 } },
		items = shopItems
	},
	gather = {
		actionLabel = 'Pescar',
		seconds = 12,
		capacity = 25,
		xp = 4,
		unit = 'peixe',
		units = 'peixes',
		order = { 'sardinha', 'cavala', 'robalo', 'pargo', 'atum', 'tilapia', 'bagre', 'carpa', 'truta', 'esturjao' },
		products = {
			-- Mar
			sardinha = { label = 'Sardinha', unit = 'sardinha', units = 'sardinhas', price = 12, tier = 'common', xp = 4 },
			cavala = { label = 'Cavala', unit = 'cavala', units = 'cavalas', price = 17, tier = 'common', xp = 4 },
			robalo = { label = 'Robalo', unit = 'robalo', units = 'robalos', price = 32, tier = 'uncommon', xp = 6 },
			pargo = { label = 'Pargo', unit = 'pargo', units = 'pargos', price = 38, tier = 'uncommon', xp = 6 },
			atum = { label = 'Atum', unit = 'atum', units = 'atuns', price = 95, tier = 'rare', xp = 10 },
			-- Água doce
			tilapia = { label = 'Tilápia', unit = 'tilápia', units = 'tilápias', price = 12, tier = 'common', xp = 4 },
			bagre = { label = 'Bagre', unit = 'bagre', units = 'bagres', price = 17, tier = 'common', xp = 4 },
			carpa = { label = 'Carpa', unit = 'carpa', units = 'carpas', price = 30, tier = 'uncommon', xp = 6 },
			truta = { label = 'Truta', unit = 'truta', units = 'trutas', price = 36, tier = 'uncommon', xp = 6 },
			esturjao = { label = 'Esturjão', unit = 'esturjão', units = 'esturjões', price = 100, tier = 'rare', xp = 10 }
		},
		fishing = {
			actionLabel = 'Pescar',
			-- Arremesso (s), espera pela mordida (s, antes dos bônus), tempo para fisgar quando morde (s) e duração máxima
			-- da briga com o peixe (s). A briga em si (faixa, agitação, progresso) sai de JobRules.FightParams.
			castSeconds = 1.5,
			biteSeconds = { 6, 14 },
			hookSeconds = 1.6,
			fightSeconds = 35,
			rods = RODS,
			baits = BAITS,
			areas = {
				{ -1845.0, -1255.0, 8.6, radius = 75.0, label = 'Píer de Del Perro', water = 'sea',
					species = { sardinha = 40, cavala = 30, robalo = 15, pargo = 10, atum = 3 } },
				{ -1605.0, 5258.0, 3.5, radius = 70.0, label = 'Píer de Paleto Cove', water = 'sea',
					species = { sardinha = 25, cavala = 30, robalo = 20, pargo = 15, atum = 6 } },
				{ -3200.0, 1000.0, 5.0, radius = 160.0, label = 'Litoral de Chumash', water = 'sea',
					species = { sardinha = 15, cavala = 30, robalo = 25, pargo = 20, atum = 8 } },
				{ 1300.0, 4225.0, 33.0, radius = 110.0, label = 'Doca do Alamo Sea', water = 'fresh',
					species = { tilapia = 40, bagre = 30, carpa = 18, truta = 6, esturjao = 3 } },
				{ 1700.0, 40.0, 160.0, radius = 170.0, label = 'Represa do Land Act', water = 'fresh',
					species = { tilapia = 30, bagre = 15, carpa = 20, truta = 25, esturjao = 4 } }
			}
		},
		sell = {
			label = 'Vender peixes',
			ped = 's_m_y_chef_01',
			points = { { -1834.5, -1190.6, 14.3, 330.0 }, { 1316.2, 4236.4, 33.9, 260.0 }, { -1600.4, 5244.0, 4.0, 60.0 } }
		}
	}
}
