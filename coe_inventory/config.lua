-- Configuração do coe_inventory — único arquivo que o administrador precisa editar.
--
-- Todas as chaves são OPCIONAIS: o que for omitido usa o padrão definido em
-- `domain/config_schema.lua`. Valores inválidos (tipo errado ou fora da faixa) são
-- ignorados, o padrão é usado no lugar e o motivo aparece no console como
-- `[coe_inventory] config: ...`.
--
-- Atenção: este arquivo é carregado no servidor E no cliente. Não coloque segredos aqui.
Config = {
	Locale = 'pt-BR',
	-- Interface e comportamento do jogador (lidos pelo cliente).
	Client = {
		openKey = 'I', -- tecla padrão para abrir o inventário (o jogador pode remapear)
		hotbarKey = 'TAB', -- tecla padrão para exibir a hotbar rápida (1..N) na tela
		cancelKey = 'X', -- tecla padrão para cancelar o consumo de um item em andamento
		hotbarSlots = 5, -- quantidade de atalhos de hotbar (teclas 1..N), de 1 a 9
		hotbarPreviewMs = 3000, -- duração (ms) em que a hotbar fica visível ao pressionar TAB
		defaultConsumeTimeMs = 3000, -- tempo padrão (ms) para consumir um item
		targetDistance = 3.0, -- distância (m) para Abrir/Pegar no target (não passe de Server.worldInteractDistance)
		placementRange = 4.0, -- alcance (m) da mira ao posicionar uma maleta no mundo
		placementPreviewAlpha = 150, -- transparência do preview ao posicionar (0-255)
		streamTimeoutMs = 5000, -- tempo máximo (ms) para carregar modelo/animação
		networkControlTimeoutMs = 500 -- tempo máximo (ms) para assumir controle de rede de um prop
	},

	-- Tempo de consumo (ms) configurável por item consumível.
	Consumables = {
		items = {
			water = 2500,
			bread = 2600,
			burger = 3000,
			burger_chicken = 3000,
			sandwich = 2800,
			pizza_ham = 3500,
			pizza_ham_slice = 2600,
			donut = 2400,
			fries = 2500,
			chips = 2400,
			chocolate = 2200,
			cereal_bar = 2200,
			mustard = 2000,
			sprunk = 2600,
			ecola = 2600,
			coffee = 2800,
			energy_drink = 2800,
			beer = 3000,
			whiskey = 3200,
			vodka = 3200,
			cigarette = 3800,
			cigarettes_redwood = 3800,
			weed = 3800,
			cocaine = 3200,
			meth = 3200,
			bandage = 3200,
			medikit = 4000,
			painkillers = 2400,
			armour = 3500
		}
	},

	-- Regras e limites aplicados pelo servidor.
	Server = {
		defaultSlots = 30, -- slots de um inventário novo
		maxSlots = 200, -- limite máximo de slots aceito
		giveDistance = 3.0, -- distância (m) máxima para entregar item (o cliente usa o mesmo valor na lista)
		worldInteractDistance = 3.0, -- distância (m) máxima para abrir/pegar container do mundo
		adoptTimeoutMs = 2000, -- espera (ms) pela entidade networked ao colocar um container
		cacheTtlMs = 600000, -- inventário sem uso por esse tempo sai do cache (0 = nunca)
		flushIntervalMs = 1500, -- intervalo (ms) do flush de trocas/divisões de slots; 0 = gravar na hora
		-- Maletas no mundo são efêmeras: somem no restart junto com o conteúdo.
		maxWorldContainers = 200, -- máximo de maletas simultâneas no mundo
		maxWorldContainersPerPlayer = 10, -- máximo por personagem
		-- Intervalo mínimo (ms) entre ações do mesmo jogador (proteção contra spam).
		rateLimits = {
			requestMs = 300, -- abrir inventário
			swapMs = 100, -- trocar slots
			actionMs = 150, -- usar, dividir, entregar, mover
			dropMs = 300, -- colocar container no mundo
			syncMs = 1000 -- sincronizar containers do mundo
		},
		-- Itens entregues na criação de um inventário de personagem.
		starterItems = {
			{ name = 'money', count = 500 },
			{ name = 'phone', count = 1 },
			{ name = 'business_tablet', count = 1 },
			{ name = 'water', count = 3 },
			{ name = 'sprunk', count = 2 },
			{ name = 'sandwich', count = 3 },
			{ name = 'bread', count = 2 },
			{ name = 'chips', count = 2 },
			{ name = 'chocolate', count = 2 },
			{ name = 'bandage', count = 2 }
		}
	},

	-- Containers portáteis (maletas e sacos): modelo no mundo e como são carregados.
	-- Slots e peso de cada container ficam no catálogo (`data/coe_containers.lua`).
	Containers = {
		-- Chave = nome do item. Para um item novo, informe ao menos `model`.
		items = {
			paperbag = {
				model = 'prop_paper_bag_01',
				bone = 57005, -- osso do ped onde o prop é preso
				position = { x = 0.12, y = 0.02, z = -0.02 },
				rotation = { x = -90.0, y = 0.0, z = 0.0 }
			},
			-- Maletas e saco de lixo são armas nativas: o GTA cuida da pose e do prop na mão.
			-- bone/position/rotation abaixo só servem de referência para o posicionamento.
			WEAPON_BRIEFCASE = {
				model = 'prop_ld_case_01',
				bone = 57005,
				position = { x = 0.10, y = 0.0, z = 0.0 },
				rotation = { x = 0.0, y = 280.0, z = 53.0 }
			},
			WEAPON_BRIEFCASE_02 = {
				model = 'prop_security_case_01',
				bone = 57005,
				position = { x = 0.13, y = 0.0, z = -0.01 },
				rotation = { x = 0.0, y = 280.0, z = 90.0 }
			},
			WEAPON_GARBAGEBAG = {
				model = 'prop_cs_rub_binbag_01',
				bone = 28422,
				position = { x = 0.0, y = 0.04, z = -0.02 },
				rotation = { x = 0.0, y = 0.0, z = 0.0 }
			}
		}
	}
}
