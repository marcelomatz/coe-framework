// Aba "Imóveis": apartamento inicial, hotéis, casas e imóveis comerciais. Usa os helpers de app.js.
const HOU_SECTIONS = [['general', 'Geral'], ['interior', 'Interior'], ['points', 'Porta e baú'], ['rent', 'Aluguel']];
const HOU_TRIP_ERRORS = {
	inside_property: 'Saia do imóvel antes de visitar interiores.', forbidden: 'Sem permissão para visitar interiores.',
	not_ready: 'O resource coe_housing não está disponível.', timeout: 'O servidor não respondeu. Tente de novo.'
};
const HOU_THUMB = { width: 384, height: 216, quality: 0.75 };
const HOU_KINDS = { apartment: 'Apartamentos', hotel: 'Hotéis', house: 'Casas', commercial: 'Comerciais', hideout: 'Ilegais' };
// Espelha HousingConfig.Limits.MaxHideoutMembers.
const HOU_MAX_MEMBERS = 10;
const HOU_CYCLES = [[7, 'Semanal'], [15, 'Quinzenal'], [30, 'Mensal']];
const HOU_BLIP = { apartment: { sprite: 40, color: 3 }, hotel: { sprite: 40, color: 5 }, house: { sprite: 40, color: 2 }, commercial: { sprite: 475, color: 4 }, hideout: { sprite: 40, color: 1 } };
// Espelha HousingConfig.Stash.Defaults (peso em gramas).
const HOU_STASH = { apartment: { slots: 40, maxWeight: 200000 }, hotel: { slots: 20, maxWeight: 80000 }, house: { slots: 60, maxWeight: 400000 }, commercial: { slots: 80, maxWeight: 600000 }, hideout: { slots: 50, maxWeight: 300000 } };

function houNewDraft(kind) {
	return {
		id: '', kind, label: '', enabled: true, units: 1, starter: false, door: null, interior: null, interiorId: '', businessId: '', stash: null,
		rentOn: kind !== 'apartment' && kind !== 'hideout', daily: 100, cycles: [7, 15, 30], owner: null, members: [],
		blip: { enabled: kind !== 'hideout', sprite: HOU_BLIP[kind].sprite, color: HOU_BLIP[kind].color, scale: 0.8 }
	};
}

function houFromEntry(entry) {
	const draft = houNewDraft(entry.kind);
	Object.assign(draft, {
		id: entry.id, label: entry.label, enabled: entry.enabled !== false, units: entry.units || 1, starter: entry.starter === true,
		door: entry.door || null, interior: entry.interior || null, interiorId: entry.interiorId || '', blip: { ...draft.blip, ...(entry.blip || {}) },
		businessId: entry.businessId || '', stash: entry.stash ? { ...entry.stash } : null,
		rentOn: !!entry.rent, daily: entry.rent?.daily || 100, cycles: entry.rent?.cycles || [7, 15, 30],
		owner: entry.owner ? { characterId: String(entry.owner.characterId), name: entry.owner.name } : null,
		members: (entry.members || []).map((person) => ({ characterId: String(person.characterId), name: person.name }))
	});
	return draft;
}

function houLinked(draft) {
	return draft.kind === 'commercial' && !!draft.businessId;
}

function houPayload(draft) {
	const linked = houLinked(draft);
	const payload = {
		id: draft.id, kind: draft.kind, label: draft.label, enabled: draft.enabled, units: linked ? 1 : draft.units,
		starter: draft.kind !== 'commercial' && draft.starter, door: draft.door || undefined, interior: draft.interior || undefined,
		interiorId: draft.interiorId || undefined, blip: draft.blip, stash: draft.stash || undefined
	};
	if (draft.kind === 'hideout') {
		Object.assign(payload, { units: 1, starter: false, blip: { ...draft.blip, enabled: false }, owner: draft.owner || undefined, members: draft.members });
	} else if (linked) payload.businessId = draft.businessId;
	else if (draft.rentOn && !payload.starter) payload.rent = { daily: draft.daily, cycles: draft.cycles };
	return payload;
}

