// Aba "DeepWeb" (coe_deepweb): sites por blocos, fornecedores NPC do Deep Market, pedidos em disputa ou sem entrega,
// moderação do Rabbit e contatos dos perfis da staff (fantasma.onion). Usa os helpers de app.js; o servidor confere a permissão (manageDeepweb) e valida tudo de novo.
state.deepweb = { tab: 'sites', draft: null, selected: null };

const DW_TABS = [['sites', 'Sites'], ['vendors', 'Fornecedores'], ['orders', 'Pedidos'], ['posts', 'Rabbit'], ['contacts', 'Contatos']];
const DW_BLOCKS = {
	heading: 'Título', text: 'Texto', quote: 'Citação', notice: 'Aviso', list: 'Lista', divider: 'Divisória', link: 'Link', listing: 'Anúncio do Deep Market'
};
const DW_TONES = [['info', 'Informação'], ['warn', 'Atenção'], ['danger', 'Perigo'], ['success', 'Sucesso']];
const DW_STATUS = {
	paid: 'Pago, sem entrega', dropped: 'No ponto / entregue', disputed: 'Em disputa', completed: 'Concluído', cancelled: 'Cancelado',
	refunded: 'Estornado', released: 'Pago ao vendedor'
};

function dwData() {
	return state.data?.deepweb || null;
}

function dwList(value) {
	if (Array.isArray(value)) return value;
	return value && typeof value === 'object' ? Object.values(value) : [];
}

function dwMessage(text, success) {
	const message = document.getElementById('deepweb-message');
	if (!message) return;
	message.textContent = text || '';
	message.classList.toggle('is-success', success === true);
}

function dwButton(text, className, onClick) {
	const node = bizEl('button', className, text);
	node.type = 'button';
	node.addEventListener('click', onClick);
	return node;
}

function dwSend(op, payload) {
	dwMessage('Enviando...');
	postNui('deepweb', { op, payload }).then((result) => {
		if (!result.ok) dwMessage('Não foi possível enviar.', false);
	});
}

function onDeepwebResult(data) {
	dwMessage(data.message, data.success === true);
	if (data.success === true) {
		state.deepweb.draft = null;
		state.deepweb.selected = null;
	}
}

function dwCoinText(units, decimals) {
	const value = Number(units || 0) / Math.pow(10, decimals);
	return value.toFixed(decimals).replace(/0+$/, '').replace(/\.$/, '').replace('.', ',');
}

function dwSelect(options, value, onChange) {
	const node = bizEl('select', 'coe-field field-control');
	for (const [id, label] of options) {
		const option = bizEl('option', '', label);
		option.value = id;
		if (id === value) option.selected = true;
		node.append(option);
	}
	node.addEventListener('change', () => onChange(node.value));
	return node;
}

function dwTextarea(value, onInput, rows) {
	const node = bizEl('textarea', 'coe-field field-control');
	node.rows = rows || 3;
	node.value = value ?? '';
	node.addEventListener('input', () => onInput(node.value));
	return node;
}

function dwCheck(label, value, onChange) {
	const wrapper = bizEl('label', 'biz-check');
	const box = bizEl('input');
	box.type = 'checkbox';
	box.checked = value === true;
	box.addEventListener('change', () => onChange(box.checked));
	wrapper.append(box, bizEl('span', '', label));
	return wrapper;
}

function dwRow(title, subtitle, selected, onClick, badge) {
	const node = dwButton('', `catalog-item${selected ? ' is-selected' : ''}`, onClick);
	const text = bizEl('span', 'amzg-item-text');
	text.append(bizEl('strong', '', title), bizEl('small', '', subtitle));
	node.append(text);
	if (badge) node.append(bizEl('small', 'catalog-item-count', badge));
	return node;
}

