Config = {
	-- Teclas padrao; cada jogador troca em Configuracoes > Teclado > FiveM.
	Keys = {
		extended = { command = 'coe_map_extended', default = 'Z', label = 'Coe: minimapa estendido' },
		full = { command = 'coe_map_full', default = 'M', label = 'Coe: mapa completo' },
		clear = { command = 'coe_map_clear', default = '', label = 'Coe: limpar destino' }
	},
	-- Escala usada so para o HUD (icones e painel de local) se afastar do bigmap nativo.
	ExtendedScale = 1.9,
	-- Zoom do radar a pe. Maior = mais afastado (mais ruas visiveis). nil = padrao do GTA.
	FootZoom = 1250,
	-- Intervalo de leitura do destino (ms) enquanto o mapa estendido esta aberto.
	WaypointIntervalMs = 500,
	-- Blip de destino do GTA.
	WaypointSprite = 8
}
