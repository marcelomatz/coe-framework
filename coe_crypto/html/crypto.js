// Carteira cripto (coe_crypto) no smartphone, no tablet e nos computadores do coe_deepweb: carteiras com chave,
// envio, corretora com cotação e explorador público da rede.
(function () {
	'use strict';

	const host = window.CoeComputer || window.CoePhone || window.CoeTablet;
	if (!host) { return; }

	if (!document.querySelector('link[data-coe-crypto]')) {
		const link = document.createElement('link');
		link.rel = 'stylesheet';
		link.href = 'nui://coe_crypto/html/crypto.css';
		link.dataset.coeCrypto = '1';
		document.head.appendChild(link);
	}

	const ERRORS = {
		not_ready: 'Rede ainda iniciando.', no_character: 'Personagem não carregado.', no_device: 'Aparelho não reconhecido.',
		not_installed: 'App indisponível neste aparelho.', database_error: 'Falha na rede. Tente de novo.', busy: 'Aguarde a operação anterior.',
		rate_limited: 'Calma, muitas ações seguidas.', unknown_action: 'Ação desconhecida.',
		device_full: 'Este aparelho já guarda o máximo de carteiras. Remova uma.', create_limit: 'Você criou carteiras demais hoje.',
		invalid_key: 'Endereço ou chave inválidos.', invalid_key_format: 'Chave em formato inválido: NXK- e 25 letras/números (sem 0, 1, I e O).', key_mismatch: 'Essa chave não é desta carteira. Confira letra por letra.', import_locked: 'Muitas chaves erradas. Aguarde um pouco.',
		invalid_address: 'Endereço inválido.', unknown_address: 'Esse endereço não existe na rede.', no_key: 'A chave dessa carteira não está à mão.',
		invalid_recipient: 'Endereço de destino inválido.', unknown_recipient: 'O endereço de destino não existe na rede.',
		same_address: 'Origem e destino são o mesmo endereço.', invalid_amount: 'Quantia inválida.',
		too_many_decimals: 'Casas decimais demais.', insufficient_funds: 'Saldo insuficiente.', send_cooldown: 'Aguarde alguns segundos para enviar de novo.',
		inventory_full: 'Sem espaço no inventário.', inventory_error: 'Falha no inventário.', no_blank_usb: 'Você precisa de um pen drive vazio.',
		exchange_closed: 'Corretora fechada.', order_cooldown: 'Aguarde para fazer outra ordem.', order_out_of_range: 'Valor fora dos limites da corretora.',
		daily_limit: 'Limite diário da corretora atingido.', no_liquidity: 'Corretora sem liquidez no momento.',
		bank_unavailable: 'Banco indisponível.', payment_failed: 'O banco recusou a operação.', locked: 'Aparelho bloqueado.'
	};

	const SOURCES = { device: 'Neste aparelho', paper: 'Papel', usb: 'Pen drive' };
	const KINDS = { transfer: 'Transferência', buy: 'Compra', sell: 'Venda', mint: 'Mineração', genesis: 'Gênese', refund: 'Estorno' };

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

	function input(placeholder, value, type) {
		const node = el('input', 'coe-field');
		node.type = type || 'text';
		node.placeholder = placeholder || '';
		if (value !== undefined && value !== null) { node.value = value; }
		node.spellcheck = false;
		return node;
	}

	function select(options, value) {
		const node = el('select', 'coe-field');
		options.forEach(function (option) {
			const item = el('option', null, option.label);
			item.value = option.value;
			if (option.value === value) { item.selected = true; }
			node.appendChild(item);
		});
		return node;
	}

	function field(label, control, hint) {
		const box = el('label', 'cr-field');
		box.appendChild(el('span', 'tb-muted', label));
		box.appendChild(control);
		if (hint) { box.appendChild(el('small', 'tb-muted', hint)); }
		return box;
	}

	function money(value) {
		return '$ ' + Number(value || 0).toLocaleString('pt-BR');
	}

	function when(seconds) {
		if (!seconds) { return '-'; }
		const d = new Date(Number(seconds) * 1000);
		return String(d.getDate()).padStart(2, '0') + '/' + String(d.getMonth() + 1).padStart(2, '0') + ' ' +
			String(d.getHours()).padStart(2, '0') + ':' + String(d.getMinutes()).padStart(2, '0');
	}

	function shortAddress(address) {
		return address ? address.slice(0, 8) + '…' + address.slice(-6) : '';
	}

	function copy(text) {
		const area = el('textarea');
		area.value = text;
		area.style.position = 'fixed';
		area.style.opacity = '0';
		document.body.appendChild(area);
		area.select();
		let done = false;
		try { done = document.execCommand('copy'); } catch (e) { done = false; }
		area.remove();
		return done;
	}

	host.register('crypto', function (root, api) {
		let data = null;
		let tab = 'wallets';
		let busy = false;
		let draft = {};
		let revealed = null;
		let explored = null;
		let confirmForget = null;

		const symbol = function () { return data && data.coin ? data.coin.symbol : 'NOX'; };
		const decimals = function () { return data && data.coin ? data.coin.decimals : 4; };

		function units(value) {
			const scale = Math.pow(10, decimals());
			const n = Number(value || 0);
			const sign = n < 0 ? '-' : '';
			const abs = Math.abs(n);
			const whole = Math.floor(abs / scale);
			const fraction = String(abs % scale).padStart(decimals(), '0');
			return sign + whole.toLocaleString('pt-BR') + ',' + fraction + ' ' + symbol();
		}

		function parseUnits(text) {
			const clean = String(text || '').trim().replace(',', '.');
			if (!/^\d+(\.\d+)?$/.test(clean)) { return null; }
			const parts = clean.split('.');
			const fraction = (parts[1] || '').slice(0, decimals()).padEnd(decimals(), '0');
			return Number(parts[0]) * Math.pow(10, decimals()) + Number(fraction);
		}

		function errorText(code) { return ERRORS[code] || api.errorText(code); }

		function request(action, payload, onDone, message) {
			if (busy) { return; }
			busy = true;
			paintBusy();
			api.call('crypto', action, payload || {}).then(function (result) {
				busy = false;
				paintBusy();
				if (!result || !result.ok) {
					api.status(errorText(result && result.error), 'error');
					return;
				}
				if (message) { api.status(message, 'success'); }
				if (onDone) { onDone(result); }
			});
		}

		function load(message) {
			api.call('crypto', 'state', {}).then(function (result) {
				if (!result || !result.ok) {
					root.replaceChildren(el('p', 'tb-empty', errorText(result && result.error)));
					return;
				}
				data = result;
				if (message) { api.status(message, 'success'); }
				paint();
			});
		}

		function paintBusy() {
			root.classList.toggle('cr-busy', busy);
		}

		function walletOptions(onlyHeld) {
			return (data.wallets || []).filter(function (w) { return !onlyHeld || w.known; }).map(function (w) {
				return { value: w.address, label: (w.label || shortAddress(w.address)) + ' · ' + units(w.balance) };
			});
		}

		// Carteiras -------------------------------------------------------------------------------------

		function walletCard(wallet) {
			const box = el('div', 'coe-panel coe-panel--compact tb-card cr-wallet');
			const head = el('div', 'tb-card-head');
			const title = el('div', 'tb-title');
			title.append(el('strong', null, wallet.label || 'Carteira'), el('span', 'tb-muted cr-mono', shortAddress(wallet.address)));
			head.append(title, el('span', 'coe-badge ' + (wallet.source === 'device' ? 'tb-badge--accent' : 'tb-badge--warn'), SOURCES[wallet.source] || wallet.source));
			box.appendChild(head);
			const total = el('div', 'tb-total');
			total.append(el('span', null, 'Saldo'), el('strong', null, units(wallet.balance)));
			box.appendChild(total);
			if (data.market) {
				box.appendChild(el('span', 'tb-muted', '≈ ' + money(Math.floor(wallet.balance * data.market.sell / Math.pow(10, decimals()))) + ' na venda'));
			}
			if (revealed && revealed.address === wallet.address) {
				const secret = el('div', 'cr-secret');
				secret.append(el('span', 'tb-muted', 'Chave privada: quem tiver esta chave move os fundos.'), el('code', 'cr-mono', revealed.key));
				secret.appendChild(button('Copiar', '', function () { api.status(copy(revealed.key) ? 'Chave copiada.' : 'Não foi possível copiar.', 'info'); }));
				box.appendChild(secret);
			}
			const actions = el('div', 'tb-actions');
			actions.append(
				button('Receber', '', function () {
					api.status(copy(wallet.address) ? 'Endereço copiado: ' + wallet.address : wallet.address, 'info');
				}),
				button('Enviar', 'coe-button--primary', function () { draft.from = wallet.address; tab = 'send'; paint(); }),
				button(revealed && revealed.address === wallet.address ? 'Ocultar chave' : 'Ver chave', '', function () {
					if (revealed && revealed.address === wallet.address) { revealed = null; paint(); return; }
					request('reveal', { address: wallet.address }, function (result) { revealed = result; paint(); });
				}),
				button('Anotar em papel', '', function () { request('exportPaper', { address: wallet.address }, null, 'Chave anotada num papel (inventário).'); })
			);
			if (data.hasBlankUsb) {
				actions.appendChild(button('Gravar em pen drive', '', function () {
					request('exportUsb', { address: wallet.address }, function () { load('Chave gravada no pen drive.'); });
				}));
			}
			if (wallet.source === 'device') {
				const confirming = confirmForget === wallet.address;
				actions.appendChild(button(confirming ? 'Confirmar: remover' : 'Remover', 'coe-button--danger', function () {
					if (!confirming) {
						confirmForget = wallet.address;
						api.status('Sem outra cópia da chave, os fundos ficam inacessíveis para sempre. Toque de novo para confirmar.', 'error');
						paint();
						return;
					}
					confirmForget = null;
					request('forget', { address: wallet.address }, function () { load('Carteira removida do aparelho.'); });
				}));
			}
			box.appendChild(actions);
			return box;
		}

		function wallets(body) {
			const tools = el('div', 'tb-toolbar');
			tools.append(el('span', 'tb-section', 'Carteiras à mão'), el('span', 'tb-muted',
				(data.wallets || []).filter(function (w) { return w.source === 'device'; }).length + '/' + data.deviceSlots + ' neste aparelho'));
			body.appendChild(tools);
			if (!data.wallets || data.wallets.length === 0) {
				body.appendChild(el('p', 'tb-empty', 'Nenhuma carteira por aqui. Crie uma ou importe com endereço e chave.'));
			} else {
				const grid = el('div', 'tb-grid');
				data.wallets.forEach(function (wallet) { grid.appendChild(walletCard(wallet)); });
				body.appendChild(grid);
			}

			const forms = el('div', 'tb-grid');
			const create = el('div', 'coe-panel coe-panel--compact tb-card');
			create.appendChild(el('strong', null, 'Nova carteira'));
			const label = input('Nome (opcional)', '');
			create.appendChild(field('Nome', label));
			create.appendChild(el('p', 'tb-muted', 'A chave fica guardada neste aparelho. Anote em papel ou grave num pen drive: perdeu o aparelho, perdeu a carteira.'));
			create.appendChild(el('div', 'tb-actions')).appendChild(button('Criar', 'coe-button--primary', function () {
				request('create', { label: label.value }, function (result) {
					revealed = { address: result.address, key: result.key };
					load('Carteira criada. Anote a chave!');
				});
			}));

			const importBox = el('div', 'coe-panel coe-panel--compact tb-card');
			importBox.appendChild(el('strong', null, 'Importar carteira'));
			const address = input('nx…', '');
			const key = input('NXK-XXXXX-XXXXX-XXXXX-XXXXX-XXXXX', '');
			const importLabel = input('Nome (opcional)', '');
			importBox.append(field('Endereço', address), field('Chave privada', key), field('Nome', importLabel));
			importBox.appendChild(el('p', 'tb-muted', 'Mais fácil: no aparelho de origem, use "Anotar em papel" ou "Gravar em pen drive". Com o papel ou o pen drive no inventário, a carteira aparece sozinha em qualquer aparelho.'));
			importBox.appendChild(el('div', 'tb-actions')).appendChild(button('Importar', '', function () {
				request('import', { address: address.value, key: key.value, label: importLabel.value }, function () { load('Carteira importada para este aparelho.'); });
			}));
			forms.append(create, importBox);
			body.appendChild(forms);
		}

		// Envio -----------------------------------------------------------------------------------------

		function send(body) {
			const options = walletOptions(true);
			if (options.length === 0) {
				body.appendChild(el('p', 'tb-empty', 'Você precisa de uma carteira com chave à mão para enviar.'));
				return;
			}
			const box = el('div', 'coe-panel coe-panel--compact tb-card cr-form');
			const from = select(options, draft.from || options[0].value);
			const to = input('nx…', draft.to || '');
			const amount = input('0,0000', draft.amount || '');
			const memo = input('Mensagem (opcional, pública)', draft.memo || '');
			const preview = el('div', 'tb-total');
			function update() {
				draft = { from: from.value, to: to.value, amount: amount.value, memo: memo.value };
				const value = parseUnits(amount.value);
				preview.replaceChildren(el('span', null, 'Taxa da rede ' + units(data.fee)), el('strong', null, value ? 'Total ' + units(value + data.fee) : '-'));
			}
			[from, to, amount, memo].forEach(function (node) { node.addEventListener('input', update); });
			box.append(field('De', from), field('Para', to), field('Quantia (' + symbol() + ')', amount), field('Mensagem', memo), preview);
			box.appendChild(el('p', 'tb-muted', 'Transações na rede não podem ser desfeitas. Confira o endereço.'));
			box.appendChild(el('div', 'tb-actions')).appendChild(button('Enviar', 'coe-button--primary', function () {
				request('send', { from: from.value, to: to.value.trim(), amount: amount.value, memo: memo.value }, function () {
					draft = {};
					tab = 'wallets';
					load('Envio confirmado na rede.');
				});
			}));
			update();
			body.appendChild(box);
		}

		// Corretora -------------------------------------------------------------------------------------

		function sparkline(points) {
			const ns = 'http://www.w3.org/2000/svg';
			const svg = document.createElementNS(ns, 'svg');
			svg.setAttribute('viewBox', '0 0 300 80');
			svg.setAttribute('preserveAspectRatio', 'none');
			svg.classList.add('cr-chart');
			if (!points || points.length < 2) { return svg; }
			const min = Math.min.apply(null, points);
			const max = Math.max.apply(null, points);
			const span = Math.max(1, max - min);
			const coords = points.map(function (value, index) {
				return (index * 300 / (points.length - 1)).toFixed(1) + ',' + (76 - (value - min) * 72 / span).toFixed(1);
			});
			const line = document.createElementNS(ns, 'polyline');
			line.setAttribute('points', coords.join(' '));
			line.setAttribute('class', points[points.length - 1] >= points[0] ? 'is-up' : 'is-down');
			svg.appendChild(line);
			return svg;
		}

		function exchange(body) {
			if (!data.exchange) {
				body.appendChild(el('p', 'tb-empty', 'Corretora fechada.'));
				return;
			}
			const marketInfo = data.market;
			const head = el('div', 'coe-panel coe-panel--compact tb-card');
			const top = el('div', 'tb-card-head');
			top.append(el('strong', null, data.exchange.name + ' · ' + symbol() + '/$'),
				el('span', 'coe-badge ' + (marketInfo.change >= 0 ? 'coe-badge--success' : 'tb-badge--warn'),
					(marketInfo.change >= 0 ? '+' : '') + String(marketInfo.change).replace('.', ',') + '% 24h'));
			head.appendChild(top);
			const price = el('div', 'tb-total');
			price.append(el('span', null, 'Cotação'), el('strong', null, money(marketInfo.price)));
			head.append(price, sparkline(marketInfo.history));
			const lines = el('div', 'tb-lines');
			[['Você compra a', money(marketInfo.buy)], ['Você vende a', money(marketInfo.sell)],
				['Limite de compra hoje', money(data.exchange.buyLeft)], ['Limite de venda hoje', money(data.exchange.sellLeft)]].forEach(function (row) {
				const line = el('div', 'tb-line');
				line.append(el('span', 'tb-muted', row[0]), el('strong', null, row[1]));
				lines.appendChild(line);
			});
			head.appendChild(lines);
			head.appendChild(el('span', 'tb-muted', 'Atualiza a cada ' + marketInfo.tickMinutes + ' min. Ordens identificadas: o dinheiro sai e entra na sua conta do banco.'));
			body.appendChild(head);

			const grid = el('div', 'tb-grid');
			const all = walletOptions(false);
			const held = walletOptions(true);

			const buyBox = el('div', 'coe-panel coe-panel--compact tb-card cr-form');
			buyBox.appendChild(el('strong', null, 'Comprar'));
			const buyTo = all.length ? select(all, all[0].value) : input('Endereço de destino (nx…)', '');
			const dollars = input(String(data.exchange.minOrder), '', 'number');
			const buyPreview = el('div', 'tb-total');
			function updateBuy() {
				const value = Math.floor(Number(dollars.value) || 0);
				const got = value > 0 ? Math.floor(value * Math.pow(10, decimals()) / marketInfo.buy) : 0;
				buyPreview.replaceChildren(el('span', null, 'Você recebe'), el('strong', null, got ? '≈ ' + units(got) : '-'));
			}
			dollars.addEventListener('input', updateBuy);
			buyBox.append(field('Carteira de destino', buyTo), field('Valor em $', dollars, 'De ' + money(data.exchange.minOrder) + ' a ' + money(data.exchange.maxOrder)), buyPreview);
			buyBox.appendChild(el('div', 'tb-actions')).appendChild(button('Comprar', 'coe-button--primary', function () {
				request('buy', { address: buyTo.value.trim(), dollars: Math.floor(Number(dollars.value) || 0) }, function (result) {
					load('Compra feita: ' + units(result.units) + ' por ' + money(result.cost) + '.');
				});
			}));
			updateBuy();

			const sellBox = el('div', 'coe-panel coe-panel--compact tb-card cr-form');
			sellBox.appendChild(el('strong', null, 'Vender'));
			if (held.length === 0) {
				sellBox.appendChild(el('p', 'tb-muted', 'Para vender, a chave da carteira precisa estar à mão.'));
			} else {
				const sellFrom = select(held, held[0].value);
				const amount = input('0,0000', '');
				const sellPreview = el('div', 'tb-total');
				const updateSell = function () {
					const value = parseUnits(amount.value);
					const got = value ? Math.floor(value * marketInfo.sell / Math.pow(10, decimals())) : 0;
					sellPreview.replaceChildren(el('span', null, 'Você recebe no banco'), el('strong', null, got ? money(got) : '-'));
				};
				amount.addEventListener('input', updateSell);
				sellBox.append(field('Carteira de origem', sellFrom), field('Quantia (' + symbol() + ')', amount), sellPreview);
				sellBox.appendChild(el('div', 'tb-actions')).appendChild(button('Vender', 'coe-button--danger', function () {
					request('sell', { address: sellFrom.value, amount: amount.value }, function (result) {
						load('Venda feita: ' + money(result.payout) + ' na sua conta.');
					});
				}));
				updateSell();
			}
			grid.append(buyBox, sellBox);
			body.appendChild(grid);
		}

		// Explorador ------------------------------------------------------------------------------------

		function explorer(body) {
			const box = el('div', 'coe-panel coe-panel--compact tb-card cr-form');
			const address = input('nx…', explored ? explored.address : '');
			box.append(el('strong', null, 'Explorador da rede'), el('span', 'tb-muted', 'Toda a rede é pública: qualquer endereço mostra saldo e movimentações.'), field('Endereço', address));
			box.appendChild(el('div', 'tb-actions')).appendChild(button('Consultar', 'coe-button--primary', function () {
				request('explore', { address: address.value.trim() }, function (result) { explored = result; paint(); });
			}));
			const mine = (data.wallets || []).map(function (w) { return w.address; });
			if (mine.length) {
				const chips = el('div', 'tb-chips');
				(data.wallets || []).forEach(function (w) {
					chips.appendChild(button(w.label || shortAddress(w.address), '', function () {
						request('explore', { address: w.address }, function (result) { explored = result; paint(); });
					}));
				});
				box.appendChild(chips);
			}
			body.appendChild(box);
			if (!explored) { return; }
			const result = el('div', 'coe-panel coe-panel--compact tb-card');
			const total = el('div', 'tb-total');
			total.append(el('span', 'cr-mono', shortAddress(explored.address)), el('strong', null, units(explored.balance)));
			result.appendChild(total);
			if (!explored.history.length) {
				result.appendChild(el('p', 'tb-empty', 'Sem movimentações.'));
			}
			const list = el('div', 'tb-lines');
			explored.history.forEach(function (tx) {
				const incoming = tx.to === explored.address;
				const row = el('div', 'tb-line cr-tx');
				const left = el('div', 'tb-title');
				const peer = incoming ? tx.from : tx.to;
				left.append(el('strong', null, (KINDS[tx.kind] || tx.kind) + (peer ? (incoming ? ' de ' : ' para ') + shortAddress(peer) : '')),
					el('span', 'tb-muted', when(tx.at) + (tx.memo ? ' · ' + tx.memo : '')));
				row.append(left, el('strong', incoming ? 'tb-in' : 'tb-out', (incoming ? '+' : '−') + units(tx.amount + (incoming ? 0 : tx.fee))));
				list.appendChild(row);
			});
			result.appendChild(list);
			if (explored.more) {
				const last = explored.history[explored.history.length - 1];
				result.appendChild(el('div', 'tb-actions tb-more')).appendChild(button('Mais antigas', '', function () {
					request('explore', { address: explored.address, before: last.id }, function (page) {
						explored.history = explored.history.concat(page.history);
						explored.more = page.more;
						paint();
					});
				}));
			}
			body.appendChild(result);
		}

		// Estrutura -------------------------------------------------------------------------------------

		const TABS = [
			{ id: 'wallets', label: 'Carteiras', render: wallets },
			{ id: 'send', label: 'Enviar', render: send },
			{ id: 'exchange', label: 'Corretora', render: exchange },
			{ id: 'explorer', label: 'Explorador', render: explorer }
		];

		function paint() {
			root.replaceChildren();
			root.classList.add('cr-app');
			const tabs = el('nav', 'tb-tabs');
			TABS.forEach(function (entry) {
				const node = el('button', 'tb-tab' + (tab === entry.id ? ' is-active' : ''), entry.label);
				node.type = 'button';
				node.addEventListener('click', function () {
					tab = entry.id;
					revealed = tab === 'wallets' ? revealed : null;
					if (tab === 'exchange') {
						api.call('crypto', 'market', {}).then(function (result) {
							if (result && result.ok) { data.market = result.market; }
							paint();
						});
						return;
					}
					paint();
				});
				tabs.appendChild(node);
			});
			root.appendChild(tabs);
			const body = el('div', 'cr-body');
			const current = TABS.find(function (entry) { return entry.id === tab; }) || TABS[0];
			current.render(body);
			root.appendChild(body);
		}

		root.replaceChildren(el('p', 'tb-empty', 'Conectando à rede…'));
		load();
	});
})();