function renderDeepweb() {
	const tabs = document.getElementById('deepweb-tabs');
	const list = document.getElementById('deepweb-list');
	const editor = document.getElementById('deepweb-editor');
	const newButton = document.getElementById('deepweb-new');
	if (!tabs || !list || !editor) return;
	tabs.replaceChildren();
	list.replaceChildren();
	editor.replaceChildren();
	const data = dwData();
	if (!data) {
		appendEmpty(list, 'O resource coe_deepweb não está iniciado.');
		return;
	}
	if (!data.ready) {
		appendEmpty(list, 'A DeepWeb ainda está iniciando.');
		return;
	}
	for (const [id, label] of DW_TABS) {
		tabs.append(dwButton(label, `biz-tab${state.deepweb.tab === id ? ' is-active' : ''}`, () => {
			state.deepweb.tab = id;
			state.deepweb.draft = null;
			state.deepweb.selected = null;
			renderDeepweb();
		}));
	}
	const title = document.getElementById('deepweb-list-title');
	const eyebrow = document.getElementById('deepweb-list-eyebrow');
	const tab = state.deepweb.tab;
	if (newButton) newButton.hidden = tab !== 'sites' && tab !== 'vendors';
	if (tab === 'sites') {
		eyebrow.textContent = 'REDE';
		title.textContent = 'Sites';
		dwSites(list, editor, data);
	} else if (tab === 'vendors') {
		eyebrow.textContent = 'DEEP MARKET';
		title.textContent = 'Fornecedores NPC';
		dwVendors(list, editor, data);
	} else if (tab === 'orders') {
		eyebrow.textContent = 'DEEP MARKET';
		title.textContent = 'Pedidos';
		dwOrders(list, editor, data);
	} else if (tab === 'contacts') {
		eyebrow.textContent = 'PERFIS';
		title.textContent = 'Contatos';
		dwContacts(list, editor, data);
	} else {
		eyebrow.textContent = 'RABBIT';
		title.textContent = 'Posts recentes';
		dwPosts(list, editor, data);
	}
}

// Sites ---------------------------------------------------------------------------------------------

function dwParseBlocks(text) {
	if (!text) return [];
	try {
		const parsed = JSON.parse(text);
		return Array.isArray(parsed) ? parsed : dwList(parsed);
	} catch (error) {
		return [];
	}
}

function dwOpenSite(site) {
	state.deepweb.draft = site
		? { domain: site.domain, title: site.title, description: site.description, keywords: site.keywords, active: site.active !== false, listed: site.listed !== false, blocks: dwParseBlocks(site.blocks), system: site.system, existing: true }
		: { domain: '', title: '', description: '', keywords: '', active: true, listed: true, blocks: [{ type: 'heading', text: '' }, { type: 'text', text: '' }], system: false, existing: false };
	renderDeepweb();
}

function dwSites(list, editor, data) {
	const sites = dwList(data.sites);
	if (!sites.length) appendEmpty(list, 'Nenhum site.');
	const draft = state.deepweb.draft;
	for (const site of sites) {
		list.append(dwRow(site.title, `${site.domain}${site.system ? ' · sistema' : ''}${site.active ? '' : ' · fora do ar'}${site.listed === false ? ' · oculto' : ''}`, draft && draft.domain === site.domain, () => dwOpenSite(site)));
	}
	if (!draft) {
		editor.append(bizEl('div', 'empty-state', 'Selecione um site ou crie um novo. Sites de sistema (DuckDark, Rabbit, Deep Market, Fantasma) vêm do config.'));
		return;
	}
	if (draft.system) {
		editor.append(bizEl('h3', '', draft.title), bizEl('p', 'subtle', `${draft.domain} é um site de sistema: título, descrição e palavras-chave vêm de Sites.System no config do coe_deepweb.`));
		return;
	}
	const form = bizEl('div', 'biz-form');
	const domain = bizInput('text', draft.domain, (value) => { draft.domain = value; }, { placeholder: 'nome (vira nome.onion)', maxlength: '30' });
	if (draft.existing) domain.disabled = true;
	form.append(
		bizField('Endereço', domain),
		bizField('Título', bizInput('text', draft.title, (value) => { draft.title = value; }, { maxlength: '48' })),
		bizField('Descrição (aparece no DuckDark)', bizInput('text', draft.description, (value) => { draft.description = value; }, { maxlength: '200' })),
		bizField('Palavras-chave da busca', bizInput('text', draft.keywords, (value) => { draft.keywords = value; }, { maxlength: '120' })),
		dwCheck('No ar', draft.active, (value) => { draft.active = value; }),
		dwCheck('Aparece no DuckDark (diretório e busca)', draft.listed, (value) => { draft.listed = value; })
	);
	const blocks = bizEl('div', 'dw-blocks');
	draft.blocks.forEach((block, index) => blocks.append(dwBlockEditor(draft, block, index)));
	form.append(bizEl('h4', '', `Blocos (${draft.blocks.length})`), blocks);
	const add = bizEl('div', 'biz-actions');
	add.append(dwSelect(Object.entries(DW_BLOCKS), 'text', (value) => {
		draft.blocks.push(value === 'list' ? { type: value, items: [''] } : value === 'link' ? { type: value, label: '', href: '' } : value === 'notice' ? { type: value, text: '', tone: 'info' } : { type: value, text: '' });
		renderDeepweb();
	}));
	add.firstChild.prepend(Object.assign(bizEl('option', '', '+ Adicionar bloco'), { value: '', selected: true, disabled: true }));
	form.append(add);
	const actions = bizEl('div', 'biz-actions');
	actions.append(dwButton('Salvar', 'coe-button coe-button--primary', () => {
		dwSend('saveSite', { domain: draft.domain, title: draft.title, description: draft.description, keywords: draft.keywords, active: draft.active, listed: draft.listed, blocks: draft.blocks });
	}));
	if (draft.existing) {
		actions.append(dwButton('Apagar site', 'coe-button coe-button--danger', () => dwSend('deleteSite', { domain: draft.domain })));
	}
	form.append(actions);
	editor.append(form);
}

