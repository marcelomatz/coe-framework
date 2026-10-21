function reportToGame(message) {
	fetch(`https://${GetParentResourceName()}/nuiError`, {
		method: 'POST',
		headers: { 'Content-Type': 'application/json; charset=UTF-8' },
		body: JSON.stringify({ message: String(message) })
	}).catch(() => {})
}

window.addEventListener('error', (event) => reportToGame(`${event.message} (${event.lineno}:${event.colno})`))
window.addEventListener('unhandledrejection', (event) => reportToGame(event.reason))
fetch(`https://${GetParentResourceName()}/nuiReady`, {
	method: 'POST',
	headers: { 'Content-Type': 'application/json; charset=UTF-8' },
	body: '{}'
}).catch(() => {})

const app = document.getElementById('app')
const list = document.getElementById('character-list')
const message = document.getElementById('message')
const hero = document.getElementById('hero')
const form = document.getElementById('create-form')
const modal = document.getElementById('create-modal')
const changeButton = document.getElementById('change-character')
const genderSelect = document.getElementById('gender')

let characters = []
let selectedId = null
let selectionRequired = true
let creatorAvailable = true
let busy = false
// A interface fica escondida até a cena 3D estar pronta (mensagem 'reveal' do client).
let waitingScene = false

const errorMessages = {
	character_limit_reached: 'Você atingiu o limite de personagens.',
	character_not_found: 'Esse personagem não está disponível.',
	character_not_loaded: 'Nenhum personagem está ativo.',
	character_not_owned: 'Esse personagem não pertence à sua conta.',
	character_selection_required: 'Selecione um personagem antes de continuar.',
	invalid_character_id: 'O identificador do personagem é inválido.',
	invalid_character_name: 'Informe um nome e sobrenome válidos.',
	invalid_birth_date: 'Informe uma data de nascimento válida.',
	birth_date_out_of_range: 'A idade do personagem está fora do permitido.',
	invalid_gender: 'Selecione um gênero válido.',
	invalid_profile: 'Os dados do personagem são inválidos.',
	operation_in_progress: 'Aguarde a operação atual terminar.',
	player_not_loaded: 'Seus dados ainda não foram carregados.',
	rate_limited: 'Aguarde um momento antes de tentar novamente.',
	request_capacity: 'Muitas solicitações estão em andamento.',
	request_failed: 'Não foi possível enviar a solicitação.'
}

function formatError(error) {
	if (typeof error !== 'string') return 'Não foi possível concluir a solicitação.'
	return errorMessages[error] || 'Não foi possível concluir a solicitação.'
}

function post(endpoint, payload) {
	return fetch(`https://${GetParentResourceName()}/${endpoint}`, {
		method: 'POST',
		headers: { 'Content-Type': 'application/json; charset=UTF-8' },
		body: JSON.stringify(payload)
	}).then((response) => response.json()).catch(() => {
		setBusy(false)
		showMessage('Não foi possível comunicar com o cliente do jogo.')
		return { success: false }
	})
}

function showMessage(text = '') {
	message.textContent = text
}

function setBusy(value) {
	busy = value
	for (const control of app.querySelectorAll('button, input, select')) control.disabled = value
}

function el(tag, className, text) {
	const node = document.createElement(tag)
	if (className) node.className = className
	if (text !== undefined) node.textContent = text
	return node
}

function renderGenders(genders) {
	if (!Array.isArray(genders)) return
	genderSelect.replaceChildren()
	for (const gender of genders) {
		if (typeof gender.value === 'string' && typeof gender.label === 'string') genderSelect.append(new Option(gender.label, gender.value))
	}
}

function ageOf(birthDate) {
	const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(birthDate || '')
	if (!match) return null
	const now = new Date()
	let age = now.getFullYear() - Number(match[1])
	if (now.getMonth() + 1 < Number(match[2]) || (now.getMonth() + 1 === Number(match[2]) && now.getDate() < Number(match[3]))) age -= 1
	return age
}

const GENDERS = { male: 'Masculino', female: 'Feminino' }

function initials(character) {
	return `${(character.firstName || '?').charAt(0)}${(character.lastName || '').charAt(0)}`.toUpperCase()
}

function current() {
	return characters.find((character) => character.characterId === selectedId) || null
}

function select(characterId, notify = true) {
	if (!characters.some((character) => character.characterId === characterId)) return
	const changed = selectedId !== characterId
	selectedId = characterId
	renderCharacters()
	renderHero()
	if (notify && changed) post('focusCharacter', { characterId })
}

function renderCharacters() {
	list.replaceChildren()
	if (characters.length === 0) {
		list.append(el('p', 'empty-state', 'Você ainda não tem personagens. Crie o primeiro.'))
		return
	}
	for (const character of characters) {
		const card = el('button', `character-card${character.characterId === selectedId ? ' is-active' : ''}`)
		card.type = 'button'
		const text = el('span')
		const name = el('span', 'card-name', `${character.firstName} ${character.lastName}`)
		if (!character.appearance) name.append(el('span', 'card-badge', 'APARÊNCIA PENDENTE'))
		const age = ageOf(character.birthDate)
		text.append(name, el('span', 'card-meta', [character.stateId ? `ID ${character.stateId}` : `#${character.characterId}`, age !== null ? `${age} anos` : null].filter(Boolean).join(' · ')))
		card.append(el('span', 'monogram', initials(character)), text)
		card.addEventListener('click', () => select(character.characterId))
		card.addEventListener('dblclick', () => play())
		list.append(card)
	}
}

