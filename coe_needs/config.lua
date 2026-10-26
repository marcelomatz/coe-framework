Config = Config or {}

-- Necessidades do personagem: fome, sede, estresse, alcool e drogas (0 a 100).
-- Fome/sede: 100 = saciado, 0 = esgotado. Estresse/alcool/drogas: 0 = limpo/calmo, 100 = limite maximo.
Config.Locale = 'pt-BR'

Config.Needs = {
	Names = { 'hunger', 'thirst', 'stress', 'alcohol', 'drugs' },
	Initial = { hunger = 90, thirst = 90, stress = 10, alcohol = 0, drugs = 0 },
	-- Variacao por minuto em cada atividade do personagem.
	Rates = {
		idle      = { hunger = -0.35, thirst = -0.5, stress = -0.6, alcohol = -1.5, drugs = -1.2 },
		walk      = { hunger = -0.5,  thirst = -0.7, stress = -0.2, alcohol = -1.8, drugs = -1.5 },
		run       = { hunger = -0.8,  thirst = -1.2, stress =  0.0, alcohol = -2.2, drugs = -1.8 },
		sprint    = { hunger = -1.2,  thirst = -1.8, stress =  0.2, alcohol = -2.5, drugs = -2.0 },
		swim      = { hunger = -1.0,  thirst = -1.4, stress = -0.1, alcohol = -2.2, drugs = -1.8 },
		drive     = { hunger = -0.4,  thirst = -0.6, stress =  0.1, alcohol = -1.5, drugs = -1.2 },
		driveFast = { hunger = -0.5,  thirst = -0.7, stress =  0.8, alcohol = -1.5, drugs = -1.2 },
		combat    = { hunger = -0.9,  thirst = -1.3, stress =  1.8, alcohol = -2.0, drugs = -1.5 }
	},
	-- Efeito de consumir itens do inventario (evento inventory.itemUsed).
	-- Cada item pode configurar: hunger, thirst, stress, alcohol, drugs, energy (stamina/sprint), health, armor e durationMs.
	ItemEffects = {
		-- Alimentos
		bread              = { hunger = 20, thirst = -2, durationMs = 2600 },
		burger             = { hunger = 35, thirst = -5, stress = -5, durationMs = 3000 },
		burger_chicken     = { hunger = 35, thirst = -5, stress = -5, durationMs = 3000 },
		sandwich           = { hunger = 25, thirst = -3, stress = -3, durationMs = 2800 },
		pizza_ham          = { hunger = 45, thirst = -5, stress = -6, durationMs = 3500 },
		pizza_ham_slice    = { hunger = 22, thirst = -3, stress = -3, durationMs = 2600 },
		donut              = { hunger = 15, stress = -8, durationMs = 2400 },
		fries              = { hunger = 18, thirst = -6, durationMs = 2500 },
		chips              = { hunger = 14, thirst = -5, durationMs = 2400 },
		chocolate          = { hunger = 12, stress = -10, durationMs = 2200 },
		cereal_bar         = { hunger = 16, stress = -4, durationMs = 2200 },
		mustard            = { hunger = 5, thirst = -4, durationMs = 2000 },
		-- Bebidas e energeticos
		water              = { thirst = 30, durationMs = 2500 },
		sprunk             = { thirst = 25, hunger = 3, stress = -4, durationMs = 2600 },
		ecola              = { thirst = 25, hunger = 4, stress = -4, durationMs = 2600 },
		coffee             = { thirst = 15, stress = -12, energy = 15, durationMs = 2800 },
		energy_drink       = { thirst = 25, stress = 5, alcohol = -5, energy = 30, durationMs = 2800 },
		-- Bebidas alcoolicas
		beer               = { thirst = 15, stress = -12, alcohol = 18, durationMs = 3000 },
		whiskey            = { thirst = 8, stress = -20, alcohol = 35, durationMs = 3200 },
		vodka              = { thirst = 8, stress = -22, alcohol = 40, durationMs = 3200 },
		-- Tabaco e substancias (drogas)
		cigarette          = { stress = -18, thirst = -4, durationMs = 3800 },
		cigarettes_redwood = { stress = -20, thirst = -4, durationMs = 3800 },
		weed               = { stress = -30, hunger = -8, thirst = -6, drugs = 25, durationMs = 3800 },
		cocaine            = { stress = 10, hunger = -10, thirst = -12, drugs = 45, energy = 25, durationMs = 3200 },
		meth               = { stress = 18, hunger = -15, thirst = -15, drugs = 55, energy = 30, durationMs = 3200 },
		-- Medicos e protecao
		bandage            = { stress = -10, health = 25, durationMs = 3200 },
		medikit            = { stress = -20, health = 60, durationMs = 4000 },
		painkillers        = { stress = -25, drugs = 8, health = 15, durationMs = 2400 },
		armour             = { armor = 50, durationMs = 3500 }
	},
	-- Acima de FastDriveSpeedKmh no volante conta como direcao em alta velocidade (gera estresse).
	FastDriveSpeedKmh = 140,
	-- Servidor avisa o client e persiste no banco.
	TickIntervalMs = 5000,
	SaveIntervalMs = 60000,
	MaxElapsedSeconds = 30,
	ActivityMinIntervalMs = 400,
	-- Efeitos no client quando as barras chegam aos extremos.
	Effects = {
		IntervalMs = 6000,
		StarveDamage = 2,
		DehydrateDamage = 3,
		StressShakeThreshold = 75,
		StressShakeIntensity = 0.18,
		Alcohol = {
			Threshold = 30,
			HeavyThreshold = 65,
			ShakeIntensity = 0.25,
			HeavyShakeIntensity = 0.55,
			Timecycle = 'spectator5'
		},
		Drugs = {
			Threshold = 25,
			HeavyThreshold = 60,
			ShakeIntensity = 0.20,
			HeavyShakeIntensity = 0.45,
			Timecycle = 'drug_flying_base'
		},
		Energy = {
			SprintMultiplier = 1.15,
			DurationPerPointMs = 1000
		}
	},
	-- Quem pode chamar SetNeed / AddNeed. O nome vem de GetInvokingResource().
	-- Outros resources podem ser autorizados no server.cfg com: add_ace resource.<nome> coe.needs allow
	Ace = 'coe.needs',
	AllowedResources = {
		coe_needs = true,
		coe_inventory = true,
		coe_shops = true,
		coe_staff = true
	}
}
