// Aba "Receitas e cardápios" em Negócios e seção "Cardápio" do negócio (coe_crafting). Usa os helpers de app.js.
const craftState = { view: 'recipes', draft: null, isNew: false, idTouched: false, picks: {}, refresh: false, lastOp: null };

function craftData() {
	return state.data?.businesses?.crafting || null;
}

// Tabelas Lua vazias podem chegar como {} ou [].
function craftList(value) {
	if (Array.isArray(value)) return value;
	return value && typeof value === 'object' ? Object.values(value) : [];
}

function craftHasBench(category) {
	return Boolean(craftData()?.benches?.[category]);
}

function craftBizLabel(category) {
	return state.data?.businesses?.categories?.[category]?.label || category;
}

function craftRecipesFor(bizCategory) {
	const allowed = new Set(craftList(craftData()?.benches?.[bizCategory]?.categories));
	return craftList(craftData()?.recipes)
		.filter((recipe) => allowed.has(recipe.category))
		.sort((a, b) => String(a.label).localeCompare(String(b.label)));
}

function craftCategoryLabel(id) {
	const entry = craftList(craftData()?.categories).find((category) => category.id === id);
	return entry ? (entry.business ? `${entry.label} (${craftBizLabel(entry.business)})` : entry.label) : id;
}

function craftSlug(text, max) {
	return String(text || '').normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase()
		.replace(/[^a-z0-9]+/g, '_').replace(/^_+|_+$/g, '').slice(0, max);
}

function craftCheck(text, checked, onChange, disabled = false) {
	const label = bizEl('label', 'biz-check');
	const input = bizEl('input');
	input.type = 'checkbox';
	input.checked = checked;
	input.disabled = disabled;
	input.addEventListener('change', () => onChange(input.checked));
	label.append(input, bizEl('span', '', text));
	return label;
}

function craftSelect(options, value, onChange) {
	const select = bizEl('select', 'coe-field field-control');
	for (const [optionValue, text] of options) {
		const option = bizEl('option', '', text);
		option.value = optionValue;
		select.append(option);
	}
	select.value = value ?? '';
	select.addEventListener('change', () => onChange(select.value));
	return select;
}

function craftButton(text, className, onClick) {
	const button = bizEl('button', className, text);
	button.type = 'button';
	button.addEventListener('click', onClick);
	return button;
}

function craftConfirm(text, onConfirm) {
	const button = craftButton(text, 'coe-button biz-danger', () => {
		if (button.dataset.confirm !== '1') {
			button.dataset.confirm = '1';
			button.textContent = 'Confirmar remoção';
			return;
		}
		onConfirm();
	});
	return button;
}

function craftSend(op, payload) {
	craftState.lastOp = op;
	postNui('craftCatalog', { op, payload }).then((result) => {
		if (!result.ok) showToast('Não foi possível enviar.', false);
	});
}

function craftOpen(draft, isNew) {
	craftState.draft = draft;
	craftState.isNew = isNew;
	craftState.idTouched = !isNew;
	renderBusinesses();
	renderBusinessEditor();
}

function craftRecipeDraft(recipe) {
	return {
		kind: 'recipe', id: recipe.id, label: recipe.label, category: recipe.category, custom: recipe.custom === true,
		seconds: (Number(recipe.timeMs) || 5000) / 1000,
		inputs: craftList(recipe.inputs).map((entry) => ({ item: entry.item, count: entry.count })),
		outputs: craftList(recipe.outputs).map((entry) => ({ item: entry.item, count: entry.count }))
	};
}

function craftMenuDraft(menu) {
	return { kind: 'menu', id: menu.id, label: menu.label, category: menu.category, recipes: [...craftList(menu.recipes)] };
}

function craftBenchDraft(bench) {
	const recipes = [...craftList(bench.recipes)];
	return {
		kind: 'bench', id: bench.id, label: bench.label, enabled: bench.enabled !== false,
		x: Number(bench.x), y: Number(bench.y), z: Number(bench.z), radius: Number(bench.radius) || 1.5,
		customRecipes: recipes.length > 0, recipes
	};
}

