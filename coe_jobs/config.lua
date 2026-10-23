JobsConfig = {
	-- Distância do centro do emprego (NPC) para começar e encerrar.
	CenterRadius = 6.0,
	-- Distância dos pontos (coleta, venda, parada) aceita pelo servidor; a altura tem tolerância separada.
	PointRadius = 5.0,
	PointHeight = 6.0,
	-- Distância do jogador até o veículo do emprego para guardar a carga (rotas de coleta, como o lixeiro).
	VehicleReach = 8.0,
	-- Velocidade máxima plausível entre duas paradas (m/s), contra teleporte.
	MaxTravelSpeed = 60.0,
	-- Intervalo mínimo entre ações de rede do mesmo jogador (ms).
	ActionCooldownMs = 600,
	-- Folga sobre a duração da ação de coleta (o client anima; o servidor exige pelo menos esta fração do tempo).
	GatherTimeSlack = 0.8,
	-- Motivo do extrato no coe_economy: <prefixo><id do emprego> (até 32 caracteres, [a-z0-9_]).
	LedgerPrefix = 'job_',
	-- Distância em que os NPCs dos centros e dos pontos aparecem (client).
	SpawnDistance = 70.0,
	-- Quantos trabalhos recentes cada personagem guarda (app Carreira e "Como funciona" no NPC).
	RecentSessions = 10,
	-- Tablets que chamam o app Carreira (TabletCall). Padrão do framework: o tablet de trabalho básico; pacotes
	-- recebem a ACE no server.cfg: add_ace resource.<nome> coe.jobs.tablet allow
	TabletResources = { coe_workpad = true },

	-- Liga ou desliga cada emprego de jobs/*.lua sem mexer na definição.
	Enabled = {
		lumberjack = true,
		miner = true,
		fisher = true,
		farmer = true,
		delivery = true,
		garbage = true,
		taxi = true,
		trucker = true
	},

	-- Carreira: o histórico do jogador em todos os empregos livres (shared/career.lua).
	Career = {
		-- XP total (soma de todos os empregos) de cada nível de carreira.
		levels = { 0, 300, 900, 2000, 4000, 7000, 11000, 16000 },
		-- Por nível de carreira acima do 1: +1% de pagamento e +3% de XP em qualquer emprego.
		payPerLevel = 0.01,
		xpPerLevel = 0.03,
		-- Teto da soma dos bônus de pagamento (nível do emprego + carreira + habilidades + reputação).
		maxPayBonus = 0.6,
		-- Teto da redução do tempo das ações de coleta.
		maxSpeedBonus = 0.3,
		-- Habilidades: o XP de cada uma é a soma do XP dos empregos que a treinam (`skills` na definição).
		-- perks por nível acima do 1: pay (+% pagamento), speed (-% tempo da ação), capacity (+% carga), deposit (-% depósito).
		skills = {
			strength = { label = 'Força', levels = { 0, 250, 750, 1750, 3500 }, perks = { capacity = 0.10 } },
			outdoor = { label = 'Campo', levels = { 0, 250, 750, 1750, 3500 }, perks = { speed = 0.05 } },
			driving = { label = 'Direção', levels = { 0, 250, 750, 1750, 3500 }, perks = { deposit = 0.15 } },
			logistics = { label = 'Logística', levels = { 0, 250, 750, 1750, 3500 }, perks = { pay = 0.03 } }
		},
		-- Reputação (-100 a 100): sobe ao concluir, cai ao abandonar o trabalho com o veículo da empresa.
		reputation = {
			start = 0, min = -100, max = 100,
			events = { complete = 1, abandon = -10, lost_vehicle = -5 },
			-- Faixas (a maior com `min` atingido vale): pay = bônus, deposit = multiplicador, depositWaived = sem depósito.
			tiers = {
				{ min = 50, label = 'Exemplar', pay = 0.05, depositWaived = true },
				{ min = 20, label = 'Confiável', pay = 0.03 },
				{ min = -19, label = 'Regular' },
				{ min = -100, label = 'Duvidosa', deposit = 2.0 }
			}
		}
	}
}

-- Cada arquivo em jobs/ acrescenta uma definição (contrato no README).
JobsCatalog = {}
