// App de facção do COE OS (coe_tablet): um por facção do personagem. Membros, cargos e crafts liberados.
(function () {
	'use strict';

	function el(tag, className, text) {
		const node = document.createElement(tag);
		if (className) { node.className = className; }
		if (text !== undefined && text !== null) { node.textContent = String(text); }
		return node;
	}

	window.CoeTablet.register('faction', function (root, tablet) {
		function view(faction) {
			root.replaceChildren();
			const head = el('div', 'coe-panel coe-panel--compact tb-card');
			const title = el('div', 'tb-card-head');
			title.append(el('strong', '', faction.label), el('span', 'coe-badge tb-badge--accent', faction.category));
			head.appendChild(title);
			head.appendChild(el('span', 'tb-muted', 'Seu cargo: ' + faction.grade));
			root.appendChild(head);

			const people = el('div', 'coe-panel coe-panel--compact tb-card');
			people.appendChild(el('div', 'tb-section', 'Membros (' + faction.members.length + ')'));
			const lines = el('div', 'tb-lines');
			faction.members.forEach(function (member) {
				const line = el('div', 'tb-line');
				line.append(el('span', '', member.name + (member.me ? ' (você)' : '')), el('span', 'tb-muted', member.grade));
				lines.appendChild(line);
			});
			people.appendChild(lines);
			const columns = el('div', 'tb-grid');
			columns.appendChild(people);
			root.appendChild(columns);

			const crafts = el('div', 'coe-panel coe-panel--compact tb-card');
			crafts.appendChild(el('div', 'tb-section', 'Produção liberada para o seu cargo'));
			if (!faction.recipes.length) { crafts.appendChild(el('p', 'tb-muted', 'Nenhuma receita liberada.')); }
			const chips = el('div', 'tb-chips');
			faction.recipes.forEach(function (recipe) { chips.appendChild(el('span', 'coe-badge', recipe)); });
			crafts.appendChild(chips);
			columns.appendChild(crafts);
		}

		root.appendChild(el('p', 'tb-empty', 'Carregando…'));
		tablet.call('faction', 'overview', {}).then(function (result) {
			if (!result || !result.ok) { root.replaceChildren(); tablet.status(tablet.errorText(result && result.error), 'error'); return; }
			view(result.faction);
		});
	});
})();