// Aba "Portas": fechaduras de portas do mapa/MLO (coe_doors). Usa os helpers de app.js.
const DOOR_SECTIONS = [['general', 'Local'], ['leaves', 'Portas'], ['access', 'Acesso'], ['pin', 'Senha']];

const DOOR_KINDS = [['single', 'Porta simples'], ['double', 'Porta dupla'], ['garage', 'Portão de garagem'], ['gate', 'Portão']];
const DOOR_WIDE = new Set(['garage', 'gate']);

function doorNewEntry(draft) {
	let index = (draft?.entries?.length || 0) + 1;
	while (draft?.entries?.some((entry) => entry.key === `p${index}`)) index += 1;
	return { key: `p${index}`, label: '', kind: 'single', doors: [], distance: 2, autoLock: 0, locked: true, restricted: false, allowed: [], pin: '', clearPin: false };
}

function doorNewDraft() {
	const draft = {
		id: '', label: '', enabled: true, entries: [],
		access: { businesses: [], factions: [], characters: [], items: [], key: true },
		owner: null, hasPin: false, pin: '', clearPin: false
	};
	draft.entries.push(doorNewEntry(draft));
	return draft;
}

function doorFromEntry(entry) {
	const draft = JSON.parse(JSON.stringify(entry));
	draft.access = Object.assign({ businesses: [], factions: [], characters: [], items: [], key: false }, draft.access || {});
	draft.entries = Array.isArray(draft.entries) ? draft.entries : [];
	for (const door of draft.entries) {
		door.restricted = door.restricted === true;
		door.allowed = Array.isArray(door.allowed) ? door.allowed : [];
		door.pin = '';
		door.clearPin = false;
	}
	draft.owner = draft.owner || null;
	draft.pin = '';
	draft.clearPin = false;
	return draft;
}
function doorPayload(draft) {
	const payload = JSON.parse(JSON.stringify(draft));
	delete payload.hasPin;
	for (const entry of payload.entries || []) {
		delete entry.current;
		delete entry.hasPin;
		if (!entry.pin) delete entry.pin;
		if (!entry.clearPin) delete entry.clearPin;
	}
	if (!payload.owner) delete payload.owner;
	if (!payload.pin) delete payload.pin;
	if (!payload.clearPin) delete payload.clearPin;
	payload.isNew = state.door.isNew;
	return payload;
}

function doorAim(apply) {
	state.biz.pendingCapture = apply;
	postNui('doorAim', {}).then((result) => {
		if (!result.ok) {
			state.biz.pendingCapture = null;
			showToast('Não foi possível iniciar a mira.', false);
		}
	});
}

function doorRemoveButton(onClick) {
	const button = bizEl('button', 'coe-button biz-small-button biz-danger', 'Remover');
	button.type = 'button';
	button.addEventListener('click', () => {
		onClick();
		renderDoorEditor();
	});
	return button;
}

function doorRow(text, onRemove, extra) {
	const row = bizEl('div', 'door-rule');
	row.append(bizEl('span', '', text));
	if (extra) row.append(extra);
	row.append(doorRemoveButton(onRemove));
	return row;
}

function renderDoorGeneral(draft) {
	const box = bizEl('div', 'biz-block');
	const idInput = bizInput('text', draft.id, (value) => { draft.id = value.toLowerCase(); }, { maxlength: 32 });
	idInput.disabled = !state.door.isNew;
	box.append(
		bizEl('h3', '', 'Local'),
		bizField('ID (letras minúsculas, números e _)', idInput),
		bizField('Nome do local (casa, prédio, sede)', bizInput('text', draft.label, (value) => { draft.label = value; }, { maxlength: 48 })),
		garCheck('Ativo', draft.enabled !== false, (checked) => { draft.enabled = checked; }),
		bizEl('p', 'biz-hint', 'Cadastre todas as portas do local (entrada, fundos, garagem, portão) na aba Portas: acesso, senha e chave valem para todas. Cada porta tranca e destranca separadamente.')
	);
	const owner = bizEl('div', 'biz-block');
	owner.append(bizEl('h3', '', 'Dono'));
	if (draft.owner) {
		owner.append(doorRow(`${draft.owner.name || 'Personagem'} (#${draft.owner.characterId})`, () => { draft.owner = null; }));
	} else {
		owner.append(bizEl('p', 'biz-hint', 'Sem dono.'));
	}
	owner.append(
		bizCharacterPicker((character) => {
			draft.owner = { characterId: String(character.characterId), name: character.name };
			renderDoorEditor();
		}),
		bizEl('p', 'biz-hint', 'O dono abre todas as portas e, no tablet (/casa), escolhe portas exclusivas, quem pode abri-las e a senha de cada porta.')
	);
	const wrapper = bizEl('div');
	wrapper.append(box, owner);
	return wrapper;
}

