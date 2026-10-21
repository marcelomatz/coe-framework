// Criador de personagem (NUI). Cada mudança vai para o jogo (callback `update`, com debounce) e o ped muda na hora.
// O cliente devolve os limites do modelo (quantas roupas, texturas e cabelos existem) para os seletores.
const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'coe_appearance'
const $ = (id) => document.getElementById(id)

function post(endpoint, payload = {}) {
	return fetch(`https://${resource}/${endpoint}`, {
		method: 'POST',
		headers: { 'Content-Type': 'application/json; charset=UTF-8' },
		body: JSON.stringify(payload)
	}).then((response) => response.json()).catch(() => ({ ok: false }))
}

const STEPS = [
	{ id: 'identity', label: 'Identidade', hint: 'Nome, data de nascimento e gênero. É assim que a cidade vai te conhecer.' },
	{ id: 'heritage', label: 'Herança', hint: 'Escolha mãe e pai. As barras definem com quem você se parece e o tom da pele.' },
	{ id: 'face', label: 'Rosto', hint: 'Ajustes finos de nariz, olhos, maçãs, mandíbula e queixo.' },
	{ id: 'details', label: 'Detalhes', hint: 'Cor dos olhos, pele, idade aparente, sardas e marcas.' },
	{ id: 'hair', label: 'Cabelo e maquiagem', hint: 'Corte e cores da paleta do jogo, sobrancelhas, barba e maquiagem.' },
	{ id: 'clothes', label: 'Roupas', hint: 'Comece por um conjunto pronto e ajuste peça por peça.' },
	{ id: 'review', label: 'Revisão', hint: 'Confira tudo antes de registrar. Depois, o visual só muda em barbearias e lojas.' }
]
const CAMERAS = [['body', 'Corpo'], ['upper', 'Busto'], ['face', 'Rosto'], ['legs', 'Pernas']]
const PART_CAMERA = { 4: 'legs', 6: 'legs', 11: 'upper', 8: 'upper', 3: 'upper', 7: 'upper', 5: 'upper', 1: 'face', 9: 'upper', 10: 'upper' }
const PROP_CAMERA = { 0: 'face', 1: 'face', 2: 'face', 6: 'upper', 7: 'upper' }
const EYE_COLORS = ['Verde', 'Esmeralda', 'Azul-claro', 'Azul-oceano', 'Castanho-claro', 'Castanho-escuro', 'Avelã', 'Cinza-escuro', 'Cinza-claro', 'Rosa', 'Amarelo', 'Roxo', 'Preto', 'Cinza-sombra', 'Tequila', 'Ametista', 'Âmbar', 'Mel', 'Prata', 'Ouro', 'Fogo', 'Gelo']

const state = {
	open: false,
	mode: 'create',
	gender: 'male',
	identity: { firstName: '', lastName: '', birthDate: '' },
	identityLimits: { NameMin: 2, NameMax: 24, MinAge: 18, MaxAge: 90 },
	appearance: null,
	limits: null,
	palettes: { hair: [], makeup: [] },
	schema: null,
	outfits: [],
	cameraSteps: {},
	step: 0,
	camera: 'body',
	saving: false,
	thumbs: null,
	clothesTab: null,
	clothesPart: {}
}

function steps() {
	return state.mode === 'create' ? STEPS : STEPS.filter((step) => step.id !== 'identity')
}

function el(tag, className, text) {
	const node = document.createElement(tag)
	if (className) node.className = className
	if (text !== undefined) node.textContent = text
	return node
}

function message(text = '') {
	$('message').textContent = text
}

// Envio ao jogo -------------------------------------------------------------------------------------------------

let updateTimer = null
function pushAppearance() {
	clearTimeout(updateTimer)
	updateTimer = setTimeout(async () => {
		const result = await post('update', { appearance: state.appearance })
		if (result.ok && result.limits) {
			state.limits = result.limits
			refreshLimits()
		}
	}, 40)
}

function applySnapshot(result) {
	if (!result || !result.ok) return
	if (result.appearance) state.appearance = result.appearance
	if (result.limits) state.limits = result.limits
	if (result.outfits) state.outfits = result.outfits
	renderStep()
}

