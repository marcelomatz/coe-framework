// Aba "Imobiliária" dentro de Imóveis: carteira de imóveis cadastrados (visita, edição e contratos) e catálogo de interiores.
const REALTY_VIEWS = [['portfolio', 'Carteira'], ['interiors', 'Interiores']];
const REALTY_KIND_FROM_CATEGORY = { apartment: 'apartment', house: 'house' };
const REALTY_STATE = { ok: 'Em dia', due: 'Vencido (tolerância)', expired: 'Expirado' };
const REALTY_CONTRACT_ERRORS = { forbidden: 'Sem permissão.', not_ready: 'O resource coe_housing não está disponível.', unknown_property: 'Imóvel inexistente.' };

function realtyState() {
	if (!state.hou.realty) state.hou.realty = { view: 'portfolio', search: '', contracts: null };
	return state.hou.realty;
}

function realtyMoney(value) {
	return typeof value === 'number' ? `$${value.toLocaleString('pt-BR')}` : '—';
}

function realtyDate(value) {
	return value > 0 ? new Date(value * 1000).toLocaleDateString('pt-BR') : '—';
}

function realtyProperties() {
	// Imóveis ilegais ficam fora da imobiliária: só aparecem na aba Ilegais.
	return (state.data?.housing?.list || []).filter((entry) => entry.kind !== 'hideout');
}

function realtyOpenEditor(draft, isNew) {
	state.hou.kind = draft.kind;
	state.hou.draft = draft;
	state.hou.isNew = isNew;
	state.hou.section = isNew ? 'general' : state.hou.section;
	renderHousing();
	renderHousingEditor();
}

function realtyInteriorText(entry) {
	const known = entry.interiorId && houInteriorById(entry.interiorId);
	if (known) return known.label;
	return entry.interior ? 'Interior personalizado' : 'Sem interior';
}

function realtyLoadContracts(entry) {
	const realty = realtyState();
	realty.contracts = { id: entry.id, label: entry.label, requestId: 0, list: null, error: null };
	renderRealty();
	postNui('housingContracts', { propertyId: entry.id }).then((result) => {
		if (!result.ok) {
			realty.contracts.error = 'timeout';
			renderRealty();
			return;
		}
		if (realty.contracts?.id === entry.id) realty.contracts.requestId = result.requestId;
	});
}

function onHousingContractsResult(data) {
	const contracts = realtyState().contracts;
	if (!contracts || contracts.requestId !== data.requestId || contracts.id !== data.propertyId) return;
	contracts.list = Array.isArray(data.contracts) ? data.contracts : [];
	contracts.error = data.error || null;
	renderRealty();
}

function onRealtyContractEnd(data) {
	const contracts = realtyState().contracts;
	if (data.success !== true || !contracts) return;
	const entry = realtyProperties().find((item) => item.id === contracts.id);
	if (entry) realtyLoadContracts(entry);
}

