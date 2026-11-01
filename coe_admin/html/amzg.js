// Aba "Amzg": catálogo da loja virtual (coe_amzg). Cada produto é um item do inventário com preço e categoria.
// Usa os helpers de app.js; o servidor confere a permissão (manageBusinesses) e valida de novo em cada ação.
state.amzg = { category: '', search: '', draft: null, pickCategory: 'all', pickSearch: '' };

function amzgData() {
	return state.data?.amzg || null;
}

function amzgList(value) {
	if (Array.isArray(value)) return value;
	return value && typeof value === 'object' ? Object.values(value) : [];
}

function amzgMessage(text, success) {
	const message = document.getElementById('amzg-message');
	if (!message) return;
	message.textContent = text || '';
	message.classList.toggle('is-success', success === true);
}

function amzgButton(text, className, onClick) {
	const button = bizEl('button', className, text);
	button.type = 'button';
	button.addEventListener('click', onClick);
	return button;
}

function amzgCategoryLabel(id) {
	return amzgList(amzgData()?.categories).find((category) => category.id === id)?.label || id;
}

function amzgImage(item, name) {
	const image = bizEl('img');
	image.src = `nui://coe_inventory/data/images/${encodeURIComponent(item?.image || `${name}.png`)}`;
	image.alt = '';
	image.addEventListener('error', () => image.remove(), { once: true });
	return image;
}

function amzgPrice(value) {
	return `$ ${Number(value || 0).toLocaleString('pt-BR')}`;
}

