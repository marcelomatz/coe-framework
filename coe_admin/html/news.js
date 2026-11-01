// Aba "Imprensa": Weazel News, Rebel News e qualquer outro veículo do coe_news. Gerencia o negócio e seus recursos,
// a linha editorial, a equipe e os cargos, os equipamentos (estoque no baú e frota), a publicidade e as matérias.
// Usa os helpers de app.js (bizEl, bizField, bizInput, renderBusinessGrades, renderBusinessStaff, bizVehicleCard).
// O servidor confere a permissão (manageNews) e valida de novo cada ação.
state.news = {
	outlet: null,
	section: 'overview',
	team: null,
	editorial: null,
	ads: { group: 'pending', list: null, error: null, requestId: null },
	articles: { status: '', search: '', list: null, error: null, requestId: null, open: null, openRequestId: null },
	equipment: { data: null, error: null, requestId: null, count: {} },
	pending: {},
	fleetSearch: ''
};

const NEWS_SECTIONS = [
	['overview', 'Visão geral'], ['business', 'Negócio e recursos'], ['editorial', 'Linha editorial'], ['team', 'Equipe e cargos'],
	['equipment', 'Equipamentos e frota'], ['ads', 'Publicidade'], ['articles', 'Matérias']
];
const NEWS_AD_GROUPS = [['pending', 'Pendentes'], ['active', 'No ar'], ['history', 'Histórico']];
const NEWS_AD_STATUS = { pending: 'Pendente', active: 'No ar', expired: 'Expirado', rejected: 'Recusado', cancelled: 'Cancelado', removed: 'Retirado' };
const NEWS_ARTICLE_STATUS = { draft: 'Rascunho', review: 'Em revisão', published: 'Publicada', unpublished: 'Fora do ar' };
const NEWS_REFUND = [['none', 'Sem estorno'], ['remaining', 'Estornar os dias restantes'], ['full', 'Estornar o valor total']];

function newsData() {
	return state.data?.news || null;
}

function newsList(value) {
	if (Array.isArray(value)) return value;
	return value && typeof value === 'object' ? Object.values(value) : [];
}

function newsOutlet() {
	const data = newsData();
	return newsList(data?.outlets).find((outlet) => outlet.id === state.news.outlet) || null;
}

function newsBusiness(outlet) {
	return outlet ? newsData()?.businesses?.[outlet.business] || null : null;
}

function newsMoney(value) {
	return typeof value === 'number' ? '$ ' + value.toLocaleString('pt-BR') : '—';
}

function newsDate(epoch) {
	return epoch ? new Date(epoch * 1000).toLocaleString('pt-BR', { dateStyle: 'short', timeStyle: 'short' }) : '—';
}

function newsMessage(text, success) {
	const message = document.getElementById('news-message');
	if (!message) return;
	message.textContent = text || '';
	message.classList.toggle('is-success', success === true);
}

function newsButton(text, onClick, extra = '') {
	const button = bizEl('button', `coe-button biz-small-button ${extra}`.trim(), text);
	button.type = 'button';
	button.addEventListener('click', onClick);
	return button;
}

function newsStat(label, value) {
	const box = bizEl('div', 'bank-stat');
	box.append(bizEl('span', '', label), bizEl('strong', '', value === undefined || value === null ? '—' : String(value)));
	return box;
}

function newsRow(title, details, actions) {
	const row = bizEl('div', 'bank-row');
	const info = bizEl('div', 'bank-row-info');
	info.append(bizEl('strong', '', title));
	for (const detail of details.filter(Boolean)) info.append(bizEl('span', 'biz-hint', detail));
	row.append(info);
	if (actions && actions.length) {
		const box = bizEl('div', 'bank-row-actions');
		box.append(...actions);
		row.append(box);
	}
	return row;
}

function newsBlock(title, hint) {
	const block = bizEl('div', 'biz-block');
	block.append(bizEl('h3', '', title));
	if (hint) block.append(bizEl('p', 'biz-hint', hint));
	return block;
}

// Envio --------------------------------------------------------------------------------------------------------