function craftNew() {
	const data = craftData();
	if (!data) return;
	if (craftState.view === 'recipes') {
		const first = craftList(data.categories)[0];
		craftOpen({
			kind: 'recipe', id: '', label: '', category: first?.id || '', custom: true, seconds: 5,
			inputs: [{ item: '', count: 1 }], outputs: [{ item: '', count: 1 }]
		}, true);
	} else if (craftState.view === 'benches') {
		craftOpen({
			kind: 'bench', id: '', label: '', enabled: true,
			x: null, y: null, z: null, radius: 1.5, customRecipes: false, recipes: []
		}, true);
	} else {
		craftOpen({ kind: 'menu', id: '', label: '', category: Object.keys(data.benches || {}).sort()[0] || '', recipes: [] }, true);
	}
}

// Chamado por renderBusinesses: adiciona a aba e, no modo receitas, assume a lista. Retorna true quando assumiu.
function craftRenderTab(tabs, list) {
	if (craftState.refresh) {
		craftState.refresh = false;
		window.setTimeout(renderBusinessEditor, 0);
	}
	const data = craftData();
	if (!data) {
		if (state.biz.mode === 'recipes') state.biz.mode = null;
		return false;
	}
	const active = state.biz.mode === 'recipes';
	if (active) tabs.querySelectorAll('.biz-tab.is-active').forEach((node) => node.classList.remove('is-active'));
	tabs.append(craftButton('Receitas e cardápios', `biz-tab${active ? ' is-active' : ''}`, () => {
		state.biz.mode = 'recipes';
		state.biz.draft = null;
		craftState.draft = null;
		renderBusinesses();
		renderBusinessEditor();
	}));
	if (!active) return false;
	craftRenderList(list, data);
	return true;
}

function craftRenderList(list, data) {
	document.getElementById('biz-list-title').textContent = 'Receitas e cardápios';
	const switcher = bizEl('div', 'biz-sections');
	for (const [key, text] of [['recipes', 'Receitas'], ['menus', 'Tipos de cardápio'], ['benches', 'Bancadas ilegais']]) {
		switcher.append(craftButton(text, `biz-tab${craftState.view === key ? ' is-active' : ''}`, () => {
			craftState.view = key;
			craftState.draft = null;
			renderBusinesses();
			renderBusinessEditor();
		}));
	}
	list.append(switcher);
	const current = craftState.draft;
	if (craftState.view === 'recipes') {
		const editable = new Set(craftList(data.categories).map((category) => category.id));
		const recipes = craftList(data.recipes).filter((recipe) => editable.has(recipe.category))
			.sort((a, b) => String(a.label).localeCompare(String(b.label)));
		if (!recipes.length) appendEmpty(list, 'Nenhuma receita.');
		for (const recipe of recipes) {
			const row = craftButton('', `biz-item${current?.kind === 'recipe' && current.id === recipe.id ? ' is-active' : ''}`,
				() => craftOpen(craftRecipeDraft(recipe), false));
			row.append(bizEl('strong', '', recipe.label),
				bizEl('small', '', `${recipe.id} · ${craftCategoryLabel(recipe.category)}${recipe.custom ? '' : ' · padrão'}`));
			list.append(row);
		}
	} else if (craftState.view === 'benches') {
		const benches = craftList(data.illegalBenches);
		if (!benches.length) appendEmpty(list, 'Nenhuma bancada ilegal cadastrada.');
		for (const bench of benches) {
			const row = craftButton('', `biz-item${current?.kind === 'bench' && current.id === bench.id ? ' is-active' : ''}`,
				() => craftOpen(craftBenchDraft(bench), false));
			const count = craftList(bench.recipes).length;
			row.append(bizEl('strong', '', bench.label),
				bizEl('small', '', `${bench.id} · ${count ? `${count} receitas` : 'todas as receitas ilegais'}${bench.enabled === false ? ' · inativa' : ''}`));
			list.append(row);
		}
	} else {
		const menus = craftList(data.menus);
		if (!menus.length) appendEmpty(list, 'Nenhum tipo de cardápio. Crie um (ex.: Pizzaria, Hamburgueria, Bar).');
		for (const menu of menus) {
			const row = craftButton('', `biz-item${current?.kind === 'menu' && current.id === menu.id ? ' is-active' : ''}`,
				() => craftOpen(craftMenuDraft(menu), false));
			row.append(bizEl('strong', '', menu.label),
				bizEl('small', '', `${menu.id} · ${craftBizLabel(menu.category)} · ${craftList(menu.recipes).length} receitas`));
			list.append(row);
		}
	}
}