function renderDoorEntry(draft, entry, index) {
	const box = bizEl('div', 'biz-block');
	const head = bizEl('div', 'biz-block-head');
	const status = entry.current === undefined ? '' : (entry.current ? ' · trancada agora' : ' · destrancada agora');
	head.append(bizEl('h3', '', `${entry.label || `Porta ${index + 1}`}${status}`));
	const aim = bizEl('button', 'coe-button biz-small-button', entry.doors.length ? 'Remirar' : 'Mirar na porta');
	aim.type = 'button';
	aim.addEventListener('click', () => doorAim((data) => {
		if (!Array.isArray(data.doors) || !data.doors.length) return;
		entry.doors = data.doors;
		if (entry.kind === 'single' && entry.doors.length === 2) entry.kind = 'double';
		else if (entry.kind === 'double' && entry.doors.length === 1) entry.kind = 'single';
	}));
	head.append(aim);
	if (draft.entries.length > 1) {
		head.append(doorRemoveButton(() => draft.entries.splice(index, 1)));
	}
	box.append(head);

	const kind = bizEl('select', 'coe-field field-control');
	for (const [value, text] of DOOR_KINDS) kind.append(new Option(text, value, false, entry.kind === value));
	kind.addEventListener('change', () => {
		entry.kind = kind.value;
		if (!DOOR_WIDE.has(entry.kind)) entry.distance = Math.min(entry.distance, 6);
		renderDoorEditor();
	});
	const maxDistance = DOOR_WIDE.has(entry.kind) ? 12 : 6;
	const fields = bizEl('div', 'biz-station-fields');
	fields.append(
		bizField('Nome da porta', bizInput('text', entry.label, (value) => { entry.label = value; }, { maxlength: 48, placeholder: `Porta ${index + 1}` })),
		bizField('Tipo', kind),
		bizField(`Distância de uso (1 a ${maxDistance} m)`, bizInput('number', entry.distance, (value) => { entry.distance = bizNumber(value, 2); }, { min: 1, max: maxDistance, step: '0.5' })),
		bizField('Trancar sozinha após (s, 0 = nunca)', bizInput('number', entry.autoLock, (value) => { entry.autoLock = Math.round(bizNumber(value, 0)); }, { min: 0, max: 3600, step: '1' }))
	);
	box.append(fields, garCheck('Trancada por padrão (ao iniciar o servidor)', entry.locked !== false, (checked) => { entry.locked = checked; }));
	if (!entry.doors.length) box.append(bizEl('p', 'biz-hint', 'Ainda sem folha: clique em "Mirar na porta".'));
	entry.doors.forEach((leaf, leafIndex) => {
		box.append(doorRow(`Folha ${leafIndex + 1} · modelo ${leaf.model} · ${bizPointText(leaf)}`, () => entry.doors.splice(leafIndex, 1)));
	});
	box.append(
		bizEl('h4', '', 'Acesso e senha desta porta'),
		garCheck('Acesso exclusivo (só o dono e as pessoas abaixo; chave e regras do local não valem)', entry.restricted === true, (checked) => {
			entry.restricted = checked;
			renderDoorEditor();
		})
	);
	if (entry.restricted) {
		entry.allowed.forEach((person, personIndex) => {
			box.append(doorRow(`${person.name || 'Personagem'} (#${person.characterId})`, () => entry.allowed.splice(personIndex, 1)));
		});
		if (entry.allowed.length < 6) {
			box.append(bizCharacterPicker((character) => {
				const characterId = String(character.characterId);
				if (!entry.allowed.some((person) => person.characterId === characterId) && draft.owner?.characterId !== characterId) {
					entry.allowed.push({ characterId, name: character.name });
				}
				renderDoorEditor();
			}));
		}
	}
	const pin = bizInput('password', entry.pin, (value) => { entry.pin = value.replace(/\D/g, '').slice(0, 8); }, { maxlength: 8, inputmode: 'numeric' });
	pin.autocomplete = 'new-password';
	box.append(bizField(entry.hasPin ? 'Senha da porta: nova (vazio mantém a atual)' : 'Senha da porta (4 a 8 dígitos; pedida para destrancar mesmo com acesso)', pin));
	if (entry.hasPin) box.append(garCheck('Remover a senha desta porta', entry.clearPin === true, (checked) => { entry.clearPin = checked; }));
	return box;
}

