// App Empregos livres (coe_workpad): os empregos do coe_jobs abertos a qualquer cidadão, com pagamento, depósito do
// veículo, requisitos da carreira e GPS até o responsável, onde o trabalho começa.
(function () {
	'use strict';

	function el(tag, className, text) {
		const node = document.createElement(tag);
		if (className) { node.className = className; }
		if (text !== undefined && text !== null) { node.textContent = String(text); }
		return node;
	}
	function money(value) { return '$ ' + Math.floor(Number(value) || 0).toLocaleString('pt-BR'); }

	function render(root, api) {
		let jobs = null;
		let filter = 'all';

		function load() {
			api.call('freejobs', 'list').then(function (result) {
				if (!result || !result.ok) { api.status(api.errorText(result && result.error), 'error'); return; }
				jobs = (result.data && result.data.jobs) || [];
				paint();
			});
		}

		function gps(job) {
			api.waypoint(job.x, job.y).then(function (result) {
				api.status(result && result.ok ? 'Responsável de ' + job.label + ' marcado no GPS.' : 'Não foi possível marcar o GPS.', result && result.ok ? 'ok' : 'error');
			});
		}

		function jobCard(job) {
			const box = el('section', 'tb-card coe-panel wp-job' + (job.allowed ? '' : ' is-locked'));
			const head = el('div', 'tb-card-head');
			const title = el('div', 'tb-title');
			title.append(el('strong', null, job.label), el('span', 'tb-muted', job.kind));
			const badge = job.working ? 'Trabalhando' : (job.allowed ? 'Nível ' + job.level + '/' + job.maxLevel : 'Bloqueado');
			head.append(title, el('span', 'tb-badge' + (job.working ? ' tb-badge--accent' : (job.allowed ? '' : ' tb-badge--warn')), badge));
			box.append(head);
			if (job.description) { box.append(el('p', 'wp-job-text', job.description)); }
			const lines = el('div', 'tb-lines');
			(job.pay || []).forEach(function (text, index) {
				const row = el('div', 'tb-line');
				row.append(el('span', null, index === 0 ? 'Pagamento' : ''), el('strong', 'tb-in', text));
				lines.append(row);
			});
			if (job.deposit) {
				const row = el('div', 'tb-line');
				row.append(el('span', null, 'Veículo da empresa'), el('strong', null, 'Depósito de ' + money(job.deposit) + ' (devolvido)'));
				lines.append(row);
			}
			if (job.earned) {
				const row = el('div', 'tb-line');
				row.append(el('span', null, 'Você já ganhou'), el('strong', null, money(job.earned)));
				lines.append(row);
			}
			if (lines.childNodes.length) { box.append(lines); }
			if (!job.allowed && job.lockedReason) { box.append(el('div', 'tb-alert', 'Precisa de ' + job.lockedReason + '. Veja o caminho no app Carreira.')); }
			const actions = el('div', 'tb-actions');
			if (job.x !== null && job.x !== undefined) {
				const gpsButton = el('button', 'coe-button' + (job.allowed ? ' coe-button--primary' : ''), 'GPS até o responsável');
				gpsButton.type = 'button';
				gpsButton.addEventListener('click', function () { gps(job); });
				actions.append(gpsButton);
			}
			box.append(actions);
			return box;
		}

		function paint() {
			root.replaceChildren();
			const toolbar = el('div', 'tb-toolbar');
			const tabs = el('div', 'tb-tabs');
			const free = jobs.filter(function (job) { return job.allowed; }).length;
			[['all', 'Todos', jobs.length], ['allowed', 'Disponíveis para mim', free]].forEach(function (entry) {
				const tab = el('button', 'tb-tab' + (filter === entry[0] ? ' is-active' : ''), entry[1]);
				tab.type = 'button';
				tab.append(el('span', 'tb-count', entry[2]));
				tab.addEventListener('click', function () { filter = entry[0]; paint(); });
				tabs.append(tab);
			});
			toolbar.append(tabs, el('span', 'tb-muted', 'Fale com o responsável no local para começar.'));
			root.append(toolbar);
			const list = jobs.filter(function (job) { return filter === 'all' || job.allowed; });
			if (!list.length) {
				root.append(el('p', 'tb-empty', jobs.length ? 'Nenhum emprego liberado para você ainda.' : 'Nenhum emprego livre no momento.'));
				return;
			}
			const grid = el('div', 'tb-grid');
			list.forEach(function (job) { grid.append(jobCard(job)); });
			root.append(grid);
		}

		root.append(el('p', 'tb-empty', 'Carregando...'));
		load();
	}

	if (window.CoeTablet) { window.CoeTablet.register('freejobs', render); }
})();