async function newsAction(op, payload, confirmOptions) {
	if (confirmOptions && !(await CoeUI.confirm(confirmOptions))) return;
	newsMessage('Enviando...');
	const result = await postNui('newsAction', { op, payload });
	if (!result.ok) {
		newsMessage('Não foi possível enviar a ação.', false);
		return;
	}
	state.news.pending[result.requestId] = op;
}

function newsQuery(kind, payload) {
	return postNui('newsQuery', { kind, payload }).then((result) => (result.ok ? result.requestId : null));
}

function newsLoadAds() {
	const outlet = newsOutlet();
	if (!outlet) return;
	const ads = state.news.ads;
	ads.list = null;
	ads.error = null;
	newsQuery('ads', { outlet: outlet.id, group: ads.group }).then((requestId) => { ads.requestId = requestId; });
}

function newsLoadArticles() {
	const outlet = newsOutlet();
	if (!outlet) return;
	const articles = state.news.articles;
	articles.list = null;
	articles.error = null;
	newsQuery('articles', { outlet: outlet.id, status: articles.status || null, search: articles.search || null })
		.then((requestId) => { articles.requestId = requestId; });
}

function newsLoadEquipment() {
	const outlet = newsOutlet();
	if (!outlet) return;
	const equipment = state.news.equipment;
	equipment.data = null;
	equipment.error = null;
	newsQuery('equipment', { outlet: outlet.id }).then((requestId) => { equipment.requestId = requestId; });
}

function newsLoadSection() {
	if (state.news.section === 'ads') newsLoadAds();
	if (state.news.section === 'articles') newsLoadArticles();
	if (state.news.section === 'equipment') newsLoadEquipment();
}

const NEWS_ERRORS = {
	forbidden: 'Sem permissão.', not_ready: 'O coe_news ainda está iniciando.', busy: 'Aguarde um instante.',
	database_error: 'Banco indisponível.', no_stash: 'O negócio não tem baú cadastrado (aba Negócios > Pontos).',
	not_found: 'Matéria não encontrada.', invalid_query: 'Consulta inválida.'
};

function onNewsData(data) {
	const news = state.news;
	const error = data.error ? NEWS_ERRORS[data.error] || 'Não foi possível carregar.' : null;
	if (data.kind === 'ads' && data.requestId === news.ads.requestId) {
		news.ads.list = data.result?.ads || [];
		news.ads.error = error;
	} else if (data.kind === 'articles' && data.requestId === news.articles.requestId) {
		news.articles.list = data.result?.articles || [];
		news.articles.error = error;
	} else if (data.kind === 'article' && data.requestId === news.articles.openRequestId) {
		news.articles.open = data.result?.article || null;
		if (error) newsMessage(error, false);
	} else if (data.kind === 'equipment' && data.requestId === news.equipment.requestId) {
		news.equipment.data = data.result || null;
		news.equipment.error = error;
	} else {
		return;
	}
	renderNewsBody();
}

function onNewsResult(data) {
	const op = state.news.pending[data.requestId];
	delete state.news.pending[data.requestId];
	newsMessage(data.message, data.success === true);
	if (data.success !== true) return;
	if (op === 'team') state.news.team = null;
	if (op === 'editorial') state.news.editorial = null;
	if (op && op.startsWith('ad')) newsLoadAds();
	if (op && op.startsWith('article')) {
		state.news.articles.open = null;
		newsLoadArticles();
	}
	if (op === 'stock') newsLoadEquipment();
}

// Seções -------------------------------------------------------------------------------------------------------