function renderDoorLeaves(draft) {
	const wrapper = bizEl('div');
	const head = bizEl('div', 'biz-block-head');
	head.append(bizEl('h3', '', `Portas do local (${draft.entries.length}/12)`));
	const add = bizEl('button', 'coe-button biz-small-button', '+ Adicionar porta');
	add.type = 'button';
	add.disabled = draft.entries.length >= 12;
	add.addEventListener('click', () => {
		draft.entries.push(doorNewEntry(draft));
		renderDoorEditor();
	});
	head.append(add);
	wrapper.append(head, bizEl('p', 'biz-hint', 'Mire com a câmera: E marca a folha (marque as duas numa porta dupla ou portão de duas folhas), Enter conclui. Garagens e portões ficam abertos enquanto destrancados (a pé ou de carro) e aceitam distância maior (para usar de dentro do veículo).'));
	draft.entries.forEach((entry, index) => wrapper.append(renderDoorEntry(draft, entry, index)));
	return wrapper;
}
function renderDoorAccess(draft) {
	const access = draft.access;
	const wrapper = bizEl('div');

	const biz = bizEl('div', 'biz-block');
	biz.append(bizEl('h3', '', 'Negócios / corporações'));
	access.businesses.forEach((rule, index) => {
		const label = (state.data?.businesses?.list || []).find((entry) => entry.id === rule.id)?.label || rule.id;
		const duty = garCheck('Exige ponto batido', rule.duty === true, (checked) => { rule.duty = checked; });
		biz.append(doorRow(label, () => access.businesses.splice(index, 1), duty));
	});
	const bizSelect = bizEl('select', 'coe-field field-control');
	bizSelect.append(new Option('Adicionar negócio…', ''));
	for (const business of state.data?.businesses?.list || []) {
		if (!access.businesses.some((rule) => rule.id === business.id)) bizSelect.append(new Option(`${business.label} (${business.id})`, business.id));
	}
	bizSelect.addEventListener('change', () => {
		if (!bizSelect.value) return;
		access.businesses.push({ id: bizSelect.value, duty: true });
		renderDoorEditor();
	});
	biz.append(bizSelect, bizEl('p', 'biz-hint', 'Dono, sócios e equipe do negócio abrem. Com "exige ponto", só quem está em serviço.'));

	const fac = bizEl('div', 'biz-block');
	fac.append(bizEl('h3', '', 'Facções'));
	const factions = state.data?.doors?.factions || [];
	access.factions.forEach((rule, index) => {
		const label = factions.find((entry) => entry.id === rule.id)?.label || rule.id;
		const grade = bizInput('number', rule.minGrade, (value) => { rule.minGrade = Math.max(0, Math.round(bizNumber(value, 0))); }, { min: 0, max: 100, step: '1' });
		grade.title = 'Grau mínimo';
		fac.append(doorRow(`${label} · grau mínimo`, () => access.factions.splice(index, 1), grade));
	});
	const facSelect = bizEl('select', 'coe-field field-control');
	facSelect.append(new Option(factions.length ? 'Adicionar facção…' : 'Nenhuma facção disponível', ''));
	for (const faction of factions) {
		if (!access.factions.some((rule) => rule.id === faction.id)) facSelect.append(new Option(`${faction.label} (${faction.id})`, faction.id));
	}
	facSelect.addEventListener('change', () => {
		if (!facSelect.value) return;
		access.factions.push({ id: facSelect.value, minGrade: 0 });
		renderDoorEditor();
	});
	fac.append(facSelect);

	const chars = bizEl('div', 'biz-block');
	chars.append(bizEl('h3', '', 'Personagens'));
	access.characters.forEach((entry, index) => {
		chars.append(doorRow(`${entry.name || 'Personagem'} (#${entry.characterId})`, () => access.characters.splice(index, 1)));
	});
	chars.append(bizCharacterPicker((character) => {
		const characterId = String(character.characterId);
		if (!access.characters.some((entry) => entry.characterId === characterId)) {
			access.characters.push({ characterId, name: character.name });
		}
		renderDoorEditor();
	}));

	const items = bizEl('div', 'biz-block');
	items.append(
		bizEl('h3', '', 'Itens e chave'),
		bizField('Itens que abrem (IDs separados por vírgula, até 4)', bizInput('text', access.items.join(', '), (value) => {
			access.items = value.split(',').map((name) => name.trim().toLowerCase()).filter(Boolean);
		}, { maxlength: 160 })),
		garCheck('Aceitar chave do local (item "key" com metadata {"door":"ID"}; abre todas as portas)', access.key === true, (checked) => { access.key = checked; }),
		bizEl('p', 'biz-hint', draft.id ? `Para entregar uma chave: aba Itens → "key" com metadata {"door":"${draft.id}"}.` : 'Defina o ID para gerar a chave.')
	);

	wrapper.append(biz, fac, chars, items);
	return wrapper;
}

