// Portais de notícias do COE OS (smartphone e tablet). Um script atende todos os veículos do coe_news
// (Weazel News, Rebel News): portal com editorias e busca, anúncios, redação, aprovação de anúncios e linha editorial.
(function () {
	'use strict';

	const host = window.CoePhone || window.CoeTablet;
	if (!host) { return; }

	if (!document.querySelector('link[data-coe-news]')) {
		const link = document.createElement('link');
		link.rel = 'stylesheet';
		link.href = 'nui://coe_news/html/news.css';
		link.dataset.coeNews = '1';
		document.head.appendChild(link);
	}

	const OUTLETS = ['weazel', 'rebel'];
	const PHOTO = { width: 960, quality: 0.72, maxBytes: 400000 };
	const STATUS = { draft: 'Rascunho', review: 'Em revisão', published: 'Publicada', unpublished: 'Fora do ar' };
	const AD_STATUS = { pending: 'Aguardando', active: 'No ar', rejected: 'Recusado', cancelled: 'Cancelado', expired: 'Encerrado' };

	const ERRORS = {
		not_ready: 'Portal ainda iniciando.', no_character: 'Personagem não carregado.', database_error: 'Falha ao gravar. Tente de novo.',
		unknown_action: 'Ação desconhecida.', busy: 'Aguarde a operação anterior terminar.', not_installed: 'App indisponível.',
		forbidden: 'Seu cargo não permite isso (ou você está fora do ponto).', not_found: 'Não encontrado.',
		conflict: 'Isso mudou enquanto você editava. Atualize.', invalid_action: 'Ação inválida.',
		invalid_section: 'Escolha uma editoria.', missing_title: 'Informe o título.', missing_body: 'Escreva o texto.',
		draft_limit: 'Você tem matérias abertas demais. Publique ou apague algumas.', save_cooldown: 'Aguarde um instante para salvar de novo.',
		invalid_sections: 'Escolha pelo menos uma editoria.', invalid_price: 'Preço por dia fora do limite.',
		invalid_payer: 'Escolha quem paga.', payer_forbidden: 'Você não pode usar o caixa desse negócio.',
		invalid_days: 'Escolha a duração.', missing_advertiser: 'Informe o anunciante.',
		insufficient_funds: 'Saldo insuficiente.', payment_failed: 'Pagamento recusado.', refund_failed: 'Não foi possível devolver o valor. Tente de novo.',
		ad_pending_limit: 'Você já tem anúncios demais aguardando aprovação.', ad_decided: 'Esse anúncio já foi decidido.',
		ad_slots_full: 'Não há espaço para mais anúncios no ar.', upload_failed: 'Falha ao enviar a foto.',
		photo_expired: 'A foto expirou. Tire de novo.', invalid_photo: 'Foto inválida.', camera_unavailable: 'Câmera indisponível.'
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

	function field(tag, placeholder, value, max) {
		const node = el(tag, 'coe-field');
		if (tag === 'input') { node.type = 'text'; }
		node.placeholder = placeholder || '';
		node.value = value || '';
		if (max) { node.maxLength = max; }
		return node;
	}

	function select(options, value) {
		const node = el('select', 'coe-field');
		options.forEach(function (option) {
			const item = el('option', null, option.label);
			item.value = option.id;
			node.appendChild(item);
		});
		if (value !== undefined && value !== null) { node.value = String(value); }
		return node;
	}

	function labeled(text, control) {
		const box = el('label', 'nw-label');
		box.append(el('span', null, text), control);
		return box;
	}

	function money(value) { return '$' + Number(value || 0).toLocaleString('pt-BR'); }

	function ago(at) {
		const seconds = Math.max(0, Math.floor(Date.now() / 1000) - Number(at || 0));
		if (seconds < 60) { return 'agora'; }
		if (seconds < 3600) { return Math.floor(seconds / 60) + ' min'; }
		if (seconds < 86400) { return Math.floor(seconds / 3600) + ' h'; }
		return new Date(Number(at) * 1000).toLocaleDateString('pt-BR');
	}

	function shrink(image) {
		return new Promise(function (resolve) {
			const img = new Image();
			img.onload = function () {
				const width = Math.min(PHOTO.width, img.width);
				const canvas = document.createElement('canvas');
				canvas.width = width;
				canvas.height = Math.round(img.height * (width / img.width));
				canvas.getContext('2d').drawImage(img, 0, 0, canvas.width, canvas.height);
				let quality = PHOTO.quality;
				let out = canvas.toDataURL('image/jpeg', quality);
				while (out.length > PHOTO.maxBytes && quality > 0.3) {
					quality -= 0.1;
					out = canvas.toDataURL('image/jpeg', quality);
				}
				resolve(out.length <= PHOTO.maxBytes ? out : null);
			};
			img.onerror = function () { resolve(null); };
			img.src = image;
		});
	}

	// O aparelho aceita uma ação a cada 250 ms: as chamadas passam por esta fila.
	const queue = [];
	let running = false;
	let lastSent = 0;

	function pump() {
		if (running || queue.length === 0) { return; }
		running = true;
		const job = queue.shift();
		setTimeout(function () {
			lastSent = Date.now();
			job.api.call(job.app, job.action, job.payload).then(function (result) {
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
		}, Math.max(0, lastSent + 300 - Date.now()));
	}

	const mediaCache = {};

	function portal(appId) {
		host.register(appId, function (root, api) {
			const page = el('div', 'nw-page');
			root.appendChild(page);

			let boot = null;
			let tab = 'portal';
			let section = null;
			let search = '';
			let feed = null;
			let ads = [];
			let cursor = null;
			let reading = null;
			let desk = null;
			let editing = null;
			let myAds = null;
			let adQueue = null;
			let busy = false;

			function call(action, payload) {
				return new Promise(function (resolve) {
					queue.push({ api: api, app: appId, action: action, payload: payload || {}, resolve: resolve, retries: 0 });
					pump();
				});
			}
			function fail(result) { api.status(ERRORS[result && result.error] || api.errorText(result && result.error), 'error'); }
			function guard(promise, done) {
				if (busy) { return; }
				busy = true;
				promise.then(function (result) {
					busy = false;
					if (!result || !result.ok) { fail(result); return; }
					done(result);
				}, function () { busy = false; fail({ error: 'app_error' }); });
			}

			function paint(img, image) {
				if (/^https:\/\//.test(image || '')) { img.src = image; return; }
				const match = /^media:(\d+)$/.exec(image || '');
				if (!match) { img.remove(); return; }
				const id = Number(match[1]);
				if (mediaCache[id]) { img.src = mediaCache[id]; return; }
				call('media', { id: id }).then(function (result) {
					if (!result.ok || typeof result.data !== 'string') { img.classList.add('is-missing'); return; }
					mediaCache[id] = result.data.indexOf('data:') === 0 ? result.data : 'data:image/jpeg;base64,' + result.data;
					img.src = mediaCache[id];
				});
			}

			function cover(image, className) {
				if (!image) { return null; }
				const img = el('img', className || 'nw-cover');
				img.alt = '';
				paint(img, image);
				return img;
			}

			// Navegação --------------------------------------------------------------------------------

			function tabs() {
				const role = boot.role;
				const list = [{ id: 'portal', label: 'Portal' }, { id: 'ads', label: 'Anunciar' }];
				if (role.write || role.publish) { list.push({ id: 'desk', label: 'Redação' }); }
				if (role.ads) { list.push({ id: 'queue', label: 'Anúncios' }); }
				if (role.editorial) { list.push({ id: 'editorial', label: 'Linha editorial' }); }
				const bar = el('div', 'tb-tabs nw-tabs');
				list.forEach(function (item) {
					const node = button(item.label, 'tb-tab' + (tab === item.id ? ' is-active' : ''), function () {
						tab = item.id;
						reading = null;
						editing = null;
						load();
					});
					bar.appendChild(node);
				});
				return bar;
			}

			function masthead() {
				const head = el('header', 'nw-masthead');
				const logo = el('div', 'nw-logo');
				api.icon(logo, { icon: appId === 'rebel' ? 'radio' : 'tv', color: boot.outlet.color });
				const name = el('div', 'nw-name');
				name.append(el('strong', null, boot.outlet.label), el('span', null, boot.outlet.tagline || boot.outlet.region));
				head.append(logo, name);
				return head;
			}

			function render() {
				page.replaceChildren();
				if (!boot) { page.appendChild(el('div', 'tb-empty', 'Carregando...')); return; }
				page.style.setProperty('--nw-color', boot.outlet.color);
				page.append(masthead(), tabs());
				const body = el('div', 'nw-body');
				page.appendChild(body);
				if (tab === 'portal') { reading ? renderArticle(body) : renderFeed(body); }
				else if (tab === 'ads') { renderAds(body); }
				else if (tab === 'desk') { editing ? renderEditor(body) : renderDesk(body); }
				else if (tab === 'queue') { renderQueue(body); }
				else if (tab === 'editorial') { renderEditorial(body); }
			}

			function load() {
				if (tab === 'portal' && !reading) { loadFeed(false); }
				else if (tab === 'ads') { call('myAds').then(function (r) { myAds = r.ok ? r.ads : []; render(); }); }
				else if (tab === 'desk' && !editing) { call('desk').then(function (r) { if (!r.ok) { fail(r); } desk = r.ok ? r.articles : []; render(); }); }
				else if (tab === 'queue') { call('adQueue').then(function (r) { if (!r.ok) { fail(r); } adQueue = r.ok ? r : { pending: [], active: [] }; render(); }); }
				render();
			}

			// Portal ------------------------------------------------------------------------------------

			function loadFeed(more) {
				const payload = { section: section, search: search };
				if (more && cursor) { payload.cursor = cursor; }
				call('feed', payload).then(function (result) {
					if (!result.ok) { fail(result); feed = feed || []; render(); return; }
					feed = more ? (feed || []).concat(result.articles) : result.articles;
					if (result.ads) { ads = result.ads; }
					cursor = result.cursor || null;
					render();
				});
			}

			function openArticle(id) {
				guard(call('article', { id: id }), function (result) { reading = result.article; tab = 'portal'; render(); });
			}

			function adCard(ad) {
				const box = el('div', 'nw-ad');
				box.append(el('span', 'nw-kicker', 'Publicidade · ' + ad.advertiser), el('strong', null, ad.title), el('p', null, ad.body));
				return box;
			}

			function articleCard(article, lead) {
				const box = el('button', 'nw-card' + (lead ? ' nw-card--lead' : ''));
				box.type = 'button';
				const img = cover(article.image, 'nw-thumb');
				if (img) { box.appendChild(img); }
				const text = el('div', 'nw-card-text');
				const kicker = el('span', 'nw-kicker', (article.breaking ? 'URGENTE · ' : '') + article.sectionLabel);
				text.append(kicker, el('strong', null, article.title));
				if (lead && article.summary) { text.appendChild(el('p', null, article.summary)); }
				text.appendChild(el('span', 'tb-muted', article.byline + ' · ' + ago(article.publishedAt)));
				box.appendChild(text);
				box.addEventListener('click', function () { openArticle(article.id); });
				return box;
			}

			function renderFeed(body) {
				const bar = el('div', 'nw-sections');
				[{ id: null, label: 'Tudo' }].concat(boot.outlet.sections).forEach(function (item) {
					bar.appendChild(button(item.label, 'nw-chip' + (section === item.id ? ' is-active' : ''), function () {
						section = item.id;
						feed = null;
						loadFeed(false);
						render();
					}));
				});
				const find = field('input', 'Buscar matérias', search, 40);
				find.addEventListener('keydown', function (event) {
					if (event.key === 'Enter') { search = find.value.trim(); feed = null; loadFeed(false); render(); }
				});
				body.append(bar, find);
				if (feed === null) { body.appendChild(el('div', 'tb-empty', 'Carregando...')); return; }
				if (feed.length === 0) {
					body.appendChild(el('div', 'tb-empty', search ? 'Nada encontrado.' : 'Nenhuma matéria publicada ainda.'));
				}
				const every = boot.limits.ads.FeedEvery || 4;
				let adIndex = 0;
				feed.forEach(function (article, index) {
					body.appendChild(articleCard(article, index === 0 && !search));
					if ((index + 1) % every === 0 && ads.length > 0) {
						body.appendChild(adCard(ads[adIndex % ads.length]));
						adIndex += 1;
					}
				});
				if (feed.length > 0 && feed.length < every && ads.length > 0) { body.appendChild(adCard(ads[0])); }
				if (cursor) { body.appendChild(button('Carregar mais', '', function () { loadFeed(true); })); }
			}

			function renderArticle(body) {
				const article = reading;
				body.appendChild(button('‹ Voltar', 'nw-back', function () { reading = null; render(); }));
				const box = el('article', 'nw-article');
				box.appendChild(el('span', 'nw-kicker', (article.breaking ? 'URGENTE · ' : '') + article.sectionLabel));
				box.appendChild(el('h2', null, article.title));
				if (article.summary) { box.appendChild(el('p', 'nw-summary', article.summary)); }
				const meta = 'Por ' + article.byline + (article.publishedAt ? ' · ' + ago(article.publishedAt) : '') +
					(article.status && article.status !== 'published' ? ' · ' + STATUS[article.status] : ' · ' + article.views + ' leituras');
				box.appendChild(el('span', 'tb-muted', meta));
				const img = cover(article.image);
				if (img) { box.appendChild(img); }
				String(article.body || '').split(/\n\n+/).forEach(function (paragraph) { box.appendChild(el('p', null, paragraph)); });
				body.appendChild(box);
			}

			// Anunciar -----------------------------------------------------------------------------------

			function renderAds(body) {
				const limits = boot.limits.ads;
				const form = el('div', 'coe-panel coe-panel--compact nw-form');
				form.appendChild(el('strong', null, 'Anuncie no ' + boot.outlet.label));
				form.appendChild(el('span', 'tb-muted', money(boot.outlet.adPrice) + ' por dia. O valor fica retido até o veículo aprovar; recusado, volta para você.'));
				const advertiser = field('input', 'Anunciante (você ou sua empresa)', '', limits.AdvertiserMax);
				const title = field('input', 'Título', '', limits.TitleMax);
				const text = field('textarea', 'Texto do anúncio', '', limits.BodyMax);
				const days = select(boot.outlet.adDays.map(function (d) { return { id: d, label: d + (d === 1 ? ' dia' : ' dias') + ' · ' + money(d * boot.outlet.adPrice) }; }));
				const payer = select(boot.payers);
				form.append(advertiser, title, text, labeled('Duração', days), labeled('Pagamento', payer));
				form.appendChild(button('Enviar para aprovação', 'coe-button--primary', function () {
					guard(call('adBuy', { advertiser: advertiser.value, title: title.value, body: text.value, days: Number(days.value), payer: payer.value }), function (result) {
						api.status('Anúncio enviado. ' + money(result.price) + ' retidos até a aprovação.', 'success');
						load();
					});
				}));
				body.appendChild(form);
				body.appendChild(el('div', 'tb-title', 'Meus anúncios'));
				if (myAds === null) { body.appendChild(el('div', 'tb-empty', 'Carregando...')); return; }
				if (myAds.length === 0) { body.appendChild(el('div', 'tb-empty', 'Você ainda não anunciou aqui.')); }
				myAds.forEach(function (ad) {
					const card = el('div', 'coe-panel coe-panel--compact nw-row');
					const info = el('div', 'nw-row-text');
					info.append(el('strong', null, ad.title), el('span', 'tb-muted', AD_STATUS[ad.status] + ' · ' + ad.days + 'd · ' + money(ad.price) +
						(ad.status === 'active' ? ' · até ' + new Date(ad.endsAt * 1000).toLocaleString('pt-BR') : '')));
					if (ad.note) { info.appendChild(el('span', 'nw-note', ad.note)); }
					card.appendChild(info);
					if (ad.status === 'pending') {
						card.appendChild(button('Cancelar', 'coe-button--danger', function () {
							guard(call('adCancel', { id: ad.id }), function () { api.status('Anúncio cancelado. Valor devolvido.', 'success'); load(); });
						}));
					}
					body.appendChild(card);
				});
			}

			// Redação ------------------------------------------------------------------------------------

			function renderDesk(body) {
				if (boot.role.write) {
					body.appendChild(button('Nova matéria', 'coe-button--primary', function () {
						editing = { section: boot.outlet.sections[0] && boot.outlet.sections[0].id, title: '', summary: '', body: '', anonymous: false, image: '' };
						render();
					}));
				}
				if (desk === null) { body.appendChild(el('div', 'tb-empty', 'Carregando...')); return; }
				if (desk.length === 0) { body.appendChild(el('div', 'tb-empty', 'Nenhuma matéria na mesa.')); }
				desk.forEach(function (article) {
					const card = el('button', 'coe-panel coe-panel--compact nw-row');
					card.type = 'button';
					const info = el('div', 'nw-row-text');
					info.append(el('strong', null, article.title),
						el('span', 'tb-muted', STATUS[article.status] + ' · ' + article.sectionLabel + ' · ' + article.authorName + ' · ' + ago(article.updatedAt)));
					if (article.note) { info.appendChild(el('span', 'nw-note', 'Editor: ' + article.note)); }
					card.append(el('span', 'nw-status nw-status--' + article.status, STATUS[article.status]), info);
					card.addEventListener('click', function () {
						guard(call('article', { id: article.id, desk: true }), function (result) { editing = result.article; render(); });
					});
					body.appendChild(card);
				});
			}

			function act(action, payload, message) {
				guard(call(action, payload), function (result) {
					api.status(result.breakingDenied ? message + ' (urgente em espera: aguarde o intervalo)' : message, 'success');
					editing = null;
					load();
				});
			}

			function renderEditor(body) {
				const article = editing;
				const limits = boot.limits.article;
				const role = boot.role;
				const isNew = !article.id;
				const mine = isNew || article.mine;
				const canEdit = isNew || (article.status === 'draft' && mine) || (article.status === 'review' && (mine || role.publish)) || role.publish;
				body.appendChild(button('‹ Redação', 'nw-back', function () { editing = null; load(); }));
				const form = el('div', 'coe-panel coe-panel--compact nw-form');
				if (!isNew) {
					form.appendChild(el('span', 'nw-status nw-status--' + article.status, STATUS[article.status] + ' · ' + article.authorName));
					if (article.note) { form.appendChild(el('span', 'nw-note', 'Editor: ' + article.note)); }
				}
				const sectionField = select(boot.outlet.sections, article.section);
				const title = field('input', 'Título', article.title, limits.TitleMax);
				const summary = field('textarea', 'Linha fina (resumo)', article.summary, limits.LeadMax);
				summary.rows = 2;
				const text = field('textarea', 'Texto da matéria. Separe parágrafos com uma linha em branco.', article.body, limits.BodyMax);
				text.rows = 10;
				const anonymous = el('input');
				anonymous.type = 'checkbox';
				anonymous.checked = article.anonymous === true;
				const anonLabel = el('label', 'nw-check');
				anonLabel.append(anonymous, el('span', null, 'Assinar como "Redação"'));
				form.append(labeled('Editoria', sectionField), title, summary, text, anonLabel);

				const photo = el('div', 'nw-photo');
				const preview = article.photo ? el('img', 'nw-cover') : cover(article.removeImage ? '' : article.image);
				if (article.photo) { preview.src = article.photo; }
				if (preview) { photo.appendChild(preview); }
				photo.appendChild(button(preview ? 'Trocar foto' : 'Tirar foto de capa', '', function () {
					if (busy || !api.camera) { return; }
					keep();
					busy = true;
					api.camera().then(function (result) {
						if (!result || !result.ok) { busy = false; fail(result); return; }
						return shrink(result.image).then(function (image) {
							busy = false;
							if (!image) { fail({ error: 'invalid_photo' }); return; }
							editing.photo = image;
							editing.token = null;
							render();
						});
					}, function () { busy = false; fail({ error: 'camera_unavailable' }); });
				}));
				if (preview) {
					photo.appendChild(button('Sem foto', '', function () { keep(); editing.photo = null; editing.token = null; editing.removeImage = true; render(); }));
				}
				form.appendChild(photo);

				function keep() {
					editing.section = sectionField.value;
					editing.title = title.value;
					editing.summary = summary.value;
					editing.body = text.value;
					editing.anonymous = anonymous.checked;
				}

				// Salva (enviando a foto nova, se houver) e devolve o id da matéria.
				function save() {
					keep();
					const upload = editing.photo && !editing.token ? api.upload(editing.photo) : Promise.resolve({ ok: true, token: editing.token });
					return upload.then(function (uploaded) {
						if (!uploaded || !uploaded.ok) { return uploaded || { ok: false, error: 'upload_failed' }; }
						editing.token = uploaded.token || null;
						return call('save', {
							id: editing.id, section: editing.section, title: editing.title, summary: editing.summary, body: editing.body,
							anonymous: editing.anonymous, token: editing.token || undefined, removeImage: editing.removeImage === true
						}).then(function (result) {
							if (result.ok) {
								editing.id = result.id;
								if (editing.token) { editing.photo = null; editing.token = null; }
							} else if (result.error === 'photo_expired') {
								editing.token = null;
							}
							return result;
						});
					});
				}

				const actions = el('div', 'nw-actions');
				if (canEdit) {
					actions.appendChild(button('Salvar', '', function () {
						guard(save(), function () { api.status('Matéria salva.', 'success'); editing.mine = editing.mine || isNew; if (isNew) { editing.status = 'draft'; editing.authorName = 'Você'; } render(); });
					}));
				}
				const status = article.status || 'draft';
				if (mine && status === 'draft' && role.write) {
					actions.appendChild(button('Enviar para revisão', 'coe-button--primary', function () {
						guard(save(), function (result) { act('submit', { id: result.id }, 'Matéria enviada para revisão.'); });
					}));
				}
				const note = field('input', 'Observação para o autor (opcional)', '', limits.NoteMax);
				const breaking = el('input');
				breaking.type = 'checkbox';
				const breakingLabel = el('label', 'nw-check');
				breakingLabel.append(breaking, el('span', null, 'Urgente (avisa os leitores)'));
				if (role.publish && status !== 'published') {
					actions.appendChild(breakingLabel);
					actions.appendChild(button('Publicar', 'coe-button--primary', function () {
						guard(save(), function (result) { act('publish', { id: result.id, breaking: breaking.checked }, 'Matéria publicada.'); });
					}));
				}
				if (role.publish && !isNew && (status === 'review' || status === 'published')) {
					actions.appendChild(note);
					if (status === 'review') {
						actions.appendChild(button('Devolver ao autor', '', function () { act('reject', { id: article.id, note: note.value }, 'Matéria devolvida.'); }));
					} else {
						actions.appendChild(button('Tirar do ar', 'coe-button--danger', function () { act('unpublish', { id: article.id, note: note.value }, 'Matéria retirada do ar.'); }));
					}
				}
				if (!isNew && (role.publish || (mine && (status === 'draft' || status === 'review')))) {
					actions.appendChild(button('Apagar', 'coe-button--danger', function () { act('remove', { id: article.id }, 'Matéria apagada.'); }));
				}
				form.appendChild(actions);
				body.appendChild(form);
			}

			// Aprovação de anúncios ------------------------------------------------------------------------

			function renderQueue(body) {
				if (adQueue === null) { body.appendChild(el('div', 'tb-empty', 'Carregando...')); return; }
				body.appendChild(el('div', 'tb-title', 'Aguardando aprovação'));
				if (adQueue.pending.length === 0) { body.appendChild(el('div', 'tb-empty', 'Nenhum anúncio na fila.')); }
				adQueue.pending.forEach(function (ad) {
					const card = el('div', 'coe-panel coe-panel--compact nw-form');
					card.append(adCard(ad), el('span', 'tb-muted', ad.days + 'd · ' + money(ad.price) + ' · enviado ' + ago(ad.createdAt)));
					const note = field('input', 'Observação (opcional)', '', boot.limits.ads.NoteMax);
					const actions = el('div', 'nw-actions');
					actions.append(note,
						button('Aprovar', 'coe-button--primary', function () {
							guard(call('adDecide', { id: ad.id, approve: true, note: note.value }), function () { api.status('Anúncio no ar. ' + money(ad.price) + ' no caixa.', 'success'); load(); });
						}),
						button('Recusar', 'coe-button--danger', function () {
							guard(call('adDecide', { id: ad.id, approve: false, note: note.value }), function () { api.status('Anúncio recusado e valor devolvido.', 'success'); load(); });
						}));
					card.appendChild(actions);
					body.appendChild(card);
				});
				body.appendChild(el('div', 'tb-title', 'No ar'));
				if (adQueue.active.length === 0) { body.appendChild(el('div', 'tb-empty', 'Nenhum anúncio no ar.')); }
				adQueue.active.forEach(function (ad) {
					const card = el('div', 'coe-panel coe-panel--compact nw-row');
					const info = el('div', 'nw-row-text');
					info.append(el('strong', null, ad.advertiser + ' · ' + ad.title), el('span', 'tb-muted', 'até ' + new Date(ad.endsAt * 1000).toLocaleString('pt-BR')));
					card.appendChild(info);
					body.appendChild(card);
				});
			}

			// Linha editorial --------------------------------------------------------------------------------

			function renderEditorial(body) {
				const limits = boot.limits;
				const form = el('div', 'coe-panel coe-panel--compact nw-form');
				const tagline = field('input', 'Slogan', boot.outlet.tagline, limits.editorial.TaglineMax);
				const editorial = field('textarea', 'Linha editorial: o que o veículo cobre e como', boot.outlet.editorial, limits.editorial.EditorialMax);
				editorial.rows = 6;
				const active = {};
				boot.outlet.sections.forEach(function (s) { active[s.id] = true; });
				const checks = el('div', 'nw-checks');
				const boxes = boot.allSections.map(function (s) {
					const box = el('input');
					box.type = 'checkbox';
					box.checked = active[s.id] === true;
					box.value = s.id;
					const label = el('label', 'nw-check');
					label.append(box, el('span', null, s.label));
					checks.appendChild(label);
					return box;
				});
				const price = el('input', 'coe-field');
				price.type = 'number';
				price.min = limits.ads.MinPricePerDay;
				price.max = limits.ads.MaxPricePerDay;
				price.value = boot.outlet.adPrice;
				form.append(labeled('Slogan', tagline), labeled('Linha editorial', editorial), labeled('Editorias', checks),
					labeled('Preço do anúncio por dia ($' + limits.ads.MinPricePerDay + ' a $' + limits.ads.MaxPricePerDay + ')', price));
				form.appendChild(button('Salvar linha editorial', 'coe-button--primary', function () {
					const sections = boxes.filter(function (b) { return b.checked; }).map(function (b) { return b.value; });
					guard(call('editorial', { tagline: tagline.value, editorial: editorial.value, sections: sections, adPrice: Number(price.value) }), function () {
						api.status('Linha editorial salva.', 'success');
						boot = null;
						start();
					});
				}));
				body.appendChild(form);
				body.appendChild(el('span', 'tb-muted', 'Matérias antigas continuam na editoria em que foram publicadas.'));
			}

			function start() {
				render();
				call('state').then(function (result) {
					if (!result.ok) { fail(result); page.replaceChildren(el('div', 'tb-empty', ERRORS[result.error] || 'Portal indisponível.')); return; }
					boot = result;
					if (section && !boot.outlet.sections.some(function (s) { return s.id === section; })) { section = null; }
					if (tab === 'editorial' && !boot.role.editorial) { tab = 'portal'; }
					load();
				});
			}

			start();
		});
	}

	OUTLETS.forEach(portal);
})();
