const shell = document.getElementById('admin-shell');
const views = ['overview', 'players', 'items', 'staff', 'groups', 'businesses', 'housing', 'garages', 'doors', 'amzg', 'news', 'banking', 'crypto', 'deepweb', 'framework', 'appearance'];
const state = {
	fac: { draft: null, isNew: false, section: 'general', members: { id: null, list: null, error: null, requestId: null } },
	biz: { category: null, section: 'general', draft: null, isNew: false, pendingCapture: null, mode: null },
	gar: { kind: 'public', section: 'general', draft: null, isNew: false },
	door: { section: 'general', draft: null, isNew: false, filter: '', reload: null },
	hou: { kind: 'apartment', section: 'general', draft: null, isNew: false, interiorCategory: 'all', interiorSearch: '', thumbs: {}, thumbsRequestId: 0, thumbsLoaded: false },
	data: null,
	view: 'overview',
	cart: new Map(),
	activeCategory: 'all',
	deliverySubmission: null,
	requestSequence: 0
};

const elements = {
	currentSection: document.getElementById('current-section'),
	adminName: document.getElementById('admin-name'),
	adminAvatar: document.getElementById('admin-avatar'),
	metricPlayers: document.getElementById('metric-players'),
	metricItems: document.getElementById('metric-items'),
	metricStaff: document.getElementById('metric-staff'),
	sidebarPlayerCount: document.getElementById('sidebar-player-count'),
	sessionCount: document.getElementById('session-count'),
	sessionCatalogCount: document.getElementById('session-catalog-count'),
	sessionRole: document.getElementById('session-role'),
	onlineSummary: document.getElementById('online-summary'),
	onlineList: document.getElementById('online-list'),
	targetPlayer: document.getElementById('target-player'),
	targetSummary: document.getElementById('target-summary'),
	itemSearch: document.getElementById('item-search'),
	categoryMenu: document.getElementById('category-menu'),
	itemResults: document.getElementById('item-results'),
	itemMetadata: document.getElementById('item-metadata'),
	formMessage: document.getElementById('form-message'),
	giveItem: document.getElementById('give-item'),
	deliveryPreview: document.getElementById('delivery-preview'),
	deliveryCount: document.getElementById('delivery-count'),
	clearCart: document.getElementById('clear-cart'),
	staffPlayer: document.getElementById('staff-player'),
	staffRole: document.getElementById('staff-role'),
	staffMessage: document.getElementById('staff-message'),
	assignStaff: document.getElementById('assign-staff'),
	staffList: document.getElementById('staff-list'),
	staffCount: document.getElementById('staff-count'),
	frameworkList: document.getElementById('framework-list'),
	frameworkCount: document.getElementById('framework-count'),
	frameworkSearch: document.getElementById('framework-search'),
	frameworkMessage: document.getElementById('framework-message'),
	themeList: document.getElementById('theme-list'),
	themeMessage: document.getElementById('theme-message'),
	toastRegion: document.getElementById('toast-region')
};

function postNui(endpoint, payload = {}) {
	return fetch(`https://${GetParentResourceName()}/${endpoint}`, {
		method: 'POST',
		headers: { 'Content-Type': 'application/json; charset=UTF-8' },
		body: JSON.stringify(payload)
	}).then((response) => response.json());
}

function showToast(message, type = 'success') {
	const isSuccess = type === true || type === 'success';
	const toast = document.createElement('div');
	toast.className = `toast ${isSuccess ? 'is-success' : 'is-error'}`;
	toast.textContent = message || (isSuccess ? 'Ação concluída.' : 'A ação falhou.');
	elements.toastRegion.append(toast);
	window.setTimeout(() => toast.remove(), 3600);
}

function setView(viewName) {
	if (!views.includes(viewName)) return;
	const permissions = state.data?.permissions || {};
	if (viewName === 'players' && !permissions.viewPlayers) return;
	if (viewName === 'items' && !permissions.giveItems) return;
	if (viewName === 'staff' && !permissions.manageStaff) return;
	if (viewName === 'groups' && !permissions.manageGroups) return;
	if ((viewName === 'businesses' || viewName === 'garages' || viewName === 'housing' || viewName === 'doors' || viewName === 'amzg') && !permissions.manageBusinesses) return;
	if (viewName === 'banking' && !permissions.manageBanking) return;
	if (viewName === 'crypto' && !permissions.manageCrypto) return;
	if (viewName === 'news' && !permissions.manageNews) return;
	if (viewName === 'deepweb' && !permissions.manageDeepweb) return;
	if (viewName === 'framework' && !permissions.manageResources) return;
	if (viewName === 'appearance' && !permissions.manageTheme) return;

	state.view = viewName;
	if (viewName === 'players') mountProfileSearch();
	for (const view of views) {
		document.getElementById(`view-${view}`).classList.toggle('is-visible', view === viewName);
		document.querySelector(`[data-view="${view}"]`)?.classList.toggle('is-active', view === viewName);
	}
	elements.currentSection.textContent = {
		overview: 'Visão geral',
		players: 'Jogadores',
		items: 'Entregar itens',
		staff: 'Equipe',
		groups: 'Grupos',
		businesses: 'Negócios',
		garages: 'Garagens',
		housing: 'Imóveis',
		doors: 'Portas',
		amzg: 'Amzg',
		news: 'Imprensa',
		banking: 'Banco',
		crypto: 'Criptomoeda',
		deepweb: 'DeepWeb',
		framework: 'Framework',
		appearance: 'Aparência'
	}[viewName];
}

function applyPermissions(data) {
	const permissions = data.permissions || {};
	document.querySelectorAll('[data-permission="giveItems"]').forEach((element) => {
		element.hidden = !permissions.giveItems;
	});
	document.querySelectorAll('[data-permission="viewPlayers"]').forEach((element) => {
		element.hidden = !permissions.viewPlayers;
	});
	if (state.view === 'players' && !permissions.viewPlayers) setView('overview');
	document.querySelectorAll('[data-permission="manageStaff"]').forEach((element) => {
		element.hidden = !permissions.manageStaff;
	});
	document.querySelectorAll('[data-permission="manageGroups"]').forEach((element) => {
		element.hidden = !permissions.manageGroups;
	});
	document.querySelectorAll('[data-permission="manageResources"]').forEach((element) => {
		element.hidden = !permissions.manageResources;
	});
	document.querySelectorAll('[data-permission="manageBusinesses"]').forEach((element) => {
		element.hidden = !permissions.manageBusinesses;
	});
	if ((state.view === 'businesses' || state.view === 'garages' || state.view === 'housing' || state.view === 'doors' || state.view === 'amzg') && !permissions.manageBusinesses) setView('overview');
	if (state.view === 'framework' && !permissions.manageResources) setView('overview');
	document.querySelectorAll('[data-permission="manageBanking"]').forEach((element) => {
		element.hidden = !permissions.manageBanking;
	});
	if (state.view === 'banking' && !permissions.manageBanking) setView('overview');
	document.querySelectorAll('[data-permission="manageCrypto"]').forEach((element) => {
		element.hidden = !permissions.manageCrypto;
	});
	if (state.view === 'crypto' && !permissions.manageCrypto) setView('overview');
	document.querySelectorAll('[data-permission="manageNews"]').forEach((element) => {
		element.hidden = !permissions.manageNews;
	});
	if (state.view === 'news' && !permissions.manageNews) setView('overview');
	document.querySelectorAll('[data-permission="manageDeepweb"]').forEach((element) => {
		element.hidden = !permissions.manageDeepweb;
	});
	if (state.view === 'deepweb' && !permissions.manageDeepweb) setView('overview');
	document.querySelectorAll('[data-permission="manageTheme"]').forEach((element) => {
		element.hidden = !permissions.manageTheme;
	});
	if (state.view === 'appearance' && !permissions.manageTheme) setView('overview');
	if (state.view === 'items' && !permissions.giveItems) setView('overview');
	if (state.view === 'staff' && !permissions.manageStaff) setView('overview');
	if (state.view === 'groups' && !permissions.manageGroups) setView('overview');
}

function appendEmpty(container, message) {
	container.replaceChildren();
	const empty = document.createElement('div');
	empty.className = 'empty-state';
	empty.textContent = message;
	container.append(empty);
}

function renderOnlinePlayers() {
	const players = state.data?.players || [];
	elements.onlineSummary.textContent = `${players.length} jogador${players.length === 1 ? '' : 'es'}`;
	elements.sidebarPlayerCount.textContent = String(players.length);
	elements.metricPlayers.textContent = String(players.length);
	elements.sessionCount.textContent = String(players.length);
	if (players.length === 0) {
		appendEmpty(elements.onlineList, 'Nenhum jogador conectado.');
		return;
	}

	elements.onlineList.replaceChildren();
	for (const player of players) {
		const row = document.createElement('div');
		row.className = 'online-row';
		const id = document.createElement('span');
		id.className = 'player-id';
		id.textContent = `#${player.id}`;
		const name = document.createElement('span');
		name.className = 'player-name';
		name.textContent = player.name;
		const account = document.createElement('small');
		account.className = 'player-account';
		account.textContent = (player.hasCharacter ? 'Conta: ' : 'Sem personagem · conta: ') + (player.account || '') + (player.stateId ? ' · ID ' + player.stateId : '');
		name.append(account);
		const ping = document.createElement('span');
		ping.className = 'player-ping';
		ping.textContent = `${player.ping} ms`;
		const status = document.createElement('span');
		status.className = 'online-tag';
		status.textContent = 'Online';
		row.append(id, name, ping, status);
		if (player.characterId && state.data?.permissions?.viewPlayers) {
			row.classList.add('is-clickable');
			row.title = 'Abrir perfil';
			row.addEventListener('click', () => openProfile(player.characterId));
		}
		elements.onlineList.append(row);
	}
}

const PROFILE_TABS = [['summary', 'Resumo'], ['inventory', 'Inventário'], ['vehicles', 'Veículos'], ['housing', 'Imóveis'], ['businesses', 'Negócios'], ['economy', 'Economia']];
const profileState = { requestId: null, profile: null, tab: 'summary', mounted: false };
const PROFILE_ERRORS = { forbidden: 'Sem permissão.', rate_limited: 'Aguarde um instante.', character_not_found: 'Personagem não encontrado.', invalid_character: 'Personagem inválido.', database_error: 'Banco indisponível.' };

function mountProfileSearch() {
	if (profileState.mounted) return;
	profileState.mounted = true;
	document.getElementById('profile-search-slot').append(bizCharacterPicker((character) => openProfile(character.characterId)));
}

async function openProfile(characterId) {
	setView('players');
	mountProfileSearch();
	document.getElementById('profile-message').textContent = 'Carregando perfil...';
	const result = await postNui('getProfile', { characterId: String(characterId) });
	if (result.ok) profileState.requestId = result.requestId;
}

function profileRows(rows) {
	const box = bizEl('div', 'profile-rows');
	for (const [label, value] of rows) {
		const row = bizEl('div', 'session-row');
		row.append(bizEl('span', '', label), bizEl('strong', '', value === undefined || value === null || value === '' ? '—' : String(value)));
		box.append(row);
	}
	return box;
}

function profileTable(columns, rows, emptyText) {
	if (!rows.length) return bizEl('p', 'biz-hint', emptyText);
	const table = bizEl('table', 'profile-table');
	const head = bizEl('tr');
	for (const column of columns) head.append(bizEl('th', '', column[0]));
	table.append(head);
	for (const row of rows) {
		const line = bizEl('tr');
		for (const column of columns) line.append(bizEl('td', '', String(column[1](row) ?? '—')));
		table.append(line);
	}
	return table;
}

function profileSection(title, content) {
	const panel = bizEl('section', 'content-panel profile-section');
	panel.append(bizEl('h3', '', title), content);
	return panel;
}

function profileError(data) {
	return data && data.error ? bizEl('p', 'biz-hint', 'Indisponível agora (' + data.error + ').') : null;
}

const profileMoney = (value) => (typeof value === 'number' ? (value < 0 ? '-$' : '$') + Math.abs(value).toLocaleString('pt-BR') : '—');