function newsOverview(outlet, business, body) {
	const data = newsData();
	const stats = outlet.stats || { articles: {}, ads: {} };
	const staff = newsList(business?.staff);
	const online = data.online || {};
	const onlineCount = staff.filter((member) => online[String(member.characterId)]).length;
	const garages = newsList(data.garages?.[outlet.business]);
	const vehicles = garages.reduce((total, garage) => total + newsList(garage.fleet).length, 0);

	const content = newsBlock('Conteúdo');
	const contentGrid = bizEl('div', 'bank-stats');
	contentGrid.append(
		newsStat('Publicadas', stats.articles.published || 0), newsStat('Em revisão', stats.articles.review || 0),
		newsStat('Rascunhos', stats.articles.draft || 0), newsStat('Fora do ar', stats.articles.unpublished || 0),
		newsStat('Leituras', (stats.views || 0).toLocaleString('pt-BR')), newsStat('Publicadas em 30 dias', stats.publishedRecent || 0)
	);
	content.append(contentGrid);

	const ads = newsBlock('Publicidade');
	const adsGrid = bizEl('div', 'bank-stats');
	adsGrid.append(
		newsStat('No ar', stats.ads.active || 0), newsStat('Aguardando aprovação', stats.ads.pending || 0),
		newsStat('Receita total', newsMoney(stats.revenue || 0)), newsStat('Receita em 30 dias', newsMoney(stats.revenueRecent || 0)),
		newsStat('Preço por dia', newsMoney(outlet.adPrice))
	);
	ads.append(adsGrid);

	const company = newsBlock('Negócio');
	const companyGrid = bizEl('div', 'bank-stats');
	companyGrid.append(
		newsStat('Caixa da sociedade', newsMoney(outlet.balance)), newsStat('Dono', business?.owner?.name || 'Sem dono'),
		newsStat('Equipe', staff.length), newsStat('Online agora', onlineCount),
		newsStat('De ponto agora', data.duty?.[outlet.business] || 0), newsStat('Veículos de frota', vehicles)
	);
	company.append(companyGrid);
	if (!business) company.append(bizEl('p', 'biz-hint', `O negócio ${outlet.business} ainda não existe. Ele é criado na primeira subida do coe_news com o coe_businesses iniciado.`));
	body.append(content, ads, company);
}

function newsPoint(entry) {
	return entry && Number.isFinite(entry.x) ? `${entry.x.toFixed(1)}, ${entry.y.toFixed(1)}, ${entry.z.toFixed(1)}` : 'não marcado';
}

function newsBusinessSection(outlet, business, body) {
	if (!business) {
		body.append(bizEl('div', 'empty-state', `O negócio ${outlet.business} não foi encontrado no coe_businesses.`));
		return;
	}
	const id = newsBlock('Identificação');
	const grid = bizEl('div', 'bank-stats');
	grid.append(
		newsStat('ID do negócio', business.id), newsStat('Nome', business.label), newsStat('Região', outlet.region || '—'),
		newsStat('Situação', business.enabled === false ? 'Inativo' : 'Ativo'), newsStat('Dono', business.owner?.name || 'Sem dono'),
		newsStat('Sócios', newsList(business.partners).length)
	);
	id.append(grid);
	body.append(id);

	const area = business.area || {};
	const resources = newsBlock('Recursos no mapa', 'Área de atuação, ponto da redação e baús. O baú "Arquivo" guarda o estoque de equipamentos.');
	resources.append(newsRow('Área', [area.kind === 'polygon' ? `Polígono com ${newsList(area.points).length} pontos` : `Círculo de ${area.radius || 0} m em ${newsPoint(area)}`]));
	for (const clock of newsList(business.stations?.clocks)) resources.append(newsRow(`Ponto: ${clock.label || clock.id}`, [newsPoint(clock)]));
	for (const stash of newsList(business.stations?.stashes)) {
		resources.append(newsRow(`Baú: ${stash.label || stash.id}`, [newsPoint(stash), stash.slots ? `${stash.slots} espaços` : '']));
	}
	body.append(resources);

	const rules = business.rules || {};
	const rulesBlock = newsBlock('Regras de trabalho');
	rulesBlock.append(newsRow('Ponto', [
		rules.clockRequired === false ? 'A equipe trabalha sem bater ponto.' : 'A equipe precisa bater o ponto.',
		rules.clockOffsite ? 'O ponto continua aberto fora da área (pautas na rua).' : 'Sair da área encerra o ponto.',
		rules.multiJob === false ? 'Dedicação exclusiva.' : 'A equipe pode ter outros empregos.'
	]));
	body.append(rulesBlock);

	if (state.data?.permissions?.manageBusinesses) {
		const link = newsButton('Editar área, pontos, regras e dono na aba Negócios', () => {
			state.biz.category = business.category;
			state.biz.mode = null;
			state.biz.draft = JSON.parse(JSON.stringify(business));
			state.biz.draft.stations = state.biz.draft.stations || {};
			state.biz.draft.rules = state.biz.draft.rules || {};
			state.biz.isNew = false;
			state.biz.section = 'general';
			setView('businesses');
			renderBusinesses();
			renderBusinessEditor();
		});
		body.append(link);
	} else {
		body.append(bizEl('p', 'biz-hint', 'Área, pontos, regras e dono são editados na aba Negócios (permissão de negócios).'));
	}
}