function dwBlockEditor(draft, block, index) {
	const box = bizEl('div', 'dw-block');
	const head = bizEl('div', 'biz-actions');
	head.append(bizEl('strong', '', `${index + 1}. ${DW_BLOCKS[block.type] || block.type}`));
	head.append(dwButton('↑', 'coe-button biz-small-button', () => {
		if (index > 0) { [draft.blocks[index - 1], draft.blocks[index]] = [draft.blocks[index], draft.blocks[index - 1]]; renderDeepweb(); }
	}));
	head.append(dwButton('↓', 'coe-button biz-small-button', () => {
		if (index < draft.blocks.length - 1) { [draft.blocks[index + 1], draft.blocks[index]] = [draft.blocks[index], draft.blocks[index + 1]]; renderDeepweb(); }
	}));
	head.append(dwButton('Remover', 'coe-button biz-small-button coe-button--danger', () => { draft.blocks.splice(index, 1); renderDeepweb(); }));
	box.append(head);
	if (block.type === 'heading') {
		box.append(bizInput('text', block.text, (value) => { block.text = value; }, { maxlength: '80' }));
	} else if (block.type === 'text' || block.type === 'quote') {
		box.append(dwTextarea(block.text, (value) => { block.text = value; }, 4));
	} else if (block.type === 'notice') {
		box.append(dwSelect(DW_TONES, block.tone || 'info', (value) => { block.tone = value; }), dwTextarea(block.text, (value) => { block.text = value; }, 2));
	} else if (block.type === 'list') {
		box.append(bizField('Um item por linha', dwTextarea(dwList(block.items).join('\n'), (value) => { block.items = value.split('\n').filter((line) => line.trim()); }, 4)));
	} else if (block.type === 'link') {
		box.append(
			bizField('Texto', bizInput('text', block.label, (value) => { block.label = value; }, { maxlength: '60' })),
			bizField('Endereço (.onion ou about:)', bizInput('text', block.href, (value) => { block.href = value; }, { placeholder: 'rabbit.onion/r/geral' }))
		);
	} else if (block.type === 'listing') {
		box.append(bizField('Número do anúncio', bizInput('number', block.id, (value) => { block.id = Number(value); }, { min: '1' })));
	}
	return box;
}

// Fornecedores ----------------------------------------------------------------------------------------

function dwOpenVendor(vendor, data) {
	const categories = dwList(data.categories);
	state.deepweb.draft = vendor
		? { id: vendor.id, vendor: vendor.vendor, kind: vendor.kind, category: vendor.category, title: vendor.title, description: vendor.description, item: vendor.item, count: vendor.count, price: dwCoinText(vendor.price, data.decimals), stock: vendor.stock, status: vendor.status }
		: { id: null, vendor: '', kind: 'item', category: categories[0]?.id || 'other', title: '', description: '', item: '', count: 1, price: '1', stock: 10, status: 'active' };
	renderDeepweb();
}