function renderDoorPin(draft) {
	const box = bizEl('div', 'biz-block');
	box.append(
		bizEl('h3', '', 'Senha (teclado)'),
		bizEl('p', 'biz-hint', draft.hasPin && !draft.clearPin
			? 'Este local tem senha. Quem não tem acesso pode digitá-la no teclado de qualquer porta dele.'
			: 'Sem senha: só quem tem acesso pelas regras abre.')
	);
	const input = bizInput('password', draft.pin, (value) => { draft.pin = value.replace(/\D/g, '').slice(0, 8); }, { maxlength: 8, inputmode: 'numeric' });
	input.autocomplete = 'new-password';
	box.append(bizField(draft.hasPin ? 'Nova senha (4 a 8 dígitos; vazio mantém a atual)' : 'Senha (4 a 8 dígitos)', input));
	if (draft.hasPin) box.append(garCheck('Remover a senha', draft.clearPin === true, (checked) => { draft.clearPin = checked; }));
	box.append(bizEl('p', 'biz-hint', 'A senha é guardada só como hash. Após 5 erros, o jogador espera 60 s.'));
	return box;
}

function renderDoorEditor() {
	const host = document.getElementById('door-editor');
	if (!host) return;
	const draft = state.door.draft;
	host.replaceChildren();
	if (!draft) {
		host.append(bizEl('div', 'empty-state', 'Selecione um local ou cadastre um novo.'));
		return;
	}
	const heading = bizEl('div', 'panel-heading');
	heading.append(bizEl('h2', '', state.door.isNew ? 'Novo local' : `Editar: ${draft.label || draft.id}`));
	host.append(heading);

	const tabs = bizEl('div', 'biz-sections');
	tabs.setAttribute('role', 'tablist');
	for (const [key, text] of DOOR_SECTIONS) {
		const tab = bizEl('button', `biz-tab${key === state.door.section ? ' is-active' : ''}`, text);
		tab.type = 'button';
		tab.addEventListener('click', () => {
			state.door.section = key;
			renderDoorEditor();
		});
		tabs.append(tab);
	}
	host.append(tabs);

	const body = bizEl('div', 'biz-section-body');
	if (state.door.section === 'general') body.append(renderDoorGeneral(draft));
	else if (state.door.section === 'leaves') body.append(renderDoorLeaves(draft));
	else if (state.door.section === 'access') body.append(renderDoorAccess(draft));
	else body.append(renderDoorPin(draft));
	host.append(body);

	const actions = bizEl('div', 'biz-actions');
	const save = bizEl('button', 'coe-button coe-button--primary primary-button', 'Salvar local');
	save.type = 'button';
	save.addEventListener('click', () => {
		if (!draft.entries.length || draft.entries.some((entry) => !entry.doors.length)) {
			showToast('Mire em todas as portas antes de salvar (aba Portas).', false);
			return;
		}
		postNui('saveDoor', { door: doorPayload(draft) }).then((result) => {
			if (!result.ok) showToast('Não foi possível enviar a porta.', false);
		});
	});
	actions.append(save);
	if (!state.door.isNew) {
		const remove = bizEl('button', 'coe-button biz-danger', 'Remover');
		remove.type = 'button';
		remove.addEventListener('click', () => {
			if (remove.dataset.confirm !== '1') {
				remove.dataset.confirm = '1';
				remove.textContent = 'Confirmar remoção';
				return;
			}
			postNui('deleteDoor', { id: draft.id });
		});
		actions.append(remove);
	}
	host.append(actions);
}

