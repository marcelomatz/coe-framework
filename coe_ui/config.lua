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
	-- Quem troca o tema padrão (a autorização do operador é de quem chama): ACE no server.cfg, ex.:
	--   add_ace resource.coe_admin coe.ui.theme allow
	Ace = 'coe.ui.theme'
}
