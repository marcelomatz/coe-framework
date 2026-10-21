CoeCharactersConfig = {
	Command = 'coe_characters',
	OpenKey = 'F7',
	KeyDescription = 'Open character selection',
	-- Imprime no console F8 do client as etapas do fluxo de seleção; desative após validar o fluxo in-game.
	Debug = false,
	-- A tela de carregamento (coe_loadscreen) fica até a seleção estar pronta; depois deste tempo fecha mesmo assim.
	LoadingScreenTimeoutMs = 30000,
	-- Opções exibidas no formulário; o servidor valida contra coe_character_genders (valores devem coincidir).
	Genders = {
		{ value = 'male', label = 'Masculino' },
		{ value = 'female', label = 'Feminino' }
	},
	-- Cena da seleção. Padrão: terraço do Observatório Galileo, personagens de costas para Los Santos ao pôr do sol.
	-- Anchor é o centro da fila (o chão é procurado a partir dele); Facing é para onde os personagens olham
	-- (0 = norte). Para mudar de lugar: fique no ponto, use /coe_scene_anchor e copie o valor do console F8.
	Scene = {
		Enabled = true,
		Anchor = { x = -438.8, y = 1076.1, z = 352.4 },
		Facing = 0.0,
		Spacing = 1.3,
		MaxSlots = 5,
		LoadTimeoutMs = 6000,
		Camera = {
			-- distância à frente da fila, altura e alvo relativos ao centro do ped, campo de visão.
			overview = { distance = 6.8, height = 0.9, target = 0.2, fov = 44.0, dofFar = 4.0, dofStrength = 0.6 },
			focus = { distance = 2.3, height = 0.45, target = 0.35, fov = 30.0, dofFar = 2.0, dofStrength = 0.9 }
		},
		InterpolationMs = 900,
		DepthOfField = true,
		Clock = { hour = 19, minute = 20 },
		Weather = 'EXTRASUNNY',
		-- Filtro de cor opcional (nome de timecycle do GTA), ex.: 'cinema'. nil desliga.
		Timecycle = nil,
		TimecycleStrength = 0.4,
		-- Poses de espera dos personagens que não estão em foco (cenários nativos do GTA).
		Idles = { 'WORLD_HUMAN_HANG_OUT_STREET', 'WORLD_HUMAN_STAND_MOBILE', 'WORLD_HUMAN_AA_COFFEE', 'WORLD_HUMAN_SMOKING', 'WORLD_HUMAN_STAND_IMPATIENT' }
	}
}