function renderProfile() {
	const body = document.getElementById('profile-body');
	body.replaceChildren();
	const profile = profileState.profile;
	if (!profile) return;
	const identity = profile.identity;
	const header = bizEl('section', 'content-panel profile-header');
	header.append(bizEl('h2', '', identity.name), bizEl('span', 'profile-state-id', identity.stateId));
	if (profile.online) header.append(bizEl('span', 'online-tag', 'Online · #' + profile.online.serverId + ' · ' + profile.online.ping + ' ms'));
	else header.append(bizEl('span', 'profile-offline', 'Offline'));
	if (identity.archived) header.append(bizEl('span', 'profile-offline', 'Arquivado'));
	body.append(header);

	const tabs = bizEl('div', 'biz-categories profile-tabs');
	for (const [key, label] of PROFILE_TABS) {
		const tab = bizEl('button', 'biz-tab' + (profileState.tab === key ? ' is-active' : ''), label);
		tab.type = 'button';
		tab.addEventListener('click', () => { profileState.tab = key; renderProfile(); });
		tabs.append(tab);
	}
	body.append(tabs);

	const tab = profileState.tab;
	if (tab === 'summary') {
		body.append(profileSection('Identidade', profileRows([['ID', identity.stateId], ['Nascimento', identity.birthDate], ['Gênero', identity.gender], ['Criado em', identity.createdAt], ['Atualizado em', identity.updatedAt]])));
		const groups = profile.groups;
		const factions = profile.factions;
		body.append(profileSection('Facções', profileError(factions) || profileTable([['Facção', (f) => f.label], ['Categoria', (f) => f.category], ['Grau', (f) => f.gradeLabel], ['Ativa', (f) => (f.enabled === false ? 'Não' : 'Sim')]], factions.list, 'Sem facções.')));
		body.append(profileSection('Grupos de sistema', profileError(groups) || profileTable([['Grupo', (g) => g.label], ['Tipo', (g) => g.type], ['Grau', (g) => g.grade], ['Ativo', (g) => (g.active ? 'Sim' : 'Não')]], groups.list, 'Sem grupos.')));
		const needs = profile.needs;
		body.append(profileSection('Necessidades', profileError(needs) || (needs.available ? profileRows([['Fome', needs.hunger], ['Sede', needs.thirst], ['Estresse', needs.stress]]) : bizEl('p', 'biz-hint', 'Sem registro.'))));
		const account = profile.account;
		if (!account.error) {
			body.append(profileSection('Conta e personagens', profileTable([['Personagem', (c) => c.name + (c.current ? ' (este)' : '')], ['ID', (c) => c.stateId], ['Situação', (c) => (c.archived ? 'Arquivado' : 'Ativo')]], account.characters, 'Nenhum.')));
			body.append(profileSection('Identificadores', profileTable([['Tipo', (i) => i.type], ['Valor', (i) => i.value]], account.identifiers, 'Nenhum.')));
		}
	} else if (tab === 'inventory') {
		const inventory = profile.inventory;
		if (inventory.error) body.append(profileSection('Inventário', profileError(inventory)));
		else {
			const info = profileRows([['Slots usados', inventory.used + ' / ' + inventory.slots], ['Peso', inventory.weight + (inventory.maxWeight ? ' / ' + inventory.maxWeight : '') + ' g']]);
			const table = profileTable([['Slot', (i) => i.slot], ['Item', (i) => i.label], ['Quantidade', (i) => i.count], ['Detalhes', (i) => (i.metadata ? JSON.stringify(i.metadata) : '')]], inventory.items, 'Inventário vazio.');
			body.append(profileSection('Inventário', info), profileSection('Itens', table));
		}
	} else if (tab === 'vehicles') {
		const vehicles = profile.vehicles;
		if (vehicles.error) body.append(profileSection('Veículos', profileError(vehicles)));
		else {
			body.append(profileSection('Veículos próprios', profileTable([['Modelo', (v) => v.model], ['Placa', (v) => v.plate], ['Km', (v) => v.kilometers], ['Estado', (v) => v.state], ['Garagem', (v) => v.garage]], vehicles.owned, 'Nenhum veículo.')));
			body.append(profileSection('Chaves de terceiros', profileTable([['Modelo', (v) => v.model], ['Placa', (v) => v.plate]], vehicles.keys, 'Nenhuma chave.')));
		}
	} else if (tab === 'housing') {
		const housing = profile.housing;
		const until = (value) => (value > 0 ? new Date(value * 1000).toLocaleDateString('pt-BR') : '—');
		body.append(profileSection('Imóveis', profileError(housing) || profileTable([['Imóvel', (h) => h.label], ['Unidade', (h) => h.unit], ['Diária', (h) => profileMoney(h.dailyRate)], ['Pago até', (h) => until(h.paidUntil)]], housing.list, 'Nenhum imóvel.')));
	} else if (tab === 'businesses') {
		const business = profile.businesses;
		if (business.error) body.append(profileSection('Negócios', profileError(business)));
		else {
			const columns = [['Negócio', (b) => b.label || b.id], ['Categoria', (b) => ANALYTICS_CATEGORIES[b.category] || b.category]];
			body.append(profileSection('Como dono', profileTable(columns, business.owned, 'Não é dono de negócios.')));
			body.append(profileSection('Como funcionário', profileTable(columns, business.staff, 'Não é funcionário.')));
		}
	} else if (tab === 'economy') {
		const economy = profile.economy;
		if (economy.error) body.append(profileSection('Economia', profileError(economy)));
		else {
			body.append(profileSection('Conta bancária', profileRows([['Saldo', profileMoney(economy.balance)]])));
			body.append(profileSection('Últimas movimentações bancárias', profileTable([['Quando', (e) => e.at], ['Valor', (e) => profileMoney(e.delta)], ['Motivo', (e) => e.reason], ['Origem', (e) => e.source], ['Referência', (e) => e.reference]], economy.ledger, 'Sem movimentações.')));
		}
		const crypto = profile.crypto;
		const fmtUnits = (units) => (typeof cryptoFormatUnits === 'function' ? cryptoFormatUnits(units) : `${(Number(units) || 0) / 10000} NOX`);
		if (crypto && !crypto.error) {
			const kindLabels = { buy: 'Compra', sell: 'Venda', transfer: 'Envio', mine: 'Mineração', refund: 'Estorno' };
			body.append(
				profileSection('Carteiras de criptomoeda', profileTable([
					['Endereço', (w) => w.address],
					['Rótulo / Vínculo', (w) => (w.label ? `${w.label} (${w.source})` : w.source)],
					['Saldo', (w) => fmtUnits(w.balance)],
					['Criada em', (w) => w.at || '—']
				], crypto.wallets || [], 'Nenhuma carteira de criptomoeda associada.')),
				profileSection('Últimas movimentações de criptomoeda', profileTable([
					['Quando', (t) => t.at],
					['Tipo', (t) => kindLabels[t.kind] || t.kind],
					['Quantia', (t) => fmtUnits(t.amount)],
					['Valor ($)', (t) => (t.fiat ? profileMoney(t.fiat) : '—')],
					['Origem → Destino', (t) => `${t.from || 'Emissão'} → ${t.to}`],
					['Aparelho', (t) => t.device || '—']
				], crypto.tx || [], 'Sem movimentações de criptomoeda.'))
			);
		}
	}
}
const ANALYTICS_CATEGORIES = { mechanic: 'Mecânica', shop: 'Lojinha', gas_station: 'Posto', restaurant: 'Restaurante', media: 'Mídia', other: 'Outros' };
const ANALYTICS_KINDS = { public: 'Públicas', business: 'Negócio', job: 'Corporação', apartment: 'Apartamentos', hotel: 'Hotéis', house: 'Casas', commercial: 'Comerciais' };

function renderAnalytics(analytics, crypto) {
	const grid = document.getElementById('analytics-grid');
	if (!grid) return;
	grid.replaceChildren();
	if (!analytics) return;
	const card = (title, rows) => {
		const box = document.createElement('article');
		box.className = 'analytics-card';
		const heading = document.createElement('h3');
		heading.textContent = title;
		box.append(heading);
		for (const [label, value] of rows) {
			const row = document.createElement('div');
			row.className = 'session-row';
			const name = document.createElement('span');
			name.textContent = label;
			const strong = document.createElement('strong');
			strong.textContent = value === undefined || value === null ? '—' : String(value);
			row.append(name, strong);
			box.append(row);
		}
		grid.append(box);
	};
	const money = (value) => (typeof value === 'number' ? '$' + value.toLocaleString('pt-BR') : '—');
	const players = analytics.players;
	if (players) {
		card('Jogadores', [['Online', players.online], ['Com personagem', players.withCharacter], ['Ping médio', players.averagePing + ' ms'], ['Personagens criados', players.characters]]);
	}
	const business = analytics.businesses;
	if (business?.available) {
		const rows = [['Negócios', business.total], ['Com dono', business.withOwner], ['Sem dono', business.withoutOwner], ['Funcionários', business.staff], ['Sem equipe', business.withoutStaff], ['Em serviço agora', business.onDuty], ['Pontos de craft', business.stations.crafts], ['Estoques', business.stations.stashes], ['Pontos de ponto', business.stations.clocks]];
		for (const [category, amount] of Object.entries(business.byCategory || {})) rows.push([ANALYTICS_CATEGORIES[category] || category, amount]);
		card('Negócios', rows);
	}
	const garages = analytics.garages;
	if (garages?.available) {
		const rows = [['Garagens', garages.total], ['Vagas', garages.spots], ['Veículos de frota', garages.fleetVehicles]];
		for (const [kind, amount] of Object.entries(garages.byKind || {})) rows.push([ANALYTICS_KINDS[kind] || kind, amount]);
		card('Garagens', rows);
	}
	const housing = analytics.housing;
	if (housing?.available) {
		const rows = [['Propriedades', housing.total], ['Unidades', housing.units], ['Ocupadas', housing.occupied], ['Vagas', housing.vacant]];
		for (const [kind, amount] of Object.entries(housing.byKind || {})) rows.push([ANALYTICS_KINDS[kind] || kind, amount]);
		card('Moradias', rows);
	}
	if (analytics.economy?.available) {
		card('Economia', [['Contas', analytics.economy.accounts], ['Dinheiro em circulação', money(analytics.economy.total)]]);
	}
	if (crypto?.available) {
		const coin = crypto.settings?.coin || { name: 'Noxcoin', symbol: 'NOX', decimals: 4 };
		const ex = crypto.settings?.exchange || {};
		const market = crypto.market || {};
		const summary = crypto.summary || {};
		const fmtUnits = (units) => (typeof cryptoFormatUnits === 'function' ? cryptoFormatUnits(units) : `${((Number(units) || 0) / Math.pow(10, coin.decimals || 4)).toFixed(4)} ${coin.symbol}`);
		const changeNum = Number(market.change) || 0;
		const changeStr = `${changeNum > 0 ? '+' : ''}${changeNum.toFixed(1)}%`;
		card(`Criptomoeda (${coin.symbol})`, [
			['Moeda', `${coin.name} (${coin.symbol})`],
			['Cotação atual', `${money(market.price)} (${changeStr})`],
			['Compra / Venda', `${money(market.buy)} / ${money(market.sell)}`],
			['Corretora', `${ex.name || 'NoxSwap'} (${ex.enabled !== false ? 'Aberta' : 'Fechada'})`],
			['Carteiras de jogadores', summary.wallets ?? 0],
			['Em circulação', fmtUnits(summary.circulating)],
			['Reserva da corretora', fmtUnits(market.reserveBalance)],
			['Total minerado', fmtUnits(market.minted)],
			['Transações na rede', summary.txCount ?? 0]
		]);
	}
	const framework = analytics.framework;
	if (framework) {
		card('Framework', [['Resources', framework.total], ['Iniciados', framework.started], ['Parados', framework.stopped], ['Críticos', framework.critical]]);
	}
}

function createPlayerOptions(select, players, placeholder) {
	select.replaceChildren();
	const first = document.createElement('option');
	first.value = '';
	first.textContent = placeholder;
	select.append(first);
	for (const player of players) {
		const option = document.createElement('option');
		option.value = String(player.id);
		option.textContent = `#${player.id} · ${player.name}${player.hasCharacter ? '' : ' (sem personagem)'}`;
		select.append(option);
	}
}

function getSelectedPlayer() {
	return (state.data?.players || []).find((player) => String(player.id) === elements.targetPlayer.value);
}

function getItems() {
	return Object.values(state.data?.items || {}).sort((first, second) => first.label.localeCompare(second.label));
}

const itemCategoryLabels = {
	weapons: 'Armas',
	ammo: 'Munições',
	attachments: 'Acessórios',
	food: 'Comidas',
	consumables: 'Consumíveis',
	containers: 'Containers',
	misc: 'Diversos'
};
const itemCategoryOrder = ['weapons', 'ammo', 'attachments', 'food', 'consumables', 'containers', 'misc'];

function getMaxQuantity(item) {
	const maxStack = Number(item.maxStack);
	if (Number.isInteger(maxStack) && maxStack > 0) return Math.min(maxStack, 999);
	return item.stack === false ? 1 : 999;
}

