// E-mail do COE OS (smartphone e tablet). Contas com senha abertas por aparelho, pastas, leitura, resposta,
// encaminhamento, rascunhos, busca, estrela, arquivo e lixeira.
(function () {
	'use strict';

	const host = window.CoePhone || window.CoeTablet;
	if (!host) { return; }

	if (!document.querySelector('link[data-coe-mail]')) {
		const link = document.createElement('link');
		link.rel = 'stylesheet';
		link.href = 'nui://coe_mail/html/mail.css';
		link.dataset.coeMail = '1';
		document.head.appendChild(link);
	}

	const ERRORS = {
		not_ready: 'E-mail ainda iniciando.', no_character: 'Personagem não carregado.', no_device: 'Aparelho não encontrado.',
		database_error: 'Falha ao gravar. Tente de novo.', unknown_action: 'Ação desconhecida.', busy: 'Aguarde a operação anterior terminar.',
		not_installed: 'App de e-mail indisponível.',
		invalid_address: 'Nome inválido: use letras minúsculas, números, ponto, hífen ou sublinhado.',
		address_reserved: 'Esse nome é reservado. Escolha outro.', address_taken: 'Esse endereço já está em uso.',
		account_limit: 'Você já criou o máximo de contas.', invalid_password: 'A senha precisa ter de 6 a 32 caracteres, sem espaço nas pontas.',
		wrong_credentials: 'Endereço ou senha incorretos.', wrong_password: 'Senha incorreta.',
		login_locked: 'Muitas tentativas erradas. Aguarde um pouco.', too_many_sessions: 'Contas demais abertas neste aparelho. Saia de uma.',
		not_signed_in: 'Essa conta não está mais aberta neste aparelho.', not_owner: 'Só quem criou a conta pode fazer isso.',
		invalid_recipient: 'Endereço inválido.', unknown_recipient: 'Esse endereço não existe.',
		no_recipients: 'Informe pelo menos um destinatário em Para.', too_many_recipients: 'Destinatários demais.',
		empty_message: 'Escreva um assunto ou uma mensagem.', send_cooldown: 'Aguarde para enviar de novo.',
		mailbox_full: 'A caixa do destinatário está cheia.', message_not_found: 'Mensagem não encontrada.',
		invalid_selection: 'Seleção inválida.'
	};

	const FOLDERS = [
		{ id: 'inbox', label: 'Entrada' },
		{ id: 'starred', label: 'Com estrela' },
		{ id: 'sent', label: 'Enviados' },
		{ id: 'drafts', label: 'Rascunhos' },
		{ id: 'archive', label: 'Arquivo' },
		{ id: 'trash', label: 'Lixeira' }
	];

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

	function input(type, placeholder, value, max) {
		const node = el('input', 'coe-field');
		node.type = type;
		node.placeholder = placeholder || '';
		node.value = value || '';
		if (max) { node.maxLength = max; }
		return node;
	}

	function withPass(payload, control) {
		payload.password = control.value;
		return payload;
	}

	function field(label, control, hint) {
		const box = el('label', 'ml-field');
		box.appendChild(el('span', null, label));
		box.appendChild(control);
		if (hint) { box.appendChild(el('small', 'tb-muted', hint)); }
		return box;
	}

	function pad(n) { return n < 10 ? '0' + n : String(n); }

	function when(seconds, full) {
		const date = new Date(Number(seconds || 0) * 1000);
		const now = new Date();
		const time = pad(date.getHours()) + ':' + pad(date.getMinutes());
		const day = pad(date.getDate()) + '/' + pad(date.getMonth() + 1);
		if (full) { return day + '/' + date.getFullYear() + ' ' + time; }
		return date.toDateString() === now.toDateString() ? time : day;
	}

	function initial(text) {
		const value = String(text || '?').trim();
		return value ? value.charAt(0).toUpperCase() : '?';
	}

	function splitAddresses(text) {
		return String(text || '').split(/[,;\s]+/).filter(Boolean);
	}

	// O aparelho aceita uma ação a cada 250 ms: as chamadas passam por esta fila.
	const queue = [];
	let running = false;
	let lastSent = 0;
	const GAP = 300;

	function pump() {
		if (running || queue.length === 0) { return; }
		running = true;
		const job = queue.shift();
		const wait = Math.max(0, lastSent + GAP - Date.now());
		setTimeout(function () {
			lastSent = Date.now();
			job.api.call('mail', job.action, job.payload).then(function (result) {
				if (result && result.error === 'rate_limited' && job.retries < 3) {
					job.retries += 1;
					queue.unshift(job);
				} else {
					job.resolve(result || { ok: false, error: 'app_error' });
				}
			}, function () {
				job.resolve({ ok: false, error: 'app_error' });
			}).then(function () {
				running = false;
				pump();
			});
		}, wait);
	}

	// Conta e pasta escolhidas continuam entre aberturas do app.
	const memory = { account: null, folder: 'inbox' };

	host.register('mail', function (root, api) {
		const page = el('div', 'ml-page');
		root.appendChild(page);

		let boot = null;
		let view = 'loading';
		let folder = memory.folder;
		let search = '';
		let list = null;
		let more = false;
		let counts = {};
		let message = null;
		let compose = null;
		let auth = 'login';
		let busy = false;
		let focusSearch = false;
		let confirmEmpty = false;

		function errorText(code) { return ERRORS[code] || api.errorText(code); }
		function fail(result) {
			let text = errorText(result && result.error);
			if (result && result.address) { text += ' (' + result.address + ')'; }
			if (result && result.seconds) { text += ' ' + result.seconds + ' s.'; }
			api.status(text, 'error');
		}
		function call(action, payload) {
			return new Promise(function (resolve) {
				queue.push({ api: api, action: action, payload: payload || {}, resolve: resolve, retries: 0 });
				pump();
			});
		}

		function account() {
			const accounts = boot && boot.accounts || [];
			return accounts.find(function (a) { return a.id === memory.account; }) || null;
		}

		function limits() { return boot && boot.limits || {}; }

		// Carregamento -----------------------------------------------------------------------------------

		function loadState(then) {
			return call('state').then(function (result) {
				if (!result.ok) { fail(result); view = 'error'; render(); return; }
				boot = result;
				const accounts = boot.accounts || [];
				if (!accounts.some(function (a) { return a.id === memory.account; })) {
					memory.account = accounts.length ? accounts[0].id : null;
				}
				if (then) { then(); return; }
				if (!memory.account) { view = 'auth'; render(); return; }
				loadFolder();
			});
		}

		function loadFolder(append, keepFocus) {
			focusSearch = keepFocus === true;
			confirmEmpty = false;
			const current = account();
			if (!current) { view = 'auth'; render(); return Promise.resolve(); }
			const payload = { account: current.id, folder: folder, search: search || undefined };
			if (append && list && list.length) { payload.before = list[list.length - 1].id; }
			return call('folder', payload).then(function (result) {
				if (!result.ok) {
					fail(result);
					if (result.error === 'not_signed_in') { loadState(); }
					return;
				}
				list = append ? (list || []).concat(result.messages || []) : (result.messages || []);
				more = result.more === true;
				counts = result.counts || {};
				current.unread = counts.inbox ? counts.inbox.unread : 0;
				view = 'list';
				render();
			});
		}

		function openBox(id) {
			const current = account();
			call('open', { account: current.id, box: id }).then(function (result) {
				if (!result.ok) { fail(result); return; }
				const item = result.message;
				if (item.folder === 'drafts') {
					startCompose({ draft: item.id, to: item.to, cc: item.cc, bcc: item.bcc, subject: item.subject, body: item.body });
					return;
				}
				message = item;
				(list || []).forEach(function (row) { if (row.id === item.id) { row.read = true; } });
				view = 'read';
				render();
			});
		}

		// Tela inicial (sem conta aberta) -----------------------------------------------------------------

		function brand(parent, subtitle) {
			const head = el('div', 'ml-brand');
			const logo = el('div', 'ml-logo');
			api.icon(logo, { icon: 'mail', color: '#3a7bd5' });
			const text = el('div');
			text.appendChild(el('strong', null, 'E-mail'));
			if (subtitle) { text.appendChild(el('small', 'tb-muted', subtitle)); }
			head.append(logo, text);
			parent.appendChild(head);
		}

		function authView() {
			brand(page, 'Entre numa conta ou crie um endereço @' + boot.domain);
			const tabs = el('div', 'tb-tabs');
			[{ id: 'login', label: 'Entrar' }, { id: 'create', label: 'Criar conta' }, { id: 'owned', label: 'Minhas contas' }].forEach(function (t) {
				tabs.appendChild(button(t.label, 'tb-tab' + (t.id === auth ? ' is-active' : ''), function () { auth = t.id; render(); }));
			});
			page.appendChild(tabs);
			if (auth === 'login') { loginForm(); } else if (auth === 'create') { createForm(); } else { ownedList(); }
			if ((boot.accounts || []).length) {
				page.appendChild(button('Voltar para a caixa de entrada', '', function () { loadFolder(); }));
			}
		}

		function loginForm() {
			const panel = el('div', 'coe-panel coe-panel--compact ml-form');
			const address = input('email', 'nome@' + boot.domain, '', 80);
			const passField = input('password', 'Senha', '', 64);
			const submit = button('Entrar', 'coe-button--primary', function () {
				if (busy) { return; }
				busy = true;
				call('login', withPass({ address: address.value }, passField)).then(function (result) {
					busy = false;
					if (!result.ok) { fail(result); return; }
					memory.account = result.account;
					api.status('Conta aberta neste aparelho.', 'success');
					loadState(function () { loadFolder(); });
				});
			});
			passField.addEventListener('keydown', function (event) { if (event.key === 'Enter') { submit.click(); } });
			panel.append(field('Endereço', address), field('Senha', passField), submit,
				el('small', 'tb-muted', 'A conta fica aberta neste aparelho até você sair. Quem estiver com o aparelho desbloqueado vê seus e-mails.'));
			page.appendChild(panel);
		}

		function createForm() {
			const l = limits();
			const panel = el('div', 'coe-panel coe-panel--compact ml-form');
			if (!boot.canCreate) {
				panel.appendChild(el('p', 'tb-empty', 'Você já criou ' + l.MaxPerCharacter + ' contas. Exclua uma em Minhas contas para criar outra.'));
				page.appendChild(panel);
				return;
			}
			const local = input('text', 'seunome', '', l.LocalMax);
			const row = el('div', 'ml-address');
			row.append(local, el('span', 'tb-muted', '@' + boot.domain));
			local.addEventListener('input', function () { local.value = local.value.toLowerCase().replace(/[^a-z0-9._-]/g, ''); });
			const name = input('text', 'Como seu nome aparece', '', l.NameMax);
			const passField = input('password', 'Senha', '', l.PasswordMax);
			const confirm = input('password', 'Repita a senha', '', l.PasswordMax);
			const submit = button('Criar conta', 'coe-button--primary', function () {
				if (busy) { return; }
				if (passField.value !== confirm.value) { api.status('As senhas não conferem.', 'error'); return; }
				busy = true;
				call('create', withPass({ local: local.value, name: name.value }, passField)).then(function (result) {
					busy = false;
					if (!result.ok) { fail(result); return; }
					memory.account = result.account;
					api.status('Conta ' + local.value + '@' + boot.domain + ' criada.', 'success');
					loadState(function () { loadFolder(); });
				});
			});
			panel.append(
				field('Endereço', row, l.LocalMin + ' a ' + l.LocalMax + ' caracteres: letras minúsculas, números, ponto, hífen ou sublinhado.'),
				field('Nome de exibição', name, 'Opcional. Em branco, usa o nome do personagem.'),
				field('Senha', passField, l.PasswordMin + ' a ' + l.PasswordMax + ' caracteres. Quem souber a senha entra na conta.'),
				field('Confirmar senha', confirm),
				submit
			);
			page.appendChild(panel);
		}

		function ownedList() {
			const owned = boot.owned || [];
			if (owned.length === 0) {
				page.appendChild(el('p', 'tb-empty', 'Você ainda não criou nenhuma conta.'));
				return;
			}
			page.appendChild(el('p', 'tb-muted ml-note', 'Contas criadas por você. Esqueceu a senha? Defina outra aqui: a conta sai dos outros aparelhos e abre neste.'));
			owned.forEach(function (item) {
				const row = el('div', 'coe-panel coe-panel--compact ml-owned');
				row.appendChild(el('strong', null, item.address));
				const actions = el('div', 'ml-actions');
				actions.append(
					button('Redefinir senha', '', function () { ownedForm(row, item, 'reset'); }),
					button('Excluir', 'coe-button--danger', function () { ownedForm(row, item, 'remove'); })
				);
				row.appendChild(actions);
				page.appendChild(row);
			});
		}

		function ownedForm(row, item, mode) {
			const old = row.querySelector('.ml-form');
			if (old) { old.remove(); }
			const form = el('div', 'ml-form');
			const passField = input('password', mode === 'reset' ? 'Nova senha' : 'Senha da conta', '', limits().PasswordMax);
			const go = button(mode === 'reset' ? 'Salvar nova senha' : 'Excluir conta e mensagens', mode === 'reset' ? 'coe-button--primary' : 'coe-button--danger', function () {
				if (busy) { return; }
				busy = true;
				call(mode, withPass({ account: item.id }, passField)).then(function (result) {
					busy = false;
					if (!result.ok) { fail(result); return; }
					if (mode === 'reset') {
						memory.account = result.account;
						api.status('Senha redefinida. A conta foi aberta neste aparelho.', 'success');
						loadState(function () { loadFolder(); });
					} else {
						api.status('Conta ' + item.address + ' excluída.', 'success');
						loadState(function () { view = 'auth'; auth = 'owned'; render(); });
					}
				});
			});
			form.append(passField, go);
			if (mode === 'remove') { form.appendChild(el('small', 'tb-muted', 'Apaga todas as mensagens da conta. O endereço fica livre para outra pessoa.')); }
			row.appendChild(form);
			passField.focus();
		}

		// Caixa ------------------------------------------------------------------------------------------

		function accountBar() {
			const current = account();
			const bar = el('div', 'ml-bar');
			const select = el('select', 'coe-field ml-account');
			(boot.accounts || []).forEach(function (a) {
				const option = el('option', null, a.address + (a.unread ? ' (' + a.unread + ')' : ''));
				option.value = String(a.id);
				option.selected = a.id === current.id;
				select.appendChild(option);
			});
			const add = el('option', null, '+ Adicionar conta');
			add.value = 'add';
			select.appendChild(add);
			select.addEventListener('change', function () {
				if (select.value === 'add') { view = 'auth'; auth = 'login'; render(); return; }
				memory.account = Number(select.value);
				search = '';
				loadFolder();
			});
			bar.append(select,
				button('Ajustes', 'ml-icon-button', function () { view = 'settings'; render(); }),
				button('Escrever', 'coe-button--primary', function () { startCompose({}); }));
			return bar;
		}

		function folderTabs() {
			const tabs = el('div', 'tb-tabs ml-folders');
			FOLDERS.forEach(function (f) {
				let label = f.label;
				const count = counts[f.id];
				if (f.id === 'inbox' && count && count.unread) { label += ' (' + count.unread + ')'; }
				if ((f.id === 'drafts' || f.id === 'starred') && count && count.total) { label += ' (' + count.total + ')'; }
				tabs.appendChild(button(label, 'tb-tab' + (f.id === folder ? ' is-active' : ''), function () {
					folder = f.id;
					memory.folder = folder;
					list = null;
					loadFolder();
				}));
			});
			return tabs;
		}

		function listView() {
			page.appendChild(accountBar());
			page.appendChild(folderTabs());

			const tools = el('div', 'ml-tools');
			const box = input('search', 'Buscar em ' + FOLDERS.find(function (f) { return f.id === folder; }).label.toLowerCase(), search, 40);
			box.classList.add('ml-search');
			let timer = null;
			box.addEventListener('input', function () {
				clearTimeout(timer);
				timer = setTimeout(function () { search = box.value.trim(); loadFolder(false, true); }, 450);
			});
			tools.appendChild(box);
			if (folder === 'trash' && list && list.length) {
				tools.appendChild(button(confirmEmpty ? 'Confirmar: apagar tudo' : 'Esvaziar', 'coe-button--danger', function () {
					if (!confirmEmpty) { confirmEmpty = true; render(); return; }
					call('emptyTrash', { account: account().id }).then(function (result) {
						if (!result.ok) { fail(result); return; }
						api.status('Lixeira esvaziada.', 'success');
						loadFolder();
					});
				}));
			}
			page.appendChild(tools);
			if (folder === 'trash') {
				page.appendChild(el('small', 'tb-muted ml-note', 'Mensagens na Lixeira são apagadas depois de ' + (limits().TrashDays || 7) + ' dias.'));
			}

			if (!list || list.length === 0) {
				page.appendChild(el('p', 'tb-empty', search ? 'Nada encontrado.' : 'Nenhuma mensagem aqui.'));
				if (focusSearch) { box.focus(); box.setSelectionRange(box.value.length, box.value.length); }
				return;
			}
			const rows = el('div', 'ml-list');
			list.forEach(function (item) { rows.appendChild(listRow(item)); });
			page.appendChild(rows);
			if (more) {
				page.appendChild(button('Carregar mais', '', function () { loadFolder(true); }));
			}
			if (focusSearch) {
				box.focus();
				box.setSelectionRange(box.value.length, box.value.length);
			}
		}

		function listRow(item) {
			const row = el('div', 'ml-row' + (item.read ? '' : ' is-unread'));
			const outgoing = item.sent || item.folder === 'drafts';
			const who = outgoing ? (item.to ? 'Para: ' + item.to : '(sem destinatário)') : (item.fromName || item.from);
			const avatar = el('span', 'ml-avatar', initial(outgoing ? item.to : (item.fromName || item.from)));
			const text = el('div', 'ml-row-text');
			const top = el('div', 'ml-row-top');
			top.append(el('span', 'ml-who', who), el('span', 'ml-when', when(item.at)));
			text.appendChild(top);
			const subject = el('div', 'ml-subject', item.subject || '(sem assunto)');
			if (item.folder === 'drafts') { subject.prepend(el('span', 'ml-draft-tag', 'Rascunho ')); }
			text.appendChild(subject);
			text.appendChild(el('div', 'ml-snippet', String(item.snippet || '').replace(/\s+/g, ' ')));
			const star = button(item.starred ? '★' : '☆', 'ml-star' + (item.starred ? ' is-on' : ''), function (event) {
				event.stopPropagation();
				const value = !item.starred;
				call('mark', { account: account().id, boxes: [item.id], starred: value }).then(function (result) {
					if (!result.ok) { fail(result); return; }
					item.starred = value;
					if (folder === 'starred' && !value) { loadFolder(); return; }
					render();
				});
			});
			star.title = item.starred ? 'Remover estrela' : 'Marcar com estrela';
			row.append(avatar, text, star);
			row.addEventListener('click', function () { openBox(item.id); });
			return row;
		}

		// Leitura ----------------------------------------------------------------------------------------

		function action(name, payload, done) {
			call(name, Object.assign({ account: account().id, boxes: [message.id] }, payload || {})).then(function (result) {
				if (!result.ok) { fail(result); return; }
				done(result);
			});
		}

		function backToList(text) {
			if (text) { api.status(text, 'success'); }
			message = null;
			loadFolder();
		}

		function readView() {
			const top = el('div', 'ml-bar');
			top.appendChild(button('‹ Voltar', '', function () { backToList(); }));
			const tools = el('div', 'ml-actions');
			const star = button(message.starred ? '★' : '☆', 'ml-star' + (message.starred ? ' is-on' : ''), function () {
				const value = !message.starred;
				action('mark', { starred: value }, function () { message.starred = value; render(); });
			});
			tools.appendChild(star);
			if (message.folder === 'trash') {
				tools.append(
					button('Restaurar', '', function () { action('move', { to: 'restore' }, function () { backToList('Mensagem restaurada.'); }); }),
					button('Apagar', 'coe-button--danger', function () { action('delete', {}, function () { backToList('Mensagem apagada.'); }); })
				);
			} else {
				tools.append(
					message.folder === 'archive'
						? button('Desarquivar', '', function () { action('move', { to: 'restore' }, function () { backToList('Mensagem movida de volta.'); }); })
						: button('Arquivar', '', function () { action('move', { to: 'archive' }, function () { backToList('Mensagem arquivada.'); }); }),
					button('Não lida', '', function () { action('mark', { read: false }, function () { backToList(); }); }),
					button('Lixeira', 'coe-button--danger', function () { action('move', { to: 'trash' }, function () { backToList('Mensagem na Lixeira.'); }); })
				);
			}
			top.appendChild(tools);
			page.appendChild(top);

			const card = el('div', 'coe-panel ml-message');
			card.appendChild(el('h3', 'ml-title', message.subject || '(sem assunto)'));
			const head = el('div', 'ml-head');
			head.appendChild(el('span', 'ml-avatar', initial(message.fromName || message.from)));
			const who = el('div', 'ml-head-text');
			const from = el('div');
			from.appendChild(el('strong', null, message.fromName || message.from));
			from.appendChild(el('span', 'tb-muted', ' <' + message.from + '>'));
			who.appendChild(from);
			who.appendChild(el('small', 'tb-muted', 'Para: ' + (message.to || '—')));
			if (message.cc) { who.appendChild(el('small', 'tb-muted', 'Cc: ' + message.cc)); }
			if (message.bcc) { who.appendChild(el('small', 'tb-muted', 'Cco: ' + message.bcc)); }
			who.appendChild(el('small', 'tb-muted', when(message.at, true)));
			head.appendChild(who);
			card.appendChild(head);
			card.appendChild(el('div', 'ml-body', message.body || ''));
			page.appendChild(card);

			const reply = el('div', 'ml-actions ml-reply');
			reply.append(
				button('Responder', 'coe-button--primary', function () { startReply('reply'); }),
				button('Responder a todos', '', function () { startReply('all'); }),
				button('Encaminhar', '', function () { startReply('forward'); })
			);
			page.appendChild(reply);
		}

		function prefixed(prefix, subject) {
			const value = String(subject || '');
			return value.toLowerCase().indexOf(prefix.toLowerCase()) === 0 ? value : prefix + ' ' + value;
		}

		function quoted(item) {
			const header = 'Em ' + when(item.at, true) + ', ' + (item.fromName || item.from) + ' <' + item.from + '> escreveu:';
			return '\n\n' + header + '\n' + String(item.body || '').split('\n').map(function (line) { return '> ' + line; }).join('\n');
		}

		function startReply(mode) {
			const me = account().address;
			const item = message;
			if (mode === 'forward') {
				const header = '\n\n---------- Mensagem encaminhada ----------\nDe: ' + (item.fromName ? item.fromName + ' <' + item.from + '>' : item.from) +
					'\nData: ' + when(item.at, true) + '\nAssunto: ' + (item.subject || '') + '\nPara: ' + (item.to || '') +
					(item.cc ? '\nCc: ' + item.cc : '') + '\n\n' + (item.body || '');
				startCompose({ subject: prefixed('Enc:', item.subject), quote: header });
				return;
			}
			let to = item.sent ? splitAddresses(item.to) : [item.from];
			let cc = [];
			if (mode === 'all') {
				const others = splitAddresses(item.to).concat(splitAddresses(item.cc)).filter(function (a) { return a !== me && to.indexOf(a) < 0; });
				cc = others;
			}
			to = to.filter(function (a, i) { return to.indexOf(a) === i; });
			startCompose({ to: to.join(', '), cc: cc.join(', '), subject: prefixed('Re:', item.subject), quote: quoted(item) });
		}

		// Escrever ---------------------------------------------------------------------------------------

		function startCompose(data) {
			const current = account();
			let body = data.body;
			if (body === undefined) {
				body = (current.signature ? '\n\n-- \n' + current.signature : '') + (data.quote || '');
			}
			compose = {
				draft: data.draft || null, to: data.to || '', cc: data.cc || '', bcc: data.bcc || '',
				subject: data.subject || '', body: body, showCc: !!(data.cc || data.bcc), dirty: false
			};
			compose.original = JSON.stringify([compose.to, compose.cc, compose.bcc, compose.subject, compose.body]);
			view = 'compose';
			render();
		}

		function composeChanged() {
			return JSON.stringify([compose.to, compose.cc, compose.bcc, compose.subject, compose.body]) !== compose.original;
		}

		function saveDraft(silent) {
			const current = account();
			return call('saveDraft', {
				account: current.id, draft: compose.draft || undefined, to: compose.to, cc: compose.cc, bcc: compose.bcc,
				subject: compose.subject, body: compose.body
			}).then(function (result) {
				if (!result.ok) { fail(result); return false; }
				compose.draft = result.draft;
				compose.original = JSON.stringify([compose.to, compose.cc, compose.bcc, compose.subject, compose.body]);
				if (!silent) { api.status('Rascunho salvo.', 'success'); }
				return true;
			});
		}

		function composeView() {
			const l = limits();
			const current = account();
			const top = el('div', 'ml-bar');
			top.appendChild(button('‹ Voltar', '', function () {
				const empty = !compose.to && !compose.cc && !compose.bcc && !compose.subject.trim() && !compose.body.trim();
				if (composeChanged() && !empty) {
					saveDraft(true).then(function (saved) { if (saved) { api.status('Rascunho salvo.', 'success'); compose = null; loadFolder(); } });
					return;
				}
				compose = null;
				loadFolder();
			}));
			const actions = el('div', 'ml-actions');
			actions.appendChild(button('Salvar rascunho', '', function () { saveDraft(false); }));
			if (compose.draft) {
				actions.appendChild(button('Descartar', 'coe-button--danger', function () {
					call('delete', { account: current.id, boxes: [compose.draft] }).then(function (result) {
						if (!result.ok) { fail(result); return; }
						compose = null;
						api.status('Rascunho descartado.', 'success');
						loadFolder();
					});
				}));
			}
			const send = button('Enviar', 'coe-button--primary', function () {
				if (busy) { return; }
				busy = true;
				send.disabled = true;
				call('send', {
					account: current.id, draft: compose.draft || undefined, to: compose.to, cc: compose.cc, bcc: compose.bcc,
					subject: compose.subject, body: compose.body
				}).then(function (result) {
					busy = false;
					send.disabled = false;
					if (!result.ok) {
						fail(result);
						if (result.error === 'mailbox_full' && result.bounced) { api.status('Caixa cheia: ' + result.bounced.join(', '), 'error'); }
						return;
					}
					compose = null;
					if (result.bounced && result.bounced.length) {
						api.status('Enviado, mas a caixa está cheia em: ' + result.bounced.join(', '), 'error');
					} else {
						api.status('Mensagem enviada.', 'success');
					}
					loadFolder();
				});
			});
			actions.appendChild(send);
			top.appendChild(actions);
			page.appendChild(top);

			const form = el('div', 'coe-panel coe-panel--compact ml-form ml-compose');
			form.appendChild(el('small', 'tb-muted', 'De: ' + (current.name ? current.name + ' <' + current.address + '>' : current.address)));
			function bind(node, key) {
				node.addEventListener('input', function () { compose[key] = node.value; });
				return node;
			}
			const to = bind(input('text', 'nome@' + boot.domain + ', ...', compose.to, 400), 'to');
			const toRow = el('div', 'ml-to');
			toRow.appendChild(to);
			if (!compose.showCc) {
				toRow.appendChild(button('Cc/Cco', 'ml-icon-button', function () { compose.showCc = true; render(); }));
			}
			form.appendChild(field('Para', toRow));
			if (compose.showCc) {
				form.appendChild(field('Cc', bind(input('text', 'Com cópia', compose.cc, 400), 'cc')));
				form.appendChild(field('Cco', bind(input('text', 'Cópia oculta (os outros não veem)', compose.bcc, 400), 'bcc')));
			}
			form.appendChild(field('Assunto', bind(input('text', 'Assunto', compose.subject, l.SubjectMax), 'subject')));
			const body = el('textarea', 'coe-field ml-editor');
			body.value = compose.body;
			body.maxLength = l.BodyMax || 4000;
			body.placeholder = 'Escreva sua mensagem';
			const counter = el('small', 'tb-muted ml-counter');
			function paintCounter() { counter.textContent = body.value.length + ' / ' + body.maxLength; }
			body.addEventListener('input', function () { compose.body = body.value; paintCounter(); });
			paintCounter();
			form.append(body, counter,
				el('small', 'tb-muted', 'Separe os endereços com vírgula. Até ' + (l.MaxRecipients || 10) + ' destinatários no total.'));
			page.appendChild(form);
			if (!compose.to) { to.focus(); } else if (!compose.subject) { form.querySelectorAll('input')[compose.showCc ? 3 : 1].focus(); } else { body.focus(); body.setSelectionRange(0, 0); }
		}

		// Ajustes da conta -------------------------------------------------------------------------------

		function settingsView() {
			const l = limits();
			const current = account();
			const top = el('div', 'ml-bar');
			top.append(button('‹ Voltar', '', function () { loadFolder(); }), el('strong', null, current.address));
			page.appendChild(top);

			const profile = el('div', 'coe-panel coe-panel--compact ml-form');
			profile.appendChild(el('strong', null, 'Perfil'));
			const name = input('text', 'Nome de exibição', current.name, l.NameMax);
			const signature = el('textarea', 'coe-field ml-signature');
			signature.value = current.signature || '';
			signature.maxLength = l.SignatureMax || 200;
			signature.placeholder = 'Assinatura (vai no fim das mensagens novas)';
			profile.append(field('Nome de exibição', name), field('Assinatura', signature), button('Salvar perfil', 'coe-button--primary', function () {
				call('profile', { account: current.id, name: name.value, signature: signature.value }).then(function (result) {
					if (!result.ok) { fail(result); return; }
					api.status('Perfil salvo.', 'success');
					loadState(function () { view = 'settings'; render(); });
				});
			}));
			page.appendChild(profile);

			const security = el('div', 'coe-panel coe-panel--compact ml-form');
			security.appendChild(el('strong', null, 'Senha'));
			const oldField = input('password', 'Senha atual', '', 64);
			const next = input('password', 'Nova senha', '', l.PasswordMax);
			const confirm = input('password', 'Repita a nova senha', '', l.PasswordMax);
			security.append(oldField, next, confirm, button('Trocar senha', '', function () {
				if (next.value !== confirm.value) { api.status('As senhas não conferem.', 'error'); return; }
				call('password', { account: current.id, current: oldField.value, new: next.value }).then(function (result) {
					if (!result.ok) { fail(result); return; }
					oldField.value = next.value = confirm.value = '';
					api.status('Senha trocada. A conta saiu dos outros aparelhos.', 'success');
				});
			}), el('small', 'tb-muted', 'Trocar a senha encerra a conta em todos os outros aparelhos.'));
			page.appendChild(security);

			const session = el('div', 'coe-panel coe-panel--compact ml-form');
			session.appendChild(el('strong', null, 'Este aparelho'));
			session.appendChild(button('Sair desta conta', 'coe-button--danger', function () {
				call('logout', { account: current.id }).then(function (result) {
					if (!result.ok) { fail(result); return; }
					api.status('Você saiu de ' + current.address + '.', 'success');
					memory.account = null;
					loadState();
				});
			}));
			session.appendChild(el('small', 'tb-muted', 'Contas que você criou podem ser excluídas ou ter a senha redefinida em Adicionar conta › Minhas contas.'));
			page.appendChild(session);
		}

		// Renderização -----------------------------------------------------------------------------------

		function render() {
			page.replaceChildren();
			if (view === 'loading') { page.appendChild(el('p', 'tb-empty', 'Carregando…')); return; }
			if (view === 'error') {
				page.appendChild(el('p', 'tb-empty', 'Não foi possível abrir o e-mail.'));
				page.appendChild(button('Tentar de novo', 'coe-button--primary', function () { view = 'loading'; render(); loadState(); }));
				return;
			}
			if (view === 'auth' || !account()) { authView(); return; }
			if (view === 'read' && message) { readView(); return; }
			if (view === 'compose' && compose) { composeView(); return; }
			if (view === 'settings') { settingsView(); return; }
			listView();
		}

		render();
		loadState();

		// Novos e-mails: atualiza a caixa aberta enquanto o app está na tela.
		const poll = setInterval(function () {
			if (!page.isConnected) { clearInterval(poll); return; }
			if (page.offsetParent === null || view !== 'list' || queue.length || running || !account()) { return; }
			const before = account().unread;
			call('state').then(function (result) {
				if (!result.ok || !page.isConnected) { return; }
				boot = result;
				const now = account();
				if (!now) { view = 'auth'; render(); return; }
				if (view === 'list' && (now.unread !== before) && document.activeElement && document.activeElement.tagName !== 'INPUT') {
					loadFolder();
				}
			});
		}, 20000);
	});
})();