function houPreview(draft) {
	return [draft.door, draft.interior].filter((point) => point && Number.isFinite(point.x));
}

function renderHousingGeneral(draft) {
	if (draft.kind === 'hideout') return renderHideoutGeneral(draft);
	const box = bizEl('div', 'biz-block');
	const idInput = bizInput('text', draft.id, (value) => { draft.id = value.toLowerCase(); }, { maxlength: 32 });
	idInput.disabled = !state.hou.isNew;
	box.append(
		bizEl('h3', '', 'Identificação'),
		bizField('ID (letras minúsculas, números e _)', idInput),
		bizField('Nome', bizInput('text', draft.label, (value) => { draft.label = value; }, { maxlength: 48 })),
		bizField('Unidades (quartos ou apartamentos independentes)', bizInput('number', draft.units, (value) => { draft.units = bizNumber(value, 1); }, { min: 1, max: 500 })),
		garCheck('Ativo', draft.enabled !== false, (checked) => { draft.enabled = checked; })
	);
	if (draft.kind === 'commercial') {
		const select = bizEl('select', 'coe-field field-control');
		select.append(new Option('Nenhum (negócios alugam pelo caixa da sociedade)', ''));
		for (const business of state.data?.businesses?.list || []) {
			select.append(new Option(`${business.label} (${business.id})`, business.id));
		}
		select.value = draft.businessId;
		select.addEventListener('change', () => {
			draft.businessId = select.value;
			if (draft.businessId) draft.units = 1;
			renderHousingEditor();
		});
		box.append(
			bizField('Negócio vinculado', select),
			bizEl('p', 'biz-hint', 'Vinculado: o imóvel é cedido de graça ao negócio (uma unidade, sem aluguel). Sem vínculo: quem está de ponto com permissão de caixa aluga para o negócio.')
		);
	} else {
		box.append(garCheck('Imóvel inicial (todo personagem novo recebe uma unidade grátis)', draft.starter === true, (checked) => {
			draft.starter = checked;
			if (checked) draft.rentOn = false;
			renderHousingEditor();
		}));
	}

	const blip = bizEl('div', 'biz-block');
	blip.append(
		bizEl('h3', '', 'Blip no mapa'),
		garCheck('Mostrar no mapa', draft.blip.enabled === true, (checked) => { draft.blip.enabled = checked; })
	);
	const fields = bizEl('div', 'biz-station-fields');
	fields.append(
		bizField('Ícone (1 a 900)', bizInput('number', draft.blip.sprite, (value) => { draft.blip.sprite = bizNumber(value, 40); }, { min: 1, max: 900 })),
		bizField('Cor (0 a 85)', bizInput('number', draft.blip.color, (value) => { draft.blip.color = bizNumber(value, 3); }, { min: 0, max: 85 })),
		bizField('Tamanho (0.5 a 1.5)', bizInput('number', draft.blip.scale, (value) => { draft.blip.scale = bizNumber(value, 0.8); }, { min: 0.5, max: 1.5, step: '0.1' }))
	);
	blip.append(fields);
	const wrapper = bizEl('div');
	wrapper.append(box, blip);
	return wrapper;
}