function renderHero() {
	const character = current()
	hero.classList.toggle('is-hidden', !character)
	if (!character) return
	document.getElementById('hero-name').textContent = `${character.firstName} ${character.lastName}`
	const meta = document.getElementById('hero-meta')
	meta.replaceChildren()
	const age = ageOf(character.birthDate)
	const items = [
		['ID', character.stateId || `#${character.characterId}`],
		age !== null ? ['Idade', `${age} anos`] : null,
		character.gender ? ['Gênero', GENDERS[character.gender] || character.gender] : null
	].filter(Boolean)
	for (const [label, value] of items) {
		const chip = el('span', '', `${label} `)
		chip.append(el('strong', '', value))
		meta.append(chip)
	}
	document.getElementById('hero-pending').classList.toggle('is-hidden', Boolean(character.appearance))
	document.getElementById('hero-state').textContent = character.appearance ? 'PRONTO PARA ENTRAR' : 'PRIMEIRO ACESSO'
	document.getElementById('play').classList.toggle('is-hidden', !selectionRequired)
}

function setCharacters(next, focusId) {
	characters = Array.isArray(next) ? next : []
	const wanted = focusId && characters.some((character) => character.characterId === focusId) ? focusId : null
	if (wanted) selectedId = wanted
	else if (!characters.some((character) => character.characterId === selectedId)) selectedId = characters[0]?.characterId || null
	renderCharacters()
	renderHero()
}

function open(data) {
	selectionRequired = data.selectionRequired
	if (!waitingScene) app.classList.remove('is-hidden')
	changeButton.classList.toggle('is-hidden', selectionRequired)
	modal.classList.add('is-hidden')
	setBusy(false)
	showMessage('')
	setCharacters(data.characters, data.focus)
}

function play() {
	const character = current()
	if (!character || busy || !selectionRequired) return
	setBusy(true)
	post('selectCharacter', { characterId: character.characterId }).then((result) => {
		if (result && result.success === false) setBusy(false)
	})
}

function applyResult(data) {
	setBusy(false)
	if (!data.success) {
		showMessage(formatError(data.result))
		return
	}
	showMessage('')
}

window.addEventListener('message', (event) => {
	const data = event.data
	switch (data.action) {
		case 'open':
			renderGenders(data.genders)
			creatorAvailable = data.creator !== false
			waitingScene = data.waitScene === true
			app.classList.toggle('is-hidden', waitingScene)
			break
		case 'reveal':
			waitingScene = false
			app.classList.remove('is-hidden')
			break
		case 'close':
			app.classList.add('is-hidden')
			setBusy(false)
			break
		case 'selectionRequired':
			open({ selectionRequired: true, characters: data.characters, focus: data.focus })
			break
		case 'characters':
			setBusy(false)
			setCharacters(data.characters)
			break
		case 'focus':
			if (data.characterId) select(data.characterId, false)
			break
		case 'createResult':
			applyResult(data)
			if (data.success) modal.classList.add('is-hidden')
			break
		case 'selectResult':
			applyResult(data)
			break
		case 'changeResult':
			if (data.success) open({ selectionRequired: true, characters: data.result })
			else applyResult(data)
			break
		case 'archiveResult':
			applyResult(data)
			break
		case 'listResult':
			setBusy(false)
			if (data.success) setCharacters(data.result)
			else showMessage(formatError(data.result))
			break
		case 'error':
			setBusy(false)
			showMessage(formatError(data.message))
			break
		default:
			break
	}
})

document.getElementById('play').addEventListener('click', play)

document.getElementById('archive').addEventListener('click', async () => {
	const character = current()
	if (!character || busy) return
	const confirmed = await CoeUI.confirm({
		title: 'Arquivar personagem',
		message: `Arquivar ${character.firstName} ${character.lastName}? Os dados serão preservados.`,
		confirmLabel: 'Arquivar',
		danger: true
	})
	if (!confirmed) return
	setBusy(true)
	post('archiveCharacter', { characterId: character.characterId })
})

document.getElementById('new-character').addEventListener('click', async () => {
	if (busy) return
	if (creatorAvailable) {
		const result = await post('newCharacter', {})
		if (result && result.success !== false) return
	}
	modal.classList.remove('is-hidden')
})

document.getElementById('create-cancel').addEventListener('click', () => modal.classList.add('is-hidden'))

form.addEventListener('submit', (event) => {
	event.preventDefault()
	if (busy) return
	const values = new FormData(form)
	setBusy(true)
	post('createCharacter', {
		firstName: values.get('firstName'),
		lastName: values.get('lastName'),
		birthDate: values.get('birthDate'),
		gender: values.get('gender')
	})
})

changeButton.addEventListener('click', () => {
	if (!busy) {
		setBusy(true)
		post('changeCharacter', {})
	}
})

window.addEventListener('keydown', (event) => {
	if (app.classList.contains('is-hidden') || !modal.classList.contains('is-hidden') || busy) return
	if (document.querySelector('.coe-modal')) return
	const index = characters.findIndex((character) => character.characterId === selectedId)
	if ((event.key === 'ArrowDown' || event.key === 'ArrowRight') && characters.length) {
		event.preventDefault()
		select(characters[(index + 1) % characters.length].characterId)
	} else if ((event.key === 'ArrowUp' || event.key === 'ArrowLeft') && characters.length) {
		event.preventDefault()
		select(characters[(index - 1 + characters.length) % characters.length].characterId)
	} else if (event.key === 'Enter') {
		event.preventDefault()
		play()
	}
})

fetch(`https://${GetParentResourceName()}/coe_theme_ready`, { method: 'POST', body: '{}' }).catch(() => {})