function realtyContractRow(contract) {
	const row = bizEl('div', 'realty-contract');
	const info = bizEl('div', 'realty-contract-info');
	const who = contract.kind === 'lease'
		? `Negócio: ${contract.businessLabel || contract.businessId}`
		: `${contract.name || 'Personagem'}${contract.stateId ? ` (#${contract.stateId})` : ''}`;
	const terms = contract.starter ? 'Gratuito (inicial)' : contract.granted ? 'Cedido pelo admin'
		: `${realtyMoney(contract.dailyRate)}/dia · ciclo de ${contract.cycleDays} dias · pago até ${realtyDate(contract.paidUntil)}`;
	info.append(
		bizEl('strong', '', `Unidade ${contract.unit} · ${who}`),
		bizEl('small', '', `${terms} · ${REALTY_STATE[contract.state] || contract.state}${contract.present ? ` · ${contract.present} dentro agora` : ''}`)
	);
	row.append(info);
	if (!contract.starter && !contract.granted) {
		const end = houSmallButton('Encerrar', () => {
			if (end.dataset.confirm !== '1') {
				end.dataset.confirm = '1';
				end.textContent = 'Confirmar encerramento';
				end.classList.add('biz-danger');
				return;
			}
			end.disabled = true;
			postNui('housingEndContract', { kind: contract.kind, id: contract.id }).then((result) => {
				if (!result.ok) {
					end.disabled = false;
					showToast('Não foi possível enviar o pedido.', false);
				}
			});
		});
		row.append(end);
	}
	return row;
}

function realtyContractsBlock() {
	const contracts = realtyState().contracts;
	const box = bizEl('div', 'biz-block');
	const head = bizEl('div', 'biz-block-head');
	head.append(bizEl('h3', '', `Contratos: ${contracts.label}`), houSmallButton('Fechar', () => {
		realtyState().contracts = null;
		renderRealty();
	}));
	box.append(head);
	if (contracts.error) {
		box.append(bizEl('p', 'biz-hint', REALTY_CONTRACT_ERRORS[contracts.error] || 'Não foi possível carregar os contratos.'));
	} else if (!contracts.list) {
		box.append(bizEl('p', 'biz-hint', 'Carregando...'));
	} else if (!contracts.list.length) {
		box.append(bizEl('p', 'biz-hint', 'Nenhum contrato ativo.'));
	} else {
		box.append(bizEl('p', 'biz-hint', 'Encerrar devolve a unidade à imobiliária e tira quem estiver dentro. O imóvel inicial e o cedido a um negócio não são encerrados por aqui.'));
		for (const contract of contracts.list) box.append(realtyContractRow(contract));
	}
	return box;
}

function realtyPortfolio(host) {
	const realty = realtyState();
	if (realty.contracts) host.append(realtyContractsBlock());
	const search = bizInput('search', realty.search, (value) => {
		realty.search = value;
		fill();
	}, { placeholder: 'Buscar por nome ou ID', maxlength: 40 });
	host.append(bizField('Buscar', search));
	const grid = bizEl('div', 'hou-interior-grid realty-grid');
	const fill = () => {
		grid.replaceChildren();
		const term = realty.search.trim().toLowerCase();
		const items = realtyProperties().filter((entry) => !term || entry.label.toLowerCase().includes(term) || entry.id.includes(term));
		if (!items.length) appendEmpty(grid, 'Nenhum imóvel cadastrado.');
		for (const entry of items) {
			const interior = entry.interiorId ? houInteriorById(entry.interiorId) : null;
			const card = bizEl('div', `hou-card${realty.contracts?.id === entry.id ? ' is-active' : ''}`);
			const body = bizEl('div', 'hou-card-body');
			const flags = [entry.starter ? 'inicial' : '', entry.businessId ? `cedido a ${entry.businessId}` : '', entry.enabled === false ? 'inativo' : ''].filter(Boolean);
			body.append(
				bizEl('strong', '', entry.label),
				bizEl('small', '', `${HOU_KINDS[entry.kind] || entry.kind} · ${entry.occupied || 0}/${entry.units} ocupada(s)`),
				bizEl('small', '', `${realtyInteriorText(entry)} · ${entry.stash ? 'com baú' : 'sem baú'}`)
			);
			if (flags.length) body.append(bizEl('small', '', flags.join(' · ')));
			const actions = bizEl('div', 'hou-card-actions realty-actions');
			const visit = houSmallButton('Visitar', () => houVisitProperty(houFromEntry(entry), 'none'));
			visit.disabled = !entry.interior;
			actions.append(
				visit,
				houSmallButton('Editar', () => realtyOpenEditor(houFromEntry(entry), false)),
				houSmallButton('Contratos', () => realtyLoadContracts(entry))
			);
			card.append(interior ? houThumb(interior) : houThumb({ id: '', label: entry.label }), body, actions);
			grid.append(card);
		}
	};
	fill();
	host.append(grid);
}

function realtyInteriors(host) {
	const used = {};
	for (const entry of realtyProperties()) {
		if (entry.interiorId) used[entry.interiorId] = (used[entry.interiorId] || 0) + 1;
	}
	const head = bizEl('div', 'biz-block-head');
	const generate = bizEl('div', 'hou-actions-row');
	generate.append(houSmallButton('Gerar miniaturas faltantes', () => houGenerateThumbs(false)), houSmallButton('Regerar todas', () => houGenerateThumbs(true)));
	head.append(bizEl('p', 'biz-hint', 'Interiores nativos do jogo. "Criar imóvel" abre um cadastro novo já com o interior escolhido; falta só marcar a porta na rua.'), generate);
	host.append(head);

	const filters = bizEl('div', 'hou-filters');
	for (const [key, label] of [['all', 'Todos'], ...(houInteriors().categories || [])]) {
		const chip = bizEl('button', `biz-tab${state.hou.interiorCategory === key ? ' is-active' : ''}`, label);
		chip.type = 'button';
		chip.addEventListener('click', () => {
			state.hou.interiorCategory = key;
			renderRealty();
		});
		filters.append(chip);
	}
	const search = bizInput('search', state.hou.interiorSearch, (value) => {
		state.hou.interiorSearch = value;
		fill();
	}, { placeholder: 'Buscar interior', maxlength: 40 });
	host.append(filters, bizField('Buscar', search));

	const grid = bizEl('div', 'hou-interior-grid');
	const fill = () => {
		grid.replaceChildren();
		const term = state.hou.interiorSearch.trim().toLowerCase();
		const items = (houInteriors().list || []).filter((entry) => (state.hou.interiorCategory === 'all' || entry.category === state.hou.interiorCategory)
			&& (!term || entry.label.toLowerCase().includes(term) || entry.id.includes(term)));
		if (!items.length) appendEmpty(grid, 'Nenhum interior encontrado.');
		for (const entry of items) {
			const card = bizEl('div', 'hou-card');
			const body = bizEl('div', 'hou-card-body');
			const count = used[entry.id] || 0;
			body.append(bizEl('strong', '', entry.label), bizEl('small', '', `${houCategoryLabel(entry.category)} · ${count ? `usado em ${count} imóvel(is)` : 'livre'}`));
			const actions = bizEl('div', 'hou-card-actions');
			actions.append(
				houSmallButton('Visitar', () => houStartVisit({ id: entry.id, mark: 'none', label: entry.label }, null)),
				houSmallButton('Criar imóvel', () => {
					const draft = houNewDraft(REALTY_KIND_FROM_CATEGORY[entry.category] || 'commercial');
					draft.label = entry.label.slice(0, 48);
					draft.interiorId = entry.id;
					draft.interior = { x: entry.x, y: entry.y, z: entry.z, heading: entry.heading || 0, radius: 1.5 };
					realtyOpenEditor(draft, true);
				})
			);
			card.append(houThumb(entry), body, actions);
			grid.append(card);
		}
	};
	fill();
	host.append(grid);
}

function renderRealty() {
	const host = document.getElementById('hou-realty');
	if (!host || state.hou.kind !== 'realty') return;
	houLoadThumbs(false);
	const realty = realtyState();
	host.replaceChildren();
	const tabs = bizEl('div', 'biz-sections');
	tabs.setAttribute('role', 'tablist');
	for (const [key, text] of REALTY_VIEWS) {
		const tab = bizEl('button', `biz-tab${key === realty.view ? ' is-active' : ''}`, text);
		tab.type = 'button';
		tab.addEventListener('click', () => {
			realty.view = key;
			renderRealty();
		});
		tabs.append(tab);
	}
	host.append(tabs);
	const body = bizEl('div', 'biz-section-body');
	if (realty.view === 'interiors') realtyInteriors(body);
	else realtyPortfolio(body);
	host.append(body);
}