// Imóvel ilegal: entrada escondida (sem mapa, fora da imobiliária) para um interior compartilhado por dono e membros.
function renderHideoutGeneral(draft) {
	const box = bizEl('div', 'biz-block');
	const idInput = bizInput('text', draft.id, (value) => { draft.id = value.toLowerCase(); }, { maxlength: 32 });
	idInput.disabled = !state.hou.isNew;
	box.append(
		bizEl('h3', '', 'Identificação'),
		bizField('ID (letras minúsculas, números e _)', idInput),
		bizField('Nome (só quem tem acesso vê)', bizInput('text', draft.label, (value) => { draft.label = value; }, { maxlength: 48 })),
		garCheck('Ativo', draft.enabled !== false, (checked) => { draft.enabled = checked; }),
		bizEl('p', 'biz-hint', 'Não aparece no mapa nem na imobiliária. A entrada só existe para o dono e as pessoas com acesso; todos dividem o mesmo interior e o mesmo baú.')
	);
	const owner = bizEl('div', 'biz-block');
	owner.append(bizEl('h3', '', 'Dono'));
	if (draft.owner) owner.append(doorRow(`${draft.owner.name || 'Personagem'} (#${draft.owner.characterId})`, () => { draft.owner = null; renderHousingEditor(); }));
	else owner.append(bizEl('p', 'biz-hint', 'Sem dono: só as pessoas abaixo entram.'));
	owner.append(
		bizCharacterPicker((character) => {
			const characterId = String(character.characterId);
			draft.owner = { characterId, name: character.name };
			draft.members = draft.members.filter((person) => person.characterId !== characterId);
			renderHousingEditor();
		}),
		bizEl('p', 'biz-hint', 'O dono entra e, no tablet (/casa → Esconderijo), escolhe quem mais tem acesso.')
	);
	const members = bizEl('div', 'biz-block');
	members.append(bizEl('h3', '', `Pessoas com acesso (${draft.members.length}/${HOU_MAX_MEMBERS})`));
	if (!draft.members.length) members.append(bizEl('p', 'biz-hint', 'Ninguém além do dono.'));
	draft.members.forEach((person, index) => {
		members.append(doorRow(`${person.name || 'Personagem'} (#${person.characterId})`, () => {
			draft.members.splice(index, 1);
			renderHousingEditor();
		}));
	});
	if (draft.members.length < HOU_MAX_MEMBERS) {
		members.append(bizCharacterPicker((character) => {
			const characterId = String(character.characterId);
			if (draft.owner?.characterId !== characterId && !draft.members.some((person) => person.characterId === characterId)) {
				draft.members.push({ characterId, name: character.name });
			}
			renderHousingEditor();
		}));
	}
	const wrapper = bizEl('div');
	wrapper.append(box, owner, members);
	return wrapper;
}

function houPointBlock(draft, key, title, hint, defaultRadius, min, max) {
	const box = bizEl('div', 'biz-block');
	const head = bizEl('div', 'biz-block-head');
	head.append(bizEl('h3', '', title));
	const mark = bizEl('button', 'coe-button biz-small-button', draft[key] ? 'Remarcar' : '+ Marcar');
	mark.type = 'button';
	mark.addEventListener('click', () => bizCapture({ label: title, preview: houPreview(draft) }, (data) => {
		if (!data.point) return;
		draft[key] = { ...data.point, radius: draft[key]?.radius || defaultRadius };
	}));
	head.append(mark);
	box.append(head, bizEl('p', 'biz-hint', hint));
	if (draft[key]) {
		box.append(
			bizEl('p', 'biz-hint', `${bizPointText(draft[key])} · direção ${Number(draft[key].heading || 0).toFixed(0)}°`),
			bizField('Raio de interação', bizInput('number', draft[key].radius, (value) => { draft[key].radius = bizNumber(value, defaultRadius); }, { min, max, step: '0.5' }))
		);
	}
	return box;
}

