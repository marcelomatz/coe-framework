CoeMechanicConfig = {
	-- Capacidades ACE (`add_ace resource.<nome> coe.mechanic.write allow`) e quem pode trocar peças e ajustar a quilometragem. Auditado.
	Ace = {
		Write = 'coe.mechanic.write',
		Wear = 'coe.mechanic.wear',
		Tablet = 'coe.mechanic.tablet'
	},
	WriterResources = {
		coe_admin = true,
		coe_mechanic = true
	},

	-- Quem pode somar desgaste extra às peças (AddWear): combustível.
	WearResources = {
		coe_fuel = true
	},

	-- Quem pode chamar TabletCall (o coe_tablet valida o emprego do jogador antes).
	TabletResources = {
		coe_tablet = true
	},
	-- Distância máxima entre o mecânico e o veículo para o tablet agir.
	TabletRadius = 8.0,
	-- Raio ao redor do showroom em que o mecânico atende pedidos da oficina.
	ShopWorkRadius = 40.0,

	-- Câmera do showroom: órbita em torno do veículo e câmera livre limitada à área da oficina.
	Camera = {
		FreeRadius = 30.0,
		FreeMaxHeight = 14.0,
		FreeSpeed = 4.0,
		FreeFastFactor = 3.0,
		FreeSlowFactor = 0.3,
		FreeLookSensitivity = 6.0,
		Smoothing = 7.0,
		Fov = 45.0,
		InteriorFov = 65.0
	},

	-- As oficinas vivem no registro coe_businesses: crie-as na aba "Negócios" do coe_admin (categoria Mecânicas).
	-- Esta tabela é preenchida em memória a partir do registro. O dono (por personagem) é definido no painel
	-- do negócio e também atende (se a regra `ownerAccess` permitir).
	ShopBlip = { sprite = 446, colour = 5 },
	Shops = {},
	-- Receitas das bancadas de craft das mecânicas; registradas no coe_crafting (categoria mechanic).
	Recipes = {
		mechanic = {
			{ id = 'repair_kit', label = 'Kit de reparo', category = 'mechanic', timeMs = 6000,
				inputs = { { item = 'scrapmetal', count = 4 }, { item = 'plastic', count = 2 } }, outputs = { { item = 'repair_kit', count = 1 } } },
			{ id = 'engine_oil', label = 'Óleo de motor', category = 'mechanic', timeMs = 4000,
				inputs = { { item = 'plastic', count = 2 }, { item = 'scrapmetal', count = 1 } }, outputs = { { item = 'part_engine_oil', count = 1 } } },
			{ id = 'air_filter', label = 'Filtro de ar', category = 'mechanic', timeMs = 4000,
				inputs = { { item = 'plastic', count = 2 }, { item = 'rubber', count = 1 } }, outputs = { { item = 'part_air_filter', count = 1 } } },
			{ id = 'spark_plugs', label = 'Velas de ignição', category = 'mechanic', timeMs = 5000,
				inputs = { { item = 'scrapmetal', count = 2 }, { item = 'plastic', count = 1 } }, outputs = { { item = 'part_spark_plugs', count = 1 } } },
			{ id = 'brake_pads', label = 'Pastilhas de freio', category = 'mechanic', timeMs = 7000,
				inputs = { { item = 'scrapmetal', count = 3 }, { item = 'rubber', count = 1 } }, outputs = { { item = 'part_brake_pads', count = 1 } } },
			{ id = 'brake_discs', label = 'Discos de freio', category = 'mechanic', timeMs = 9000,
				inputs = { { item = 'scrapmetal', count = 8 } }, outputs = { { item = 'part_brake_discs', count = 1 } } },
			{ id = 'clutch', label = 'Kit de embreagem', category = 'mechanic', timeMs = 12000,
				inputs = { { item = 'scrapmetal', count = 10 }, { item = 'rubber', count = 3 } }, outputs = { { item = 'part_clutch', count = 1 } } },
			{ id = 'suspension', label = 'Kit de suspensão', category = 'mechanic', timeMs = 14000,
				inputs = { { item = 'scrapmetal', count = 14 }, { item = 'rubber', count = 4 } }, outputs = { { item = 'part_suspension', count = 1 } } }
		}
	},
	-- Pedidos de serviço (orçamento). Ficam em memória; expiram sem resposta.
	Orders = {
		TtlMs = 900000,
		MaxOpenPerShop = 20,
		-- Faixa que o mecânico pode ajustar sobre a estimativa automática.
		MaxDiscount = 0.5,
		MaxMarkup = 0.5,
		MaxNoteLength = 120,
		MaxPatchBytes = 4096
	},

	-- Peças com desgaste por quilometragem. life em metros; threshold = desgaste a partir do qual há efeito.
	-- effects: multiplicador de CHandlingData no desgaste total (interpolado a partir do threshold).
	Parts = {
		engine_oil = { life = 20000, threshold = 0.5, effects = { fInitialDriveForce = 0.9, fEngineDamageMult = 1.6 } },
		air_filter = { life = 30000, threshold = 0.5, effects = { fInitialDriveForce = 0.95 } },
		spark_plugs = { life = 40000, threshold = 0.4, effects = { fInitialDriveForce = 0.93 } },
		brake_pads = { life = 35000, threshold = 0.3, effects = { fBrakeForce = 0.7 } },
		brake_discs = { life = 80000, threshold = 0.4, effects = { fBrakeForce = 0.85 } },
		clutch = { life = 90000, threshold = 0.4, effects = { fClutchChangeRateScaleUpShift = 0.7,
			fClutchChangeRateScaleDownShift = 0.7 } },
		suspension = { life = 100000, threshold = 0.4, effects = { fSuspensionForce = 0.85, fSuspensionCompDamp = 0.8,
			fSuspensionReboundDamp = 0.8, fAntiRollBarForce = 0.85 } }
	},

	-- Desgaste (0-1) a partir do qual a inspeção marca a peça.
	WarnAt = 0.6,
	CriticalAt = 0.85,

	-- Limites aceitos pelo servidor na aparência (o cliente ainda confere o que o modelo suporta).
	Appearance = {
		MaxColorIndex = 160,
		MaxModType = 49,
		MaxModIndex = 255,
		-- Toggles (17-22) têm campo próprio; 48 é a livery (campo `livery`).
		BlockedModTypes = { [17] = true, [18] = true, [19] = true, [20] = true, [21] = true, [22] = true, [48] = true },
		MaxLivery = 63,
		MaxTint = 6,
		MaxPlateIndex = 5,
		MaxWheelType = 12,
		MaxXenonColor = 12,
		MaxExtra = 14
	},

	-- Preços como fração do valor do veículo no catálogo.
	Pricing = {
		DefaultVehiclePrice = 20000,
		MinPrice = 100,
		-- Cada nível acima do primeiro encarece em IndexStep (ex.: motor nível 3).
		IndexStep = 0.25,
		ModFraction = 0.012,
		ModFractionByType = { [11] = 0.04, [12] = 0.03, [13] = 0.03, [15] = 0.02, [16] = 0.025, [23] = 0.015 },
		ColorFraction = 0.006,
		PearlFraction = 0.008,
		RgbFraction = 0.02,
		ToggleFraction = 0.03,
		LiveryFraction = 0.015,
		MinorFraction = 0.004,
		NeonFraction = 0.015,
		ClassMultipliers = { super = 1.6, sports = 1.3, sports_classics = 1.3, muscle = 1.1, compacts = 0.8 }
	}
}
