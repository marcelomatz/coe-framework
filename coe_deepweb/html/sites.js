// Telas dos sites da rede onion (coe_deepweb): DuckDark (search), Rabbit (forum), Deep Market (market), perfis da
// staff (profile) e sites por blocos (blocks). O navegador (deepweb.js) carrega este arquivo e chama window.CoeOnion.sites[app](page, ctx).
// Todo conteúdo vindo do servidor é escrito com textContent (nada de HTML de jogador ou da staff chega à NUI).
(function () {
	'use strict';

	const O = window.CoeOnion = window.CoeOnion || {};
	O.sites = O.sites || {};

	if (!document.querySelector('link[data-coe-deepweb="sites"]')) {
		const sheet = document.createElement('link');
		sheet.rel = 'stylesheet';
		sheet.href = 'nui://coe_deepweb/html/sites.css';
		sheet.dataset.coeDeepweb = 'sites';
		document.head.appendChild(sheet);
	}

	// Utilitários do navegador (deepweb.js). Resolvidos na hora do uso: este arquivo pode carregar antes.
	function el(tag, className, text) { return O.el(tag, className, text); }
	function button(label, className, onClick) { return O.button(label, className, onClick); }

	function paragraphs(text, className) {
		const box = el('div', 'ob-text ' + (className || ''));
		String(text || '').split(/\n{2,}/).forEach(function (chunk) {
			if (chunk.trim()) { box.appendChild(el('p', null, chunk.trim())); }
		});
		return box;
	}

	function badge(text, tone) { return el('span', 'coe-badge ' + (tone || ''), text); }

	function stars(value) {
		const rounded = Math.max(0, Math.min(5, Math.round(Number(value) || 0)));
		return '★★★★★'.slice(0, rounded) + '☆☆☆☆☆'.slice(0, 5 - rounded);
	}

	function signedOut(ctx, text) {
		const box = el('div', 'ob-hint');
		box.append(el('span', null, (text || 'Entre com um apelido para participar.') + ' '), O.link('Abrir identidade', 'about:identidade', '', ctx.go));
		return box;
	}

	function notFound(page, text) {
		page.appendChild(el('p', 'tb-empty', text || 'Página não encontrada neste serviço.'));
	}

	// Chama a ação e desenha quando voltar (se a página ainda for a mesma).
	function load(target, ctx, action, payload, draw) {
		const wait = el('p', 'tb-empty dw-connecting', 'Carregando…');
		target.appendChild(wait);
		ctx.call(action, payload).then(function (result) {
			if (!ctx.alive()) { return; }
			wait.remove();
			if (!result.ok) {
				if (result.error === 'not_found') { notFound(target); return; }
				if (result.error === 'not_signed_in') { target.appendChild(signedOut(ctx)); return; }
				target.appendChild(el('p', 'tb-empty', ctx.errorText(result.error)));
				return;
			}
			draw(result);
		});
	}

	// Botão de duas etapas para ações destrutivas.
	function confirmButton(label, confirmLabel, onConfirm) {
		let armed = false;
		const node = button(label, 'coe-button--danger', function () {
			if (!armed) { armed = true; node.textContent = confirmLabel; return; }
			armed = false;
			node.textContent = label;
			onConfirm();
		});
		return node;
	}

	function onEnter(node, action) {
		node.addEventListener('keydown', function (event) { if (event.key === 'Enter') { event.preventDefault(); action(); } });
	}

	// DuckDark ----------------------------------------------------------------------------------------------

	O.sites.search = function (page, ctx) {
		const query = ctx.target.query;
		const head = el('div', 'dd-head' + (query ? ' is-compact' : ''));
		const logo = el('a', 'dd-logo');
		logo.href = '#';
		logo.append(el('i', 'dd-duck'), el('strong', null, 'DuckDark'));
		logo.addEventListener('click', function (event) { event.preventDefault(); ctx.go('duckdark.onion'); });
		const bar = el('div', 'dd-search');
		const box = O.input('Buscar na rede oculta');
		box.value = query || '';
		function submit() {
			const text = box.value.trim();
			if (text.length < 2 || text.length > 40) { ctx.status(O.errors.invalid_query, 'error'); return; }
			ctx.go('duckdark.onion/?q=' + text);
		}
		onEnter(box, submit);
		bar.append(box, button('Buscar', 'coe-button--primary', submit));
		head.append(logo, bar);
		if (!query) { head.appendChild(el('span', 'tb-muted', 'Sem rastros. Só o que existe nesta rede.')); }
		page.appendChild(head);
		const body = el('div', 'dd-body');
		page.appendChild(body);

		if (!query) {
			load(body, ctx, 'directory', {}, function (result) {
				body.appendChild(el('h3', 'dd-section', 'Diretório'));
				if (!result.sites.length) { body.appendChild(el('p', 'tb-empty', 'Nenhum site no ar.')); return; }
				result.sites.forEach(function (site) { body.appendChild(siteResult(site, ctx)); });
			});
			setTimeout(function () { if (ctx.alive()) { box.focus(); } }, 0);
			return;
		}
		ctx.setTitle(query + ' · DuckDark');
		load(body, ctx, 'search', { q: query }, function (result) {
			const total = result.sites.length + result.posts.length + result.listings.length;
			body.appendChild(el('p', 'tb-muted', total ? total + ' resultado(s) para "' + result.query + '"' : 'Nada encontrado para "' + result.query + '".'));
			if (result.sites.length) {
				body.appendChild(el('h3', 'dd-section', 'Sites'));
				result.sites.forEach(function (site) { body.appendChild(siteResult(site, ctx)); });
			}
			if (result.posts.length) {
				body.appendChild(el('h3', 'dd-section', 'No Rabbit'));
				result.posts.forEach(function (post) {
					const href = 'rabbit.onion/r/' + post.community + '/' + post.id;
					body.appendChild(result_(post.title, href, 'r/' + post.community + ' · u/' + post.author + ' · ' + post.score + ' pontos · ' + post.comments + ' comentários', post.body, ctx));
				});
			}
			if (result.listings.length) {
				body.appendChild(el('h3', 'dd-section', 'No Deep Market'));
				result.listings.forEach(function (listing) {
					const seller = listing.npc ? 'fornecedor ' + (listing.seller || '') : '@' + listing.seller;
					body.appendChild(result_(listing.title, 'deepmarket.onion/a/' + listing.id, listing.priceText + ' · ' + seller, listing.description, ctx));
				});
			}
		});
	};

	function siteResult(site, ctx) {
		return result_(site.title, site.domain, null, site.description, ctx);
	}

	function result_(title, href, meta, text, ctx) {
		const row = el('div', 'dd-result');
		row.append(O.link(title, href, 'dd-result-title', ctx.go), el('small', 'dd-result-url', href));
		if (meta) { row.appendChild(el('small', 'tb-muted', meta)); }
		if (text) { row.appendChild(el('p', 'dd-result-text', text)); }
		return row;
	}

	// Rabbit ------------------------------------------------------------------------------------------------

	const SORTS = [['hot', 'Em alta'], ['new', 'Novos'], ['top', 'Top']];

	O.sites.forum = function (page, ctx) {
		const path = ctx.target.path || [];
		const me = ctx.data && ctx.data.handle ? ctx.data.handle.name : null;
		const head = el('div', 'rb-head');
		const brand = el('a', 'rb-brand');
		brand.href = '#';
		brand.append(el('i', 'rb-logo'), el('strong', null, 'rabbit'));
		brand.addEventListener('click', function (event) { event.preventDefault(); ctx.go('rabbit.onion'); });
		const nav = el('div', 'rb-nav');
		nav.appendChild(me ? O.link('u/' + me, 'rabbit.onion/u/' + me, 'rb-me', ctx.go) : O.link('Entrar', 'about:identidade', 'rb-me', ctx.go));
		head.append(brand, nav);
		page.appendChild(head);
		const body = el('div', 'rb-body');
		page.appendChild(body);

		if (path.length === 0 || (path.length === 1 && (path[0] === 'new' || path[0] === 'top'))) {
			forumHome(body, ctx, path[0] || 'hot', me);
		} else if (path.length === 1 && path[0] === 'criar') {
			forumCreate(body, ctx, me);
		} else if (path[0] === 'r' && path[1]) {
			const third = path[2];
			if (!third || third === 'new' || third === 'top') { forumCommunity(body, ctx, path[1], third || 'hot', me); }
			else if (third === 'enviar') { forumSubmit(body, ctx, path[1], me); }
			else if (/^\d+$/.test(third)) { forumPost(body, ctx, Number(third), me); }
			else { notFound(body); }
		} else if (path[0] === 'p' && /^\d+$/.test(path[1] || '')) {
			forumPost(body, ctx, Number(path[1]), me);
		} else if (path[0] === 'u' && path[1]) {
			forumUser(body, ctx, path[1]);
		} else {
			notFound(body);
		}
	};

	function sortTabs(base, sort, ctx) {
		const tabs = el('div', 'rb-sorts');
		SORTS.forEach(function (entry) {
			const node = O.link(entry[1], base + (entry[0] === 'hot' ? '' : '/' + entry[0]), 'rb-sort' + (entry[0] === sort ? ' is-active' : ''), ctx.replace);
			tabs.appendChild(node);
		});
		return tabs;
	}

	// Votos: ▲ pontuação ▼. Sem apelido, o servidor recusa (not_signed_in).
	function voter(target, entry, ctx) {
		const box = el('div', 'rb-vote');
		const up = el('button', 'rb-arrow rb-up', '▲');
		const score = el('span', 'rb-score');
		const down = el('button', 'rb-arrow rb-down', '▼');
		up.type = 'button';
		down.type = 'button';
		function paint() {
			score.textContent = String(entry.score || 0);
			up.classList.toggle('is-on', entry.vote === 1);
			down.classList.toggle('is-on', entry.vote === -1);
			box.classList.toggle('is-up', entry.vote === 1);
			box.classList.toggle('is-down', entry.vote === -1);
		}
		function vote(value) {
			const next = entry.vote === value ? 0 : value;
			ctx.request('forumVote', { target: target, id: entry.id, value: next }, function (result) {
				entry.score = (entry.score || 0) + (result.delta || 0);
				entry.vote = result.vote;
				paint();
			});
		}
		up.addEventListener('click', function () { vote(1); });
		down.addEventListener('click', function () { vote(-1); });
		box.append(up, score, down);
		paint();
		return box;
	}

	function postRow(post, ctx, options) {
		const row = el('div', 'rb-post');
		const main = el('div', 'rb-post-main');
		const meta = el('div', 'rb-meta');
		if (!options || !options.hideCommunity) {
			meta.append(O.link('r/' + post.community, 'rabbit.onion/r/' + post.community, 'rb-community', ctx.go), el('span', null, ' · '));
		}
		meta.append(O.link('u/' + post.author, 'rabbit.onion/u/' + post.author, 'rb-author', ctx.go), el('span', null, ' · ' + O.ago(post.createdAt)));
		main.append(meta, O.link(post.title, 'rabbit.onion/r/' + post.community + '/' + post.id, 'rb-post-title', ctx.go));
		if (post.body) { main.appendChild(el('p', 'rb-excerpt', post.body)); }
		const foot = el('div', 'rb-foot');
		foot.appendChild(O.link((post.comments || 0) + ' comentário(s)', 'rabbit.onion/r/' + post.community + '/' + post.id, 'rb-foot-link', ctx.go));
		if (options && options.moderating) {
			foot.appendChild(confirmButton('Remover', 'Confirmar remoção', function () {
				ctx.request('forumRemove', { target: 'p', id: post.id }, function () { row.remove(); }, 'Post removido.');
			}));
		}
		main.appendChild(foot);
		row.append(voter('p', post, ctx), main);
		return row;
	}

	// Lista paginada: "Carregar mais" pede a próxima página e acrescenta.
	function postList(container, ctx, action, payload, first, options) {
		const list = el('div', 'rb-posts');
		container.appendChild(list);
		function add(result) {
			if (!result.posts.length && payload.page === 1) { list.appendChild(el('p', 'tb-empty', 'Nenhum post ainda.')); }
			result.posts.forEach(function (post) { list.appendChild(postRow(post, ctx, options)); });
			if (result.more) {
				const more = button('Carregar mais', '', function () {
					more.remove();
					payload.page += 1;
					load(list, ctx, action, payload, add);
				});
				list.appendChild(more);
			}
		}
		add(first);
	}

	function forumHome(body, ctx, sort, me) {
		load(body, ctx, 'forumHome', { sort: sort, page: 1 }, function (result) {
			const grid = el('div', 'rb-grid');
			const main = el('div', 'rb-column');
			main.appendChild(sortTabs('rabbit.onion', result.sort || sort, ctx));
			postList(main, ctx, 'forumHome', { sort: result.sort || sort, page: 1 }, result);
			const side = el('div', 'rb-side');
			const about = O.card('rb-card');
			about.append(el('strong', null, 'Rabbit'), el('p', 'tb-muted', 'Comunidades anônimas da rede. Você posta pelo apelido, ninguém vê quem está por trás.'));
			if (result.canCreate) {
				about.appendChild(button('Criar comunidade', 'coe-button--primary', function () { ctx.go('rabbit.onion/criar'); }));
			}
			if (!me) { about.appendChild(signedOut(ctx, 'Para postar, votar e comentar, entre com um apelido.')); }
			side.appendChild(about);
			const communities = O.card('rb-card');
			communities.appendChild(el('strong', null, 'Comunidades'));
			(result.communities || []).forEach(function (community) {
				const row = el('div', 'rb-community-row');
				row.append(O.link('r/' + community.slug, 'rabbit.onion/r/' + community.slug, 'rb-community', ctx.go), el('small', 'tb-muted', community.posts + ' posts'));
				communities.appendChild(row);
			});
			side.appendChild(communities);
			grid.append(main, side);
			body.appendChild(grid);
		});
	}

	function forumCommunity(body, ctx, slug, sort, me) {
		load(body, ctx, 'forumCommunity', { slug: slug, sort: sort, page: 1 }, function (result) {
			const community = result.community;
			ctx.setTitle('r/' + community.slug);
			const banner = el('div', 'rb-banner');
			const text = el('div', 'rb-banner-text');
			text.append(el('h2', null, community.title), el('small', 'tb-muted', 'r/' + community.slug + ' · ' + community.posts + ' posts' +
				(community.moderator ? ' · moderada por u/' + community.moderator : '')));
			if (community.description) { text.appendChild(el('p', null, community.description)); }
			banner.appendChild(text);
			if (me) {
				banner.appendChild(button('Novo post', 'coe-button--primary', function () { ctx.go('rabbit.onion/r/' + community.slug + '/enviar'); }));
			}
			body.appendChild(banner);
			if (!me) { body.appendChild(signedOut(ctx, 'Para postar nesta comunidade, entre com um apelido.')); }
			if (result.moderating) { body.appendChild(el('div', 'ob-hint', 'Você modera esta comunidade: pode remover posts e comentários.')); }
			body.appendChild(sortTabs('rabbit.onion/r/' + community.slug, result.sort || sort, ctx));
			postList(body, ctx, 'forumCommunity', { slug: community.slug, sort: result.sort || sort, page: 1 }, result,
				{ hideCommunity: true, moderating: result.moderating });
		});
	}

	function forumSubmit(body, ctx, slug, me) {
		ctx.setTitle('Novo post · r/' + slug);
		if (!me) { body.appendChild(signedOut(ctx, 'Para postar, entre com um apelido.')); return; }
		const form = O.card('dw-form rb-form');
		const title = O.input('Título');
		const text = O.textarea('Texto (opcional)', 8);
		form.append(el('strong', null, 'Novo post em r/' + slug + ' como u/' + me), O.field('Título', title), O.field('Texto', text));
		const actions = el('div', 'tb-actions');
		actions.append(button('Cancelar', '', function () { ctx.go('rabbit.onion/r/' + slug); }), button('Publicar', 'coe-button--primary', function () {
			ctx.request('forumSubmit', { slug: slug, title: title.value, body: text.value }, function (result) {
				ctx.replace('rabbit.onion/r/' + result.slug + '/' + result.id);
			}, 'Post publicado.');
		}));
		form.appendChild(actions);
		body.appendChild(form);
	}

	function forumCreate(body, ctx, me) {
		ctx.setTitle('Criar comunidade · Rabbit');
		if (!me) { body.appendChild(signedOut(ctx, 'Para criar uma comunidade, entre com um apelido.')); return; }
		const form = O.card('dw-form rb-form');
		const slug = O.input('3 a 21 letras minúsculas, números ou sublinhado');
		const title = O.input('Nome de exibição');
		const description = O.textarea('Sobre o que é a comunidade', 3);
		form.append(el('strong', null, 'Nova comunidade'), el('p', 'tb-muted', 'Quem cria modera: pode remover posts e comentários da comunidade.'),
			O.field('Endereço (r/…)', slug), O.field('Título', title), O.field('Descrição', description));
		form.appendChild(el('div', 'tb-actions')).appendChild(button('Criar', 'coe-button--primary', function () {
			ctx.request('forumCreate', { slug: slug.value.trim().toLowerCase(), title: title.value, description: description.value }, function (result) {
				ctx.replace('rabbit.onion/r/' + result.slug);
			}, 'Comunidade criada.');
		}));
		body.appendChild(form);
	}

	function forumPost(body, ctx, id, me) {
		load(body, ctx, 'forumPost', { id: id }, function (result) {
			const post = result.post;
			ctx.setTitle(post.title);
			if (result.community) {
				const crumb = el('div', 'rb-meta');
				crumb.append(O.link('r/' + result.community.slug, 'rabbit.onion/r/' + result.community.slug, 'rb-community', ctx.go),
					el('span', 'tb-muted', ' · ' + result.community.title));
				body.appendChild(crumb);
			}
			const article = el('div', 'rb-post rb-post--full');
			const main = el('div', 'rb-post-main');
			const meta = el('div', 'rb-meta');
			meta.append(O.link('u/' + post.author, 'rabbit.onion/u/' + post.author, 'rb-author', ctx.go), el('span', null, ' · ' + O.when(post.createdAt)));
			main.append(meta, el('h2', 'rb-title', post.title));
			if (post.body) { main.appendChild(paragraphs(post.body, 'rb-text')); }
			const foot = el('div', 'rb-foot');
			foot.appendChild(el('span', 'tb-muted', (post.comments || 0) + ' comentário(s)'));
			if (post.canRemove) {
				foot.appendChild(confirmButton('Remover post', 'Confirmar remoção', function () {
					ctx.request('forumRemove', { target: 'p', id: post.id }, function () {
						ctx.replace('rabbit.onion/r/' + post.community);
					}, 'Post removido.');
				}));
			}
			main.appendChild(foot);
			article.append(voter('p', post, ctx), main);
			body.appendChild(article);

			if (me) {
				body.appendChild(commentForm(ctx, post.id, null, 'Comentar como u/' + me));
			} else {
				body.appendChild(signedOut(ctx, 'Para comentar, entre com um apelido.'));
			}
			const thread = el('div', 'rb-thread');
			if (!result.comments.length) { thread.appendChild(el('p', 'tb-empty', 'Nenhum comentário ainda.')); }
			result.comments.forEach(function (comment) { thread.appendChild(commentRow(comment, post, ctx, me)); });
			body.appendChild(thread);
		});
	}

	function commentForm(ctx, postId, parentId, label) {
		const form = el('div', 'rb-reply');
		const text = O.textarea(label, 3);
		form.append(text);
		form.appendChild(el('div', 'tb-actions')).appendChild(button(parentId ? 'Responder' : 'Comentar', 'coe-button--primary', function () {
			const payload = { postId: postId, body: text.value };
			if (parentId) { payload.parentId = parentId; }
			ctx.request('forumComment', payload, function () { ctx.refresh(); }, 'Comentário publicado.');
		}));
		return form;
	}

	function commentRow(comment, post, ctx, me) {
		const row = el('div', 'rb-comment');
		row.style.marginLeft = (Math.max(0, (comment.depth || 1) - 1) * 16) + 'px';
		if (comment.removed) {
			row.classList.add('is-removed');
			row.appendChild(el('span', 'tb-muted', '[comentário removido]'));
			return row;
		}
		const meta = el('div', 'rb-meta');
		meta.append(O.link('u/' + comment.author, 'rabbit.onion/u/' + comment.author, 'rb-author' + (comment.author === post.author ? ' is-op' : ''), ctx.go),
			el('span', null, ' · ' + O.ago(comment.createdAt)));
		row.append(meta, paragraphs(comment.body, 'rb-comment-text'));
		const actions = el('div', 'rb-comment-actions');
		actions.appendChild(voter('c', comment, ctx));
		if (me) {
			let open = null;
			actions.appendChild(button('Responder', 'rb-small', function () {
				if (open) { open.remove(); open = null; return; }
				open = commentForm(ctx, post.id, comment.id, 'Responder a u/' + comment.author);
				row.appendChild(open);
			}));
		}
		if (comment.canRemove) {
			actions.appendChild(confirmButton('Remover', 'Confirmar', function () {
				ctx.request('forumRemove', { target: 'c', id: comment.id }, function () { ctx.refresh(); }, 'Comentário removido.');
			}));
		}
		row.appendChild(actions);
		return row;
	}

	function forumUser(body, ctx, handle) {
		load(body, ctx, 'forumUser', { handle: handle }, function (result) {
			ctx.setTitle('u/' + result.handle);
			const profile = O.card('rb-card rb-profile');
			const head = el('div', 'tb-card-head');
			head.append(el('h2', null, 'u/' + result.handle), badge(result.karma + ' pontos', 'tb-badge--accent'));
			profile.appendChild(head);
			const lines = el('div', 'tb-lines');
			lines.append(O.line('Na rede desde', O.when(result.createdAt)), O.line('Posts', String(result.postCount)), O.line('Comentários', String(result.commentCount)),
				O.line('Reputação no Deep Market', String(result.reputation || 0)));
			profile.appendChild(lines);
			body.appendChild(profile);
			const reviews = result.reviews || { count: 0, recent: [] };
			if (reviews.count) {
				const box = O.card('rb-card');
				box.appendChild(el('strong', null, 'Vendas no Deep Market · ' + stars(reviews.average) + ' (' + reviews.count + ')'));
				reviews.recent.forEach(function (review) { box.appendChild(reviewRow(review)); });
				body.appendChild(box);
			}
			body.appendChild(el('h3', 'rb-section', 'Posts'));
			if (!result.posts.length) { body.appendChild(el('p', 'tb-empty', 'Nenhum post.')); return; }
			const list = el('div', 'rb-posts');
			result.posts.forEach(function (post) { list.appendChild(postRow(post, ctx)); });
			body.appendChild(list);
		});
	}

	function reviewRow(review) {
		const row = el('div', 'bz-review');
		row.append(el('span', 'bz-stars', stars(review.rating)), el('small', 'tb-muted', (review.buyer ? '@' + review.buyer : 'comprador') + ' · ' + O.ago(review.createdAt)));
		if (review.body) { row.appendChild(el('p', null, review.body)); }
		return row;
	}

	// Deep Market -------------------------------------------------------------------------------------------

	const ORDER_STATUS = {
		paid: 'Pago · aguardando o vendedor', collecting: 'Coletando', completed: 'Concluído', disputed: 'Contestado · com a administração',
		refunded: 'Devolvido pela administração', released: 'Pago pela administração', cancelled: 'Cancelado · valor devolvido'
	};

	function orderStatus(order) {
		if (order.status === 'dropped') { return order.kind === 'item' ? 'No ponto de coleta' : 'Feito · aguardando confirmação'; }
		return ORDER_STATUS[order.status] || order.status;
	}

	function orderTone(order) {
		if (order.status === 'completed' || order.status === 'released') { return 'coe-badge--success'; }
		if (order.status === 'cancelled' || order.status === 'refunded') { return ''; }
		if (order.status === 'disputed') { return 'coe-badge--danger'; }
		return 'tb-badge--warn';
	}

	const LISTING_STATUS = { active: 'Ativo', paused: 'Pausado', removed: 'Removido' };

	// Unidades -> texto editável ("0,5"), no formato que o servidor aceita no marketSave.
	function coinText(units, decimals) {
		const scale = Math.pow(10, decimals || 0);
		const whole = Math.floor(units / scale);
		const rest = String(units % scale).padStart(decimals, '0').replace(/0+$/, '');
		return rest ? whole + ',' + rest : String(whole);
	}

	O.sites.market = function (page, ctx) {
		const path = ctx.target.path || [];
		const head = el('div', 'bz-head');
		const brand = el('a', 'bz-brand');
		brand.href = '#';
		brand.append(el('i', 'bz-logo'), el('strong', null, 'Deep Market'));
		brand.addEventListener('click', function (event) { event.preventDefault(); ctx.go('deepmarket.onion'); });
		const search = O.input('Buscar anúncios');
		search.value = ctx.target.query || '';
		onEnter(search, function () {
			const text = search.value.trim();
			if (!text) { ctx.go('deepmarket.onion'); return; }
			if (text.length < 2 || text.length > 40) { ctx.status(O.errors.invalid_query, 'error'); return; }
			ctx.go('deepmarket.onion/?q=' + text);
		});
		const nav = el('div', 'bz-nav');
		nav.append(O.link('Vitrine', 'deepmarket.onion', '', ctx.go), O.link('Fornecedores', 'deepmarket.onion/fornecedores', '', ctx.go), O.link('Meu painel', 'deepmarket.onion/painel', '', ctx.go));
		head.append(brand, search, nav);
		page.appendChild(head);
		const body = el('div', 'bz-body');
		page.appendChild(body);

		if (path.length === 0) {
			marketHome(body, ctx, { q: ctx.target.query || undefined });
		} else if (path[0] === 'c' && path[1]) {
			marketHome(body, ctx, { category: path[1] });
		} else if (path.length === 1 && path[0] === 'fornecedores') {
			marketHome(body, ctx, { npc: true });
		} else if (path[0] === 'a' && /^\d+$/.test(path[1] || '')) {
			marketListing(body, ctx, Number(path[1]));
		} else if (path[0] === 'painel' && path.length === 1) {
			marketPanel(body, ctx);
		} else if (path[0] === 'painel' && path[1] === 'novo') {
			marketForm(body, ctx, null);
		} else if (path[0] === 'painel' && path[1] === 'editar' && /^\d+$/.test(path[2] || '')) {
			marketForm(body, ctx, Number(path[2]));
		} else if (path[0] === 'pedido' && /^\d+$/.test(path[1] || '')) {
			marketOrder(body, ctx, Number(path[1]));
		} else {
			notFound(body);
		}
	};

	function listingCard(listing, ctx) {
		const box = el('a', 'bz-card' + (listing.stock > 0 ? '' : ' is-out'));
		box.href = '#';
		box.addEventListener('click', function (event) { event.preventDefault(); ctx.go('deepmarket.onion/a/' + listing.id); });
		const top = el('div', 'bz-card-top');
		top.append(badge(listing.kind === 'service' ? 'Serviço' : 'Item', listing.kind === 'service' ? 'tb-badge--accent' : ''),
			el('span', 'bz-price', listing.priceText));
		box.append(top, el('strong', 'bz-card-title', listing.title));
		if (listing.kind === 'item' && listing.itemLabel) { box.appendChild(el('small', 'tb-muted', listing.itemLabel + ' × ' + listing.count + ' por unidade')); }
		const foot = el('div', 'bz-card-foot');
		foot.append(el('small', 'bz-seller', listing.npc ? 'fornecedor · ' + (listing.seller || '') : '@' + listing.seller + ' · rep ' + (listing.reputation || 0)),
			el('small', 'tb-muted', listing.stock > 0 ? listing.stock + ' em estoque' : 'Esgotado'));
		box.appendChild(foot);
		return box;
	}

	function marketHome(body, ctx, filter) {
		const payload = { category: filter.category, q: filter.q, npc: filter.npc, page: 1 };
		load(body, ctx, 'marketHome', payload, function (result) {
			const chips = el('div', 'bz-categories');
			chips.appendChild(O.link('Tudo', 'deepmarket.onion', 'bz-chip' + (!result.category && !filter.npc ? ' is-active' : ''), ctx.replace));
			(result.categories || []).forEach(function (category) {
				chips.appendChild(O.link(category.label, 'deepmarket.onion/c/' + category.id, 'bz-chip' + (result.category === category.id ? ' is-active' : ''), ctx.replace));
			});
			body.appendChild(chips);
			if (filter.q) { body.appendChild(el('p', 'tb-muted', 'Resultados para "' + filter.q + '"')); }
			if (filter.npc) { body.appendChild(el('p', 'tb-muted', 'Fornecedores da rede: a mercadoria já está no ponto de coleta quando você paga.')); }
			const notes = [];
			if (!result.me) { notes.push('Entre com um apelido para comprar.'); }
			else if (!result.canBuy) { notes.push('Seu equipamento só alcança a vitrine. Para comprar, use um tablet ou computador.'); }
			if (notes.length) { body.appendChild(el('div', 'ob-hint', notes.join(' '))); }
			const grid = el('div', 'bz-grid');
			body.appendChild(grid);
			function add(page) {
				if (!page.listings.length && payload.page === 1) { grid.appendChild(el('p', 'tb-empty', 'Nenhum anúncio por aqui.')); }
				page.listings.forEach(function (listing) { grid.appendChild(listingCard(listing, ctx)); });
				if (page.more) {
					const more = button('Carregar mais', 'bz-more', function () {
						more.remove();
						payload.page += 1;
						load(grid, ctx, 'marketHome', payload, add);
					});
					grid.appendChild(more);
				}
			}
			add(result);
		});
	}

	function marketListing(body, ctx, id) {
		load(body, ctx, 'marketListing', { id: id }, function (result) {
			const listing = result.listing;
			ctx.setTitle(listing.title + ' · Deep Market');
			const layout = el('div', 'bz-detail');
			const main = el('div', 'bz-column');
			const head = el('div', 'tb-card-head');
			head.append(el('h2', null, listing.title), badge(listing.kind === 'service' ? 'Serviço' : 'Item', listing.kind === 'service' ? 'tb-badge--accent' : ''));
			main.appendChild(head);
			if (listing.status !== 'active') { main.appendChild(el('div', 'ob-hint', 'Anúncio ' + (LISTING_STATUS[listing.status] || listing.status).toLowerCase() + ': só você vê.')); }
			const lines = el('div', 'tb-lines');
			lines.append(O.line('Preço por unidade', listing.priceText), O.line('Estoque', listing.stock > 0 ? String(listing.stock) : 'Esgotado'),
				O.line('Vendidos', String(listing.sold || 0)));
			if (listing.kind === 'item' && listing.itemLabel) { lines.appendChild(O.line('Cada unidade', listing.itemLabel + ' × ' + listing.count)); }
			main.appendChild(lines);
			if (listing.description) { main.appendChild(paragraphs(listing.description)); }
			main.appendChild(el('p', 'tb-muted', listing.kind === 'item'
				? 'Entrega num ponto de coleta sorteado. O pagamento fica em custódia até você coletar.'
				: 'O vendedor marca o serviço como feito; você confirma ou contesta. Sem resposta em ' + result.autoReleaseHours + ' h, libera sozinho.'));
			layout.appendChild(main);

			const side = el('div', 'bz-side');
			const seller = O.card('bz-seller-card');
			if (listing.npc) {
				seller.append(el('strong', null, listing.seller || 'Fornecedor'), el('small', 'tb-muted', 'Fornecedor da rede'));
			} else {
				seller.append(O.link('@' + listing.seller, 'rabbit.onion/u/' + listing.seller, 'bz-seller-name', ctx.go), el('small', 'tb-muted', 'Reputação ' + (listing.reputation || 0)));
				const reviews = result.reviews;
				if (reviews && reviews.count) {
					seller.appendChild(el('span', 'bz-stars', stars(reviews.average) + ' (' + reviews.count + ')'));
					reviews.recent.forEach(function (review) { seller.appendChild(reviewRow(review)); });
				} else {
					seller.appendChild(el('small', 'tb-muted', 'Sem avaliações.'));
				}
			}
			side.appendChild(seller);
			side.appendChild(buyBox(result, ctx));
			layout.appendChild(side);
			body.appendChild(layout);
		});
	}

	function buyBox(result, ctx) {
		const listing = result.listing;
		const box = O.card('dw-form bz-buy');
		box.appendChild(el('strong', null, 'Comprar'));
		if (listing.mine) {
			box.appendChild(el('p', 'tb-muted', 'Este anúncio é seu.'));
			box.appendChild(button('Editar anúncio', '', function () { ctx.go('deepmarket.onion/painel/editar/' + listing.id); }));
			return box;
		}
		if (listing.stock <= 0 || result.maxQuantity < 1) { box.appendChild(el('p', 'tb-muted', 'Sem estoque.')); return box; }
		if (!result.canBuy) { box.appendChild(el('p', 'tb-muted', 'Seu equipamento não alcança compras. Use um tablet ou computador.')); return box; }
		if (!result.me) { box.appendChild(signedOut(ctx, 'Para comprar, entre com um apelido.')); return box; }
		if (!result.wallets.length) {
			box.appendChild(el('p', 'tb-muted', 'Nenhuma carteira com chave neste aparelho. Crie ou importe uma no app Carteira.'));
			return box;
		}
		const quantities = [];
		for (let count = 1; count <= result.maxQuantity; count += 1) { quantities.push({ value: String(count), label: String(count) }); }
		const quantity = O.select(quantities, '1');
		const wallet = O.select(result.wallets.map(function (entry) {
			return { value: entry.address, label: (entry.label ? entry.label + ' · ' : '') + entry.address.slice(0, 10) + '… · ' + entry.balanceText };
		}), result.wallets[0].address);
		const total = el('small', 'tb-muted');
		function paint() { total.textContent = quantity.value + ' × ' + listing.priceText + ' + taxa da rede'; }
		quantity.addEventListener('change', paint);
		paint();
		box.append(O.field('Quantidade', quantity), O.field('Pagar com', wallet), total);
		box.appendChild(el('div', 'tb-actions')).appendChild(button('Comprar', 'coe-button--primary', function () {
			ctx.request('marketBuy', { id: listing.id, quantity: Number(quantity.value), from: wallet.value }, function (order) {
				ctx.go('deepmarket.onion/pedido/' + order.orderId);
			}, 'Pedido feito. O valor está em custódia.');
		}));
		return box;
	}

	function orderRow(order, ctx) {
		const row = el('div', 'ob-row bz-order' + (order.actions && order.actions.length ? ' is-pending' : ''));
		const text = el('div', 'ob-row-text');
		text.append(O.link('#' + order.id + ' · ' + order.title, 'deepmarket.onion/pedido/' + order.id, 'ob-row-title', ctx.go),
			el('small', 'tb-muted', (order.role === 'seller' ? 'para @' + (order.buyer || '?') : (order.npc ? 'fornecedor' : 'de @' + order.seller)) + ' · ' +
				order.totalText + ' · ' + O.ago(order.createdAt)));
		row.append(text, badge(orderStatus(order), orderTone(order)));
		return row;
	}

	function marketPanel(body, ctx) {
		ctx.setTitle('Meu painel · Deep Market');
		load(body, ctx, 'marketMine', {}, function (result) {
			body.appendChild(el('h2', 'bz-title', 'Painel de @' + result.me));
			const pending = result.bought.concat(result.sold).filter(function (order) { return order.actions && order.actions.length; });
			if (pending.length) { body.appendChild(el('div', 'ob-hint', pending.length + ' pedido(s) esperando uma ação sua.')); }

			const sections = [['Compras', result.bought, 'Nenhuma compra.'], ['Vendas', result.sold, 'Nenhuma venda.']];
			sections.forEach(function (section) {
				body.appendChild(el('h3', 'bz-section', section[0]));
				if (!section[1].length) { body.appendChild(el('p', 'tb-empty', section[2])); return; }
				const list = el('div', 'ob-list');
				section[1].forEach(function (order) { list.appendChild(orderRow(order, ctx)); });
				body.appendChild(list);
			});

			const head = el('div', 'bz-section-head');
			head.appendChild(el('h3', 'bz-section', 'Meus anúncios (' + result.listings.length + '/' + result.maxListings + ')'));
			if (result.canSell && result.listings.length < result.maxListings) {
				head.appendChild(button('Novo anúncio', 'coe-button--primary', function () { ctx.go('deepmarket.onion/painel/novo'); }));
			}
			body.appendChild(head);
			if (!result.canSell) { body.appendChild(el('div', 'ob-hint', 'Vender exige notebook, desktop ou servidor.')); }
			if (!result.listings.length) { body.appendChild(el('p', 'tb-empty', 'Nenhum anúncio.')); return; }
			const list = el('div', 'ob-list');
			result.listings.forEach(function (listing) {
				const row = el('div', 'ob-row');
				const text = el('div', 'ob-row-text');
				text.append(O.link(listing.title, 'deepmarket.onion/a/' + listing.id, 'ob-row-title', ctx.go),
					el('small', 'tb-muted', listing.priceText + ' · ' + listing.stock + ' em estoque · ' + (listing.sold || 0) + ' vendidos'));
				const actions = el('div', 'tb-actions');
				actions.appendChild(badge(LISTING_STATUS[listing.status] || listing.status, listing.status === 'active' ? 'coe-badge--success' : 'tb-badge--warn'));
				actions.appendChild(button('Editar', '', function () { ctx.go('deepmarket.onion/painel/editar/' + listing.id); }));
				const next = listing.status === 'active' ? 'paused' : 'active';
				actions.appendChild(button(next === 'paused' ? 'Pausar' : 'Reativar', '', function () {
					ctx.request('marketListingStatus', { id: listing.id, status: next }, function () { ctx.refresh(); }, next === 'paused' ? 'Anúncio pausado.' : 'Anúncio reativado.');
				}));
				actions.appendChild(confirmButton('Remover', 'Confirmar', function () {
					ctx.request('marketListingStatus', { id: listing.id, status: 'removed' }, function () { ctx.refresh(); }, 'Anúncio removido.');
				}));
				row.append(text, actions);
				list.appendChild(row);
			});
			body.appendChild(list);
		});
	}

	function marketForm(body, ctx, id) {
		ctx.setTitle((id ? 'Editar anúncio' : 'Novo anúncio') + ' · Deep Market');
		load(body, ctx, 'marketMine', {}, function (result) {
			let listing = null;
			if (id) {
				listing = result.listings.filter(function (entry) { return entry.id === id; })[0];
				if (!listing) { notFound(body, 'Anúncio não encontrado no seu painel.'); return; }
			}
			if (!result.canSell) { body.appendChild(el('div', 'ob-hint', 'Vender exige notebook, desktop ou servidor.')); return; }
			const form = O.card('dw-form bz-form');
			form.appendChild(el('strong', null, id ? 'Editar anúncio #' + id : 'Novo anúncio como @' + result.me));
			const title = O.input('Título do anúncio');
			const kind = O.select([{ value: 'item', label: 'Item (entregue no ponto de coleta)' }, { value: 'service', label: 'Serviço' }], listing ? listing.kind : 'item');
			const category = O.select((result.categories || []).map(function (entry) { return { value: entry.id, label: entry.label }; }), listing ? listing.category : undefined);
			const item = O.input('nome do item no inventário (ex.: lockpick)');
			const count = O.input('1', 'number');
			const price = O.input('ex.: 0,5');
			const stock = O.input('quantas unidades', 'number');
			const payout = O.input('carteira que recebe (nx…)');
			const description = O.textarea('Descrição (opcional)', 5);
			if (listing) {
				title.value = listing.title;
				item.value = listing.item || '';
				count.value = String(listing.count || 1);
				price.value = coinText(listing.price, result.decimals);
				stock.value = String(listing.stock);
				payout.value = listing.payout || '';
				description.value = listing.description || '';
			} else {
				count.value = '1';
				stock.value = '1';
			}
			const itemFields = el('div', 'bz-item-fields');
			itemFields.append(O.field('Item', item), O.field('Quantidade por unidade', count));
			function paintKind() { itemFields.hidden = kind.value !== 'item'; }
			kind.addEventListener('change', paintKind);
			paintKind();
			form.append(O.field('Título', title), O.field('Tipo', kind), O.field('Categoria', category), itemFields, O.field('Preço por unidade', price),
				O.field('Estoque', stock), O.field('Carteira de recebimento', payout), O.field('Descrição', description));
			form.appendChild(el('p', 'tb-muted', 'A rede retém ' + (result.feeBps / 100).toLocaleString('pt-BR') + '% de cada venda. Itens saem do seu inventário só quando você deixa a entrega no ponto de coleta.'));
			const actions = el('div', 'tb-actions');
			actions.append(button('Cancelar', '', function () { ctx.go('deepmarket.onion/painel'); }), button('Salvar', 'coe-button--primary', function () {
				const payload = {
					title: title.value, kind: kind.value, category: category.value, item: item.value.trim().toLowerCase(), count: Number(count.value),
					price: price.value, stock: Number(stock.value), payout: payout.value, description: description.value
				};
				if (listing) { payload.id = listing.id; payload.status = listing.status === 'paused' ? 'paused' : 'active'; }
				ctx.request('marketSave', payload, function () { ctx.replace('deepmarket.onion/painel'); }, listing ? 'Anúncio salvo.' : 'Anúncio publicado.');
			}));
			form.appendChild(actions);
			body.appendChild(form);
		});
	}

	const ACTIONS = {
		deliver: function (order) { return order.kind === 'item' ? ['Ir deixar a entrega', 'coe-button--primary'] : ['Marcar como feito', 'coe-button--primary']; },
		collect: function () { return ['Ir coletar', 'coe-button--primary']; },
		confirm: function () { return ['Confirmar serviço', 'coe-button--primary']; },
		cancel: function () { return ['Cancelar pedido', 'coe-button--danger']; }
	};

	function marketOrder(body, ctx, id) {
		ctx.setTitle('Pedido #' + id + ' · Deep Market');
		load(body, ctx, 'marketOrder', { id: id }, function (result) {
			const order = result.order;
			const box = O.card('bz-order-card');
			const head = el('div', 'tb-card-head');
			head.append(el('h2', null, '#' + order.id + ' · ' + order.title), badge(orderStatus(order), orderTone(order)));
			box.appendChild(head);
			const lines = el('div', 'tb-lines');
			lines.appendChild(O.line('Você é', order.role === 'seller' ? 'Vendedor' : 'Comprador'));
			lines.appendChild(O.line(order.role === 'seller' ? 'Comprador' : 'Vendedor',
				order.role === 'seller' ? '@' + (order.buyer || '?') : (order.npc ? 'fornecedor · ' + (order.seller || '') : '@' + order.seller)));
			lines.appendChild(O.line('Quantidade', order.quantity + (order.kind === 'item' && order.itemLabel ? ' (' + order.itemLabel + ' × ' + order.count + ')' : '')));
			lines.appendChild(O.line('Total em custódia', order.totalText));
			if (order.role === 'seller') { lines.appendChild(O.line('Você recebe', order.netText + ' (taxa ' + order.feeText + ')')); }
			lines.appendChild(O.line('Pedido em', O.when(order.createdAt)));
			if (order.status === 'paid') { lines.appendChild(O.line('Prazo de entrega', O.when(order.deliverBy))); }
			if (order.deliveredAt) { lines.appendChild(O.line(order.kind === 'item' ? 'Deixado em' : 'Feito em', O.when(order.deliveredAt))); }
			if (order.releaseAt && order.status === 'dropped') { lines.appendChild(O.line('Libera sozinho em', O.when(order.releaseAt))); }
			if (order.closedAt) { lines.appendChild(O.line('Encerrado em', O.when(order.closedAt))); }
			box.appendChild(lines);
			if (order.note) { box.appendChild(el('div', 'ob-hint', 'Contestação: ' + order.note)); }
			box.appendChild(O.link('Ver anúncio', 'deepmarket.onion/a/' + order.listingId, '', ctx.go));
			body.appendChild(box);

			if (order.drop) {
				const drop = O.card('bz-drop');
				drop.append(el('strong', null, 'Ponto de coleta'), el('span', null, order.drop.label || 'Ponto marcado'),
					el('small', 'tb-muted', order.role === 'seller'
						? 'Toque em "Ir deixar a entrega": o ponto vai para o GPS. No local, mire na caixa (alvo) com os itens no inventário.'
						: 'Toque em "Ir coletar": o ponto vai para o GPS. No local, mire na caixa (alvo) para pegar. Cuidado: o lugar pode estar sendo observado.'));
				drop.appendChild(el('div', 'tb-actions')).appendChild(button('Marcar no GPS', '', function () { ctx.waypoint(order.drop.x, order.drop.y); }));
				body.appendChild(drop);
			}

			const actions = (order.actions || []).filter(function (action) { return action !== 'dispute'; });
			if (actions.length) {
				const bar = el('div', 'tb-actions bz-actions');
				actions.forEach(function (action) {
					const spec = ACTIONS[action] ? ACTIONS[action](order) : [action, ''];
					const atDrop = order.kind === 'item' && (action === 'deliver' || action === 'collect');
					const run = function () {
						ctx.request('marketAct', { id: order.id, action: action }, function () { ctx.refresh(); },
							atDrop ? 'Ponto marcado no GPS. No local, use o alvo na caixa.' : 'Pedido atualizado.');
					};
					bar.appendChild(action === 'cancel' ? confirmButton(spec[0], 'Confirmar cancelamento', run) : button(spec[0], spec[1], run));
				});
				body.appendChild(bar);
			}
			if ((order.actions || []).indexOf('dispute') !== -1) {
				const dispute = O.card('dw-form');
				const note = O.textarea('O que deu errado? (até 200 caracteres)', 3);
				dispute.append(el('strong', null, 'Contestar'), el('p', 'tb-muted', 'O valor continua em custódia e a administração da rede decide.'), note);
				dispute.appendChild(el('div', 'tb-actions')).appendChild(button('Contestar', 'coe-button--danger', function () {
					ctx.request('marketAct', { id: order.id, action: 'dispute', note: note.value }, function () { ctx.refresh(); }, 'Contestação enviada.');
				}));
				body.appendChild(dispute);
			}
			if (order.rating) {
				body.appendChild(el('p', 'tb-muted', 'Sua avaliação: ' + stars(order.rating)));
			} else if (order.canReview) {
				const review = O.card('dw-form');
				const rating = O.select([5, 4, 3, 2, 1].map(function (value) { return { value: String(value), label: stars(value) }; }), '5');
				const text = O.textarea('Comentário (opcional)', 2);
				review.append(el('strong', null, 'Avaliar o vendedor'), O.field('Nota', rating), O.field('Comentário', text));
				review.appendChild(el('div', 'tb-actions')).appendChild(button('Enviar avaliação', 'coe-button--primary', function () {
					ctx.request('marketReview', { id: order.id, rating: Number(rating.value), body: text.value }, function () { ctx.refresh(); }, 'Avaliação enviada.');
				}));
				body.appendChild(review);
			}
		});
	}

	// Sites por blocos --------------------------------------------------------------------------------------

	function decodeBlocks(raw) {
		if (Array.isArray(raw)) { return raw; }
		if (typeof raw !== 'string' || !raw) { return []; }
		try {
			const list = JSON.parse(raw);
			return Array.isArray(list) ? list : [];
		} catch (error) {
			return [];
		}
	}

	const TONES = { info: 'info', warn: 'warn', danger: 'danger', success: 'success' };

	function block(entry, ctx) {
		switch (entry && entry.type) {
			case 'heading': return el('h2', 'bk-heading', entry.text);
			case 'text': return paragraphs(entry.text, 'bk-text');
			case 'quote': return el('blockquote', 'bk-quote', entry.text);
			case 'notice': return el('div', 'bk-notice is-' + (TONES[entry.tone] || 'info'), entry.text);
			case 'divider': return el('hr', 'bk-divider');
			case 'list': {
				const list = el('ul', 'bk-list');
				(entry.items || []).forEach(function (item) { list.appendChild(el('li', null, item)); });
				return list;
			}
			case 'link': {
				const row = el('div', 'bk-link-row');
				row.append(el('span', 'bk-arrow', '→'), O.link(entry.label, entry.href, 'bk-link', ctx.go));
				return row;
			}
			case 'listing': return listingBlock(entry.id, ctx);
			default: return null;
		}
	}

	function listingBlock(id, ctx) {
		const holder = el('div', 'bk-listing');
		holder.appendChild(el('small', 'tb-muted', 'Carregando anúncio…'));
		ctx.call('marketListing', { id: id }).then(function (result) {
			if (!ctx.alive()) { return; }
			holder.replaceChildren();
			if (!result.ok) { holder.appendChild(el('small', 'tb-muted', 'Anúncio indisponível.')); return; }
			holder.appendChild(listingCard(result.listing, ctx));
		});
		return holder;
	}

	O.sites.blocks = function (page, ctx) {
		const site = ctx.site || {};
		const head = el('div', 'bk-head');
		head.append(el('h1', 'bk-title', site.title || site.domain), el('small', 'bk-domain', site.domain));
		if (site.description) { head.appendChild(el('p', 'tb-muted', site.description)); }
		page.appendChild(head);
		const body = el('div', 'bk-body');
		const blocks = decodeBlocks(site.blocks);
		blocks.forEach(function (entry) {
			const node = block(entry, ctx);
			if (node) { body.appendChild(node); }
		});
		if (!body.childNodes.length) { body.appendChild(el('p', 'tb-empty', 'Este site ainda não tem conteúdo.')); }
		page.appendChild(body);
		if (site.updatedAt) { page.appendChild(el('small', 'bk-updated tb-muted', 'Atualizado ' + O.when(site.updatedAt))); }
	};

	// Perfil (sites de sistema com profile no config, ex.: fantasma.onion) --------------------------------------

	const CONTACT_STATUS = { open: ['Aguardando', ''], answered: ['Respondida', 'tb-badge--accent'], closed: ['Arquivada', ''] };

	function contactRow(message) {
		const row = el('div', 'fx-message');
		const status = CONTACT_STATUS[message.status] || CONTACT_STATUS.open;
		const head = el('div', 'fx-message-head');
		head.append(el('small', 'tb-muted', O.when(message.createdAt)), badge(status[0], status[1]));
		row.append(head, paragraphs(message.body, 'fx-message-body'));
		if (message.reply) {
			const reply = el('div', 'fx-reply');
			reply.append(el('small', 'fx-prompt', 'resposta · ' + O.ago(message.repliedAt)), paragraphs(message.reply));
			row.appendChild(reply);
		}
		return row;
	}

	function contactBox(page, ctx, site) {
		const box = O.card('fx-card fx-contact');
		box.appendChild(el('h3', 'fx-section', '$ contato'));
		page.appendChild(box);
		if (!(ctx.data && ctx.data.handle)) { box.appendChild(signedOut(ctx, 'Entre com um apelido para mandar mensagem.')); return; }
		box.appendChild(el('small', 'tb-muted', 'Assinado como @' + ctx.data.handle.name + '. A resposta aparece aqui.'));
		const text = O.textarea('Mensagem', 5);
		box.appendChild(text);
		box.appendChild(el('div', 'tb-actions')).appendChild(button('Enviar', 'coe-button--primary', function () {
			ctx.request('contactSend', { domain: site.domain, body: text.value }, function () { ctx.refresh(); }, 'Mensagem enviada.');
		}));
		const thread = el('div', 'fx-thread');
		box.append(el('h3', 'fx-section', '$ suas mensagens'), thread);
		load(thread, ctx, 'contactThread', { domain: site.domain }, function (result) {
			if (!result.messages.length) { thread.appendChild(el('p', 'tb-empty', 'Nenhuma mensagem ainda.')); return; }
			result.messages.forEach(function (message) { thread.appendChild(contactRow(message)); });
		});
	}

	O.sites.profile = function (page, ctx) {
		const site = ctx.site || {};
		const profile = site.profile || {};
		const card = O.card('fx-card fx-hero');
		card.append(el('code', 'fx-prompt', profile.tagline || ''), el('h1', 'fx-handle', '@' + (profile.handle || site.title)));
		if (site.description) { card.appendChild(el('p', 'tb-muted', site.description)); }
		page.appendChild(card);
		const grid = el('div', 'fx-grid');
		const main = el('div', 'fx-main');
		const side = el('div', 'fx-side');
		if (profile.bio) {
			const about = O.card('fx-card');
			about.append(el('h3', 'fx-section', '$ cat sobre.txt'), paragraphs(profile.bio));
			main.appendChild(about);
		}
		if (Array.isArray(profile.rules) && profile.rules.length) {
			const rules = O.card('fx-card');
			const list = el('ol', 'fx-rules');
			profile.rules.forEach(function (rule) { list.appendChild(el('li', null, rule)); });
			rules.append(el('h3', 'fx-section', '$ cat regras.txt'), list);
			main.appendChild(rules);
		}
		if (Array.isArray(profile.facts) && profile.facts.length) {
			const facts = O.card('fx-card');
			const lines = el('div', 'tb-lines');
			profile.facts.forEach(function (fact) { lines.appendChild(O.line(fact.label, fact.value)); });
			facts.append(el('h3', 'fx-section', '$ id'), lines);
			side.appendChild(facts);
		}
		if (Array.isArray(profile.skills) && profile.skills.length) {
			const skills = O.card('fx-card');
			const chips = el('div', 'fx-skills');
			profile.skills.forEach(function (skill) { chips.appendChild(el('span', 'fx-skill', skill)); });
			skills.append(el('h3', 'fx-section', '$ ls skills/'), chips);
			side.appendChild(skills);
		}
		grid.append(main, side);
		page.appendChild(grid);
		if (profile.contact) { contactBox(main, ctx, site); }
	};

	O.sitesLoaded = true;
})();