// Baú: marcado visitando o interior (mundo isolado), já que fica dentro dele.
function renderHousingStash(draft) {
	const box = bizEl('div', 'biz-block');
	const head = bizEl('div', 'biz-block-head');
	head.append(bizEl('h3', '', 'Baú'));
	const buttons = bizEl('div', 'hou-actions-row');
	const mark = houSmallButton(draft.stash ? 'Remarcar no interior' : '+ Marcar no interior', () => houVisitProperty(draft, 'stash'));
	mark.disabled = !draft.interior;
	buttons.append(mark);
	if (draft.stash) {
		buttons.append(houSmallButton('Remover baú', () => {
			draft.stash = null;
			renderHousingEditor();
		}));
	}
	head.append(buttons);
	box.append(head, bizEl('p', 'biz-hint', draft.interior
		? 'Cada morador tem o próprio baú (em comerciais, um por negócio). O conteúdo fica no imóvel: quem volta a alugar reencontra o que guardou. Ao marcar, você visita o interior e aperta E no lugar do baú.'
		: 'Defina o interior primeiro (seção Interior) para marcar o baú dentro dele.'));
	if (draft.stash) {
		const defaults = HOU_STASH[draft.kind];
		const fields = bizEl('div', 'biz-station-fields');
		fields.append(
			bizField('Slots (1 a 200)', bizInput('number', draft.stash.slots ?? defaults.slots, (value) => { draft.stash.slots = bizNumber(value, defaults.slots); }, { min: 1, max: 200 })),
			bizField('Peso máximo (kg)', bizInput('number', (draft.stash.maxWeight ?? defaults.maxWeight) / 1000, (value) => { draft.stash.maxWeight = Math.round(bizNumber(value, defaults.maxWeight / 1000) * 1000); }, { min: 1, max: 2000 })),
			bizField('Raio de interação', bizInput('number', draft.stash.radius ?? 1.2, (value) => { draft.stash.radius = bizNumber(value, 1.2); }, { min: 0.5, max: 3, step: '0.5' }))
		);
		box.append(bizEl('p', 'biz-hint', `${bizPointText(draft.stash)}`), fields, bizEl('p', 'biz-hint', 'A capacidade vale para baús novos; baús que já existem mantêm a capacidade com que foram criados.'));
	}
	return box;
}

function renderHousingPoints(draft) {
	const wrapper = bizEl('div');
	wrapper.append(
		houPointBlock(draft, 'door', 'Porta de entrada', 'Onde o jogador abre o menu do imóvel; é também o ponto de saída ao sair.', 2, 1, 5),
		renderHousingStash(draft)
	);
	return wrapper;
}

// Catálogo de interiores nativos (coe_housing/shared/interiors.lua) e miniaturas capturadas no jogo.
function houInteriors() {
	return state.data?.housing?.interiors || { categories: [], list: [] };
}

function houInteriorById(id) {
	return (houInteriors().list || []).find((entry) => entry.id === id) || null;
}

function houCategoryLabel(key) {
	const found = (houInteriors().categories || []).find(([value]) => value === key);
	return found ? found[1] : key;
}

function houThumb(entry) {
	const frame = bizEl('div', 'hou-thumb');
	const source = state.hou.thumbs[entry.id];
	if (source) {
		const image = bizEl('img');
		image.src = source;
		image.alt = entry.label;
		frame.append(image);
	} else {
		frame.append(bizEl('span', '', 'Sem miniatura'));
	}
	return frame;
}

function houLoadThumbs(force) {
	if (state.hou.thumbsLoaded && !force) return;
	state.hou.thumbsLoaded = true;
	postNui('housingThumbs').then((result) => {
		if (result.ok) state.hou.thumbsRequestId = result.requestId;
		else state.hou.thumbsLoaded = false;
	});
}

function onHousingThumbsResult(data) {
	if (data.requestId !== state.hou.thumbsRequestId) return;
	if (data.error) {
		state.hou.thumbsLoaded = false;
		showToast('Não foi possível carregar as miniaturas.', false);
		return;
	}
	state.hou.thumbs = data.thumbs && !Array.isArray(data.thumbs) ? data.thumbs : {};
	if (state.hou.section === 'interior') renderHousingEditor();
	renderRealty();
}

