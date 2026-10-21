CoeSpawnConfig = {
	-- Imprime no console F8 as etapas do spawn; desative após validar.
	Debug = false,
	-- Ponto usado no primeiro acesso do personagem (ou se a última posição não puder ser lida).
	location = {
		x = 215.76,
		y = -810.12,
		z = 30.73,
		heading = 157.0
	},
	-- O personagem volta onde estava ao sair. Dentro de imóveis/visitas vale a última posição na rua
	-- (o coe_housing devolve quem saiu dentro do imóvel para o interior).
	LastPosition = {
		Enabled = true,
		-- Espera máxima pela posição salva antes de usar o ponto padrão.
		TimeoutMs = 5000,
		-- Leitura da posição no servidor e gravação no banco.
		SampleMs = 5000,
		FlushMs = 60000,
		-- Deslocamento mínimo (m) para considerar uma posição nova.
		MinMove = 2.0,
		Bounds = { MaxXY = 16000.0, MinZ = -200.0, MaxZ = 2500.0 }
	},
	-- Peds comuns sorteados a cada spawn (temporário, até existir um criador de personagem).
	models = {
		'a_m_y_hipster_01',
		'a_m_y_business_01',
		'a_m_y_skater_01',
		'a_m_m_business_01',
		'a_f_y_hipster_01',
		'a_f_y_business_01',
		'a_f_y_tourist_01',
		'a_f_m_downtown_01'
	}
}