function setCamera(preset) {
	if (state.camera === preset) return
	state.camera = preset
	post('camera', { preset })
	renderCameras()
}

// Controles -----------------------------------------------------------------------------------------------------

function slider({ label, value, min = 0, max = 1, step = 0.01, left, right, format, onInput }) {
	const box = el('div', 'slider')
	const name = el('label', '', label)
	const output = el('output')
	const input = el('input')
	input.type = 'range'
	input.min = min
	input.max = max
	input.step = step
	input.value = value
	const show = () => { output.textContent = format ? format(Number(input.value)) : Number(input.value).toFixed(2) }
	input.addEventListener('input', () => {
		show()
		onInput(Number(input.value))
	})
	show()
	box.append(name, output, input)
	if (left || right) {
		const ends = el('div', 'ends')
		ends.append(el('span', '', left || ''), el('span', '', right || ''))
		box.append(ends)
	}
	return box
}

// Seletor de índice com setas. `min` pode ser -1 (nenhum). `refresh` devolve o máximo atual (exclusivo).
function stepper({ label, value, min = 0, max, format, onChange, limitKey }) {
	const box = el('div', 'stepper')
	box.append(el('span', '', label))
	const controls = el('div', 'controls')
	const prev = el('button', '', '‹')
	const next = el('button', '', '›')
	prev.type = next.type = 'button'
	const output = el('span', 'value')
	let current = value
	const bound = () => Math.max(min, (typeof max === 'function' ? max() : max) - 1)
	const show = () => {
		const top = bound()
		output.textContent = format ? format(current, top) : (current < 0 ? 'Nenhum' : `${current + 1} / ${top + 1}`)
	}
	const move = (delta) => {
		const top = bound()
		let target = current + delta
		if (target > top) target = min
		if (target < min) target = top
		current = target
		show()
		onChange(current)
	}
	prev.addEventListener('click', () => move(-1))
	next.addEventListener('click', () => move(1))
	controls.append(prev, output, next)
	box.append(controls)
	box.refresh = (newValue) => {
		if (newValue !== undefined) current = newValue
		if (current > bound()) current = bound()
		show()
	}
	if (limitKey) box.dataset.limit = limitKey
	show()
	return box
}

function swatches(palette, value, onPick) {
	const box = el('div', 'swatches')
	palette.forEach((rgb, index) => {
		const swatch = el('button', `swatch${index === value ? ' is-active' : ''}`)
		swatch.type = 'button'
		swatch.style.background = `rgb(${rgb[0]}, ${rgb[1]}, ${rgb[2]})`
		swatch.title = `Cor ${index + 1}`
		swatch.addEventListener('click', () => {
			box.querySelectorAll('.swatch').forEach((node) => node.classList.remove('is-active'))
			swatch.classList.add('is-active')
			onPick(index)
		})
		box.append(swatch)
	})
	return box
}

function group(title, ...children) {
	const box = el('section', 'group')
	box.append(el('h3', 'group-title', title), ...children)
	return box
}

const refreshers = []
function refreshLimits() {
	for (const refresh of refreshers) refresh()
}

// Etapas --------------------------------------------------------------------------------------------------------

function ageFrom(date) {
	const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(date || '')
	if (!match) return null
	const now = new Date()
	let age = now.getFullYear() - Number(match[1])
	if (now.getMonth() + 1 < Number(match[2]) || (now.getMonth() + 1 === Number(match[2]) && now.getDate() < Number(match[3]))) age -= 1
	return age
}

function isoYearsAgo(years) {
	const date = new Date()
	date.setFullYear(date.getFullYear() - years)
	return date.toISOString().slice(0, 10)
}