// Reduz a captura em tela cheia para uma miniatura 16:9 (recorte central) antes de enviar ao servidor.
function onHousingThumbRaw(data) {
	const reply = (small) => postNui('housingThumbReady', { id: data.id, data: small || null });
	const image = new Image();
	image.onload = () => {
		const canvas = document.createElement('canvas');
		canvas.width = HOU_THUMB.width;
		canvas.height = HOU_THUMB.height;
		const scale = Math.max(HOU_THUMB.width / image.width, HOU_THUMB.height / image.height);
		const width = HOU_THUMB.width / scale;
		const height = HOU_THUMB.height / scale;
		canvas.getContext('2d').drawImage(image, (image.width - width) / 2, (image.height - height) / 2, width, height, 0, 0, HOU_THUMB.width, HOU_THUMB.height);
		const small = canvas.toDataURL('image/jpeg', HOU_THUMB.quality);
		state.hou.thumbs[data.id] = small;
		reply(small);
	};
	image.onerror = () => reply(null);
	image.src = data.data;
}

// Resultado de uma visita ou geração de miniaturas (vem no captureDone).
function houTripNotice(result) {
	if (result.error) showToast(HOU_TRIP_ERRORS[result.error] || 'Não foi possível visitar o interior.', false);
	if (result.thumbs) {
		const { done, failed, cancelled } = result.thumbs;
		showToast(`Miniaturas: ${done} gerada(s)${failed ? `, ${failed} com falha` : ''}${cancelled ? ' (cancelado)' : ''}.`, !failed);
	}
}

function houSelectInterior(draft, entry) {
	draft.interiorId = entry.id;
	draft.interior = { x: entry.x, y: entry.y, z: entry.z, heading: entry.heading || 0, radius: draft.interior?.radius || 1.5 };
	renderHousingEditor();
}

function houStartVisit(payload, onPoint) {
	state.biz.pendingCapture = (data) => {
		if (data.point && onPoint) onPoint(data);
	};
	postNui('housingVisit', payload).then((result) => {
		if (!result.ok) {
			state.biz.pendingCapture = null;
			showToast('Não foi possível iniciar a visita.', false);
		}
	});
}

function houVisit(draft, entry, useDraftPoint) {
	houStartVisit({ id: entry.id, point: useDraftPoint ? draft.interior : undefined, mark: 'interior' }, (data) => {
		draft.interiorId = data.interiorId;
		draft.interior = { ...data.point, radius: draft.interior?.radius || 1.5 };
	});
}

// Visita o interior do imóvel (catálogo ou ponto personalizado). mark: 'stash' marca o baú; 'none' só visita.
function houVisitProperty(draft, mark) {
	if (!draft.interior) return;
	const known = draft.interiorId && houInteriorById(draft.interiorId);
	const start = mark === 'stash' && draft.stash ? draft.stash : draft.interior;
	houStartVisit({ id: known ? draft.interiorId : undefined, point: start, mark, label: draft.label || draft.id }, mark === 'stash' ? (data) => {
		const defaults = HOU_STASH[draft.kind];
		draft.stash = { slots: defaults.slots, maxWeight: defaults.maxWeight, radius: 1.2, ...(draft.stash || {}), x: data.point.x, y: data.point.y, z: data.point.z };
	} : null);
}

function houGenerateThumbs(all) {
	const ids = (houInteriors().list || []).filter((entry) => all || !state.hou.thumbs[entry.id]).map((entry) => entry.id);
	if (!ids.length) {
		showToast('Todos os interiores já têm miniatura.');
		return;
	}
	postNui('housingGenerateThumbs', { ids }).then((result) => {
		if (result.ok) return;
		showToast(result.error === 'no_screenshot' ? 'Inicie o resource screenshot-basic para gerar miniaturas.' : 'Não foi possível iniciar a geração.', false);
	});
}

function houSmallButton(text, onClick) {
	const button = bizEl('button', 'coe-button biz-small-button', text);
	button.type = 'button';
	button.addEventListener('click', onClick);
	return button;
}

