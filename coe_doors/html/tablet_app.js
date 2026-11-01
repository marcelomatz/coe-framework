// App "Casa" do coe_tablet (/casa): o dono de um local gerencia acesso exclusivo e senha de cada porta.
(function () {
	'use strict';

	const ERRORS = {
		not_ready: 'Fechaduras ainda iniciando.', no_character: 'Personagem não carregado.',
		not_owner: 'Você não é dono deste local.', unknown_entry: 'Porta não encontrada. Atualize.',
		target_not_found: 'Cidadão não encontrado (confira o ID).', target_not_online: 'O cidadão precisa estar na cidade.',
		is_owner: 'O dono já tem acesso a todas as portas.', already_allowed: 'Esta pessoa já tem acesso a esta porta.',
		allowed_limit: 'Limite de pessoas nesta porta atingido.', unknown_person: 'Pessoa não encontrada. Atualize.',
		invalid_pin: 'A senha deve ter de 4 a 8 dígitos.', invalid_access: 'Lista de pessoas inválida.',
		database_error: 'Falha ao gravar. Tente de novo.', unknown_action: 'Ação desconhecida.'
	};

	const KINDS = { single: 'Porta', double: 'Porta dupla', garage: 'Garagem', gate: 'Portão' };

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
		node.maxLength = max;
		node.placeholder = placeholder;
		return node;
	}

	window.CoeTablet.register('home', function (root, tablet) {
		let busy = false;
		let data = null;

		function errorText(code) { return ERRORS[code] || tablet.errorText(code); }

		function call(action, payload, done) {
			if (busy) { return; }
			busy = true;
			tablet.call('home', action, payload || {}).then(function (result) {
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

		function change(place, entry, action, payload, message) {
			const body = Object.assign({ place: place.id, key: entry.key }, payload || {});
			call(action, body, function () {
				tablet.status(message, 'ok');
				load();
			});
		}

		function entryCard(place, entry) {
			const card = el('div', 'coe-panel coe-panel--compact tb-card');
			const head = el('div', 'tb-card-head');
			head.appendChild(el('strong', '', entry.label));
			const badges = el('div', 'tb-toolbar');
			badges.appendChild(el('span', 'coe-badge', KINDS[entry.kind] || 'Porta'));
			badges.appendChild(el('span', 'coe-badge' + (entry.locked ? '' : ' tb-badge--warn'), entry.locked ? 'Trancada' : 'Destrancada'));
			if (entry.restricted) { badges.appendChild(el('span', 'coe-badge tb-badge--accent', 'Exclusiva')); }
			if (entry.hasPin) { badges.appendChild(el('span', 'coe-badge tb-badge--accent', 'Senha')); }
			head.appendChild(badges);
			card.appendChild(head);

			card.appendChild(el('div', 'tb-section', 'Acesso'));
			const access = el('div', 'tb-toolbar');
			access.appendChild(el('span', 'tb-muted', entry.restricted
				? 'Exclusiva: só você e as pessoas abaixo abrem (chave e regras do local não valem).'
				: 'Normal: vale o acesso do local (chave, moradores e regras).'));
			access.appendChild(button(entry.restricted ? 'Liberar para o local' : 'Tornar exclusiva', '', function () {
				change(place, entry, 'restrict', { restricted: !entry.restricted }, entry.restricted ? 'Porta liberada para o local.' : 'Porta agora é exclusiva.');
			}));
			card.appendChild(access);

			if (entry.restricted) {
				const people = el('div', 'tb-lines');
				if (!entry.allowed.length) { people.appendChild(el('p', 'tb-muted', 'Ninguém além de você.')); }
				entry.allowed.forEach(function (person) {
					const line = el('div', 'tb-line');
					line.appendChild(el('span', '', person.name || ('Personagem #' + person.characterId)));
					line.appendChild(button('Remover', 'coe-button--danger', function () {
						change(place, entry, 'revoke', { characterId: person.characterId }, 'Acesso removido.');
					}));
					people.appendChild(line);
				});
				card.appendChild(people);
				if (entry.allowed.length < (data.maxAllowed || 6)) {
					const add = el('div', 'tb-toolbar');
					const input = field('ID do cidadão (/id)', 7, 'number');
					add.appendChild(input);
					add.appendChild(button('Dar acesso', 'coe-button--primary', function () {
						const stateId = Number(input.value);
						if (!stateId) { tablet.status('Informe o ID do cidadão.', 'error'); return; }
						change(place, entry, 'allow', { stateId: stateId }, 'Acesso concedido.');
					}));
					card.appendChild(add);
				}
			}

			card.appendChild(el('div', 'tb-section', 'Senha da porta'));
			card.appendChild(el('span', 'tb-muted', entry.hasPin
				? 'Pedida para destrancar, mesmo de quem tem a chave ou acesso (inclusive você).'
				: 'Sem senha própria.'));
			const pinRow = el('div', 'tb-toolbar');
			const pin = field(entry.hasPin ? 'Nova senha (4 a 8 dígitos)' : 'Senha (4 a 8 dígitos)', 8, 'password');
			pin.inputMode = 'numeric';
			pin.autocomplete = 'new-password';
			pin.addEventListener('input', function () { pin.value = pin.value.replace(/\D/g, '').slice(0, 8); });
			pinRow.appendChild(pin);
			pinRow.appendChild(button(entry.hasPin ? 'Trocar senha' : 'Definir senha', 'coe-button--primary', function () {
				if (pin.value.length < 4) { tablet.status(ERRORS.invalid_pin, 'error'); return; }
				change(place, entry, 'pin', { pin: pin.value }, 'Senha da porta salva.');
			}));
			if (entry.hasPin) {
				pinRow.appendChild(button('Remover senha', 'coe-button--danger', function () {
					change(place, entry, 'clearPin', {}, 'Senha da porta removida.');
				}));
			}
			card.appendChild(pinRow);
			return card;
		}

		function view() {
			root.replaceChildren();
			const places = (data && data.places) || [];
			if (!places.length) {
				root.appendChild(el('p', 'tb-empty', 'Você não é dono de nenhum local.'));
				return;
			}
			places.forEach(function (place) {
				const head = el('div', 'tb-toolbar');
				head.appendChild(el('strong', '', place.label));
				head.appendChild(el('span', 'tb-muted', place.entries.length + (place.entries.length === 1 ? ' porta' : ' portas')));
				root.appendChild(head);
				place.entries.forEach(function (entry) { root.appendChild(entryCard(place, entry)); });
			});
		}

		root.appendChild(el('p', 'tb-empty', 'Carregando…'));
		load();
	});
})();