function newsEditorial(outlet, body) {
	const data = newsData();
	const limits = data.limits || {};
	if (!state.news.editorial || state.news.editorial.outlet !== outlet.id) {
		state.news.editorial = {
			outlet: outlet.id, tagline: outlet.tagline || '', editorial: outlet.editorial || '',
			sections: newsList(outlet.sections).slice(), adPrice: outlet.adPrice
		};
	}
	const draft = state.news.editorial;
	const block = newsBlock('Linha editorial', 'Aparece no portal do veículo. A equipe com news.editorial também pode editar pelo app.');
	block.append(bizField(`Slogan (até ${limits.taglineMax || 80})`, bizInput('text', draft.tagline, (value) => { draft.tagline = value; }, { maxlength: limits.taglineMax || 80 })));
	const text = bizEl('textarea', 'coe-field field-control');
	text.rows = 5;
	text.maxLength = limits.editorialMax || 600;
	text.value = draft.editorial;
	text.addEventListener('input', () => { draft.editorial = text.value; });
	block.append(bizField(`Texto da linha editorial (até ${limits.editorialMax || 600})`, text));
	const sections = bizEl('div', 'biz-staff');
	for (const section of newsList(data.sections)) {
		const box = document.createElement('input');
		box.type = 'checkbox';
		box.checked = draft.sections.includes(section.id);
		box.addEventListener('change', () => {
			draft.sections = draft.sections.filter((entry) => entry !== section.id);
			if (box.checked) draft.sections.push(section.id);
		});
		const label = bizEl('label', 'biz-check');
		label.append(box, bizEl('span', '', section.label));
		sections.append(label);
	}
	block.append(bizEl('span', 'field-label', 'Editorias ativas'), sections);
	block.append(bizField(`Preço do anúncio por dia (${newsMoney(limits.minPrice)} a ${newsMoney(limits.maxPrice)})`,
		bizInput('number', draft.adPrice, (value) => { draft.adPrice = value; }, { min: limits.minPrice || 0, max: limits.maxPrice || 0 })));
	body.append(block);
	const actions = bizEl('div', 'biz-actions');
	actions.append(newsButton('Salvar linha editorial', () => newsAction('editorial', {
		outlet: outlet.id, tagline: draft.tagline, editorial: draft.editorial, sections: draft.sections, adPrice: Number(draft.adPrice)
	}), 'coe-button--primary'));
	body.append(actions);
}

function newsTeam(outlet, business, body) {
	if (!business) {
		body.append(bizEl('div', 'empty-state', 'O negócio do veículo ainda não existe.'));
		return;
	}
	if (!state.news.team || state.news.team.id !== business.id) {
		state.news.team = JSON.parse(JSON.stringify(business));
		state.news.team.staffAdd = [];
	}
	const draft = state.news.team;
	const data = newsData();
	const online = data.online || {};
	const roster = newsBlock('Quem está na redação', 'Online e cargo de cada um. "De ponto" é o total do negócio agora.');
	const grades = new Map(newsList(draft.grades).map((grade) => [grade.id, grade]));
	if (business.owner) roster.append(newsRow(`${business.owner.name} · Dono`, [online[String(business.owner.characterId)] ? 'Online' : 'Offline']));
	for (const member of newsList(business.staff)) {
		const grade = grades.get(member.grade);
		roster.append(newsRow(`${member.name || member.characterId} · ${grade?.label || member.grade || 'sem cargo'}`,
			[online[String(member.characterId)] ? 'Online' : 'Offline', grade ? `Salário ${newsMoney(Number(grade.salary) || 0)}` : '']));
	}
	if (!business.owner && !newsList(business.staff).length) roster.append(bizEl('p', 'biz-hint', 'Sem dono e sem equipe.'));
	roster.append(bizEl('p', 'biz-hint', `De ponto agora: ${data.duty?.[business.id] || 0}`));
	body.append(roster);
	body.append(renderBusinessGrades(draft, data.permissions));
	body.append(renderBusinessStaff(draft));
	const actions = bizEl('div', 'biz-actions');
	actions.append(newsButton('Salvar equipe e cargos', () => newsAction('team', {
		business: draft.id,
		grades: newsList(draft.grades).map((grade) => ({
			id: grade.id, label: grade.label, level: Number(grade.level), salary: Number(grade.salary), permissions: grade.permissions || []
		})),
		staff: newsList(draft.staff).map((member) => ({ characterId: member.characterId, grade: member.grade })),
		staffAddStateIds: newsList(draft.staffAdd).map((entry) => entry.stateId),
		staffAddGrades: Object.fromEntries(newsList(draft.staffAdd).filter((entry) => entry.grade).map((entry) => [entry.stateId, entry.grade]))
	}), 'coe-button--primary'), newsButton('Descartar alterações', () => {
		state.news.team = null;
		renderNewsBody();
	}));
	body.append(actions);
}

