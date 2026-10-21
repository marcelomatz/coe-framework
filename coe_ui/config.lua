UiConfig = {
	DefaultTheme = 'moss',
	-- Cada nome precisa existir em html/tokens.css (:root[data-coe-theme="nome"]; moss é o :root).
	Themes = {
		{ name = 'moss', label = 'Musgo', swatch = '#c4df9b', base = '#151d1a' },
		{ name = 'ocean', label = 'Oceano', swatch = '#8db6d8', base = '#141e2a' },
		{ name = 'amber', label = 'Âmbar', swatch = '#e6b65c', base = '#1f1a12' },
		{ name = 'rose', label = 'Rosa', swatch = '#d98aa5', base = '#21161b' },
		{ name = 'violet', label = 'Violeta', swatch = '#b6a3f0', base = '#1b1625' }
	},
	-- Único resource autorizado a trocar o tema (a autorização do operador é do painel).
	Caller = 'coe_admin'
}