function getCategories() {
	const categories = new Set(getItems().map((item) => item.category || 'misc'));
	return [...categories].sort((first, second) => {
		const firstIndex = itemCategoryOrder.indexOf(first);
		const secondIndex = itemCategoryOrder.indexOf(second);
		return (firstIndex === -1 ? itemCategoryOrder.length : firstIndex)
			- (secondIndex === -1 ? itemCategoryOrder.length : secondIndex)
			|| first.localeCompare(second);
	});
}

function renderCategoryMenu() {
	const categories = getCategories();
	if (state.activeCategory !== 'all' && !categories.includes(state.activeCategory)) {
		state.activeCategory = 'all';
	}
	elements.categoryMenu.replaceChildren();
	const options = [
		{ key: 'all', label: 'Todos', count: getItems().length },
		...categories.map((category) => ({
			key: category,
			label: itemCategoryLabels[category] || category,
			count: getItems().filter((item) => (item.category || 'misc') === category).length
		}))
	];

	for (const option of options) {
		const button = document.createElement('button');
		button.type = 'button';
		button.className = `category-button${state.activeCategory === option.key ? ' is-active' : ''}`;
		button.setAttribute('aria-pressed', String(state.activeCategory === option.key));
		const label = document.createElement('span');
		label.textContent = option.label;
		const count = document.createElement('small');
		count.textContent = String(option.count);
		button.append(label, count);
		button.addEventListener('click', () => {
			state.activeCategory = option.key;
			renderCategoryMenu();
			renderItems();
		});
		elements.categoryMenu.append(button);
	}
}

function updateDeliveryState() {
	const player = getSelectedPlayer();
	elements.targetSummary.textContent = player
		? `ID ${player.id} · ${player.ping} ms · inventário pessoal`
		: 'Escolha um jogador online para continuar.';
	const entries = [...state.cart.values()];
	const validCart = entries.length > 0 && entries.every(({ item, count }) =>
		Number.isInteger(count) && count >= 1 && count <= getMaxQuantity(item)
	);
	const canSubmit = Boolean(player && validCart && !state.deliverySubmission);
	elements.giveItem.disabled = !canSubmit;
	elements.giveItem.querySelector('span').textContent = state.deliverySubmission ? 'Enviando entrega...' : 'Confirmar entrega';
	elements.clearCart.disabled = entries.length === 0 || Boolean(state.deliverySubmission);
}

function renderItems() {
	const query = elements.itemSearch.value.trim().toLowerCase();
	const filtered = getItems().filter((item) => {
		const inCategory = state.activeCategory === 'all' || (item.category || 'misc') === state.activeCategory;
		return inCategory && `${item.label} ${item.name}`.toLowerCase().includes(query);
	});
	elements.itemResults.replaceChildren();
	if (filtered.length === 0) {
		appendEmpty(elements.itemResults, 'Nenhum item corresponde à busca.');
		return;
	}

	const groups = new Map();
	for (const item of filtered) {
		const category = item.category || 'misc';
		if (!groups.has(category)) groups.set(category, []);
		groups.get(category).push(item);
	}

	const categories = [...groups.keys()].sort((first, second) => {
		const firstIndex = itemCategoryOrder.indexOf(first);
		const secondIndex = itemCategoryOrder.indexOf(second);
		return (firstIndex === -1 ? itemCategoryOrder.length : firstIndex)
			- (secondIndex === -1 ? itemCategoryOrder.length : secondIndex)
			|| first.localeCompare(second);
	});

	for (const category of categories) {
		const items = groups.get(category);
		const group = document.createElement('section');
		group.className = 'item-category';
		if (state.activeCategory === 'all') {
			const heading = document.createElement('div');
			heading.className = 'item-category-heading';
			const title = document.createElement('strong');
			title.textContent = itemCategoryLabels[category] || category;
			const count = document.createElement('span');
			count.textContent = String(items.length);
			heading.append(title, count);
			group.append(heading);
		}
		const itemGrid = document.createElement('div');
		itemGrid.className = 'item-category-items';

		for (const item of items) {
			const cartEntry = state.cart.get(item.name);
			const button = document.createElement('button');
			button.type = 'button';
			button.className = `catalog-item${cartEntry ? ' is-selected' : ''}`;
			button.setAttribute('aria-pressed', String(Boolean(cartEntry)));
			button.setAttribute('aria-label', `${cartEntry ? 'Adicionar mais' : 'Adicionar'} ${item.label} à entrega`);
			const image = document.createElement('img');
			image.src = `nui://coe_inventory/data/images/${encodeURIComponent(item.image || `${item.name}.png`)}`;
			image.alt = '';
			image.addEventListener('error', () => image.remove(), { once: true });
			const label = document.createElement('span');
			label.textContent = item.label;
			button.append(image, label);
			if (cartEntry) {
				const quantity = document.createElement('small');
				quantity.className = 'catalog-item-count';
				quantity.textContent = String(cartEntry.count);
				button.append(quantity);
			}
			button.addEventListener('click', () => {
					if (state.deliverySubmission) return;
					const max = getMaxQuantity(item);
					const current = state.cart.get(item.name);
					if (current && current.count >= max) {
						showToast(`Limite máximo de ${max} para ${item.label}.`, 'error');
						return;
					}
					state.cart.set(item.name, { item, count: (current?.count || 0) + 1 });
				renderItems();
					renderCart();
				updateDeliveryState();
			});
			itemGrid.append(button);
		}

		group.append(itemGrid);
		elements.itemResults.append(group);
	}
}

function renderCart() {
	const entries = [...state.cart.values()];
	const units = entries.reduce((total, entry) => total + (Number(entry.count) || 0), 0);
	const weight = entries.reduce((total, entry) => total + (Number(entry.count) || 0) * (Number(entry.item.weight) || 0), 0);
	elements.deliveryCount.textContent = `${entries.length} ${entries.length === 1 ? 'item' : 'itens'} · ${units} un. · ${weight.toLocaleString('pt-BR')} g`;
	elements.deliveryPreview.replaceChildren();
	if (entries.length === 0) {
		const empty = document.createElement('span');
		empty.className = 'preview-empty';
		empty.textContent = 'Adicione itens ao carrinho para montar a entrega.';
		elements.deliveryPreview.append(empty);
		return;
	}

	for (const entry of entries) {
		const { item } = entry;
		const max = getMaxQuantity(item);
		const row = document.createElement('div');
		row.className = 'cart-item';
		const header = document.createElement('div');
		header.className = 'cart-item-header';
		const image = document.createElement('img');
		image.src = `nui://coe_inventory/data/images/${encodeURIComponent(item.image || `${item.name}.png`)}`;
		image.alt = '';
		image.addEventListener('error', () => image.remove(), { once: true });
		const label = document.createElement('strong');
		label.textContent = item.label;
		const remove = document.createElement('button');
		remove.type = 'button';
		remove.className = 'cart-remove';
		remove.textContent = '×';
		remove.title = `Remover ${item.label}`;
		remove.setAttribute('aria-label', `Remover ${item.label} do carrinho`);
		remove.disabled = Boolean(state.deliverySubmission);
		remove.addEventListener('click', () => {
			if (state.deliverySubmission) return;
			state.cart.delete(item.name);
			renderCart();
			renderItems();
			updateDeliveryState();
		});
		header.append(image, label, remove);

		const quantityRow = document.createElement('div');
		quantityRow.className = 'cart-quantity-row';
		const input = document.createElement('input');
		input.type = 'number';
		input.className = 'cart-quantity-input';
		input.min = '1';
		input.max = String(max);
		input.step = '1';
		input.value = String(entry.count);
		input.disabled = Boolean(state.deliverySubmission);
		input.setAttribute('aria-label', `Quantidade de ${item.label}`);
		input.addEventListener('input', () => {
			entry.count = Number(input.value);
			updateCartSummary();
			updateDeliveryState();
		});
		input.addEventListener('change', () => {
			const count = Number(input.value);
			entry.count = Number.isInteger(count) && count >= 1 ? Math.min(count, max) : 1;
			renderCart();
			renderItems();
			updateDeliveryState();
		});
		const maximum = document.createElement('span');
		maximum.className = 'cart-quantity-max';
		maximum.textContent = `Máx. ${max}`;
		quantityRow.append(input, maximum);
		if (max > 1) {
			const maxButton = document.createElement('button');
			maxButton.type = 'button';
			maxButton.className = 'cart-max-button';
			maxButton.textContent = 'Máx.';
			maxButton.title = `Definir quantidade máxima: ${max}`;
			maxButton.disabled = Boolean(state.deliverySubmission);
			maxButton.addEventListener('click', () => {
				entry.count = max;
				renderCart();
				renderItems();
				updateDeliveryState();
			});
			quantityRow.append(maxButton);
		}
		row.append(header, quantityRow);
		elements.deliveryPreview.append(row);
	}
}

function updateCartSummary() {
	const entries = [...state.cart.values()];
	const units = entries.reduce((total, entry) => total + (Number(entry.count) || 0), 0);
	const weight = entries.reduce((total, entry) => total + (Number(entry.count) || 0) * (Number(entry.item.weight) || 0), 0);
	elements.deliveryCount.textContent = `${entries.length} ${entries.length === 1 ? 'item' : 'itens'} · ${units} un. · ${weight.toLocaleString('pt-BR')} g`;
}

function renderStaff() {
	const players = state.data?.players || [];
	const roles = state.data?.roles || {};
	createPlayerOptions(elements.staffPlayer, players, 'Selecione um jogador online');
	elements.staffRole.replaceChildren();
	const rolePlaceholder = document.createElement('option');
	rolePlaceholder.value = '';
	rolePlaceholder.textContent = 'Selecione um cargo';
	elements.staffRole.append(rolePlaceholder);
	for (const [role, definition] of Object.entries(roles)) {
		const option = document.createElement('option');
		option.value = role;
		option.textContent = definition.label || role;
		elements.staffRole.append(option);
	}
	elements.assignStaff.disabled = true;

	const staff = state.data?.staff || [];
	elements.staffCount.textContent = `${staff.length} membro${staff.length === 1 ? '' : 's'}`;
	if (staff.length === 0) {
		appendEmpty(elements.staffList, 'Nenhum membro adicionado à equipe.');
		return;
	}

	elements.staffList.replaceChildren();
	for (const member of staff) {
		const row = document.createElement('div');
		row.className = 'staff-row';
		const id = document.createElement('span');
		id.className = 'player-id';
		id.textContent = member.id ? `#${member.id}` : 'OFF';
		const name = document.createElement('span');
		name.className = 'player-name';
		name.title = member.license;
		name.textContent = member.name;
		const role = document.createElement('span');
		role.className = 'staff-role-label';
		role.textContent = member.roleLabel;
		const remove = document.createElement('button');
		remove.type = 'button';
		remove.className = 'remove-staff';
		remove.textContent = '×';
		remove.title = 'Remover acesso';
		remove.setAttribute('aria-label', `Remover ${member.name} da equipe`);
		remove.addEventListener('click', async () => {
			const ok = await CoeUI.confirm({
				title: 'Remover acesso',
				message: `Remover acesso de ${member.name}?`,
				confirmLabel: 'Remover',
				danger: true
			});
			if (ok) postNui('removeStaff', { license: member.license });
		});
		row.append(id, name, role, remove);
		elements.staffList.append(row);
	}
}

function addOption(select, value, text) {
	const option = document.createElement('option');
	option.value = value;
	option.textContent = text;
	select.append(option);
}

const FAC_SECTIONS = [['general', 'Geral'], ['grades', 'Graus'], ['crafts', 'Crafts'], ['stations', 'Pontos'], ['members', 'Membros']];

function facData() {
	return state.data?.factions || { available: false, categories: [], list: [], recipes: [] };
}

function facNewDraft() {
	const first = facData().categories[0];
	return {
		id: '', label: '', category: first ? first.id : 'gang', enabled: true,
		grades: [{ grade: 0, label: 'Membro' }, { grade: 1, label: 'Líder' }], crafts: [],
		stations: { crafts: [], stashes: [] }
	};
}

function facPayload(draft) {
	return {
		id: draft.id,
		label: draft.label,
		category: draft.category,
		enabled: draft.enabled !== false,
		grades: draft.grades.map((entry) => ({ grade: Number(entry.grade), label: entry.label })),
		crafts: draft.crafts.map((entry) => ({ recipe: entry.recipe, minGrade: Number(entry.minGrade) })),
		stations: draft.stations || { crafts: [], stashes: [] }
	};
}

function facStations(draft) {
	draft.stations = draft.stations || {};
	draft.stations.crafts = Array.isArray(draft.stations.crafts) ? draft.stations.crafts : [];
	draft.stations.stashes = Array.isArray(draft.stations.stashes) ? draft.stations.stashes : [];
	const wrap = bizEl('div');
	wrap.append(
		renderBusinessStations(draft, 'crafts', renderFactionEditor),
		renderBusinessStations(draft, 'stashes', renderFactionEditor)
	);
	return wrap;
}

