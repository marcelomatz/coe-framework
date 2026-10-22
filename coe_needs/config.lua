Config = Config or {}
Config.Needs = {}
local N = Config.Needs

-- hunger e thirst: 100 = saciado, 0 = esgotado. stress: 0 = calmo, 100 = no limite.
N.Names = { 'hunger', 'thirst', 'stress' }
N.Initial = { hunger = 90, thirst = 90, stress = 10 }

-- Variacao por minuto em cada atividade (negativo = consome/diminui).
-- Atividades vem do client, mas o servidor so aceita estas chaves e mede o tempo sozinho.
N.Rates = {
	idle = { hunger = -0.20, thirst = -0.30, stress = -0.60 },
	walk = { hunger = -0.35, thirst = -0.50, stress = -0.40 },
	run = { hunger = -0.70, thirst = -1.00, stress = -0.10 },
	sprint = { hunger = -1.20, thirst = -1.80, stress = 0.20 },
	swim = { hunger = -1.00, thirst = -0.80, stress = 0.10 },
	drive = { hunger = -0.25, thirst = -0.35, stress = -0.20 },
	driveFast = { hunger = -0.30, thirst = -0.40, stress = 0.80 },
	combat = { hunger = -1.00, thirst = -1.40, stress = 2.00 }
}

-- Efeito de consumir itens do inventario (evento inventory.itemUsed).
N.ItemEffects = {
	burger = { hunger = 35 },
	burger_chicken = { hunger = 35 },
	donut = { hunger = 15, stress = -3 },
	fries = { hunger = 20 },
	mustard = { hunger = 2 },
	pizza_ham = { hunger = 30 },
	pizza_ham_slice = { hunger = 15 },
	sprunk = { thirst = 30 },
	-- Lojas de conveniência (coe_shops)
	water = { thirst = 35 },
	ecola = { thirst = 30 },
	coffee = { thirst = 15, stress = -3 },
	energy_drink = { thirst = 25, stress = 3 },
	sandwich = { hunger = 30 },
	chips = { hunger = 12, thirst = -3 },
	chocolate = { hunger = 10, stress = -4 },
	cereal_bar = { hunger = 15 },
	beer = { thirst = 10, stress = -8 },
	whiskey = { thirst = -5, stress = -15 },
	vodka = { thirst = -5, stress = -15 },
	cigarette = { stress = -6 },
	cigarettes_redwood = { stress = -8 },
	painkillers = { stress = -5 }
}

-- Faixas usadas pelo client para reagir (valores em pontos).
N.Low = 20
N.Empty = 0
N.StressHigh = 60
N.StressMax = 85

-- Quem chama AddNeed/SetNeed (roubos, itens, admin...). Padrões do framework; pacotes e scripts de terceiros recebem a
-- ACE no server.cfg: add_ace resource.<nome> coe.needs allow
N.Ace = 'coe.needs'
N.AllowedResources = { coe_needs = true, coe_inventory = true }

N.TickMs = 5000
N.MaxAdvanceSeconds = 30
N.SaveIntervalMs = 60000
N.ActivityMinIntervalMs = 800
