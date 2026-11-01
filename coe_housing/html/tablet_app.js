// Apps do coe_housing no COE OS: Esconderijo (o dono de um imóvel ilegal decide quem mais pode entrar) e Aluguéis.
(function () {
	'use strict';

	const ERRORS = {
		not_ready: 'Serviço de imóveis ainda iniciando.', no_character: 'Personagem não carregado.',
		not_owner: 'Você não é dono deste local.', target_not_found: 'Cidadão não encontrado (confira o ID).',
		target_not_online: 'O cidadão precisa estar na cidade.', is_owner: 'Você já tem acesso como dono.',
		already_allowed: 'Esta pessoa já tem acesso.', members_limit: 'Limite de pessoas atingido.',
		unknown_person: 'Pessoa não encontrada. Atualize.', invalid_members: 'Lista de pessoas inválida.',
		database_error: 'Falha ao gravar. Tente de novo.', unknown_action: 'Ação desconhecida.'
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

	window.CoeTablet.register('hideout', function (root, tablet) {
		let busy = false;
		let data = null;

		function errorText(code) { return ERRORS[code] || tablet.errorText(code); }

		function call(action, payload, done) {
			if (busy) { return; }
			busy = true;
			tablet.call('hideout', action, payload || {}).then(function (result) {
				busy = false;
				if (!result || !result.ok) { tablet.status(errorText(result && result.error), 'error'); return; }
				done(result);
			});
		}

		function load() {
			call('list', {}, function (result) {
				data = result;
				view();
			});
		}

		function change(hideout, action, payload, message) {
			call(action, Object.assign({ property: hideout.id }, payload), function () {
				tablet.status(message, 'ok');
				load();
			});
		}

		function card(hideout) {
			const box = el('div', 'coe-panel coe-panel--compact tb-card');
			const head = el('div', 'tb-card-head');
			head.appendChild(el('strong', '', hideout.label));
			const badges = el('div', 'tb-toolbar');
			badges.appendChild(el('span', 'coe-badge tb-badge--accent', 'Acesso restrito'));
			if (!hideout.enabled) { badges.appendChild(el('span', 'coe-badge tb-badge--warn', 'Inativo')); }
			if (hideout.present > 0) { badges.appendChild(el('span', 'coe-badge', hideout.present + ' dentro')); }
			head.appendChild(badges);
			box.appendChild(head);

			box.appendChild(el('div', 'tb-section', 'Quem pode entrar'));
			box.appendChild(el('span', 'tb-muted', 'Só você e as pessoas abaixo veem a entrada e entram. Quem for removido sai na hora.'));
			const people = el('div', 'tb-lines');
			if (!hideout.members.length) { people.appendChild(el('p', 'tb-muted', 'Ninguém além de você.')); }
			hideout.members.forEach(function (person) {
				const line = el('div', 'tb-line');
				line.appendChild(el('span', '', person.name || ('Personagem #' + person.characterId)));
				line.appendChild(button('Remover', 'coe-button--danger', function () {
					change(hideout, 'revoke', { characterId: person.characterId }, 'Acesso removido.');
				}));
				people.appendChild(line);
			});
			box.appendChild(people);

			const max = data.maxMembers || 10;
			box.appendChild(el('span', 'tb-muted', hideout.members.length + ' de ' + max + ' pessoas.'));
			if (hideout.members.length < max) {
				const add = el('div', 'tb-toolbar');
				const input = el('input', 'coe-field');
				input.type = 'number';
				input.placeholder = 'ID do cidadão (/id)';
				add.appendChild(input);
				add.appendChild(button('Dar acesso', 'coe-button--primary', function () {
					const stateId = Number(input.value);
					if (!stateId) { tablet.status('Informe o ID do cidadão.', 'error'); return; }
					change(hideout, 'allow', { stateId: stateId }, 'Acesso concedido.');
				}));
				box.appendChild(add);
			}
			return box;
		}

		function view() {
			root.replaceChildren();
			const list = (data && data.hideouts) || [];
			if (!list.length) {
				root.appendChild(el('p', 'tb-empty', 'Você não controla nenhum local restrito.'));
				return;
			}
			const grid = el('div', 'tb-grid');
			list.forEach(function (hideout) { grid.appendChild(card(hideout)); });
			root.appendChild(grid);
		}

		root.appendChild(el('p', 'tb-empty', 'Carregando…'));
		load();
	});
	const RENT_STATES = { ok: ['Em dia', 'tb-badge--accent'], due: ['Vencido', 'tb-badge--warn'], expired: ['Encerrando', 'tb-badge--warn'] };

	function money(value) { return '$ ' + Number(value || 0).toLocaleString('pt-BR'); }
	function date(seconds) {
		return new Date(seconds * 1000).toLocaleDateString('pt-BR', { day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit' });
	}

	window.CoeTablet.register('rentals', function (root, tablet) {
		function rental(entry) {
			const box = el('div', 'coe-panel coe-panel--compact tb-card');
			const head = el('div', 'tb-card-head');
			const title = el('div', 'tb-title');
			title.append(el('strong', '', entry.label), el('span', 'tb-muted', entry.kind + (entry.unit ? ' · unidade ' + entry.unit : '')));
			head.appendChild(title);
			const state = entry.starter ? ['Cedido', ''] : (RENT_STATES[entry.state] || [entry.state, '']);
			head.appendChild(el('span', 'coe-badge ' + state[1], state[0]));
			box.appendChild(head);

			const lines = el('div', 'tb-lines');
			const rows = [['Pago por', entry.payer || 'Você']];
			if (entry.starter) {
				rows.push(['Contrato', 'Moradia inicial, sem cobrança']);
			} else {
				rows.push(['Diária', money(entry.dailyRate)]);
				rows.push(['Ciclo', entry.cycleDays + ' dias · ' + money(entry.cycleTotal)]);
				rows.push([entry.state === 'ok' ? 'Próxima cobrança' : 'Encerra em', date(entry.state === 'ok' ? entry.paidUntil : entry.graceUntil)]);
			}
			rows.forEach(function (pair) {
				const line = el('div', 'tb-line');
				line.append(el('span', 'tb-muted', pair[0]), el('span', '', pair[1]));
				lines.appendChild(line);
			});
			box.appendChild(lines);
			if (!entry.starter && entry.state !== 'ok') {
				box.appendChild(el('span', 'tb-alert', entry.payer
					? 'Garanta saldo no caixa do negócio antes do encerramento.'
					: 'Garanta saldo na conta antes do encerramento.'));
			}
			const actions = el('div', 'tb-actions');
			actions.appendChild(button('Marcar no GPS', '', function () {
				tablet.waypoint(entry.x, entry.y).then(function () { tablet.status('Imóvel marcado no GPS.', 'ok'); });
			}));
			box.appendChild(actions);
			return box;
		}

		root.appendChild(el('p', 'tb-empty', 'Carregando…'));
		tablet.call('rentals', 'list', {}).then(function (result) {
			root.replaceChildren();
			if (!result || !result.ok) { tablet.status(ERRORS[result && result.error] || tablet.errorText(result && result.error), 'error'); return; }
			const list = result.rentals || [];
			if (!list.length) { root.appendChild(el('p', 'tb-empty', 'Você não tem aluguéis.')); return; }
			const grid = el('div', 'tb-grid');
			list.forEach(function (entry) { grid.appendChild(rental(entry)); });
			root.appendChild(grid);
		});
	});
})();