function renderHousingChosen(draft) {
	const entry = draft.interiorId ? houInteriorById(draft.interiorId) : null;
	if (!entry) {
		const box = houPointBlock(draft, 'interior', 'Interior personalizado', 'Sem interior do catálogo: marque onde o jogador aparece ao entrar (de frente para dentro) e onde aperta E para sair. Ou escolha um interior nativo abaixo.', 1.5, 1, 4);
		if (draft.interiorId) box.append(bizEl('p', 'biz-hint', `O interior "${draft.interiorId}" não existe mais no catálogo; o ponto salvo continua valendo.`));
		return box;
	}
	const box = bizEl('div', 'biz-block');
	const head = bizEl('div', 'biz-block-head');
	head.append(bizEl('h3', '', 'Interior escolhido'));
	box.append(head);
	const selected = bizEl('div', 'hou-selected');
	const info = bizEl('div', 'hou-selected-info');
	info.append(
		bizEl('strong', '', entry.label),
		bizEl('p', 'biz-hint', `${houCategoryLabel(entry.category)} · ponto ${bizPointText(draft.interior)} · direção ${Number(draft.interior?.heading || 0).toFixed(0)}°`),
		bizEl('p', 'biz-hint', 'Todos os moradores usam este interior, cada um no seu próprio mundo. Visite para conferir e, se quiser, marque com E o ponto exato de chegada e saída (de frente para dentro).')
	);
	const buttons = bizEl('div', 'hou-actions-row');
	buttons.append(
		houSmallButton('Visitar e ajustar', () => houVisit(draft, entry, true)),
		houSmallButton('Ponto padrão', () => houSelectInterior(draft, entry)),
		houSmallButton('Trocar para personalizado', () => {
			draft.interiorId = '';
			renderHousingEditor();
		})
	);
	info.append(buttons);
	if (draft.interior) {
		info.append(bizField('Raio de interação da saída', bizInput('number', draft.interior.radius, (value) => { draft.interior.radius = bizNumber(value, 1.5); }, { min: 1, max: 4, step: '0.5' })));
	}
	selected.append(houThumb(entry), info);
	box.append(selected);
	return box;
}

function renderHousingCatalog(draft) {
	const box = bizEl('div', 'biz-block');
	const head = bizEl('div', 'biz-block-head');
	head.append(bizEl('h3', '', 'Interiores nativos'));
	const generate = bizEl('div', 'hou-actions-row');
	generate.append(
		houSmallButton('Gerar miniaturas faltantes', () => houGenerateThumbs(false)),
		houSmallButton('Regerar todas', () => houGenerateThumbs(true))
	);
	head.append(generate);
	box.append(head, bizEl('p', 'biz-hint', 'As miniaturas são capturadas no próprio jogo (screenshot-basic): o painel some, você visita cada interior num mundo só seu e volta ao fim. Backspace cancela.'));

	const filters = bizEl('div', 'hou-filters');
	const categories = [['all', 'Todos'], ...(houInteriors().categories || [])];
	for (const [key, label] of categories) {
		const chip = bizEl('button', `biz-tab${state.hou.interiorCategory === key ? ' is-active' : ''}`, label);
		chip.type = 'button';
		chip.addEventListener('click', () => {
			state.hou.interiorCategory = key;
			renderHousingEditor();
		});
		filters.append(chip);
	}
	const search = bizInput('search', state.hou.interiorSearch, (value) => {
		state.hou.interiorSearch = value;
		fill();
	}, { placeholder: 'Buscar interior', maxlength: 40 });
	box.append(filters, bizField('Buscar', search));

	const grid = bizEl('div', 'hou-interior-grid');
	const fill = () => {
		grid.replaceChildren();
		const term = state.hou.interiorSearch.trim().toLowerCase();
		const items = (houInteriors().list || []).filter((entry) => (state.hou.interiorCategory === 'all' || entry.category === state.hou.interiorCategory)
			&& (!term || entry.label.toLowerCase().includes(term) || entry.id.includes(term)));
		if (!items.length) appendEmpty(grid, 'Nenhum interior encontrado.');
		for (const entry of items) {
			const card = bizEl('div', `hou-card${draft.interiorId === entry.id ? ' is-active' : ''}`);
			const body = bizEl('div', 'hou-card-body');
			body.append(bizEl('strong', '', entry.label), bizEl('small', '', houCategoryLabel(entry.category)));
			const actions = bizEl('div', 'hou-card-actions');
			const use = houSmallButton(draft.interiorId === entry.id ? 'Escolhido' : 'Usar', () => houSelectInterior(draft, entry));
			use.disabled = draft.interiorId === entry.id;
			actions.append(use, houSmallButton('Visitar', () => houVisit(draft, entry, false)));
			card.append(houThumb(entry), body, actions);
			grid.append(card);
		}
	};
	fill();
	box.append(grid);
	return box;
}