// datetime-local (horário desta tela) <-> segundos Unix usados pelo servidor.
function amzgToLocalInput(seconds) {
	if (!seconds) return '';
	const date = new Date(seconds * 1000);
	const pad = (value) => String(value).padStart(2, '0');
	return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}`;
}

function amzgFromLocalInput(value) {
	if (!value) return 0;
	const time = new Date(value).getTime();
	return Number.isFinite(time) ? Math.floor(time / 1000) : 0;
}

function amzgSend(op, payload) {
	amzgMessage('Enviando...');
	postNui('amzgCatalog', { op, payload }).then((result) => {
		if (!result.ok) amzgMessage('Não foi possível enviar.', false);
	});
}

function onAmzgResult(data) {
	amzgMessage(data.message, data.success === true);
	if (data.success === true) state.amzg.draft = null;
}

function amzgOpen(product) {
	const first = amzgList(amzgData()?.categories)[0];
	const now = Number(amzgData()?.now) || Math.floor(Date.now() / 1000);
	// Promoção vencida não volta sozinha: o rascunho abre sem ela (o servidor recusa prazo no passado).
	const expired = !!product && Number(product.promoPrice) > 0 && Number(product.promoUntil) > 0 && Number(product.promoUntil) <= now;
	state.amzg.draft = product
		? {
			id: product.id, item: product.item, label: product.label, category: product.category, price: product.price, sort: product.sort, active: product.active !== false,
			promoPrice: expired ? 0 : Number(product.promoPrice) || 0, promoUntil: expired ? 0 : Number(product.promoUntil) || 0,
			featured: product.featured === true, bannerText: product.bannerText || '', expired
		}
		: { id: null, item: '', label: '', category: state.amzg.category || first?.id || '', price: 100, sort: 0, active: true, promoPrice: 0, promoUntil: 0, featured: false, bannerText: '', expired: false };
	state.amzg.pickSearch = '';
	renderAmzg();
}

function renderAmzg() {
	const list = document.getElementById('amzg-list');
	const editor = document.getElementById('amzg-editor');
	const tabs = document.getElementById('amzg-categories');
	if (!list || !editor || !tabs) return;
	list.replaceChildren();
	editor.replaceChildren();
	tabs.replaceChildren();
	const data = amzgData();
	if (!data) {
		appendEmpty(list, 'O resource coe_amzg não está iniciado.');
		editor.append(bizEl('div', 'empty-state', 'O resource coe_amzg não está iniciado.'));
		return;
	}
	const products = amzgList(data.products);
	const count = document.getElementById('amzg-count');
	if (count) count.textContent = `${products.length} de ${data.max || 0}`;

	for (const [id, text] of [['', 'Todas'], ...amzgList(data.categories).map((category) => [category.id, category.label])]) {
		tabs.append(amzgButton(text, `biz-tab${state.amzg.category === id ? ' is-active' : ''}`, () => {
			state.amzg.category = id;
			renderAmzg();
		}));
	}

	amzgRenderProducts(list, products);

	const draft = state.amzg.draft;
	if (!draft) {
		editor.append(bizEl('div', 'empty-state', 'Selecione um produto ou crie um novo.'));
		return;
	}
	amzgEditor(editor, draft, data);
}

function amzgRenderProducts(list, products) {
	list.replaceChildren();
	const items = state.data?.items || {};
	const term = state.amzg.search.trim().toLowerCase();
	const visible = products.filter((product) => (!state.amzg.category || product.category === state.amzg.category)
		&& (!term || `${product.label} ${product.item} ${items[product.item]?.label || ''}`.toLowerCase().includes(term)));
	if (!visible.length) {
		appendEmpty(list, products.length ? 'Nenhum produto neste filtro.' : 'Nenhum produto. Crie o primeiro.');
		return;
	}
	const grid = bizEl('div', 'amzg-grid');
	const draft = state.amzg.draft;
	for (const product of visible) {
		const button = amzgButton('', `catalog-item${draft && draft.id === product.id ? ' is-selected' : ''}${product.active ? '' : ' is-paused'}`, () => amzgOpen(product));
		const text = bizEl('span', 'amzg-item-text');
		const flags = [amzgCategoryLabel(product.category)];
		if (!product.active) flags.push('pausado');
		if (product.missing) flags.push('item inexistente');
		if (product.promoActive) flags.push(`promoção ${amzgPrice(product.promoPrice)}${product.featured ? ' · banner' : ''}`);
		text.append(bizEl('strong', '', product.label), bizEl('small', '', flags.join(' · ')));
		button.append(amzgImage(items[product.item], product.item), text, bizEl('small', 'catalog-item-count', amzgPrice(product.price)));
		grid.append(button);
	}
	list.append(grid);
}

// Seletor de item igual ao da aba Itens: categorias, busca e grade com imagens.
function amzgItemPicker(draft, onPick) {
	const wrapper = bizEl('div', 'amzg-picker');
	const menu = bizEl('nav', 'category-menu');
	const search = bizEl('div', 'search-field');
	const input = bizEl('input');
	input.type = 'search';
	input.placeholder = 'Buscar item do inventário';
	input.autocomplete = 'off';
	input.value = state.amzg.pickSearch;
	search.append(bizEl('span', '', '⌕'), input);
	const results = bizEl('div', 'item-results');
	wrapper.append(menu, search, results);

	const items = getItems();
	const categories = getCategories();
	if (state.amzg.pickCategory !== 'all' && !categories.includes(state.amzg.pickCategory)) state.amzg.pickCategory = 'all';

	const paintMenu = () => {
		menu.replaceChildren();
		for (const key of ['all', ...categories]) {
			const button = amzgButton('', `category-button${state.amzg.pickCategory === key ? ' is-active' : ''}`, () => {
				state.amzg.pickCategory = key;
				paintMenu();
				paintResults();
			});
			const total = key === 'all' ? items.length : items.filter((item) => (item.category || 'misc') === key).length;
			button.append(bizEl('span', '', key === 'all' ? 'Todos' : (itemCategoryLabels[key] || key)), bizEl('small', '', String(total)));
			menu.append(button);
		}
	};

	const paintResults = () => {
		results.replaceChildren();
		const query = state.amzg.pickSearch.trim().toLowerCase();
		const filtered = items.filter((item) => (state.amzg.pickCategory === 'all' || (item.category || 'misc') === state.amzg.pickCategory)
			&& `${item.label} ${item.name}`.toLowerCase().includes(query));
		if (!filtered.length) {
			appendEmpty(results, 'Nenhum item corresponde à busca.');
			return;
		}
		const grid = bizEl('div', 'item-category-items');
		for (const item of filtered) {
			const selected = draft.item === item.name;
			const button = amzgButton('', `catalog-item${selected ? ' is-selected' : ''}`, () => {
				onPick(item);
				paintResults();
			});
			button.setAttribute('aria-pressed', String(selected));
			button.title = item.name;
			button.append(amzgImage(item, item.name), bizEl('span', '', item.label));
			grid.append(button);
		}
		results.append(grid);
	};

	input.addEventListener('input', () => {
		state.amzg.pickSearch = input.value;
		paintResults();
	});
	paintMenu();
	paintResults();
	return wrapper;
}

function amzgEditor(host, draft, data) {
	const items = state.data?.items || {};
	const heading = bizEl('div', 'panel-heading');
	heading.append(bizEl('h2', '', draft.id ? `Produto: ${draft.label || draft.item}` : 'Novo produto'));
	host.append(heading);

	const chosen = bizEl('div', 'amzg-chosen');
	const paintChosen = () => {
		chosen.replaceChildren();
		const item = items[draft.item];
		if (!draft.item) {
			chosen.append(bizEl('span', 'biz-hint', 'Nenhum item escolhido: selecione na lista abaixo.'));
			return;
		}
		const text = bizEl('span', 'amzg-item-text');
		text.append(bizEl('strong', '', item?.label || draft.item), bizEl('small', '', item ? `${draft.item} · pilha de ${item.maxStack || 1}` : `${draft.item} · não existe no inventário`));
		chosen.append(amzgImage(item, draft.item), text);
	};
	paintChosen();

	const label = bizInput('text', draft.label, (value) => { draft.label = value; }, { maxlength: 48, placeholder: 'vazio = nome do item' });
	const itemBlock = bizEl('div', 'biz-block');
	itemBlock.append(
		bizEl('h3', '', 'Item'),
		bizEl('p', 'biz-hint', 'A compra entrega este item numa caixa dentro do imóvel escolhido. Pilhas seguem o limite do item no inventário.'),
		chosen,
		amzgItemPicker(draft, (item) => {
			const previous = items[draft.item]?.label;
			draft.item = item.name;
			if (!draft.label || draft.label === previous) {
				draft.label = item.label;
				label.value = item.label;
			}
			paintChosen();
		})
	);

	const category = bizEl('select', 'coe-field field-control');
	for (const entry of amzgList(data.categories)) {
		const option = bizEl('option', '', entry.label);
		option.value = entry.id;
		category.append(option);
	}
	category.value = draft.category;
	category.addEventListener('change', () => { draft.category = category.value; });
	const price = bizInput('number', draft.price, (value) => { draft.price = Number(value); }, { min: 1, max: data.priceMax || 100000, step: 1 });
	const sort = bizInput('number', draft.sort, (value) => { draft.sort = Number(value); }, { min: 0, max: 9999, step: 1 });
	const active = bizEl('label', 'biz-check');
	const activeInput = bizEl('input');
	activeInput.type = 'checkbox';
	activeInput.checked = draft.active;
	activeInput.addEventListener('change', () => { draft.active = activeInput.checked; });
	active.append(activeInput, bizEl('span', '', 'À venda (desmarque para pausar sem apagar)'));

	const block = bizEl('div', 'biz-block');
	block.append(
		bizEl('h3', '', 'Vitrine'),
		bizField('Nome na vitrine', label),
		bizField('Categoria', category),
		bizField('Preço por unidade', price),
		bizField('Ordem na vitrine (menor primeiro)', sort),
		active
	);

	// Promoção: vira "De $X por $Y" na vitrine e, com destaque, um banner com a imagem do produto.
	const promoPrice = bizInput('number', draft.promoPrice || '', (value) => { draft.promoPrice = Number(value) || 0; paintPreview(); }, { min: 0, step: 1, placeholder: '0 = sem promoção' });
	const promoUntil = bizInput('datetime-local', amzgToLocalInput(draft.promoUntil), (value) => { draft.promoUntil = amzgFromLocalInput(value); paintPreview(); });
	const bannerMax = data.bannerTextMax || 24;
	const bannerText = bizInput('text', draft.bannerText, (value) => { draft.bannerText = value; paintPreview(); }, { maxlength: bannerMax, placeholder: 'ex.: Oferta relâmpago' });
	const featured = bizEl('label', 'biz-check');
	const featuredInput = bizEl('input');
	featuredInput.type = 'checkbox';
	featuredInput.checked = draft.featured;
	featuredInput.addEventListener('change', () => { draft.featured = featuredInput.checked; paintPreview(); });
	featured.append(featuredInput, bizEl('span', '', 'Destaque no banner do topo da loja'));
	const preview = bizEl('div', 'amzg-preview');
	const paintPreview = () => {
		preview.replaceChildren();
		const price = Math.floor(Number(draft.price) || 0);
		const promo = Math.floor(Number(draft.promoPrice) || 0);
		if (promo <= 0) {
			preview.append(bizEl('span', 'biz-hint', 'Sem promoção: a vitrine mostra só o preço normal.'));
			return;
		}
		if (promo >= price) {
			preview.append(bizEl('span', 'biz-hint is-error', 'O preço promocional precisa ser menor que o preço normal.'));
			return;
		}
		const discount = Math.max(1, Math.floor((price - promo) * 100 / price));
		const text = bizEl('div', 'amzg-preview-text');
		text.append(
			bizEl('span', 'amzg-preview-tag', String(draft.bannerText || '').trim() || `-${discount}% OFF`),
			bizEl('strong', '', String(draft.label || '').trim() || items[draft.item]?.label || draft.item || 'Produto'),
			bizEl('span', 'amzg-preview-deal', `De ${amzgPrice(price)} por ${amzgPrice(promo)}`),
			bizEl('small', '', `${draft.featured ? 'Banner no topo e' : 'Banner'} entre os produtos${draft.promoUntil ? ` · até ${new Date(draft.promoUntil * 1000).toLocaleString('pt-BR')}` : ' · sem prazo'}`)
		);
		preview.append(text, amzgImage(items[draft.item], draft.item));
	};
	paintPreview();
	const promoBlock = bizEl('div', 'biz-block');
	promoBlock.append(
		bizEl('h3', '', 'Promoção e banner'),
		bizEl('p', 'biz-hint', 'Com preço promocional a vitrine mostra "De $ por $" e o desconto. O banner usa a imagem do item. Sem prazo, a promoção vale até você zerar o preço promocional.'),
		...(draft.expired ? [bizEl('p', 'biz-hint', 'A promoção anterior terminou e foi retirada deste rascunho.')] : []),
		bizField('Preço promocional (0 = sem promoção)', promoPrice),
		bizField('Termina em (vazio = sem prazo)', promoUntil),
		bizField(`Selo do banner (até ${bannerMax} caracteres, vazio = desconto)`, bannerText),
		featured,
		preview
	);
	price.addEventListener('input', paintPreview);
	label.addEventListener('input', paintPreview);
	host.append(itemBlock, block, promoBlock);

	const actions = bizEl('div', 'biz-actions');
	actions.append(amzgButton('Salvar produto', 'coe-button coe-button--primary primary-button', () => {
		if (!draft.item) {
			amzgMessage('Escolha o item do inventário.', false);
			return;
		}
		amzgSend('save', {
			id: draft.id || undefined, item: draft.item, label: String(draft.label || '').trim(), category: draft.category,
			price: Math.floor(Number(draft.price) || 0), sort: Math.floor(Number(draft.sort) || 0), active: draft.active,
			promoPrice: Math.floor(Number(draft.promoPrice) || 0), promoUntil: Math.floor(Number(draft.promoUntil) || 0),
			featured: draft.featured === true, bannerText: String(draft.bannerText || '').trim()
		});
	}));
	if (draft.id) {
		const remove = amzgButton('Remover', 'coe-button biz-danger', () => {
			if (remove.dataset.confirm !== '1') {
				remove.dataset.confirm = '1';
				remove.textContent = 'Confirmar remoção';
				return;
			}
			amzgSend('delete', { id: draft.id });
		});
		actions.append(remove);
	}
	actions.append(amzgButton('Cancelar', 'coe-button biz-small-button', () => {
		state.amzg.draft = null;
		renderAmzg();
	}));
	host.append(actions);
}

document.getElementById('amzg-new')?.addEventListener('click', () => {
	if (amzgData()) amzgOpen(null);
});

// Filtra só a lista de produtos (sem redesenhar o editor e perder o que está sendo digitado).
document.getElementById('amzg-search')?.addEventListener('input', (event) => {
	state.amzg.search = event.target.value;
	const list = document.getElementById('amzg-list');
	const data = amzgData();
	if (list && data) amzgRenderProducts(list, amzgList(data.products));
});
