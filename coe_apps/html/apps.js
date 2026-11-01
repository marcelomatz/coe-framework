// Apps do coe_apps no COE OS: Loja, Empregos, Classificados e Insta. O mesmo script serve o smartphone, que expõe
// a mesma API (call, status, errorText, waypoint, camera, upload, refresh, icon).
(function () {
	'use strict';

	const ERRORS = {
		not_ready: 'Serviço ainda iniciando.', no_character: 'Personagem não carregado.',
		database_error: 'Falha ao gravar. Tente de novo.', unknown_action: 'Ação desconhecida.',
		unknown_app: 'Aplicativo não encontrado.', already_installed: 'Aplicativo já instalado.',
		not_installed: 'Instale o aplicativo pela Loja.', insufficient_funds: 'Saldo insuficiente na conta.',
		economy_unavailable: 'Banco indisponível no momento.', ad_limit: 'Você atingiu o limite de anúncios ativos.',
		invalid_ad: 'Anúncio inválido.', invalid_category: 'Escolha uma categoria.',
		invalid_title: 'Título precisa de pelo menos 3 letras.', invalid_price: 'Preço inválido.',
		post_cooldown: 'Espere um pouco antes de publicar de novo.', photo_expired: 'A foto expirou. Tire outra.',
		invalid_photo: 'Foto inválida ou grande demais.', upload_failed: 'Falha ao enviar a foto.',
		upload_cooldown: 'Espere alguns segundos para enviar outra foto.', not_found: 'Não encontrado. Atualize.',
		forbidden: 'Você não pode fazer isso.',
		no_credit: 'Assinaturas são pagas no cartão de crédito. Peça o seu na agência do banco.',
		no_card: 'Você precisa de um cartão de crédito ativo (não bloqueado nem vencido).',
		credit_late: 'Cartão de crédito bloqueado por fatura em atraso.', credit_limit: 'Limite do cartão de crédito insuficiente.',
		bank_unavailable: 'Banco indisponível no momento.', busy: 'Aguarde a operação anterior terminar.',
		card_blocked: 'Cartão bloqueado. Escolha outro cartão na Carteira.', card_expired: 'Cartão vencido. Escolha outro cartão na Carteira.',
		wallet_required: 'Assinaturas são pagas pela Carteira do smartphone.',
		payment_expired: 'O pagamento expirou. Tente de novo.', payment_mismatch: 'Pagamento não confere. Tente de novo.'
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

	function money(value) {
		return '$ ' + Number(value || 0).toLocaleString('pt-BR');
	}

	function day(seconds) {
		const date = new Date(Number(seconds || 0) * 1000);
		return String(date.getDate()).padStart(2, '0') + '/' + String(date.getMonth() + 1).padStart(2, '0');
	}

	function ago(seconds) {
		const diff = Math.max(0, Math.floor(Date.now() / 1000) - Number(seconds || 0));
		if (diff < 60) { return 'agora'; }
		if (diff < 3600) { return 'há ' + Math.floor(diff / 60) + ' min'; }
		if (diff < 86400) { return 'há ' + Math.floor(diff / 3600) + ' h'; }
		return 'há ' + Math.floor(diff / 86400) + ' d';
	}

	function left(seconds) {
		const diff = Math.max(0, Number(seconds || 0) - Math.floor(Date.now() / 1000));
		if (diff < 3600) { return 'expira em ' + Math.max(1, Math.floor(diff / 60)) + ' min'; }
		if (diff < 86400) { return 'expira em ' + Math.floor(diff / 3600) + ' h'; }
		return 'expira em ' + Math.floor(diff / 86400) + ' d';
	}

	// O tablet aceita uma ação a cada 250 ms: todas as chamadas destes apps passam por esta fila.
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
			job.tablet.call(job.app, job.action, job.payload).then(function (result) {
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

	function send(tablet, app, action, payload) {
		return new Promise(function (resolve) {
			queue.push({ tablet: tablet, app: app, action: action, payload: payload || {}, resolve: resolve, retries: 0 });
			pump();
		});
	}

	function helpers(app, tablet) {
		function errorText(code) { return ERRORS[code] || tablet.errorText(code); }
		return {
			errorText: errorText,
			call: function (action, payload) { return send(tablet, app, action, payload); },
			fail: function (result) { tablet.status(errorText(result && result.error), 'error'); }
		};
	}

	// Loja ---------------------------------------------------------------------------------------------

	window.CoeTablet.register('store', function (root, tablet) {
		const h = helpers('store', tablet);
		let busy = false;

		function act(action, app, message, extra) {
			if (busy) { return; }
			busy = true;
			h.call(action, Object.assign({ app: app.id }, extra || {})).then(function (result) {
				busy = false;
				if (!result.ok) { h.fail(result); return; }
				tablet.status(message, 'ok');
				if (tablet.refresh) { tablet.refresh(); }
				load();
			});
		}

		function card(app) {
			const box = el('div', 'coe-panel coe-panel--compact tb-card tb-store-app');
			const head = el('div', 'tb-store-head');
			const icon = el('i', 'tablet-app-icon');
			if (tablet.icon) { tablet.icon(icon, app); } else { icon.textContent = app.label.charAt(0); }
			const title = el('div', 'tb-title');
			title.append(el('strong', null, app.label), el('span', 'tb-muted', app.category));
			head.append(icon, title);
			const paid = app.price > 0;
			const price = app.builtin ? 'Nativo' : (paid ? money(app.price) + '/semana' : 'Grátis');
			const badge = el('span', 'coe-badge' + (app.installed ? ' coe-badge--success' : ''), app.installed ? (paid ? 'Assinado' : 'Instalado') : price);
			head.appendChild(badge);
			box.append(head, el('p', 'tb-muted', app.description || ''));
			if (paid) {
				let note = 'Assinatura semanal de ' + money(app.price) + ' no cartão de crédito.';
				if (app.installed && app.renews) { note = 'Renova em ' + day(app.paidUntil) + ' no cartão de crédito (' + money(app.price) + ').'; }
				else if (app.paidUntil) { note = 'Pago até ' + day(app.paidUntil) + ' — reinstale sem custo.'; }
				box.appendChild(el('p', 'tb-muted tb-store-note', note));
			}
			const actions = el('div', 'tb-actions');
			if (app.builtin) {
				actions.appendChild(el('span', 'tb-muted', 'Vem com o sistema'));
			} else if (app.installed) {
				actions.appendChild(button(paid ? 'Cancelar assinatura' : 'Remover', 'coe-button--danger', function () {
					act('uninstall', app, paid ? 'Assinatura de ' + app.label + ' cancelada.' : app.label + ' removido.');
				}));
			} else {
				const label = app.owned || !paid ? 'Instalar' : 'Assinar ' + money(app.price) + '/semana';
				actions.appendChild(button(label, 'coe-button--primary', function () {
					if (!paid) { act('install', app, app.label + ' instalado na tela inicial.'); return; }
					subscribe(app);
				}));
			}
			box.appendChild(actions);
			return box;
		}

		// Assinatura: escolhe o cartão e confirma na Carteira do smartphone; o servidor cobra no cartão escolhido.
		function subscribe(app) {
			if (busy) { return; }
			if (typeof tablet.pay !== 'function') { tablet.status(h.errorText('wallet_required'), 'error'); return; }
			busy = true;
			tablet.pay({
				amount: app.price,
				label: 'Assinatura ' + app.label,
				note: app.owned ? 'Semana já paga: nada é cobrado agora. A renovação semanal usa este cartão.' : 'Cobrança semanal no cartão escolhido, renovada automaticamente.'
			}).then(function (payment) {
				busy = false;
				if (!payment) { return; }
				act('install', app, app.label + ' instalado na tela inicial.', { payment: payment.token });
			});
		}

		function view(apps) {
			root.replaceChildren();
			const head = el('div', 'tb-toolbar');
			const title = el('div', 'tb-title');
			title.append(el('strong', null, 'Loja COE'), el('span', 'tb-muted', 'Os mesmos apps no tablet e no smartphone. Apps pagos são assinaturas semanais pagas pela Carteira do smartphone.'));
			head.appendChild(title);
			root.appendChild(head);
			const categories = [];
			apps.forEach(function (app) { if (categories.indexOf(app.category) < 0) { categories.push(app.category); } });
			categories.forEach(function (category) {
				root.appendChild(el('div', 'tb-section', category));
				const grid = el('div', 'tb-grid');
				apps.filter(function (app) { return app.category === category; }).forEach(function (app) { grid.appendChild(card(app)); });
				root.appendChild(grid);
			});
		}

		function load() {
			h.call('list').then(function (result) {
				if (!result.ok) { h.fail(result); return; }
				view(result.apps || []);
			});
		}

		load();
	});

	// Empregos -----------------------------------------------------------------------------------------

	window.CoeTablet.register('jobs', function (root, tablet) {
		const h = helpers('jobs', tablet);

		function card(job) {
			const box = el('div', 'coe-panel coe-panel--compact tb-card');
			const head = el('div', 'tb-card-head');
			const title = el('div', 'tb-title');
			title.append(el('strong', null, job.label), el('span', 'tb-muted', job.place || 'Procure o responsável'));
			head.append(title, el('span', 'coe-badge' + (job.mine ? ' coe-badge--success' : ''), job.mine ? 'Seu emprego' : job.online + ' em serviço'));
			box.appendChild(head);
			if (job.description) { box.appendChild(el('p', 'tb-muted', job.description)); }
			if (job.grades && job.grades.length) {
				const chips = el('div', 'tb-chips');
				job.grades.forEach(function (grade) { chips.appendChild(el('span', 'coe-badge', grade)); });
				box.appendChild(chips);
			}
			const actions = el('div', 'tb-actions');
			if (typeof job.x === 'number' && typeof job.y === 'number') {
				actions.appendChild(button('Marcar no GPS', 'coe-button--primary', function () {
					tablet.waypoint(job.x, job.y).then(function () { tablet.status('Local marcado no GPS.', 'ok'); });
				}));
			}
			box.appendChild(actions);
			return box;
		}

		h.call('list').then(function (result) {
			if (!result.ok) { h.fail(result); return; }
			root.replaceChildren();
			const head = el('div', 'tb-title');
			head.append(el('strong', null, 'Empregos públicos'), el('span', 'tb-muted', 'Vá até o local e procure o responsável para ser contratado.'));
			root.appendChild(head);
			const jobs = result.jobs || [];
			if (jobs.length === 0) { root.appendChild(el('p', 'tb-empty', 'Nenhuma vaga pública no momento.')); return; }
			const grid = el('div', 'tb-grid');
			jobs.forEach(function (job) { grid.appendChild(card(job)); });
			root.appendChild(grid);
		});
	});

	// Classificados ------------------------------------------------------------------------------------

	window.CoeTablet.register('classifieds', function (root, tablet) {
		const h = helpers('classifieds', tablet);
		let category = '';
		let data = null;
		let busy = false;

		function load() {
			h.call('list', { category: category }).then(function (result) {
				if (!result.ok) { h.fail(result); return; }
				data = result;
				view();
			});
		}

		function adCard(ad) {
			const box = el('div', 'coe-panel coe-panel--compact tb-card');
			const head = el('div', 'tb-card-head');
			const title = el('div', 'tb-title');
			title.append(el('strong', null, ad.title), el('span', 'tb-muted', (ad.categoryLabel || '') + ' · ' + ago(ad.createdAt)));
			head.append(title, el('span', 'coe-badge tb-badge--accent', ad.price !== null && ad.price !== undefined ? money(ad.price) : 'A combinar'));
			box.appendChild(head);
			if (ad.body) { box.appendChild(el('p', 'tb-ad-body', ad.body)); }
			const foot = el('div', 'tb-toolbar');
			foot.appendChild(el('span', 'tb-muted', 'Contato: ' + ad.author + (ad.contact ? ' · ID ' + ad.contact : '')));
			const side = el('div', 'tb-actions');
			if (ad.mine) { side.appendChild(el('span', 'tb-muted', left(ad.expiresAt))); }
			if (ad.canRemove) {
				side.appendChild(button(ad.mine ? 'Encerrar' : 'Remover', 'coe-button--danger', function () {
					if (busy) { return; }
					busy = true;
					h.call('remove', { id: ad.id }).then(function (result) {
						busy = false;
						if (!result.ok) { h.fail(result); return; }
						tablet.status('Anúncio removido.', 'ok');
						load();
					});
				}));
			}
			foot.appendChild(side);
			box.appendChild(foot);
			return box;
		}

		function form() {
			const box = el('div', 'coe-panel coe-panel--compact tb-card');
			box.appendChild(el('div', 'tb-section', 'Novo anúncio'));
			const select = el('select', 'coe-field');
			(data.categories || []).forEach(function (c) {
				const option = el('option', null, c.label);
				option.value = c.id;
				select.appendChild(option);
			});
			if (category) { select.value = category; }
			const title = el('input', 'coe-field');
			title.placeholder = 'Título';
			title.maxLength = data.limits.title;
			const price = el('input', 'coe-field');
			price.type = 'number';
			price.min = '0';
			price.placeholder = 'Preço (vazio = a combinar)';
			const body = el('textarea', 'coe-field tb-textarea');
			body.placeholder = 'Descrição';
			body.maxLength = data.limits.body;
			const row = el('div', 'tb-form-row');
			row.append(select, price);
			box.append(row, title, body);
			const info = el('span', 'tb-muted', 'Taxa ' + (data.fee > 0 ? money(data.fee) : 'grátis') + ' · fica ' + data.durationHours + ' h no ar · ' + data.mine + '/' + data.maxActive + ' ativos');
			const actions = el('div', 'tb-toolbar');
			actions.append(info, button('Publicar', 'coe-button--primary', function () {
				if (busy) { return; }
				busy = true;
				h.call('post', { category: select.value, title: title.value, body: body.value, price: price.value === '' ? null : Number(price.value) }).then(function (result) {
					busy = false;
					if (!result.ok) { h.fail(result); return; }
					tablet.status('Anúncio publicado.', 'ok');
					load();
				});
			}));
			box.appendChild(actions);
			return box;
		}

		function view() {
			root.replaceChildren();
			const tabs = el('div', 'tb-tabs');
			[{ id: '', label: 'Todos' }].concat(data.categories || []).forEach(function (c) {
				const tab = button(c.label, 'tb-tab' + (c.id === category ? ' is-active' : ''), function () { category = c.id; load(); });
				tabs.appendChild(tab);
			});
			root.appendChild(tabs);
			if (data.mine < data.maxActive) {
				root.appendChild(form());
			} else {
				root.appendChild(el('div', 'tb-alert', 'Você já tem ' + data.maxActive + ' anúncios ativos. Encerre um para publicar outro.'));
			}
			const ads = data.ads || [];
			if (ads.length === 0) { root.appendChild(el('p', 'tb-empty', 'Nenhum anúncio nesta categoria.')); return; }
			const grid = el('div', 'tb-grid');
			ads.forEach(function (ad) { grid.appendChild(adCard(ad)); });
			root.appendChild(grid);
		}

		load();
	});

	// Insta --------------------------------------------------------------------------------------------

	const mediaCache = {};

	function shrink(image, settings) {
		return new Promise(function (resolve) {
			const img = new Image();
			img.onload = function () {
				const width = Math.min(settings.width || 960, img.width);
				const height = Math.round(img.height * (width / img.width));
				const canvas = document.createElement('canvas');
				canvas.width = width;
				canvas.height = height;
				canvas.getContext('2d').drawImage(img, 0, 0, width, height);
				let quality = settings.quality || 0.72;
				let out = canvas.toDataURL('image/jpeg', quality);
				while (out.length > (settings.maxBytes || 400000) && quality > 0.3) {
					quality -= 0.1;
					out = canvas.toDataURL('image/jpeg', quality);
				}
				resolve(out.length <= (settings.maxBytes || 400000) ? out : null);
			};
			img.onerror = function () { resolve(null); };
			img.src = image;
		});
	}

	window.CoeTablet.register('insta', function (root, tablet) {
		const h = helpers('insta', tablet);
		let tab = 'feed';
		let posts = [];
		let more = false;
		let settings = { width: 960, quality: 0.72, maxBytes: 400000 };
		let captionMax = 280;
		let me = '';
		let busy = false;
		let draft = null;

		function paint(img, image) {
			if (/^https:\/\//.test(image)) { img.src = image; return; }
			const match = /^media:(\d+)$/.exec(image || '');
			if (!match) { return; }
			const id = Number(match[1]);
			if (mediaCache[id]) { img.src = mediaCache[id]; return; }
			h.call('media', { id: id }).then(function (result) {
				if (!result.ok || typeof result.data !== 'string') { img.classList.add('is-missing'); return; }
				mediaCache[id] = result.data.indexOf('data:') === 0 ? result.data : 'data:image/jpeg;base64,' + result.data;
				img.src = mediaCache[id];
			});
		}

		function postCard(post) {
			const box = el('div', 'coe-panel coe-panel--compact tb-post');
			const head = el('div', 'tb-card-head');
			const title = el('div', 'tb-title');
			title.append(el('strong', null, post.handle), el('span', 'tb-muted', post.author + ' · ' + ago(post.createdAt)));
			head.appendChild(title);
			if (post.canRemove) {
				head.appendChild(button('Apagar', 'coe-button--danger', function () {
					if (busy) { return; }
					busy = true;
					h.call('remove', { id: post.id }).then(function (result) {
						busy = false;
						if (!result.ok) { h.fail(result); return; }
						posts = posts.filter(function (p) { return p.id !== post.id; });
						tablet.status('Post apagado.', 'ok');
						view();
					});
				}));
			}
			const frame = el('div', 'tb-post-photo');
			const img = el('img');
			img.alt = post.caption || 'Foto';
			frame.appendChild(img);
			paint(img, post.image);
			const like = button((post.liked ? '♥ ' : '♡ ') + post.likes, 'tb-like' + (post.liked ? ' is-liked' : ''), function () {
				h.call('like', { id: post.id }).then(function (result) {
					if (!result.ok) { h.fail(result); return; }
					post.liked = result.liked;
					post.likes = result.likes;
					like.textContent = (post.liked ? '♥ ' : '♡ ') + post.likes;
					like.classList.toggle('is-liked', post.liked);
				});
			});
			frame.addEventListener('dblclick', function () { if (!post.liked) { like.click(); } });
			box.append(head, frame, like);
			if (post.caption) { box.appendChild(el('p', 'tb-post-caption', post.caption)); }
			return box;
		}

		function composer() {
			const box = el('div', 'coe-panel coe-panel--compact tb-card tb-composer');
			box.appendChild(el('div', 'tb-section', 'Nova publicação'));
			const preview = el('div', 'tb-post-photo');
			const img = el('img');
			img.src = draft.image;
			preview.appendChild(img);
			const caption = el('textarea', 'coe-field tb-textarea');
			caption.placeholder = 'Legenda (opcional)';
			caption.maxLength = captionMax;
			caption.value = draft.caption || '';
			caption.addEventListener('input', function () { draft.caption = caption.value; });
			const actions = el('div', 'tb-actions');
			actions.append(
				button('Descartar', '', function () { draft = null; view(); }),
				button('Tirar outra', '', shoot),
				button('Publicar', 'coe-button--primary', publish)
			);
			box.append(preview, caption, actions);
			return box;
		}

		function shoot() {
			if (busy || !tablet.camera) { return; }
			busy = true;
			tablet.camera().then(function (result) {
				if (!result || !result.ok) { busy = false; h.fail(result); return; }
				return shrink(result.image, settings).then(function (image) {
					busy = false;
					if (!image) { h.fail({ error: 'invalid_photo' }); return; }
					draft = { image: image, caption: draft ? draft.caption : '', token: null };
					view();
				});
			}, function () { busy = false; h.fail({ error: 'camera_unavailable' }); });
		}

		function publish() {
			if (busy || !draft) { return; }
			busy = true;
			tablet.status('Enviando foto...');
			const ready = draft.token ? Promise.resolve({ ok: true, token: draft.token }) : tablet.upload(draft.image);
			ready.then(function (uploaded) {
				if (!uploaded || !uploaded.ok) { busy = false; h.fail(uploaded); return; }
				draft.token = uploaded.token;
				return h.call('publish', { token: uploaded.token, caption: draft.caption || '' }).then(function (result) {
					busy = false;
					if (!result.ok) {
						if (result.error === 'photo_expired') { draft.token = null; }
						h.fail(result);
						return;
					}
					draft = null;
					tablet.status('Foto publicada.', 'ok');
					load(false);
				});
			}, function () { busy = false; h.fail({ error: 'upload_failed' }); });
		}

		function view() {
			root.replaceChildren();
			const bar = el('div', 'tb-toolbar');
			const tabs = el('div', 'tb-tabs');
			[{ id: 'feed', label: 'Feed' }, { id: 'mine', label: 'Meus posts' }].forEach(function (t) {
				tabs.appendChild(button(t.label, 'tb-tab' + (t.id === tab ? ' is-active' : ''), function () { tab = t.id; load(false); }));
			});
			const side = el('div', 'tb-actions');
			if (me) { side.appendChild(el('span', 'tb-muted', me)); }
			if (!draft && tablet.camera) { side.appendChild(button('Nova foto', 'coe-button--primary', shoot)); }
			bar.append(tabs, side);
			root.appendChild(bar);
			if (draft) { root.appendChild(composer()); }
			if (posts.length === 0) {
				root.appendChild(el('p', 'tb-empty', tab === 'mine' ? 'Você ainda não publicou nada.' : 'Nenhuma foto ainda. Seja o primeiro!'));
				return;
			}
			const feed = el('div', 'tb-feed');
			posts.forEach(function (post) { feed.appendChild(postCard(post)); });
			root.appendChild(feed);
			if (more) {
				const moreRow = el('div', 'tb-actions tb-more');
				moreRow.appendChild(button('Carregar mais', '', function () { load(true); }));
				root.appendChild(moreRow);
			}
		}

		function load(append) {
			const before = append && posts.length ? posts[posts.length - 1].id : undefined;
			h.call('feed', { before: before, mine: tab === 'mine' }).then(function (result) {
				if (!result.ok) { h.fail(result); return; }
				posts = append ? posts.concat(result.posts || []) : (result.posts || []);
				more = result.more === true;
				if (result.photo) { settings = result.photo; }
				captionMax = result.captionMax || captionMax;
				me = result.me || me;
				view();
			});
		}

		load(false);
	});
})();