function newsItemImage(name) {
	const image = bizEl('img');
	image.src = `nui://coe_inventory/data/images/${encodeURIComponent(name)}.png`;
	image.alt = '';
	image.width = 48;
	image.height = 48;
	image.addEventListener('error', () => image.remove(), { once: true });
	return image;
}

function newsEquipment(outlet, body) {
	const data = newsData();
	const equipment = state.news.equipment;
	const stock = newsBlock('Equipamentos de imprensa',
		'Estoque no baú do veículo. A equipe retira no baú; usar o item segura a câmera, o microfone ou o boom (X guarda).');
	if (equipment.error) stock.append(bizEl('p', 'biz-hint', equipment.error));
	else if (!equipment.data) stock.append(bizEl('p', 'biz-hint', 'Carregando estoque...'));
	else {
		stock.append(bizEl('p', 'biz-hint', `Baú: ${equipment.data.stash?.label || '—'}`));
		const max = data.limits?.maxPerOperation || 20;
		for (const item of newsList(equipment.data.items)) {
			const row = bizEl('div', 'bank-row');
			const info = bizEl('div', 'bank-row-info');
			const holders = newsList(item.holders).map((holder) => `${holder.name}${holder.owner ? ' (dono)' : ''}: ${holder.count}`);
			info.append(bizEl('strong', '', `${item.label} · ${item.stock} no baú`),
				bizEl('span', 'biz-hint', holders.length ? `Com a equipe: ${holders.join(', ')}` : 'Ninguém da equipe está com este equipamento.'));
			const quantity = bizInput('number', equipment.count[item.name] || 1, (value) => { equipment.count[item.name] = value; }, { min: 1, max });
			quantity.style.width = '72px';
			const actions = bizEl('div', 'bank-row-actions');
			const send = (op) => newsAction('stock', { outlet: outlet.id, item: item.name, op, count: Number(equipment.count[item.name] || 1) });
			actions.append(quantity, newsButton('Abastecer', () => send('add')), newsButton('Retirar', () => send('remove'), 'biz-danger'));
			row.prepend(newsItemImage(item.name));
			row.append(info, actions);
			stock.append(row);
		}
	}
	stock.append(newsButton('Atualizar estoque', newsLoadEquipment));
	body.append(stock);

	const fleet = newsBlock('Frota de reportagem', 'Veículos das garagens de negócio deste veículo. Para ter frota, crie uma garagem do tipo Negócio na aba Garagens.');
	const garages = newsList(data.garages?.[outlet.business]);
	if (!garages.length) fleet.append(bizEl('p', 'biz-hint', `Nenhuma garagem de negócio ligada a ${outlet.business}.`));
	const catalog = newsList(data.vehicleCatalog);
	const names = new Map(catalog.map((entry) => [entry.model, entry.name]));
	for (const garage of garages) {
		const vehicles = newsList(garage.fleet);
		fleet.append(bizEl('h3', '', `${garage.label || garage.id} (${vehicles.length})`));
		const grid = bizEl('div', 'biz-vehicle-grid');
		for (const vehicle of vehicles) {
			const remove = newsButton('Remover', () => newsAction('fleetRemove', { garage: garage.id, vehicleId: vehicle.vehicleId }, {
				title: 'Remover da frota', message: `Remover ${names.get(vehicle.model) || vehicle.model} (${vehicle.plate}) da frota?`, confirmLabel: 'Remover', danger: true
			}), 'biz-danger');
			remove.disabled = vehicle.state !== 'stored';
			remove.title = vehicle.state === 'stored' ? '' : 'O veículo está na rua';
			grid.append(bizVehicleCard(vehicle.model, names.get(vehicle.model), `${vehicle.plate} · ${vehicle.state === 'stored' ? 'guardado' : 'na rua'}`, remove));
		}
		if (!vehicles.length) fleet.append(bizEl('p', 'biz-hint', 'Nenhum veículo na frota.'));
		fleet.append(grid);
	}
	if (garages.length) {
		const target = garages[0];
		fleet.append(bizEl('h3', '', `Adicionar à garagem ${target.label || target.id}`));
		const suggested = newsList(data.suggestedVehicles);
		const results = bizEl('div', 'biz-vehicle-grid');
		const fill = () => {
			results.replaceChildren();
			const term = (state.news.fleetSearch || '').trim().toLowerCase();
			const matches = term
				? catalog.filter((entry) => entry.model.includes(term) || (entry.name || '').toLowerCase().includes(term) || (entry.brand || '').toLowerCase().includes(term))
				: suggested.map((model) => catalog.find((entry) => entry.model === model) || { model });
			for (const entry of matches.slice(0, 24)) {
				const add = newsButton('Adicionar', () => newsAction('fleetAdd', { garage: target.id, model: entry.model }));
				results.append(bizVehicleCard(entry.model, entry.name, [entry.brand, entry.type].filter(Boolean).join(' · ') || 'Sugerido', add));
			}
			if (!matches.length) results.append(bizEl('p', 'biz-hint', 'Nenhum veículo encontrado.'));
		};
		fleet.append(bizInput('text', state.news.fleetSearch, (value) => { state.news.fleetSearch = value; fill(); },
			{ maxlength: 32, placeholder: 'Sugeridos abaixo; busque por nome, marca ou modelo' }), results);
		fill();
	}
	body.append(fleet);
}