function dwVendors(list, editor, data) {
	const vendors = dwList(data.vendors);
	if (!vendors.length) appendEmpty(list, 'Nenhum fornecedor NPC.');
	const draft = state.deepweb.draft;
	for (const vendor of vendors) {
		list.append(dwRow(vendor.title, `${vendor.vendor} · estoque ${vendor.stock} · ${vendor.sold} vendido(s)${vendor.status === 'paused' ? ' · pausado' : ''}`,
			draft && draft.id === vendor.id, () => dwOpenVendor(vendor, data), vendor.priceText));
	}
	const newButton = document.getElementById('deepweb-new');
	if (!draft) {
		editor.append(bizEl('div', 'empty-state', 'Selecione um fornecedor ou crie um novo. O pagamento dos fornecedores vai para a reserva da corretora.'));
		return;
	}
	const form = bizEl('div', 'biz-form');
	const categories = dwList(data.categories).map((category) => [category.id, category.label]);
	form.append(
		bizField('Fornecedor (nome que aparece)', bizInput('text', draft.vendor, (value) => { draft.vendor = value; }, { maxlength: '32' })),
		bizField('Título', bizInput('text', draft.title, (value) => { draft.title = value; }, { maxlength: '60' })),
		bizField('Tipo', dwSelect([['item', 'Item (ponto de coleta)'], ['service', 'Serviço (confirmação do comprador)']], draft.kind, (value) => { draft.kind = value; renderDeepweb(); })),
		bizField('Categoria', dwSelect(categories, draft.category, (value) => { draft.category = value; }))
	);
	if (draft.kind === 'item') {
		form.append(
			bizField('Item do inventário', bizInput('text', draft.item, (value) => { draft.item = value; }, { placeholder: 'ex.: lockpick' })),
			bizField('Quantidade por unidade', bizInput('number', draft.count, (value) => { draft.count = Number(value); }, { min: '1', max: '100' }))
		);
	}
	form.append(
		bizField('Preço (em moeda, ex.: 0,5)', bizInput('text', draft.price, (value) => { draft.price = value; })),
		bizField('Estoque', bizInput('number', draft.stock, (value) => { draft.stock = Number(value); }, { min: '0', max: '999' })),
		bizField('Descrição', dwTextarea(draft.description, (value) => { draft.description = value; }, 4)),
		dwCheck('Pausado', draft.status === 'paused', (value) => { draft.status = value ? 'paused' : 'active'; })
	);
	const actions = bizEl('div', 'biz-actions');
	actions.append(dwButton('Salvar', 'coe-button coe-button--primary', () => dwSend('saveVendor', Object.assign({}, draft))));
	if (draft.id) actions.append(dwButton('Remover anúncio', 'coe-button coe-button--danger', () => dwSend('deleteVendor', { id: draft.id })));
	form.append(actions);
	editor.append(form);
}

// Pedidos -----------------------------------------------------------------------------------------------

function dwOrders(list, editor, data) {
	const orders = dwList(data.orders);
	if (!orders.length) appendEmpty(list, 'Nenhum pedido em disputa ou aguardando entrega.');
	const selected = state.deepweb.selected;
	let current = null;
	for (const order of orders) {
		if (selected === order.id) current = order;
		list.append(dwRow(`#${order.id} ${order.title}`, `${DW_STATUS[order.status] || order.status}${order.late ? ' · prazo vencido' : ''} · @${order.buyer || '?'} → ${order.seller || '?'}`,
			selected === order.id, () => { state.deepweb.selected = order.id; renderDeepweb(); }, order.totalText));
	}
	if (!current) {
		editor.append(bizEl('div', 'empty-state', 'Selecione um pedido. Disputas: decida quem recebe. Pagos sem entrega: cancele e devolva ao comprador.'));
		return;
	}
	const box = bizEl('div', 'biz-form');
	box.append(bizEl('h3', '', `Pedido #${current.id}`));
	const lines = [
		['Anúncio', current.title], ['Tipo', current.kind === 'service' ? 'Serviço' : 'Item'], ['Estado', DW_STATUS[current.status] || current.status],
		['Valor', current.totalText], ['Comprador', `@${current.buyer || '?'} (personagem ${current.buyerCharacter})`], ['Vendedor', current.seller || '?'],
		['Criado', new Date(current.createdAt * 1000).toLocaleString('pt-BR')]
	];
	if (current.note) lines.push(['Motivo da contestação', current.note]);
	for (const [label, value] of lines) {
		const row = bizEl('div', 'detail-row');
		row.append(bizEl('span', 'field-label', label), bizEl('strong', '', value));
		box.append(row);
	}
	const actions = bizEl('div', 'biz-actions');
	if (current.status === 'disputed') {
		actions.append(
			dwButton('Devolver ao comprador', 'coe-button', () => dwSend('resolveOrder', { id: current.id, decision: 'buyer' })),
			dwButton('Pagar o vendedor', 'coe-button coe-button--primary', () => dwSend('resolveOrder', { id: current.id, decision: 'seller' }))
		);
	} else if (current.status === 'paid') {
		actions.append(dwButton('Cancelar e devolver ao comprador', 'coe-button coe-button--danger', () => dwSend('resolveOrder', { id: current.id, decision: 'buyer' })));
	}
	box.append(actions);
	editor.append(box);
}

