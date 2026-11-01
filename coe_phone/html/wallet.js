// Carteira digital: cartões do banco guardados no aparelho e pagamento por aproximação/no app (api.pay).
(function () {
	'use strict';

	const phone = window.CoePhone;
	const PIN_LENGTH = 4;
	const STATUS = { active: 'Ativo', expired: 'Vencido', blocked: 'Bloqueado', missing: 'Indisponível' };

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

	// Botão de dois toques: o primeiro arma ("Confirmar" por 3 s), o segundo executa.
	function armedButton(label, className, onConfirm) {
		let armed = false;
		const node = button(label, className, function () {
			if (!armed) {
				armed = true;
				node.textContent = 'Confirmar';
				setTimeout(function () { armed = false; node.textContent = label; }, 3000);
				return;
			}
			node.disabled = true;
			onConfirm();
		});
		return node;
	}

	function money(value) {
		return '$ ' + Math.floor(Math.abs(Number(value) || 0)).toLocaleString('pt-BR');
	}

	function expiry(seconds) {
		if (!seconds) { return '--/--'; }
		const date = new Date(Number(seconds) * 1000);
		return String(date.getMonth() + 1).padStart(2, '0') + '/' + String(date.getFullYear()).slice(-2);
	}

	function errorOf(api, result) {
		if (result && result.error === 'wrong_pin' && result.data && result.data.left !== undefined) {
			return 'Senha do cartão incorreta. Restam ' + result.data.left + ' tentativa(s).';
		}
		if (result && result.error === 'locked_out' && result.data) {
			return 'Muitas tentativas. Aguarde ' + result.data.wait + ' s.';
		}
		return api.errorText(result && result.error);
	}

	// Visual do cartão (cores pelo nível de crédito da conta).
	function cardFace(card, compact) {
		const node = el('div', 'wl-card wl-card--' + (card.tier || 'none') + (compact ? ' is-compact' : '') + (card.status !== 'active' ? ' is-off' : ''));
		const top = el('div', 'wl-card-top');
		top.append(el('strong', null, 'COE Bank'), el('span', 'wl-card-kind', card.kind === 'virtual' ? 'Virtual' : 'Físico'));
		const chip = el('i', 'wl-card-chip');
		const number = el('div', 'wl-card-number', '•••• •••• •••• ' + card.last4);
		const bottom = el('div', 'wl-card-bottom');
		const holder = el('span', null, card.holder || '');
		const right = el('span', null, (card.tierLabel ? card.tierLabel + ' · ' : '') + expiry(card.expiresAt));
		bottom.append(holder, right);
		node.append(top, chip, number, bottom);
		if (card.default) { node.appendChild(el('b', 'wl-card-default', '★ Padrão')); }
		if (card.status !== 'active') { node.appendChild(el('b', 'wl-card-status', STATUS[card.status] || card.status)); }
		return node;
	}

	// Teclado numérico com pontos; onDone(code). Teclado físico também funciona enquanto o nó existe.
	function keypad(length, onDone, minLength) {
		const wrap = el('div', 'wl-pad');
		const dots = el('div', 'phone-lock-dots');
		const pad = el('div', 'phone-lock-pad');
		let code = '';
		function paint() {
			dots.replaceChildren();
			for (let i = 0; i < length; i++) {
				const dot = el('b');
				if (i < code.length) { dot.className = 'is-on'; }
				dots.appendChild(dot);
			}
		}
		function press(key) {
			if (/^\d$/.test(key)) {
				if (code.length < length) { code += key; }
				paint();
				if (code.length === length && length === (minLength || length)) { const value = code; code = ''; paint(); onDone(value); }
			} else if (key === 'Backspace') {
				code = code.slice(0, -1);
				paint();
			} else if (key === 'Enter' && code.length >= (minLength || length)) {
				const value = code;
				code = '';
				paint();
				onDone(value);
			}
		}
		['1', '2', '3', '4', '5', '6', '7', '8', '9', 'del', '0', 'ok'].forEach(function (key) {
			const label = key === 'del' ? '⌫' : (key === 'ok' ? 'OK' : key);
			const node = el('button', key === 'del' ? 'is-muted' : (key === 'ok' ? 'is-ok' : ''), label);
			node.type = 'button';
			node.addEventListener('click', function (event) { event.stopPropagation(); press(key === 'del' ? 'Backspace' : (key === 'ok' ? 'Enter' : key)); });
			pad.appendChild(node);
		});
		function onKey(event) {
			if (!wrap.isConnected) { document.removeEventListener('keydown', onKey, true); return; }
			if (/^\d$/.test(event.key) || event.key === 'Backspace' || event.key === 'Enter') {
				event.preventDefault();
				event.stopPropagation();
				press(event.key);
			}
		}
		document.addEventListener('keydown', onKey, true);
		paint();
		wrap.append(dots, pad);
		return wrap;
	}

	// App Carteira ---------------------------------------------------------------------------------------

	phone.register('wallet', function (root, api) {
		const page = el('div', 'wl-app');
		root.appendChild(page);
		let state = null;
		let busy = false;

		function run(action, payload, success) {
			if (busy) { return Promise.resolve(null); }
			busy = true;
			return api.call('wallet', action, payload || {}).then(function (result) {
				busy = false;
				if (!result || !result.ok) {
					api.status(errorOf(api, result), 'error');
					return result;
				}
				if (result.data && result.data.cards && action !== 'eligible') { state = result.data; }
				if (success) { api.status(success, 'success'); }
				return result;
			});
		}

		function load() {
			page.replaceChildren(el('p', 'wl-muted', 'Carregando...'));
			run('list').then(function (result) {
				if (result && result.ok) { paintList(); } else { page.replaceChildren(el('p', 'wl-muted', 'Carteira indisponível.')); }
			});
		}

		function paintList() {
			page.replaceChildren();
			const cards = state.cards || [];
			if (!state.hasPasscode) {
				page.appendChild(el('p', 'wl-note is-warn', 'Defina uma senha em Ajustes para usar a Carteira. Cada pagamento pede o rosto cadastrado ou a senha.'));
			}
			if (!cards.length) {
				const empty = el('div', 'wl-empty');
				empty.append(el('strong', null, 'Nenhum cartão'), el('small', null, 'Adicione um cartão físico (com a senha dele) ou peça um cartão virtual ao banco. Os cartões ficam neste aparelho e não vão para a nuvem.'));
				page.appendChild(empty);
			}
			const list = el('div', 'wl-list');
			cards.forEach(function (card) {
				const face = cardFace(card);
				face.addEventListener('click', function () { paintCard(card); });
				list.appendChild(face);
			});
			page.appendChild(list);
			const add = button('Adicionar cartão', 'coe-button--primary', paintAdd);
			add.disabled = !state.hasPasscode || cards.length >= state.max;
			page.appendChild(add);
			page.appendChild(el('small', 'wl-muted', cards.length + ' de ' + state.max + ' cartões'));
		}

		function paintCard(card) {
			page.replaceChildren(cardFace(card));
			const info = el('div', 'wl-info');
			info.append(
				el('span', null, card.kind === 'virtual' ? 'Cartão virtual: só existe no celular.' : 'Cartão físico vinculado: paga sem precisar estar em mãos.'),
				el('span', null, 'Situação: ' + (STATUS[card.status] || card.status))
			);
			page.appendChild(info);
			const actions = el('div', 'wl-actions');
			if (!card.default) {
				actions.appendChild(button('Tornar padrão', '', function () { run('setDefault', { cardId: card.id }, 'Cartão padrão alterado.').then(function (r) { if (r && r.ok) { paintList(); } }); }));
			}
			actions.appendChild(armedButton('Remover da carteira', 'coe-button--danger', function () {
				run('remove', { cardId: card.id }, 'Cartão removido.').then(function (r) { if (r && r.ok) { paintList(); } else { paintCard(card); } });
			}));
			actions.appendChild(button('Voltar', '', paintList));
			page.appendChild(actions);
		}

		function paintAdd() {
			page.replaceChildren(el('p', 'wl-muted', 'Procurando cartões...'));
			run('eligible').then(function (result) {
				if (!result || !result.ok) { paintList(); return; }
				const data = result.data;
				page.replaceChildren(el('strong', 'wl-title', 'Adicionar cartão'));
				const options = (data.cards || []).filter(function (card) { return !card.added; });
				if (!options.length) {
					page.appendChild(el('p', 'wl-muted', 'Nenhum cartão disponível. Tenha o cartão físico no inventário ou peça um cartão virtual.'));
				}
				const list = el('div', 'wl-list');
				options.forEach(function (card) {
					const face = cardFace(card, true);
					face.addEventListener('click', function () {
						if (card.kind === 'virtual') {
							run('add', { cardId: card.id }, 'Cartão adicionado.').then(function (r) { if (r && r.ok) { paintList(); } });
						} else {
							paintPin(card);
						}
					});
					list.appendChild(face);
				});
				page.appendChild(list);
				const fee = Number(data.virtualFee) || 0;
				page.appendChild(el('small', 'wl-muted', (data.hasVirtual ? 'Trocar cancela o cartão virtual atual. ' : '') + 'O cartão virtual usa o crédito da sua conta' + (fee > 0 ? ' e custa ' + money(fee) + '.' : ', sem tarifa.')));
				page.appendChild(armedButton(data.hasVirtual ? 'Trocar cartão virtual' : 'Pedir cartão virtual', '', function () {
					run('issueVirtual', {}, 'Cartão virtual emitido.').then(function (r) { if (r && r.ok) { paintList(); } else { paintAdd(); } });
				}));
				page.appendChild(button('Voltar', '', paintList));
			});
		}

		function paintPin(card) {
			page.replaceChildren(cardFace(card, true), el('p', 'wl-muted', 'Digite a senha do cartão para vinculá-lo.'));
			page.appendChild(keypad(PIN_LENGTH, function (pin) {
				run('add', { cardId: card.id, pin: pin }, 'Cartão adicionado.').then(function (r) {
					if (r && r.ok) { paintList(); }
					else if (r && (r.error === 'card_blocked' || r.error === 'no_card')) { paintAdd(); }
				});
			}));
			page.appendChild(button('Cancelar', '', paintAdd));
		}

		load();
	});

	// Pagamento ------------------------------------------------------------------------------------------

	let sheet = null;

	// Abre a folha de pagamento: escolhe o cartão e confirma com o rosto ou a senha.
	// options: { amount, label, note }. Resolve { token, cardId } ou null (cancelado).
	phone.pay = function (options) {
		const api = phone;
		const amount = Math.floor(Number(options && options.amount) || 0);
		if (sheet) { sheet.close(null); }
		return new Promise(function (resolve) {
			const screen = document.getElementById('phone-screen');
			const node = el('section', 'wl-sheet');
			const panel = el('div', 'wl-sheet-panel');
			node.appendChild(panel);
			screen.appendChild(node);
			let cards = [];
			let chosen = null;
			let done = false;

			function close(value) {
				if (done) { return; }
				done = true;
				sheet = null;
				node.remove();
				document.removeEventListener('keydown', onEscape, true);
				resolve(value);
			}
			function onEscape(event) {
				if (event.key === 'Escape') { event.preventDefault(); event.stopPropagation(); close(null); }
			}
			document.addEventListener('keydown', onEscape, true);
			sheet = { close: close };

			function head() {
				const top = el('div', 'wl-sheet-head');
				top.append(el('strong', null, options.label || 'Pagamento'), el('span', 'wl-sheet-amount', money(amount)));
				const box = el('div');
				box.appendChild(top);
				if (options.note) { box.appendChild(el('small', 'wl-muted', options.note)); }
				return box;
			}

			function message(text, isError) {
				const p = el('p', isError ? 'wl-sheet-msg is-error' : 'wl-sheet-msg', text);
				return p;
			}

			function paintChoose(error) {
				panel.replaceChildren(head());
				const usable = cards.filter(function (card) { return card.status === 'active'; });
				if (!usable.length) {
					panel.appendChild(message('Nenhum cartão ativo na Carteira. Abra o app Carteira para adicionar um.', true));
					panel.appendChild(button('Abrir Carteira', 'coe-button--primary', function () { close(null); api.openApp('wallet'); }));
				} else {
					if (!chosen || chosen.status !== 'active') { chosen = usable.find(function (c) { return c.default; }) || usable[0]; }
					const list = el('div', 'wl-sheet-cards');
					usable.forEach(function (card) {
						const face = cardFace(card, true);
						face.classList.toggle('is-chosen', card.id === chosen.id);
						face.addEventListener('click', function () { chosen = card; paintChoose(); });
						list.appendChild(face);
					});
					panel.appendChild(list);
					if (error) { panel.appendChild(message(error, true)); }
					panel.appendChild(button('Pagar ' + money(amount), 'coe-button--primary', confirm));
				}
				panel.appendChild(button('Cancelar', '', function () { close(null); }));
			}

			function authorize(proof) {
				return api.call('wallet', 'authorize', Object.assign({ cardId: chosen.id, amount: amount }, proof)).then(function (result) {
					if (result && result.ok && result.data && result.data.token) {
						close({ token: result.data.token, cardId: chosen.id });
						return true;
					}
					return result;
				});
			}

			function confirm() {
				const settings = api.settings() || {};
				const profile = api.profile() || {};
				if (settings.faceId && profile.device && profile.device.myFace) { paintFace(); } else { paintCode(); }
			}

			function paintFace() {
				panel.replaceChildren(head());
				const face = el('i', 'phone-lock-face is-scanning');
				face.innerHTML = api.svg('face');
				const text = message('Reconhecendo rosto...');
				panel.append(face, text, button('Usar senha', '', paintCode));
				setTimeout(function () {
					if (done || !face.isConnected) { return; }
					authorize({ face: true }).then(function (result) {
						if (result === true || done) { return; }
						paintCode(result && result.error === 'face_mismatch' ? 'Rosto não reconhecido. Use a senha.' : errorOf(api, result));
					});
				}, 900);
			}

			function paintCode(error) {
				panel.replaceChildren(head());
				panel.appendChild(message(typeof error === 'string' ? error : 'Digite a senha do celular', typeof error === 'string'));
				const limits = api.passcodeLimits();
				panel.appendChild(keypad(limits.MaxLength, function (code) {
					authorize({ code: code }).then(function (result) {
						if (result === true || done) { return; }
						if (result && ['card_blocked', 'card_expired', 'no_card', 'not_in_wallet'].indexOf(result.error) >= 0) {
							chosen = null;
							load(errorOf(api, result));
							return;
						}
						paintCode(errorOf(api, result));
						panel.classList.remove('is-shake');
						void panel.offsetWidth;
						panel.classList.add('is-shake');
					});
				}, limits.MinLength));
				panel.appendChild(button('Cancelar', '', function () { close(null); }));
			}

			function load(error) {
				panel.replaceChildren(head(), message('Abrindo Carteira...'));
				api.call('wallet', 'list', {}).then(function (result) {
					if (done) { return; }
					if (!result || !result.ok) {
						panel.replaceChildren(head(), message(errorOf(api, result), true), button('Fechar', '', function () { close(null); }));
						return;
					}
					if (!result.data.hasPasscode) {
						panel.replaceChildren(head(), message(api.errorText('wallet_passcode'), true), button('Fechar', '', function () { close(null); }));
						return;
					}
					cards = result.data.cards || [];
					paintChoose(error);
				});
			}

			if (amount < 1) { close(null); return; }
			load();
		});
	};

	// Pagamento pedido por outro resource (export RequestPayment do client): mostra a folha e devolve a autorização.
	window.addEventListener('message', function (event) {
		const message = event.data || {};
		if (message.action !== 'payRequest' || !message.data) { return; }
		const request = message.data;
		phone.pay({ amount: request.amount, label: request.label, note: request.note }).then(function (result) {
			return fetch('https://' + GetParentResourceName() + '/payResult', {
				method: 'POST',
				headers: { 'Content-Type': 'application/json; charset=UTF-8' },
				body: JSON.stringify({ id: request.id, token: result ? result.token : null, cardId: result ? result.cardId : null })
			});
		}).catch(function () { return null; });
	});
}());
