// Navegador onion (coe_deepweb) no celular, no tablet e nos computadores. Barra de endereço, abas, voltar/avançar,
// favoritos (por aparelho) e histórico só da sessão. Páginas internas `about:` (rede, identidade, mineração,
// computador, favoritos, histórico); os sites da rede (DuckDark, Rabbit, Deep Market, perfis da staff e páginas por blocos) ficam em
// sites.js. Todo conteúdo vem do servidor e é escrito com textContent (nada de HTML vindo da rede).
(function () {
	'use strict';

	const host = window.CoeComputer || window.CoePhone || window.CoeTablet;
	if (!host) { return; }

	function css(href, key) {
		if (document.querySelector('link[data-coe-deepweb="' + key + '"]')) { return; }
		const link = document.createElement('link');
		link.rel = 'stylesheet';
		link.href = href;
		link.dataset.coeDeepweb = key;
		document.head.appendChild(link);
	}
	css('nui://coe_deepweb/html/deepweb.css', 'base');
	css('nui://coe_deepweb/html/browser.css', 'browser');

	// sites.js registra os renderizadores dos sites em CoeOnion.sites.
	const sitesReady = new Promise(function (resolve) {
		if (window.CoeOnion && window.CoeOnion.sitesLoaded) { resolve(); return; }
		const script = document.createElement('script');
		script.src = 'nui://coe_deepweb/html/sites.js';
		script.onload = function () { resolve(); };
		script.onerror = function () { resolve(); };
		document.head.appendChild(script);
	});

	const ERRORS = {
		not_ready: 'Rede ainda iniciando.', no_character: 'Personagem não carregado.', no_device: 'Aparelho não reconhecido.',
		not_installed: 'Navegador não instalado neste aparelho.', database_error: 'Falha na rede. Tente de novo.', busy: 'Aguarde a operação anterior.',
		tier_too_low: 'Seu equipamento não alcança este recurso.', invalid_handle: 'Apelido inválido: 3 a 20 letras minúsculas, números, ponto, hífen ou sublinhado.',
		handle_reserved: 'Esse apelido é reservado.', handle_taken: 'Esse apelido já existe.', handle_limit: 'Você já criou o máximo de apelidos.',
		invalid_password: 'Senha inválida (tamanho mínimo, sem espaço nas pontas).', wrong_credentials: 'Apelido ou senha incorretos.',
		wrong_password: 'Senha incorreta.', login_locked: 'Muitas tentativas erradas. Aguarde.', not_signed_in: 'Entre com um apelido (about:identidade).',
		crypto_unavailable: 'Rede cripto indisponível.', invalid_address: 'Endereço inválido.', unknown_address: 'Esse endereço não existe na rede.',
		no_payout: 'Informe a carteira que recebe a mineração.', not_owner: 'Só quem criou o apelido pode redefinir a senha.', password_required: 'Defina uma senha do computador antes de ligar o reconhecimento facial.',
		craft_unavailable: 'Bancada indisponível agora.', not_found: 'Não encontrado.', inventory_full: 'Sem espaço no inventário.', rate_limited: 'Calma, muitas ações seguidas.',
		bookmark_limit: 'Favoritos cheios. Remova algum.', invalid_query: 'Busque com 2 a 40 caracteres.',
		invalid_slug: 'Nome da comunidade: 3 a 21 letras minúsculas, números ou sublinhado.', slug_reserved: 'Esse nome é reservado.', slug_taken: 'Essa comunidade já existe.',
		community_limit: 'Você já criou o máximo de comunidades.', invalid_community: 'Escolha uma comunidade.', invalid_title: 'Título curto ou longo demais.',
		invalid_body: 'Texto vazio ou longo demais.', post_cooldown: 'Espere um pouco antes de postar de novo.', comment_cooldown: 'Espere um pouco antes de comentar de novo.',
		invalid_vote: 'Voto inválido.', own_content: 'Não dá para votar no próprio conteúdo.', forbidden: 'Sem permissão.',
		invalid_quantity: 'Quantidade inválida.', own_listing: 'Esse anúncio é seu.', out_of_stock: 'Sem estoque.', seller_unavailable: 'Vendedor sem carteira de recebimento.',
		insufficient_funds: 'Saldo insuficiente (valor + taxa da rede).', no_key: 'A chave dessa carteira não está neste aparelho.', invalid_key: 'Chave inválida.',
		invalid_amount: 'Valor inválido.', invalid_price: 'Preço inválido.', invalid_stock: 'Estoque inválido.', invalid_item: 'Informe o item (nome no inventário).',
		invalid_count: 'Quantidade por unidade inválida.', invalid_category: 'Escolha uma categoria.', invalid_description: 'Descrição longa demais.',
		unknown_item: 'Esse item não existe.', invalid_payout: 'Carteira de recebimento inválida.', unknown_payout: 'A carteira de recebimento não existe na rede.',
		listing_limit: 'Você já tem anúncios demais.', invalid_listing: 'Anúncio inválido.', invalid_action: 'Ação inválida.', invalid_status: 'O pedido já mudou de estado.',
		not_seller: 'Só o vendedor faz isso.', not_buyer: 'Só o comprador faz isso.', too_early: 'Ainda dentro do prazo do vendedor.',
		not_at_drop: 'Vá até o ponto de coleta.', missing_items: 'Você não tem os itens para entregar.', invalid_note: 'Explique o problema (até 200 caracteres).',
		invalid_rating: 'Dê de 1 a 5 estrelas.', invalid_review: 'Avaliação longa demais.', already_reviewed: 'Pedido já avaliado.',
		invalid_message: 'Mensagem curta ou longa demais.', contact_cooldown: 'Espere um pouco antes de mandar outra mensagem.',
		contact_limit: 'Você já tem mensagens demais sem resposta.'
	};

	const STATES = { open: 'Liberado', locked: 'Bloqueado', soon: 'Em breve' };
	const MINING = {
		ok: 'Minerando', off: 'Desligada', no_payout: 'Sem carteira', no_contract: 'Imóvel sem contrato', no_power: 'Sem saldo para energia',
		network: 'Rede recusou a rodada', no_hash: 'Máquina não minera', '': 'Aguardando a primeira rodada'
	};

	// Utilitários de DOM (usados também pelo sites.js) --------------------------------------------------

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

	function input(placeholder, type) {
		const node = el('input', 'coe-field');
		node.type = type || 'text';
		node.placeholder = placeholder || '';
		node.spellcheck = false;
		node.autocomplete = 'off';
		return node;
	}

	function textarea(placeholder, rows) {
		const node = el('textarea', 'coe-field ob-textarea');
		node.placeholder = placeholder || '';
		node.rows = rows || 4;
		node.spellcheck = false;
		return node;
	}

	function select(options, value) {
		const node = el('select', 'coe-field');
		options.forEach(function (option) {
			const entry = el('option', null, option.label);
			entry.value = option.value;
			if (option.value === value) { entry.selected = true; }
			node.appendChild(entry);
		});
		return node;
	}

	function field(label, control) {
		const box = el('label', 'dw-field');
		box.append(el('span', 'tb-muted', label), control);
		return box;
	}

	function when(seconds) {
		if (!seconds) { return '-'; }
		const d = new Date(Number(seconds) * 1000);
		return String(d.getDate()).padStart(2, '0') + '/' + String(d.getMonth() + 1).padStart(2, '0') + ' ' +
			String(d.getHours()).padStart(2, '0') + ':' + String(d.getMinutes()).padStart(2, '0');
	}

	function ago(seconds) {
		if (!seconds) { return ''; }
		const diff = Math.max(0, Math.floor(Date.now() / 1000) - Number(seconds));
		if (diff < 60) { return 'agora'; }
		if (diff < 3600) { return Math.floor(diff / 60) + ' min'; }
		if (diff < 86400) { return Math.floor(diff / 3600) + ' h'; }
		return Math.floor(diff / 86400) + ' d';
	}

	function line(label, value) {
		const node = el('div', 'tb-line');
		node.append(el('span', 'tb-muted', label), el('strong', null, value));
		return node;
	}

	function card(className) {
		return el('div', 'coe-panel coe-panel--compact tb-card ' + (className || ''));
	}

	// Link interno: navega na aba atual (o endereço vai para o histórico).
	function link(text, address, className, go) {
		const node = el('a', 'ob-link ' + (className || ''), text);
		node.href = '#';
		node.title = address;
		node.addEventListener('click', function (event) { event.preventDefault(); go(address); });
		return node;
	}

	// Endereço -> { kind: about|site|search, page, domain, path, query, href }. Mesmo formato do servidor.
	function parse(value) {
		const text = String(value || '').trim();
		if (!text) { return null; }
		const lower = text.toLowerCase().replace(/^https?:\/\//, '').replace(/^onion:\/\//, '');
		const about = lower.match(/^about:([a-z]+)$/);
		if (about) { return { kind: 'about', page: about[1], href: 'about:' + about[1] }; }
		const match = lower.match(/^([a-z0-9-]+\.onion)(.*)$/);
		if (!match) { return { kind: 'search', query: text, href: 'duckdark.onion/?q=' + text }; }
		const parts = match[2].split('?');
		const path = parts[0].split('/').filter(Boolean);
		const original = text.match(/[?&]q=([^&]*)/);
		const query = original ? original[1].replace(/\+/g, ' ') : null;
		const href = match[1] + (path.length ? '/' + path.join('/') : '') + (query !== null ? '/?q=' + query : '');
		return { kind: 'site', domain: match[1], path: path, query: query, href: href };
	}

	window.CoeOnion = window.CoeOnion || {};
	Object.assign(window.CoeOnion, {
		el: el, button: button, input: input, textarea: textarea, select: select, field: field, when: when, ago: ago, line: line, card: card,
		link: link, parse: parse, errors: ERRORS, sites: window.CoeOnion.sites || {}
	});

	const ABOUT = {
		rede: 'Rede', identidade: 'Identidade', mineracao: 'Mineração', computador: 'Computador', favoritos: 'Favoritos', historico: 'Histórico'
	};

	host.register('onion', function (root, api) {
		let data = null;
		let bookmarks = [];
		let busy = false;
		let confirmUninstall = false;
		let tabs = [];
		let active = 0;
		let tabSeq = 0;
		let visits = [];
		let renderSeq = 0;

		function errorText(code) { return ERRORS[code] || api.errorText(code); }

		// Chamada ao servidor. Erro vira aviso na barra (a página decide o que mostrar).
		function call(action, payload) {
			return api.call('onion', action, payload || {}).then(function (result) {
				return result || { ok: false, error: 'closed' };
			});
		}

		function request(action, payload, onDone, message) {
			if (busy) { return; }
			busy = true;
			call(action, payload).then(function (result) {
				busy = false;
				if (!result.ok) {
					api.status(errorText(result.error), 'error');
					return;
				}
				if (message) { api.status(message, 'success'); }
				if (onDone) { onDone(result); }
			});
		}

		function loadState() {
			return call('state').then(function (result) {
				if (result.ok) { data = result; }
				return result;
			});
		}

		function loadBookmarks() {
			return call('bookmarks').then(function (result) {
				if (result.ok) { bookmarks = result.bookmarks || []; }
				paintChrome();
			});
		}

		// Abas e histórico --------------------------------------------------------------------------------

		function current() { return tabs[active]; }
		function currentAddress() { const tab = current(); return tab ? tab.history[tab.index] : null; }

		function newTab(address) {
			if (tabs.length >= ((data && data.browser && data.browser.maxTabs) || 4)) {
				api.status('Abas demais abertas.', 'error');
				return;
			}
			tabSeq += 1;
			tabs.push({ id: tabSeq, history: [], index: -1, title: 'Nova aba' });
			active = tabs.length - 1;
			go(address || home());
		}

		function closeTab(index) {
			if (tabs.length <= 1) { return; }
			tabs.splice(index, 1);
			if (active >= tabs.length) { active = tabs.length - 1; }
			render();
		}

		function home() { return (data && data.browser && data.browser.home) || 'duckdark.onion'; }

		function go(address) {
			const target = parse(address);
			if (!target) { return; }
			const tab = current();
			tab.history = tab.history.slice(0, tab.index + 1);
			tab.history.push(target.href);
			tab.index = tab.history.length - 1;
			visits.unshift({ address: target.href, at: Math.floor(Date.now() / 1000) });
			visits = visits.slice(0, 50);
			render();
		}

		// Troca o endereço da página atual sem criar entrada no histórico (filtros, ordenação).
		function replace(address) {
			const target = parse(address);
			const tab = current();
			if (!target || !tab) { return; }
			tab.history[tab.index] = target.href;
			render();
		}

		function back() { const tab = current(); if (tab.index > 0) { tab.index -= 1; render(); } }
		function forward() { const tab = current(); if (tab.index < tab.history.length - 1) { tab.index += 1; render(); } }

		// Moldura do navegador ------------------------------------------------------------------------------

		const chrome = el('div', 'ob-chrome');
		const tabStrip = el('div', 'ob-tabs');
		const bar = el('div', 'ob-bar');
		const backButton = el('button', 'ob-nav', '‹');
		const forwardButton = el('button', 'ob-nav', '›');
		const reloadButton = el('button', 'ob-nav', '⟳');
		const homeButton = el('button', 'ob-nav', '⌂');
		const addressBox = el('div', 'ob-address');
		const lock = el('span', 'ob-lock');
		const address = el('input', 'ob-address-input');
		const starButton = el('button', 'ob-nav ob-star', '☆');
		const menuButton = el('button', 'ob-nav', '≡');
		const menu = el('div', 'ob-menu');
		const view = el('div', 'ob-view');
		const content = el('div', 'ob-page');
		[backButton, forwardButton, reloadButton, homeButton, starButton, menuButton].forEach(function (node) { node.type = 'button'; });
		backButton.title = 'Voltar'; forwardButton.title = 'Avançar'; reloadButton.title = 'Recarregar'; homeButton.title = 'Início';
		starButton.title = 'Favoritar'; menuButton.title = 'Menu';
		address.spellcheck = false;
		address.autocomplete = 'off';
		address.placeholder = 'Busque no DuckDark ou digite um endereço .onion';
		addressBox.append(lock, address);
		bar.append(backButton, forwardButton, reloadButton, homeButton, addressBox, starButton, menuButton);
		chrome.append(tabStrip, bar);
		menu.hidden = true;
		view.append(content, menu);

		backButton.addEventListener('click', back);
		forwardButton.addEventListener('click', forward);
		reloadButton.addEventListener('click', function () { render(); });
		homeButton.addEventListener('click', function () { go(home()); });
		address.addEventListener('keydown', function (event) {
			if (event.key === 'Enter') { event.preventDefault(); go(address.value); address.blur(); }
		});
		address.addEventListener('focus', function () { address.select(); });
		starButton.addEventListener('click', toggleBookmark);
		menuButton.addEventListener('click', function () { menu.hidden = !menu.hidden; if (!menu.hidden) { paintMenu(); } });

		function isBookmarked(href) {
			return bookmarks.some(function (entry) { return entry.address === href; });
		}

		function toggleBookmark() {
			const href = currentAddress();
			if (!href) { return; }
			if (isBookmarked(href)) {
				request('bookmarkRemove', { address: href }, function () { loadBookmarks(); }, 'Removido dos favoritos.');
			} else {
				request('bookmarkAdd', { address: href, title: current().title }, function () { loadBookmarks(); }, 'Adicionado aos favoritos.');
			}
		}

		function paintMenu() {
			menu.replaceChildren();
			const entries = [['about:favoritos', 'Favoritos'], ['about:historico', 'Histórico'], ['about:rede', 'Rede e equipamento'], ['about:identidade', 'Identidade']];
			if (data && data.rig) { entries.push(['about:mineracao', 'Mineração']); }
			if (data && data.computer) { entries.push(['about:computador', 'Computador']); }
			const add = el('button', 'ob-menu-item', '+ Nova aba');
			add.type = 'button';
			add.addEventListener('click', function () { menu.hidden = true; newTab(); });
			menu.appendChild(add);
			entries.forEach(function (entry) {
				const item = el('button', 'ob-menu-item', entry[1]);
				item.type = 'button';
				item.addEventListener('click', function () { menu.hidden = true; go(entry[0]); });
				menu.appendChild(item);
			});
			if (bookmarks.length) {
				menu.appendChild(el('span', 'ob-menu-label', 'Favoritos'));
				bookmarks.slice(0, 8).forEach(function (entry) {
					const item = el('button', 'ob-menu-item', entry.title || entry.address);
					item.type = 'button';
					item.title = entry.address;
					item.addEventListener('click', function () { menu.hidden = true; go(entry.address); });
					menu.appendChild(item);
				});
			}
		}

		function paintChrome() {
			const tab = current();
			const href = currentAddress() || '';
			tabStrip.replaceChildren();
			tabs.forEach(function (entry, index) {
				const node = el('div', 'ob-tab' + (index === active ? ' is-active' : ''));
				const label = el('span', 'ob-tab-title', entry.title || 'Nova aba');
				node.appendChild(label);
				node.addEventListener('click', function () { if (active !== index) { active = index; render(); } });
				if (tabs.length > 1) {
					const close = el('button', 'ob-tab-close', '×');
					close.type = 'button';
					close.title = 'Fechar aba';
					close.addEventListener('click', function (event) { event.stopPropagation(); closeTab(index); });
					node.appendChild(close);
				}
				tabStrip.appendChild(node);
			});
			const plus = el('button', 'ob-tab-new', '+');
			plus.type = 'button';
			plus.title = 'Nova aba';
			plus.addEventListener('click', function () { newTab(); });
			tabStrip.appendChild(plus);
			if (document.activeElement !== address) { address.value = href; }
			backButton.disabled = !tab || tab.index <= 0;
			forwardButton.disabled = !tab || tab.index >= tab.history.length - 1;
			const target = parse(href);
			lock.textContent = target && target.kind === 'about' ? 'ⓘ' : '◉';
			lock.title = target && target.kind === 'about' ? 'Página do navegador' : 'Circuito de 3 saltos · conexão anônima';
			starButton.textContent = isBookmarked(href) ? '★' : '☆';
			starButton.classList.toggle('is-on', isBookmarked(href));
		}

		// Contexto entregue a cada página.
		function context(target, seq) {
			const tab = current();
			return {
				target: target, api: api, data: data, call: call, request: request, go: go, replace: replace, errorText: errorText,
				newTab: newTab,
				alive: function () { return seq === renderSeq; },
				setTitle: function (title) { tab.title = String(title || '').slice(0, 40) || target.href; paintChrome(); },
				refresh: function () { if (seq === renderSeq) { render(); } },
				reloadState: function () { return loadState().then(function () { if (seq === renderSeq) { render(); } }); },
				status: api.status,
				waypoint: function (x, y) {
					if (typeof api.waypoint !== 'function') { api.status('GPS indisponível neste aparelho.', 'error'); return; }
					api.waypoint(x, y).then(function () { api.status('Ponto marcado no GPS.', 'success'); });
				}
			};
		}

		// Página de erro de serviço oculto (endereço que não existe ou fora do ar).
		function unreachable(page, href) {
			page.className = 'ob-page ob-error-page';
			const box = el('div', 'ob-error');
			box.append(el('i', 'ob-error-icon'), el('h2', null, 'Não foi possível alcançar o serviço oculto'),
				el('p', 'tb-muted', 'O endereço ' + href + ' pode estar fora do ar, ter mudado de lugar ou nunca ter existido.'),
				el('p', 'tb-muted', 'Confira o endereço ou procure no DuckDark.'));
			const actions = el('div', 'tb-actions');
			actions.append(button('Buscar no DuckDark', 'coe-button--primary', function () { go('duckdark.onion'); }));
			box.appendChild(actions);
			page.appendChild(box);
		}

		function render() {
			renderSeq += 1;
			const seq = renderSeq;
			menu.hidden = true;
			const href = currentAddress();
			const target = parse(href);
			content.replaceChildren();
			content.className = 'ob-page';
			content.scrollTop = 0;
			view.scrollTop = 0;
			paintChrome();
			if (!target) { return; }
			const ctx = context(target, seq);
			if (target.kind === 'about') {
				const page = ABOUT[target.page];
				if (!page) { unreachable(content, href); ctx.setTitle('Erro'); return; }
				ctx.setTitle(page);
				content.classList.add('ob-about');
				aboutPages[target.page](content, ctx);
				return;
			}
			content.appendChild(el('p', 'tb-empty dw-connecting', 'Montando circuito…'));
			sitesReady.then(function () { return call('site', { address: href }); }).then(function (result) {
				if (seq !== renderSeq) { return; }
				content.replaceChildren();
				if (!result.ok) {
					if (result.error === 'not_found') { ctx.setTitle('Erro'); unreachable(content, target.domain); return; }
					content.appendChild(el('p', 'tb-empty', errorText(result.error)));
					return;
				}
				const site = result.site;
				const renderers = window.CoeOnion.sites || {};
				const renderer = renderers[site.app || 'blocks'];
				ctx.site = site;
				ctx.setTitle(site.title);
				content.classList.add('ob-site', 'ob-site--' + (site.app || 'blocks'));
				if (!renderer) { content.appendChild(el('p', 'tb-empty', 'Este site não abriu no seu navegador.')); return; }
				renderer(content, ctx);
			});
		}

		// Páginas internas (about:) -----------------------------------------------------------------------

		function tierHeader() {
			const box = el('div', 'dw-head');
			const brand = el('div', 'dw-brand');
			brand.append(el('i', 'dw-onion'), el('strong', null, 'onion'), el('span', 'tb-muted', 'circuito: 3 saltos · conexão anônima'));
			const tier = el('div', 'dw-tier');
			const meter = el('div', 'dw-levels');
			(data.tiers || []).forEach(function (entry) {
				const step = el('span', 'dw-level' + (entry.level <= data.tier.level ? ' is-on' : ''), entry.level);
				step.title = entry.label;
				meter.appendChild(step);
			});
			tier.append(el('span', 'tb-muted', 'Equipamento'), el('strong', null, data.tier.label + ' · nível ' + data.tier.level), meter);
			box.append(brand, tier);
			if (data.handle) {
				box.appendChild(el('span', 'coe-badge tb-badge--accent dw-handle', '@' + data.handle.name));
			}
			return box;
		}

		const FEATURE_LINKS = {
			identity: 'about:identidade', search: 'duckdark.onion', forum: 'rabbit.onion', forum_create: 'rabbit.onion/criar',
			market_browse: 'deepmarket.onion', market_buy: 'deepmarket.onion', market_sell: 'deepmarket.onion/painel', mining: 'about:mineracao', burn: 'about:computador'
		};

		const aboutPages = {
			rede: function (body, ctx) {
				body.appendChild(tierHeader());
				body.appendChild(el('p', 'tb-muted', 'Quanto melhor o equipamento, mais da rede se abre. Celular e tablet navegam; notebook, desktop e servidor doméstico liberam o resto.'));
				const grid = el('div', 'dw-features');
				data.features.forEach(function (feature) {
					const box = el('div', 'dw-feature is-' + feature.state);
					const head = el('div', 'tb-card-head');
					head.append(el('strong', null, feature.label), el('span', 'coe-badge ' + (feature.state === 'open' ? 'coe-badge--success' : 'tb-badge--warn'),
						STATES[feature.state] + (feature.state === 'locked' ? ' · nível ' + feature.level : '')));
					box.append(head, el('span', 'tb-muted', feature.description || ''));
					const target = FEATURE_LINKS[feature.id];
					const needsRig = feature.id === 'mining' || feature.id === 'burn';
					if (feature.state === 'open' && target && (!needsRig || data.rig)) {
						box.classList.add('is-link');
						box.addEventListener('click', function () { ctx.go(target); });
					}
					grid.appendChild(box);
				});
				body.appendChild(grid);
			},
			identidade: function (body, ctx) { identity(body, ctx); },
			mineracao: function (body, ctx) { mining(body, ctx); },
			computador: function (body, ctx) { device(body, ctx); },
			favoritos: function (body, ctx) {
				body.appendChild(el('h2', 'ob-about-title', 'Favoritos'));
				if (!bookmarks.length) {
					body.appendChild(el('p', 'tb-empty', 'Nenhum favorito. Use a estrela na barra de endereço.'));
					return;
				}
				const list = el('div', 'ob-list');
				bookmarks.forEach(function (entry) {
					const row = el('div', 'ob-row');
					const text = el('div', 'ob-row-text');
					text.append(link(entry.title || entry.address, entry.address, 'ob-row-title', ctx.go), el('small', 'tb-muted', entry.address));
					row.append(text, button('Remover', 'coe-button--danger', function () {
						request('bookmarkRemove', { address: entry.address }, function () { loadBookmarks().then(ctx.refresh); });
					}));
					list.appendChild(row);
				});
				body.appendChild(list);
				body.appendChild(el('p', 'tb-muted', 'Os favoritos ficam neste aparelho: quem usar o aparelho vê.'));
			},
			historico: function (body, ctx) {
				body.appendChild(el('h2', 'ob-about-title', 'Histórico'));
				body.appendChild(el('p', 'tb-muted', 'Só desta sessão. Ao fechar o navegador, tudo é apagado.'));
				if (!visits.length) { body.appendChild(el('p', 'tb-empty', 'Nada por aqui.')); return; }
				const list = el('div', 'ob-list');
				visits.forEach(function (entry) {
					const row = el('div', 'ob-row');
					row.append(link(entry.address, entry.address, 'ob-row-title', ctx.go), el('small', 'tb-muted', ago(entry.at)));
					list.appendChild(row);
				});
				body.appendChild(list);
				body.appendChild(el('div', 'tb-actions')).appendChild(button('Limpar histórico', '', function () { visits = []; ctx.refresh(); }));
			}
		};

		function identity(body, ctx) {
			body.appendChild(tierHeader());
			if (data.handle) {
				const box = card();
				const head = el('div', 'tb-card-head');
				head.append(el('strong', null, '@' + data.handle.name), el('span', 'coe-badge tb-badge--accent', 'Conectado'));
				box.appendChild(head);
				const lines = el('div', 'tb-lines');
				lines.append(line('Na rede desde', when(data.handle.createdAt)), line('Reputação no Deep Market', String(data.handle.reputation || 0)));
				box.appendChild(lines);
				box.appendChild(el('p', 'tb-muted', 'O apelido fica conectado neste aparelho. Quem usar o aparelho entra como você.'));
				const actions = el('div', 'tb-actions');
				actions.append(button('Meu perfil no Rabbit', '', function () { ctx.go('rabbit.onion/u/' + data.handle.name); }),
					button('Sair deste aparelho', 'coe-button--danger', function () {
						request('handleLogout', {}, function () { ctx.reloadState(); }, 'Apelido desconectado.');
					}));
				box.appendChild(actions);
				body.appendChild(box);

				const pass = card('dw-form');
				pass.appendChild(el('strong', null, 'Trocar senha'));
				const currentPass = input('Senha atual', 'password');
				const next = input('Nova senha', 'password');
				pass.append(field('Atual', currentPass), field('Nova', next));
				pass.appendChild(el('div', 'tb-actions')).appendChild(button('Salvar', 'coe-button--primary', function () {
					request('handlePassword', { current: currentPass.value, new: next.value }, function () { ctx.reloadState(); }, 'Senha trocada. Outros aparelhos foram desconectados.');
				}));
				body.appendChild(pass);
				return;
			}
			const grid = el('div', 'tb-grid');
			const login = card('dw-form');
			login.appendChild(el('strong', null, 'Entrar'));
			const name = input('apelido');
			const password = input('senha', 'password');
			login.append(field('Apelido', name), field('Senha', password));
			login.appendChild(el('div', 'tb-actions')).appendChild(button('Entrar', 'coe-button--primary', function () {
				request('handleLogin', { name: name.value, password: password.value }, function () { ctx.reloadState(); }, 'Conectado.');
			}));
			grid.appendChild(login);

			const create = card('dw-form');
			create.appendChild(el('strong', null, 'Novo apelido'));
			if (!data.canCreate) {
				create.appendChild(el('p', 'tb-muted', 'Você já criou ' + data.limits.MaxPerCharacter + ' apelidos.'));
			} else {
				const newName = input(data.limits.Min + ' a ' + data.limits.Max + ' caracteres');
				const newPassword = input('mínimo ' + data.limits.PasswordMin + ' caracteres', 'password');
				create.append(field('Apelido', newName), field('Senha', newPassword));
				create.appendChild(el('p', 'tb-muted', 'Ninguém na rede vê quem está por trás do apelido. Esqueceu a senha? Quem criou redefine em "Meus apelidos".'));
				create.appendChild(el('div', 'tb-actions')).appendChild(button('Criar', 'coe-button--primary', function () {
					request('handleCreate', { name: newName.value, password: newPassword.value }, function () { ctx.reloadState(); }, 'Apelido criado e conectado.');
				}));
			}
			grid.appendChild(create);
			body.appendChild(grid);

			if ((data.ownedNames || []).length) {
				const mine = card('dw-form');
				mine.appendChild(el('strong', null, 'Meus apelidos'));
				mine.appendChild(el('p', 'tb-muted', 'Esqueceu a senha? Quem criou o apelido define outra aqui; ele sai dos outros aparelhos e entra neste.'));
				const list = el('div', 'tb-chips');
				const resetName = input('apelido');
				(data.ownedNames || []).forEach(function (handle) {
					list.appendChild(button('@' + handle, '', function () { resetName.value = handle; }));
				});
				const resetPassword = input('nova senha', 'password');
				mine.append(list, field('Apelido', resetName), field('Nova senha', resetPassword));
				mine.appendChild(el('div', 'tb-actions')).appendChild(button('Redefinir senha e entrar', '', function () {
					request('handleReset', { name: resetName.value, password: resetPassword.value }, function () { ctx.reloadState(); }, 'Senha redefinida. Conectado.');
				}));
				body.appendChild(mine);
			}
		}

		function mining(body, ctx) {
			const rig = data.rig;
			if (!rig) {
				body.appendChild(el('p', 'tb-empty', 'Mineração só em desktop ou servidor instalado num imóvel.'));
				return;
			}
			const box = card();
			const head = el('div', 'tb-card-head');
			head.append(el('strong', null, 'Mineração · ' + rig.serial),
				el('span', 'coe-badge ' + (rig.mining && rig.lastStatus === 'ok' ? 'coe-badge--success' : 'tb-badge--warn'),
					rig.mining ? (MINING[rig.lastStatus] || rig.lastStatus) : MINING.off));
			box.appendChild(head);
			const lines = el('div', 'tb-lines');
			lines.append(
				line('Poder', rig.hash + ' H'),
				line('Energia por rodada', '$ ' + Number(rig.powerCost).toLocaleString('pt-BR') + ' (do banco de quem instalou)'),
				line('Rodada', 'a cada ' + rig.tickMinutes + ' min'),
				line('Última rodada', rig.lastTickAt ? when(rig.lastTickAt) + ' · ' + (rig.lastPayoutText || rig.lastPayout) : '-'),
				line('Total minerado', rig.minedText || String(rig.minedTotal))
			);
			box.appendChild(lines);
			const wallet = input('Carteira que recebe (nx…)');
			wallet.value = rig.payout || '';
			box.appendChild(field('Carteira', wallet));
			box.appendChild(el('p', 'tb-muted', 'Qualquer endereço da rede. Copie o seu no app Carteira.'));
			const actions = el('div', 'tb-actions');
			actions.append(
				button('Salvar carteira', '', function () {
					request('mining', { address: wallet.value, enabled: rig.mining }, function () { ctx.reloadState(); }, 'Carteira salva.');
				}),
				button(rig.mining ? 'Desligar' : 'Ligar', rig.mining ? 'coe-button--danger' : 'coe-button--primary', function () {
					request('mining', { address: wallet.value, enabled: !rig.mining }, function () { ctx.reloadState(); }, rig.mining ? 'Mineração desligada.' : 'Mineração ligada.');
				})
			);
			box.appendChild(actions);
			body.appendChild(box);
		}

		function device(body, ctx) {
			const info = data.computer;
			if (!info) { body.appendChild(el('p', 'tb-empty', 'Só nos computadores (notebook, desktop e servidor).')); return; }
			const box = card('dw-form');
			box.appendChild(el('strong', null, info.hasPassword ? 'Senha do computador' : 'Proteger com senha'));
			box.appendChild(el('p', 'tb-muted', 'A senha fica no aparelho (série ' + info.serial + '). Sem ela, ninguém usa o computador, nem as carteiras guardadas nele.'));
			const currentPass = input('Senha atual', 'password');
			const next = input('Nova senha (vazio remove)', 'password');
			if (info.hasPassword) { box.appendChild(field('Atual', currentPass)); }
			box.appendChild(field('Nova', next));
			box.appendChild(el('div', 'tb-actions')).appendChild(button('Salvar', 'coe-button--primary', function () {
				request('devicePassword', { current: currentPass.value, new: next.value }, function (result) {
					api.status(result.hasPassword ? 'Senha definida.' : 'Senha removida.', 'success');
					ctx.reloadState();
				});
			}));
			body.appendChild(box);
			if (info.hasPassword) {
				const faceBox = card('dw-form');
				const head = el('div', 'tb-card-head');
				head.append(el('strong', null, 'Reconhecimento facial'),
					el('span', 'coe-badge ' + (info.face ? 'coe-badge--success' : 'tb-badge--warn'), info.face ? 'Ligado' : 'Desligado'));
				faceBox.appendChild(head);
				faceBox.appendChild(el('p', 'tb-muted', info.face
					? (info.faceMine ? 'Seu rosto abre este computador sem senha. Outra pessoa precisa da senha.' : 'Cadastrado com o rosto de outra pessoa. Ligue de novo para usar o seu.')
					: 'Ao ligar, o seu rosto passa a abrir o computador sem digitar a senha. Outra pessoa continua precisando da senha.'));
				faceBox.appendChild(el('div', 'tb-actions')).appendChild(button(info.face && info.faceMine ? 'Desligar' : 'Cadastrar meu rosto',
					info.face && info.faceMine ? 'coe-button--danger' : 'coe-button--primary', function () {
						const enable = !(info.face && info.faceMine);
						request('deviceFace', { enabled: enable }, function () { ctx.reloadState(); }, enable ? 'Rosto cadastrado.' : 'Reconhecimento facial desligado.');
					}));
				body.appendChild(faceBox);
			}
			if (data.rig) {
				const benchBox = card('dw-form');
				benchBox.appendChild(el('strong', null, 'Bancada'));
				benchBox.appendChild(el('p', 'tb-muted', 'Grave o navegador onion num pen drive vazio (usb_black) para vender ou entregar. O computador fecha e a bancada abre aqui mesmo.'));
				benchBox.appendChild(el('div', 'tb-actions')).appendChild(button('Abrir bancada', 'coe-button--primary', function () {
					request('workbench', {});
				}));
				body.appendChild(benchBox);
				const rigBox = card('dw-form');
				rigBox.appendChild(el('strong', null, 'Desmontar'));
				rigBox.appendChild(el('p', 'tb-muted', 'A máquina volta para o seu inventário com a mesma série: senha, carteiras e apelido conectado vão junto.'));
				rigBox.appendChild(el('div', 'tb-actions')).appendChild(button(confirmUninstall ? 'Confirmar: desmontar' : 'Desmontar', 'coe-button--danger', function () {
					if (!confirmUninstall) { confirmUninstall = true; ctx.refresh(); return; }
					confirmUninstall = false;
					request('uninstall', {}, function () { api.status('Máquina desmontada.', 'success'); });
				}));
				body.appendChild(rigBox);
			}
		}

		// Início ----------------------------------------------------------------------------------------

		root.replaceChildren(el('p', 'tb-empty dw-connecting', 'Montando circuito…'));
		root.classList.add('dw-app', 'ob-app');
		loadState().then(function (result) {
			if (!result.ok) {
				root.replaceChildren(el('p', 'tb-empty', errorText(result.error)));
				return;
			}
			root.replaceChildren(chrome, view);
			newTab(home());
			loadBookmarks();
		});
	});
})();
