-- Tabelas de saque. Os scripts de roubo (residência, pedestre, veículo, comércio) chamam `Give(playerId, tabela)` ou
-- `Roll(tabela)` em vez de ter a própria lista; aqui fica o que cai e com que chance.
-- Cada sorteio (`rolls`, de min a max) escolhe uma entrada pelo peso (`weight`). `nothing = true` é sorteio vazio.
-- `min`/`max`: quantidade (padrão 1). `unique = true`: item que não empilha (cada unidade entra separada).
LootConfig = {
	-- Resources que podem dar saque a um jogador (Give) ou sortear (Roll). O nome vem do runtime.
	Callers = { coe_heists = true, coe_robbery = true, coe_admin = true },

	-- Comando de teste para a staff: `coe_loot_test <tabela>` dá o saque a si mesmo (ACE command.coe_loot_test).
	TestCommand = 'coe_loot_test',

	Tables = {
		-- Gavetas, armários e escrivaninha de uma casa.
		house_robbery = {
			label = 'Roubo a residência',
			rolls = { min = 2, max = 4 },
			entries = {
				{ item = 'money', weight = 30, min = 80, max = 600 },
				{ item = 'phone', weight = 12, unique = true },
				{ item = 'laptop', weight = 6, unique = true },
				{ item = 'usb_black', weight = 10, unique = true },
				{ item = 'onion_usb', weight = 4, unique = true },
				{ item = 'bandage', weight = 8, min = 1, max = 3 },
				{ item = 'cigarettes_redwood', weight = 8 },
				{ nothing = true, weight = 22 }
			}
		},
		-- Assalto a pedestre: bolsos e mochila.
		pedestrian_robbery = {
			label = 'Assalto a pedestre',
			rolls = { min = 1, max = 2 },
			entries = {
				{ item = 'money', weight = 50, min = 20, max = 250 },
				{ item = 'phone', weight = 15, unique = true },
				{ item = 'usb_black', weight = 5, unique = true },
				{ item = 'onion_usb', weight = 3, unique = true },
				{ item = 'cigarette', weight = 8, min = 1, max = 4 },
				{ nothing = true, weight = 19 }
			}
		},
		-- Arrombamento de carro: banco de trás e porta-luvas.
		vehicle_break_in = {
			label = 'Arrombamento de veículo',
			rolls = { min = 1, max = 2 },
			entries = {
				{ item = 'money', weight = 20, min = 10, max = 150 },
				{ item = 'laptop', weight = 5, unique = true },
				{ item = 'phone', weight = 8, unique = true },
				{ item = 'usb_black', weight = 8, unique = true },
				{ item = 'onion_usb', weight = 3, unique = true },
				{ item = 'repairkit', weight = 6 },
				{ nothing = true, weight = 50 }
			}
		},
		-- Caixa e escritório de comércio.
		store_robbery = {
			label = 'Assalto a comércio',
			rolls = { min = 1, max = 2 },
			entries = {
				{ item = 'money', weight = 70, min = 300, max = 1500 },
				{ item = 'usb_black', weight = 10, unique = true },
				{ item = 'onion_usb', weight = 5, unique = true },
				{ nothing = true, weight = 15 }
			}
		}
	}
}