function facGradeLabel(draft, grade) {
	return draft.grades.find((entry) => Number(entry.grade) === Number(grade))?.label || String(grade);
}

function facGradeSelect(draft, value, onChange) {
	const select = bizEl('select', 'coe-field field-control');
	const grades = [...draft.grades].sort((a, b) => a.grade - b.grade);
	for (const entry of grades) {
		const option = bizEl('option', '', `${entry.grade} · ${entry.label}`);
		option.value = String(entry.grade);
		select.append(option);
	}
	select.value = String(value);
	select.addEventListener('change', () => onChange(Number(select.value)));
	return select;
}

function facGeneral(draft) {
	const block = bizEl('div', 'biz-block');
	const idInput = bizInput('text', draft.id, (value) => { draft.id = value.toLowerCase(); }, { maxlength: 32 });
	idInput.disabled = !state.fac.isNew;
	const category = bizEl('select', 'coe-field field-control');
	for (const entry of facData().categories) {
		const option = bizEl('option', '', entry.label);
		option.value = entry.id;
		category.append(option);
	}
	category.value = draft.category;
	category.addEventListener('change', () => { draft.category = category.value; });
	const enabled = bizEl('input');
	enabled.type = 'checkbox';
	enabled.checked = draft.enabled !== false;
	enabled.addEventListener('change', () => { draft.enabled = enabled.checked; });
	const enabledLabel = bizEl('label', 'biz-check');
	enabledLabel.append(enabled, bizEl('span', '', 'Ativa (inativa não libera crafts)'));
	block.append(
		bizEl('h3', '', 'Identificação'),
		bizField('ID (letras minúsculas, números e _)', idInput),
		bizField('Nome', bizInput('text', draft.label, (value) => { draft.label = value; }, { maxlength: 48 })),
		bizField('Categoria', category),
		enabledLabel
	);
	return block;
}

function facGrades(draft) {
	const block = bizEl('div', 'biz-block');
	block.append(bizEl('h3', '', 'Graus'), bizEl('p', 'biz-hint', 'De 0 a 9. O número maior é a posição mais alta. Remover um grau só vale se ninguém estiver nele.'));
	draft.grades.forEach((entry, index) => {
		const row = bizEl('div', 'fac-row');
		row.append(
			bizInput('number', entry.grade, (value) => { entry.grade = Number(value); }, { min: '0', max: '9', step: '1' }),
			bizInput('text', entry.label, (value) => { entry.label = value; }, { maxlength: 32 })
		);
		const remove = bizEl('button', 'coe-button biz-danger', 'Remover');
		remove.type = 'button';
		remove.disabled = draft.grades.length <= 1;
		remove.addEventListener('click', () => {
			draft.grades.splice(index, 1);
			renderFactionEditor();
		});
		row.append(remove);
		block.append(row);
	});
	const add = bizEl('button', 'coe-button biz-small-button', '+ Grau');
	add.type = 'button';
	add.disabled = draft.grades.length >= 10;
	add.addEventListener('click', () => {
		const used = new Set(draft.grades.map((entry) => Number(entry.grade)));
		let next = 0;
		while (used.has(next)) next += 1;
		draft.grades.push({ grade: next, label: `Grau ${next}` });
		renderFactionEditor();
	});
	block.append(add);
	return block;
}

function facCrafts(draft) {
	const block = bizEl('div', 'biz-block');
	block.append(bizEl('h3', '', 'Crafts liberados'), bizEl('p', 'biz-hint', 'Membros com o grau mínimo (ou maior) usam a receita nas bancadas da facção. Sem crafts, a facção não libera nenhum.'));
	const recipes = facData().recipes || [];
	const labelOf = (id) => recipes.find((recipe) => recipe.id === id)?.label || id;
	if (!draft.crafts.length) block.append(bizEl('p', 'biz-hint', 'Nenhum craft liberado.'));
	draft.crafts.forEach((entry, index) => {
		const row = bizEl('div', 'fac-row');
		row.append(bizEl('span', 'fac-name', `${labelOf(entry.recipe)} · ${entry.recipe}`));
		row.append(facGradeSelect(draft, entry.minGrade, (value) => { entry.minGrade = value; }));
		const remove = bizEl('button', 'coe-button biz-danger', 'Remover');
		remove.type = 'button';
		remove.addEventListener('click', () => {
			draft.crafts.splice(index, 1);
			renderFactionEditor();
		});
		row.append(remove);
		block.append(row);
	});
	const available = recipes.filter((recipe) => !draft.crafts.some((entry) => entry.recipe === recipe.id));
	if (!recipes.length) {
		block.append(bizEl('p', 'biz-hint', 'Catálogo de receitas indisponível (coe_crafting parado).'));
		return block;
	}
	const pick = bizEl('select', 'coe-field field-control');
	for (const recipe of available) {
		const option = bizEl('option', '', `${recipe.label} · ${recipe.category}`);
		option.value = recipe.id;
		pick.append(option);
	}
	const lowest = [...draft.grades].sort((a, b) => a.grade - b.grade)[0];
	let minGrade = lowest ? Number(lowest.grade) : 0;
	const grade = facGradeSelect(draft, minGrade, (value) => { minGrade = value; });
	const add = bizEl('button', 'coe-button biz-small-button', '+ Liberar');
	add.type = 'button';
	add.disabled = !available.length;
	add.addEventListener('click', () => {
		if (!pick.value) return;
		draft.crafts.push({ recipe: pick.value, minGrade });
		renderFactionEditor();
	});
	const form = bizEl('div', 'fac-row');
	form.append(pick, grade, add);
	block.append(bizField('Liberar receita (grau mínimo)', form));
	return block;
}

function facMembers(draft) {
	const block = bizEl('div', 'biz-block');
	block.append(bizEl('h3', '', 'Membros'));
	if (state.fac.isNew) {
		block.append(bizEl('p', 'biz-hint', 'Salve a facção para gerenciar membros.'));
		return block;
	}
	block.append(bizEl('p', 'biz-hint', 'Alterações de membros valem na hora, sem precisar salvar a facção. Funciona com jogadores offline.'));
	let addGrade = Math.min(...draft.grades.map((entry) => Number(entry.grade)));
	const addRow = bizEl('div', 'fac-add');
	addRow.append(bizField('Adicionar: buscar pelo nome do personagem ou ID', bizCharacterPicker((character) => {
		postNui('setFactionMember', { id: draft.id, characterId: character.characterId, grade: addGrade });
	})), bizField('Grau inicial', facGradeSelect(draft, addGrade, (value) => { addGrade = value; })));
	block.append(addRow);
	const members = state.fac.members;
	if (members.id !== draft.id || members.list === null) {
		block.append(bizEl('p', 'biz-hint', members.error ? 'Não foi possível carregar os membros.' : 'Carregando membros...'));
		return block;
	}
	block.append(bizEl('p', 'biz-hint', `${members.list.length} membro${members.list.length === 1 ? '' : 's'}`));
	if (!members.list.length) block.append(bizEl('p', 'biz-hint', 'Nenhum membro.'));
	for (const member of members.list) {
		const row = bizEl('div', 'fac-row');
		row.append(bizEl('span', 'fac-name', member.name || `Personagem ${member.characterId}`), bizEl('small', 'char-result-id', member.stateId || ''));
		row.append(facGradeSelect(draft, member.grade, (value) => {
			postNui('setFactionMember', { id: draft.id, characterId: member.characterId, grade: value });
		}));
		const remove = bizEl('button', 'coe-button biz-danger', 'Remover');
		remove.type = 'button';
		remove.addEventListener('click', async () => {
			const ok = await CoeUI.confirm({
				title: 'Remover da facção',
				message: `Remover ${member.name || member.characterId} de ${draft.label || draft.id}?`,
				confirmLabel: 'Remover',
				danger: true
			});
			if (ok) postNui('removeFactionMember', { id: draft.id, characterId: member.characterId });
		});
		row.append(remove);
		block.append(row);
	}
	return block;
}

function facLoadMembers() {
	const draft = state.fac.draft;
	if (!draft || state.fac.isNew) return;
	state.fac.members = { id: draft.id, list: null, error: null, requestId: null };
	postNui('getFactionMembers', { id: draft.id }).then((result) => {
		if (result.ok && state.fac.members.id === draft.id) state.fac.members.requestId = result.requestId;
	});
}

function renderFactionEditor() {
	const host = document.getElementById('fac-editor');
	if (!host) return;
	const draft = state.fac.draft;
	host.replaceChildren();
	if (!draft) {
		host.append(bizEl('div', 'empty-state', 'Selecione uma facção ou crie uma nova.'));
		return;
	}
	const heading = bizEl('div', 'panel-heading');
	heading.append(bizEl('h2', '', state.fac.isNew ? 'Nova facção' : `Editar: ${draft.label || draft.id}`));
	host.append(heading);
	const tabs = bizEl('div', 'biz-sections');
	tabs.setAttribute('role', 'tablist');
	for (const [key, text] of FAC_SECTIONS) {
		const tab = bizEl('button', `biz-tab${key === state.fac.section ? ' is-active' : ''}`, text);
		tab.type = 'button';
		tab.addEventListener('click', () => {
			state.fac.section = key;
			if (key === 'members') facLoadMembers();
			renderFactionEditor();
		});
		tabs.append(tab);
	}
	host.append(tabs);
	const body = bizEl('div', 'biz-section-body');
	if (state.fac.section === 'general') body.append(facGeneral(draft));
	else if (state.fac.section === 'grades') body.append(facGrades(draft));
	else if (state.fac.section === 'crafts') body.append(facCrafts(draft));
	else if (state.fac.section === 'stations') body.append(facStations(draft));
	else body.append(facMembers(draft));
	host.append(body);

	const actions = bizEl('div', 'biz-actions');
	const save = bizEl('button', 'coe-button coe-button--primary primary-button', 'Salvar facção');
	save.type = 'button';
	save.addEventListener('click', () => {
		postNui('saveFaction', { faction: facPayload(draft) }).then((result) => {
			if (!result.ok) showToast('Não foi possível enviar a facção.', false);
		});
	});
	actions.append(save);
	if (!state.fac.isNew) {
		const remove = bizEl('button', 'coe-button biz-danger', 'Remover');
		remove.type = 'button';
		remove.addEventListener('click', () => {
			if (remove.dataset.confirm !== '1') {
				remove.dataset.confirm = '1';
				remove.textContent = 'Confirmar remoção (apaga também os membros)';
				return;
			}
			postNui('deleteFaction', { id: draft.id });
		});
		actions.append(remove);
	}
	host.append(actions);
}

function renderFactions() {
	const data = facData();
	const list = document.getElementById('fac-list');
	if (!list) return;
	list.replaceChildren();
	if (!data.available) {
		appendEmpty(list, 'O resource coe_factions não está iniciado.');
		renderFactionEditor();
		return;
	}
	const categoryLabel = (id) => data.categories.find((entry) => entry.id === id)?.label || id;
	if (!data.list.length) appendEmpty(list, 'Nenhuma facção cadastrada.');
	for (const entry of data.list) {
		const row = bizEl('button', `biz-item${state.fac.draft?.id === entry.id && !state.fac.isNew ? ' is-active' : ''}`);
		row.type = 'button';
		row.append(bizEl('strong', '', entry.label), bizEl('small', '', `${categoryLabel(entry.category)} · ${entry.id}${entry.enabled === false ? ' · inativa' : ''}`));
		row.addEventListener('click', () => {
			state.fac.draft = JSON.parse(JSON.stringify(entry));
			state.fac.draft.stations = state.fac.draft.stations || { crafts: [], stashes: [] };
			state.fac.isNew = false;
			if (state.fac.section === 'members') facLoadMembers();
			renderFactions();
			renderFactionEditor();
		});
		list.append(row);
	}
	if (!state.fac.draft) renderFactionEditor();
}

document.getElementById('fac-new').addEventListener('click', () => {
	state.fac.draft = facNewDraft();
	state.fac.isNew = true;
	state.fac.section = 'general';
	renderFactions();
	renderFactionEditor();
});

function onFactionResult(data) {
	const message = document.getElementById('fac-message');
	message.textContent = data.message || '';
	message.classList.toggle('is-success', data.success === true);
	if (data.success !== true) return;
	if (data.operation === 'factionMember') {
		facLoadMembers();
		renderFactionEditor();
		return;
	}
	if (data.operation === 'factionDelete') {
		state.fac.draft = null;
	} else {
		state.fac.isNew = false;
	}
}