function newsAds(outlet, body) {
	const ads = state.news.ads;
	const tabs = bizEl('div', 'biz-sections');
	for (const [key, text] of NEWS_AD_GROUPS) {
		const tab = bizEl('button', `biz-tab${key === ads.group ? ' is-active' : ''}`, text);
		tab.type = 'button';
		tab.addEventListener('click', () => {
			ads.group = key;
			newsLoadAds();
			renderNewsBody();
		});
		tabs.append(tab);
	}
	body.append(tabs);
	const block = newsBlock('Anúncios', 'Aprovar move o valor retido para o caixa do veículo. Recusar devolve a quem pagou. Tirar do ar pode estornar.');
	if (ads.error) block.append(bizEl('p', 'biz-hint', ads.error));
	else if (!ads.list) block.append(bizEl('p', 'biz-hint', 'Carregando...'));
	else if (!ads.list.length) block.append(bizEl('p', 'biz-hint', 'Nenhum anúncio aqui.'));
	const noteMax = newsData()?.limits?.noteMax || 160;
	for (const ad of ads.list || []) {
		const payer = ad.payer === 'personal' ? 'conta pessoal' : `caixa de ${String(ad.payer).replace('business:', '')}`;
		const details = [
			`${ad.advertiser} · ${ad.days} dia(s) · ${newsMoney(ad.price)} · pago pela ${payer}`,
			`Comprador: ${ad.buyerName || ad.buyerId} · pedido em ${newsDate(ad.createdAt)}${ad.endsAt ? ` · termina em ${newsDate(ad.endsAt)}` : ''}`,
			ad.body, ad.note ? `Observação: ${ad.note}` : ''
		];
		const actions = [];
		if (ad.status === 'pending') {
			const note = bizInput('text', '', () => {}, { maxlength: noteMax, placeholder: 'Observação ao anunciante (opcional)' });
			actions.push(note, newsButton('Aprovar', () => newsAction('adApprove', { outlet: outlet.id, id: ad.id, note: note.value })));
			actions.push(newsButton('Recusar', () => newsAction('adReject', { outlet: outlet.id, id: ad.id, note: note.value }, {
				title: 'Recusar anúncio', message: `Recusar "${ad.title}"? ${newsMoney(ad.price)} voltam para quem pagou.`, confirmLabel: 'Recusar', danger: true
			}), 'biz-danger'));
		} else if (ad.status === 'active') {
			const refund = bizEl('select', 'coe-field field-control');
			for (const [value, text] of NEWS_REFUND) {
				const option = bizEl('option', '', text);
				option.value = value;
				refund.append(option);
			}
			const note = bizInput('text', '', () => {}, { maxlength: noteMax, placeholder: 'Motivo (opcional)' });
			actions.push(refund, note, newsButton('Tirar do ar', () => newsAction('adTakedown', {
				outlet: outlet.id, id: ad.id, refund: refund.value, note: note.value
			}, {
				title: 'Tirar anúncio do ar', message: `Tirar "${ad.title}" do ar? ${NEWS_REFUND.find(([value]) => value === refund.value)?.[1]}. O estorno sai do caixa do veículo.`,
				confirmLabel: 'Tirar do ar', danger: true
			}), 'biz-danger'));
		}
		block.append(newsRow(`#${ad.id} · ${ad.title} · ${NEWS_AD_STATUS[ad.status] || ad.status}`, details, actions));
	}
	block.append(newsButton('Atualizar', newsLoadAds));
	body.append(block);
}

