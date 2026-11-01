DoorsConfig = {
	Limits = {
		-- Locais (casa, prédio, sede) cadastrados; cada local agrupa várias portas com as mesmas regras.
		MaxDoors = 500,
		-- Portas por local (entrada, fundos, garagem, portão...).
		MaxEntries = 12,
		-- Folhas por porta: 1 (simples) ou 2 (dupla, travam juntas).
		MaxLeaves = 2,
		-- Distância máxima entre as duas folhas de uma porta dupla.
		MaxLeafGap = 6.0,
		-- Idem para garagens e portões de duas folhas (mais largos).
		WideLeafGap = 14.0,
		MaxBusinesses = 8,
		MaxFactions = 8,
		MaxCharacters = 20,
		-- Pessoas liberadas numa porta exclusiva (além do dono).
		MaxEntryCharacters = 6,
		MaxItems = 4,
		ActionIntervalMs = 600
	},
	-- Distância de interação (m) a partir do centro da porta (garagens e portões aceitam mais, para abrir de dentro do veículo).
	Distance = { Default = 2.0, Min = 1.0, Max = 6.0, WideMax = 12.0 },
	-- Tipos de porta: folhas aceitas e se usa os limites largos.
	Kinds = {
		single = { label = 'Porta simples', minLeaves = 1, maxLeaves = 1 },
		double = { label = 'Porta dupla', minLeaves = 2, maxLeaves = 2 },
		garage = { label = 'Portão de garagem', minLeaves = 1, maxLeaves = 2, wide = true },
		gate = { label = 'Portão', minLeaves = 1, maxLeaves = 2, wide = true }
	},
	-- Trava automática depois de destrancar (segundos; 0 = desligada).
	AutoLock = { Max = 3600 },
	Pin = {
		MinLength = 4,
		MaxLength = 8,
		-- Erros seguidos por jogador e porta antes do bloqueio temporário.
		MaxAttempts = 5,
		LockoutSeconds = 60
	},
	-- Item de chave: abre todas as portas do local cujo ID estiver em metadata.door.
	KeyItem = 'key',
	-- Margem extra (m) aceita pelo servidor na checagem de distância.
	ServerSlack = 1.5
}