function craftRenderEditor(host) {
	const draft = craftState.draft;
	if (!craftData()) {
		host.append(bizEl('div', 'empty-state', 'O resource coe_crafting não está iniciado.'));
		return;
	}
	if (!draft) {
		const emptyMsg = craftState.view === 'recipes'
			? 'Selecione uma receita ou crie uma nova.'
			: (craftState.view === 'benches' ? 'Selecione uma bancada ilegal ou crie uma nova.' : 'Selecione um tipo de cardápio ou crie um novo.');
		host.append(bizEl('div', 'empty-state', emptyMsg));
		return;
	}
	if (draft.kind === 'recipe') craftRecipeEditor(host, draft);
	else if (draft.kind === 'bench') craftBenchEditor(host, draft);
	else craftMenuEditor(host, draft);
}

function craftIdentity(draft, idMax) {
	const idInput = bizInput('text', draft.id, (value) => {
		draft.id = value.toLowerCase();
		craftState.idTouched = true;
	}, { maxlength: idMax });
	idInput.disabled = !craftState.isNew;
	const labelInput = bizInput('text', draft.label, (value) => {
		draft.label = value;
		if (craftState.isNew && !craftState.idTouched) {
			draft.id = craftSlug(value, idMax);
			idInput.value = draft.id;
		}
	}, { maxlength: 48 });
	return { idInput, labelInput };
}

function craftItemsDatalist() {
	const list = bizEl('datalist');
	list.id = 'craft-items';
	const items = state.data?.items || {};
	for (const name of Object.keys(items).sort()) {
		const option = bizEl('option');
		option.value = name;
		option.label = items[name]?.label || name;
		list.append(option);
	}
	return list;
}

function craftStacks(title, entries, max, readOnly, hint) {
	const block = bizEl('div', 'biz-block');
	block.append(bizEl('h3', '', title), bizEl('p', 'biz-hint', hint));
	entries.forEach((entry, index) => {
		const row = bizEl('div', 'fac-row');
		const item = bizInput('text', entry.item, (value) => {
			entry.item = value.trim();
			name.textContent = state.data?.items?.[entry.item]?.label || '';
		}, { list: 'craft-items', placeholder: 'item', maxlength: 64 });
		const count = bizInput('number', entry.count, (value) => { entry.count = Number(value); }, { min: 1, max: 1000, step: 1 });
		const name = bizEl('span', 'fac-name', state.data?.items?.[entry.item]?.label || '');
		item.disabled = readOnly;
		count.disabled = readOnly;
		row.append(item, count, name);
		if (!readOnly && entries.length > 1) {
			row.append(craftButton('Remover', 'coe-button biz-small-button', () => {
				entries.splice(index, 1);
				renderBusinessEditor();
			}));
		}
		block.append(row);
	});
	if (!readOnly && entries.length < max) {
		block.append(craftButton('+ Item', 'coe-button biz-small-button', () => {
			entries.push({ item: '', count: 1 });
			renderBusinessEditor();
		}));
	}
	return block;
}

