-- Corridas ilegais de rua: pistas com checkpoints pela cidade, entrada paga em cripto (coe_crypto) com pote dividido
-- entre os primeiros, ranking de pilotos, recordes por pista e risco de a polícia aparecer (coe_dispatch).
RacesConfig = {
	Locale = 'pt-BR',

	-- O tablet de corridas é um item: só quem carrega abre o app (usar o item, /corridas ou o app no COE OS).
	Item = 'race_tablet',
	Command = 'corridas',
	-- Sai da corrida (no lobby devolve a entrada; correndo, conta como abandono).
	QuitCommand = 'sairdacorrida',

	-- Gravador de pistas (teclas padrão; cada jogador troca em Configurações > Teclas > FiveM).
	Recorder = {
		MarkKey = 'Y',
		UndoKey = 'U',
		SaveKey = 'RETURN',
		CancelKey = 'DELETE'
	},

	-- Staff que modera pistas e corridas (ACE no principal do jogador): add_ace group.admin coe_races.admin allow
	AdminAce = 'coe_races.admin',

	Tracks = {
		MinCheckpoints = 3,
		MaxCheckpoints = 60,
		-- Distância mínima entre checkpoints gravados e raio padrão de cada um (m).
		MinSpacing = 25.0,
		CheckpointRadius = 12.0,
		NameMax = 32,
		DescriptionMax = 160,
		MaxLaps = 10,
		-- Para criar pistas o piloto precisa ter terminado esta quantidade de corridas (a staff cria sem limite).
		MinRacesToCreate = 3,
		-- Pistas por piloto (ativas ou ocultas).
		MaxPerCreator = 10
	},

	Races = {
		MinRacers = 2,
		MaxRacers = 12,
		-- Largada agendada: em quantos minutos a corrida pode ser marcada (o organizador também larga antes, à mão).
		MinStartMinutes = 1,
		MaxStartMinutes = 30,
		-- Na largada todos precisam estar no grid (a este raio do ponto de partida) e dentro de um veículo.
		GridRadius = 60.0,
		CountdownSeconds = 5,
		-- Colisão entre corredores desligada no começo (segundos depois do "VAI").
		GhostSeconds = 8,
		-- Depois do primeiro a cruzar a chegada, os demais têm este tempo para terminar; senão, abandono.
		FinishWindowSeconds = 90,
		-- Tempo máximo de prova por quilômetro de pista (x voltas), contra corridas que nunca acabam.
		MaxSecondsPerKm = 150,
		MinMaxSeconds = 240,
		-- Fora do veículo da largada por mais que isso: abandono.
		OutOfVehicleSeconds = 10,
		-- Corridas abertas (no lobby) ao mesmo tempo, no servidor e por organizador.
		MaxOpen = 10,
		MaxOpenPerOrganizer = 1,
		-- Velocidade máxima plausível entre dois checkpoints (m/s; ~540 km/h), contra teleporte.
		MaxSpeed = 150.0,
		-- Folga no raio do checkpoint conferido pelo servidor (a posição chega com atraso da rede).
		RadiusSlack = 10.0,
		-- Intervalo de atualização da posição de cada corredor no HUD.
		StandingsMs = 1000
	},

	-- Entrada em cripto (coe_crypto). Valores em unidades da moeda (1 NOX = 10.000). 0 = corrida sem aposta.
	BuyIn = {
		Min = 0,
		Max = 500000, -- 50 NOX
		-- Parte do pote do organizador, em pontos-base (500 = 5%).
		OrganizerFeeBps = 500,
		-- Divisão do restante por colocação, pelo número de corredores que largaram (a maior lista que couber).
		-- Se menos gente termina do que posições premiadas, a parte que sobra vai para o 1º.
		Payouts = {
			[2] = { 100 },
			[3] = { 70, 30 },
			[5] = { 60, 25, 15 },
			[8] = { 50, 25, 15, 10 }
		}
	},

	-- Classes de veículo (GetVehicleClass) que o organizador pode exigir. `any` = qualquer carro ou moto.
	Classes = {
		any = { label = 'Livre' },
		compacts = { label = 'Compactos', ids = { 0 } },
		sedans = { label = 'Sedãs', ids = { 1 } },
		suvs = { label = 'SUVs', ids = { 2 } },
		coupes = { label = 'Cupês', ids = { 3 } },
		muscle = { label = 'Muscle', ids = { 4 } },
		sports_classics = { label = 'Clássicos esportivos', ids = { 5 } },
		sports = { label = 'Esportivos', ids = { 6 } },
		super = { label = 'Super', ids = { 7 } },
		motorcycles = { label = 'Motos', ids = { 8 } },
		offroad = { label = 'Off-road', ids = { 9 } },
		tuners = { label = 'Esportivos e muscle', ids = { 4, 6 } }
	},
	-- Classes que nunca correm (bicicletas, barcos, aeronaves, trens, militares e serviço).
	BlockedClasses = { 13, 14, 15, 16, 17, 18, 19, 21 },

	-- Ranking: rating tipo Elo entre todos os pares de corredores de cada prova.
	Rating = { Start = 1000, K = 24, Min = 100 },
	Nickname = { Min = 3, Max = 16 },

	-- Polícia (coe_dispatch). Chance de alerta na largada e, durante a prova, a cada `TickSeconds` na posição do líder.
	Police = {
		Code = 'street_race',
		StartChance = 0.35,
		PerRacer = 0.05,
		MaxChance = 0.9,
		TickSeconds = 45,
		TickChance = 0.2,
		-- Viaturas com sirene ligada perto do grid aumentam o risco na largada.
		SirenRadius = 150.0,
		SirenBonus = 0.3
	},

	-- Interface do tablet e do HUD.
	CallCooldownMs = 250,
	MaxPayloadBytes = 8192,
	-- Corridas e resultados mostrados no tablet.
	HistorySize = 15,
	LeaderboardSize = 50,

	Animation = {
		Prop = 'prop_cs_tablet',
		Bone = 28422,
		Dict = 'amb@code_human_in_bus_passenger_idles@female@tablet@base',
		Name = 'base'
	}
}