function renderFramework() {
	const all = state.data?.resources || [];
	const query = elements.frameworkSearch.value.trim().toLowerCase();
	const categoryLabel = (id) => FRAMEWORK_CATEGORIES.find((category) => category.id === id)?.label || '';
	const resources = query
		? all.filter((resource) => [resource.name, resource.description, categoryLabel(resource.category), resource.state, resource.critical ? 'crítico' : '']
			.some((value) => String(value || '').toLowerCase().includes(query)))
		: all;
	elements.frameworkCount.textContent = query
		? `${resources.length} de ${all.length} resources`
		: `${all.length} resource${all.length === 1 ? '' : 's'}`;
	if (!state.data?.supervisorAvailable) {
		appendEmpty(elements.frameworkList, 'O coe_supervisor não está iniciado. Adicione "ensure coe_supervisor" ao server.cfg.');
		return;
	}

	elements.frameworkList.replaceChildren();
	if (!resources.length) {
		appendEmpty(elements.frameworkList, 'Nenhum resource encontrado para o filtro.');
		return;
	}
	const relation = (label, names) => {
		const line = make('div', 'resource-relation');
		line.append(make('span', 'resource-relation-label', label));
		line.append(make('span', 'resource-relation-values', names.length ? names.join(', ') : 'nenhum'));
		return line;
	};
	const groups = new Map(FRAMEWORK_CATEGORIES.map((category) => [category.id, []]));
	for (const resource of resources) {
		const id = groups.has(resource.category) ? resource.category : 'other';
		groups.get(id).push(resource);
	}
	for (const category of FRAMEWORK_CATEGORIES) {
		const members = groups.get(category.id);
		if (!members.length) continue;
		const section = make('section', 'resource-group');
		const heading = make('div', 'resource-group-head');
		heading.append(make('h3', 'resource-group-title', category.label), make('span', 'resource-group-count', String(members.length)), make('span', 'resource-group-hint', category.hint));
		const grid = make('div', 'resource-list');
		for (const resource of members) grid.append(frameworkCard(resource, relation));
		section.append(heading, grid);
		elements.frameworkList.append(section);
	}
}

function frameworkCard(resource, relation) {
	const order = resource.restart || [resource.name];
	const others = order.filter((name) => name !== resource.name);
	const critical = resource.critical === true;
	const card = make('article', `resource-card${critical ? ' is-critical' : ''}`);
	const head = make('div', 'resource-head');
	head.append(make('h3', 'resource-name', resource.name));
	if (critical) head.append(make('span', 'resource-critical', 'CRÍTICO'));
	if (resource.version) head.append(make('span', 'resource-version', `v${resource.version}`));
	head.append(make('span', `resource-state is-${resource.state}`, resource.state));
	const restart = make('button', `resource-restart${critical ? ' is-critical' : ''}`, 'Reiniciar');
	restart.type = 'button';
	restart.setAttribute('aria-label', `Reiniciar ${resource.name}`);
	restart.addEventListener('click', async () => {
		const sequence = order.join(' → ');
		const impact = others.length
			? `Também serão reiniciados (${others.length}): ${others.join(', ')}.`
			: 'Nenhum outro resource será reiniciado.';
		const confirmed = await CoeUI.confirm(critical ? {
			title: `⚠ PERIGO: reiniciar ${resource.name}`,
			message: `ISTO É UM RESOURCE CRÍTICO.\nSe algo der errado, TUDO pode ir pro caralho: jogadores desconectados, dados sem salvar e o servidor quebrado até um reinício completo.\n\n${impact}\n\nOrdem: ${sequence}\n\nSó continue se souber exatamente o que está fazendo.`,
			confirmLabel: 'Reiniciar mesmo assim',
			danger: true,
			panic: true,
			requireText: resource.name
		} : {
			title: `Reiniciar ${resource.name}`,
			message: `${impact}\n\nOrdem do reinício:\n${sequence}\n\nO painel pode fechar durante o processo.`,
			confirmLabel: 'Reiniciar',
			danger: true
		});
		if (!confirmed) return;
		const result = await postNui('restartResource', { name: resource.name });
		if (!result.ok) showToast('Não foi possível enviar o reinício.', false);
	});
	head.append(restart);
	card.append(head);
	card.append(make('p', 'resource-description', resource.description || 'Sem descrição no fxmanifest.'));
	const details = make('div', 'resource-details');
	details.append(relation('Depende de', resource.dependencies || []));
	details.append(relation('Dependentes', resource.dependents || []));
	details.append(relation('Também reinicia', others));
	details.append(relation('Ordem do reinício', order));
	card.append(details);
	if (critical) card.append(make('p', 'resource-warning', 'Reiniciar este resource afeta o servidor inteiro. Use apenas em manutenção.'));
	return card;
}
const FRAMEWORK_CATEGORIES = [
	{ id: 'infrastructure', label: 'Infraestrutura', hint: 'Logs, banco de dados e auditoria' },
	{ id: 'core', label: 'Núcleo', hint: 'Jogadores, personagens ativos e eventos' },
	{ id: 'interface', label: 'Interface', hint: 'Biblioteca de UI, notificações, HUD, mapa e tela de carregamento' },
	{ id: 'gameplay', label: 'Jogabilidade', hint: 'Spawn, personagens, inventário, target, necessidades e veículos' },
	{ id: 'business', label: 'Negócios e economia', hint: 'Negócios, economia, craft, garagens, moradias e mecânica' },
	{ id: 'administration', label: 'Administração', hint: 'Painel administrativo' },
	{ id: 'other', label: 'Outros', hint: '' }
];function make(tag, className, text) {
	const node = document.createElement(tag);
	if (className) node.className = className;
	if (text !== undefined) node.textContent = text;
	return node;
}

function renderThemes() {
	const theme = state.data?.theme || { options: [] };
	elements.themeList.replaceChildren();
	for (const option of theme.options || []) {
		const card = make('button', 'theme-card', '');
		card.type = 'button';
		card.setAttribute('aria-pressed', String(option.name === theme.current));
		card.classList.toggle('is-active', option.name === theme.current);
		const swatch = make('span', 'theme-swatch', '');
		swatch.style.background = option.base;
		swatch.style.borderColor = option.swatch;
		const dot = make('span', 'theme-dot', '');
		dot.style.background = option.swatch;
		swatch.append(dot);
		card.append(swatch, make('strong', '', option.label), make('small', '', option.name === theme.current ? 'Em uso' : 'Aplicar'));
		card.addEventListener('click', async () => {
			if (option.name === theme.current) return;
			const result = await postNui('setTheme', { name: option.name });
			if (!result.ok) showToast('Não foi possível enviar a alteração.', false);
		});
		elements.themeList.append(card);
	}
}

function renderData(data) {
	state.data = data;
	applyPermissions(data);
	const name = data.actor?.name || 'Administrador';
	elements.adminName.textContent = name;
	elements.adminAvatar.textContent = name.trim().charAt(0).toUpperCase() || 'A';
	elements.metricItems.textContent = String(Object.keys(data.items || {}).length);
	elements.metricStaff.textContent = String((data.staff || []).length);
	elements.sessionCatalogCount.textContent = `${Object.keys(data.items || {}).length} itens`;
	elements.sessionRole.textContent = data.permissions?.manageStaff ? 'Gestão de equipe' : data.permissions?.giveItems ? 'Entrega de itens' : 'Visualização';
	renderOnlinePlayers();
	renderAnalytics(data.analytics, data.crypto);
	createPlayerOptions(elements.targetPlayer, data.players || [], 'Selecione um jogador');
	renderCategoryMenu();
	renderItems();
	renderCart();
	renderStaff();
	renderFactions();
	renderFramework();
	renderThemes();
	renderBusinesses();
	renderGarages();
	if (typeof renderRentals === 'function') renderRentals();
	renderHousing();
	renderDoors();
	renderAmzg();
	renderNews();
	renderBanking();
	if (typeof renderCrypto === 'function') renderCrypto();
	if (typeof renderDeepweb === 'function') renderDeepweb();
}

const BIZ_SECTIONS = [['general', 'Geral'], ['area', 'Área'], ['stations', 'Pontos'], ['rules', 'Regras'], ['menu', 'Cardápio'], ['owner', 'Dono'], ['grades', 'Cargos'], ['staff', 'Equipe']];
const BIZ_ORDER = ['mechanic', 'shop', 'gas_station', 'restaurant', 'media', 'other'];
const BIZ_KINDS = { showroom: 'Showroom (área de vitrine)', crafts: 'Mesas de craft', stashes: 'Baús', clocks: 'Pontos de ponto (bater cartão)' };
const BIZ_STATION_NAMES = {
	crafts: { label: 'mesa de craft', prefix: 'mesa', title: 'Mesa' },
	stashes: { label: 'baú', prefix: 'bau', title: 'Baú' },
	clocks: { label: 'ponto', prefix: 'ponto', title: 'Ponto' }
};
const BIZ_RULES = {
	ownerAccess: { label: 'Dono pode trabalhar/operar', type: 'bool', default: true },
	clockRequired: { label: 'Equipe precisa bater o ponto para trabalhar', type: 'bool', default: true },
	clockOffsite: { label: 'Permitir ponto batido fora da área do negócio', type: 'bool', default: false },
	multiJob: { label: 'Equipe pode ter outros empregos (desligado = dedicação exclusiva)', type: 'bool', default: true },
	priceMultiplier: { label: 'Multiplicador de preço (0.5 a 3)', type: 'number', step: '0.05' }
};

function bizEl(tag, className, text) {
	const node = document.createElement(tag);
	if (className) node.className = className;
	if (text !== undefined) node.textContent = text;
	return node;
}

function bizCategories() {
	const categories = state.data?.businesses?.categories || {};
	const keys = Object.keys(categories).sort((a, b) => {
		const ia = BIZ_ORDER.indexOf(a);
		const ib = BIZ_ORDER.indexOf(b);
		return (ia < 0 ? 99 : ia) - (ib < 0 ? 99 : ib);
	});
	return { categories, keys };
}

function bizNumber(value, fallback) {
	const parsed = Number(value);
	return Number.isFinite(parsed) ? parsed : fallback;
}

function bizField(labelText, input) {
	const wrapper = bizEl('label', 'biz-field');
	wrapper.append(bizEl('span', 'field-label', labelText), input);
	return wrapper;
}

function bizInput(type, value, onInput, attrs = {}) {
	const input = bizEl('input', 'coe-field field-control');
	input.type = type;
	input.value = value ?? '';
	for (const [key, attr] of Object.entries(attrs)) input.setAttribute(key, attr);
	input.addEventListener('input', () => onInput(input.value));
	return input;
}

function bizCapture(options, apply) {
	state.biz.pendingCapture = apply;
	postNui('capture', options).then((result) => {
		if (!result.ok) {
			state.biz.pendingCapture = null;
			showToast('Não foi possível iniciar a marcação.', false);
		}
	});
}

function bizPointText(entry) {
	return entry && Number.isFinite(entry.x) ? `${entry.x.toFixed(1)}, ${entry.y.toFixed(1)}, ${entry.z.toFixed(1)}` : 'não marcado';
}

function bizPreview(draft) {
	const preview = [];
	if (draft.area?.kind === 'circle') preview.push(draft.area);
	if (draft.area?.kind === 'polygon') {
		for (const entry of draft.area.points) preview.push({ x: entry.x, y: entry.y, z: draft.area.z });
	}
	if (draft.stations.showroom) preview.push(draft.stations.showroom);
	for (const kind of ['crafts', 'stashes', 'clocks']) preview.push(...(draft.stations[kind] || []));
	return preview.filter((entry) => Number.isFinite(entry.x) && Number.isFinite(entry.y) && Number.isFinite(entry.z));
}

function bizNewDraft(category) {
	const { categories } = bizCategories();
	const definition = categories[category] || { stations: [], rules: [] };
	const rules = {};
	for (const name of definition.rules || []) {
		const schema = state.data?.businesses?.rules?.[name];
		if (schema && schema.default !== undefined) rules[name] = schema.default;
	}
	const stations = {};
	for (const kind of definition.stations || []) if (kind !== 'showroom') stations[kind] = [];
	return { id: '', category, label: '', enabled: true, area: { kind: 'circle', radius: 30 }, stations, rules };
}