// Rabbit ----------------------------------------------------------------------------------------------

function dwPosts(list, editor, data) {
	const posts = dwList(data.posts);
	if (!posts.length) appendEmpty(list, 'Nenhum post ainda.');
	const selected = state.deepweb.selected;
	let current = null;
	for (const post of posts) {
		if (selected === post.id) current = post;
		list.append(dwRow(post.title, `r/${post.community} · @${post.author} · ${post.score} pts`, selected === post.id, () => { state.deepweb.selected = post.id; renderDeepweb(); }));
	}
	if (!current) {
		editor.append(bizEl('div', 'empty-state', 'Selecione um post para ler ou remover.'));
		return;
	}
	const box = bizEl('div', 'biz-form');
	box.append(bizEl('h3', '', current.title), bizEl('p', 'subtle', `r/${current.community} · @${current.author} · ${new Date(current.createdAt * 1000).toLocaleString('pt-BR')}`));
	const body = bizEl('p', '', current.body || '(sem texto)');
	body.style.whiteSpace = 'pre-wrap';
	box.append(body);
	const actions = bizEl('div', 'biz-actions');
	actions.append(dwButton('Remover post', 'coe-button coe-button--danger', () => dwSend('removePost', { id: current.id })));
	box.append(actions);
	editor.append(box);
}

// Contatos ---------------------------------------------------------------------------------------------

const DW_CONTACT_STATUS = { open: 'Aguardando', answered: 'Respondida', closed: 'Arquivada' };

function dwContacts(list, editor, data) {
	const contacts = dwList(data.contacts);
	if (!contacts.length) appendEmpty(list, 'Nenhuma mensagem.');
	const selected = state.deepweb.selected;
	let current = null;
	for (const contact of contacts) {
		if (selected === contact.id) current = contact;
		list.append(dwRow(`@${contact.handle || '?'} → ${contact.site}`, `${DW_CONTACT_STATUS[contact.status] || contact.status} · ${new Date(contact.createdAt * 1000).toLocaleString('pt-BR')}`,
			selected === contact.id, () => { state.deepweb.selected = contact.id; state.deepweb.draft = { reply: contact.reply || '' }; renderDeepweb(); }, contact.status === 'open' ? 'nova' : ''));
	}
	if (!current) {
		editor.append(bizEl('div', 'empty-state', 'Selecione uma mensagem. A resposta aparece na página do site para o apelido, que recebe um aviso se estiver online.'));
		return;
	}
	const draft = state.deepweb.draft || (state.deepweb.draft = { reply: current.reply || '' });
	const box = bizEl('div', 'biz-form');
	box.append(bizEl('h3', '', `@${current.handle || '?'} → ${current.site}`), bizEl('p', 'subtle', `${DW_CONTACT_STATUS[current.status] || current.status} · ${new Date(current.createdAt * 1000).toLocaleString('pt-BR')}`));
	const body = bizEl('p', '', current.body);
	body.style.whiteSpace = 'pre-wrap';
	box.append(body);
	const actions = bizEl('div', 'biz-actions');
	if (current.status !== 'closed') {
		box.append(bizField(current.reply ? 'Resposta (editar reenvia o aviso)' : 'Resposta', dwTextarea(draft.reply, (value) => { draft.reply = value; }, 5)));
		actions.append(dwButton('Responder', 'coe-button coe-button--primary', () => dwSend('replyContact', { id: current.id, reply: draft.reply })));
		actions.append(dwButton('Arquivar', 'coe-button', () => dwSend('closeContact', { id: current.id })));
	} else if (current.reply) {
		const reply = bizEl('p', 'subtle', `Resposta: ${current.reply}`);
		reply.style.whiteSpace = 'pre-wrap';
		box.append(reply);
	}
	box.append(actions);
	editor.append(box);
}

document.getElementById('deepweb-new')?.addEventListener('click', () => {
	const data = dwData();
	if (!data) return;
	if (state.deepweb.tab === 'sites') dwOpenSite(null);
	else if (state.deepweb.tab === 'vendors') dwOpenVendor(null, data);
});
