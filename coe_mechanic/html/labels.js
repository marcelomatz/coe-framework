(function () {
	'use strict';

	const MOD_NAMES = {
		0: 'Aerofólio', 1: 'Para-choque dianteiro', 2: 'Para-choque traseiro', 3: 'Saias laterais', 4: 'Escapamento',
		5: 'Santantônio', 6: 'Grade', 7: 'Capô', 8: 'Paralama esquerdo', 9: 'Paralama direito', 10: 'Teto',
		11: 'Motor', 12: 'Freios', 13: 'Transmissão', 14: 'Buzina', 15: 'Suspensão', 16: 'Blindagem',
		23: 'Rodas dianteiras', 24: 'Rodas traseiras', 25: 'Suporte da placa', 26: 'Placa decorativa', 27: 'Acabamento',
		28: 'Ornamentos', 29: 'Painel', 30: 'Mostradores', 31: 'Alto-falantes das portas', 32: 'Bancos', 33: 'Volante',
		34: 'Câmbio', 35: 'Detalhes internos', 36: 'Alto-falantes', 37: 'Porta-malas', 38: 'Hidráulica', 39: 'Bloco do motor',
		40: 'Filtro de ar', 41: 'Reforços', 42: 'Capas de arco', 43: 'Antena', 44: 'Coberturas', 45: 'Tanque', 46: 'Janelas',
		48: 'Livery'
	};

	const CATEGORIES = [
		{ id: 'colors', label: 'Pintura' },
		{ id: 'body', label: 'Carroceria' },
		{ id: 'performance', label: 'Desempenho' },
		{ id: 'wheels', label: 'Rodas' },
		{ id: 'interior', label: 'Interior' },
		{ id: 'lights', label: 'Vidros e luzes' },
		{ id: 'livery', label: 'Livery e extras' }
	];

	const BODY = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 41, 42, 43, 44, 45, 46];
	const PERFORMANCE = [11, 12, 13, 15, 16, 39, 40];
	const WHEELS = [23, 24];

	function categoryOf(modType) {
		if (BODY.indexOf(modType) !== -1) { return 'body'; }
		if (PERFORMANCE.indexOf(modType) !== -1) { return 'performance'; }
		if (WHEELS.indexOf(modType) !== -1) { return 'wheels'; }
		return 'interior';
	}

	const COLOR_KEYS = {
		primary: 'Cor primária', secondary: 'Cor secundária', pearl: 'Perolado', wheel: 'Cor das rodas',
		interior: 'Cor do interior', dashboard: 'Cor do painel', primaryRgb: 'Pintura primária', secondaryRgb: 'Pintura secundária'
	};
	const TOGGLES = { turbo: 'Turbo', xenon: 'Faróis xenon', tyreSmoke: 'Fumaça dos pneus' };
	const SCALARS = { tint: 'Película dos vidros', wheelType: 'Tipo de roda', plateIndex: 'Estilo da placa', xenonColor: 'Cor do xenon' };

	function lineLabel(line) {
		if (line.kind === 'mod') { return MOD_NAMES[line.key] || ('Modificação ' + line.key); }
		if (line.kind === 'color') { return COLOR_KEYS[line.key] || 'Cor'; }
		if (line.kind === 'toggle') { return TOGGLES[line.key] || line.key; }
		if (line.kind === 'livery') { return 'Livery'; }
		if (line.kind === 'scalar') { return SCALARS[line.key] || line.key; }
		if (line.kind === 'neon') { return 'Neon'; }
		return line.key;
	}

	window.CoeMechanicLabels = { MOD_NAMES: MOD_NAMES, CATEGORIES: CATEGORIES, categoryOf: categoryOf, lineLabel: lineLabel };
})();