function renderBusinessArea(draft) {
	const box = bizEl('div', 'biz-block');
	box.append(bizEl('h3', '', 'Área do negócio'));
	const kind = bizEl('select', 'coe-field field-control');
	for (const [value, text] of [['circle', 'Círculo'], ['polygon', 'Polígono']]) {
		const option = bizEl('option', '', text);
		option.value = value;
		kind.append(option);
	}
	kind.value = draft.area.kind;
	kind.addEventListener('change', () => {
		draft.area = kind.value === 'circle'
			? { kind: 'circle', radius: 30 }
			: { kind: 'polygon', points: [], z: 0, height: 12 };
		renderBusinessEditor();
	});
	box.append(bizField('Formato', kind));

	if (draft.area.kind === 'circle') {
		const mark = bizEl('button', 'coe-button biz-small-button', 'Marcar centro aqui');
		mark.type = 'button';
		mark.addEventListener('click', () => bizCapture({ label: 'centro da área', preview: bizPreview(draft) }, (data) => {
			if (data.point) Object.assign(draft.area, data.point);
		}));
		box.append(bizEl('p', 'biz-hint', `Centro: ${bizPointText(draft.area)}`), mark);
		box.append(bizField('Raio (3 a 300 m)', bizInput('number', draft.area.radius, (value) => { draft.area.radius = bizNumber(value, 0); }, { min: 3, max: 300 })));
	} else {
		const mark = bizEl('button', 'coe-button biz-small-button', 'Marcar vértices no mapa');
		mark.type = 'button';
		mark.addEventListener('click', () => bizCapture({ multi: true, min: 3, label: 'vértices da área', preview: bizPreview(draft) }, (data) => {
			if (!data.points) return;
			draft.area.points = data.points.map(({ x, y }) => ({ x, y }));
			draft.area.z = Math.min(...data.points.map((entry) => entry.z)) - 1;
		}));
		box.append(bizEl('p', 'biz-hint', `${draft.area.points.length} vértices (mín. 3, máx. 16). Z base: ${Number(draft.area.z).toFixed(1)}`), mark);
		box.append(bizField('Altura (3 a 200 m)', bizInput('number', draft.area.height, (value) => { draft.area.height = bizNumber(value, 0); }, { min: 3, max: 200 })));
	}
	return box;
}

function renderBusinessStations(draft, kind, onRender = renderBusinessEditor) {
	const box = bizEl('div', 'biz-block');
	if (kind === 'showroom') {
		box.append(bizEl('h3', '', BIZ_KINDS.showroom));
		const current = draft.stations.showroom;
		const mark = bizEl('button', 'coe-button biz-small-button', current ? 'Remarcar aqui' : 'Marcar aqui');
		mark.type = 'button';
		mark.addEventListener('click', () => bizCapture({ label: 'showroom', preview: bizPreview(draft) }, (data) => {
			if (data.point) draft.stations.showroom = { ...data.point, radius: current?.radius || 6 };
		}));
		box.append(bizEl('p', 'biz-hint', `Posição: ${bizPointText(current)}`), mark);
		if (current) box.append(bizField('Raio (2 a 20 m)', bizInput('number', current.radius, (value) => { current.radius = bizNumber(value, 0); }, { min: 2, max: 20 })));
		return box;
	}

	const list = draft.stations[kind] || (draft.stations[kind] = []);
	const head = bizEl('div', 'biz-block-head');
	head.append(bizEl('h3', '', `${BIZ_KINDS[kind]} (${list.length}/8)`));
	const add = bizEl('button', 'coe-button biz-small-button', '+ Marcar novo');
	add.type = 'button';
	add.disabled = list.length >= 8;
	const names = BIZ_STATION_NAMES[kind];
	add.addEventListener('click', () => bizCapture({ label: names.label, preview: bizPreview(draft) }, (data) => {
		if (!data.point) return;
		let index = list.length + 1;
		while (list.some((entry) => entry.id === `${names.prefix}${index}`)) index += 1;
		const id = `${names.prefix}${index}`;
		const entry = { id, label: `${names.title} ${index}`, ...data.point, radius: 1.5 };
		if (kind === 'stashes') Object.assign(entry, { slots: 40, maxWeight: 150000 });
		list.push(entry);
	}));
	head.append(add);
	box.append(head);

	list.forEach((entry, index) => {
		const row = bizEl('div', 'biz-station');
		const fields = bizEl('div', 'biz-station-fields');
		fields.append(bizField('ID', bizInput('text', entry.id, (value) => { entry.id = value.toLowerCase(); }, { maxlength: 24 })));
		fields.append(bizField('Nome', bizInput('text', entry.label, (value) => { entry.label = value; }, { maxlength: 32 })));
		fields.append(bizField('Raio', bizInput('number', entry.radius, (value) => { entry.radius = bizNumber(value, 0); }, { min: 0.5, max: 5, step: '0.1' })));
		if (kind === 'stashes') {
			fields.append(bizField('Slots', bizInput('number', entry.slots, (value) => { entry.slots = bizNumber(value, 0); }, { min: 1, max: 200 })));
			fields.append(bizField('Peso máx. (g)', bizInput('number', entry.maxWeight, (value) => { entry.maxWeight = bizNumber(value, 0); }, { min: 1000, max: 1000000 })));
		}
		row.append(fields);
		const foot = bizEl('div', 'biz-station-foot');
		foot.append(bizEl('p', 'biz-hint', bizPointText(entry)));
		const actions = bizEl('div', 'biz-station-actions');
		const remark = bizEl('button', 'coe-button biz-small-button', 'Remarcar');
		remark.type = 'button';
		remark.addEventListener('click', () => bizCapture({ label: entry.label, preview: bizPreview(draft) }, (data) => {
			if (data.point) Object.assign(entry, data.point);
		}));
		const remove = bizEl('button', 'coe-button biz-small-button biz-danger', 'Remover');
		remove.type = 'button';
		remove.addEventListener('click', () => {
			list.splice(index, 1);
			onRender();
		});
		actions.append(remark, remove);
		foot.append(actions);
		row.append(foot);
		box.append(row);
	});
	return box;
}

function renderBusinessRules(draft, names) {
	const box = bizEl('div', 'biz-block');
	box.append(bizEl('h3', '', 'Regras'));
	for (const name of names) {
		const meta = BIZ_RULES[name];
		if (!meta) continue;
		if (meta.type === 'bool') {
			const input = bizEl('input');
			input.type = 'checkbox';
			input.checked = draft.rules[name] ?? meta.default !== false;
			input.addEventListener('change', () => { draft.rules[name] = input.checked; });
			const wrapper = bizEl('label', 'biz-check');
			wrapper.append(input, bizEl('span', '', meta.label));
			box.append(wrapper);
		} else if (meta.type === 'number') {
			box.append(bizField(meta.label, bizInput('number', draft.rules[name] ?? 1, (value) => { draft.rules[name] = bizNumber(value, 1); }, { min: 0.5, max: 3, step: meta.step })));
		} else {
			box.append(bizField(meta.label, bizInput('text', draft.rules[name] ?? '', (value) => { draft.rules[name] = value; }, { maxlength: 32 })));
		}
	}
	return box;
}

function bizOwnerText(draft) {
	return draft.owner
		? `Dono atual: ${draft.owner.name || 'sem nome'}`
		: 'Sem dono definido.';
}

const characterSearch = { requestId: null, show: null };

// Busca de personagem por nome ou ID: espera o usuário parar de digitar e só mostra a resposta mais recente.
function bizCharacterPicker(onPick) {
	const wrap = bizEl('div', 'char-picker');
	const input = bizEl('input', 'coe-field field-control');
	input.type = 'search';
	input.maxLength = 64;
	input.autocomplete = 'off';
	input.placeholder = 'Digite ao menos 2 letras do nome, ou o ID';
	const list = bizEl('div', 'char-results');
	let timer;
	const show = (results, error) => {
		list.replaceChildren();
		if (error === 'term_too_short') return;
		if (error) {
			list.append(bizEl('p', 'biz-hint', 'Não foi possível buscar agora.'));
			return;
		}
		if (!results.length) {
			list.append(bizEl('p', 'biz-hint', 'Nenhum personagem encontrado.'));
			return;
		}
		for (const character of results) {
			const row = bizEl('button', 'char-result');
			row.type = 'button';
			row.append(bizEl('span', 'char-result-name', character.name), bizEl('span', 'char-result-id', character.stateId));
			if (character.online) row.append(bizEl('span', 'online-tag', 'Online'));
			row.addEventListener('click', () => {
				onPick(character);
				input.value = '';
				list.replaceChildren();
			});
			list.append(row);
		}
	};
	input.addEventListener('input', () => {
		clearTimeout(timer);
		const term = input.value.trim();
		if (term.length < 2) {
			characterSearch.requestId = null;
			list.replaceChildren();
			return;
		}
		timer = setTimeout(async () => {
			const result = await postNui('searchCharacters', { term });
			if (result.ok) {
				characterSearch.requestId = result.requestId;
				characterSearch.show = show;
			}
		}, 300);
	});
	wrap.append(input, list);
	return wrap;
}

function renderBusinessOwner(draft) {
	const box = bizEl('div', 'biz-block');
	box.append(bizEl('h3', '', 'Dono'));
	const current = bizEl('p', 'biz-hint', bizOwnerText(draft));
	current.id = 'biz-owner-label';
	box.append(current);
	const picked = bizEl('p', 'biz-hint', draft.ownerPick ? 'Novo dono ao salvar: ' + draft.ownerPick : '');
	box.append(bizField('Definir dono: buscar pelo nome do personagem ou ID', bizCharacterPicker((character) => {
		draft.ownerStateId = character.stateId;
		draft.ownerPick = character.name + ' (' + character.stateId + ')';
		draft.clearOwner = false;
		picked.textContent = 'Novo dono ao salvar: ' + draft.ownerPick;
	})));
	box.append(picked);
	const clear = bizEl('input');
	clear.type = 'checkbox';
	clear.checked = draft.clearOwner === true;
	clear.addEventListener('change', () => { draft.clearOwner = clear.checked; });
	const clearLabel = bizEl('label', 'biz-check');
	clearLabel.append(clear, bizEl('span', '', 'Remover dono ao salvar'));
	box.append(clearLabel);
	const mode = bizEl('select');
	for (const [value, text] of [['keep', 'Manter a equipe atual'], ['dismiss', 'Demitir toda a equipe']]) {
		const option = bizEl('option', '', text);
		option.value = value;
		mode.append(option);
	}
	mode.value = draft.staffOnOwnerChange === 'dismiss' ? 'dismiss' : 'keep';
	mode.addEventListener('change', () => { draft.staffOnOwnerChange = mode.value; });
	box.append(bizField('Se o dono mudar (ou for removido), a equipe', mode));
	box.append(bizEl('p', 'biz-hint', 'O dono tem acesso completo ao tablet do negócio. Vale ao salvar.'));
	return box;
}

function bizGradeSelect(draft, current, onChange) {
	const select = bizEl('select');
	const grades = (draft.grades || []).filter((grade) => grade.id);
	if (!grades.length) select.hidden = true;
	const entry = grades.slice().sort((a, b) => Number(a.level) - Number(b.level))[0];
	for (const grade of grades) {
		const option = bizEl('option', '', `${grade.label || grade.id} (nível ${grade.level})`);
		option.value = grade.id;
		select.append(option);
	}
	select.value = grades.some((grade) => grade.id === current) ? current : (entry ? entry.id : '');
	select.addEventListener('change', () => onChange(select.value));
	return select;
}

function renderBusinessGrades(draft, catalogOverride) {
	const box = bizEl('div', 'biz-block');
	box.append(bizEl('h3', '', 'Cargos e salários'));
	box.append(bizEl('p', 'biz-hint', 'Cada negócio define os seus cargos. O menor nível é o cargo de entrada. O salário é pago pela conta da sociedade, só a quem está em serviço. Remover um cargo exige antes mover a equipe para outro.'));
	draft.grades = Array.isArray(draft.grades) ? draft.grades : [];
	const catalog = catalogOverride || state.data?.businesses?.permissions || {};
	const list = bizEl('div', 'biz-staff');
	const paint = () => {
		list.replaceChildren();
		if (!draft.grades.length) list.append(bizEl('p', 'biz-hint', 'Nenhum cargo: a equipe não tem cargo nem salário.'));
		draft.grades.forEach((grade, index) => {
			const card = bizEl('div', 'biz-block');
			const head = bizEl('div', 'biz-staff-row');
			const remove = bizEl('button', 'biz-button', 'Remover cargo');
			remove.type = 'button';
			remove.addEventListener('click', () => {
				draft.grades.splice(index, 1);
				paint();
			});
			head.append(bizField('ID', bizInput('text', grade.id, (value) => { grade.id = value.toLowerCase(); }, { maxlength: 24 })),
				bizField('Nome', bizInput('text', grade.label, (value) => { grade.label = value; }, { maxlength: 32 })),
				bizField('Nível', bizInput('number', grade.level, (value) => { grade.level = value; }, { min: 0, max: 99 })),
				bizField('Salário', bizInput('number', grade.salary, (value) => { grade.salary = value; }, { min: 0 })),
				remove);
			card.append(head);
			grade.permissions = Array.isArray(grade.permissions) ? grade.permissions : [];
			const perms = bizEl('div', 'biz-staff');
			for (const name of Object.keys(catalog).sort()) {
				const box = document.createElement('input');
				box.type = 'checkbox';
				box.checked = grade.permissions.includes(name);
				box.addEventListener('change', () => {
					grade.permissions = grade.permissions.filter((entry) => entry !== name);
					if (box.checked) grade.permissions.push(name);
				});
				const label = bizEl('label', 'biz-check');
				label.append(box, bizEl('span', '', `${catalog[name]} (${name})`));
				perms.append(label);
			}
			card.append(perms);
			list.append(card);
		});
	};
	paint();
	box.append(list);
	const add = bizEl('button', 'biz-button', 'Adicionar cargo');
	add.type = 'button';
	add.addEventListener('click', () => {
		const levels = draft.grades.map((grade) => Number(grade.level) || 0);
		draft.grades.push({ id: '', label: '', level: levels.length ? Math.max(...levels) + 1 : 0, salary: 0, permissions: [] });
		paint();
	});
	box.append(add);
	return box;
}