function newsArticles(outlet, body) {
	const articles = state.news.articles;
	const filters = bizEl('div', 'bank-inline');
	const status = bizEl('select', 'coe-field field-control');
	for (const [value, text] of [['', 'Todos os status'], ...Object.entries(NEWS_ARTICLE_STATUS)]) {
		const option = bizEl('option', '', text);
		option.value = value;
		status.append(option);
	}
	status.value = articles.status;
	status.addEventListener('change', () => {
		articles.status = status.value;
		newsLoadArticles();
		renderNewsBody();
	});
	const search = bizInput('search', articles.search, (value) => { articles.search = value; }, { maxlength: 40, placeholder: 'Título ou autor' });
	search.addEventListener('keydown', (event) => {
		if (event.key === 'Enter') {
			newsLoadArticles();
			renderNewsBody();
		}
	});
	filters.append(bizField('Status', status), bizField('Busca', search), newsButton('Buscar', () => { newsLoadArticles(); renderNewsBody(); }));
	body.append(filters);

	if (articles.open) {
		const article = articles.open;
		const reader = newsBlock(article.title, `${NEWS_ARTICLE_STATUS[article.status] || article.status} · ${article.anonymous ? 'Redação (anônima)' : article.authorName} · ${newsDate(article.publishedAt || article.updatedAt)}`);
		if (article.summary) reader.append(bizEl('p', '', article.summary));
		const text = bizEl('p', 'biz-hint', article.body || '');
		text.style.whiteSpace = 'pre-wrap';
		reader.append(text, newsButton('Fechar leitura', () => { articles.open = null; renderNewsBody(); }));
		body.append(reader);
	}

	const block = newsBlock('Matérias', 'Moderação da staff: tirar do ar, publicar de novo ou apagar. Toda ação fica na auditoria.');
	if (articles.error) block.append(bizEl('p', 'biz-hint', articles.error));
	else if (!articles.list) block.append(bizEl('p', 'biz-hint', 'Carregando...'));
	else if (!articles.list.length) block.append(bizEl('p', 'biz-hint', 'Nenhuma matéria encontrada.'));
	for (const article of articles.list || []) {
		const actions = [newsButton('Ler', () => {
			newsQuery('article', { outlet: outlet.id, id: article.id }).then((requestId) => { articles.openRequestId = requestId; });
		})];
		if (article.status === 'published') {
			actions.push(newsButton('Tirar do ar', () => newsAction('articleUnpublish', { outlet: outlet.id, id: article.id }, {
				title: 'Tirar matéria do ar', message: `Tirar "${article.title}" do ar? A equipe pode publicar de novo.`, confirmLabel: 'Tirar do ar', danger: true
			}), 'biz-danger'));
		}
		if (article.status === 'unpublished') {
			actions.push(newsButton('Publicar de novo', () => newsAction('articleRepublish', { outlet: outlet.id, id: article.id })));
		}
		actions.push(newsButton('Apagar', () => newsAction('articleDelete', { outlet: outlet.id, id: article.id }, {
			title: 'Apagar matéria', message: `Apagar "${article.title}" de vez? A foto de capa também é apagada.`, confirmLabel: 'Apagar', danger: true,
			requireText: String(article.id)
		}), 'biz-danger'));
		block.append(newsRow(`#${article.id} · ${article.title}`, [
			`${NEWS_ARTICLE_STATUS[article.status] || article.status}${article.breaking ? ' · urgente' : ''} · ${article.anonymous ? `Redação (por ${article.authorName})` : article.authorName}`,
			`${article.views} leitura(s) · atualizada em ${newsDate(article.updatedAt)}${article.publishedAt ? ` · publicada em ${newsDate(article.publishedAt)}` : ''}`,
			article.note ? `Observação: ${article.note}` : ''
		], actions));
	}
	body.append(block);
}