function validateIdentity() {
	const limits = state.identityLimits
	const nameOk = (value) => {
		const text = (value || '').trim()
		return text.length >= limits.NameMin && text.length <= limits.NameMax && /^[\p{L}][\p{L}' -]*$/u.test(text)
	}
	if (!nameOk(state.identity.firstName)) return `Nome: de ${limits.NameMin} a ${limits.NameMax} letras.`
	if (!nameOk(state.identity.lastName)) return `Sobrenome: de ${limits.NameMin} a ${limits.NameMax} letras.`
	const age = ageFrom(state.identity.birthDate)
	if (age === null) return 'Informe a data de nascimento.'
	if (age < limits.MinAge || age > limits.MaxAge) return `A idade deve ficar entre ${limits.MinAge} e ${limits.MaxAge} anos.`
	return ''
}

function stepIdentity(body) {
	const first = el('input', 'coe-field')
	first.maxLength = state.identityLimits.NameMax
	first.value = state.identity.firstName
	first.autocomplete = 'off'
	first.addEventListener('input', () => { state.identity.firstName = first.value })
	const last = el('input', 'coe-field')
	last.maxLength = state.identityLimits.NameMax
	last.value = state.identity.lastName
	last.autocomplete = 'off'
	last.addEventListener('input', () => { state.identity.lastName = last.value })
	const birth = el('input', 'coe-field')
	birth.type = 'date'
	birth.min = isoYearsAgo(state.identityLimits.MaxAge)
	birth.max = isoYearsAgo(state.identityLimits.MinAge)
	if (!state.identity.birthDate) state.identity.birthDate = isoYearsAgo(25)
	birth.value = state.identity.birthDate
	birth.addEventListener('input', () => { state.identity.birthDate = birth.value })

	const fieldFirst = el('label', 'field')
	fieldFirst.append('Nome', first)
	const fieldLast = el('label', 'field')
	fieldLast.append('Sobrenome', last)
	const row = el('div', 'field-row')
	row.append(fieldFirst, fieldLast)
	const fieldBirth = el('label', 'field')
	fieldBirth.append('Data de nascimento', birth)

	const toggle = el('div', 'toggle')
	for (const [value, text] of [['male', 'Masculino'], ['female', 'Feminino']]) {
		const button = el('button', state.gender === value ? 'is-active' : '', text)
		button.type = 'button'
		button.addEventListener('click', async () => {
			if (state.gender === value) return
			state.gender = value
			applySnapshot(await post('gender', { gender: value }))
		})
		toggle.append(button)
	}
	body.append(group('Quem é você', row, fieldBirth), group('Gênero', toggle,
		el('p', 'hint', 'Trocar o gênero recomeça a aparência.')))
	setTimeout(() => first.focus(), 50)
}

function parentGrid(list, value, onPick) {
	const grid = el('div', 'parents')
	for (const parent of list) {
		const card = el('button', `parent${parent.id === value ? ' is-active' : ''}`)
		card.type = 'button'
		card.title = parent.name
		const image = el('img')
		image.alt = ''
		image.src = `https://nui-img/char_creator_portraits/${parent.portrait}`
		image.addEventListener('error', () => image.replaceWith(el('div', 'initial', parent.name.charAt(0))), { once: true })
		card.append(image, el('span', 'name', parent.name))
		card.addEventListener('click', () => {
			grid.querySelectorAll('.parent').forEach((node) => node.classList.remove('is-active'))
			card.classList.add('is-active')
			onPick(parent.id)
		})
		grid.append(card)
	}
	return grid
}

function stepHeritage(body) {
	const heritage = state.appearance.heritage
	const mothers = state.schema.mothers
	const fathers = state.schema.fathers
	const nameOf = (list, id) => list.find((entry) => entry.id === id)?.name || ''
	const percent = (value) => `${Math.round((1 - value) * 100)}% / ${Math.round(value * 100)}%`
	body.append(
		group('Mãe', parentGrid(mothers, heritage.mother, (id) => { heritage.mother = id; pushAppearance() })),
		group('Pai', parentGrid(fathers, heritage.father, (id) => { heritage.father = id; pushAppearance() })),
		group('Mistura',
			slider({ label: 'Semelhança', value: heritage.shapeMix, left: 'Mãe', right: 'Pai', format: percent, onInput: (value) => { heritage.shapeMix = value; pushAppearance() } }),
			slider({ label: 'Tom de pele', value: heritage.skinMix, left: 'Mãe', right: 'Pai', format: percent, onInput: (value) => { heritage.skinMix = value; pushAppearance() } }),
			el('p', 'hint', `${nameOf(mothers, heritage.mother)} e ${nameOf(fathers, heritage.father)}`))
	)
}

function stepFace(body) {
	for (const featureGroup of state.schema.featureGroups) {
		const sliders = featureGroup.features.map(([index, label]) => slider({
			label, value: state.appearance.features[index], min: -1, max: 1,
			format: (value) => (value > 0 ? '+' : '') + Math.round(value * 100),
			onInput: (value) => { state.appearance.features[index] = value; pushAppearance() }
		}))
		body.append(group(featureGroup.label, ...sliders))
	}
}

function overlayBlock(key, { withColor, palette, onlyMale } = {}) {
	const index = state.schema.overlays.findIndex((overlay) => overlay.key === key)
	if (index < 0 || (onlyMale && state.gender !== 'male')) return null
	const overlay = state.schema.overlays[index]
	const entry = state.appearance.overlays[index]
	const children = [
		stepper({
			label: 'Estilo', value: entry.style, min: -1,
			max: () => (state.limits?.overlays?.[String(overlay.id)] || overlay.max + 1),
			onChange: (value) => { entry.style = value; pushAppearance() }
		}),
		slider({ label: 'Intensidade', value: entry.opacity, format: (value) => `${Math.round(value * 100)}%`, onInput: (value) => { entry.opacity = value; pushAppearance() } })
	]
	if (withColor && palette.length) {
		children.push(swatches(palette, entry.color, (color) => { entry.color = color; entry.secondColor = color; pushAppearance() }))
	}
	return group(overlay.label, ...children)
}

function stepDetails(body) {
	const eyes = stepper({
		label: 'Cor dos olhos', value: state.appearance.eyeColor, max: EYE_COLORS.length,
		format: (value) => EYE_COLORS[value] || `${value + 1}`,
		onChange: (value) => { state.appearance.eyeColor = value; pushAppearance() }
	})
	body.append(group('Olhos', eyes))
	for (const key of ['complexion', 'ageing', 'freckles', 'blemishes', 'sunDamage', 'bodyBlemishes']) {
		const block = overlayBlock(key)
		if (block) body.append(block)
	}
}

function stepHair(body) {
	const hair = state.appearance.hair
	const style = stepper({
		label: 'Corte', value: hair.style, max: () => state.limits?.hair || 1,
		onChange: (value) => { hair.style = value; hair.texture = 0; texture.refresh(0); pushAppearance() }
	})
	const texture = stepper({
		label: 'Variação', value: hair.texture, max: () => state.limits?.hairTextures || 1,
		onChange: (value) => { hair.texture = value; pushAppearance() }
	})
	refreshers.push(() => { style.refresh(); texture.refresh() })
	body.append(group('Cabelo', style, texture,
		el('p', 'hint', 'Cor'), swatches(state.palettes.hair, hair.color, (color) => { hair.color = color; pushAppearance() }),
		el('p', 'hint', 'Luzes'), swatches(state.palettes.hair, hair.highlight, (color) => { hair.highlight = color; pushAppearance() })))
	const blocks = [
		overlayBlock('eyebrows', { withColor: true, palette: state.palettes.hair }),
		overlayBlock('beard', { withColor: true, palette: state.palettes.hair, onlyMale: true }),
		overlayBlock('chestHair', { withColor: true, palette: state.palettes.hair, onlyMale: true }),
		overlayBlock('makeup'),
		overlayBlock('blush', { withColor: true, palette: state.palettes.makeup }),
		overlayBlock('lipstick', { withColor: true, palette: state.palettes.makeup })
	]
	for (const block of blocks) if (block) body.append(block)
}

// Roupas: subcategorias (abas) > peças (pílulas) > grade de fotos; variações (texturas) da peça escolhida embaixo.
const GRID_PAGE = 48

function thumbUrl(part, drawable) {
	if (!state.thumbs || drawable < 0) return null
	const kind = part.kind === 'prop' ? 'p' : 'c'
	return `${state.thumbs.base}${state.gender}_${kind}${part.id}_${drawable}.${state.thumbs.extension}`
}

function partStore(part) {
	const key = String(part.id)
	const store = part.kind === 'prop' ? state.appearance.props : state.appearance.components
	store[key] = store[key] || { drawable: part.kind === 'prop' ? -1 : 0, texture: 0 }
	return store[key]
}

function drawableCount(part) {
	const key = String(part.id)
	return (part.kind === 'prop' ? state.limits?.props?.[key] : state.limits?.components?.[key]) || 0
}

function textureCount(part) {
	const key = String(part.id)
	return (part.kind === 'prop' ? state.limits?.propTextures?.[key] : state.limits?.textures?.[key]) || 0
}

function focusPart(part) {
	setCamera((part.kind === 'prop' ? PROP_CAMERA : PART_CAMERA)[part.id] || 'body')
}

function thumbCard(part, drawable, active, onPick) {
	const card = el('button', `thumb${active ? ' is-active' : ''}`)
	card.type = 'button'
	card.dataset.drawable = String(drawable)
	if (drawable < 0) {
		card.classList.add('is-none')
		card.append(el('span', 'thumb-none', '∅'), el('span', 'thumb-num', 'Nenhum'))
	} else {
		const url = thumbUrl(part, drawable)
		if (url) {
			const image = el('img')
			image.alt = ''
			image.loading = 'lazy'
			image.decoding = 'async'
			image.src = url
			image.addEventListener('error', () => {
				card.classList.add('no-photo')
				image.replaceWith(el('span', 'thumb-fallback', String(drawable + 1)))
			}, { once: true })
			card.append(image)
		} else {
			card.classList.add('no-photo')
			card.append(el('span', 'thumb-fallback', String(drawable + 1)))
		}
		card.append(el('span', 'thumb-num', `#${drawable + 1}`))
	}
	card.title = drawable < 0 ? 'Nenhum' : `${part.label} ${drawable + 1}`
	card.addEventListener('click', () => onPick(drawable, card))
	return card
}

function variantsBlock(part) {
	const box = el('div', 'variants')
	const render = () => {
		const entry = partStore(part)
		const count = textureCount(part)
		box.replaceChildren()
		if (entry.drawable < 0 || count <= 1) {
			box.append(el('p', 'hint', entry.drawable < 0 ? 'Nenhuma peça escolhida.' : 'Esta peça não tem outras cores.'))
			return
		}
		const row = el('div', 'variant-row')
		for (let index = 0; index < count; index += 1) {
			const chip = el('button', `variant${index === entry.texture ? ' is-active' : ''}`, String(index + 1))
			chip.type = 'button'
			chip.title = `Variação ${index + 1}`
			chip.addEventListener('click', () => {
				entry.texture = index
				row.querySelectorAll('.variant').forEach((node) => node.classList.toggle('is-active', node === chip))
				focusPart(part)
				pushAppearance()
			})
			row.append(chip)
		}
		box.append(row)
	}
	render()
	refreshers.push(render)
	return box
}

function partGrid(part) {
	const wrap = el('div', 'part-grid')
	const entry = partStore(part)
	const head = el('div', 'grid-head')
	const counter = el('span', 'grid-count')
	const jump = el('input', 'coe-field grid-jump')
	jump.type = 'number'
	jump.min = 1
	jump.placeholder = 'Nº'
	jump.title = 'Ir para o número da peça'
	head.append(counter, jump)
	const grid = el('div', 'thumbs')
	const sentinel = el('div', 'grid-sentinel')
	let rendered = 0

	const updateCounter = () => {
		const total = drawableCount(part)
		counter.textContent = entry.drawable < 0 ? `${total} opções` : `Peça ${entry.drawable + 1} de ${total}`
	}
	const pick = (drawable, card) => {
		entry.drawable = drawable
		entry.texture = 0
		grid.querySelectorAll('.thumb.is-active').forEach((node) => node.classList.remove('is-active'))
		if (card) card.classList.add('is-active')
		updateCounter()
		focusPart(part)
		pushAppearance()
	}
	const renderMore = (until) => {
		const total = drawableCount(part)
		const target = Math.min(total, Math.max(rendered + GRID_PAGE, until || 0))
		for (let drawable = rendered; drawable < target; drawable += 1) {
			grid.append(thumbCard(part, drawable, drawable === entry.drawable, pick))
		}
		rendered = target
		sentinel.classList.toggle('is-hidden', rendered >= total)
	}
	if (part.kind === 'prop') grid.append(thumbCard(part, -1, entry.drawable < 0, pick))
	renderMore(entry.drawable + 1)

	jump.addEventListener('change', () => {
		const total = drawableCount(part)
		const number = Math.min(total, Math.max(1, Math.round(Number(jump.value) || 1)))
		jump.value = number
		renderMore(number)
		const card = grid.querySelector(`.thumb[data-drawable="${number - 1}"]`)
		if (card) {
			pick(number - 1, card)
			card.scrollIntoView({ block: 'center' })
		}
	})
	// Carrega mais cards conforme a rolagem chega ao fim da grade.
	const observer = new IntersectionObserver((entries) => {
		if (entries.some((item) => item.isIntersecting)) renderMore()
	}, { root: $('step-body'), rootMargin: '240px' })
	observer.observe(sentinel)

	updateCounter()
	refreshers.push(updateCounter)
	wrap.append(head, grid, sentinel)
	setTimeout(() => grid.querySelector('.thumb.is-active')?.scrollIntoView({ block: 'nearest' }), 0)
	return wrap
}

function stepClothes(body) {
	const categories = state.schema.clothing || []
	const tabs = []
	if (state.outfits.length) tabs.push({ key: 'outfits', label: 'Conjuntos' })
	for (const category of categories) tabs.push({ key: category.key, label: category.label })
	if (!tabs.some((tab) => tab.key === state.clothesTab)) state.clothesTab = tabs[0]?.key

	const bar = el('div', 'subtabs')
	for (const tab of tabs) {
		const button = el('button', `subtab${tab.key === state.clothesTab ? ' is-active' : ''}`, tab.label)
		button.type = 'button'
		button.addEventListener('click', () => {
			if (state.clothesTab === tab.key) return
			state.clothesTab = tab.key
			renderStep()
		})
		bar.append(button)
	}
	body.append(bar)

	if (state.clothesTab === 'outfits') {
		const outfits = el('div', 'outfits')
		for (const outfit of state.outfits) {
			const button = el('button', '', outfit.label)
			button.type = 'button'
			button.addEventListener('click', async () => applySnapshot(await post('outfit', { id: outfit.id })))
			outfits.append(button)
		}
		body.append(group('Conjuntos prontos', outfits, el('p', 'hint', 'Ponto de partida: depois ajuste peça por peça nas outras abas.')))
		return
	}

	const category = categories.find((entry) => entry.key === state.clothesTab)
	if (!category) return
	const partIndex = Math.min(state.clothesPart[category.key] || 0, category.parts.length - 1)
	const part = category.parts[partIndex]
	if (category.parts.length > 1) {
		const pills = el('div', 'pills')
		category.parts.forEach((entry, index) => {
			const pill = el('button', `pill${index === partIndex ? ' is-active' : ''}`, entry.label)
			pill.type = 'button'
			pill.addEventListener('click', () => {
				if (index === partIndex) return
				state.clothesPart[category.key] = index
				focusPart(entry)
				renderStep()
			})
			pills.append(pill)
		})
		body.append(pills)
	}
	body.append(group(part.label, partGrid(part)), group('Variações', variantsBlock(part)))
	if (!state.thumbs) body.append(el('p', 'hint', 'Fotos das peças desligadas no servidor.'))
}

function stepReview(body) {
	const heritage = state.appearance.heritage
	const nameOf = (list, id) => list.find((entry) => entry.id === id)?.name || '—'
	const summary = el('div', 'summary')
	const rows = []
	if (state.mode === 'create') {
		rows.push(['Nome', `${state.identity.firstName.trim()} ${state.identity.lastName.trim()}`])
		rows.push(['Idade', `${ageFrom(state.identity.birthDate) ?? '—'} anos`])
	}
	rows.push(['Gênero', state.gender === 'female' ? 'Feminino' : 'Masculino'])
	rows.push(['Pais', `${nameOf(state.schema.mothers, heritage.mother)} e ${nameOf(state.schema.fathers, heritage.father)}`])
	rows.push(['Olhos', EYE_COLORS[state.appearance.eyeColor] || `${state.appearance.eyeColor + 1}`])
	for (const [label, value] of rows) {
		const row = el('div')
		row.append(el('span', '', label), el('strong', '', value))
		summary.append(row)
	}
	body.append(group('Resumo', summary), el('p', 'hint', state.mode === 'create'
		? 'Ao concluir, o personagem é registrado e aparece na seleção.'
		: 'Ao concluir, a aparência fica salva neste personagem.'))
}

const RENDER = { identity: stepIdentity, heritage: stepHeritage, face: stepFace, details: stepDetails, hair: stepHair, clothes: stepClothes, review: stepReview }

// Estrutura -----------------------------------------------------------------------------------------------------

function renderSteps() {
	const nav = $('steps')
	nav.replaceChildren()
	steps().forEach((step, index) => {
		const button = el('button', `step${index === state.step ? ' is-active' : ''}${index < state.step ? ' is-done' : ''}`)
		button.type = 'button'
		button.append(el('span', 'step-number', String(index + 1)), el('span', '', step.label))
		button.addEventListener('click', () => goTo(index))
		nav.append(button)
	})
}

function renderCameras() {
	const box = $('cameras')
	box.replaceChildren()
	for (const [preset, label] of CAMERAS) {
		const chip = el('button', `chip${preset === state.camera ? ' is-active' : ''}`, label)
		chip.type = 'button'
		chip.addEventListener('click', () => setCamera(preset))
		box.append(chip)
	}
}

function renderStep() {
	if (!state.appearance || !state.schema) return
	const list = steps()
	const step = list[state.step]
	refreshers.length = 0
	$('step-count').textContent = `ETAPA ${state.step + 1} DE ${list.length}`
	$('step-title').textContent = step.label
	$('step-hint').textContent = step.hint
	const body = $('step-body')
	body.replaceChildren()
	RENDER[step.id](body)
	body.scrollTop = 0
	$('back').disabled = state.step === 0
	$('next').textContent = state.step === list.length - 1 ? (state.mode === 'create' ? 'Registrar personagem' : 'Salvar aparência') : 'Próximo'
	renderSteps()
	renderCameras()
}

function goTo(index) {
	const list = steps()
	if (index < 0 || index >= list.length) return
	// Só avança da identidade com dados válidos.
	if (state.mode === 'create' && state.step === 0 && index > 0) {
		const problem = validateIdentity()
		if (problem) {
			message(problem)
			return
		}
	}
	message('')
	state.step = index
	const camera = state.cameraSteps[list[index].id]
	if (camera) setCamera(camera)
	renderStep()
}

async function submit() {
	if (state.saving) return
	if (state.mode === 'create') {
		const problem = validateIdentity()
		if (problem) {
			message(problem)
			goTo(0)
			return
		}
	}
	const confirmed = await CoeUI.confirm({
		title: state.mode === 'create' ? 'Registrar personagem' : 'Salvar aparência',
		message: 'Depois de registrar, o visual só muda em barbearias e lojas de roupa. Continuar?',
		confirmLabel: 'Registrar'
	})
	if (!confirmed) return
	state.saving = true
	$('saving').classList.remove('is-hidden')
	message('')
	const result = await post('submit', {
		identity: { firstName: state.identity.firstName.trim(), lastName: state.identity.lastName.trim(), birthDate: state.identity.birthDate },
		appearance: state.appearance
	})
	if (!result.ok) {
		state.saving = false
		$('saving').classList.add('is-hidden')
		message('Não foi possível enviar.')
	}
}

// Eventos -------------------------------------------------------------------------------------------------------

$('back').addEventListener('click', () => goTo(state.step - 1))
$('next').addEventListener('click', () => {
	if (state.step === steps().length - 1) submit()
	else goTo(state.step + 1)
})
$('randomize').addEventListener('click', async () => applySnapshot(await post('randomize')))
$('cancel').addEventListener('click', async () => {
	const confirmed = await CoeUI.confirm({
		title: 'Sair do criador',
		message: 'As alterações não salvas serão perdidas.',
		confirmLabel: 'Sair',
		danger: true
	})
	if (confirmed) post('cancel')
})
document.querySelectorAll('[data-rotate]').forEach((button) => {
	button.addEventListener('click', () => post('rotate', { delta: Number(button.dataset.rotate) }))
})
document.querySelector('[data-rotate-reset]').addEventListener('click', () => post('resetRotation'))

// Arrastar no espaço livre gira o personagem.
const stage = $('stage')
let dragX = null
let pending = 0
let rotateTimer = null
stage.addEventListener('mousedown', (event) => {
	dragX = event.clientX
	stage.classList.add('is-dragging')
})
window.addEventListener('mouseup', () => {
	dragX = null
	stage.classList.remove('is-dragging')
})
window.addEventListener('mousemove', (event) => {
	if (dragX === null) return
	pending += (event.clientX - dragX) * 0.45
	dragX = event.clientX
	if (!rotateTimer) {
		rotateTimer = setTimeout(() => {
			rotateTimer = null
			if (pending) post('rotate', { delta: pending })
			pending = 0
		}, 30)
	}
})

window.addEventListener('keydown', (event) => {
	if (!state.open || state.saving) return
	if (event.target instanceof HTMLInputElement && event.target.type !== 'range') return
	if (event.key === 'a' || event.key === 'A') post('rotate', { delta: -15 })
	if (event.key === 'd' || event.key === 'D') post('rotate', { delta: 15 })
})

window.addEventListener('message', (event) => {
	const data = event.data || {}
	if (data.action === 'open') {
		Object.assign(state, {
			open: true,
			mode: data.mode === 'appearance' ? 'appearance' : 'create',
			gender: data.gender === 'female' ? 'female' : 'male',
			identity: Object.assign({ firstName: '', lastName: '', birthDate: '' }, data.identity || {}),
			identityLimits: data.identityLimits || state.identityLimits,
			appearance: data.appearance,
			limits: data.limits,
			palettes: data.palettes || state.palettes,
			schema: data.schema,
			outfits: data.outfits || [],
			cameraSteps: data.cameras || {},
			thumbs: data.thumbs && typeof data.thumbs.base === 'string' ? data.thumbs : null,
			clothesTab: null,
			clothesPart: {},
			step: 0,
			saving: false
		})
		state.camera = state.cameraSteps[steps()[0].id] || 'body'
		$('creator-mode').textContent = state.mode === 'create' ? 'NOVO PERSONAGEM' : 'DEFINIR APARÊNCIA'
		$('saving').classList.add('is-hidden')
		$('creator').classList.remove('is-hidden')
		message('')
		renderStep()
	} else if (data.action === 'close') {
		state.open = false
		state.saving = false
		$('creator').classList.add('is-hidden')
		$('saving').classList.add('is-hidden')
	} else if (data.action === 'thumbCrop') {
		cropThumb(data)
	} else if (data.action === 'thumbsProgress') {
		$('thumbs-progress').textContent = data.text || ''
		$('thumbs-progress').classList.toggle('is-hidden', !data.text)
	} else if (data.action === 'error') {
		state.saving = false
		$('saving').classList.add('is-hidden')
		message(data.message || 'Não foi possível salvar.')
	}
})

// Gerador de fotos: recorta o centro da captura em um quadrado e reduz para `size` px (webp).
function cropThumb({ id, data, size = 256, crop = 0.62, quality = 0.8, type = 'image/webp' }) {
	const image = new Image()
	image.onload = () => {
		const side = Math.round(Math.min(image.height * crop, image.width))
		const sx = Math.round((image.width - side) / 2)
		const sy = Math.round((image.height - side) / 2)
		const canvas = document.createElement('canvas')
		canvas.width = canvas.height = size
		const context = canvas.getContext('2d')
		context.imageSmoothingQuality = 'high'
		context.drawImage(image, sx, sy, side, side, 0, 0, size, size)
		post('thumbCropped', { id, data: canvas.toDataURL(type, quality) })
	}
	image.onerror = () => post('thumbCropped', { id, data: null })
	image.src = data
}

post('coe_theme_ready')
