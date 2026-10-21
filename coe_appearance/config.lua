AppearanceConfig = {
	-- Sala do criador de personagem do GTA Online (o "lineup" com a parede de altura). Posição do ped e direção.
	-- Se mudar de lugar, ajuste o ped e as câmeras; a câmera é sempre relativa ao ped.
	Creator = {
		Ped = { x = 402.89, y = -996.87, z = -99.0, heading = 180.0 },
		-- Ponto que mantém o streaming e a colisão carregados enquanto o criador está aberto.
		Focus = { x = 402.89, y = -999.0, z = -99.0 },
		-- Câmeras: distância à frente do ped, altura e alvo relativos ao centro do ped (quadril), campo de visão.
		Cameras = {
			body = { distance = 3.2, height = 0.15, target = 0.0, fov = 38.0 },
			upper = { distance = 1.75, height = 0.55, target = 0.45, fov = 34.0 },
			face = { distance = 0.85, height = 0.68, target = 0.66, fov = 28.0 },
			legs = { distance = 1.9, height = -0.45, target = -0.55, fov = 36.0 }
		},
		-- Câmera de cada etapa do criador.
		StepCamera = { identity = 'body', heritage = 'face', face = 'face', details = 'face', hair = 'face', clothes = 'body', review = 'body' },
		InterpolationMs = 700,
		-- Animação de espera (como no GTA Online); sem ela o ped fica parado.
		Idle = {
			male = { dict = 'mp_character_creation@customise@male_a', anim = 'loop' },
			female = { dict = 'mp_character_creation@customise@female_a', anim = 'loop' }
		},
		-- Desfoque de profundidade nas câmeras do criador.
		DepthOfField = true,
		-- Hora congelada localmente enquanto o criador está aberto (só afeta este jogador).
		Clock = { hour = 12, minute = 0 }
	},

	-- Conjuntos prontos na etapa Roupas. Valores são drawable/textura por peça (ids em AppearanceSchema.Components);
	-- confira no jogo: variam com DLCs e addons de roupa. Peças ausentes ficam como estão.
	Outfits = {
		male = {
			{ id = 'casual', label = 'Casual', components = { ['11'] = { 1, 0 }, ['8'] = { 15, 0 }, ['3'] = { 0, 0 }, ['4'] = { 0, 0 }, ['6'] = { 1, 0 } } },
			{ id = 'street', label = 'Rua', components = { ['11'] = { 7, 0 }, ['8'] = { 15, 0 }, ['3'] = { 0, 0 }, ['4'] = { 4, 0 }, ['6'] = { 1, 1 } } },
			{ id = 'social', label = 'Social', components = { ['11'] = { 4, 0 }, ['8'] = { 4, 0 }, ['3'] = { 4, 0 }, ['4'] = { 10, 0 }, ['6'] = { 10, 0 } } }
		},
		female = {
			{ id = 'casual', label = 'Casual', components = { ['11'] = { 0, 0 }, ['8'] = { 14, 0 }, ['3'] = { 0, 0 }, ['4'] = { 0, 0 }, ['6'] = { 1, 0 } } },
			{ id = 'street', label = 'Rua', components = { ['11'] = { 3, 0 }, ['8'] = { 14, 0 }, ['3'] = { 3, 0 }, ['4'] = { 4, 0 }, ['6'] = { 3, 0 } } },
			{ id = 'social', label = 'Social', components = { ['11'] = { 6, 0 }, ['8'] = { 14, 0 }, ['3'] = { 5, 0 }, ['4'] = { 6, 0 }, ['6'] = { 0, 0 } } }
		}
	},

	-- Fotos das peças na etapa Roupas. A NUI busca `Base .. AppearanceSchema.ThumbName(...)`; sem foto, o card mostra
	-- o número da peça. As fotos são geradas no próprio servidor com o comando abaixo (precisa do screenshot-basic e
	-- da ACE `Ace`), salvas em coe_appearance/thumbs/ e entregues aos jogadores depois de reiniciar o recurso.
	-- Base também pode ser uma URL https (CDN) com os mesmos nomes de arquivo.
	Thumbnails = {
		Enabled = true,
		Base = 'nui://coe_appearance/thumbs/',
		Extension = 'webp',
		Size = 256, -- lado da foto quadrada, em pixels
		Quality = 0.8, -- qualidade do webp (0 a 1)
		Crop = 0.62, -- fração da altura da tela recortada no centro
		Command = 'coe_fotos_roupas', -- /coe_fotos_roupas [male|female] [refazer]
		Ace = 'coe_appearance.thumbs',
		SettleMs = 250, -- espera depois de vestir a peça, antes da foto
		MaxBytes = 300000, -- tamanho máximo aceito pelo servidor por foto
		-- Câmeras da foto (relativas ao quadril do ped, como em Creator.Cameras). `back` fotografa de costas.
		Cameras = {
			torso = { distance = 1.35, height = 0.35, target = 0.3, fov = 40.0 },
			legs = { distance = 1.55, height = -0.4, target = -0.45, fov = 40.0 },
			feet = { distance = 1.0, height = -0.6, target = -0.85, fov = 40.0 },
			head = { distance = 0.7, height = 0.66, target = 0.64, fov = 40.0 },
			wrist = { distance = 0.8, height = 0.05, target = -0.05, fov = 40.0, side = 0.25 },
			back = { distance = 1.35, height = 0.35, target = 0.3, fov = 40.0, back = true }
		},
		-- Roupa por baixo durante as fotos, para cada peça aparecer sozinha (ids comuns do freemode; confira no jogo).
		BaseOutfit = {
			male = { ['11'] = { 15, 0 }, ['8'] = { 15, 0 }, ['3'] = { 15, 0 }, ['4'] = { 61, 0 }, ['6'] = { 34, 0 },
				['7'] = { 0, 0 }, ['5'] = { 0, 0 }, ['1'] = { 0, 0 }, ['9'] = { 0, 0 }, ['10'] = { 0, 0 } },
			female = { ['11'] = { 15, 0 }, ['8'] = { 14, 0 }, ['3'] = { 15, 0 }, ['4'] = { 17, 0 }, ['6'] = { 35, 0 },
				['7'] = { 0, 0 }, ['5'] = { 0, 0 }, ['1'] = { 0, 0 }, ['9'] = { 0, 0 }, ['10'] = { 0, 0 } }
		}
	},

	-- Limites do formulário de identidade (o servidor valida de novo no coe_core).
	Identity = { NameMin = 2, NameMax = 24, MinAge = 18, MaxAge = 90 }
}
