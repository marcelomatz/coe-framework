// Telefone básico (coe_mobile): Telefone, Contatos, Mensagens e Ajustes. O servidor decide tudo; a tela mostra e pede.
(function () {
	'use strict';

	const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'coe_mobile';
	const ERRORS = {
		not_ready: 'O telefone ainda está ligando.', unavailable: 'Serviço indisponível.', busy: 'Aguarde um instante.',
		no_character: 'Personagem não carregado.', no_phone: 'Você não está com o telefone.',
		invalid_number: 'Número inválido.', number_not_found: 'Número inexistente.',
		unreachable: 'Fora de área ou desligado.', line_busy: 'Linha ocupada.',
		already_in_call: 'Você já está em uma ligação.', not_in_call: 'A ligação já terminou.',
		invalid_name: 'Nome inválido.', invalid_message: 'Mensagem vazia ou longa demais.',
		contacts_full: 'A agenda está cheia.', duplicate_contact: 'Esse número já está na agenda.',
		contact_not_found: 'Contato não encontrado.', database_error: 'Falha ao consultar. Tente de novo.',
		timeout: 'Sem resposta do servidor.', closed: 'Telefone fechado.'
	};
	const ENDED = {
		ended: 'Ligação encerrada', missed: 'Sem resposta', declined: 'Ligação recusada',
		cancelled: 'Ligação cancelada', unreachable: 'Ligação caiu'
	};
	const CALL_STATUS = {
		answered: 'Atendida', missed: 'Perdida', declined: 'Recusada', busy: 'Ocupado', unreachable: 'Fora de área'
	};
	const WALLPAPERS = { padrao: 'Padrão', noite: 'Noite', oceano: 'Oceano', grafite: 'Grafite' };
	const RINGTONES = { classico: 'Clássico', digital: 'Digital', suave: 'Suave' };
	const ICONS = {
		phone: '<path d="M5 3h4l2 5-2.5 1.5a11 11 0 0 0 6 6L16 13l5 2v4a2 2 0 0 1-2 2A17 17 0 0 1 3 5a2 2 0 0 1 2-2"/>',
		contacts: '<circle cx="12" cy="8" r="4"/><path d="M4 21a8 8 0 0 1 16 0"/>',
		messages: '<path d="M4 4h16v12H8l-4 4z"/>',
		settings: '<circle cx="12" cy="12" r="3"/><path d="M12 2v3M12 19v3M2 12h3M19 12h3M4.9 4.9l2.1 2.1M17 17l2.1 2.1M4.9 19.1 7 17M17 7l2.1-2.1"/>',
		back: '<path d="M15 5l-7 7 7 7"/>',
		plus: '<path d="M12 5v14M5 12h14"/>',
		send: '<path d="M4 12l16-8-6 16-2-6z"/>',
		trash: '<path d="M4 7h16M9 7V4h6v3M6 7l1 13h10l1-13"/>',
		edit: '<path d="M4 20h4L19 9l-4-4L4 16z"/>',
		hangup: '<path d="M3 14c5-5 13-5 18 0l-2 3-4-1v-3a10 10 0 0 0-6 0v3l-4 1z"/>',
		incoming: '<path d="M17 7 7 17M7 9v8h8"/>',
		outgoing: '<path d="M7 17 17 7M9 7h8v8"/>',
		erase: '<path d="M9 5h11v14H9l-6-7z"/><path d="M12 9l5 6M17 9l-5 6"/>'
	};

	const els = {
		phone: document.getElementById('phone'),
		screen: document.getElementById('mb-screen'),
		view: document.getElementById('mb-view'),
		call: document.getElementById('mb-call'),
		toast: document.getElementById('mb-toast'),
		clock: document.getElementById('mb-clock'),
		home: document.getElementById('mb-home'),
		hint: document.getElementById('mb-hint')
	};

	const state = {
		profile: null, route: { app: 'home' }, contacts: null, threads: null, recents: null, thread: null,
		call: null, unread: 0, missed: 0, dial: '', focused: false
	};
	let toastTimer = null;
	let callTimer = null;
	let endedTimer = null;

	// Utilidades -----------------------------------------------------------------------------------------------

	function el(tag, className, text) {
		const node = document.createElement(tag);
		if (className) { node.className = className; }
		if (text !== undefined && text !== null) { node.textContent = String(text); }
		return node;
	}
	function icon(name, className) {
		const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
		svg.setAttribute('viewBox', '0 0 24 24');
		svg.setAttribute('class', 'mb-icon' + (className ? ' ' + className : ''));
		svg.setAttribute('aria-hidden', 'true');
		svg.innerHTML = ICONS[name] || '';
		return svg;
	}
	function button(label, className, onClick, iconName) {
		const node = el('button', className);
		node.type = 'button';
		if (iconName) {
			node.append(icon(iconName));
			node.setAttribute('aria-label', label);
			node.title = label;
		} else {
			node.textContent = label;
		}
		node.addEventListener('click', onClick);
		return node;
	}
	function post(name, body) {
		return fetch('https://' + resource + '/' + name, {
			method: 'POST',
			headers: { 'Content-Type': 'application/json; charset=UTF-8' },
			body: JSON.stringify(body || {})
		}).then(function (response) { return response.json(); }).catch(function () { return { ok: false, error: 'closed' }; });
	}
	function toast(text, kind) {
		clearTimeout(toastTimer);
		els.toast.textContent = text || '';
		els.toast.className = 'mb-toast' + (kind ? ' is-' + kind : '');
		els.toast.hidden = !text;
		if (text) { toastTimer = setTimeout(function () { els.toast.hidden = true; }, 3200); }
	}
	function errorText(result) {
		return (result && (ERRORS[result.error] || result.message)) || 'Não foi possível concluir.';
	}
	function act(action, data) {
		return post('action', { action: action, data: data || {} }).then(function (result) {
			if (!result || !result.ok) { toast(errorText(result), 'error'); return null; }
			return result.data || {};
		});
	}
	function digits(value) { return String(value || '').replace(/\D/g, ''); }
	function formatNumber(value) {
		const raw = digits(value);
		const prefix = state.profile ? String(state.profile.limits.prefix) : '555';
		if (raw.length <= prefix.length) { return raw; }
		return raw.slice(0, prefix.length) + '-' + raw.slice(prefix.length);
	}
	function maxDigits() {
		const limits = state.profile && state.profile.limits;
		return limits ? String(limits.prefix).length + Number(limits.digits) : 7;
	}
	function contactFor(number) {
		const list = state.contacts || [];
		for (let i = 0; i < list.length; i += 1) { if (list[i].number === number) { return list[i]; } }
		return null;
	}
	function pad(value) { return String(value).padStart(2, '0'); }
	function when(seconds) {
		if (!seconds) { return ''; }
		const date = new Date(seconds * 1000);
		const now = new Date();
		if (date.toDateString() === now.toDateString()) { return pad(date.getHours()) + ':' + pad(date.getMinutes()); }
		return pad(date.getDate()) + '/' + pad(date.getMonth() + 1);
	}
	function duration(seconds) {
		const total = Math.max(0, Math.floor(seconds || 0));
		return pad(Math.floor(total / 60)) + ':' + pad(total % 60);
	}
	function initials(name) {
		const parts = String(name || '').trim().split(/\s+/).filter(Boolean);
		if (!parts.length) { return '#'; }
		return (parts[0][0] + (parts.length > 1 ? parts[parts.length - 1][0] : '')).toUpperCase();
	}
	function avatar(name) { return el('span', 'mb-avatar', initials(name)); }
	function tick() {
		const now = new Date();
		els.clock.textContent = pad(now.getHours()) + ':' + pad(now.getMinutes());
	}

	// Sons (gerados aqui, sem arquivos) ------------------------------------------------------------------------

	const sound = { ctx: null, timer: null };
	function audio() {
		if (!sound.ctx) {
			const Context = window.AudioContext || window.webkitAudioContext;
			if (!Context) { return null; }
			sound.ctx = new Context();
		}
		return sound.ctx;
	}
	function beep(frequencies, length, gainValue) {
		const ctx = audio();
		if (!ctx || gainValue <= 0) { return; }
		const gain = ctx.createGain();
		gain.gain.setValueAtTime(0, ctx.currentTime);
		gain.gain.linearRampToValueAtTime(gainValue, ctx.currentTime + 0.02);
		gain.gain.setValueAtTime(gainValue, ctx.currentTime + length - 0.04);
		gain.gain.linearRampToValueAtTime(0, ctx.currentTime + length);
		gain.connect(ctx.destination);
		frequencies.forEach(function (frequency) {
			const osc = ctx.createOscillator();
			osc.type = 'sine';
			osc.frequency.value = frequency;
			osc.connect(gain);
			osc.start();
			osc.stop(ctx.currentTime + length);
		});
	}
	const PATTERNS = {
		classico: { tones: [440, 480], length: 1.2, every: 3000 },
		digital: { tones: [880], length: 0.18, every: 450, bursts: 4, pause: 1600 },
		suave: { tones: [523, 659], length: 0.9, every: 2400 },
		ringback: { tones: [425], length: 1.0, every: 4000 }
	};
	function stopSound() {
		clearTimeout(sound.timer);
		sound.timer = null;
	}
	function playLoop(name, volume) {
		stopSound();
		const pattern = PATTERNS[name] || PATTERNS.classico;
		const gainValue = Math.max(0, Math.min(1, volume)) * 0.25;
		let count = 0;
		function step() {
			beep(pattern.tones, pattern.length, gainValue);
			count += 1;
			let wait = pattern.every;
			if (pattern.bursts) { wait = count % pattern.bursts === 0 ? pattern.pause : pattern.every; }
			sound.timer = setTimeout(step, wait);
		}
		step();
	}
	function settings() { return (state.profile && state.profile.settings) || {}; }
	function syncSound() {
		const call = state.call;
		if (call && call.state === 'ringing' && call.direction === 'incoming') {
			if (settings().silent) { stopSound(); } else { playLoop(settings().ringtone, settings().volume / 10); }
		} else if (call && call.state === 'ringing' && call.direction === 'outgoing') {
			playLoop('ringback', 0.5);
		} else {
			stopSound();
		}
	}

	// Moldura das telas ----------------------------------------------------------------------------------------

	function go(route) {
		state.route = route;
		render();
	}
	function appHeader(title, onBack, action) {
		const header = el('header', 'mb-apphead');
		header.append(button('Voltar', 'mb-iconbtn', onBack || function () { go({ app: 'home' }); }, 'back'));
		header.append(el('h1', 'mb-apptitle', title));
		header.append(action || el('span', 'mb-iconbtn is-ghost'));
		return header;
	}
	function emptyState(text) { return el('p', 'mb-empty', text); }
	function loading() { return el('p', 'mb-empty', 'Carregando…'); }

	function render() {
		const route = state.route;
		els.view.replaceChildren();
		els.screen.dataset.wallpaper = settings().wallpaper || 'padrao';
		els.screen.dataset.app = route.app;
		const renderers = {
			home: renderHome, phone: renderPhone, contacts: renderContacts, contact: renderContact,
			contact_edit: renderContactEdit, messages: renderThreads, thread: renderThread, compose: renderCompose,
			settings: renderSettings
		};
		(renderers[route.app] || renderHome)(route);
	}

	// Início ---------------------------------------------------------------------------------------------------

	function renderHome() {
		const now = new Date();
		const top = el('div', 'mb-home');
		top.append(el('p', 'mb-bigclock', pad(now.getHours()) + ':' + pad(now.getMinutes())));
		top.append(el('p', 'mb-date', now.toLocaleDateString('pt-BR', { weekday: 'long', day: 'numeric', month: 'long' })));
		const card = el('div', 'mb-numbercard');
		card.append(el('span', 'mb-numbercard-label', 'Meu número'));
		card.append(el('strong', 'mb-numbercard-value', state.profile ? state.profile.number : ''));
		top.append(card);

		const grid = el('div', 'mb-apps');
		[
			{ id: 'phone', label: 'Telefone', badge: state.missed },
			{ id: 'contacts', label: 'Contatos' },
			{ id: 'messages', label: 'Mensagens', badge: state.unread },
			{ id: 'settings', label: 'Ajustes' }
		].forEach(function (app) {
			const tile = el('button', 'mb-app mb-app--' + app.id);
			tile.type = 'button';
			const glyph = el('span', 'mb-app-icon');
			glyph.append(icon(app.id));
			if (app.badge) { glyph.append(el('span', 'mb-badge', app.badge > 99 ? '99+' : app.badge)); }
			tile.append(glyph, el('span', 'mb-app-label', app.label));
			tile.addEventListener('click', function () { openApp(app.id); });
			grid.append(tile);
		});
		els.view.append(top, grid);
	}

	function openApp(app) {
		if (app === 'phone') { state.missed = 0; go({ app: 'phone', tab: 'keypad' }); loadContacts(); return; }
		if (app === 'contacts') { go({ app: 'contacts' }); loadContacts(); return; }
		if (app === 'messages') { go({ app: 'messages' }); loadThreads(); loadContacts(); return; }
		go({ app: app });
	}

	function loadContacts() {
		return act('contacts').then(function (data) {
			if (data) { state.contacts = data.contacts || []; rerender(['contacts', 'contact', 'phone', 'compose']); }
		});
	}
	function loadThreads() {
		return act('threads').then(function (data) {
			if (!data) { return; }
			state.threads = data.threads || [];
			state.unread = state.threads.reduce(function (sum, t) { return sum + (t.unread || 0); }, 0);
			rerender(['messages']);
		});
	}
	function loadRecents() {
		return act('recents').then(function (data) {
			if (data) { state.recents = data.recents || []; rerender(['phone']); }
		});
	}
	function rerender(apps) {
		if (apps.indexOf(state.route.app) !== -1) { render(); }
	}

	// Telefone -------------------------------------------------------------------------------------------------

	function startCall(number) {
		return act('call_start', { number: number }).then(function (data) {
			if (data && data.call) { setCall(data.call); }
		});
	}

	function renderPhone(route) {
		const tabs = el('div', 'mb-tabs');
		[['keypad', 'Teclado'], ['recents', 'Recentes']].forEach(function (pair) {
			const tab = button(pair[1], 'mb-tab' + (route.tab === pair[0] ? ' is-active' : ''), function () {
				go({ app: 'phone', tab: pair[0] });
				if (pair[0] === 'recents') { loadRecents(); }
			});
			tabs.append(tab);
		});
		els.view.append(appHeader('Telefone'), tabs);
		if (route.tab === 'recents') { renderRecents(); } else { renderKeypad(); }
	}

	function renderKeypad() {
		const wrap = el('div', 'mb-keypad');
		const display = el('div', 'mb-dial');
		const value = el('span', 'mb-dial-value', formatNumber(state.dial));
		const known = contactFor(formatNumber(state.dial));
		const label = el('span', 'mb-dial-name', known ? known.name : '');
		display.append(value, label);
		const keys = el('div', 'mb-keys');
		['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', 'del'].forEach(function (key) {
			if (key === '') { keys.append(el('span')); return; }
			if (key === 'del') {
				keys.append(button('Apagar', 'mb-key is-erase', function () {
					state.dial = state.dial.slice(0, -1);
					render();
				}, 'erase'));
				return;
			}
			keys.append(button(key, 'mb-key', function () { pressDigit(key); }));
		});
		const dial = button('Ligar', 'mb-callbtn', function () {
			if (state.dial.length) { startCall(state.dial); }
		}, 'phone');
		dial.disabled = state.dial.length !== maxDigits();
		wrap.append(display, keys, dial);
		els.view.append(wrap);
	}

	function pressDigit(key) {
		if (state.dial.length < maxDigits()) {
			state.dial += key;
			beep([697 + Number(key) * 20], 0.08, 0.05);
			render();
		}
	}

	function renderRecents() {
		const list = el('ul', 'mb-list');
		if (!state.recents) { els.view.append(loading()); return; }
		if (!state.recents.length) { els.view.append(emptyState('Nenhuma ligação ainda.')); return; }
		state.recents.forEach(function (entry) {
			const item = el('li', 'mb-row' + (entry.status === 'missed' && !entry.outgoing ? ' is-missed' : ''));
			const main = el('button', 'mb-row-main');
			main.type = 'button';
			main.append(avatar(entry.name || entry.number));
			const info = el('span', 'mb-row-info');
			info.append(el('span', 'mb-row-title', entry.name || entry.number));
			const meta = el('span', 'mb-row-meta');
			meta.append(icon(entry.outgoing ? 'outgoing' : 'incoming', 'is-small'));
			const status = entry.status === 'answered' ? duration(entry.duration) : (CALL_STATUS[entry.status] || entry.status);
			meta.append(document.createTextNode(' ' + status));
			info.append(meta);
			main.append(info, el('span', 'mb-row-time', when(entry.at)));
			main.addEventListener('click', function () { startCall(entry.number); });
			item.append(main);
			list.append(item);
		});
		els.view.append(list);
	}

	// Contatos -------------------------------------------------------------------------------------------------

	function renderContacts(route) {
		const add = button('Novo contato', 'mb-iconbtn', function () { go({ app: 'contact_edit', back: { app: 'contacts' } }); }, 'plus');
		els.view.append(appHeader('Contatos', null, add));
		const search = el('input', 'coe-field mb-search');
		search.type = 'search';
		search.placeholder = 'Buscar';
		search.value = route.query || '';
		search.addEventListener('input', function () {
			state.route.query = search.value;
			fill();
		});
		const list = el('ul', 'mb-list');
		els.view.append(search, list);
		function fill() {
			list.replaceChildren();
			if (!state.contacts) { list.append(loading()); return; }
			const query = (state.route.query || '').trim().toLowerCase();
			const matches = state.contacts.filter(function (c) {
				return !query || c.name.toLowerCase().indexOf(query) !== -1 || c.number.indexOf(query) !== -1;
			});
			if (!matches.length) { list.append(emptyState(state.contacts.length ? 'Nenhum resultado.' : 'Sua agenda está vazia.')); return; }
			matches.forEach(function (contact) {
				const item = el('li', 'mb-row');
				const main = el('button', 'mb-row-main');
				main.type = 'button';
				const info = el('span', 'mb-row-info');
				info.append(el('span', 'mb-row-title', contact.name), el('span', 'mb-row-meta', contact.number));
				main.append(avatar(contact.name), info);
				main.addEventListener('click', function () { go({ app: 'contact', id: contact.id }); });
				item.append(main);
				list.append(item);
			});
		}
		fill();
		if (route.query) { search.focus(); }
	}

	function findContact(id) {
		return (state.contacts || []).filter(function (c) { return c.id === id; })[0] || null;
	}

	function renderContact(route) {
		const contact = findContact(route.id);
		if (!contact) { go({ app: 'contacts' }); return; }
		const edit = button('Editar', 'mb-iconbtn', function () {
			go({ app: 'contact_edit', id: contact.id, back: { app: 'contact', id: contact.id } });
		}, 'edit');
		els.view.append(appHeader('Contato', function () { go({ app: 'contacts' }); }, edit));
		const card = el('div', 'mb-contactcard');
		card.append(el('span', 'mb-avatar is-large', initials(contact.name)), el('h2', 'mb-contact-name', contact.name),
			el('p', 'mb-contact-number', contact.number));
		const actions = el('div', 'mb-quick');
		actions.append(
			quick('Ligar', 'phone', function () { startCall(contact.number); }),
			quick('Mensagem', 'messages', function () { openThread(contact.number); })
		);
		const remove = button('Apagar contato', 'coe-button coe-button--danger mb-wide', function () {
			const ask = window.CoeUI && window.CoeUI.confirm
				? window.CoeUI.confirm({ title: 'Apagar contato', message: 'Apagar ' + contact.name + ' da agenda?', confirmLabel: 'Apagar', danger: true })
				: Promise.resolve(true);
			ask.then(function (ok) {
				if (!ok) { return; }
				act('contact_delete', { id: contact.id }).then(function (data) {
					if (data) { state.contacts = data.contacts || []; toast('Contato apagado.', 'success'); go({ app: 'contacts' }); }
				});
			});
		});
		els.view.append(card, actions, remove);
	}

	function quick(label, iconName, onClick) {
		const node = el('button', 'mb-quickbtn');
		node.type = 'button';
		node.append(icon(iconName), el('span', null, label));
		node.addEventListener('click', onClick);
		return node;
	}

	function field(labelText, input) {
		const wrap = el('label', 'mb-field');
		wrap.append(el('span', 'mb-field-label', labelText), input);
		return wrap;
	}

	function renderContactEdit(route) {
		const contact = route.id ? findContact(route.id) : null;
		const back = function () { go(route.back || { app: 'contacts' }); };
		els.view.append(appHeader(contact ? 'Editar contato' : 'Novo contato', back));
		const form = el('form', 'mb-form');
		const name = el('input', 'coe-field');
		name.maxLength = state.profile.limits.nameMax;
		name.value = contact ? contact.name : (route.name || '');
		name.placeholder = 'Nome';
		const number = el('input', 'coe-field mb-mono');
		number.inputMode = 'numeric';
		number.placeholder = state.profile.limits.prefix + '-' + '0'.repeat(state.profile.limits.digits);
		number.value = contact ? contact.number : (route.number || '');
		number.addEventListener('input', function () { number.value = formatNumber(number.value.slice(0, maxDigits() + 1)); });
		const save = el('button', 'coe-button coe-button--primary mb-wide', 'Salvar');
		save.type = 'submit';
		form.append(field('Nome', name), field('Número', number), save);
		form.addEventListener('submit', function (event) {
			event.preventDefault();
			save.disabled = true;
			act('contact_save', { id: contact ? contact.id : undefined, name: name.value, number: number.value }).then(function (data) {
				save.disabled = false;
				if (!data) { return; }
				state.contacts = data.contacts || [];
				toast('Contato salvo.', 'success');
				const saved = state.contacts.filter(function (c) { return c.number === formatNumber(number.value); })[0];
				go(saved ? { app: 'contact', id: saved.id } : { app: 'contacts' });
			});
		});
		els.view.append(form);
		name.focus();
	}

	// Mensagens ------------------------------------------------------------------------------------------------

	function renderThreads() {
		const add = button('Nova mensagem', 'mb-iconbtn', function () { go({ app: 'compose' }); }, 'plus');
		els.view.append(appHeader('Mensagens', null, add));
		const list = el('ul', 'mb-list');
		if (!state.threads) { els.view.append(loading()); return; }
		if (!state.threads.length) { els.view.append(emptyState('Nenhuma conversa.')); return; }
		state.threads.forEach(function (thread) {
			const item = el('li', 'mb-row' + (thread.unread ? ' is-unread' : ''));
			const main = el('button', 'mb-row-main');
			main.type = 'button';
			const info = el('span', 'mb-row-info');
			info.append(el('span', 'mb-row-title', thread.name || thread.number),
				el('span', 'mb-row-meta mb-preview', (thread.mine ? 'Você: ' : '') + thread.body));
			const side = el('span', 'mb-row-side');
			side.append(el('span', 'mb-row-time', when(thread.at)));
			if (thread.unread) { side.append(el('span', 'mb-badge is-inline', thread.unread)); }
			main.append(avatar(thread.name || thread.number), info, side);
			main.addEventListener('click', function () { openThread(thread.number); });
			item.append(main);
			list.append(item);
		});
		els.view.append(list);
	}

	function openThread(number) {
		state.thread = { number: number, name: (contactFor(number) || {}).name, messages: null };
		go({ app: 'thread', number: number });
		act('thread', { number: number }).then(function (data) {
			if (!data || !state.thread || state.thread.number !== data.number) { return; }
			state.thread = { number: data.number, name: data.name, messages: data.messages || [] };
			if (state.threads) {
				state.threads.forEach(function (t) { if (t.number === data.number) { t.unread = 0; } });
				state.unread = state.threads.reduce(function (sum, t) { return sum + (t.unread || 0); }, 0);
			}
			rerender(['thread']);
		});
	}

	function composer(number, onSent) {
		const form = el('form', 'mb-composer');
		const input = el('textarea', 'coe-field mb-composer-input');
		input.rows = 1;
		input.maxLength = state.profile.limits.bodyMax;
		input.placeholder = 'Mensagem';
		const send = el('button', 'mb-sendbtn');
		send.type = 'submit';
		send.setAttribute('aria-label', 'Enviar');
		send.append(icon('send'));
		input.addEventListener('keydown', function (event) {
			if (event.key === 'Enter' && !event.shiftKey) { event.preventDefault(); form.requestSubmit(); }
		});
		form.addEventListener('submit', function (event) {
			event.preventDefault();
			const target = typeof number === 'function' ? number() : number;
			if (!input.value.trim()) { return; }
			send.disabled = true;
			act('message_send', { number: target, body: input.value }).then(function (data) {
				send.disabled = false;
				if (!data) { return; }
				input.value = '';
				onSent(formatNumber(target), data.message);
			});
		});
		form.append(input, send);
		return { form: form, input: input };
	}

	function renderThread(route) {
		const thread = state.thread || { number: route.number, messages: null };
		const remove = button('Apagar conversa', 'mb-iconbtn', function () {
			const ask = window.CoeUI && window.CoeUI.confirm
				? window.CoeUI.confirm({ title: 'Apagar conversa', message: 'A conversa some só do seu telefone.', confirmLabel: 'Apagar', danger: true })
				: Promise.resolve(true);
			ask.then(function (ok) {
				if (!ok) { return; }
				act('thread_delete', { number: thread.number }).then(function (data) {
					if (data) { state.threads = data.threads || []; go({ app: 'messages' }); }
				});
			});
		}, 'trash');
		const head = appHeader(thread.name || thread.number, function () { go({ app: 'messages' }); loadThreads(); }, remove);
		const call = button('Ligar', 'mb-iconbtn', function () { startCall(thread.number); }, 'phone');
		head.insertBefore(call, head.lastChild);
		els.view.append(head);
		const list = el('div', 'mb-bubbles');
		if (!thread.messages) {
			list.append(loading());
		} else if (!thread.messages.length) {
			list.append(emptyState('Nenhuma mensagem. Diga oi.'));
		} else {
			thread.messages.forEach(function (message) {
				const bubble = el('div', 'mb-bubble' + (message.mine ? ' is-mine' : ''));
				bubble.append(el('span', 'mb-bubble-body', message.body), el('span', 'mb-bubble-time', when(message.at)));
				list.append(bubble);
			});
		}
		const box = composer(thread.number, function (_, message) {
			if (state.thread && state.thread.messages && message) { state.thread.messages.push(message); }
			state.threads = null;
			render();
		});
		els.view.append(list, box.form);
		list.scrollTop = list.scrollHeight;
		box.input.focus();
	}

	function renderCompose() {
		els.view.append(appHeader('Nova mensagem', function () { go({ app: 'messages' }); }));
		const to = el('input', 'coe-field mb-mono');
		to.inputMode = 'numeric';
		to.placeholder = 'Número ou nome do contato';
		to.setAttribute('list', 'mb-contact-list');
		const options = el('datalist');
		options.id = 'mb-contact-list';
		(state.contacts || []).forEach(function (c) {
			const option = el('option');
			option.value = c.number;
			option.label = c.name;
			options.append(option);
		});
		const form = el('div', 'mb-form');
		form.append(field('Para', to), options);
		const box = composer(function () {
			const typed = to.value.trim().toLowerCase();
			const byName = (state.contacts || []).filter(function (c) { return c.name.toLowerCase() === typed; })[0];
			return byName ? byName.number : to.value;
		}, function (number) {
			state.threads = null;
			openThread(number);
		});
		els.view.append(form, el('div', 'mb-spacer'), box.form);
		to.focus();
	}

	// Ajustes --------------------------------------------------------------------------------------------------

	function renderSettings() {
		els.view.append(appHeader('Ajustes'));
		const current = settings();
		const wrap = el('div', 'mb-settings');

		const number = el('div', 'mb-setting');
		number.append(el('span', 'mb-setting-label', 'Meu número'), el('strong', 'mb-mono', state.profile.number));
		wrap.append(number);

		const silent = el('label', 'mb-setting');
		const toggle = el('input', 'mb-switch');
		toggle.type = 'checkbox';
		toggle.checked = current.silent === true;
		silent.append(el('span', 'mb-setting-label', 'Modo silencioso'), toggle);
		toggle.addEventListener('change', function () { save({ silent: toggle.checked }); });
		wrap.append(silent);

		const volume = el('label', 'mb-setting is-stacked');
		const range = el('input', 'mb-range');
		range.type = 'range';
		range.min = '0';
		range.max = '10';
		range.value = String(current.volume);
		const volumeValue = el('span', 'mb-setting-value', current.volume);
		const volumeHead = el('span', 'mb-setting-head');
		volumeHead.append(el('span', 'mb-setting-label', 'Volume do toque'), volumeValue);
		volume.append(volumeHead, range);
		range.addEventListener('input', function () { volumeValue.textContent = range.value; });
		range.addEventListener('change', function () {
			save({ volume: Number(range.value) }).then(function () { preview(); });
		});
		wrap.append(volume);

		wrap.append(choiceGroup('Toque', state.profile.limits.ringtones, RINGTONES, current.ringtone, function (value) {
			save({ ringtone: value }).then(function () { preview(); });
		}));
		wrap.append(choiceGroup('Papel de parede', state.profile.limits.wallpapers, WALLPAPERS, current.wallpaper, function (value) {
			save({ wallpaper: value });
		}, true));
		els.view.append(wrap);
	}

	function preview() {
		const current = settings();
		playLoop(current.ringtone, current.volume / 10);
		setTimeout(function () { if (!state.call) { stopSound(); } }, 1300);
	}

	function choiceGroup(title, values, labels, current, onPick, swatches) {
		const group = el('div', 'mb-setting is-stacked');
		group.append(el('span', 'mb-setting-label', title));
		const row = el('div', 'mb-choices' + (swatches ? ' is-swatches' : ''));
		(values || []).forEach(function (value) {
			const choice = el('button', 'mb-choice' + (value === current ? ' is-active' : ''));
			choice.type = 'button';
			if (swatches) {
				const swatch = el('span', 'mb-swatch');
				swatch.dataset.wallpaper = value;
				choice.append(swatch);
			}
			choice.append(el('span', null, labels[value] || value));
			choice.addEventListener('click', function () { onPick(value); });
			row.append(choice);
		});
		group.append(row);
		return group;
	}

	function save(patch) {
		return act('settings_save', patch).then(function (data) {
			if (data && data.settings) {
				state.profile.settings = data.settings;
				rerender(['settings']);
			}
		});
	}

	// Ligação --------------------------------------------------------------------------------------------------

	function setCall(call) {
		clearTimeout(endedTimer);
		state.call = call && call.state !== 'ended' ? call : null;
		if (call && call.state === 'ended') {
			showEnded(call);
		} else {
			renderCall();
		}
		syncSound();
	}

	function showEnded(call) {
		clearInterval(callTimer);
		els.call.hidden = false;
		els.call.className = 'mb-call is-ended';
		const status = els.call.querySelector('.mb-call-status');
		if (status) {
			status.textContent = ENDED[call.reason] || 'Ligação encerrada';
		} else {
			els.call.replaceChildren(el('p', 'mb-call-status', ENDED[call.reason] || 'Ligação encerrada'));
		}
		els.call.querySelectorAll('button').forEach(function (b) { b.disabled = true; });
		if (call.reason === 'missed' && els.call.dataset.direction === 'incoming') { state.missed += 1; }
		endedTimer = setTimeout(function () {
			els.call.hidden = true;
			els.call.replaceChildren();
			if (state.route.app === 'phone' && state.route.tab === 'recents') { loadRecents(); }
		}, 1400);
	}

	function renderCall() {
		clearInterval(callTimer);
		const call = state.call;
		if (!call) { els.call.hidden = true; els.call.replaceChildren(); return; }
		els.call.hidden = false;
		els.call.className = 'mb-call is-' + call.state + ' is-' + call.direction;
		els.call.dataset.direction = call.direction;
		const who = call.name || call.number;
		const head = el('div', 'mb-call-head');
		head.append(el('span', 'mb-avatar is-large', initials(call.name || '#')), el('h2', 'mb-call-name', who));
		if (call.name) { head.append(el('p', 'mb-call-number', call.number)); }
		const status = el('p', 'mb-call-status');
		head.append(status);
		const actions = el('div', 'mb-call-actions');
		if (call.state === 'ringing' && call.direction === 'incoming') {
			status.textContent = 'Ligação recebida';
			actions.append(
				callButton('Recusar', 'is-hangup', 'hangup', function () { act('call_decline'); }),
				callButton('Atender', 'is-answer', 'phone', function () {
					act('call_answer').then(function (data) { if (data && data.call) { setCall(data.call); } });
				})
			);
		} else {
			if (call.state === 'ringing') {
				status.textContent = 'Chamando…';
			} else {
				const update = function () {
					status.textContent = duration(Math.floor(Date.now() / 1000) - (call.answeredAt || Math.floor(Date.now() / 1000)));
				};
				update();
				callTimer = setInterval(update, 1000);
			}
			actions.append(callButton('Encerrar', 'is-hangup', 'hangup', function () { act('call_end'); }));
		}
		els.call.replaceChildren(head, actions);
	}

	function callButton(label, className, iconName, onClick) {
		const wrap = el('div', 'mb-call-action');
		const node = button(label, 'mb-round ' + className, function () { node.disabled = true; onClick(); }, iconName);
		wrap.append(node, el('span', null, label));
		return wrap;
	}

	// Abrir e fechar -------------------------------------------------------------------------------------------

	function show(focused) {
		els.phone.hidden = false;
		els.phone.classList.toggle('is-peek', !focused);
		els.hint.hidden = focused;
		state.focused = focused;
		tick();
	}

	function open(profile) {
		state.profile = profile;
		state.unread = profile.unread || 0;
		state.contacts = null;
		state.threads = null;
		state.recents = null;
		if (['thread', 'contact', 'contact_edit', 'compose'].indexOf(state.route.app) !== -1) {
			state.route = { app: 'home' };
		}
		show(true);
		render();
		// A ligação que vale é a do servidor (a que estava na tela pode ter terminado com o telefone fechado).
		setCall(profile.call || null);
	}

	function peek(call, key) {
		show(false);
		els.hint.textContent = 'Pressione ' + (key || 'F1') + ' para atender';
		setCall(call);
	}

	function close() {
		els.phone.hidden = true;
		state.focused = false;
		if (!state.call || state.call.state !== 'ringing') { stopSound(); }
	}

	function requestClose() {
		post('close', {});
	}

	els.home.addEventListener('click', function () { go({ app: 'home' }); });

	document.addEventListener('keydown', function (event) {
		if (event.key === 'Escape' && !els.phone.hidden && state.focused && !document.querySelector('.coe-modal-overlay')) {
			requestClose();
			return;
		}
		const typing = event.target && (event.target.tagName === 'INPUT' || event.target.tagName === 'TEXTAREA');
		if (!typing && state.focused && state.route.app === 'phone' && state.route.tab !== 'recents') {
			if (/^[0-9]$/.test(event.key)) { pressDigit(event.key); }
			if (event.key === 'Backspace') { state.dial = state.dial.slice(0, -1); render(); }
			if (event.key === 'Enter' && state.dial.length === maxDigits()) { startCall(state.dial); }
		}
	});

	window.addEventListener('message', function (event) {
		const message = event.data || {};
		if (message.type === 'open' && message.data) { open(message.data); }
		if (message.type === 'peek' && message.data) { peek(message.data, message.key); }
		if (message.type === 'close') { close(); }
		if (message.type === 'call' && message.data) { setCall(message.data); }
		if (message.type === 'message' && message.data) {
			const incoming = message.data;
			if (state.thread && state.thread.number === incoming.number && state.thread.messages && state.route.app === 'thread' && !els.phone.hidden) {
				state.thread.messages.push({ body: incoming.body, at: incoming.at, mine: false });
				act('thread', { number: incoming.number });
				render();
			} else {
				state.unread += 1;
				state.threads = null;
				if (!els.phone.hidden) {
					toast((incoming.name || incoming.number) + ': ' + incoming.body, 'info');
					if (state.route.app === 'messages') { loadThreads(); } else { rerender(['home']); }
				}
				if (!settings().silent) { beep([988, 1319], 0.12, 0.04 * (settings().volume || 5)); }
			}
		}
	});

	setInterval(tick, 15000);
})();