function renderHousingInterior(draft) {
	houLoadThumbs(false);
	const wrapper = bizEl('div');
	wrapper.append(renderHousingChosen(draft), renderHousingCatalog(draft));
	return wrapper;
}

function renderHousingRent(draft) {
	const box = bizEl('div', 'biz-block');
	box.append(bizEl('h3', '', 'Aluguel'));
	if (draft.starter) {
		box.append(bizEl('p', 'biz-hint', 'Imóvel inicial é gratuito e não pode ser alugado.'));
		return box;
	}
	if (houLinked(draft)) {
		box.append(bizEl('p', 'biz-hint', 'Imóvel cedido ao negócio vinculado: sem aluguel.'));
		return box;
	}
	box.append(
		garCheck('Disponível para aluguel', draft.rentOn, (checked) => { draft.rentOn = checked; renderHousingEditor(); })
	);
	if (!draft.rentOn) return box;
	box.append(bizField('Diária ($)', bizInput('number', draft.daily, (value) => { draft.daily = bizNumber(value, 100); }, { min: 1, max: 1000000 })));
	const cycles = bizEl('div', 'biz-block-head');
	for (const [days, label] of HOU_CYCLES) {
		cycles.append(garCheck(`${label} (${days} dias)`, draft.cycles.includes(days), (checked) => {
			draft.cycles = HOU_CYCLES.map(([value]) => value).filter((value) => (value === days ? checked : draft.cycles.includes(value)));
		}));
	}
	box.append(bizEl('p', 'biz-hint', 'A cobrança do ciclo é antecipada e renovada automaticamente; sem saldo há 3 dias de tolerância antes de encerrar o contrato.'), cycles);
	return box;
}

function renderHousingEditor() {
	const host = document.getElementById('hou-editor');
	if (!host) return;
	const draft = state.hou.draft;
	host.replaceChildren();
	if (!draft) {
		host.append(bizEl('div', 'empty-state', 'Selecione um imóvel ou crie um novo.'));
		return;
	}
	const heading = bizEl('div', 'panel-heading');
	heading.append(bizEl('h2', '', state.hou.isNew ? 'Novo imóvel' : `Editar: ${draft.label || draft.id}`));
	host.append(heading);

	const sections = HOU_SECTIONS.filter(([key]) => key !== 'rent' || draft.kind !== 'hideout');
	if (!sections.some(([key]) => key === state.hou.section)) state.hou.section = 'general';
	const tabs = bizEl('div', 'biz-sections');
	tabs.setAttribute('role', 'tablist');
	for (const [key, text] of sections) {
		const tab = bizEl('button', `biz-tab${key === state.hou.section ? ' is-active' : ''}`, text);
		tab.type = 'button';
		tab.addEventListener('click', () => {
			state.hou.section = key;
			renderHousingEditor();
		});
		tabs.append(tab);
	}
	host.append(tabs);

	const body = bizEl('div', 'biz-section-body');
	if (state.hou.section === 'general') body.append(renderHousingGeneral(draft));
	else if (state.hou.section === 'interior') body.append(renderHousingInterior(draft));
	else if (state.hou.section === 'points') body.append(renderHousingPoints(draft));
	else body.append(renderHousingRent(draft));
	host.append(body);

	const actions = bizEl('div', 'biz-actions');
	const save = bizEl('button', 'coe-button coe-button--primary primary-button', 'Salvar imóvel');
	save.type = 'button';
	save.addEventListener('click', () => {
		postNui('saveProperty', { property: houPayload(draft) }).then((result) => {
			if (!result.ok) showToast('Não foi possível enviar o imóvel.', false);
		});
	});
	actions.append(save);
	if (!state.hou.isNew) {
		const remove = bizEl('button', 'coe-button biz-danger', 'Remover');
		remove.type = 'button';
		remove.addEventListener('click', () => {
			if (remove.dataset.confirm !== '1') {
				remove.dataset.confirm = '1';
				remove.textContent = 'Confirmar remoção';
				return;
			}
			postNui('deleteProperty', { id: draft.id });
		});
		actions.append(remove);
	}
	host.append(actions);
}