function renderBusinessStaff(draft) {
	const box = bizEl('div', 'biz-block');
	box.append(bizEl('h3', '', 'Equipe'));
	box.append(bizEl('p', 'biz-hint', 'Só quem está nesta lista (e o dono) opera este negócio. O emprego não vale: cada negócio tem a sua equipe.'));
	draft.staff = Array.isArray(draft.staff) ? draft.staff : [];
	const list = bizEl('div', 'biz-staff');
	const paint = () => {
		list.replaceChildren();
		if (!draft.staff.length) list.append(bizEl('p', 'biz-hint', 'Nenhum funcionário.'));
		for (const member of draft.staff) {
			const row = bizEl('div', 'biz-staff-row');
			const remove = bizEl('button', 'biz-button', 'Remover');
			remove.type = 'button';
			remove.addEventListener('click', () => {
				draft.staff = draft.staff.filter((entry) => entry.characterId !== member.characterId);
				paint();
			});
			row.append(bizEl('span', '', member.name || member.characterId), bizGradeSelect(draft, member.grade, (value) => { member.grade = value; }), remove);
			list.append(row);
		}
	};
	paint();
	box.append(list);
	draft.staffAdd = Array.isArray(draft.staffAdd) ? draft.staffAdd : [];
	const pending = bizEl('div', 'biz-staff');
	const paintPending = () => {
		pending.replaceChildren();
		for (const entry of draft.staffAdd) {
			const row = bizEl('div', 'biz-staff-row');
			const remove = bizEl('button', 'biz-button', 'Desfazer');
			remove.type = 'button';
			remove.addEventListener('click', () => {
				draft.staffAdd = draft.staffAdd.filter((item) => item.stateId !== entry.stateId);
				paintPending();
			});
			row.append(bizEl('span', '', entry.name + ' (' + entry.stateId + ') · entra ao salvar'), bizGradeSelect(draft, entry.grade, (value) => { entry.grade = value; }), remove);
			pending.append(row);
		}
	};
	paintPending();
	box.append(bizField('Adicionar funcionário: buscar pelo nome do personagem ou ID', bizCharacterPicker((character) => {
		const known = draft.staff.some((member) => member.characterId === character.characterId)
			|| draft.staffAdd.some((entry) => entry.stateId === character.stateId);
		if (known) return;
		draft.staffAdd.push({ stateId: character.stateId, name: character.name });
		paintPending();
	})));
	box.append(pending);
	box.append(bizEl('p', 'biz-hint', 'Remoções e a inclusão valem ao salvar. Quem sai da equipe tem o ponto encerrado.'));
	return box;
}

function bizVehicleCard(model, name, caption, button) {
	const card = bizEl('div', 'biz-vehicle');
	const photo = bizEl('div', 'biz-vehicle-photo');
	const image = bizEl('img');
	image.loading = 'lazy';
	image.alt = '';
	image.src = `https://docs.fivem.net/vehicles/${encodeURIComponent(model)}.webp`;
	image.addEventListener('error', () => { image.remove(); photo.textContent = model; });
	photo.append(image);
	card.append(photo, bizEl('strong', '', name || model), bizEl('small', '', caption), button);
	return card;
}

function fillGarageFleet(box, draft) {
	box.replaceChildren();
	const fleet = state.data?.garages?.fleets?.[draft.id];
	box.append(bizEl('h3', '', `Frota da garagem${fleet ? ` (${fleet.length})` : ''}`));
	if (!fleet) {
		box.append(bizEl('p', 'biz-hint', 'Salve a garagem para montar a frota.'));
		return;
	}
	const catalog = state.data?.garages?.vehicleCatalog || [];
	const names = new Map(catalog.map((entry) => [entry.model, entry.name]));
	const grid = bizEl('div', 'biz-vehicle-grid');
	for (const vehicle of fleet) {
		const remove = bizEl('button', 'coe-button biz-small-button biz-danger', 'Remover');
		remove.type = 'button';
		remove.disabled = vehicle.state !== 'stored';
		remove.title = vehicle.state === 'stored' ? '' : 'O veículo está na rua';
		remove.addEventListener('click', () => postNui('fleetRemove', { garageId: draft.id, vehicleId: vehicle.vehicleId }));
		grid.append(bizVehicleCard(vehicle.model, names.get(vehicle.model), `${vehicle.plate} · ${vehicle.state === 'stored' ? 'guardado' : 'na rua'}`, remove));
	}
	if (!fleet.length) box.append(bizEl('p', 'biz-hint', 'Nenhum veículo na frota.'));
	box.append(grid);

	box.append(bizEl('h3', '', 'Adicionar veículo'));
	const results = bizEl('div', 'biz-vehicle-grid');
	const search = bizInput('text', state.biz.fleetSearch || '', (value) => {
		state.biz.fleetSearch = value;
		fillResults();
	}, { maxlength: 32, placeholder: 'Buscar por nome, marca ou modelo' });
	box.append(search, results);
	function fillResults() {
		results.replaceChildren();
		const term = (state.biz.fleetSearch || '').trim().toLowerCase();
		const matches = catalog.filter((entry) => !term
			|| entry.model.includes(term) || (entry.name || '').toLowerCase().includes(term) || (entry.brand || '').toLowerCase().includes(term));
		for (const entry of matches.slice(0, 48)) {
			const add = bizEl('button', 'coe-button biz-small-button', 'Adicionar');
			add.type = 'button';
			add.addEventListener('click', () => postNui('fleetAdd', { garageId: draft.id, model: entry.model }));
			results.append(bizVehicleCard(entry.model, entry.name, [entry.brand, entry.type].filter(Boolean).join(' · '), add));
		}
		if (!matches.length) results.append(bizEl('p', 'biz-hint', 'Nenhum veículo encontrado.'));
		else if (matches.length > 48) results.append(bizEl('p', 'biz-hint', `Mostrando 48 de ${matches.length}. Refine a busca.`));
	}
	fillResults();
}

function renderGarageFleet(draft) {
	const box = bizEl('div', 'biz-block');
	box.id = 'gar-fleet';
	fillGarageFleet(box, draft);
	return box;
}

function renderBusinessEditor() {
	const host = document.getElementById('biz-editor');
	const draft = state.biz.draft;
	host.replaceChildren();
	if (state.biz.mode === 'recipes' && typeof craftRenderEditor === 'function') {
		craftRenderEditor(host);
		return;
	}
	if (!draft) {
		host.append(bizEl('div', 'empty-state', 'Selecione um negócio ou crie um novo.'));
		return;
	}
	const { categories } = bizCategories();
	const definition = categories[draft.category] || { stations: [], rules: [] };
	const heading = bizEl('div', 'panel-heading');
	heading.append(bizEl('h2', '', state.biz.isNew ? 'Novo negócio' : `Editar: ${draft.label || draft.id}`));
	host.append(heading);

	const idInput = bizInput('text', draft.id, (value) => { draft.id = value.toLowerCase(); }, { maxlength: 32 });
	idInput.disabled = !state.biz.isNew;
	const enabled = bizEl('input');
	enabled.type = 'checkbox';
	enabled.checked = draft.enabled !== false;
	enabled.addEventListener('change', () => { draft.enabled = enabled.checked; });
	const enabledLabel = bizEl('label', 'biz-check');
	enabledLabel.append(enabled, bizEl('span', '', 'Ativo'));

	const stationKinds = definition.stations || [];
	const ruleNames = definition.rules || [];
	const sections = BIZ_SECTIONS.filter(([key]) => (key !== 'stations' || stationKinds.length) && (key !== 'rules' || ruleNames.length)
		&& (key !== 'menu' || (!state.biz.isNew && typeof craftHasBench === 'function' && craftHasBench(draft.category))));
	if (!sections.some(([key]) => key === state.biz.section)) state.biz.section = 'general';

	const tabs = bizEl('div', 'biz-sections');
	tabs.setAttribute('role', 'tablist');
	for (const [key, text] of sections) {
		const tab = bizEl('button', `biz-tab${key === state.biz.section ? ' is-active' : ''}`, text);
		tab.type = 'button';
		tab.addEventListener('click', () => {
			state.biz.section = key;
			renderBusinessEditor();
		});
		tabs.append(tab);
	}
	host.append(tabs);

	const body = bizEl('div', 'biz-section-body');
	if (state.biz.section === 'general') {
		const block = bizEl('div', 'biz-block');
		block.append(
			bizEl('h3', '', 'Identificação'),
			bizField('ID (letras minúsculas, números e _)', idInput),
			bizField('Nome', bizInput('text', draft.label, (value) => { draft.label = value; }, { maxlength: 48 })),
			enabledLabel
		);
		body.append(block);
	} else if (state.biz.section === 'area') {
		body.append(renderBusinessArea(draft));
	} else if (state.biz.section === 'stations') {
		for (const kind of stationKinds) body.append(renderBusinessStations(draft, kind));
	} else if (state.biz.section === 'rules') {
		body.append(renderBusinessRules(draft, ruleNames));
	} else if (state.biz.section === 'owner') {
		body.append(renderBusinessOwner(draft));
	} else if (state.biz.section === 'grades') {
		body.append(renderBusinessGrades(draft));
	} else if (state.biz.section === 'staff') {
		body.append(renderBusinessStaff(draft));
	} else if (state.biz.section === 'menu') {
		body.append(craftBusinessMenu(draft));
	}
	host.append(body);
	// O cardápio tem botão próprio de salvar.
	if (state.biz.section === 'menu') return;

	const actions = bizEl('div', 'biz-actions');
	const save = bizEl('button', 'coe-button coe-button--primary primary-button', 'Salvar negócio');
	save.type = 'button';
	save.addEventListener('click', () => {
		postNui('saveBusiness', { business: bizPayload(draft) }).then((result) => {
			if (!result.ok) showToast('Não foi possível enviar o negócio.', false);
		});
	});
	actions.append(save);
	if (!state.biz.isNew) {
		const remove = bizEl('button', 'coe-button biz-danger', 'Remover');
		remove.type = 'button';
		remove.addEventListener('click', () => {
			if (remove.dataset.confirm !== '1') {
				remove.dataset.confirm = '1';
				remove.textContent = 'Confirmar remoção';
				return;
			}
			postNui('deleteBusiness', { id: draft.id });
		});
		actions.append(remove);
	}
	host.append(actions);
}

function bizPayload(draft) {
	const payload = JSON.parse(JSON.stringify(draft));
	payload.staffAddStateIds = (payload.staffAdd || []).map((entry) => entry.stateId);
	payload.staffAddGrades = {};
	for (const entry of payload.staffAdd || []) if (entry.grade) payload.staffAddGrades[entry.stateId] = entry.grade;
	delete payload.staffAdd;
	payload.grades = (payload.grades || []).map((grade) => ({
		id: grade.id, label: grade.label, level: Number(grade.level), salary: Number(grade.salary), permissions: grade.permissions || []
	}));
	delete payload.ownerPick;
	if (payload.area.kind === 'circle' && !Number.isFinite(payload.area.x)) delete payload.area.x;
	for (const kind of ['crafts', 'stashes', 'clocks']) {
		if (payload.stations[kind]) payload.stations[kind] = payload.stations[kind].map((entry) => ({ ...entry }));
	}
	return payload;
}