function craftRecipeEditor(host, draft) {
	const readOnly = !draft.custom;
	const heading = bizEl('div', 'panel-heading');
	heading.append(bizEl('h2', '', craftState.isNew ? 'Nova receita' : `Receita: ${draft.label || draft.id}`));
	host.append(heading, craftItemsDatalist());
	const body = bizEl('div', 'biz-section-body');
	const { idInput, labelInput } = craftIdentity(draft, 48);
	const categories = craftList(craftData().categories).map((category) => [category.id, craftCategoryLabel(category.id)]);
	const category = craftSelect(categories, draft.category, (value) => { draft.category = value; });
	const seconds = bizInput('number', draft.seconds, (value) => { draft.seconds = Number(value); }, { min: 0.5, max: 120, step: 0.5 });
	for (const input of [labelInput, category, seconds]) input.disabled = readOnly;
	const block = bizEl('div', 'biz-block');
	block.append(bizEl('h3', '', 'Receita'));
	if (readOnly) block.append(bizEl('p', 'biz-hint', 'Receita padrão do servidor: só leitura. Crie uma nova receita para variar.'));
	block.append(
		bizField('Nome', labelInput),
		bizField('ID (letras, números e _)', idInput),
		bizField('Bancada', category),
		bizField('Tempo de preparo (segundos)', seconds)
	);
	body.append(block,
		craftStacks('Ingredientes', draft.inputs, 8, readOnly, 'Consumidos do jogador ou do baú da bancada (1 a 8).'),
		craftStacks('Resultado', draft.outputs, 4, readOnly, 'Itens entregues ao terminar (1 a 4).'));
	host.append(body);
	if (readOnly) return;
	const actions = bizEl('div', 'biz-actions');
	actions.append(craftButton('Salvar receita', 'coe-button coe-button--primary primary-button', () => {
		const clean = (entries) => entries.filter((entry) => entry.item).map((entry) => ({ item: entry.item, count: Math.floor(Number(entry.count) || 0) }));
		craftSend('saveRecipe', {
			id: draft.id, label: draft.label.trim(), category: draft.category,
			timeMs: Math.round((Number(draft.seconds) || 0) * 1000), inputs: clean(draft.inputs), outputs: clean(draft.outputs)
		});
	}));
	if (!craftState.isNew) actions.append(craftConfirm('Remover', () => craftSend('deleteRecipe', draft.id)));
	host.append(actions);
}

function craftRecipeChecklist(bizCategory, selected, onToggle) {
	const box = bizEl('div', 'biz-block');
	const recipes = craftRecipesFor(bizCategory);
	box.append(bizEl('h3', '', `Receitas (${selected.length} de ${recipes.length})`));
	if (!recipes.length) box.append(bizEl('p', 'biz-hint', 'Nenhuma receita para esta bancada. Crie em Receitas.'));
	for (const recipe of recipes) {
		box.append(craftCheck(`${recipe.label} · ${recipe.id}`, selected.includes(recipe.id), (checked) => onToggle(recipe.id, checked)));
	}
	return box;
}

function craftToggle(list, id, checked) {
	const index = list.indexOf(id);
	if (checked && index < 0) list.push(id);
	if (!checked && index >= 0) list.splice(index, 1);
}

function craftMenuEditor(host, draft) {
	const heading = bizEl('div', 'panel-heading');
	heading.append(bizEl('h2', '', craftState.isNew ? 'Novo tipo de cardápio' : `Tipo: ${draft.label || draft.id}`));
	host.append(heading);
	const body = bizEl('div', 'biz-section-body');
	const { idInput, labelInput } = craftIdentity(draft, 32);
	const benches = Object.keys(craftData().benches || {}).sort().map((key) => [key, craftBizLabel(key)]);
	const category = craftSelect(benches, draft.category, (value) => {
		draft.category = value;
		const allowed = new Set(craftRecipesFor(value).map((recipe) => recipe.id));
		draft.recipes = draft.recipes.filter((id) => allowed.has(id));
		renderBusinessEditor();
	});
	category.disabled = !craftState.isNew;
	const block = bizEl('div', 'biz-block');
	block.append(
		bizEl('h3', '', 'Tipo de cardápio'),
		bizEl('p', 'biz-hint', 'Negócios da categoria que escolherem este tipo produzem só estas receitas. Cada negócio ainda pode ajustar o próprio cardápio.'),
		bizField('Nome (ex.: Pizzaria)', labelInput),
		bizField('ID (letras, números e _)', idInput),
		bizField('Categoria de negócio', category)
	);
	body.append(block, craftRecipeChecklist(draft.category, draft.recipes, (id, checked) => {
		craftToggle(draft.recipes, id, checked);
		renderBusinessEditor();
	}));
	host.append(body);
	const actions = bizEl('div', 'biz-actions');
	actions.append(craftButton('Salvar tipo', 'coe-button coe-button--primary primary-button', () => {
		craftSend('saveMenu', { id: draft.id, label: draft.label.trim(), category: draft.category, recipes: draft.recipes });
	}));
	if (!craftState.isNew) actions.append(craftConfirm('Remover', () => craftSend('deleteMenu', draft.id)));
	host.append(actions);
}

