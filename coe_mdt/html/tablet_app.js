(function () {
	'use strict';

	const ERRORS = {
		not_on_duty: 'Bata o ponto em uma delegacia.', not_police: 'Você não está de ponto em uma delegacia.',
		forbidden: 'Seu cargo não permite isso.', not_ready: 'Serviço ainda iniciando.',
		rate_limited: 'Limite de consultas atingido. Aguarde um minuto.', database_error: 'Falha no banco de dados.',
		invalid_term: 'Busca inválida.', term_too_short: 'Digite ao menos 2 letras ou um ID de 8 caracteres.',
		invalid_plate: 'Placa inválida.', unknown_plate: 'Placa não registrada.', invalid_text: 'Texto inválido ou fora do tamanho permitido.',
		invalid_charge: 'Motivo inválido (minúsculas, números e _).', invalid_character: 'Cidadão inválido.',
		unknown_character: 'Cidadão não encontrado.', same_character: 'Você não pode fazer isso consigo mesmo.',
		too_many_warrants: 'Limite de mandados ativos para este cidadão.', unknown_warrant: 'Mandado não encontrado.',
		already_closed: 'Mandado já encerrado.', invalid_status: 'Estado inválido.', unknown_bulletin: 'Boletim não encontrado ou já encerrado.',
		invalid_hours: 'Validade inválida.', invalid_call: 'Chamado inválido.', unknown_call: 'Chamado não encontrado.',
		dispatch_unavailable: 'Central de despacho indisponível.', unknown_action: 'Ação desconhecida.'
	};

	function el(tag, className, text) {
		const node = document.createElement(tag);
		if (className) { node.className = className; }
		if (text !== undefined && text !== null) { node.textContent = String(text); }
		return node;
	}

	function button(label, className, onClick) {
		const node = el('button', 'coe-button ' + (className || ''), label);
		node.type = 'button';
		node.addEventListener('click', onClick);
		return node;
	}

	function field(placeholder, max, type) {
		const node = el('input', 'coe-field');
		node.type = type || 'text';
		node.maxLength = max || 100;
		node.placeholder = placeholder;
		return node;
	}

	function area(placeholder, max) {
		const node = el('textarea', 'coe-field');
		node.maxLength = max;
		node.rows = 4;
		node.placeholder = placeholder;
		return node;
	}

	window.CoeTablet.register('mdt', function (root, tablet) {
		const TABS = [
			['calls', 'Chamados'], ['lookup', 'Consulta'], ['warrants', 'Mandados'], ['bulletins', 'Boletins'], ['reports', 'Relatórios']
		];
		let tab = 'calls';
		let busy = false;
		let data = { calls: [], results: [], person: null, plate: null, warrants: [], bulletins: [], reports: [] };

		function errorText(code) { return ERRORS[code] || tablet.errorText(code); }
		function panel(className) { return el('div', 'coe-panel coe-panel--compact ' + (className || '')); }

		// Uma chamada por vez; o tablet limita 1 por 250 ms.
		function call(action, payload, done) {
			if (busy) { return; }
			busy = true;
			tablet.call('mdt', action, payload || {}).then(function (result) {
				busy = false;
				if (!result || !result.ok) { tablet.status(errorText(result && result.error), 'error'); return; }
				done(result);
			});
		}

		function reload(delay) {
			setTimeout(function () { load(tab); }, delay || 350);
		}

		function load(name) {
			tab = name;
			const next = { calls: ['calls'], warrants: ['warrants'], bulletins: ['bulletins'], reports: ['reports'] }[name];
			if (!next) { view(); return; }
			call(next[0], {}, function (result) {
				data[name] = result[name] || [];
				view();
			});
		}

		function tabs() {
			const bar = el('div', 'tb-tabs');
			TABS.forEach(function (entry) {
				const node = button(entry[1], 'tb-tab' + (tab === entry[0] ? ' is-active' : ''), function () { load(entry[0]); });
				if (entry[0] === 'calls' && data.calls.length > 0) { node.appendChild(el('span', 'tb-count', data.calls.length)); }
				bar.appendChild(node);
			});
			return bar;
		}

		function row(label, value) {
			const line = el('div', 'tb-line');
			line.appendChild(el('span', '', label));
			line.appendChild(el('span', 'tb-muted', value));
			return line;
		}

		function section(title) { return el('div', 'tb-section', title); }

		function callsView() {
			const bar = el('div', 'tb-toolbar');
			bar.appendChild(el('span', 'tb-section', 'Chamados ativos'));
			bar.appendChild(button('Atualizar', '', function () { load('calls'); }));
			root.appendChild(bar);
			if (data.calls.length === 0) { root.appendChild(el('p', 'tb-empty', 'Nenhum chamado ativo.')); return; }
			data.calls.forEach(function (item) {
				const card = panel('tb-card');
				const head = el('div', 'tb-card-head');
				head.appendChild(el('strong', '', '#' + item.id + ' ' + item.label));
				head.appendChild(el('span', 'coe-badge', item.reports > 1 ? item.reports + ' relatos' : '1 relato'));
				card.appendChild(head);
				card.appendChild(row('Atendendo', item.responders));
				const actions = el('div', 'tb-toolbar');
				actions.appendChild(button('Atender', 'coe-button--primary', function () {
					call('accept', { id: item.id }, function () { tablet.status('Chamado aceito.', 'ok'); reload(); });
				}));
				actions.appendChild(button('Encerrar', '', function () {
					call('close', { id: item.id }, function () { tablet.status('Chamado encerrado.', 'ok'); reload(); });
				}));
				card.appendChild(actions);
				root.appendChild(card);
			});
		}

		function openPerson(id) {
			call('person', { id: id }, function (result) {
				data.person = result;
				data.plate = null;
				view();
			});
		}

		function personView() {
			const person = data.person;
			const card = panel('tb-card');
			const head = el('div', 'tb-card-head');
			head.appendChild(el('strong', '', person.person.name));
			head.appendChild(el('span', 'tb-muted', person.person.stateId));
			card.appendChild(head);
			root.appendChild(card);

			root.appendChild(section('Mandados ativos'));
			if (person.warrants.length === 0) { root.appendChild(el('p', 'tb-empty', 'Nenhum mandado.')); }
			person.warrants.forEach(function (w) { root.appendChild(row(w.charge + (w.note ? ' - ' + w.note : ''), w.officer)); });

			root.appendChild(section('Ficha criminal'));
			if (person.records.length === 0) { root.appendChild(el('p', 'tb-empty', 'Sem registros (ou sem permissão de ficha).')); }
			person.records.forEach(function (r) {
				const extra = r.amount > 0 ? ' $ ' + r.amount : r.minutes > 0 ? ' ' + r.minutes + ' min' : '';
				root.appendChild(row(r.kind + ': ' + r.detail + extra, r.officer));
			});

			root.appendChild(section('Veículos'));
			if (person.vehicles.length === 0) { root.appendChild(el('p', 'tb-empty', 'Nenhum veículo.')); }
			person.vehicles.forEach(function (v) {
				const line = row(v.plate + ' - ' + v.model, '');
				line.appendChild(button('Consultar', '', function () { lookupPlate(v.plate); }));
				root.appendChild(line);
			});

			root.appendChild(section('Relatórios recentes'));
			if (person.reports.length === 0) { root.appendChild(el('p', 'tb-empty', 'Nenhum relatório.')); }
			person.reports.forEach(function (r) { root.appendChild(row(r.title, r.author)); });

			const actions = el('div', 'tb-toolbar');
			actions.appendChild(button('Emitir mandado', 'coe-button--primary', 			function () { data.prefill = person.person; load('warrants'); }));
						actions.appendChild(button('Novo relatório', '', function () { data.prefill = person.person; load('reports'); }));
			root.appendChild(actions);
		}

		function lookupPlate(plate) {
			call('plate', { plate: plate }, function (result) {
				data.plate = result;
				data.person = null;
				view();
			});
		}

		function plateView() {
			const plate = data.plate;
			const card = panel('tb-card');
			const head = el('div', 'tb-card-head');
			head.appendChild(el('strong', '', plate.vehicle.plate));
			head.appendChild(el('span', 'tb-muted', plate.vehicle.model));
			card.appendChild(head);
			if (plate.owner) {
				const line = row('Proprietário: ' + plate.owner.name, plate.owner.stateId);
				line.appendChild(button('Abrir', '', function () { openPerson(plate.owner.id); }));
				card.appendChild(line);
			}
			root.appendChild(card);
			root.appendChild(section('Boletins da placa'));
			if (plate.bulletins.length === 0) { root.appendChild(el('p', 'tb-empty', 'Nenhum boletim.')); }
			plate.bulletins.forEach(function (b) { root.appendChild(row(b.title, b.body)); });
		}

		function lookupView() {
			const term = field('Nome ou ID do cidadão (8 caracteres)', 60);
			const plate = field('Placa', 8);
			const bar = el('div', 'tb-quote');
			bar.appendChild(term);
			bar.appendChild(button('Buscar cidadão', 'coe-button--primary', function () {
				call('lookup', { term: term.value }, function (result) { data.results = result.results || []; data.person = null; data.plate = null; view(); });
			}));
			bar.appendChild(plate);
			bar.appendChild(button('Buscar placa', '', function () { lookupPlate(plate.value); }));
			root.appendChild(bar);

			if (data.person) { personView(); return; }
			if (data.plate) { plateView(); return; }
			if (data.results.length === 0) { root.appendChild(el('p', 'tb-empty', 'Busque um cidadão ou uma placa. Toda consulta é registrada.')); return; }
			data.results.forEach(function (item) {
				const line = row(item.name, item.stateId);
				line.appendChild(button('Abrir', '', function () { openPerson(item.id); }));
				root.appendChild(line);
			});
		}

		function warrantsView() {
			const bar = el('div', 'tb-toolbar');
			bar.appendChild(el('span', 'tb-section', 'Mandados ativos'));
			bar.appendChild(button('Atualizar', '', function () { load('warrants'); }));
			root.appendChild(bar);

			const form = panel('tb-card');
			const prefill = data.prefill;
			const subject = field('ID do cidadão (número)', 18);
			if (prefill) { subject.value = prefill.id; form.appendChild(el('div', 'tb-muted', 'Alvo: ' + prefill.name)); }
			const charge = field('Motivo (ex.: roubo_veiculo)', 32);
			const note = field('Observação (opcional)', 200);
			form.appendChild(subject);
			form.appendChild(charge);
			form.appendChild(note);
			form.appendChild(button('Emitir mandado', 'coe-button--primary', function () {
				call('warrant_issue', { subjectId: subject.value, charge: charge.value, note: note.value }, function () {
					data.prefill = null;
					tablet.status('Mandado emitido.', 'ok');
					reload();
				});
			}));
			root.appendChild(form);

			if (data.warrants.length === 0) { root.appendChild(el('p', 'tb-empty', 'Nenhum mandado ativo.')); return; }
			data.warrants.forEach(function (w) {
				const card = panel('tb-card');
				const head = el('div', 'tb-card-head');
				head.appendChild(el('strong', '', w.subject));
				head.appendChild(el('span', 'coe-badge', w.charge));
				card.appendChild(head);
				if (w.note) { card.appendChild(el('div', 'tb-muted', w.note)); }
				card.appendChild(row('Emitido por', w.officer));
				const actions = el('div', 'tb-toolbar');
				[['served', 'Cumprido'], ['revoked', 'Revogar']].forEach(function (entry) {
					actions.appendChild(button(entry[1], '', function () {
						call('warrant_close', { id: w.id, status: entry[0] }, function () { tablet.status('Mandado atualizado.', 'ok'); reload(); });
					}));
				});
				card.appendChild(actions);
				root.appendChild(card);
			});
		}

		function bulletinsView() {
			const bar = el('div', 'tb-toolbar');
			bar.appendChild(el('span', 'tb-section', 'Boletins ativos'));
			bar.appendChild(button('Atualizar', '', function () { load('bulletins'); }));
			root.appendChild(bar);

			const form = panel('tb-card');
			const title = field('Título', 60);
			const body = field('Descrição', 300);
			const plate = field('Placa (opcional)', 8);
			const hours = field('Validade em horas (1-72)', 2, 'number');
			[title, body, plate, hours].forEach(function (node) { form.appendChild(node); });
			form.appendChild(button('Publicar boletim', 'coe-button--primary', function () {
				const payload = { title: title.value, body: body.value, plate: plate.value };
				if (hours.value !== '') { payload.hours = Math.floor(Number(hours.value)); }
				call('bulletin_issue', payload, function () { tablet.status('Boletim publicado.', 'ok'); reload(); });
			}));
			root.appendChild(form);

			if (data.bulletins.length === 0) { root.appendChild(el('p', 'tb-empty', 'Nenhum boletim ativo.')); return; }
			data.bulletins.forEach(function (b) {
				const card = panel('tb-card');
				const head = el('div', 'tb-card-head');
				head.appendChild(el('strong', '', b.title));
				if (b.plate) { head.appendChild(el('span', 'coe-badge', b.plate)); }
				card.appendChild(head);
				card.appendChild(el('div', 'tb-muted', b.body));
				card.appendChild(row('Publicado por', b.officer));
				card.appendChild(button('Encerrar', '', function () {
					call('bulletin_close', { id: b.id }, function () { tablet.status('Boletim encerrado.', 'ok'); reload(); });
				}));
				root.appendChild(card);
			});
		}

		function reportsView() {
			const bar = el('div', 'tb-toolbar');
			bar.appendChild(el('span', 'tb-section', 'Relatórios'));
			bar.appendChild(button('Atualizar', '', function () { load('reports'); }));
			root.appendChild(bar);

			const form = panel('tb-card');
			const prefill = data.prefill;
			const subject = field('ID do cidadão envolvido (opcional)', 18);
			if (prefill) { subject.value = prefill.id; form.appendChild(el('div', 'tb-muted', 'Envolvido: ' + prefill.name)); }
			const title = field('Título', 80);
			const body = area('Relato (não pode ser editado depois)', 1000);
			[subject, title, body].forEach(function (node) { form.appendChild(node); });
			form.appendChild(button('Registrar relatório', 'coe-button--primary', function () {
				call('report_create', { subjectId: subject.value, title: title.value, body: body.value }, function () {
					data.prefill = null;
					tablet.status('Relatório registrado.', 'ok');
					reload();
				});
			}));
			root.appendChild(form);

			if (data.reports.length === 0) { root.appendChild(el('p', 'tb-empty', 'Nenhum relatório.')); return; }
			data.reports.forEach(function (r) {
				const card = panel('tb-card');
				const head = el('div', 'tb-card-head');
				head.appendChild(el('strong', '', r.title));
				head.appendChild(el('span', 'tb-muted', r.author));
				card.appendChild(head);
				if (r.subject) { card.appendChild(row('Envolvido', r.subject)); }
				card.appendChild(el('div', 'tb-muted', r.body));
				root.appendChild(card);
			});
		}

		function view() {
			root.replaceChildren();
			root.appendChild(tabs());
			({ calls: callsView, lookup: lookupView, warrants: warrantsView, bulletins: bulletinsView, reports: reportsView })[tab]();
		}

		load('calls');
	});
})();
