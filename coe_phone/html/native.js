// Apps nativos do smartphone: Telefone, Contatos e Mensagens.
(function () {
	'use strict';

	const phone = window.CoePhone;
	const COLORS = ['#3f9a5c', '#3d7ab8', '#8a6d3b', '#b5487a', '#c17a3a', '#4f7cac', '#6b5bb5', '#3f8f7a'];
	const STATUS = { answered: 'Atendida', missed: 'Perdida', declined: 'Recusada', busy: 'Ocupado', unavailable: 'Fora de área' };

	function el(tag, className, text) {
		const node = document.createElement(tag);
		if (className) { node.className = className; }
		if (text !== undefined && text !== null) { node.textContent = String(text); }
		return node;
	}

	function button(label, className, onClick) {
		const node = el('button', 'coe-button ' + (className || ''), label);
		node.type = 'button';
		node.addEventListener('click', function (event) { event.stopPropagation(); onClick(event); });
		return node;
	}

	function input(placeholder, value, type) {
		const node = el('input', 'coe-field');
		node.type = type || 'text';
		node.placeholder = placeholder || '';
		node.value = value || '';
		return node;
	}

	function avatar(name) {
		const label = String(name || '?');
		let hash = 0;
		for (let i = 0; i < label.length; i++) { hash = (hash * 31 + label.charCodeAt(i)) >>> 0; }
		const node = el('i', 'ph-avatar', /\d/.test(label.charAt(0)) ? '#' : label.charAt(0).toUpperCase());
		node.style.setProperty('--avatar', COLORS[hash % COLORS.length]);
		return node;
	}

	function ago(seconds) {
		const diff = Math.max(0, Math.floor(Date.now() / 1000) - Number(seconds || 0));
		if (diff < 60) { return 'agora'; }
		if (diff < 3600) { return Math.floor(diff / 60) + ' min'; }
		if (diff < 86400) { return Math.floor(diff / 3600) + ' h'; }
		return Math.floor(diff / 86400) + ' d';
	}

	function clock(seconds) {
		const date = new Date(Number(seconds || 0) * 1000);
		return String(date.getHours()).padStart(2, '0') + ':' + String(date.getMinutes()).padStart(2, '0');
	}

	function empty(text) {
		return el('p', 'tb-empty', text);
	}

	function row(name, detail, side, onClick) {
		const node = el('div', 'ph-row');
		const body = el('div', 'ph-row-body');
		body.append(el('strong', null, name), el('small', null, detail));
		node.append(avatar(name), body);
		if (side) { node.appendChild(side); }
		if (onClick) { node.addEventListener('click', onClick); }
		return node;
	}

	function fail(api, result) {
		api.status(api.errorText(result && result.error), 'error');
	}

	// Telefone ---------------------------------------------------------------------------------------------

	phone.register('phone', function (root, api, args) {
		const tabs = el('div', 'tb-tabs');
		const body = el('div', 'ph-form');
		root.append(tabs, body);
		let typed = String(args.number || '').replace(/\D/g, '');

		function tab(id, label) {
			const node = el('button', 'tb-tab', label);
			node.type = 'button';
			node.dataset.tab = id;
			node.addEventListener('click', function () { show(id); });
			tabs.appendChild(node);
		}
		tab('keypad', 'Teclado');
		tab('recents', 'Recentes');

		function show(id) {
			tabs.querySelectorAll('.tb-tab').forEach(function (node) { node.classList.toggle('is-active', node.dataset.tab === id); });
			body.replaceChildren();
			if (id === 'keypad') { keypad(); } else { recents(); }
		}

		function keypad() {
			const display = el('div', 'ph-display');
			const paint = function () {
				display.textContent = typed ? api.formatNumber(typed) : 'Digite um número';
				display.classList.toggle('is-empty', !typed);
			};
			const pad = el('div', 'ph-keypad');
			const letters = ['', 'ABC', 'DEF', 'GHI', 'JKL', 'MNO', 'PQRS', 'TUV', 'WXYZ'];
			const press = function (digit) {
				if (typed.length < 12) { typed += digit; paint(); }
			};
			for (let i = 1; i <= 9; i++) {
				const key = el('button', 'ph-key', String(i));
				key.type = 'button';
				key.appendChild(el('small', null, letters[i - 1] || '\u00a0'));
				key.addEventListener('click', function () { press(String(i)); });
				pad.appendChild(key);
			}
			const clear = el('button', 'ph-key ph-key--muted', 'Limpar');
			clear.type = 'button';
			clear.addEventListener('click', function () { typed = ''; paint(); });
			const zero = el('button', 'ph-key', '0');
			zero.type = 'button';
			zero.addEventListener('click', function () { press('0'); });
			const erase = el('button', 'ph-key ph-key--muted', '⌫');
			erase.type = 'button';
			erase.addEventListener('click', function () { typed = typed.slice(0, -1); paint(); });
			const dial = el('button', 'ph-key ph-key--call', 'Ligar');
			dial.type = 'button';
			dial.style.gridColumn = 'span 2';
			dial.addEventListener('click', function () {
				if (!typed) { api.status('Digite um número.', 'error'); return; }
				api.dial(typed);
			});
			const video = el('button', 'ph-key ph-key--call', 'Vídeo');
			video.type = 'button';
			video.title = 'Chamada de vídeo';
			video.addEventListener('click', function () {
				if (!typed) { api.status('Digite um número.', 'error'); return; }
				api.dial(typed, 'video');
			});
			pad.append(clear, zero, erase, dial, video);
			const mine = el('p', 'ph-mine', 'Meu número ');
			mine.appendChild(el('strong', null, api.profile().display || 'sem chip'));
			body.append(display, pad, mine);
			paint();
		}

		function recents() {
			body.appendChild(empty('Carregando...'));
			api.call('phone', 'recents').then(function (result) {
				body.replaceChildren();
				if (!result || !result.ok) { fail(api, result); return; }
				const list = el('div', 'ph-list');
				(result.data.recents || []).forEach(function (entry) {
					const arrow = entry.outgoing ? '↗ ' : '↙ ';
					const detail = arrow + (entry.kind === 'video' ? 'Vídeo · ' : '') + (STATUS[entry.status] || entry.status) +
						(entry.status === 'answered' && entry.duration ? ' · ' + Math.ceil(entry.duration / 60) + ' min' : '');
					const side = el('div', 'ph-row-side', ago(entry.at));
					const node = row(entry.name, detail, side);
					if (!entry.outgoing && entry.status === 'missed') { node.classList.add('is-missed'); }
					const actions = el('div', 'ph-row-actions');
					actions.hidden = true;
					actions.append(
						button('Ligar', 'coe-button--primary', function () { api.dial(entry.number); }),
						button('Vídeo', '', function () { api.dial(entry.number, 'video'); }),
						button('Mensagem', '', function () { api.openApp('messages', { number: entry.number }); })
					);
					if (entry.name === entry.number) {
						actions.appendChild(button('Salvar', '', function () { api.openApp('contacts', { number: entry.number }); }));
					}
					node.addEventListener('click', function () { actions.hidden = !actions.hidden; });
					list.append(node, actions);
				});
				body.appendChild(list.childElementCount ? list : empty('Nenhuma ligação ainda.'));
			});
		}

		// Digitar no teclado físico também funciona na aba Teclado.
		root.addEventListener('keydown', function (event) {
			if (event.target.tagName === 'INPUT' || event.target.tagName === 'TEXTAREA') { return; }
			if (!tabs.querySelector('[data-tab="keypad"].is-active')) { return; }
			if (/^\d$/.test(event.key)) { typed = (typed + event.key).slice(0, 12); show('keypad'); }
			if (event.key === 'Backspace') { typed = typed.slice(0, -1); show('keypad'); }
			if (event.key === 'Enter' && typed) { api.dial(typed); }
		});
		root.tabIndex = -1;
		root.focus();
		show('keypad');
	});

	// Contatos ---------------------------------------------------------------------------------------------

	phone.register('contacts', function (root, api, args) {
		let contacts = [];

		function form(contact) {
			root.replaceChildren();
			const box = el('div', 'ph-form');
			const name = input('Nome', contact && contact.name);
			name.maxLength = 32;
			const number = input('555-0000', contact && contact.number);
			number.maxLength = 16;
			const label = function (text, field) {
				const node = el('label', null, text);
				node.appendChild(field);
				return node;
			};
			const actions = el('div', 'tb-actions');
			const save = button('Salvar', 'coe-button--primary', function () {
				save.disabled = true;
				api.call('contacts', 'save', { id: contact && contact.id, name: name.value, number: number.value }).then(function (result) {
					save.disabled = false;
					if (!result || !result.ok) { fail(api, result); return; }
					api.status('Contato salvo.', 'success');
					list();
				});
			});
			actions.append(button('Cancelar', '', list), save);
			box.append(el('h3', 'tb-title', contact && contact.id ? 'Editar contato' : 'Novo contato'), label('Nome', name), label('Número', number), actions);
			root.appendChild(box);
			(contact && contact.name ? number : name).focus();
		}

		function paint(filter) {
			const listNode = root.querySelector('.ph-list');
			listNode.replaceChildren();
			const term = filter.trim().toLowerCase();
			const shown = contacts.filter(function (contact) {
				return !term || contact.name.toLowerCase().indexOf(term) >= 0 || contact.display.replace(/\D/g, '').indexOf(term.replace(/\D/g, '') || '\u0000') >= 0;
			});
			shown.forEach(function (contact) {
				const node = row(contact.name, contact.display);
				const actions = el('div', 'ph-row-actions');
				actions.hidden = true;
				actions.append(
					button('Ligar', 'coe-button--primary', function () { api.dial(contact.number || contact.display); }),
					button('Vídeo', '', function () { api.dial(contact.number || contact.display, 'video'); }),
					button('Mensagem', '', function () { api.openApp('messages', { number: contact.display }); }),
					button('Editar', '', function () { form({ id: contact.id, name: contact.name, number: contact.display }); }),
					button('Apagar', 'coe-button--danger', function () {
						api.call('contacts', 'delete', { id: contact.id }).then(function (result) {
							if (!result || !result.ok) { fail(api, result); return; }
							api.status('Contato apagado.', 'success');
							list();
						});
					})
				);
				node.addEventListener('click', function () { actions.hidden = !actions.hidden; });
				listNode.append(node, actions);
			});
			if (!shown.length) { listNode.appendChild(empty(contacts.length ? 'Nenhum contato encontrado.' : 'Sua agenda está vazia.')); }
		}

		function list() {
			root.replaceChildren();
			const head = el('div', 'ph-head');
			const search = input('Buscar contato');
			head.append(search, button('+ Novo', 'coe-button--primary', function () { form(null); }));
			root.append(head, el('div', 'ph-list'));
			root.querySelector('.ph-list').appendChild(empty('Carregando...'));
			search.addEventListener('input', function () { paint(search.value); });
			api.call('contacts', 'list').then(function (result) {
				if (!result || !result.ok) { fail(api, result); return; }
				contacts = result.data || [];
				paint(search.value);
			});
		}

		if (args.number) { form({ number: args.number }); } else { list(); }
	});

	// Mensagens --------------------------------------------------------------------------------------------

	phone.register('messages', function (root, api, args) {
		let openNumber = null;

		function threads() {
			openNumber = null;
			root.replaceChildren();
			const head = el('div', 'ph-head');
			const number = input('Número para nova conversa');
			number.maxLength = 16;
			const start = function () {
				if (number.value.replace(/\D/g, '')) { conversation(number.value); }
			};
			number.addEventListener('keydown', function (event) { if (event.key === 'Enter') { start(); } });
			head.append(number, button('Abrir', 'coe-button--primary', start));
			const listNode = el('div', 'ph-list');
			listNode.appendChild(empty('Carregando...'));
			root.append(head, listNode);
			api.call('messages', 'threads').then(function (result) {
				listNode.replaceChildren();
				if (!result || !result.ok) { fail(api, result); return; }
				let total = 0;
				(result.data || []).forEach(function (thread) {
					total += thread.unread || 0;
					const side = el('div', 'ph-row-side', ago(thread.at));
					if (thread.unread) { side.appendChild(el('span', 'ph-unread', thread.unread)); }
					listNode.appendChild(row(thread.name, (thread.mine ? 'Você: ' : '') + thread.last, side, function () { conversation(thread.number); }));
				});
				api.setUnread(total);
				if (!listNode.childElementCount) { listNode.appendChild(empty('Nenhuma conversa ainda.')); }
			});
		}

		function bubble(message) {
			const node = el('div', 'ph-bubble' + (message.mine ? ' is-mine' : ''), message.body);
			node.appendChild(el('small', null, clock(message.at)));
			return node;
		}

		function conversation(number) {
			root.replaceChildren();
			root.appendChild(empty('Carregando...'));
			api.call('messages', 'open', { number: number }).then(function (result) {
				root.replaceChildren();
				if (!result || !result.ok) { fail(api, result); threads(); return; }
				const data = result.data;
				openNumber = data.number;
				const head = el('div', 'ph-thread-head');
				const who = el('div');
				who.append(el('strong', null, data.name), el('small', null, data.name !== data.number ? data.number : ''));
				head.append(button('‹', '', threads), avatar(data.name), who, button('Ligar', 'coe-button--primary', function () { api.dial(data.number); }));
				const thread = el('div', 'ph-thread');
				(data.messages || []).forEach(function (message) { thread.appendChild(bubble(message)); });
				if (!thread.childElementCount) { thread.appendChild(empty('Comece a conversa.')); }
				const compose = el('div', 'ph-compose');
				const text = el('textarea', 'coe-field');
				text.maxLength = 500;
				text.placeholder = 'Mensagem';
				const send = function () {
					if (!text.value.trim()) { return; }
					const body = text.value;
					sendButton.disabled = true;
					api.call('messages', 'send', { number: data.number, body: body }).then(function (sent) {
						sendButton.disabled = false;
						if (!sent || !sent.ok) { fail(api, sent); return; }
						const placeholder = thread.querySelector('.tb-empty');
						if (placeholder) { placeholder.remove(); }
						thread.appendChild(bubble(sent.data));
						text.value = '';
						text.focus();
						root.scrollTop = root.scrollHeight;
					});
				};
				const sendButton = button('Enviar', 'coe-button--primary', send);
				text.addEventListener('keydown', function (event) {
					if (event.key === 'Enter' && !event.shiftKey) { event.preventDefault(); send(); }
				});
				compose.append(text, sendButton);
				root.append(head, thread, compose);
				root.scrollTop = root.scrollHeight;
				text.focus();
				api.refresh();
			});
		}

		api.on('message', function (message) {
			if (openNumber && message.number === openNumber) { conversation(openNumber); }
			else if (!openNumber) { threads(); }
		});

		if (args.number) { conversation(args.number); } else { threads(); }
	});
})();