function craftBenchEditor(host, draft) {
	const heading = bizEl('div', 'panel-heading');
	heading.append(bizEl('h2', '', craftState.isNew ? 'Nova bancada ilegal' : `Bancada: ${draft.label || draft.id}`));
	host.append(heading);
	const body = bizEl('div', 'biz-section-body');
	const { idInput, labelInput } = craftIdentity(draft, 32);
	const illegalRecipes = craftList(craftData()?.recipes)
		.filter((recipe) => recipe.category === 'illegal')
		.sort((a, b) => String(a.label).localeCompare(String(b.label)));
	const block = bizEl('div', 'biz-block');
	const preview = Number.isFinite(draft.x) ? [{ x: draft.x, y: draft.y, z: draft.z }] : [];
	const mark = craftButton(Number.isFinite(draft.x) ? 'Remarcar aqui' : 'Marcar aqui', 'coe-button biz-small-button', () => {
		bizCapture({ label: draft.label || 'bancada clandestina', preview }, (data) => {
			if (data.point) Object.assign(draft, data.point);
		});
	});
	block.append(
		bizEl('h3', '', 'Bancada clandestina livre'),
		bizEl('p', 'biz-hint', 'Aberta a qualquer jogador, sem exigir negócio ou grupo. Consome insumos apenas da mochila do jogador.'),
		bizField('Nome (ex.: Bancada do beco)', labelInput),
		bizField('ID (letras, números e _)', idInput),
		craftCheck('Ativa (visível e operável no mundo)', draft.enabled !== false, (checked) => { draft.enabled = checked; }),
		bizEl('p', 'biz-hint', `Posição: ${bizPointText(draft)}`),
		mark,
		bizField('Raio (0,5 a 10 m)', bizInput('number', draft.radius, (value) => { draft.radius = bizNumber(value, 1.5); }, { min: 0.5, max: 10, step: '0.1' })),
		craftCheck('Restringir receitas desta bancada (desmarcado = todas as receitas ilegais)', draft.customRecipes === true, (checked) => {
			draft.customRecipes = checked;
			if (checked && !draft.recipes.length) {
				draft.recipes = illegalRecipes.map((recipe) => recipe.id);
			}
			renderBusinessEditor();
		})
	);
	body.append(block);
	if (draft.customRecipes) {
		const checklist = bizEl('div', 'biz-block');
		checklist.append(bizEl('h3', '', `Receitas ilegais (${draft.recipes.length} de ${illegalRecipes.length})`));
		if (!illegalRecipes.length) checklist.append(bizEl('p', 'biz-hint', 'Nenhuma receita ilegal cadastrada.'));
		for (const recipe of illegalRecipes) {
			checklist.append(craftCheck(`${recipe.label} · ${recipe.id}`, draft.recipes.includes(recipe.id), (checked) => {
				craftToggle(draft.recipes, recipe.id, checked);
				renderBusinessEditor();
			}));
		}
		body.append(checklist);
	}
	host.append(body);
	const actions = bizEl('div', 'biz-actions');
	actions.append(craftButton('Salvar bancada', 'coe-button coe-button--primary primary-button', () => {
		if (draft.customRecipes && !draft.recipes.length) {
			showToast('Escolha ao menos uma receita ou desmarque a restrição.', false);
			return;
		}
		craftSend('saveBench', {
			id: draft.id, label: draft.label.trim(), enabled: draft.enabled !== false,
			x: draft.x, y: draft.y, z: draft.z, radius: Number(draft.radius) || 1.5,
			recipes: draft.customRecipes ? draft.recipes : null
		});
	}));
	if (!craftState.isNew) actions.append(craftConfirm('Remover', () => craftSend('deleteBench', draft.id)));
	host.append(actions);
}