function renderDoors() {
	const data = state.data?.doors;
	const list = document.getElementById('door-list');
	if (!list) return;
	list.replaceChildren();
	if (!data?.available) {
		appendEmpty(list, 'O resource coe_doors não está iniciado.');
		return;
	}
	if (state.door.reload) {
		const fresh = (data.list || []).find((entry) => entry.id === state.door.reload);
		if (fresh && state.door.draft?.id === fresh.id) {
			state.door.draft = doorFromEntry(fresh);
			state.door.reload = null;
			renderDoorEditor();
		}
	}
	const term = (state.door.filter || '').toLowerCase();
	const items = (data.list || []).filter((entry) => !term || entry.label.toLowerCase().includes(term) || entry.id.includes(term));
	if (!items.length) appendEmpty(list, term ? 'Nenhum local encontrado.' : 'Nenhum local cadastrado.');
	for (const entry of items) {
		const row = bizEl('button', `biz-item${state.door.draft?.id === entry.id ? ' is-active' : ''}`);
		row.type = 'button';
		const entries = entry.entries || [];
		const locked = entries.filter((door) => door.current).length;
		const flags = [entry.id, entries.length === 1 ? (locked ? 'trancada' : 'destrancada') : `${entries.length} portas · ${locked} trancadas`];
		if (entries.some((door) => DOOR_WIDE.has(door.kind))) flags.push('garagem/portão');
		if (entry.hasPin) flags.push('senha');
		if (entry.owner) flags.push(`dono: ${entry.owner.name || entry.owner.characterId}`);
		if (entries.some((door) => door.restricted || door.hasPin)) flags.push('portas protegidas');
		if (entry.enabled === false) flags.push('inativa');
		row.append(bizEl('strong', '', entry.label), bizEl('small', '', flags.join(' · ')));
		row.addEventListener('click', () => {
			state.door.draft = doorFromEntry(entry);
			state.door.isNew = false;
			renderDoors();
			renderDoorEditor();
		});
		list.append(row);
	}
	if (!state.door.draft) renderDoorEditor();
}

function onDoorResult(data) {
	const message = document.getElementById('door-message');
	message.textContent = data.message || '';
	message.classList.toggle('is-success', data.success === true);
	if (data.success !== true) return;
	if (data.operation === 'doorDelete') state.door.draft = null;
	else if (state.door.draft) {
		// O painel é atualizado logo depois do resultado: recarrega o rascunho com a versão salva.
		state.door.reload = state.door.draft.id;
		state.door.isNew = false;
	}
	renderDoors();
	renderDoorEditor();
}

document.getElementById('door-new').addEventListener('click', () => {
	state.door.draft = doorNewDraft();
	state.door.isNew = true;
	state.door.section = 'general';
	renderDoors();
	renderDoorEditor();
});

document.getElementById('door-search').addEventListener('input', (event) => {
	state.door.filter = event.target.value.trim();
	renderDoors();
});