function renderBusinesses() {
	const data = state.data?.businesses;
	const tabs = document.getElementById('biz-categories');
	const list = document.getElementById('biz-list');
	if (!tabs || !list) return;
	tabs.replaceChildren();
	list.replaceChildren();
	if (!data?.available) {
		appendEmpty(list, 'O resource coe_businesses não está iniciado.');
		return;
	}
	const { categories, keys } = bizCategories();
	const draft = state.biz.draft;
	if (draft && !state.biz.isNew) {
		const fresh = (data.list || []).find((entry) => entry.id === draft.id);
		if (fresh) {
			draft.owner = fresh.owner;
			draft.staff = fresh.staff || [];
		}
		const label = document.getElementById('biz-owner-label');
		if (label) label.textContent = bizOwnerText(draft);
	}
	if (!state.biz.category || !categories[state.biz.category]) state.biz.category = keys[0] || null;
	for (const key of keys) {
		const button = bizEl('button', `biz-tab${key === state.biz.category ? ' is-active' : ''}`, categories[key].label || key);
		button.type = 'button';
		button.addEventListener('click', () => {
			state.biz.category = key;
			state.biz.mode = null;
			state.biz.draft = null;
			renderBusinesses();
			renderBusinessEditor();
		});
		tabs.append(button);
	}
	if (typeof craftRenderTab === 'function' && craftRenderTab(tabs, list)) return;
	document.getElementById('biz-list-title').textContent = categories[state.biz.category]?.label || 'Negócios';
	const items = (data.list || []).filter((entry) => entry.category === state.biz.category);
	if (!items.length) appendEmpty(list, 'Nenhum negócio nesta categoria.');
	for (const entry of items) {
		const row = bizEl('button', `biz-item${state.biz.draft?.id === entry.id ? ' is-active' : ''}`);
		row.type = 'button';
		row.append(bizEl('strong', '', entry.label), bizEl('small', '', `${entry.id}${entry.enabled === false ? ' · inativo' : ''}`));
		row.addEventListener('click', () => {
			state.biz.draft = JSON.parse(JSON.stringify(entry));
			state.biz.draft.stations = state.biz.draft.stations || {};
			state.biz.draft.rules = state.biz.draft.rules || {};
			state.biz.isNew = false;
			renderBusinesses();
			renderBusinessEditor();
		});
		list.append(row);
	}
	if (!state.biz.draft) renderBusinessEditor();
}

document.getElementById('biz-new').addEventListener('click', () => {
	if (state.biz.mode === 'recipes') {
		craftNew();
		return;
	}
	if (!state.biz.category) return;
	state.biz.draft = bizNewDraft(state.biz.category);
	state.biz.isNew = true;
	renderBusinesses();
	renderBusinessEditor();
});

document.querySelectorAll('.nav-link').forEach((button) => {
	button.addEventListener('click', () => setView(button.dataset.view));
});
document.querySelectorAll('[data-open-view]').forEach((button) => {
	button.addEventListener('click', () => setView(button.dataset.openView));
});

document.getElementById('close-panel').addEventListener('click', () => postNui('close'));
elements.refreshPanel = document.getElementById('refresh-panel');
elements.refreshPanel.addEventListener('click', () => postNui('refresh'));
elements.targetPlayer.addEventListener('change', updateDeliveryState);
elements.itemMetadata.addEventListener('input', updateDeliveryState);
elements.itemSearch.addEventListener('input', renderItems);
elements.frameworkSearch.addEventListener('input', renderFramework);
elements.clearCart.addEventListener('click', () => {
	if (state.deliverySubmission) return;
	state.cart.clear();
	renderCart();
	renderItems();
	updateDeliveryState();
});
elements.staffPlayer.addEventListener('change', updateStaffButtonState);
elements.staffRole.addEventListener('change', updateStaffButtonState);

function updateStaffButtonState() {
	elements.assignStaff.disabled = !(elements.staffPlayer.value && elements.staffRole.value);
}

elements.giveItem.addEventListener('click', async () => {
	const playerId = Number(elements.targetPlayer.value);
	const entries = [...state.cart.values()];
	if (!playerId || entries.length === 0 || state.deliverySubmission) return;
	if (entries.some(({ item, count }) => !Number.isInteger(count) || count < 1 || count > getMaxQuantity(item))) {
		elements.formMessage.textContent = 'Revise as quantidades; cada item deve respeitar o máximo indicado.';
		elements.formMessage.classList.remove('is-success');
		return;
	}

	let metadata = {};
	const metadataText = elements.itemMetadata.value.trim();
	if (metadataText) {
		try {
			metadata = JSON.parse(metadataText);
			if (!metadata || typeof metadata !== 'object' || Array.isArray(metadata)) throw new Error('invalid');
		} catch {
			elements.formMessage.textContent = 'Metadata precisa ser um objeto JSON válido.';
			elements.formMessage.classList.remove('is-success');
			return;
		}
	}

	state.deliverySubmission = {
		total: entries.length,
		received: 0,
		succeeded: 0,
		pending: new Map(),
		failures: []
	};
	elements.formMessage.textContent = `Preparando ${entries.length} ${entries.length === 1 ? 'item' : 'itens'}...`;
	elements.formMessage.classList.remove('is-success');
	renderCart();
	renderItems();
	updateDeliveryState();
	try {
		const result = await postNui('giveItems', {
			playerId,
			items: entries.map(({ item, count }) => ({ name: item.name, count })),
			metadata
		});
		if (!result.ok || !Array.isArray(result.requestIds) || result.requestIds.length !== entries.length) {
			throw new Error('request_failed');
		}
		result.requestIds.forEach((requestId, index) => {
			state.deliverySubmission.pending.set(Number(requestId), entries[index].item.name);
		});
		elements.formMessage.textContent = `Enviando 0/${entries.length} itens...`;
	} catch {
		state.deliverySubmission = null;
		elements.formMessage.textContent = 'Não foi possível iniciar a entrega.';
		renderCart();
		renderItems();
		updateDeliveryState();
	}
});

elements.assignStaff.addEventListener('click', async () => {
	const selected = state.data.players.find((player) => String(player.id) === elements.staffPlayer.value);
	if (!selected) return;
	const result = await postNui('setStaffRole', { targetId: selected.id, role: elements.staffRole.value });
	if (!result.ok) showToast('Não foi possível enviar a alteração de equipe.', false);
});

window.addEventListener('message', (event) => {
	const data = event.data;
	if (!data || typeof data !== 'object') return;
	if (data.action === 'open') {
		renderData(data.data || {});
		shell.classList.add('is-open');
		shell.setAttribute('aria-hidden', 'false');
		setView('overview');
	} else if (data.action === 'refresh') {
		renderData(data.data || {});
	} else if (data.action === 'captureStart') {
		shell.classList.remove('is-open');
	} else if (data.action === 'captureDone') {
		shell.classList.add('is-open');
		const apply = state.biz.pendingCapture;
		state.biz.pendingCapture = null;
		if (apply && data.data && !data.data.cancelled) apply(data.data);
		if (data.data) houTripNotice(data.data);
		renderBusinessEditor();
		renderFactionEditor();
		renderGarageEditor();
		if (typeof renderRentalEditor === 'function') renderRentalEditor();
		renderHousingEditor();
		renderDoorEditor();
		renderRealty();
	} else if (data.action === 'housingThumbsResult') {
		onHousingThumbsResult(data);
	} else if (data.action === 'housingContractsResult') {
		onHousingContractsResult(data);
	} else if (data.action === 'housingThumbRaw') {
		onHousingThumbRaw(data);
	} else if (data.action === 'factionMembersResult') {
		const members = state.fac.members;
		if (members.requestId === data.requestId && members.id === data.factionId) {
			members.list = data.members || [];
			members.error = data.error || null;
			if (state.fac.section === 'members') renderFactionEditor();
		}
	} else if (data.action === 'profileResult') {
		if (profileState.requestId === data.requestId) {
			const message = document.getElementById('profile-message');
			if (data.profile) {
				profileState.profile = data.profile;
				message.textContent = '';
				renderProfile();
			} else {
				message.textContent = PROFILE_ERRORS[data.error] || 'Não foi possível carregar o perfil.';
			}
		}
	} else if (data.action === 'bankingAccountResult') {
		onBankingAccountResult(data);
	} else if (data.action === 'bankingBusinessResult') {
		if (typeof onBankingBusinessResult === 'function') onBankingBusinessResult(data);
	} else if (data.action === 'bankingRequestsResult') {
		onBankingRequestsResult(data);
	} else if (data.action === 'cryptoInspectResult') {
		if (typeof onCryptoInspectResult === 'function') onCryptoInspectResult(data);
	} else if (data.action === 'newsData') {
		onNewsData(data);
	} else if (data.action === 'characterResults') {
		if (characterSearch.requestId === data.requestId && characterSearch.show) {
			characterSearch.show(Array.isArray(data.results) ? data.results : [], data.error);
		}
	} else if (data.action === 'close') {
		state.biz.pendingCapture = null;
		shell.classList.remove('is-open');
		shell.setAttribute('aria-hidden', 'true');
		if (document.activeElement instanceof HTMLElement) {
			document.activeElement.blur();
		}
	} else if (data.action === 'result') {
		const batch = state.deliverySubmission;
		const itemName = batch?.pending.get(Number(data.requestId));
		if (data.operation === 'giveItem' && batch && itemName) {
			batch.pending.delete(Number(data.requestId));
			batch.received += 1;
			if (data.success === true) {
				batch.succeeded += 1;
				state.cart.delete(itemName);
			} else {
				batch.failures.push(data.message || itemName);
			}
			renderCart();
			renderItems();
			updateDeliveryState();
			if (batch.received === batch.total) {
				state.deliverySubmission = null;
				const failed = batch.total - batch.succeeded;
				const summary = `${batch.succeeded}/${batch.total} ${batch.total === 1 ? 'item entregue' : 'itens entregues'}.`;
				elements.formMessage.textContent = failed
					? `${summary} ${failed} permaneceram no carrinho. ${batch.failures[0] || ''}`
					: summary;
				elements.formMessage.classList.toggle('is-success', failed === 0);
				showToast(summary, failed === 0 ? 'success' : 'error');
				renderCart();
				renderItems();
				updateDeliveryState();
			} else {
				elements.formMessage.textContent = `Enviando ${batch.received}/${batch.total} itens...`;
			}
		} else {
			showToast(data.message, data.success === true ? 'success' : 'error');
		}
		if (data.operation === 'staffRole' || data.operation === 'removeStaff') {
			elements.staffMessage.textContent = data.message || '';
			elements.staffMessage.classList.toggle('is-success', data.success === true);
		}
		if (data.operation === 'resourceRestart') {
			elements.frameworkMessage.textContent = data.message || '';
			elements.frameworkMessage.classList.toggle('is-success', data.success === true);
		}
		if (data.operation === 'businessSave' || data.operation === 'businessDelete') {
			const message = document.getElementById('biz-message');
			message.textContent = data.message || '';
			message.classList.toggle('is-success', data.success === true);
			if (data.success === true) {
				if (data.operation === 'businessDelete') {
					state.biz.draft = null;
				} else {
					state.biz.isNew = false;
					if (state.biz.draft) {
						state.biz.draft.ownerStateId = undefined;
						state.biz.draft.staffOnOwnerChange = 'keep';
						state.biz.draft.staffAdd = [];
		state.biz.draft.ownerPick = undefined;
						state.biz.draft.clearOwner = false;
					}
				}
				renderBusinesses();
				renderBusinessEditor();
			}
		}
		if (data.operation === 'garageSave' || data.operation === 'garageDelete') onGarageResult(data);
		if ((data.operation === 'rentalSave' || data.operation === 'rentalDelete') && typeof onRentalResult === 'function') onRentalResult(data);
		if (data.operation === 'propertySave' || data.operation === 'propertyDelete') onPropertyResult(data);
		if (data.operation === 'contractEnd') onRealtyContractEnd(data);
		if (data.operation === 'banking') onBankingResult(data);
		if (data.operation === 'crypto' && typeof onCryptoResult === 'function') onCryptoResult(data);
		if (data.operation === 'themeChange') {
			elements.themeMessage.textContent = data.message || '';
			elements.themeMessage.classList.toggle('is-success', data.success === true);
		}
		if (data.operation === 'factionSave' || data.operation === 'factionDelete' || data.operation === 'factionMember') onFactionResult(data);
		if (data.operation === 'doorSave' || data.operation === 'doorDelete') onDoorResult(data);
		if (data.operation === 'craftCatalog') onCraftResult(data);
		if (data.operation === 'amzgCatalog') onAmzgResult(data);
		if (data.operation === 'deepweb' && typeof onDeepwebResult === 'function') onDeepwebResult(data);
		if (data.operation === 'news') onNewsResult(data);
	}
});

window.addEventListener('keydown', (event) => {
	if (event.key === 'Escape' && shell.classList.contains('is-open')) {
		event.preventDefault();
		postNui('close');
	}
});