// Render -------------------------------------------------------------------------------------------------------

function renderNewsBody() {
	const body = document.getElementById('news-body');
	if (!body) return;
	body.replaceChildren();
	const data = newsData();
	const outlet = newsOutlet();
	if (!data?.available || !outlet) return;
	const business = newsBusiness(outlet);
	const section = state.news.section;
	if (section === 'overview') newsOverview(outlet, business, body);
	else if (section === 'business') newsBusinessSection(outlet, business, body);
	else if (section === 'editorial') newsEditorial(outlet, body);
	else if (section === 'team') newsTeam(outlet, business, body);
	else if (section === 'equipment') newsEquipment(outlet, body);
	else if (section === 'ads') newsAds(outlet, body);
	else if (section === 'articles') newsArticles(outlet, body);
}

function renderNews() {
	const outletsBox = document.getElementById('news-outlets');
	const sectionsBox = document.getElementById('news-sections');
	const body = document.getElementById('news-body');
	if (!outletsBox || !sectionsBox || !body) return;
	outletsBox.replaceChildren();
	sectionsBox.replaceChildren();
	const data = newsData();
	if (!data?.available) {
		body.replaceChildren(bizEl('div', 'empty-state', data?.reason === 'not_started' ? 'O resource coe_news não está iniciado.' : 'O coe_news ainda está iniciando.'));
		return;
	}
	const outlets = newsList(data.outlets);
	if (!outlets.some((outlet) => outlet.id === state.news.outlet)) state.news.outlet = outlets[0]?.id || null;
	for (const outlet of outlets) {
		const tab = bizEl('button', `biz-tab${outlet.id === state.news.outlet ? ' is-active' : ''}`);
		tab.type = 'button';
		const dot = bizEl('span', 'theme-dot');
		dot.style.background = outlet.color;
		dot.style.display = 'inline-block';
		dot.style.width = '8px';
		dot.style.height = '8px';
		dot.style.marginRight = '8px';
		tab.append(dot, document.createTextNode(`${outlet.label} · ${outlet.region || ''}`));
		tab.addEventListener('click', () => {
			if (state.news.outlet === outlet.id) return;
			state.news.outlet = outlet.id;
			state.news.team = null;
			state.news.editorial = null;
			state.news.articles.open = null;
			renderNews();
			newsLoadSection();
		});
		outletsBox.append(tab);
	}
	for (const [key, text] of NEWS_SECTIONS) {
		const tab = bizEl('button', `biz-tab${key === state.news.section ? ' is-active' : ''}`, text);
		tab.type = 'button';
		tab.addEventListener('click', () => {
			state.news.section = key;
			renderNews();
			newsLoadSection();
		});
		sectionsBox.append(tab);
	}
	renderNewsBody();
}

// Ao entrar na aba, carrega a seção atual (listas não vêm no snapshot do painel).
document.querySelector('[data-view="news"]')?.addEventListener('click', () => newsLoadSection());
