// Elos (COE OS): rede profissional no smartphone e no tablet. Perfil, currículo montado do histórico real do
// personagem (empregos livres e negócios), conexões e busca. O mesmo script serve os dois aparelhos.
(function () {
	'use strict';

	const host = window.CoePhone || window.CoeTablet;
	if (!host) { return; }

	if (!document.querySelector('link[data-coe-elos]')) {
		const link = document.createElement('link');
		link.rel = 'stylesheet';
		link.href = 'nui://coe_elos/html/elos.css';
		link.dataset.coeElos = '1';
		document.head.appendChild(link);
	}

	const ERRORS = {
		not_ready: 'Elos ainda iniciando.', no_character: 'Personagem não carregado.', database_error: 'Falha ao gravar. Tente de novo.',
		unknown_action: 'Ação desconhecida.', busy: 'Aguarde um instante.', not_installed: 'Elos indisponível.',
		invalid_profile: 'Nada para salvar.', invalid_headline: 'A apresentação está longa demais.', invalid_about: 'O texto "Sobre" está longo demais.',
		invalid_visibility: 'Escolha aberto ou fechado.', invalid_item: 'Experiência inválida.', unknown_item: 'Essa experiência não está mais no seu histórico.',
		invalid_note: 'Comentário longo demais.', item_limit: 'Seu currículo já tem o máximo de experiências.',
		invalid_search: 'Busca inválida.', search_short: 'Digite pelo menos 3 letras ou o ID completo.',
		invalid_person: 'Pessoa inválida.', unknown_person: 'Essa pessoa não está no Elos.', self: 'Esse é o seu perfil.',
		already_connected: 'Vocês já estão conectados.', already_requested: 'Pedido já enviado.', connection_limit: 'Você chegou ao limite de conexões.',
		pending_limit: 'Pedidos demais aguardando resposta. Espere alguns serem respondidos.', no_request: 'Esse pedido não existe mais.'
	};

	const LOGO = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"><path d="M9.5 14.5l5-5"/><path d="M11 6.5l1.6-1.6a4 4 0 0 1 5.6 5.6L16.6 12"/><path d="M13 17.5l-1.6 1.6a4 4 0 0 1-5.6-5.6L7.4 12"/></svg>';

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
	function hours(seconds) {
		const total = Math.floor((seconds || 0) / 60);
		if (total < 1) { return '0 h'; }
		const h = Math.floor(total / 60);
		const m = total % 60;
		if (h === 0) { return m + ' min'; }
		return m > 0 && h < 10 ? h + ' h ' + m + ' min' : h.toLocaleString('pt-BR') + ' h';
	}
	function month(seconds) {
		if (!seconds) { return null; }
		return new Date(seconds * 1000).toLocaleDateString('pt-BR', { month: 'short', year: 'numeric' }).replace('.', '');
	}
	function money(value) { return '$ ' + Math.floor(value || 0).toLocaleString('pt-BR'); }
	// Iniciais das palavras que começam com letra ("Lojinha 24/7" -> "L", "Ana Lima" -> "AL").
	function initials(name) {
		const parts = String(name || '').trim().split(/\s+/).filter(function (word) { return /^\p{L}/u.test(word); });
		if (!parts.length) { return '?'; }
		return (parts[0][0] + (parts.length > 1 ? parts[parts.length - 1][0] : '')).toUpperCase();
	}
	function period(entry) {
		const from = month(entry.firstAt);
		const to = entry.current ? 'atual' : month(entry.lastAt);
		if (!from && !to) { return entry.current ? 'Atual' : ''; }
		if (!from) { return entry.current ? 'Atual' : 'até ' + to; }
		return from === to ? from : from + ' – ' + to;
	}
	function counter(field, max) {
		const node = el('small', 'tb-muted el-counter');
		function paint() { node.textContent = field.value.length + '/' + max; }
		field.addEventListener('input', paint);
		paint();
		return node;
	}

	// Avatar com as iniciais (cor estável pelo nome).
	function avatar(name, big) {
		const node = el('span', 'el-avatar' + (big ? ' el-avatar--big' : ''), initials(name));
		let hash = 0;
		for (const ch of String(name || '')) { hash = (hash * 31 + ch.charCodeAt(0)) >>> 0; }
		node.style.setProperty('--el-hue', String(hash % 360));
		return node;
	}

	// Uma experiência do currículo (do próprio jogador ou de quem ele visita).
	function experienceCard(entry, mine) {
		const card = el('article', 'el-exp' + (entry.current ? ' is-current' : ''));
		const icon = el('span', 'el-exp-icon el-exp-icon--' + entry.kind, initials(entry.kind === 'job' ? entry.title : entry.org));
		const body = el('div', 'el-exp-body');
		const head = el('div', 'el-exp-head');
		head.appendChild(el('strong', null, entry.title));
		if (entry.current) { head.appendChild(el('span', 'el-tag el-tag--accent', entry.owner ? 'Dono' : 'Atual')); }
		body.appendChild(head);
		body.appendChild(el('span', 'el-exp-org', entry.org + (entry.subtitle ? ' · ' + entry.subtitle : '')));
		const when = period(entry);
		if (when) { body.appendChild(el('span', 'el-exp-when', when)); }
		const stats = el('div', 'el-stats');
		function stat(label, value) {
			const node = el('span', 'el-stat');
			node.append(el('b', null, value), el('small', null, label));
			stats.appendChild(node);
		}
		stat('trabalhadas', hours(entry.seconds));
		if (entry.kind === 'job') {
			stat('tarefas', String(entry.tasks || 0));
			if (entry.level) { stat('nível', entry.level + '/' + entry.maxLevel); }
		} else if (entry.shifts) {
			stat(entry.shifts === 1 ? 'turno' : 'turnos', String(entry.shifts));
		}
		if (entry.earned !== undefined && entry.earned !== null) { stat(mine ? 'ganhos (só você vê)' : 'ganhos', money(entry.earned)); }
		body.appendChild(stats);
		if (!mine && entry.note) { body.appendChild(el('p', 'el-note', entry.note)); }
		card.append(icon, body);
		return card;
	}

	host.register('elos', function (root, api) {
		const page = el('div', 'el-page');
		root.appendChild(page);

		let state = null;
		let tab = 'profile';
		let editing = false;
		let person = null;       // perfil visitado
		let back = 'network';    // aba para onde o "voltar" do perfil visitado leva
		let search = { query: '', results: null };
		let pending = false;

		function call(action, payload) {
			return api.call('elos', action, payload || {}).then(function (result) {
				if (!result || !result.ok) {
					api.status(ERRORS[result && result.error] || api.errorText((result && result.error) || 'app_error'), 'error');
				}
				return result || { ok: false };
			});
		}

		function load() {
			return call('state').then(function (result) {
				if (result.ok) { state = result; }
				render();
				return result;
			});
		}

		// Ação que muda dados: trava botões enquanto roda e recarrega o estado no fim.
		function act(action, payload, success) {
			if (pending) { return Promise.resolve({ ok: false }); }
			pending = true;
			return call(action, payload).then(function (result) {
				pending = false;
				if (result.ok && success) { api.status(success, 'success'); }
				return load().then(function () { return result; });
			});
		}

		// Cabeçalho -----------------------------------------------------------------------------------

		function brand() {
			const bar = el('header', 'el-brand');
			const logo = el('span', 'el-logo');
			logo.innerHTML = LOGO;
			const text = el('div', 'tb-title');
			text.append(el('strong', null, 'Elos'), el('small', 'tb-muted', 'Sua rede profissional'));
			bar.append(logo, text);
			return bar;
		}

		function tabs() {
			const bar = el('nav', 'tb-tabs el-tabs');
			const incoming = state ? state.network.incoming.length : 0;
			[
				{ id: 'profile', label: 'Perfil' },
				{ id: 'resume', label: 'Currículo' },
				{ id: 'network', label: 'Rede', count: incoming },
				{ id: 'search', label: 'Buscar' }
			].forEach(function (item) {
				const node = el('button', 'tb-tab' + (tab === item.id && !person ? ' is-active' : ''), item.label);
				node.type = 'button';
				if (item.count) { node.appendChild(el('span', 'tb-count', item.count)); }
				node.addEventListener('click', function () { tab = item.id; person = null; editing = false; render(); });
				bar.appendChild(node);
			});
			return bar;
		}

		// Cartão de perfil (o próprio ou visitado) --------------------------------------------------------

		function profileHead(view, extra) {
			const card = el('section', 'el-hero');
			const top = el('div', 'el-hero-top');
			top.appendChild(avatar(view.name, true));
			const text = el('div', 'el-hero-text');
			text.appendChild(el('h2', 'el-name', view.name));
			text.appendChild(el('p', 'el-headline', view.headline || 'Sem apresentação'));
			const chips = el('div', 'tb-chips');
			chips.appendChild(el('span', 'el-tag', 'ID ' + view.stateId));
			chips.appendChild(el('span', 'el-tag' + (view.visibility === 'closed' ? ' el-tag--lock' : ''), view.visibility === 'closed' ? 'Perfil fechado' : 'Perfil aberto'));
			if (view.connections !== undefined) {
				chips.appendChild(el('span', 'el-tag', view.connections + (view.connections === 1 ? ' conexão' : ' conexões')));
			}
			text.appendChild(chips);
			top.appendChild(text);
			card.appendChild(top);
			if (view.summary) {
				const numbers = el('div', 'el-numbers');
				function number(value, label) {
					const node = el('div', 'el-number');
					node.append(el('strong', null, value), el('small', null, label));
					numbers.appendChild(node);
				}
				number(hours(view.summary.seconds), 'trabalhadas');
				number(String(view.summary.count), view.summary.count === 1 ? 'experiência' : 'experiências');
				if (view.career) { number('Nível ' + view.career.level, 'carreira'); }
				card.appendChild(numbers);
			}
			if (extra) { card.appendChild(extra); }
			return card;
		}

		function careerBlock(careerCard) {
			const box = el('section', 'el-block');
			box.appendChild(el('div', 'tb-section', 'Carreira nos empregos livres'));
			const lines = el('div', 'tb-lines');
			function line(label, value) {
				const row = el('div', 'tb-line');
				row.append(el('span', null, label), el('strong', null, value));
				lines.appendChild(row);
			}
			line('Nível de carreira', careerCard.level + '/' + careerCard.maxLevel);
			line('Reputação', careerCard.tier);
			line('Trabalhos concluídos', String(careerCard.completed || 0));
			box.appendChild(lines);
			if (careerCard.skills && careerCard.skills.length) {
				const chips = el('div', 'tb-chips');
				careerCard.skills.forEach(function (skill) { chips.appendChild(el('span', 'el-tag el-tag--accent', skill.label + ' ' + skill.level)); });
				box.appendChild(chips);
			}
			return box;
		}

		function resumeBlock(entries, mine, emptyText) {
			const box = el('section', 'el-block');
			box.appendChild(el('div', 'tb-section', 'Experiência'));
			if (!entries.length) {
				box.appendChild(el('p', 'tb-empty', emptyText));
				return box;
			}
			const list = el('div', 'el-exp-list');
			entries.forEach(function (entry) { list.appendChild(experienceCard(entry, mine)); });
			box.appendChild(list);
			return box;
		}

		function aboutBlock(text) {
			const box = el('section', 'el-block');
			box.appendChild(el('div', 'tb-section', 'Sobre'));
			box.appendChild(el('p', 'el-about', text));
			return box;
		}

		// Aba Perfil: como os outros veem, com edição --------------------------------------------------

		function myPublicResume() {
			return state.resume.filter(function (entry) { return entry.added; }).map(function (entry) {
				const copy = Object.assign({}, entry);
				if (!state.me.showEarnings) { delete copy.earned; }
				return copy;
			});
		}

		function profileTab() {
			const me = state.me;
			if (editing) { return editProfile(); }
			const actions = el('div', 'tb-actions el-hero-actions');
			actions.append(
				button('Editar perfil', 'coe-button--primary', function () { editing = true; render(); }),
				button('Montar currículo', '', function () { tab = 'resume'; render(); })
			);
			const view = Object.assign({}, me, { connections: state.network.connections.length, summary: state.summary, career: me.showCareer ? state.career : null });
			const wrap = el('div', 'el-columns');
			const main = el('div', 'el-stack');
			main.appendChild(profileHead(view, actions));
			main.appendChild(el('p', 'tb-muted el-hint', me.visibility === 'closed'
				? 'Assim suas conexões veem seu perfil. Quem não é conexão vê só seu nome e sua apresentação.'
				: 'Assim qualquer pessoa vê seu perfil no Elos.'));
			if (me.about) { main.appendChild(aboutBlock(me.about)); }
			main.appendChild(resumeBlock(myPublicResume(), false, 'Seu currículo está vazio. Toque em "Montar currículo" para escolher suas experiências.'));
			wrap.appendChild(main);
			if (me.showCareer && state.career) {
				const side = el('div', 'el-stack');
				side.appendChild(careerBlock(state.career));
				wrap.appendChild(side);
			}
			return wrap;
		}

		function editProfile() {
			const me = state.me;
			const form = el('section', 'el-block el-form');
			form.appendChild(el('div', 'tb-section', 'Editar perfil'));

			const headlineLabel = el('label', 'el-field');
			const headline = el('input', 'coe-field');
			headline.maxLength = state.limits.headline;
			headline.value = me.headline || '';
			headline.placeholder = 'Ex.: Mecânico na Benny\'s · Taxista nas horas vagas';
			headlineLabel.append(el('span', null, 'Apresentação'), headline, counter(headline, state.limits.headline));

			const aboutLabel = el('label', 'el-field');
			const about = el('textarea', 'coe-field tb-textarea el-textarea');
			about.maxLength = state.limits.about;
			about.value = me.about || '';
			about.placeholder = 'Conte um pouco sobre você e o que procura.';
			aboutLabel.append(el('span', null, 'Sobre'), about, counter(about, state.limits.about));

			let visibility = me.visibility;
			const segment = el('div', 'el-segment');
			const options = [
				{ id: 'open', label: 'Aberto', hint: 'Qualquer pessoa vê seu currículo.' },
				{ id: 'closed', label: 'Fechado', hint: 'Só suas conexões veem; os outros veem nome e apresentação.' }
			];
			const hint = el('small', 'tb-muted');
			function paintSegment() {
				segment.querySelectorAll('button').forEach(function (node) { node.classList.toggle('is-active', node.dataset.id === visibility); });
				hint.textContent = options.find(function (o) { return o.id === visibility; }).hint;
			}
			options.forEach(function (option) {
				const node = el('button', null, option.label);
				node.type = 'button';
				node.dataset.id = option.id;
				node.addEventListener('click', function () { visibility = option.id; paintSegment(); });
				segment.appendChild(node);
			});
			paintSegment();
			const visibilityField = el('div', 'el-field');
			visibilityField.append(el('span', null, 'Quem vê seu perfil'), segment, hint);

			function toggle(label, value) {
				const row = el('label', 'el-toggle');
				const input = el('input');
				input.type = 'checkbox';
				input.checked = value;
				row.append(input, el('span', 'el-switch'), el('span', null, label));
				return { row: row, input: input };
			}
			const showCareer = toggle('Mostrar minha carreira nos empregos livres (nível, reputação e habilidades)', me.showCareer);
			const showEarnings = toggle('Mostrar quanto ganhei em cada experiência', me.showEarnings);

			const actions = el('div', 'tb-actions');
			actions.append(
				button('Cancelar', '', function () { editing = false; render(); }),
				button('Salvar', 'coe-button--primary', function () {
					act('saveProfile', {
						headline: headline.value, about: about.value, visibility: visibility,
						showCareer: showCareer.input.checked, showEarnings: showEarnings.input.checked
					}, 'Perfil salvo.').then(function (result) {
						if (result.ok) { editing = false; render(); }
					});
				})
			);
			form.append(headlineLabel, aboutLabel, visibilityField, showCareer.row, showEarnings.row, actions);
			return form;
		}

		// Aba Currículo: escolher experiências ------------------------------------------------------------

		function resumeTab() {
			const wrap = el('div', 'el-stack');
			const intro = el('section', 'el-block');
			intro.appendChild(el('div', 'tb-section', 'Monte seu currículo'));
			intro.appendChild(el('p', 'el-about', 'Aqui está tudo o que você já fez: empregos livres e negócios onde você trabalhou. '
				+ 'Só as experiências marcadas aparecem no seu perfil. Horas e tarefas vêm do seu histórico real e não podem ser editadas.'));
			const totals = el('div', 'el-numbers');
			[
				[hours(state.totals.seconds), 'trabalhadas no total'],
				[state.summary.count + '/' + state.totals.count, 'no currículo']
			].forEach(function (pair) {
				const node = el('div', 'el-number');
				node.append(el('strong', null, pair[0]), el('small', null, pair[1]));
				totals.appendChild(node);
			});
			intro.appendChild(totals);
			wrap.appendChild(intro);

			if (!state.resume.length) {
				wrap.appendChild(el('p', 'tb-empty', 'Você ainda não tem experiências. Trabalhe em um emprego livre (procure os NPCs no mapa) ou bata ponto num negócio.'));
				return wrap;
			}
			const list = el('div', 'el-exp-list');
			state.resume.forEach(function (entry) {
				const item = el('div', 'el-pick' + (entry.added ? ' is-added' : ''));
				item.appendChild(experienceCard(entry, true));
				const controls = el('div', 'el-pick-controls');
				const switchRow = el('label', 'el-toggle');
				const input = el('input');
				input.type = 'checkbox';
				input.checked = entry.added;
				input.addEventListener('change', function () {
					act('setItem', { kind: entry.kind, ref: entry.ref, added: input.checked, note: entry.note || '' },
						input.checked ? 'Adicionado ao currículo.' : 'Removido do currículo.');
				});
				switchRow.append(input, el('span', 'el-switch'), el('span', null, entry.added ? 'No currículo' : 'Fora do currículo'));
				controls.appendChild(switchRow);
				if (entry.added) {
					const note = el('div', 'el-note-edit');
					const field = el('input', 'coe-field');
					field.maxLength = state.limits.note;
					field.placeholder = 'Comentário (opcional): o que você fazia, conquistas...';
					field.value = entry.note || '';
					const save = button('Salvar', '', function () {
						act('setItem', { kind: entry.kind, ref: entry.ref, added: true, note: field.value }, 'Comentário salvo.');
					});
					note.append(field, save);
					controls.appendChild(note);
				}
				item.appendChild(controls);
				list.appendChild(item);
			});
			wrap.appendChild(list);
			return wrap;
		}

		// Aba Rede ---------------------------------------------------------------------------------------

		function personRow(card, actions) {
			const row = el('div', 'el-person');
			const open = el('button', 'el-person-open');
			open.type = 'button';
			const text = el('span', 'el-person-text');
			text.append(el('strong', null, card.name), el('small', null, card.headline || 'Sem apresentação'));
			open.append(avatar(card.name), text);
			open.addEventListener('click', function () { openPerson(card.stateId); });
			row.appendChild(open);
			if (actions) { row.appendChild(actions); }
			return row;
		}

		function networkTab() {
			const wrap = el('div', 'el-stack');
			const net = state.network;
			if (net.incoming.length) {
				const box = el('section', 'el-block');
				box.appendChild(el('div', 'tb-section', 'Pedidos para você'));
				net.incoming.forEach(function (card) {
					const actions = el('div', 'tb-actions');
					actions.append(
						button('Recusar', '', function () { act('respond', { stateId: card.stateId, accept: false }, 'Pedido recusado.'); }),
						button('Aceitar', 'coe-button--primary', function () { act('respond', { stateId: card.stateId, accept: true }, 'Conexão aceita.'); })
					);
					box.appendChild(personRow(card, actions));
				});
				wrap.appendChild(box);
			}
			const box = el('section', 'el-block');
			box.appendChild(el('div', 'tb-section', 'Conexões (' + net.connections.length + ')'));
			if (!net.connections.length) {
				const empty = el('div', 'el-empty');
				empty.appendChild(el('p', 'tb-empty', 'Você ainda não tem conexões.'));
				empty.appendChild(button('Buscar pessoas', 'coe-button--primary', function () { tab = 'search'; render(); }));
				box.appendChild(empty);
			} else {
				net.connections.forEach(function (card) { box.appendChild(personRow(card)); });
			}
			wrap.appendChild(box);
			if (net.outgoing.length) {
				const sent = el('section', 'el-block');
				sent.appendChild(el('div', 'tb-section', 'Pedidos enviados'));
				net.outgoing.forEach(function (card) {
					sent.appendChild(personRow(card, button('Cancelar', '', function () { act('remove', { stateId: card.stateId }, 'Pedido cancelado.'); })));
				});
				wrap.appendChild(sent);
			}
			return wrap;
		}

		// Botão de conexão conforme a relação com a pessoa.
		function relationButton(stateId, relation, onDone) {
			function run(action, payload, message) {
				act(action, payload, message).then(function (result) { if (result.ok && onDone) { onDone(result.relation); } });
			}
			if (relation === 'connected') {
				return button('Remover conexão', '', function () { run('remove', { stateId: stateId }, 'Conexão removida.'); });
			}
			if (relation === 'outgoing') {
				return button('Cancelar pedido', '', function () { run('remove', { stateId: stateId }, 'Pedido cancelado.'); });
			}
			if (relation === 'incoming') {
				return button('Aceitar conexão', 'coe-button--primary', function () { run('respond', { stateId: stateId, accept: true }, 'Conexão aceita.'); });
			}
			if (relation === 'none') {
				return button('Conectar', 'coe-button--primary', function () { run('request', { stateId: stateId }, 'Pedido enviado.'); });
			}
			return null;
		}

		function searchTab() {
			const wrap = el('div', 'el-stack');
			const box = el('section', 'el-block');
			box.appendChild(el('div', 'tb-section', 'Encontrar pessoas'));
			const form = el('form', 'el-search');
			const field = el('input', 'coe-field');
			field.placeholder = 'Nome ou ID (ex.: ' + state.me.stateId + ')';
			field.value = search.query;
			form.append(field, button('Buscar', 'coe-button--primary', function () { form.requestSubmit(); }));
			form.addEventListener('submit', function (event) {
				event.preventDefault();
				search.query = field.value.trim();
				call('search', { query: search.query }).then(function (result) {
					search.results = result.ok ? result.results : search.results;
					render();
				});
			});
			box.appendChild(form);
			box.appendChild(el('small', 'tb-muted', 'Só aparece quem já abriu o Elos. O ID é o mesmo do comando /id.'));
			wrap.appendChild(box);
			if (search.results) {
				const results = el('section', 'el-block');
				results.appendChild(el('div', 'tb-section', search.results.length + (search.results.length === 1 ? ' resultado' : ' resultados')));
				if (!search.results.length) { results.appendChild(el('p', 'tb-empty', 'Ninguém encontrado.')); }
				search.results.forEach(function (card) {
					results.appendChild(personRow(card, relationButton(card.stateId, card.relation, function (relation) { card.relation = relation; render(); })));
				});
				wrap.appendChild(results);
			}
			setTimeout(function () { if (field.isConnected && !search.results) { field.focus(); } }, 0);
			return wrap;
		}

		// Perfil visitado ------------------------------------------------------------------------------------

		function openPerson(stateId) {
			back = tab;
			call('person', { stateId: stateId }).then(function (result) {
				if (!result.ok) { return; }
				person = result.person;
				render();
			});
		}

		function personTab() {
			const wrap = el('div', 'el-stack');
			wrap.appendChild(el('div', 'tb-actions el-back', null)).appendChild(button('‹ Voltar', '', function () { person = null; tab = back; render(); }));
			const actions = el('div', 'tb-actions el-hero-actions');
			const action = relationButton(person.stateId, person.relation, function () { openPerson(person.stateId); });
			if (action) { actions.appendChild(action); }
			if (person.relation === 'incoming') {
				actions.appendChild(button('Recusar', '', function () {
					act('respond', { stateId: person.stateId, accept: false }, 'Pedido recusado.').then(function () { openPerson(person.stateId); });
				}));
			}
			const columns = el('div', 'el-columns');
			const main = el('div', 'el-stack');
			main.appendChild(profileHead(person, actions.childNodes.length ? actions : null));
			if (!person.full) {
				const lock = el('section', 'el-block el-locked');
				lock.appendChild(el('strong', null, 'Perfil fechado'));
				lock.appendChild(el('p', 'tb-muted', person.relation === 'outgoing'
					? 'Seu pedido está aguardando. Quando for aceito, você verá o currículo completo.'
					: 'Conecte-se com ' + person.name.split(' ')[0] + ' para ver o currículo completo.'));
				main.appendChild(lock);
				columns.appendChild(main);
				wrap.appendChild(columns);
				return wrap;
			}
			if (person.about) { main.appendChild(aboutBlock(person.about)); }
			main.appendChild(resumeBlock(person.resume || [], false, 'Ainda não há experiências no currículo.'));
			columns.appendChild(main);
			if (person.career) {
				const side = el('div', 'el-stack');
				side.appendChild(careerBlock(person.career));
				columns.appendChild(side);
			}
			wrap.appendChild(columns);
			return wrap;
		}

		// Renderização ------------------------------------------------------------------------------------

		function render() {
			if (!page.isConnected && page.parentNode) { return; }
			page.replaceChildren();
			page.appendChild(brand());
			if (!state) {
				page.appendChild(el('p', 'tb-empty', 'Carregando…'));
				return;
			}
			page.appendChild(tabs());
			const scrollTop = root.scrollTop;
			if (person) {
				page.appendChild(personTab());
			} else if (tab === 'resume') {
				page.appendChild(resumeTab());
			} else if (tab === 'network') {
				page.appendChild(networkTab());
			} else if (tab === 'search') {
				page.appendChild(searchTab());
			} else {
				page.appendChild(profileTab());
			}
			root.scrollTop = scrollTop;
		}

		render();
		load().then(function (result) {
			if (!result.ok) {
				page.replaceChildren(brand(), el('p', 'tb-empty', 'Não foi possível abrir o Elos.'),
					button('Tentar de novo', 'coe-button--primary', function () { render(); load(); }));
			}
		});
	});
})();