function renderHousing() {
	const data = state.data?.housing;
	const tabs = document.getElementById('hou-kinds');
	const list = document.getElementById('hou-list');
	if (!tabs || !list) return;
	tabs.replaceChildren();
	list.replaceChildren();
	if (!data?.available) {
		appendEmpty(list, 'O resource coe_housing não está iniciado.');
		return;
	}
	const realtyMode = state.hou.kind === 'realty';
	document.getElementById('hou-grid').hidden = realtyMode;
	document.getElementById('hou-realty').hidden = !realtyMode;
	for (const key of [...Object.keys(HOU_KINDS), 'realty']) {
		const button = bizEl('button', `biz-tab${key === state.hou.kind ? ' is-active' : ''}`, HOU_KINDS[key] || 'Imobiliária');
		button.type = 'button';
		button.addEventListener('click', () => {
			state.hou.kind = key;
			state.hou.draft = null;
			renderHousing();
			renderHousingEditor();
		});
		tabs.append(button);
	}
	if (realtyMode) {
		renderRealty();
		return;
	}
	document.getElementById('hou-list-title').textContent = HOU_KINDS[state.hou.kind];
	const items = (data.list || []).filter((entry) => entry.kind === state.hou.kind);
	if (!items.length) appendEmpty(list, 'Nenhum imóvel neste tipo.');
	for (const entry of items) {
		const row = bizEl('button', `biz-item${state.hou.draft?.id === entry.id ? ' is-active' : ''}`);
		row.type = 'button';
		const usage = entry.kind === 'hideout'
			? `${entry.owner ? `dono ${entry.owner.name}` : 'sem dono'} · ${(entry.members || []).length} com acesso`
			: `${entry.occupied || 0}/${entry.units} ocupada(s)`;
		const flags = `${entry.starter ? ' · inicial' : ''}${entry.businessId ? ` · cedido a ${entry.businessId}` : ''}${entry.enabled === false ? ' · inativo' : ''}`;
		row.append(bizEl('strong', '', entry.label), bizEl('small', '', `${entry.id} · ${usage}${flags}`));
		row.addEventListener('click', () => {
			state.hou.draft = houFromEntry(entry);
			state.hou.isNew = false;
			renderHousing();
			renderHousingEditor();
		});
		list.append(row);
	}
	if (!state.hou.draft) renderHousingEditor();
}

function onPropertyResult(data) {
	const message = document.getElementById('hou-message');
	message.textContent = data.message || '';
	message.classList.toggle('is-success', data.success === true);
	if (data.success !== true) return;
	if (data.operation === 'propertyDelete') state.hou.draft = null;
	else state.hou.isNew = false;
	renderHousing();
	renderHousingEditor();
}

document.getElementById('hou-new').addEventListener('click', () => {
	state.hou.draft = houNewDraft(state.hou.kind);
	state.hou.isNew = true;
	state.hou.section = 'general';
	renderHousing();
	renderHousingEditor();
});