// Seção "Cardápio" do editor de negócio.
function craftBusinessMenu(draft) {
	const box = bizEl('div');
	const data = craftData();
	if (!data) {
		box.append(bizEl('div', 'empty-state', 'O resource coe_crafting não está iniciado.'));
		return box;
	}
	let pick = craftState.picks[draft.id];
	if (!pick) {
		const saved = data.businesses?.[draft.id];
		const valid = saved && saved.category === draft.category;
		const adjusted = valid && saved.recipes !== undefined && saved.recipes !== null;
		pick = { menu: valid ? saved.menu || '' : '', custom: Boolean(adjusted), recipes: adjusted ? [...craftList(saved.recipes)] : [] };
		craftState.picks[draft.id] = pick;
	}
	const menus = craftList(data.menus).filter((menu) => menu.category === draft.category);
	const menuOf = (id) => menus.find((menu) => menu.id === id);
	const block = bizEl('div', 'biz-block');
	block.append(
		bizEl('h3', '', 'Cardápio da bancada'),
		bizEl('p', 'biz-hint', 'Escolha o tipo (ex.: Pizzaria) para definir o que a bancada produz. Sem tipo, a bancada oferece todas as receitas da categoria.'),
		bizField('Tipo', craftSelect([['', 'Sem tipo (todas as receitas)'], ...menus.map((menu) => [menu.id, menu.label])], pick.menu, (value) => {
			pick.menu = value;
			renderBusinessEditor();
		})),
		craftCheck('Ajustar o cardápio deste negócio (substitui a lista do tipo)', pick.custom, (checked) => {
			pick.custom = checked;
			if (checked && !pick.recipes.length) {
				const base = menuOf(pick.menu);
				pick.recipes = base ? [...craftList(base.recipes)] : craftRecipesFor(draft.category).map((recipe) => recipe.id);
			}
			renderBusinessEditor();
		})
	);
	const effective = pick.custom ? pick.recipes.length
		: (menuOf(pick.menu) ? craftList(menuOf(pick.menu).recipes).length : craftRecipesFor(draft.category).length);
	block.append(bizEl('p', 'biz-hint', `A bancada vai oferecer ${effective} receita(s).`));
	box.append(block);
	if (pick.custom) {
		box.append(craftRecipeChecklist(draft.category, pick.recipes, (id, checked) => {
			craftToggle(pick.recipes, id, checked);
			renderBusinessEditor();
		}));
	}
	const actions = bizEl('div', 'biz-actions');
	actions.append(craftButton('Salvar cardápio', 'coe-button coe-button--primary primary-button', () => {
		if (pick.custom && !pick.recipes.length) {
			showToast('Escolha ao menos uma receita ou desmarque o ajuste.', false);
			return;
		}
		craftSend('setBusinessMenu', { businessId: draft.id, menu: pick.menu || null, recipes: pick.custom ? pick.recipes : null });
	}));
	box.append(actions);
	return box;
}

function onCraftResult(data) {
	showToast(data.message, data.success === true);
	if (data.success !== true) return;
	craftState.picks = {};
	craftState.refresh = true;
	if (craftState.lastOp === 'deleteRecipe' || craftState.lastOp === 'deleteMenu' || craftState.lastOp === 'deleteBench') craftState.draft = null;
	else {
		craftState.isNew = false;
		craftState.idTouched = true;
	}
}
